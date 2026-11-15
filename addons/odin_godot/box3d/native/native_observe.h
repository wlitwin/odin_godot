/* Opt-in diagnostic test ABI. Ordinary builds provide none of these symbols.
 * Supported layout targets: macOS arm64 / Linux x86_64.
 */
#ifndef OGB3_TEST_NATIVE_OBSERVE_V1_H
#define OGB3_TEST_NATIVE_OBSERVE_V1_H

#include <stddef.h>
#include <stdint.h>
#include "api.h"

#define OGB3_OBS_VERSION_V1 1u
#define OGB3_OBS_SPAN_CAPACITY_V1 1024u
#define OGB3_OBS_STACK_CAPACITY_V1 16u
#define OGB3_OBS_SPAN_BYTES_V1 48u
#define OGB3_OBS_BLOCK_BYTES_V1 49392u
#define OGB3_OBS_CONFIG_BYTES_V1 32u
#define OGB3_OBS_ABI_BYTES_V1 48u
#define OGB3_OBS_STATUS_UNAVAILABLE_V1 (-INT32_C(2147483647) - 1)

typedef enum ogb3_obs_mode_v1 {
  OGB3_OBS_OFF_V1 = 0,
  OGB3_OBS_STRUCTURE_ONLY_V1 = 1,
  OGB3_OBS_TIMED_V1 = 2
} ogb3_obs_mode_v1;

typedef enum ogb3_obs_phase_v1 {
  OGB3_OBS_STEP_FIXED_V1 = 1,
  OGB3_OBS_SNAPSHOT_CAPTURE_V1 = 2,
  OGB3_OBS_SNAPSHOT_SERIALIZE_V1 = 3,
  OGB3_OBS_SNAPSHOT_NORMALIZE_V1 = 4,
  OGB3_OBS_SNAPSHOT_FINALIZE_V1 = 5,
  OGB3_OBS_SNAPSHOT_VALIDATE_V1 = 6,
  OGB3_OBS_ADMISSION_WORLD_V1 = 7,
  OGB3_OBS_RECOVERY_READ_V1 = 8,
  OGB3_OBS_RECOVERY_PARSE_VALIDATE_V1 = 9,
  OGB3_OBS_RECOVERY_BUILD_V1 = 10,
  OGB3_OBS_RECOVERY_VERIFY_REENCODE_V1 = 11,
  OGB3_OBS_RECOVERY_WRITE_V1 = 12,
  OGB3_OBS_CANONICAL_VALIDATE_V1 = 13,
  OGB3_OBS_CANONICAL_COUNT_V1 = 14,
  OGB3_OBS_CANONICAL_EMIT_V1 = 15
} ogb3_obs_phase_v1;

#define OGB3_OBS_PHASE_BIT_V1(phase) (UINT64_C(1) << ((phase) - 1u))
#define OGB3_OBS_INITIAL_PHASES_V1 UINT64_C(0x0fff)
#define OGB3_OBS_ALL_PHASES_V1 UINT64_C(0x7fff)

typedef enum ogb3_obs_state_v1 {
  OGB3_OBS_UNUSED_V1 = 0,
  OGB3_OBS_ACTIVE_V1 = 1,
  OGB3_OBS_CLOSED_V1 = 2
} ogb3_obs_state_v1;

/* Attribution errors ONLY. Never substitute these for a simulation status. */
typedef enum ogb3_obs_error_v1 {
  OGB3_OBS_ERROR_OVERFLOW_V1 = 1u << 0,
  OGB3_OBS_ERROR_CLOCK_FAILED_V1 = 1u << 1,
  OGB3_OBS_ERROR_CLOCK_REGRESSED_V1 = 1u << 2,
  OGB3_OBS_ERROR_NESTING_V1 = 1u << 3,
  OGB3_OBS_ERROR_UNCLOSED_V1 = 1u << 4,
  OGB3_OBS_ERROR_SCOPE_REENTRY_V1 = 1u << 5
} ogb3_obs_error_v1;

/* C calling convention. 1 writes actual Godot usec; 0 reports unavailable.
 * Does not allocate, log, access a world, or reenter the backend.
 * Code Owner + EXACT block DataLease are held by the test caller, not inferred
 * by C from clock_user. clock_user must equal the supplied block for timed mode.
 */
typedef uint32_t (*ogb3_obs_clock_v1)(void *clock_user, uint64_t *out_usec);

typedef struct ogb3_obs_span_v1 {
  uint64_t id;                 /* 0: 1-based BEGIN ordinal */
  uint64_t parent_id;          /* 8: nearest recorded ancestor, or0 */
  uint64_t root_ordinal;       /* 16: selected root operation, NOT all API calls */
  uint64_t start_us;           /* 24: unavailable/zero in STRUCTURE_ONLY */
  uint64_t end_us;             /* 32: unavailable/zero in STRUCTURE_ONLY */
  uint32_t phase;              /* 40: ogb3_obs_phase_v1 */
  int32_t native_status;       /* 44: actual wrapper result, or UNAVAILABLE */
} ogb3_obs_span_v1;

typedef struct ogb3_obs_block_v1 {
  uint32_t abi_version;        /* 0 */
  uint32_t struct_bytes;       /* 4 */
  uint32_t mode;               /* 8 */
  uint32_t capacity;           /* 12: fixed1024 */
  uint32_t count;              /* 16: written slots <= capacity */
  uint32_t stack_depth;        /* 20: must be0 at valid END */
  uint32_t error_flags;        /* 24: bitwise ogb3_obs_error_v1 */
  uint32_t state;              /* 28: ACTIVE/CLOSED; not a simulation state */
  uint64_t scope_token;        /* 32: preserved after END for correlation */
  uint64_t domain_cookie;      /* 40 */
  uint64_t next_span_id;       /* 48 */
  uint64_t root_count;         /* 56 */
  uint64_t clock_reads;        /* 64 */
  uint64_t clock_errors;       /* 72 */
  uint64_t overflow_count;     /* 80 */
  uint64_t nesting_errors;     /* 88 */
  uint64_t last_clock_us;      /* 96 */
  uint64_t phase_mask;         /* 104 */
  uint64_t stack[OGB3_OBS_STACK_CAPACITY_V1]; /* 112: IDs, not pointers */
  ogb3_obs_span_v1 spans[OGB3_OBS_SPAN_CAPACITY_V1]; /* 240 */
} ogb3_obs_block_v1;

typedef struct ogb3_obs_config_v1 {
  uint32_t abi_version;        /* 0 */
  uint32_t mode;               /* 4: STRUCTURE_ONLY or TIMED for begin */
  uint64_t phase_mask;         /* 8: nonzero subset of supported_phases */
  ogb3_obs_clock_v1 clock;     /* 16 */
  void *clock_user;            /* 24 */
} ogb3_obs_config_v1;

typedef struct ogb3_obs_abi_v1 {
  uint32_t abi_version;        /* 0 */
  uint32_t span_bytes;         /* 4 */
  uint32_t config_bytes;       /* 8 */
  uint32_t block_bytes;        /* 12 */
  uint32_t span_alignment;     /* 16 */
  uint32_t block_alignment;    /* 20 */
  uint32_t span_capacity;      /* 24 */
  uint32_t stack_capacity;     /* 28 */
  uint64_t supported_phases;   /* 32 */
  uint64_t native_static_storage_bytes; /* 40: exact sizeof C control */
} ogb3_obs_abi_v1;

#if defined(__cplusplus)
#define OGB3_OBS_ASSERT_V1 static_assert
#define OGB3_OBS_ALIGN_V1 alignof
#else
#define OGB3_OBS_ASSERT_V1 _Static_assert
#define OGB3_OBS_ALIGN_V1 _Alignof
#endif
OGB3_OBS_ASSERT_V1(sizeof(void *) == 8, "observation v1 supported target pointers");
OGB3_OBS_ASSERT_V1(sizeof(ogb3_obs_clock_v1) == 8, "observation v1 callback width");
OGB3_OBS_ASSERT_V1(sizeof(ogb3_obs_span_v1) == OGB3_OBS_SPAN_BYTES_V1, "span48");
OGB3_OBS_ASSERT_V1(offsetof(ogb3_obs_span_v1, native_status) == 44, "span status");
OGB3_OBS_ASSERT_V1(sizeof(ogb3_obs_block_v1) == OGB3_OBS_BLOCK_BYTES_V1, "block49392");
OGB3_OBS_ASSERT_V1(offsetof(ogb3_obs_block_v1, stack) == 112, "stack offset");
OGB3_OBS_ASSERT_V1(offsetof(ogb3_obs_block_v1, spans) == 240, "spans offset");
OGB3_OBS_ASSERT_V1(sizeof(ogb3_obs_config_v1) == OGB3_OBS_CONFIG_BYTES_V1, "config32");
OGB3_OBS_ASSERT_V1(offsetof(ogb3_obs_config_v1, clock) == 16, "clock offset");
OGB3_OBS_ASSERT_V1(offsetof(ogb3_obs_config_v1, clock_user) == 24, "user offset");
OGB3_OBS_ASSERT_V1(sizeof(ogb3_obs_abi_v1) == OGB3_OBS_ABI_BYTES_V1, "descriptor48");
OGB3_OBS_ASSERT_V1(OGB3_OBS_ALIGN_V1(ogb3_obs_span_v1) == 8, "span alignment");
OGB3_OBS_ASSERT_V1(OGB3_OBS_ALIGN_V1(ogb3_obs_block_v1) == 8, "block alignment");

/* Symbols ONLY in an explicitly opted-in diagnostic Native build.
 * An ordinary build exports none of these; no production binding imports them.
 */
#if defined(OGB3_NATIVE_OBSERVATION) && OGB3_NATIVE_OBSERVATION
#ifdef __cplusplus
extern "C" {
#endif
OGB3_API ogb3_status ogb3_test_native_observe_abi_v1(
    uint64_t domain_cookie, ogb3_obs_abi_v1 *out);
OGB3_API ogb3_status ogb3_test_native_observe_begin_v1(
    uint64_t domain_cookie, const ogb3_obs_config_v1 *config,
    ogb3_obs_block_v1 *block, uint64_t block_bytes, uint64_t *out_token);
OGB3_API ogb3_status ogb3_test_native_observe_end_v1(
    uint64_t domain_cookie, uint64_t token);
#ifdef __cplusplus
}
#endif
#endif
#undef OGB3_OBS_ASSERT_V1
#undef OGB3_OBS_ALIGN_V1
#endif
