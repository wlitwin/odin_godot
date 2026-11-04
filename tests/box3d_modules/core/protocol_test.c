/* Independent C compiler layout/fingerprint reference for the public host ABI.
 */
#include "protocol.h"
#include <stddef.h>
#include <stdio.h>
#define O(t, f) offsetof(t, f)
int main(void) {
  const uint64_t values[] = {OGB3_SDK_HOST_VERSION,
                             sizeof(ogb3_sdk_domain),
                             _Alignof(ogb3_sdk_domain),
                             O(ogb3_sdk_domain, build),
                             O(ogb3_sdk_domain, target),
                             sizeof(ogb3_sdk_owner),
                             _Alignof(ogb3_sdk_owner),
                             O(ogb3_sdk_owner, realm),
                             O(ogb3_sdk_owner, context_caps),
                             O(ogb3_sdk_owner, check),
                             O(ogb3_sdk_owner, retain),
                             O(ogb3_sdk_owner, drop),
                             sizeof(ogb3_sdk_data_lease),
                             O(ogb3_sdk_data_lease, retain),
                             O(ogb3_sdk_data_lease, drop),
                             sizeof(ogb3_sdk_request_totals),
                             sizeof(ogb3_sdk_capsule),
                             O(ogb3_sdk_capsule, realm),
                             O(ogb3_sdk_capsule, invoke),
                             O(ogb3_sdk_capsule, destroy),
                             sizeof(ogb3_sdk_capsule_clone_args),
                             sizeof(ogb3_sdk_service),
                             _Alignof(ogb3_sdk_service),
                             O(ogb3_sdk_service, realm),
                             O(ogb3_sdk_service, domain),
                             O(ogb3_sdk_service, user),
                             O(ogb3_sdk_service, domain_check),
                             O(ogb3_sdk_service, owner_create),
                             O(ogb3_sdk_service, account),
                             O(ogb3_sdk_service, request_totals),
                             O(ogb3_sdk_service, budget_begin),
                             O(ogb3_sdk_service, budget_reconcile),
                             O(ogb3_sdk_service, budget_end),
                             O(ogb3_sdk_service, legacy_extra),
                             O(ogb3_sdk_service, capsule_create)};
  uint64_t h = UINT64_C(14695981039346656037);
  for (size_t i = 0; i < sizeof values / sizeof *values; i++) {
    uint64_t v = values[i];
    for (unsigned j = 0; j < 8; j++) {
      h = (h ^ (v & 255)) * UINT64_C(1099511628211);
      v >>= 8;
    }
  }
  printf("{\"fingerprint\":%llu,\"owner_size\":%zu,\"service_size\":%zu,"
         "\"domain_size\":%zu}\n",
         (unsigned long long)h, sizeof(ogb3_sdk_owner),
         sizeof(ogb3_sdk_service), sizeof(ogb3_sdk_domain));
}
