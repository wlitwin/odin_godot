#ifndef OGB3_OWNED_SNAPSHOT_INTERNAL_H
#define OGB3_OWNED_SNAPSHOT_INTERNAL_H
#include "owned_snapshot.h"

enum { OGB3_TRUSTED_HULL = 1, OGB3_TRUSTED_MESH = 2 };
typedef struct {
  uint32_t kind, byte_count;
  const void *bytes;
} ogb3_trusted_geometry;

/* The caller owns a validated immutable catalog. This private local-image gate
 * grants no trust to wire geometry or serialized image bytes. */
int32_t ogb3_snapshot_recovery_preflight(
    const ogb3_snapshot *, const ogb3_trusted_geometry *, uint32_t count,
    uint32_t body_limit, uint64_t image_limit);
#endif
