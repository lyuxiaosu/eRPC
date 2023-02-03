#include "erpc_c_interface.h"
#include "rpc.h"


typedef void (*sm_handler_t)(int, erpc::SmEventType, erpc::SmErrType, void *);
class ErpcStore
{
public:
	ErpcStore(char* local_uri, void *context, uint8_t rpc_id, sm_handler_c sm_handler, 
		  uint8_t phy_port, size_t numa_node, size_t num_bg_threads): nexus_(local_uri, numa_node, num_bg_threads) 
	{
		sm_handler_t sh = reinterpret_cast<void(*)(int, erpc::SmEventType, erpc::SmErrType, void *)>(sm_handler);
		rpc_ = new erpc::Rpc<erpc::CTransport> (&nexus_, context, rpc_id, sh, phy_port);
	}

	~ErpcStore() {
		if (rpc_) {
			delete rpc_;
			rpc_ = NULL;
		}
	}	
public:
	erpc::Nexus nexus_;
	erpc::Rpc<erpc::CTransport> *rpc_;
};

static ErpcStore *erpc_store = NULL;

extern "C" {
	int erpc_init(char* local_uri, void *context, uint8_t rpc_id, sm_handler_c sm_handler,
		      uint8_t phy_port, size_t numa_node, size_t num_bg_threads) {
		
		if (!erpc_store) {
			erpc_store = new ErpcStore(local_uri, context, rpc_id, sm_handler, phy_port, numa_node, num_bg_threads);
		}
		return 0;
	}
	int erpc_create_session(char* remote_uri, uint8_t rem_rpc_id) {
		assert(erpc_store != NULL);
		return erpc_store->rpc_->create_session(remote_uri, rem_rpc_id);
	}
	int erpc_enqueue_request(int session_num, size_t reqsize, uint8_t reqtype, size_t respsize,
                         erpc_cont_func_t cont_func, void *tag, size_t cont_etid) {
		
		erpc::MsgBuffer req = erpc_store->rpc_->alloc_msg_buffer_or_die(reqsize);
		erpc::MsgBuffer resp = erpc_store->rpc_->alloc_msg_buffer_or_die(respsize);

		erpc_store->rpc_->enqueue_request(session_num, reqtype, &req, &resp, cont_func, tag, cont_etid);
		return 0;
	}
	int erpc_run_event_loop(size_t timeout_ms) {
		erpc_store->rpc_->run_event_loop(timeout_ms);
		return 0;
	}
	void erpc_run_event_loop_once() {
		erpc_store->rpc_->run_event_loop_once();
	}
	bool erpc_is_session_connected(int session_num) {
		return erpc_store->rpc_->is_connected(session_num);
	}
	int erpc_register_req_func(uint8_t req_type, erpc_req_func_c req_func, int req_func_type) {
		erpc::erpc_req_func_t rf = reinterpret_cast<erpc::erpc_req_func_t> (req_func);
		return erpc_store->rpc_->nexus_->register_req_func(req_type, rf, static_cast<erpc::ReqFuncType>(req_func_type)); 
	}

	int erpc_req_response_enqueue(void *req_handle, char* content, size_t data_size) {
		erpc::ReqHandle * rh = reinterpret_cast<erpc::ReqHandle*> (req_handle);
		auto &resp = rh->pre_resp_msgbuf_;
		erpc_store->rpc_->resize_msg_buffer(&resp, data_size);
		sprintf(reinterpret_cast<char *>(resp.buf_), "%s", content);
		erpc_store->rpc_->enqueue_response(rh, &resp);
		return 0;
	}
}
