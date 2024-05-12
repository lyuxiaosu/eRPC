#include <gflags/gflags.h>
#include <signal.h>
#include <time.h>
#include <cstring>
#include <math.h>
#include <sstream>
#include <string>
#include <unordered_map>

#include "../apps_common.h"
#include "rpc.h"
#include "util/autorun_helpers.h"
#include "util/latency.h"
#include "util/numautils.h"
#include "util/timer.h"

std::atomic<uint64_t> warmup_completes(0);
/* type 1: Payment 5.7us -- pass parameter 8
 * type 2: OrderStatus 6us -- pass parameter 9
 * type 3: NewOrder 20us -- pass parameter 37 
 * type 4: Delivery 88us -- pass parameter 165
 * type 5: StockLevel 100us -- pass parameter 188
 */
int req_parameter_array[6] = {0, 8, 9, 37, 165, 188}; // index is type id

/* grouped type 1: type 1 and type 2, core 1,2
 * grouped type 2: type 3,            core 3,4,5,6,7,8
 * grouped type 3: type 4 and type 5, core 9,10,11,12,13,14
 */

int grouped_type_array[6] = {0, 1, 1, 2, 3, 3}; // index is type id
FILE *perf_log = NULL;
static constexpr size_t kAppEvLoopMs = 1000;     // Duration of event loop
static constexpr bool kAppVerbose = false;       // Print debug info on datapath
static constexpr double kAppLatFac = 10.0;       // Precision factor for latency
static size_t kAppReqType = 1;         // eRPC request type
static constexpr size_t kAppMaxWindowSize = 32;  // Max pending reqs per client

int sending_rps[100]; // each client thread sending rps
int service_rps[100]; // each client thread obtained the service rate
size_t responses[100]; // each client thread get the number of responses
uint32_t requests[100]; // each client thread sends out the number of requests
uint32_t dropped[100] = {0};

std::unordered_map<int, int> seperate_sending_rps; // key is request type, value is the sending rps
std::unordered_map<int, int> seperate_service_rps; 

std::vector<int> rps_array;
std::vector<int> req_type_array;
std::vector<int> warmup_rps;

DEFINE_uint64(num_server_threads, 1, "Number of threads at the server machine");
DEFINE_uint64(num_client_threads, 1, "Number of threads per client machine");
DEFINE_uint64(warmup_count, 100, "Number of packets to send during the warmup phase");
DEFINE_string(rps, "100", "Number of requests per second that client sends to the server");
DEFINE_string(req_type, "1", "Request type for each thread to send");
DEFINE_string(req_parameter, "15", "Request parameters of each type request");
DEFINE_string(warmup_rps, "200", "Number of requests per second during the warmup phase");
DEFINE_uint64(window_size, 1, "Outstanding requests per client");
DEFINE_uint64(req_size, 64, "Size of request message in bytes");
DEFINE_uint64(resp_size, 32, "Size of response message in bytes ");
DEFINE_bool(is_darc, false, "This is DARC algorithm or not");

struct Tag {
	erpc::MsgBuffer *req_msgbuf;
	erpc::MsgBuffer *resp_msgbuf;
	size_t ws_i;	
};

volatile sig_atomic_t ctrl_c_pressed = 0;
void ctrl_c_handler(int) { ctrl_c_pressed = 1; }

class ServerContext : public BasicAppContext {
 public:
  size_t num_resps = 0;
};

class ClientContext : public BasicAppContext {
 public:
  size_t num_resps = 0;
  size_t warmup_resps = 0;
  size_t thread_id;
  int request_type;
  int grouped_type;
  int send_type; //the type to be sent to the server 
  erpc::ChronoTimer *start_time = NULL;
  double *latency_array = NULL;
  int *pure_cpu_time = NULL;
  uint32_t *parameters = NULL;
  int request_parameter;
  struct timespec last_response_ts;
  erpc::Latency latency;
  erpc::MsgBuffer req_msgbuf[kAppMaxWindowSize], resp_msgbuf[kAppMaxWindowSize];
  ~ClientContext() {
  	if (start_time) {
		delete[] start_time;
		start_time = NULL;
	}
	if (latency_array) {
		free(latency_array);
		latency_array = NULL;
	}
	if (pure_cpu_time) {
		free(pure_cpu_time);
		pure_cpu_time = NULL;
	}
	if (parameters) {
		free(parameters);
		parameters = NULL;
	}
  }
};

/* Randon function follwing Poisson distribution */
double ran_expo(double lambda){
    double u;

    u = rand() / (RAND_MAX + 1.0);
    return -log(1- u) / lambda;
}

double ran_expo2(std::mt19937& generator, double lambda) {
    std::exponential_distribution<double> distribution(lambda);
    return distribution(generator);
}

void req_handler(erpc::ReqHandle *req_handle, void *_context) {
  auto *c = static_cast<ServerContext *>(_context);
  c->num_resps++;

  erpc::Rpc<erpc::CTransport>::resize_msg_buffer(&req_handle->pre_resp_msgbuf_,
                                                 FLAGS_resp_size);
  c->rpc_->enqueue_response(req_handle, &req_handle->pre_resp_msgbuf_);
}

void server_func(erpc::Nexus *nexus, size_t thread_id) {
  std::vector<size_t> port_vec = flags_get_numa_ports(FLAGS_numa_node);
  uint8_t phy_port = port_vec.at(0);

  ServerContext c;
  erpc::Rpc<erpc::CTransport> rpc(nexus, static_cast<void *>(&c), thread_id,
                                  basic_sm_handler, phy_port);
  c.rpc_ = &rpc;

  
  while (true) {
    c.num_resps = 0;
    erpc::ChronoTimer start;
    rpc.run_event_loop(kAppEvLoopMs);

    const double seconds = start.get_sec();
    printf("thread %zu: %.2f M/s. rx batch %.2f, tx batch %.2f\n", thread_id,
           c.num_resps / (seconds * Mi(1)), c.rpc_->get_avg_rx_batch(),
           c.rpc_->get_avg_tx_batch());

    c.rpc_->reset_dpath_stats();
    c.num_resps = 0;

    if (ctrl_c_pressed == 1) break;
  }
}

void app_cont_func(void *, void *);

inline void send_req(ClientContext &c, size_t ws_i) {
  c.rpc_->enqueue_request(c.round_robin_get_session_num(), 1,
                         &c.req_msgbuf[ws_i], &c.resp_msgbuf[ws_i],
                         app_cont_func, reinterpret_cast<void *>(ws_i));
}

void app_cont_func2(void *_context, void *_tag) {
  auto *c = static_cast<ClientContext *>(_context);
  auto *tag = reinterpret_cast<Tag *>(_tag);
  erpc::MsgBuffer *req_msgbuf = tag->req_msgbuf;
  erpc::MsgBuffer *resp_msgbuf = tag->resp_msgbuf;
  //assert(c->resp_msgbuf[ws_i].get_data_size() == FLAGS_resp_size);
  assert(resp_msgbuf->buf_[0] == '0');
  const double req_lat_us = c->start_time[tag->ws_i].get_us();
  c->latency_array[tag->ws_i] = req_lat_us;
  //printf("%s\n", resp_msgbuf->buf_);
  //printf("%f\n", req_lat_us);
  c->pure_cpu_time[tag->ws_i] = atoi(reinterpret_cast<const char*>(&(resp_msgbuf->buf_[2])));
  c->num_resps++;
  
  clock_gettime(CLOCK_MONOTONIC, &(c->last_response_ts)); 
  c->rpc_->free_msg_buffer_pointer(req_msgbuf);
  c->rpc_->free_msg_buffer_pointer(resp_msgbuf);
  delete(tag);
}

inline int send_req2(ClientContext &c, erpc::MsgBuffer *req_msgbuf, erpc::MsgBuffer *resp_msgbuf, size_t ws_i) {
	c.start_time[ws_i].reset();
	struct Tag *tag = new Tag();
	tag->req_msgbuf = req_msgbuf;
	tag->resp_msgbuf = resp_msgbuf;
	tag->ws_i = ws_i;
	return c.rpc_->enqueue_request(c.round_robin_get_session_num(), static_cast<size_t>(c.send_type), 
				req_msgbuf, resp_msgbuf, app_cont_func2, reinterpret_cast<void *>(tag)); 
}

void app_cont_func(void *_context, void *_ws_i) {
  auto *c = static_cast<ClientContext *>(_context);
  const auto ws_i = reinterpret_cast<size_t>(_ws_i);
  //assert(c->resp_msgbuf[ws_i].get_data_size() == FLAGS_resp_size);
  assert(c->resp_msgbuf[ws_i].buf_[0] == '0');
  c->warmup_resps++;

  if (c->warmup_resps < 100) {
      send_req(*c, ws_i);  // Clock the used window slot
  }
}

// Connect this client thread to all server threads
void create_sessions(ClientContext &c) {
  struct timespec startT, endT;
  clock_gettime(CLOCK_MONOTONIC, &startT);

  std::string server_uri = erpc::get_uri_for_process(0);
  if (FLAGS_sm_verbose == 1) {
    printf("Process %zu: Creating %zu sessions to %s.\n", FLAGS_process_id,
           FLAGS_num_server_threads, server_uri.c_str());
  }
  for (size_t i = 0; i < FLAGS_num_server_threads; i++) {
    int session_num = c.rpc_->create_session(server_uri, i);
    erpc::rt_assert(session_num >= 0, "Failed to create session");
    c.session_num_vec_.push_back(session_num);
  }

  while (c.num_sm_resps_ != FLAGS_num_server_threads) {
    c.rpc_->run_event_loop(kAppEvLoopMs);
    clock_gettime(CLOCK_MONOTONIC, &endT);
    int64_t delta_ms = (endT.tv_sec - startT.tv_sec) * 1000 + (endT.tv_nsec - startT.tv_nsec) / 1000000;
    if (delta_ms >= 10000) {
      printf("failed to connect to the server\n");
      exit(1);
    }

    if (unlikely(ctrl_c_pressed == 1)) return;
  }
}

void close_sessions(ClientContext &c) {
  auto it = c.session_num_vec_.begin();
  for(; it != c.session_num_vec_.end(); it++) {
    c.rpc_->destroy_session(*it);
  }
}

void client_loop_fun(erpc::Rpc<erpc::CTransport> *rpc) {
	while(ctrl_c_pressed != 1) {
		rpc->run_event_loop(kAppEvLoopMs); 
	}

}

void warm_up(ClientContext &c, double freq_ghz) {
        for (size_t i = 0; i < FLAGS_window_size; i++) {
    	    c.req_msgbuf[i] = c.rpc_->alloc_msg_buffer_or_die(FLAGS_req_size);
            c.resp_msgbuf[i] = c.rpc_->alloc_msg_buffer_or_die(FLAGS_resp_size);
            sprintf(reinterpret_cast<char *>(c.req_msgbuf[i].buf_), "%u", 1);
        }

	size_t count = 100;
        while (ctrl_c_pressed != 1 && c.warmup_resps < count) {	
		send_req(c, 0);
		double ms = (1.0/50) * 1000;
		size_t cycles = erpc::ms_to_cycles(ms, freq_ghz);
		uint64_t begin, end;
		begin = erpc::rdtsc();
        	end = begin;

		while((end - begin < cycles) && ctrl_c_pressed != 1) {
                	c.rpc_->run_event_loop_once();
                	end = erpc::rdtsc();
        	}
	}
}


void client_func(erpc::Nexus *nexus, size_t thread_id) {

  std::vector<size_t> port_vec = flags_get_numa_ports(FLAGS_numa_node);
  uint8_t phy_port = port_vec.at(0);
  double freq_ghz = erpc::measure_rdtsc_freq();
  uint32_t max_log_normal_value = 0; 
  uint32_t min_log_normal_value = 0xFFFFFFFF; 

  ClientContext c;
  erpc::Rpc<erpc::CTransport> rpc(nexus, static_cast<void *>(&c), thread_id,
                                  basic_sm_handler, phy_port);

  rpc.retry_connect_on_invalid_rpc_id_ = true;
  c.rpc_ = &rpc;
  c.thread_id = thread_id;
  c.request_type = req_type_array[thread_id];
  c.grouped_type = grouped_type_array[c.request_type];
  c.send_type = FLAGS_is_darc ? c.grouped_type : c.request_type;
  c.request_parameter = req_parameter_array[c.request_type]; 

  create_sessions(c);

  printf("Process %zu, thread %zu: Connected. Starting work.\n",
         FLAGS_process_id, thread_id);
  if (thread_id == 0) {
    printf("thread_id: median_us 5th_us 99th_us 999th_us Mops\n");
  }

  warm_up(c, freq_ghz);
  warmup_completes.fetch_add(1);

  while (warmup_completes.load() < rps_array.size()) {}

  /* set seed for this thread */
  std::mt19937 generator(thread_id);
  std::lognormal_distribution<double> distribution(-0.38,2.36);
  
  uint32_t success_sent = 0;
  uint32_t tmp_counter = 0;
  uint64_t max_requests = (FLAGS_test_ms/1000) * static_cast<uint64_t>(rps_array[thread_id]);
  c.start_time = new erpc::ChronoTimer[max_requests];
  c.latency_array = static_cast<double*> (malloc(max_requests * sizeof(double)));
  memset(c.latency_array, 0, max_requests * sizeof(double));
  c.pure_cpu_time = static_cast<int*> (malloc(max_requests * sizeof(int)));
  memset(c.pure_cpu_time, 0, max_requests * sizeof(int));
  c.parameters = static_cast<uint32_t*> (malloc(max_requests * sizeof(uint32_t)));
  memset(c.parameters, 0, max_requests * sizeof(uint32_t));

  struct timespec startT, endT, endT2;
  clock_gettime(CLOCK_MONOTONIC, &startT); 
  while (tmp_counter != max_requests && ctrl_c_pressed != 1) {
	erpc::MsgBuffer *req_msgbuf = rpc.alloc_msg_buffer_pointer_or_die(FLAGS_req_size);
  	erpc::MsgBuffer *resp_msgbuf = rpc.alloc_msg_buffer_pointer_or_die(FLAGS_resp_size);

	sprintf(reinterpret_cast<char *>(req_msgbuf->buf_), "%u", c.request_parameter);
	int ret = send_req2(c, req_msgbuf, resp_msgbuf, tmp_counter);
	if (ret == 0) {
		success_sent++;
	} else {
		dropped[thread_id]++;
	}
 	//sleep expanantional time
	double ms = ran_expo2(generator, rps_array[thread_id]) * 1000;
	size_t cycles = erpc::ms_to_cycles(ms, freq_ghz);
	uint64_t begin, end;
	begin = erpc::rdtsc();
	end = begin;
	while((end - begin < cycles) && ctrl_c_pressed != 1) {
		rpc.run_event_loop_once();
        	end = erpc::rdtsc();
        }	
	tmp_counter++;
  }
  clock_gettime(CLOCK_MONOTONIC, &endT);
  //wait for server sending back all responses
  while(c.num_resps != max_requests && ctrl_c_pressed != 1) {
  	rpc.run_event_loop_once();
	struct timespec end;
	clock_gettime(CLOCK_MONOTONIC, &end);
	int64_t delta_ms = (end.tv_sec - endT.tv_sec) * 1000 + (end.tv_nsec - endT.tv_nsec) / 1000000;
	if (delta_ms >= 20000) {
		break;
	}
  }
  clock_gettime(CLOCK_MONOTONIC, &endT2);

  int64_t delta_ms = (endT.tv_sec - startT.tv_sec) * 1000 + (endT.tv_nsec - startT.tv_nsec) / 1000000; 
  int64_t delta_s = delta_ms / 1000;
  int rps = success_sent / delta_s;
  sending_rps[thread_id] = rps;
  responses[thread_id] = c.num_resps;
  requests[thread_id] = success_sent;

  //TODO: Fix bug, multi-threading access the shared unordered_map 
  if (seperate_sending_rps.count(req_type_array[thread_id]) > 0) {
        seperate_sending_rps[c.request_type] += rps;
  } else {
  	seperate_sending_rps[c.request_type] = rps;
  }

  delta_ms = (c.last_response_ts.tv_sec - startT.tv_sec) * 1000 + (c.last_response_ts.tv_nsec - startT.tv_nsec) / 1000000;
  delta_s = delta_ms / 1000;
  int s_rps = static_cast<int>(c.num_resps) / delta_s;
  service_rps[thread_id] = s_rps;

  if (seperate_service_rps.count(req_type_array[thread_id]) > 0) {
        seperate_service_rps[req_type_array[thread_id]] += s_rps;
  } else {
        seperate_service_rps[req_type_array[thread_id]] = s_rps;
  }

  printf("sending requests %u get responses is %zu sending rps %d service rps %d\n", tmp_counter, c.num_resps, rps, s_rps);
  printf("max exp number %u min exp number %u\n", max_log_normal_value, min_log_normal_value);
  for (size_t i = 0; i < max_requests; i++) {
  	fprintf(perf_log, "%zu %d %f %d %u\n", thread_id, c.request_type, c.latency_array[i], c.pure_cpu_time[i], c.request_parameter);
  }
  close_sessions(c);
}

void parse_string(std::string rps, std::vector<int>& result) {
    
	std::stringstream ss(rps);
    	while (ss.good()) {
        	std::string substr;
        	getline(ss, substr, ',');
        	result.push_back(stoi(substr));
    	}
}
static inline void
perf_log_init()
{
        char *perf_log_path = getenv("CLIENT_PERF_LOG");
        if (perf_log_path != NULL) {
                printf("Client Performance Log %s\n", perf_log_path);
                perf_log = fopen(perf_log_path, "w");
                if (perf_log == NULL) perror("perf_log_init\n");
		fprintf(perf_log, "thread id, type id, latency, pure-cpu-time, exp-num\n");
        }
}

int main(int argc, char **argv) {
  signal(SIGINT, ctrl_c_handler);
  perf_log_init();

  gflags::ParseCommandLineFlags(&argc, &argv, true);

  parse_string(FLAGS_rps, rps_array);
  for(long unsigned int i = 0; i < rps_array.size();i++){ 
	printf("%d ", rps_array[i]);
  }  

  parse_string(FLAGS_req_type, req_type_array);
  parse_string(FLAGS_warmup_rps, warmup_rps);

  erpc::rt_assert(FLAGS_numa_node <= 1, "Invalid NUMA node");
  erpc::rt_assert(FLAGS_resp_size <= erpc::CTransport::kMTU, "Resp too large");
  erpc::rt_assert(FLAGS_window_size <= kAppMaxWindowSize, "Window too large");

  erpc::Nexus nexus(erpc::get_uri_for_process(FLAGS_process_id),
                    FLAGS_numa_node, 0);

  kAppReqType = FLAGS_process_id;
  nexus.register_req_func(kAppReqType, req_handler);

  size_t num_threads = rps_array.size(); 
  std::vector<std::thread> threads(num_threads);

  for (size_t i = 0; i < num_threads; i++) {
    threads[i] = std::thread(client_func, &nexus, i);
    erpc::bind_to_core(threads[i], FLAGS_numa_node, i);
  }
  for (size_t i = 0; i < num_threads; i++) threads[i].join();
  int sending_rate = 0;
  int service_rate = 0;
  size_t total_responses = 0;
  for (size_t i = 0; i < num_threads; i++) {
  	sending_rate += sending_rps[i];
  }

  for (size_t i = 0; i < num_threads; i++) {
  	service_rate += service_rps[i];
  }

  for (size_t i = 0; i < num_threads; i++) {
  	total_responses += responses[i];
  }

  uint32_t total_requests = 0;
  for (size_t i = 0; i < num_threads; i++) {
  	total_requests += requests[i];
  }

  uint32_t total_dropped = 0;
  for (size_t i = 0; i < num_threads; i++) {
       total_dropped += dropped[i];
  }

  printf("total sending rate %d, service rate %d total sent out requests %u total received response %zu dropped %u\n", 
	  sending_rate, service_rate, total_requests, total_responses, total_dropped);
  fprintf(perf_log, "total sending rate %d, service rate %d total sent out requests %u total received response %zu dropped %u\n",
          sending_rate, service_rate, total_requests, total_responses, total_dropped); 
  for (const auto& pair : seperate_sending_rps) {
        printf("type %d sending rate %d service rate %d\n", pair.first, 
		pair.second, seperate_service_rps[pair.first]); 
        fprintf(perf_log, "type %d sending rate %d service rate %d\n", pair.first, 
		pair.second, seperate_service_rps[pair.first]); 
  }
  fclose(perf_log);
}
