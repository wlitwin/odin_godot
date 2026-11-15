#ifndef OGB3_AUTHORING_CATALOG_H
#define OGB3_AUTHORING_CATALOG_H

#include "recovery_codec.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Trusted authoring inputs only. No pointer or arbitrary geometry payload is
 * admitted from canonical recovery bytes. The constructor copies all inputs. */
#define OGB3_AUTHORING_ASSET_VERSION 2u
#define OGB3_AUTHORING_RECOVERY_FORMAT 2u
#define OGB3_AUTHORING_MAX_HULL_POINTS 256u
#define OGB3_AUTHORING_MAX_GEOMETRY_BYTES OGB3_RECOVERY_MAX_DTO_BYTES
enum { OGB3_RECOVERY_HULL = 4, OGB3_RECOVERY_MESH = 5 };

typedef struct {
  uint32_t version, struct_bytes;
  ogb3_recovery_asset base;
  const ogb3_vec3 *vertices;
  const uint32_t *indices;
  uint32_t vertex_count, triangle_count;
} ogb3_recovery_asset_v2;

/* On supported 64-bit targets: sizeof=72, align=8; offsets are
 * version0,struct_bytes4,base8,vertices48,indices56,vertex_count64,
 * triangle_count68. Query the actual C layout rather than assuming a pointer
 * layout on another target. field0..6 names version,struct_bytes,base,vertices,
 * indices,vertex_count,triangle_count. */
OGB3_API ogb3_status ogb3_authoring_asset_layout(
    uint32_t field, uint32_t *size, uint32_t *alignment, uint32_t *offset);

/* Sorted unique nonzero u32 asset IDs, at most the unchanged eight assets.
 * version=2 and struct_bytes=sizeof(ogb3_recovery_asset_v2) are mandatory.
 * Primitive base fields retain their v1 meaning; geometry pointers/counts=0.
 * Hull: 4..256 finite copied points, indices=NULL/triangle_count=0.
 * Mesh: finite copied vertices and triangle_count*3 valid copied indices.
 * Hull/Mesh base.a/base.b/radius/reserved=0. Checked aggregate input geometry
 * bytes <=2MiB and unchanged total requested-byte admission <=64MiB.
 * Heightfields and transformed boxes are baked to Mesh/Hull outside C.
 * V2 catalogs use recovery identity/wire format2; v1 API/catalogs remain1.
 * Distinct IDs that resolve to identical native geometry are rejected, not
 * remapped. Authoring layers deduplicate geometry before assigning catalog IDs;
 * logical authored-resource IDs live outside this catalog.
 * Failure returns *out=NULL and releases every partial native/copied owner.
 */
OGB3_API ogb3_status ogb3_recovery_catalog_create_v2(
    const ogb3_recovery_config *, const ogb3_recovery_asset_v2 *, uint32_t count,
    ogb3_recovery_catalog **out);
/* Same immutable asset descriptor/layout2; current full motion/joint solver
 * recovery contract3. Legacy constructors keep their original format1/2. */
OGB3_API ogb3_status ogb3_recovery_catalog_create_v3(
    const ogb3_recovery_config *, const ogb3_recovery_asset_v2 *, uint32_t count,
    ogb3_recovery_catalog **out);

/* Create from the catalog's immutable owned asset, never a caller geometry
 * pointer. World/snapshot geometry ownership survives catalog/source release.
 * Mesh is static-only, with sensor and sensor-event flags unsupported.
 * Failure leaves *out=0. The ordinary checked shape APIs remain supported.
 */
OGB3_API ogb3_status ogb3_recovery_catalog_shape(
    const ogb3_recovery_catalog *, uint32_t asset_id, ogb3_body,
    const ogb3_shape_def *, ogb3_shape *out);

#ifdef __cplusplus
}
#endif
#endif
