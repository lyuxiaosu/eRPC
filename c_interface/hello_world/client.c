#include "common.h"

void cont_func(void *context, void *tag) { printf("I am called, response content is %s\n",erpc_get_req_response_content()); }

void sm_handler(int unknown, int SmEventType, int SmErrType, void * unknownpointer) {}

int main() {
  char *client_uri = append(kClientHostname, ":");
  client_uri = append(client_uri, kUDPPort);

  erpc_init(client_uri, 0, 0);
  uint8_t rpc_id = 0;
  erpc_start(NULL, rpc_id, sm_handler, 0); 

  char *server_uri = append(kServerHostname, ":");
  server_uri = append(server_uri, kUDPPort);

  int session_num = erpc_create_session(rpc_id, server_uri, 0);

  while (!erpc_session_is_connected(rpc_id, session_num)) erpc_run_event_loop_once(rpc_id);

  erpc_enqueue_request(rpc_id, session_num, kMsgSize, kReqType, kMsgSize, cont_func, NULL, 8);

  erpc_run_event_loop(rpc_id, 100);

}
