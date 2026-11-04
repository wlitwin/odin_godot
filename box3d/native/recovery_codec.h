#ifndef OGB3_RECOVERY_CODEC_H
#define OGB3_RECOVERY_CODEC_H
#include "owned_snapshot.h"
#ifdef __cplusplus
extern "C" {
#endif
/* Solver-only canonical recovery. Game/Side/proxy
 * fields/observations/epoch/tick are composed by the sibling codecs. Exact
 * build/target/profile only. */
#define OGB3_RECOVERY_FORMAT 1u
/* Current motion catalogs are constructed explicitly with create_v3 from
 * authoring_catalog.h; original catalog APIs/identity1/2 remain supported. */
#define OGB3_RECOVERY_MOTION_FORMAT 3u
#define OGB3_RECOVERY_MAX_ASSETS 8u
#define OGB3_RECOVERY_MAX_BYTES (512u * 1024u)
#define OGB3_RECOVERY_MAX_DTO_BYTES (2u * 1024u * 1024u)
#define OGB3_RECOVERY_MAX_SOURCE_IMAGE_BYTES (2u * 1024u * 1024u)
#define OGB3_RECOVERY_WRITE_RESERVE_BYTES (8u * 1024u * 1024u)
typedef struct ogb3_recovery_catalog ogb3_recovery_catalog;
enum {
  OGB3_RECOVERY_BOX = 1,
  OGB3_RECOVERY_SPHERE = 2,
  OGB3_RECOVERY_CAPSULE = 3
};
/* Sorted unique nonzero IDs. Box: a=half extents,b=0,radius=0. Sphere:
 * a=center,b=0,radius>0. Capsule: a/b=endpoints,radius>0. reserved=0.
 * Catalog owns copied immutable definitions. No arbitrary geometry wire import.
 */
typedef struct {
  uint32_t id, kind;
  ogb3_vec3 a, b;
  float radius;
  uint32_t reserved;
} ogb3_recovery_asset;
/* Defaults are the bounded alpha; callers may lower limits only. Sparse slots
 * and tree nodes are separate from live counts. build_target is filled by
 * config_default from the embedded verified native
 * source/config/compiler/target/FP identity. Catalog creation rejects
 * overriding it with a caller label. Runtime native fingerprint also binds the
 * target. */
typedef struct {
  uint64_t profile;
  uint8_t build_target[32];
  uint64_t max_bytes, max_dto_bytes;
  uint32_t max_bodies, max_shapes, max_contacts, max_joints, max_sensors;
  uint32_t max_sparse_slots, max_tree_nodes, max_manifolds, max_visitors;
  uint32_t max_pending_sensors, max_pending_contacts;
} ogb3_recovery_config;
typedef struct {
  uint32_t solver_format, recovery_format;
  uint64_t profile;
  uint8_t build_target[32], assets[32], solver_schema[32];
} ogb3_recovery_identity;
/* Optional first rejection location, never borrowed input/native pointers. */
typedef struct {
  uint64_t offset;
  uint32_t section, record, field, reason;
} ogb3_recovery_diagnostic;
OGB3_API uint32_t ogb3_recovery_format(void);
OGB3_API ogb3_status ogb3_recovery_layout(uint32_t type, uint32_t field,
                                          uint32_t *size, uint32_t *alignment,
                                          uint32_t *offset);
OGB3_API ogb3_status ogb3_recovery_config_default(ogb3_recovery_config *);
OGB3_API ogb3_status ogb3_recovery_catalog_create(const ogb3_recovery_config *,
                                                  const ogb3_recovery_asset *,
                                                  uint32_t count,
                                                  ogb3_recovery_catalog **out);
OGB3_API ogb3_status ogb3_recovery_catalog_clone(const ogb3_recovery_catalog *,
                                                 ogb3_recovery_catalog **out);
OGB3_API void ogb3_recovery_catalog_release(ogb3_recovery_catalog *);
OGB3_API ogb3_status ogb3_recovery_identity_get(const ogb3_recovery_catalog *,
                                                ogb3_recovery_identity *);
/* Readonly precommit profile admission for an idle borrowed execution. Runs
 * exactly the same semantic + full scalar/count/asset/size walker as write,
 * without creating/restoring/stepping a world. Temporaries charge external
 * bytes. required is full canonical size, not a pose estimate. Caller captures
 * this same execution and retains the <=MAX_SOURCE_IMAGE_BYTES resource gate
 * before publication. This does not export bytes or replace decode validation.
 */
OGB3_API ogb3_status ogb3_recovery_world_admit(const ogb3_recovery_catalog *,
                                               ogb3_world,
                                               uint64_t additional_owned_bytes,
                                               uint64_t *required,
                                               ogb3_recovery_diagnostic *);
/* NULL/0 output queries size; short buffers return CAPACITY with required size
 * and no partial write. Encoding can need two spare native world slots, but
 * never steps/publishes a world or consumes the image/catalog. Callers with
 * external framework charges must preflight global engine+wrapper+external
 * bytes plus WRITE_RESERVE_BYTES before BOTH query and write, and check totals
 * afterwards. The conservative supported-profile reserve includes DTO work;
 * metadata/alignment overhead is reported separately, and this is not a native
 * allocator hard-cap/OOM-recovery guarantee. Unknown geometry is rejected
 * before scratch creation. */
OGB3_API ogb3_status ogb3_recovery_write(const ogb3_recovery_catalog *,
                                         const ogb3_snapshot *, uint8_t *out,
                                         uint64_t capacity, uint64_t *required,
                                         ogb3_recovery_diagnostic *);
/* Success returns one NEW OWNED detached Snapshot (caller releases). Input is
 * borrowed only for the call. Catalog and source may be released afterwards.
 * Full bounded DTO/semantic verification precedes trusted staged
 * reconstruction; no arbitrary wire/native-image loader or wire-derived seal
 * trust. Failure returns *out=NULL, no publication/mutation, and frees all
 * owned candidates. additional_owned_bytes charges external framework storage
 * to global64MiB admission; no hidden user/runtime pointer. Engine allocator
 * OOM remains the documented fatal native boundary, not a recovered status
 * claim. */
OGB3_API ogb3_status ogb3_recovery_read(const ogb3_recovery_catalog *,
                                        const uint8_t *data, uint64_t size,
                                        uint64_t additional_owned_bytes,
                                        ogb3_snapshot **out,
                                        ogb3_recovery_diagnostic *);
/* Same complete read into a LOCAL owned result, then fresh metadata before
 * owner publication; no second getter check. All original decoder/constructor
 * checks remain. Seven metadata pointers and out are required; on failure out
 * is NULL and metadata unchanged. Optional diagnostic follows read's contract.
 */
OGB3_API ogb3_status ogb3_recovery_read_info(
    const ogb3_recovery_catalog *, const uint8_t *, uint64_t size,
    uint64_t additional_owned_bytes, ogb3_snapshot **out, uint64_t *image_used,
    uint64_t *image_capacity, uint64_t *geometry_bytes,
    uint32_t *geometry_count, uint64_t *normalized_bytes,
    uint64_t *wrapper_malloc_bytes, uint64_t *native_requested_bytes,
    ogb3_recovery_diagnostic *);
#ifdef __cplusplus
}
#endif
#endif
