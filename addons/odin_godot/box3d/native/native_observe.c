#include "native_observe_internal.h"
#if defined(OGB3_NATIVE_OBSERVATION) && OGB3_NATIVE_OBSERVATION
#include <string.h>

typedef struct ObserveControl {
  ogb3_obs_block_v1 *block;
  ogb3_obs_clock_v1 clock;
  void *user;
  uint64_t next_token, active_token;
  uint32_t in_clock;
} ObserveControl;
static ObserveControl control;

static ogb3_status domain(uint64_t cookie) {
  ogb3_domain_contract actual;
  ogb3_status status = ogb3_domain_contract_get(&actual);
  if (status) return status;
  return cookie == actual.cookie ? OGB3_OK : OGB3_INCOMPATIBLE;
}
static int reentered(void) {
  if (!control.in_clock) return 0;
  if (control.block) control.block->error_flags |= OGB3_OBS_ERROR_SCOPE_REENTRY_V1;
  return 1;
}
static int overlaps(const void *a, uint64_t na, const void *b, uint64_t nb) {
  uintptr_t x = (uintptr_t)a, y = (uintptr_t)b;
  if (na > UINTPTR_MAX - x || nb > UINTPTR_MAX - y) return 1;
  return x < y + nb && y < x + na;
}
ogb3_status ogb3_test_native_observe_abi_v1(uint64_t cookie, ogb3_obs_abi_v1 *out) {
  ogb3_status status = domain(cookie);
  if (status) return status;
  if (reentered()) return OGB3_UNSUPPORTED;
  if (!out) return OGB3_INVALID_ARGUMENT;
  *out = (ogb3_obs_abi_v1){OGB3_OBS_VERSION_V1, sizeof(ogb3_obs_span_v1),
      sizeof(ogb3_obs_config_v1), sizeof(ogb3_obs_block_v1),
      _Alignof(ogb3_obs_span_v1), _Alignof(ogb3_obs_block_v1),
      OGB3_OBS_SPAN_CAPACITY_V1, OGB3_OBS_STACK_CAPACITY_V1,
      OGB3_OBS_ALL_PHASES_V1, sizeof(control)};
  return OGB3_OK;
}
ogb3_status ogb3_test_native_observe_begin_v1(uint64_t cookie,
    const ogb3_obs_config_v1 *config, ogb3_obs_block_v1 *block,
    uint64_t bytes, uint64_t *out_token) {
  ogb3_status status = domain(cookie);
  if (status) return status;
  if (reentered()) return OGB3_UNSUPPORTED;
  if (control.block) return OGB3_UNSUPPORTED;
  if (!config || !block || !out_token || bytes != sizeof(*block) ||
      (uintptr_t)block % _Alignof(ogb3_obs_block_v1) ||
      overlaps(config, sizeof(*config), block, bytes) ||
      overlaps(out_token, sizeof(*out_token), block, bytes) ||
      overlaps(config, sizeof(*config), out_token, sizeof(*out_token)))
    return OGB3_INVALID_ARGUMENT;
  if (config->abi_version != OGB3_OBS_VERSION_V1) return OGB3_INCOMPATIBLE;
  if (!config->phase_mask || (config->phase_mask & ~OGB3_OBS_ALL_PHASES_V1) ||
      (config->mode != OGB3_OBS_STRUCTURE_ONLY_V1 && config->mode != OGB3_OBS_TIMED_V1) ||
      (config->mode == OGB3_OBS_STRUCTURE_ONLY_V1 && (config->clock || config->clock_user)) ||
      (config->mode == OGB3_OBS_TIMED_V1 && (!config->clock || config->clock_user != block)))
    return OGB3_INVALID_ARGUMENT;
  if (control.next_token == UINT64_MAX) return OGB3_CAPACITY;
  uint64_t token = control.next_token + 1;
  memset(block, 0, sizeof(*block));
  block->abi_version = OGB3_OBS_VERSION_V1;
  block->struct_bytes = sizeof(*block);
  block->mode = config->mode;
  block->capacity = OGB3_OBS_SPAN_CAPACITY_V1;
  block->state = OGB3_OBS_ACTIVE_V1;
  block->scope_token = token;
  block->domain_cookie = cookie;
  block->next_span_id = 1;
  block->phase_mask = config->phase_mask;
  control.next_token = control.active_token = token;
  control.clock = config->clock;
  control.user = config->clock_user;
  control.block = block;
  *out_token = token;
  return OGB3_OK;
}
ogb3_status ogb3_test_native_observe_end_v1(uint64_t cookie, uint64_t token) {
  ogb3_status status = domain(cookie);
  if (status) return status;
  if (reentered()) return OGB3_UNSUPPORTED;
  if (!control.block || !token || token != control.active_token) return OGB3_INVALID_HANDLE;
  ogb3_obs_block_v1 *block = control.block;
  if (block->stack_depth) {
    block->error_flags |= OGB3_OBS_ERROR_UNCLOSED_V1;
    block->nesting_errors++;
  }
  control.block = NULL;
  control.clock = NULL;
  control.user = NULL;
  control.active_token = 0;
  block->state = OGB3_OBS_CLOSED_V1;
  return OGB3_OK;
}
static uint64_t read_clock(ogb3_obs_block_v1 *block) {
  if (block->mode != OGB3_OBS_TIMED_V1) return 0;
  uint64_t value = 0;
  block->clock_reads++;
  control.in_clock = 1;
  uint32_t available = control.clock(control.user, &value);
  control.in_clock = 0;
  if (available != 1) {
    block->error_flags |= OGB3_OBS_ERROR_CLOCK_FAILED_V1;
    block->clock_errors++;
    return 0;
  }
  if (value < block->last_clock_us) {
    block->error_flags |= OGB3_OBS_ERROR_CLOCK_REGRESSED_V1;
    block->clock_errors++;
  } else block->last_clock_us = value;
  return value;
}
uint64_t ogb3_obs_enter(uint32_t phase) {
  ogb3_obs_block_v1 *block = control.block;
  if (!block) return 0;
  if (reentered()) return 0;
  if (!phase || phase > 15 || !(block->phase_mask & OGB3_OBS_PHASE_BIT_V1(phase))) return 0;
  if (block->count >= OGB3_OBS_SPAN_CAPACITY_V1) {
    block->error_flags |= OGB3_OBS_ERROR_OVERFLOW_V1;
    block->overflow_count++;
    return 0;
  }
  if (block->stack_depth >= OGB3_OBS_STACK_CAPACITY_V1) {
    block->error_flags |= OGB3_OBS_ERROR_NESTING_V1;
    block->nesting_errors++;
    return 0;
  }
  uint64_t parent = block->stack_depth ? block->stack[block->stack_depth - 1] : 0;
  uint64_t root = parent ? block->spans[parent - 1].root_ordinal : ++block->root_count;
  uint64_t id = block->next_span_id++;
  ogb3_obs_span_v1 *span = block->spans + block->count++;
  *span = (ogb3_obs_span_v1){id, parent, root, 0, 0, phase, OGB3_OBS_STATUS_UNAVAILABLE_V1};
  block->stack[block->stack_depth++] = id;
  span->start_us = read_clock(block);
  return id;
}
void ogb3_obs_leave(uint64_t id, int32_t native_status) {
  ogb3_obs_block_v1 *block = control.block;
  if (!id || !block) return;
  if (reentered()) return;
  if (!block->stack_depth || id > block->count || block->stack[block->stack_depth - 1] != id) {
    block->error_flags |= OGB3_OBS_ERROR_NESTING_V1;
    block->nesting_errors++;
    return;
  }
  ogb3_obs_span_v1 *span = block->spans + id - 1;
  span->end_us = read_clock(block);
  span->native_status = native_status;
  block->stack[--block->stack_depth] = 0;
}
#endif
