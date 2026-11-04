/* Two separately loaded producers intentionally share the native DSO. A third
 * links a forbidden static copy solely to prove domain rejection. */
#include "api.h"
OGB3_API ogb3_status producer_contract(ogb3_domain_contract *out) {
  return ogb3_domain_contract_get(out);
}
OGB3_API ogb3_status producer_open(uint64_t cookie, uint64_t producer,
                                   uint64_t component, ogb3_host_owner *out) {
  return ogb3_host_owner_open(cookie, producer, component, out);
}
OGB3_API ogb3_status producer_set(uint64_t cookie, ogb3_host_owner owner,
                                  uint64_t live, uint64_t reserved) {
  return ogb3_host_owner_set(cookie, owner, live, reserved);
}
OGB3_API ogb3_status producer_close(uint64_t cookie, ogb3_host_owner owner) {
  return ogb3_host_owner_close(cookie, owner);
}
OGB3_API ogb3_status producer_stats(uint64_t cookie,
                                    ogb3_host_ledger_stats *out) {
  return ogb3_host_ledger_get(cookie, out);
}
OGB3_API ogb3_status producer_check(const ogb3_domain_contract *expected) {
  return ogb3_domain_contract_check(expected);
}
