#ifndef __ERPC_C_INTERFACE_H__
#define __ERPC_C_INTERFACE_H__

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

struct erpc_buffer {
	uint8_t *buf_;
  	size_t class_size_;  ///< The allocator's class size
  	uint32_t lkey_;  
};

struct erpc_msgbuffer {
	struct erpc_buffer buffer_;

  	// Size info
  	size_t max_data_size_;  ///< Max data bytes in the MsgBuffer
  	size_t data_size_;      ///< Current data bytes in the MsgBuffer
  	size_t max_num_pkts_;   ///< Max number of packets in this MsgBuffer
  	size_t num_pkts_;    
        uint8_t *buf_;	/// Pointer to the first application data byte. The message buffer is invalid
  			/// invalid if this is null.
};


/*
 * The session management handler when the client receives a response for a seesion's request
 */
typedef void (*sm_handler_c)(int, int sm_event_type, int sm_err_type , void *);
/*
 * The rpc response handler when the client receives a response for a rpc request
 */
typedef void (*erpc_cont_func_t)(void *context, void *tag);

/*
 * rpc handler that will be called on the server side
 */
#ifdef SLEDGE
typedef void (*erpc_req_func_c)(void *req_handle, uint8_t req_type, uint8_t *msg, size_t size, uint16_t port);
#else
typedef void (*erpc_req_func_c)(void *req_handle, void *context);
#endif

int erpc_init(char* local_uri,size_t numa_node, size_t num_bg_threads);
int erpc_start(void *context, uint8_t rpc_id, sm_handler_c sm_handler, uint8_t phy_port);
int erpc_create_session(uint8_t rpc_id, char* remote_uri, uint8_t rem_rpc_id);

int erpc_enqueue_request(uint8_t rpc_id, int session_num, size_t reqsize, uint8_t reqtype, size_t respsize, 
		         erpc_cont_func_t cont_func, void *tag, size_t cont_etid, uint8_t *input, erpc_msgbuffer *req, erpc_msgbuffer *resp);

int erpc_run_event_loop(uint8_t rpc_id, size_t timeout_ms);
void erpc_run_event_loop_once(uint8_t rpc_id);
bool erpc_session_is_connected(uint8_t rpc_id, int session_num);

int erpc_register_req_func(uint8_t req_type, erpc_req_func_c req_func, int req_func_type);

int erpc_req_response_enqueue(uint8_t rpc_id, void *req_handle, char* content, size_t data_size, uint8_t response_code);

//unsigned char* erpc_get_req_response_content();
#ifdef __cplusplus
}
#endif

#endif
