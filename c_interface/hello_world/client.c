#include "common.h"

void cont_func(void *context, void *tag) { printf("I am called, response content is %s\n",erpc_get_req_response_content()); }

void sm_handler(int unknown, int SmEventType, int SmErrType, void * unknownpointer) {}

int main() {
  char *client_uri = append(kClientHostname, ":");
  client_uri = append(client_uri, kUDPPort);

  erpc_init(client_uri, 0, 0);
  erpc_start(NULL, 0, sm_handler, 0); 

  char *server_uri = append(kServerHostname, ":");
  server_uri = append(server_uri, kUDPPort);

  int session_num = erpc_create_session(server_uri, 0);

  while (!erpc_session_is_connected(session_num)) erpc_run_event_loop_once();

  erpc_enqueue_request(session_num, kMsgSize, kReqType, kMsgSize, cont_func, NULL, 8);

  erpc_run_event_loop(100);

}
