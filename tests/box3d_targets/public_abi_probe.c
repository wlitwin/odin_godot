/* Compile-only public C POD observations. No Box3D implementation is linked or
 * executed. These constants do not establish foreign-call, solver, snapshot,
 * platform deployment or performance correctness. */
#include <stddef.h>
#include <stdint.h>
#include <float.h>
#include "api.h"
#include "authoring_catalog.h"
#include "motion.h"
const uint32_t ogb3_target_public_abi[] = {
    sizeof(void *) * 8, sizeof(float), FLT_RADIX, FLT_MANT_DIG,
    sizeof(ogb3_world), sizeof(ogb3_body), sizeof(ogb3_shape), sizeof(ogb3_joint),
    sizeof(ogb3_vec3), sizeof(ogb3_pose), sizeof(ogb3_recovery_asset_v2),
    _Alignof(ogb3_recovery_asset_v2),
    offsetof(ogb3_recovery_asset_v2, vertices),
    offsetof(ogb3_recovery_asset_v2, indices),
    offsetof(ogb3_recovery_asset_v2, vertex_count),
    offsetof(ogb3_recovery_asset_v2, triangle_count), sizeof(ogb3_motion_joint_def)
};
