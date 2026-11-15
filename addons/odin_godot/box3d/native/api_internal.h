#ifndef OGB3_API_INTERNAL_H
#define OGB3_API_INTERNAL_H
#include <stddef.h>
#include "authoring_catalog.h"

/* Private C representation only; never part of the foreign ABI. */
struct ogb3_geometry {
  uint32_t refs, kind;
  void *data;
};
typedef struct {
  uint32_t id, kind;
  ogb3_vec3 a, b;
  float radius;
  ogb3_geometry *geometry;
} ogb3_catalog_asset_view;
struct ogb3_recovery_catalog;
ogb3_status ogb3_catalog_asset_lookup(const struct ogb3_recovery_catalog *,
                                    uint32_t, ogb3_catalog_asset_view *);
ogb3_status ogb3_authoring_asset_validate(const ogb3_recovery_asset_v2 *, uint64_t *);
void *ogb3_snapshot_internal_alloc(size_t);
void ogb3_snapshot_internal_free(void *);
#endif
