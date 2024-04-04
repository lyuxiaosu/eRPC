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

FILE *perf_log = NULL;
static constexpr size_t kAppEvLoopMs = 1000;     // Duration of event loop
static constexpr bool kAppVerbose = false;       // Print debug info on datapath
static constexpr double kAppLatFac = 10.0;       // Precision factor for latency
static size_t kAppReqType = 1;         // eRPC request type
static constexpr size_t kAppMaxWindowSize = 32;  // Max pending reqs per client

int sending_rps[100]; // each client thread sending rps
size_t responses[100]; // each client thread get the number of responses
uint32_t requests[100]; // each client thread sends out the number of requests
uint32_t dropped[100] = {0};

std::unordered_map<int, int> seperate_sending_rps; // key is request type, value is the sending rps
std::unordered_map<int, int> seperate_service_rps; 

std::vector<int> req_type_array;
std::vector<int> warmup_rps;
std::vector<int> req_parameter_array;

DEFINE_uint64(num_server_threads, 1, "Number of threads at the server machine");
DEFINE_uint64(num_client_threads, 1, "Number of threads per client machine");
DEFINE_uint64(warmup_count, 100, "Number of packets to send during the warmup phase");
DEFINE_string(req_type, "1", "Request type for each thread to send");
DEFINE_string(req_parameter, "15", "Request parameters of each type request");
DEFINE_string(warmup_rps, "200", "Number of requests per second during the warmup phase");
DEFINE_uint64(window_size, 1, "Outstanding requests per client");
DEFINE_uint64(req_size, 64, "Size of request message in bytes");
DEFINE_uint64(resp_size, 32, "Size of response message in bytes ");

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
  size_t num_reqs = 0;
  size_t thread_id;
  erpc::ChronoTimer start_time;
  std::vector<double> latency_array;
  std::vector<int> pure_cpu_time;
  struct timespec last_response_ts;
  erpc::Latency latency;
  erpc::MsgBuffer req_msgbuf[kAppMaxWindowSize], resp_msgbuf[kAppMaxWindowSize];
  ~ClientContext() {
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
  c.start_time.reset();
  c.rpc_->enqueue_request(c.round_robin_get_session_num(), static_cast<size_t>(req_type_array[c.thread_id]),
                         &c.req_msgbuf[ws_i], &c.resp_msgbuf[ws_i],
                         app_cont_func, reinterpret_cast<void *>(ws_i));
  c.num_reqs++;
}

void app_cont_func2(void *_context, void *_tag) {
  auto *c = static_cast<ClientContext *>(_context);
  auto *tag = reinterpret_cast<Tag *>(_tag);
  erpc::MsgBuffer *req_msgbuf = tag->req_msgbuf;
  erpc::MsgBuffer *resp_msgbuf = tag->resp_msgbuf;
  //assert(c->resp_msgbuf[ws_i].get_data_size() == FLAGS_resp_size);
  assert(resp_msgbuf->buf_[0] == '0');
  const double req_lat_us = c->start_time.get_us();
  c->latency_array.push_back(req_lat_us);
  c->pure_cpu_time.push_back(atoi(reinterpret_cast<const char*>(&(resp_msgbuf->buf_[2]))));
  //printf("%s\n", resp_msgbuf->buf_);
  //printf("%f\n", req_lat_us);
  c->num_resps++;
  clock_gettime(CLOCK_MONOTONIC, &(c->last_response_ts));
  c->rpc_->free_msg_buffer_pointer(req_msgbuf);
  c->rpc_->free_msg_buffer_pointer(resp_msgbuf);
  delete(tag);
}

inline int send_req2(ClientContext &c, erpc::MsgBuffer *req_msgbuf, erpc::MsgBuffer *resp_msgbuf, size_t thread_id, size_t ws_i) {
	c.start_time.reset();
	struct Tag *tag = new Tag();
	tag->req_msgbuf = req_msgbuf;
	tag->resp_msgbuf = resp_msgbuf;
	tag->ws_i = ws_i;
	return c.rpc_->enqueue_request(c.round_robin_get_session_num(), static_cast<size_t>(req_type_array[thread_id]), 
				req_msgbuf, resp_msgbuf, app_cont_func2, reinterpret_cast<void *>(tag)); 
}

void app_cont_func(void *_context, void *_ws_i) {
  auto *c = static_cast<ClientContext *>(_context);
  const double req_lat_us = c->start_time.get_us();
  const auto ws_i = reinterpret_cast<size_t>(_ws_i);
  //assert(c->resp_msgbuf[ws_i].get_data_size() == FLAGS_resp_size);
  assert(c->resp_msgbuf[ws_i].buf_[0] == '0');
  c->latency_array.push_back(req_lat_us);
  c->pure_cpu_time.push_back(atoi(reinterpret_cast<const char*>(&(c->resp_msgbuf[ws_i].buf_[2]))));
  c->num_resps++;
  send_req(*c, ws_i);  // Clock the used window slot
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

void warm_up(ClientContext &c, size_t thread_id, double freq_ghz) {
	int rps = warmup_rps[thread_id];
	size_t count = FLAGS_warmup_count;
	size_t sent_out = 0;
        while (ctrl_c_pressed != 1 && sent_out != count) {	
		erpc::MsgBuffer *req_msgbuf = c.rpc_->alloc_msg_buffer_pointer_or_die(FLAGS_req_size);
		erpc::MsgBuffer *resp_msgbuf = c.rpc_->alloc_msg_buffer_pointer_or_die(FLAGS_resp_size);
		sprintf(reinterpret_cast<char *>(req_msgbuf->buf_), "%u", 15);
		send_req2(c, req_msgbuf, resp_msgbuf, thread_id, sent_out);
		double ms = (1.0/rps) * 1000;
		size_t cycles = erpc::ms_to_cycles(ms, freq_ghz);
		uint64_t begin, end;
		begin = erpc::rdtsc();
        	end = begin;

		while((end - begin < cycles) && ctrl_c_pressed != 1) {
                	c.rpc_->run_event_loop_once();
                	end = erpc::rdtsc();
        	}
		sent_out++;
	}
}


void client_func(erpc::Nexus *nexus, size_t thread_id) {
 
  std::vector<size_t> port_vec = flags_get_numa_ports(FLAGS_numa_node);
  uint8_t phy_port = port_vec.at(0);
  double freq_ghz = erpc::measure_rdtsc_freq(); 
  ClientContext c;
  erpc::Rpc<erpc::CTransport> rpc(nexus, static_cast<void *>(&c), thread_id,
                                  basic_sm_handler, phy_port);

  rpc.retry_connect_on_invalid_rpc_id_ = true;
  c.rpc_ = &rpc;
  c.thread_id = thread_id;

  create_sessions(c);


  printf("Process %zu, thread %zu: Connected. Starting work.\n",
         FLAGS_process_id, thread_id);
  if (thread_id == 0) {
    printf("thread_id: median_us 5th_us 99th_us 999th_us Mops\n");
  }
  
  for (size_t i = 0; i < FLAGS_window_size; i++) {
    c.req_msgbuf[i] = rpc.alloc_msg_buffer_or_die(FLAGS_req_size);
    c.resp_msgbuf[i] = rpc.alloc_msg_buffer_or_die(FLAGS_resp_size);
    sprintf(reinterpret_cast<char *>(c.req_msgbuf[i].buf_), "%u", req_parameter_array.at(static_cast<size_t>(req_type_array[thread_id] - 1)));
    send_req(c, i);
  }
 
  size_t total_cycles = erpc::ms_to_cycles(FLAGS_test_ms, freq_ghz);

  struct timespec startT, endT;
  clock_gettime(CLOCK_MONOTONIC, &startT);
  uint64_t begin, end;
  begin = erpc::rdtsc();
  end = begin;  

  while ((end - begin) < total_cycles && ctrl_c_pressed != 1) {
    //rpc.run_event_loop_once(); 
    rpc.run_event_loop(FLAGS_test_ms);
    end = erpc::rdtsc();
  }
  clock_gettime(CLOCK_MONOTONIC, &endT);

  int64_t delta_ms = (endT.tv_sec - startT.tv_sec) * 1000 + (endT.tv_nsec - startT.tv_nsec) / 1000000; 
  int64_t delta_s = delta_ms / 1000;
  int rps = static_cast<int>(c.num_resps) / delta_s;
  sending_rps[thread_id] = rps;
  responses[thread_id] = c.num_resps;
  requests[thread_id] = c.num_reqs;

  if (seperate_sending_rps.count(req_type_array[thread_id]) > 0) {
        seperate_sending_rps[req_type_array[thread_id]] += rps;
  } else {
  	seperate_sending_rps[req_type_array[thread_id]] = rps;
  }

  printf("sending requests %zu rps %d\n", c.num_resps, rps);
  for (size_t i = 0; i < c.num_resps; i++) {
  	fprintf(perf_log, "%zu %d %f %d\n", thread_id, req_type_array[thread_id], c.latency_array[i], c.pure_cpu_time[i]);
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
		fprintf(perf_log, "thread id, type id, latency, cpu time\n");
        }
}

int main(int argc, char **argv) {
  signal(SIGINT, ctrl_c_handler);
  perf_log_init();

  gflags::ParseCommandLineFlags(&argc, &argv, true);

  parse_string(FLAGS_req_type, req_type_array);
  parse_string(FLAGS_warmup_rps, warmup_rps);
  parse_string(FLAGS_req_parameter, req_parameter_array);

  erpc::rt_assert(FLAGS_numa_node <= 1, "Invalid NUMA node");
  erpc::rt_assert(FLAGS_resp_size <= erpc::CTransport::kMTU, "Resp too large");
  erpc::rt_assert(FLAGS_window_size <= kAppMaxWindowSize, "Window too large");

  erpc::Nexus nexus(erpc::get_uri_for_process(FLAGS_process_id),
                    FLAGS_numa_node, 0);

  kAppReqType = FLAGS_process_id;
  nexus.register_req_func(kAppReqType, req_handler);

  size_t num_threads = req_type_array.size(); 
  std::vector<std::thread> threads(num_threads);

  for (size_t i = 0; i < num_threads; i++) {
    threads[i] = std::thread(client_func, &nexus, i);
    erpc::bind_to_core(threads[i], FLAGS_numa_node, i);
  }
  for (size_t i = 0; i < num_threads; i++) threads[i].join();
  int sending_rate = 0;
  for (size_t i = 0; i < num_threads; i++) {
  	sending_rate += sending_rps[i];
  }

  uint32_t total_responses = 0;
  for (size_t i = 0; i < num_threads; i++) {
  	total_responses += responses[i];
  }

  uint32_t total_requests = 0;
  for (size_t i = 0; i < num_threads; i++) {
  	total_requests += requests[i];
  }

  printf("total sending rate %d, total sent out requests %u total response %u\n", 
	  sending_rate, total_requests, total_responses);
  fprintf(perf_log, "total sending rate %d, total sent out requests %u\n",
          sending_rate, total_requests); 
  for (const auto& pair : seperate_sending_rps) {
        printf("type %d sending rate %d service rate %d\n", pair.first, 
		pair.second, seperate_service_rps[pair.first]); 
        fprintf(perf_log, "type %d sending rate %d service rate %d\n", pair.first, 
		pair.second, seperate_service_rps[pair.first]); 
  
  }
  fclose(perf_log);
}
