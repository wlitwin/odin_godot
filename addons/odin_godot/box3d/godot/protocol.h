#ifndef OGB3_SDK_HOST_PROTOCOL_H
#define OGB3_SDK_HOST_PROTOCOL_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#define OGB3_SDK_HOST_VERSION 1u
#define OGB3_SDK_READ 0u
#define OGB3_SDK_EXECUTE 1u
#define OGB3_SDK_MANAGED_DATA 1u
#define OGB3_SDK_WEAK_INSTANCE 2u
#define OGB3_SDK_INDEPENDENT_CONTEXT 4u
#define OGB3_SDK_CAPSULE_DESTROY 0u
#define OGB3_SDK_CAPSULE_CLONE 1u
typedef int32_t ogb3_sdk_status;
typedef struct {
  uint64_t cookie;
  uint32_t size, version, abi_version, logical_version, resource_version,
      recovery_version, pointer_bits, endian;
  uint8_t build[32], target[32];
} ogb3_sdk_domain;
typedef struct {
  void *user;
  uint64_t realm;
  uint32_t context_caps, reserved;
  ogb3_sdk_status (*check)(void *, uint32_t);
  ogb3_sdk_status (*retain)(void *);
  ogb3_sdk_status (*drop)(void *);
} ogb3_sdk_owner;
typedef struct {
  void *user;
  ogb3_sdk_status (*retain)(void *);
  ogb3_sdk_status (*drop)(void *);
} ogb3_sdk_data_lease;
typedef struct {
  uint64_t native, wrapper, host, total;
} ogb3_sdk_request_totals;
typedef ogb3_sdk_status (*ogb3_sdk_capsule_dispatch)(void *, uint32_t, void *);
typedef struct {
  void *user;
  uint64_t realm;
  ogb3_sdk_status (*invoke)(void *, uint32_t, void *);
  ogb3_sdk_status (*destroy)(void *);
} ogb3_sdk_capsule;
typedef struct {
  ogb3_sdk_capsule *out;
} ogb3_sdk_capsule_clone_args;
typedef struct {
  uint32_t size, version;
  uint64_t realm;
  ogb3_sdk_domain domain;
  void *user;
  ogb3_sdk_status (*domain_check)(void *, uint64_t);
  ogb3_sdk_status (*owner_create)(void *, uint32_t, const ogb3_sdk_data_lease *,
                                  ogb3_sdk_owner *);
  ogb3_sdk_status (*account)(void *, uint32_t, uint64_t, uint64_t);
  ogb3_sdk_status (*request_totals)(void *, ogb3_sdk_request_totals *);
  ogb3_sdk_status (*budget_begin)(void *, uint64_t, uint64_t *);
  ogb3_sdk_status (*budget_reconcile)(void *, uint64_t);
  ogb3_sdk_status (*budget_end)(void *, uint64_t);
  ogb3_sdk_status (*legacy_extra)(void *, uint64_t, uint64_t, uint64_t,
                                  uint64_t *);
  ogb3_sdk_status (*capsule_create)(void *, const ogb3_sdk_owner *, void *,
                                    ogb3_sdk_capsule_dispatch,
                                    ogb3_sdk_capsule *);
} ogb3_sdk_service;
/* Pure preboot metadata; profile0 has no native dependency or host requirement.
 */
uint32_t odin_scripts_box3d_profile(void);
uint64_t odin_scripts_box3d_protocol(void);
ogb3_sdk_status odin_scripts_box3d_contract(ogb3_sdk_domain *);
ogb3_sdk_status odin_scripts_box3d_install(const ogb3_sdk_service *);
#ifdef __cplusplus
}
#endif
#endif
