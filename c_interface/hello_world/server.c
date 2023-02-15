#include "common.h"

// req_handle is the object that caller create and fill in data
uint8_t rpc_id = 0;
//void (req_func)(void *req_handle, void *context) {
//	erpc_req_response_enqueue(rpc_id, req_handle, "hello world", kMsgSize);
//}
void req_func (void *req_handle, uint8_t req_type, uint8_t *msg, size_t size, uint16_t port) {
	printf("req_type is %d, msg %s size %zu port %d\n", req_type, msg, size, port);
	erpc_req_response_enqueue(rpc_id, req_handle, "hello world", kMsgSize, 1);
}

int main() {
  char *server_uri = append(kServerHostname, ":");
  server_uri = append(server_uri, kUDPPort);

  erpc_init(server_uri, 0, 0);

  erpc_register_req_func(kReqType, req_func, 0);
  erpc_start(NULL, rpc_id, NULL, 0); 

  erpc_run_event_loop(rpc_id, 100000);
}
