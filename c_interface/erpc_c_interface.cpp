#include <unordered_map>

#include "erpc_c_interface.h"
#include "rpc.h"


typedef void (*sm_handler_t)(int, erpc::SmEventType, erpc::SmErrType, void *);
class ErpcStore
{
public:
	ErpcStore(char* local_uri,size_t numa_node, size_t num_bg_threads) 
	{
		nexus_ = new erpc::Nexus(local_uri, numa_node, num_bg_threads);
	}
	~ErpcStore() {
		//TODO: release all rpc pointer in rpc_table_
	}	
public:
	erpc::Nexus *nexus_;
	std::unordered_map<uint8_t, erpc::Rpc<erpc::CTransport>*> rpc_table_;
};

static ErpcStore *erpc_store = NULL;

extern "C" {

	int erpc_init(char* local_uri,size_t numa_node, size_t num_bg_threads) {
		if (!erpc_store) {
            erpc_store = new ErpcStore(local_uri, numa_node, num_bg_threads);
        }


		printf("erpc_msgbuffer size is %ld MsgBuffer size is %ld\n", sizeof(erpc_msgbuffer), sizeof(erpc::MsgBuffer));
		return 0;
	}
	/*
	 * Called after erpc_register_req_func()
	 */
	int erpc_start(void *context, uint8_t rpc_id, sm_handler_c sm_handler, uint8_t phy_port) {
		assert(erpc_store != NULL);
		sm_handler_t sh = reinterpret_cast<void(*)(int, erpc::SmEventType, erpc::SmErrType, void *)>(sm_handler);
		erpc::Rpc<erpc::CTransport> *rpc = new erpc::Rpc<erpc::CTransport> (erpc_store->nexus_, context, rpc_id, sh, phy_port);
		erpc_store->rpc_table_[rpc_id] = rpc;
		return 0;
	}
	/*
	 * Called after erpc_start()
	 */
	int erpc_create_session(uint8_t rpc_id, char* remote_uri, uint8_t rem_rpc_id) {
		assert(erpc_store != NULL);
		erpc::Rpc<erpc::CTransport> *rpc = erpc_store->rpc_table_[rpc_id];
        assert(rpc != NULL);

		return rpc->create_session(remote_uri, rem_rpc_id);
	}
	/*
	 * Called after erpc_create_session
	 */
	int erpc_enqueue_request(uint8_t rpc_id, int session_num, size_t reqsize, uint8_t reqtype, size_t respsize,
                             erpc_cont_func_t cont_func, void *tag, size_t cont_etid, uint8_t *input, 
			                 struct erpc_msgbuffer *req, struct erpc_msgbuffer *resp) {
		assert(erpc_store != NULL);
		erpc::Rpc<erpc::CTransport> *rpc = erpc_store->rpc_table_[rpc_id];
		assert(rpc != NULL);	
		erpc::MsgBuffer *req_local = reinterpret_cast<erpc::MsgBuffer*>(req);
		*req_local = rpc->alloc_msg_buffer_or_die(reqsize);

		erpc::MsgBuffer *resp_local = reinterpret_cast<erpc::MsgBuffer*>(resp);
		*resp_local = rpc->alloc_msg_buffer_or_die(respsize);
		sprintf(reinterpret_cast<char *>(req_local->buf_), "%s", input);

		rpc->enqueue_request(session_num, reqtype, req_local, resp_local, cont_func, tag, cont_etid);
		return 0;
	}
	int erpc_run_event_loop(uint8_t rpc_id, size_t timeout_ms) {
		assert(erpc_store != NULL);
		erpc::Rpc<erpc::CTransport> *rpc = erpc_store->rpc_table_[rpc_id];
        assert(rpc != NULL);

		rpc->run_event_loop(timeout_ms);
		return 0;
	}
	void erpc_run_event_loop_once(uint8_t rpc_id) {
		assert(erpc_store != NULL);
		erpc::Rpc<erpc::CTransport> *rpc = erpc_store->rpc_table_[rpc_id];
        assert(rpc != NULL);

		rpc->run_event_loop_once();
	}
	bool erpc_session_is_connected(uint8_t rpc_id, int session_num) {
		assert(erpc_store != NULL);
		erpc::Rpc<erpc::CTransport> *rpc = erpc_store->rpc_table_[rpc_id];
        assert(rpc != NULL);

		return rpc->is_connected(session_num);
	}
	int erpc_register_req_func(uint8_t req_type, erpc_req_func_c req_func, int req_func_type) {
		erpc::erpc_req_func_t rf = reinterpret_cast<erpc::erpc_req_func_t> (req_func);
		return erpc_store->nexus_->register_req_func(req_type, rf, static_cast<erpc::ReqFuncType>(req_func_type)); 
	}

	int erpc_req_response_enqueue(uint8_t rpc_id, void *req_handle, char* content, size_t data_size, uint8_t response_code) {
		assert(erpc_store != NULL);
        erpc::Rpc<erpc::CTransport> *rpc = erpc_store->rpc_table_[rpc_id];
        assert(rpc != NULL);

		erpc::ReqHandle * rh = reinterpret_cast<erpc::ReqHandle*> (req_handle);
		auto &resp = rh->pre_resp_msgbuf_;
		rpc->resize_msg_buffer(&resp, data_size + 2); // one for response_code, the other is white space 
		sprintf(reinterpret_cast<char *>(resp.buf_), "%hhu", response_code);
		sprintf(reinterpret_cast<char *>(resp.buf_ + 1), "%s", " ");
		if (content != NULL) {
			sprintf(reinterpret_cast<char *>(resp.buf_ + 2), "%s", content);
		}
		rpc->enqueue_response(rh, &resp);
		return 0;
	}

}
