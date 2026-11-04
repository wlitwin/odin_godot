/* Benchmark-only scalar adapter over the pinned public Box3D counters.
 * Link this object with the exact native archive used by the measured case.
 * Call only at an unlocked step boundary on the backend's single caller.
 *
 * Prototype (api.h supplies ogb3_status):
 *   ogb3_status ogb3_bench_world_counts(uint32_t world, uint32_t counts[6]);
 *
 * counts[0..5] = b3Counters.bodyCount, shapeCount, contactCount, jointCount,
 *               islandCount, treeHeight.
 * treeHeight is max(dynamic-tree height, kinematic-tree height), as reported
 * by the pinned b3World_GetCounters implementation; it excludes the static tree.
 * Counts are current live solver allocation counts, including static bodies and
 * shapes. No b3Counters layout or other upstream struct crosses the flat ABI.
 * Failure leaves the caller's array untouched. */
#include "api.h"
#include "box3d/box3d.h"

#include <string.h>

OGB3_API ogb3_status ogb3_bench_world_counts(uint32_t packed_world,
                                           uint32_t counts[6]) {
    if (counts == NULL) {
        return OGB3_INVALID_ARGUMENT;
    }

    uint32_t valid = 0;
    ogb3_status status = ogb3_world_valid(packed_world, &valid);
    if (status != OGB3_OK) {
        return status;
    }
    if (valid == 0) {
        return OGB3_INVALID_HANDLE;
    }

    b3WorldId world;
    _Static_assert(sizeof(world) == sizeof(packed_world), "world handle ABI");
    memcpy(&world, &packed_world, sizeof(world));
    const b3Counters native = b3World_GetCounters(world);
    const int values[6] = {native.bodyCount, native.shapeCount,
                           native.contactCount, native.jointCount,
                           native.islandCount, native.treeHeight};
    uint32_t result[6];
    for (unsigned i = 0; i < 6; ++i) {
        if (values[i] < 0) {
            return OGB3_CORRUPT;
        }
        result[i] = (uint32_t)values[i];
    }
    memcpy(counts, result, sizeof(result));
    return OGB3_OK;
}
