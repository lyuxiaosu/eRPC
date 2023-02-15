#include "common.h"
#include "nexus.h"
#include "rpc_types.h"
#include "session.h"
#include "util/mt_queue.h"
#include "req_handle.h"

namespace erpc {

void Nexus::bg_thread_func(BgThreadCtx ctx) {
  ctx.tls_registry_->init();  // Initialize thread-local variables

  // The BgWorkItem request list can be indexed using the background thread's
  // index in the Nexus, or its eRPC TID.
  assert(ctx.bg_thread_index_ == ctx.tls_registry_->get_etid());
  ERPC_INFO("eRPC Nexus: Background thread %zu running. Tiny TID = %zu.\n",
            ctx.bg_thread_index_, ctx.tls_registry_->get_etid());

  while (*ctx.kill_switch_ == false) {
    if (ctx.bg_req_queue_->size_ == 0) {
      // TODO: Put bg thread to sleep if it's idle for a long time
      continue;
    }

    while (ctx.bg_req_queue_->size_ > 0) {
      BgWorkItem wi = ctx.bg_req_queue_->unlocked_pop();

      if (wi.is_req()) {
        SSlot *s = wi.sslot_;  // For requests, we have a valid sslot
        uint8_t req_type = s->server_info_.req_type_;
        const ReqFunc &req_func = ctx.req_func_arr_->at(req_type);
#ifdef SLEDGE
	uint8_t *msg = s->server_info_.req_msgbuf_.buf_;
	uint8_t msg_size = s->server_info_.req_msgbuf_.get_data_size();
	uint16_t src_port = s->get_session()->get_src_port();
	req_func.req_func_(static_cast<ReqHandle *>(s), req_type, msg, msg_size, src_port);
#else
        req_func.req_func_(static_cast<ReqHandle *>(s), wi.context_);
#endif
      } else {
        // For responses, we don't have a valid sslot
        wi.cont_func_(wi.context_, wi.tag_);
      }
    }
  }

  ERPC_INFO("eRPC Nexus: Background thread %zu exiting.\n",
            ctx.bg_thread_index_);
  return;
}

}  // namespace erpc
