#ifndef OGB3_STATE_DUMP_H
#define OGB3_STATE_DUMP_H
#include "api.h"
#ifdef __cplusplus
extern "C" {
#endif
#define OGB3_STATE_DUMP_VERSION 4u
#define OGB3_STATE_COVERAGE_ID "ogb3-33626332-solver-v4"
/* Normalized solver state only. Includes all future-affecting fields serialized
 * by pinned world_snapshot.c; excludes pointers, padding, world slot, names,
 * profiling, completed event outputs and unused registry history. Geometry is
 * content-based. Ordered pending sensor/contact end queues are future inputs
 * and are included with local allocation IDs/generations. Callbacks, process
 * configuration and deterministic game side-state remain host prerequisites.
 * Bytes are local exact-build comparison data, not recovery wire. */
OGB3_API const char *ogb3_state_coverage(void);
OGB3_API uint32_t ogb3_state_version(void);
/* NULL bytes with zero capacity queries required and returns OK. Insufficient
 * non-NULL capacity returns CAPACITY without writing. World must remain idle
 * between sizing and fill. */
OGB3_API int32_t ogb3_state_dump(uint32_t world, uint8_t *bytes,
                                 uint64_t capacity, uint64_t *required);
OGB3_API int32_t ogb3_state_digest(uint32_t world,
                                   uint64_t *complete_solver_digest,
                                   uint64_t *motion_digest);
#ifdef __cplusplus
}
#endif
#endif
