#ifndef ODIN_MANAGED_CALLABLE_PROTOCOL_H
#define ODIN_MANAGED_CALLABLE_PROTOCOL_H
#include <stdint.h>
#include "../../../box3d/godot/protocol.h"
/* SDK Godot Callable wrapper reserves four uintptr words. Only the normal
 * Godot API touches its native representation; runtime/core fingerprint it. */
typedef struct {uintptr_t opaque[4];} odin_managed_callable_value;
typedef struct {odin_managed_callable_value value;uint64_t token;} odin_managed_callable;
typedef struct {int32_t error,argument,expected;} odin_managed_call_error;
typedef struct {void **variants;int32_t count;uint32_t reserved;void *result;odin_managed_call_error *error;} odin_managed_callable_args;
typedef struct {uint64_t live_records,open_records,pending_records,inflight_calls,storage_bytes,calls,rejected_calls,declined_drops;} odin_managed_callable_stats;
typedef struct {
 uint32_t size,version;
 uint64_t fingerprint;
 int32_t (*create)(ogb3_sdk_capsule *,uint32_t,odin_managed_callable *);
 int32_t (*close)(odin_managed_callable *);
 int32_t (*collect)(void);
 int32_t (*stats)(odin_managed_callable_stats *);
} odin_managed_callable_api;
/* i32 status: Host/native values0..7 plus optional Runtime BUSY8. */
#define ODIN_MANAGED_CALLABLE_BUSY 8
#define ODIN_MANAGED_CALLABLE_VERSION 1
#endif
