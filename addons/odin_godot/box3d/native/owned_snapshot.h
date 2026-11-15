#ifndef OGB3_OWNED_SNAPSHOT_H
#define OGB3_OWNED_SNAPSHOT_H
#include "api.h"
#ifdef __cplusplus
extern "C" {
#endif
/* Exact pinned native build only. No byte import/export or wire format. All
 * calls are single-threaded, at unlocked step boundaries. Owned handles must be
 * released exactly once; clone returns a distinct lease. NULL release is
 * harmless. Restore stages a trusted, sealed image before replacing simulation
 * storage. Body/shape/joint userData and completed outputs are cleared. Future
 * pending sensor/contact end queues are retained and retargeted to the
 * destination. Host callback wiring stays with the destination. Application
 * identity maps must be restored/rebound separately; future native handle
 * numbers can recur after rewind. */
typedef struct ogb3_snapshot ogb3_snapshot;
#define OGB3_SNAPSHOT_VERSION 2u
#define OGB3_SNAPSHOT_BODY_CAPACITY 65536u
#define OGB3_SNAPSHOT_PENDING_END_CAPACITY 65536u
/* Cumulative successful wrapper allocation requests: every Resource/owner/slot/
 * normalized/pose/pending-queue buffer/world Lease in this module, plus
 * state_dump digest temporary buffers. Excludes caller buffers, flat-api
 * geometry wrappers, native engine allocations, allocator headers/rounding.
 * Live/high-water track requested bytes. */
OGB3_API int32_t ogb3_snapshot_allocation_stats(ogb3_allocation_stats *out);
OGB3_API int32_t ogb3_snapshot_capture(uint32_t world, ogb3_snapshot **out);
OGB3_API int32_t ogb3_snapshot_clone(const ogb3_snapshot *snapshot,
                                     ogb3_snapshot **out);
OGB3_API void ogb3_snapshot_release(ogb3_snapshot *snapshot);
OGB3_API int32_t ogb3_snapshot_restore(uint32_t world,
                                       const ogb3_snapshot *snapshot);
OGB3_API int32_t ogb3_snapshot_dump(const ogb3_snapshot *, uint8_t *bytes,
                                    uint64_t capacity, uint64_t *required);
OGB3_API int32_t ogb3_snapshot_digest(const ogb3_snapshot *,
                                      uint64_t *complete_solver_digest,
                                      uint64_t *motion_digest);
/* Immutable copied historical state. Lookup is allocation-free O(log bodies),
 * no scratch worlds or full-image scans. Bulk NULL/0 query returns OK; short
 * non-NULL arrays return CAPACITY without partial writes. Keys must be
 * canonical. Cache storage is charged to snapshot_storage and allocation_stats.
 */
OGB3_API int32_t ogb3_snapshot_body_state(const ogb3_snapshot *, ogb3_body_key,
                                          ogb3_body_state *);
OGB3_API int32_t ogb3_snapshot_body_states(const ogb3_snapshot *,
                                           ogb3_body_state *, uint32_t capacity,
                                           uint32_t *required);
/* Resource memory: wrapper_malloc_bytes includes normalized and body-state
 * cache and pending queue bytes, resource, one owner and registry-slot array.
 * Shared clones report the same resource. native_requested_bytes includes
 * image/registry/dedup/mutex allocations and lazily reconstructed compounds,
 * measured in Box3D requested (unrounded) bytes. Excludes allocator overhead
 * and per-import world lease sizeof(void*)*3. */
OGB3_API int32_t ogb3_snapshot_storage(const ogb3_snapshot *,
                                       uint64_t *normalized_bytes,
                                       uint64_t *wrapper_malloc_bytes,
                                       uint64_t *native_requested_bytes);
OGB3_API int32_t ogb3_snapshot_metrics(const ogb3_snapshot *snapshot,
                                       uint64_t *image_used,
                                       uint64_t *image_capacity,
                                       uint64_t *geometry_bytes,
                                       uint32_t *geometry_count);
/* Combined immutable metadata: ONE identical full seal/structural validation.
 * All seven output pointers are required. Any failure leaves all outputs
 * unchanged. Existing storage/metrics getters retain their exact contracts. */
OGB3_API int32_t ogb3_snapshot_info(const ogb3_snapshot *, uint64_t *image_used,
                                    uint64_t *image_capacity,
                                    uint64_t *geometry_bytes,
                                    uint32_t *geometry_count,
                                    uint64_t *normalized_bytes,
                                    uint64_t *wrapper_malloc_bytes,
                                    uint64_t *native_requested_bytes);
/* Atomic checked constructors + fresh metadata. Existing capture/clone runs
 * into a LOCAL owner, preserving its full seal/structural/fingerprint/cache and
 * allocation validation. Pure metadata is copied before exposing the owner;
 * there is no second getter validation and no arbitrary-resource trust path.
 * All output pointers required. Failure: owner=NULL, metadata unchanged. */
OGB3_API int32_t ogb3_snapshot_capture_info(
    uint32_t world, ogb3_snapshot **out, uint64_t *image_used,
    uint64_t *image_capacity, uint64_t *geometry_bytes,
    uint32_t *geometry_count, uint64_t *normalized_bytes,
    uint64_t *wrapper_malloc_bytes, uint64_t *native_requested_bytes);
OGB3_API int32_t ogb3_snapshot_clone_info(
    const ogb3_snapshot *, ogb3_snapshot **out, uint64_t *image_used,
    uint64_t *image_capacity, uint64_t *geometry_bytes,
    uint32_t *geometry_count, uint64_t *normalized_bytes,
    uint64_t *wrapper_malloc_bytes, uint64_t *native_requested_bytes);
/* Native lifecycle hook: call AFTER b3DestroyWorld, never before. Imported
 * worlds retain geometry independently of caller snapshots until
 * replacement/destruction. */
OGB3_API void ogb3_snapshot_world_detach(uint32_t world);
#ifdef __cplusplus
}
#endif
#endif
