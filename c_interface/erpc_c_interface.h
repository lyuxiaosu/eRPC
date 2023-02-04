#ifndef __ERPC_C_INTERFACE_H__
#define __ERPC_C_INTERFACE_H__

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

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
typedef void (*erpc_req_func_c)(void *req_handle, void *context);


int erpc_init(char* local_uri,size_t numa_node, size_t num_bg_threads);
int erpc_start(void *context, uint8_t rpc_id, sm_handler_c sm_handler, uint8_t phy_port);
int erpc_create_session(char* remote_uri, uint8_t rem_rpc_id);

int erpc_enqueue_request(int session_num, size_t reqsize, uint8_t reqtype, size_t respsize, 
		         erpc_cont_func_t cont_func, void *tag, size_t cont_etid);

int erpc_run_event_loop(size_t timeout_ms);
void erpc_run_event_loop_once();
bool erpc_is_session_connected(int session_num);

int erpc_register_req_func(uint8_t req_type, erpc_req_func_c req_func, int req_func_type);

int erpc_req_response_enqueue(void *req_handle, char* content, size_t data_size);
#ifdef __cplusplus
}
#endif

#endif
