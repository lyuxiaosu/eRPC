#include "common.h"

// req_handle is the object that caller create and fill in data
void (req_func)(void *req_handle, void *context) {
	erpc_req_response_enqueue(req_handle, "hello world", kMsgSize);
}

int main() {
  char *server_uri = append(kServerHostname, ":");
  server_uri = append(server_uri, kUDPPort);

  erpc_init(server_uri, NULL, 0, NULL, 0, 0, 0); 
  erpc_register_req_func(kReqType, req_func, 0); 

  erpc_run_event_loop(100000);
}
