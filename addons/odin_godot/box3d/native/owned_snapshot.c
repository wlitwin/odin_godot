#include "native_observe_internal.h"
/* Owned exact-build snapshots for the pinned private Box3D serializer.
 * Never expose b3DeserializeIntoShell to arbitrary image bytes. */
#include "owned_snapshot.h"
#include "owned_snapshot_internal.h"
#include "body.h"
#include "box3d/box3d.h"
#include "contact.h"
#include "island.h"
#include "joint.h"
#include "physics_world.h"
#include "sensor.h"
#include "shape.h"
#include "solver_set.h"
#include "state_dump.h"
#include "state_dump_internal.h"
#include "world_snapshot.h"
#include <assert.h>
#include <limits.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

/* All wrapper allocations share this accounting domain, including temporary
 * digest storage used by state_dump.c. Header/alignment overhead is
 * deliberately outside requested-byte totals, matching the engine counter
 * convention. */
typedef union WrapperHeader {
  max_align_t alignment;
  size_t requested;
} WrapperHeader;
static ogb3_allocation_stats wrapper_stats;
#ifdef OGB3_TESTING
static int64_t fail_allocation_after = -1;
void ogb3_snapshot_test_fail_allocation_after(int64_t count) {
  fail_allocation_after = count;
}
#endif
void *ogb3_snapshot_internal_alloc(size_t size) {
  if (size > SIZE_MAX - sizeof(WrapperHeader))
    return NULL;
#ifdef OGB3_TESTING
  if (fail_allocation_after == 0)
    return NULL;
  if (fail_allocation_after > 0)
    fail_allocation_after--;
#endif
  WrapperHeader *h = malloc(sizeof(*h) + size);
  if (!h)
    return NULL;
  h->requested = size;
  wrapper_stats.total_calls++;
  wrapper_stats.total_bytes += size;
  wrapper_stats.live_bytes += size;
  if (wrapper_stats.live_bytes > wrapper_stats.high_water_bytes)
    wrapper_stats.high_water_bytes = wrapper_stats.live_bytes;
  return h + 1;
}
void ogb3_snapshot_internal_free(void *ptr) {
  if (!ptr)
    return;
  WrapperHeader *h = (WrapperHeader *)ptr - 1;
  assert(wrapper_stats.live_bytes >= h->requested);
  wrapper_stats.live_bytes -= h->requested;
  free(h);
}
static void *wrapper_calloc(size_t count, size_t size) {
  if (size && count > SIZE_MAX / size)
    return NULL;
  size_t total = count * size;
  void *ptr = ogb3_snapshot_internal_alloc(total);
  if (ptr)
    memset(ptr, 0, total);
  return ptr;
}
int32_t ogb3_snapshot_allocation_stats(ogb3_allocation_stats *out) {
  if (!out)
    return OGB3_INVALID_ARGUMENT;
  *out = wrapper_stats;
  return OGB3_OK;
}
typedef struct PendingSensorEnd {
  uint64_t sensor, visitor;
} PendingSensorEnd;
typedef struct PendingContactEnd {
  uint64_t shape_a, shape_b, contact;
} PendingContactEnd;
_Static_assert(sizeof(PendingSensorEnd) == 16 &&
                   sizeof(PendingContactEnd) == 24,
               "pending key storage");
static int shape_key_valid(uint64_t key) {
  return (uint32_t)key > 0 && (uint32_t)key <= INT32_MAX &&
         (key >> 32) <= UINT16_MAX;
}
static int contact_key_valid(uint64_t key) {
  return (uint32_t)key > 0 && (uint32_t)key <= INT32_MAX;
}
static uint64_t local_shape_key(b3ShapeId id) {
  return (uint32_t)id.index1 | ((uint64_t)id.generation << 32);
}
static uint64_t local_contact_key(b3ContactId id) {
  return (uint32_t)id.index1 | ((uint64_t)id.generation << 32);
}
typedef struct Resource {
  uint32_t refs;
  b3Recording *recording;
  b3RecBuffer image;
  b3RegistrySlot *slots;
  uint8_t *normalized;
  uint64_t normalized_size, seal, complete, motion, geometry_bytes;
  /* complete is exact FNV-1a over normalized, computed on first digest
   * request: per-tick captures never pay a byte-serial walk nobody reads. */
  uint32_t complete_ready;
  uint64_t fingerprint, native_requested_bytes;
  uint32_t version;
  ogb3_body_state *bodies;
  uint32_t body_count;
  PendingSensorEnd *sensor_pending;
  PendingContactEnd *contact_pending;
  uint32_t sensor_pending_count, contact_pending_count;
} Resource;
struct ogb3_snapshot {
  Resource *resource;
};
typedef struct Lease {
  uint32_t world;
  Resource *resource;
  struct Lease *next;
} Lease;
static Lease *leases;
#ifdef OGB3_TESTING
static int fail_stage;
static uint32_t pose_limit = OGB3_SNAPSHOT_BODY_CAPACITY;
static uint32_t pending_limit = OGB3_SNAPSHOT_PENDING_END_CAPACITY;
static uint32_t fresh_fault;
static uint64_t seal_walks;
void ogb3_snapshot_test_fresh_fault(uint32_t mode) { fresh_fault = mode; }
void ogb3_snapshot_test_reset_seal_walks(void) { seal_walks = 0; }
uint64_t ogb3_snapshot_test_seal_walks(void) { return seal_walks; }
void ogb3_snapshot_test_pending_limit(uint32_t count) { pending_limit = count; }
void ogb3_snapshot_test_pose_limit(uint32_t count) { pose_limit = count; }
void ogb3_snapshot_test_fail_stage(int stage) { fail_stage = stage; }
#endif
static uint64_t hash_bytes(uint64_t h, const void *data, size_t n) {
  const uint8_t *p = data;
  /* Exact FNV-1a for every uint64 seed: k zero-byte rounds are h*prime^k
   * modulo2^64. Every memcpy stays inside the remaining span and checks ALL
   * bytes in that group. Nonzero groups retain the original byte order;
   * equality-to-zero is independent of host endian/alignment/aliasing. */
  const uint64_t prime = UINT64_C(1099511628211);
  const uint64_t power2 = prime * prime;
  const uint64_t power4 = power2 * power2;
  while (n >= 8) {
    uint64_t word;
    memcpy(&word, p, 8);
    if (word == 0)
      h *= UINT64_C(0x1efac7090aef4a21);
    else {
      for (unsigned i = 0; i < 8; i += 4) {
        uint32_t half;
        memcpy(&half, p + i, 4);
        if (half == 0)
          h *= power4;
        else {
          for (unsigned j = i; j < i + 4; j += 2) {
            uint16_t pair;
            memcpy(&pair, p + j, 2);
            if (pair == 0)
              h *= power2;
            else {
              h = (h ^ p[j]) * prime;
              h = (h ^ p[j + 1]) * prime;
            }
          }
        }
      }
    }
    p += 8;
    n -= 8;
  }
  if (n >= 4) {
    uint32_t word;
    memcpy(&word, p, 4);
    if (word == 0)
      h *= power4;
    else {
      for (unsigned i = 0; i < 4; i += 2) {
        uint16_t pair;
        memcpy(&pair, p + i, 2);
        if (pair == 0)
          h *= power2;
        else {
          h = (h ^ p[i]) * prime;
          h = (h ^ p[i + 1]) * prime;
        }
      }
    }
    p += 4;
    n -= 4;
  }
  if (n >= 2) {
    uint16_t pair;
    memcpy(&pair, p, 2);
    if (pair == 0)
      h *= power2;
    else {
      h = (h ^ p[0]) * prime;
      h = (h ^ p[1]) * prime;
    }
    p += 2;
    n -= 2;
  }
  if (n)
    h = (h ^ p[0]) * prime;
  return h;
}
#ifdef OGB3_TESTING
uint64_t ogb3_snapshot_test_hash_bytes(uint64_t h, const void *p, size_t n) {
  return hash_bytes(h, p, n);
}
#endif
/* Process-local integrity hash for the seal. The seal is never serialized,
 * transmitted or compared across processes; it only detects in-memory change
 * of an immutable resource. Four independent multiply/rotate lanes over 8-byte
 * words keep every validate() walk (capture, clone, restore, dump, digest)
 * memory-bandwidth bound instead of one dependent multiply per byte. */
static inline uint64_t seal_rotl(uint64_t x, unsigned k) {
  return (x << k) | (x >> (64u - k));
}
static inline uint64_t seal_fmix(uint64_t x) {
  x ^= x >> 33;
  x *= UINT64_C(0xff51afd7ed558ccd);
  x ^= x >> 33;
  x *= UINT64_C(0xc4ceb9fe1a85ec53);
  x ^= x >> 33;
  return x;
}
static uint64_t seal_bytes(uint64_t h, const void *data, size_t n) {
  const uint8_t *p = data;
  const uint64_t k1 = UINT64_C(0x9e3779b97f4a7c15),
                 k2 = UINT64_C(0xc2b2ae3d27d4eb4f);
  uint64_t a = h ^ k1, b = h + k2, c = h - k1, d = seal_rotl(h, 29) ^ k2;
  size_t length = n;
  while (n >= 32) {
    uint64_t w[4];
    memcpy(w, p, 32);
    a = seal_rotl((a ^ w[0]) * k1, 31) * k2;
    b = seal_rotl((b ^ w[1]) * k1, 31) * k2;
    c = seal_rotl((c ^ w[2]) * k1, 31) * k2;
    d = seal_rotl((d ^ w[3]) * k1, 31) * k2;
    p += 32;
    n -= 32;
  }
  while (n >= 8) {
    uint64_t w;
    memcpy(&w, p, 8);
    a = seal_rotl((a ^ w) * k1, 31) * k2;
    a ^= seal_rotl(a, 17);
    p += 8;
    n -= 8;
  }
  if (n) {
    uint64_t w = 0;
    memcpy(&w, p, n);
    b = seal_rotl((b ^ w ^ ((uint64_t)n << 56)) * k1, 31) * k2;
  }
  return seal_fmix(a ^ seal_rotl(b, 13) ^ seal_rotl(c, 27) ^
                   seal_rotl(d, 41) ^ (uint64_t)length);
}
static uint64_t seal(const Resource *r) {
#ifdef OGB3_TESTING
  seal_walks++;
#endif
  uint64_t h =
      seal_bytes(14695981039346656037ull, r->image.data, (size_t)r->image.size);
  for (int i = 0; i < r->recording->registry.entries.count; i++) {
    const b3GeometryEntry *g = r->recording->registry.entries.data + i;
    h = seal_bytes(h, &g->kind, sizeof(g->kind));
    h = seal_bytes(h, &g->byteCount, sizeof(g->byteCount));
    h = seal_bytes(h, g->bytes, (size_t)g->byteCount);
  }
  h = seal_bytes(h, &r->sensor_pending_count, sizeof(r->sensor_pending_count));
  h = seal_bytes(h, r->sensor_pending,
                 (size_t)r->sensor_pending_count * sizeof(*r->sensor_pending));
  h = seal_bytes(h, &r->contact_pending_count,
                 sizeof(r->contact_pending_count));
  h = seal_bytes(h, r->contact_pending,
                 (size_t)r->contact_pending_count *
                     sizeof(*r->contact_pending));
  return h;
}
static void drop(Resource *r) {
  if (!r || --r->refs)
    return;
  /* Registry slots borrow the recording-owned packed geometry bytes. */
  ogb3_snapshot_internal_free(r->slots);
  ogb3_snapshot_internal_free(r->normalized);
  ogb3_snapshot_internal_free(r->bodies);
  ogb3_snapshot_internal_free(r->sensor_pending);
  ogb3_snapshot_internal_free(r->contact_pending);
  b3RecBufFree(&r->image);
  if (r->recording)
    b3DestroyRecording(r->recording);
  ogb3_snapshot_internal_free(r);
}
void ogb3_snapshot_world_detach(uint32_t world) {
  Lease **p = &leases;
  while (*p) {
    Lease *l = *p;
    if (l->world == world) {
      *p = l->next;
      drop(l->resource);
      ogb3_snapshot_internal_free(l);
      return;
    }
    p = &l->next;
  }
}
/* Bounds-only preflight mirrors every section in world_snapshot.c v2. Captured
 * images also carry a seal: changes to scalar indices, geometry, or headers are
 * rejected before this walker or the destructive loader sees them. This is an
 * integrity boundary for trusted local resources, not an untrusted codec. */
typedef struct Cursor {
  const uint8_t *data;
  int size, pos;
  int ok;
} Cursor;
static void take(Cursor *c, void *out, uint64_t n) {
  if (!c->ok || n > (uint64_t)(c->size - c->pos)) {
    c->ok = 0;
    return;
  }
  if (out)
    memcpy(out, c->data + c->pos, (size_t)n);
  c->pos += (int)n;
}
static int number(Cursor *c) {
  int32_t n = 0;
  take(c, &n, 4);
  return n;
}
static void array(Cursor *c, uint64_t elem) {
  int n = number(c);
  if (n < 0) {
    c->ok = 0;
    return;
  }
  take(c, NULL, (uint64_t)n * elem);
}
static int count(Cursor *c, int minimum) {
  int n = number(c);
  if (n < 0 || (uint64_t)n * minimum > (uint64_t)(c->size - c->pos))
    c->ok = 0;
  return c->ok ? n : 0;
}
static int preflight(const Resource *r) {
  Cursor c = {r->image.data, r->image.size, 0, 1};
  take(&c, NULL, 16);
  take(&c, NULL,
       sizeof(b3Vec3) + 8 * sizeof(float) + sizeof(int32_t) + sizeof(uint64_t) + 4 +
           2 * sizeof(float));
  int end_index = number(&c);
  if (end_index < 0 || end_index > 1)
    c.ok = 0;
  number(&c); /* compoundShapeCount */
  take(&c, NULL, sizeof(b3Capacity) + 1);
  for (int i = 0; i < 6; i++) {
    int next = number(&c);
    if (next < 0)
      c.ok = 0;
    array(&c, 4);
  }
  int sets = count(&c, 24);
  for (int i = 0; i < sets && c.ok; i++) {
    number(&c);
    array(&c, sizeof(b3BodySim));
    array(&c, sizeof(b3BodyState));
    array(&c, sizeof(b3JointSim));
    array(&c, 4);
    array(&c, sizeof(b3IslandSim));
  }
  array(&c, sizeof(b3Body));
  int shapes = count(&c, sizeof(b3Shape) + 8);
  for (int i = 0; i < shapes && c.ok; i++) {
    b3Shape s;
    take(&c, &s, sizeof(s));
    array(&c, sizeof(b3SurfaceMaterial));
    int kind = number(&c);
    if (s.id != i) {
      if (kind != -1)
        c.ok = 0;
      continue;
    }
    if (kind != (int)s.type) {
      c.ok = 0;
      break;
    }
    if (kind == b3_sphereShape)
      take(&c, NULL, sizeof(b3Sphere));
    else if (kind == b3_capsuleShape)
      take(&c, NULL, sizeof(b3Capsule));
    else {
      int gid = number(&c);
      int expected = kind == b3_hullShape       ? b3_geometryHull
                     : kind == b3_meshShape     ? b3_geometryMesh
                     : kind == b3_heightShape   ? b3_geometryHeightField
                     : kind == b3_compoundShape ? b3_geometryCompound
                                                : -1;
      if (gid < 0 || gid >= r->recording->registry.entries.count || expected < 0 ||
          (int)r->slots[gid].kind != expected) {
        c.ok = 0;
        break;
      }
      if (kind == b3_meshShape)
        take(&c, NULL, sizeof(b3Vec3));
    }
  }
  array(&c,sizeof(b3AABB));
  int contacts = count(&c, sizeof(b3Contact) + 4);
  for (int i = 0; i < contacts && c.ok; i++) {
    b3Contact contact;
    take(&c, &contact, sizeof(contact));
    array(&c, sizeof(b3Manifold));
    if (contact.contactId == i && (contact.flags & b3_simMeshContact))
      array(&c, sizeof(b3TriangleCache));
  }
  array(&c, sizeof(b3Joint));
  int sensors = count(&c, 16);
  for (int i = 0; i < sensors && c.ok; i++) {
    number(&c);
    for (int j = 0; j < 3; j++)
      array(&c, sizeof(b3Visitor));
  }
  int islands = count(&c, 28);
  for (int i = 0; i < islands && c.ok; i++) {
    take(&c, NULL, 16);
    array(&c, 4);
    array(&c, sizeof(b3ContactLink));
    array(&c, sizeof(b3JointLink));
  }
  for(int i=0;i<b3_bodyTypeCount&&c.ok;i++){
    take(&c,NULL,8);int nodes=number(&c);number(&c);
    int proxies=number(&c),capacity=number(&c);number(&c);int dfs=number(&c);
    if(nodes<2||(nodes&1)||capacity<1||proxies<0||proxies>capacity||(dfs!=0&&dfs!=1)){c.ok=0;break;}
    take(&c,NULL,(uint64_t)nodes*(sizeof(b3TreeNode)+sizeof(int32_t)));
    take(&c,NULL,(uint64_t)capacity*sizeof(b3TreeProxy));
  }
  int capacity = number(&c), used = number(&c);
  if (capacity < 0 || used < 0 || used > capacity ||
      (capacity && (capacity & (capacity - 1))))
    c.ok = 0;
  if (c.ok)
    take(&c, NULL, (uint64_t)capacity * sizeof(b3SetItem));
  for (int i = 0; i < B3_GRAPH_COLOR_COUNT && c.ok; i++) {
    if (i != B3_OVERFLOW_INDEX)
      array(&c, 8);
    array(&c, sizeof(b3JointSim));
    array(&c, 4);
    array(&c, sizeof(b3ContactSpec));
  }
  int names = count(&c, 8);
  for (int i = 0; i < names && c.ok; i++) {
    number(&c);
    int n = number(&c);
    if (n < 0)
      c.ok = 0;
    else
      take(&c, NULL, n);
  }
  return c.ok && c.pos == c.size;
}
static int32_t validate(const ogb3_snapshot *s) {
  OGB3_OBS_BEGIN(observe_validate, OGB3_OBS_SNAPSHOT_VALIDATE_V1);
  if (!s || !s->resource)
    OGB3_OBS_RETURN(observe_validate, OGB3_INVALID_ARGUMENT);
  const Resource *r = s->resource;
  if (r->version != OGB3_SNAPSHOT_VERSION)
    OGB3_OBS_RETURN(observe_validate, OGB3_INCOMPATIBLE);
  uint64_t fingerprint = ogb3_build_fingerprint();
  if (!fingerprint)
    OGB3_OBS_RETURN(observe_validate, OGB3_CAPACITY);
  if (!r->fingerprint || r->fingerprint != fingerprint)
    OGB3_OBS_RETURN(observe_validate, OGB3_INCOMPATIBLE);
  if (r->sensor_pending_count > OGB3_SNAPSHOT_PENDING_END_CAPACITY ||
      r->contact_pending_count > OGB3_SNAPSHOT_PENDING_END_CAPACITY ||
      (r->sensor_pending_count && !r->sensor_pending) ||
      (r->contact_pending_count && !r->contact_pending))
    OGB3_OBS_RETURN(observe_validate, OGB3_CORRUPT);
  for (uint32_t i = 0; i < r->sensor_pending_count; i++)
    if (!shape_key_valid(r->sensor_pending[i].sensor) ||
        !shape_key_valid(r->sensor_pending[i].visitor))
      OGB3_OBS_RETURN(observe_validate, OGB3_CORRUPT);
  for (uint32_t i = 0; i < r->contact_pending_count; i++)
    if (!shape_key_valid(r->contact_pending[i].shape_a) ||
        !shape_key_valid(r->contact_pending[i].shape_b) ||
        !contact_key_valid(r->contact_pending[i].contact))
      OGB3_OBS_RETURN(observe_validate, OGB3_CORRUPT);
  if (r->image.size < 16 || seal(r) != r->seal)
    OGB3_OBS_RETURN(observe_validate, OGB3_CORRUPT);
  OGB3_OBS_RETURN(observe_validate, preflight(r) ? OGB3_OK : OGB3_CORRUPT);
}
/* Only capture's freshly allocated, unpublished local owner may enter here.
 * All allocations/caches are complete. Keep the existing metadata status order
 * and full structural walker, then establish the exact original seal once.
 * Public validate above still recomputes/compares seals on existing resources.
 * Observer callbacks bracket this pure interval and retain the existing
 * time-only/nonreentry contract; no callback/allocation/failpoint is inside it.
 */
static int32_t fresh_finish(ogb3_snapshot *s) {
  OGB3_OBS_BEGIN(observe_validate, OGB3_OBS_SNAPSHOT_VALIDATE_V1);
  if (!s || !s->resource)
    OGB3_OBS_RETURN(observe_validate, OGB3_INVALID_ARGUMENT);
  Resource *r = s->resource;
  if (r->version != OGB3_SNAPSHOT_VERSION)
    OGB3_OBS_RETURN(observe_validate, OGB3_INCOMPATIBLE);
  uint64_t fingerprint = ogb3_build_fingerprint();
  if (!fingerprint)
    OGB3_OBS_RETURN(observe_validate, OGB3_CAPACITY);
  if (!r->fingerprint || r->fingerprint != fingerprint)
    OGB3_OBS_RETURN(observe_validate, OGB3_INCOMPATIBLE);
  if (r->sensor_pending_count > OGB3_SNAPSHOT_PENDING_END_CAPACITY ||
      r->contact_pending_count > OGB3_SNAPSHOT_PENDING_END_CAPACITY ||
      (r->sensor_pending_count && !r->sensor_pending) ||
      (r->contact_pending_count && !r->contact_pending))
    OGB3_OBS_RETURN(observe_validate, OGB3_CORRUPT);
  for (uint32_t i = 0; i < r->sensor_pending_count; i++)
    if (!shape_key_valid(r->sensor_pending[i].sensor) ||
        !shape_key_valid(r->sensor_pending[i].visitor))
      OGB3_OBS_RETURN(observe_validate, OGB3_CORRUPT);
  for (uint32_t i = 0; i < r->contact_pending_count; i++)
    if (!shape_key_valid(r->contact_pending[i].shape_a) ||
        !shape_key_valid(r->contact_pending[i].shape_b) ||
        !contact_key_valid(r->contact_pending[i].contact))
      OGB3_OBS_RETURN(observe_validate, OGB3_CORRUPT);
  if (r->image.size < 16 || !preflight(r))
    OGB3_OBS_RETURN(observe_validate, OGB3_CORRUPT);
  r->seal = seal(r);
  OGB3_OBS_RETURN(observe_validate, OGB3_OK);
}
#ifdef OGB3_TESTING
/* One-shot controlled INTERNAL fresh faults, consumed BEFORE fresh_finish.
 * No caller bytes, external callback, allocation or post-check mutation gap. */
static void test_fresh_fault(Resource *r) {
  uint32_t mode = fresh_fault;
  fresh_fault = 0;
  switch (mode) {
  case 1: r->version++; break;
  case 2: r->fingerprint = 0; break;
  case 3: r->fingerprint ^= 1; break;
  case 4: r->sensor_pending_count = OGB3_SNAPSHOT_PENDING_END_CAPACITY + 1; break;
  case 5: r->contact_pending_count = OGB3_SNAPSHOT_PENDING_END_CAPACITY + 1; break;
  case 6: r->image.size = 15; break;
  case 7: r->image.size--; break;
  case 8:
    if (r->sensor_pending_count) r->sensor_pending[0].visitor = 0;
    else r->sensor_pending_count = 1;
    break;
  case 9:
    if (r->contact_pending_count) r->contact_pending[0].shape_a = 0;
    else r->contact_pending_count = 1;
    break;
  case 10:
    if (r->contact_pending_count) r->contact_pending[0].contact = 0;
    else r->contact_pending_count = 1;
    break;
  default: break;
  }
}
uint64_t ogb3_snapshot_test_stored_seal(const ogb3_snapshot *s) {
  return s->resource->seal;
}
uint64_t ogb3_snapshot_test_compute_seal(const ogb3_snapshot *s) {
  return seal(s->resource);
}
uint64_t ogb3_snapshot_test_pending_counts(const ogb3_snapshot *s) {
  return s->resource->sensor_pending_count |
         ((uint64_t)s->resource->contact_pending_count << 32);
}
#endif
/* Internal codec gate: bound trusted local image staging and reject unknown
 * geometry before opening any scratch execution. This grants no wire trust. */
int32_t ogb3_snapshot_recovery_preflight(const ogb3_snapshot *s,
                                         const ogb3_trusted_geometry *assets,
                                         uint32_t asset_count,
                                         uint32_t body_limit,
                                         uint64_t image_limit) {
  int32_t status = validate(s);
  if (status)
    return status;
  const Resource *r = s->resource;
  if (r->body_count > body_limit || (uint64_t)r->image.size > image_limit)
    return OGB3_CAPACITY;
  for (int i = 0; i < r->recording->registry.entries.count; ++i) {
    const b3GeometryEntry *g = r->recording->registry.entries.data + i;
    uint32_t kind=g->kind==b3_geometryHull ? OGB3_TRUSTED_HULL :
                  g->kind==b3_geometryMesh ? OGB3_TRUSTED_MESH : 0;
    if (!kind)
      return OGB3_UNSUPPORTED;
    int matched = 0;
    for (uint32_t j = 0; j < asset_count; ++j)
      if (assets[j].kind==kind && assets[j].bytes && g->byteCount>=0 &&
          assets[j].byte_count==(uint32_t)g->byteCount &&
          !memcmp(g->bytes, assets[j].bytes, g->byteCount))
        matched = 1;
    if (!matched)
      return OGB3_UNSUPPORTED;
  }
  return OGB3_OK;
}
static int32_t read_header(const ogb3_snapshot *s) {
  if (!s || !s->resource)
    return OGB3_INVALID_ARGUMENT;
  Resource *r = s->resource;
  if (r->version != OGB3_SNAPSHOT_VERSION)
    return OGB3_INCOMPATIBLE;
  uint64_t fp = ogb3_build_fingerprint();
  if (!fp)
    return OGB3_CAPACITY;
  return r->fingerprint && r->fingerprint == fp ? OGB3_OK : OGB3_INCOMPATIBLE;
}
static int32_t cache_bodies(Resource *r, b3World *w, uint32_t count) {
  r->body_count = count;
  if (!count)
    return OGB3_OK;
  r->bodies = ogb3_snapshot_internal_alloc((size_t)count * sizeof(*r->bodies));
  if (!r->bodies)
    return OGB3_OUT_OF_MEMORY;
  uint32_t n = 0;
  for (int i = 0; i < w->bodies.count; i++) {
    b3Body *b = w->bodies.data + i;
    if (b->id != i)
      continue;
    b3BodyId id = b3MakeBodyId(w, i);
    b3WorldTransform xf = b3Body_GetTransform(id);
    b3Vec3 linear = b3Body_GetLinearVelocity(id),
           angular = b3Body_GetAngularVelocity(id);
    ogb3_body_state *dst = r->bodies + n++;
    memset(dst, 0, sizeof(*dst));
    dst->key = (uint32_t)(i + 1) | ((uint64_t)b->generation << 32);
    dst->pose = (ogb3_pose){{xf.p.x, xf.p.y, xf.p.z},
                            {xf.q.v.x, xf.q.v.y, xf.q.v.z, xf.q.s}};
    dst->linear_velocity = (ogb3_vec3){linear.x, linear.y, linear.z};
    dst->angular_velocity = (ogb3_vec3){angular.x, angular.y, angular.z};
    dst->mass = b->mass;
    dst->type = (int32_t)b->type;
    dst->is_awake = b->setIndex == b3_awakeSet;
    dst->is_enabled = b->setIndex != b3_disabledSet;
  }
  assert(n == count);
  return OGB3_OK;
}
int32_t ogb3_snapshot_body_state(const ogb3_snapshot *s, ogb3_body_key key,
                                 ogb3_body_state *out) {
  if (!out || (uint32_t)key == 0 || (uint32_t)key > INT32_MAX ||
      (key >> 32) > UINT16_MAX)
    return OGB3_INVALID_ARGUMENT;
  int32_t status = read_header(s);
  if (status)
    return status;
  Resource *r = s->resource;
  uint32_t lo = 0, hi = r->body_count, index = (uint32_t)key;
  while (lo < hi) {
    uint32_t mid = lo + (hi - lo) / 2;
    if ((uint32_t)r->bodies[mid].key < index)
      lo = mid + 1;
    else
      hi = mid;
  }
  if (lo >= r->body_count || r->bodies[lo].key != key)
    return OGB3_INVALID_HANDLE;
  *out = r->bodies[lo];
  return OGB3_OK;
}
int32_t ogb3_snapshot_body_states(const ogb3_snapshot *s, ogb3_body_state *out,
                                  uint32_t capacity, uint32_t *required) {
  if (!required || (!out && capacity))
    return OGB3_INVALID_ARGUMENT;
  int32_t status = read_header(s);
  if (status)
    return status;
  Resource *r = s->resource;
  *required = r->body_count;
  if (!out)
    return OGB3_OK;
  if (capacity < r->body_count)
    return OGB3_CAPACITY;
  if (r->body_count)
    memcpy(out, r->bodies, (size_t)r->body_count * sizeof(*out));
  return OGB3_OK;
}
static int32_t cache_pending(Resource *r, const b3World *w) {
  int index = w->endEventArrayIndex;
  r->sensor_pending_count = (uint32_t)w->sensorEndEvents[index].count;
  r->contact_pending_count = (uint32_t)w->contactEndEvents[index].count;
  if (r->sensor_pending_count) {
    r->sensor_pending = ogb3_snapshot_internal_alloc(
        (size_t)r->sensor_pending_count * sizeof(*r->sensor_pending));
    if (!r->sensor_pending)
      return OGB3_OUT_OF_MEMORY;
    for (uint32_t i = 0; i < r->sensor_pending_count; i++) {
      const b3SensorEndTouchEvent *e = w->sensorEndEvents[index].data + i;
      r->sensor_pending[i] =
          (PendingSensorEnd){local_shape_key(e->sensorShapeId),
                             local_shape_key(e->visitorShapeId)};
    }
  }
  if (r->contact_pending_count) {
    r->contact_pending = ogb3_snapshot_internal_alloc(
        (size_t)r->contact_pending_count * sizeof(*r->contact_pending));
    if (!r->contact_pending)
      return OGB3_OUT_OF_MEMORY;
    for (uint32_t i = 0; i < r->contact_pending_count; i++) {
      const b3ContactEndTouchEvent *e = w->contactEndEvents[index].data + i;
      r->contact_pending[i] = (PendingContactEnd){
          local_shape_key(e->shapeIdA), local_shape_key(e->shapeIdB),
          local_contact_key(e->contactId)};
    }
  }
  return OGB3_OK;
}
static b3ShapeId pending_shape_id(uint64_t key, uint16_t world0) {
  b3ShapeId id = {(int32_t)(uint32_t)key, world0, (uint16_t)(key >> 32)};
  return id;
}
static void import_pending(const Resource *r, b3World *c,
                           uint16_t destination) {
  int index = c->endEventArrayIndex;
  assert(index == 0 || index == 1);
  b3Array_Resize(c->sensorEndEvents[index], (int)r->sensor_pending_count);
  b3Array_Resize(c->contactEndEvents[index], (int)r->contact_pending_count);
  for (uint32_t i = 0; i < r->sensor_pending_count; i++) {
    const PendingSensorEnd *e = r->sensor_pending + i;
    c->sensorEndEvents[index].data[i] =
        (b3SensorEndTouchEvent){pending_shape_id(e->sensor, destination),
                                pending_shape_id(e->visitor, destination)};
  }
  for (uint32_t i = 0; i < r->contact_pending_count; i++) {
    const PendingContactEnd *e = r->contact_pending + i;
    b3ContactId id = {.index1 = (int32_t)(uint32_t)e->contact,
                      .world0 = destination,
                      .padding = 0,
                      .generation = (uint32_t)(e->contact >> 32)};
    c->contactEndEvents[index].data[i] =
        (b3ContactEndTouchEvent){pending_shape_id(e->shape_a, destination),
                                 pending_shape_id(e->shape_b, destination), id};
  }
}
int32_t ogb3_snapshot_capture(uint32_t packed, ogb3_snapshot **out) {
  OGB3_OBS_BEGIN(observe_capture, OGB3_OBS_SNAPSHOT_CAPTURE_V1);
  if (!out)
    OGB3_OBS_RETURN(observe_capture, OGB3_INVALID_ARGUMENT);
  *out = NULL;
  b3WorldId world;
  _Static_assert(sizeof(world) == sizeof(packed), "world packing");
  memcpy(&world, &packed, sizeof(world));
  if (!b3World_IsValid(world))
    OGB3_OBS_RETURN(observe_capture, OGB3_INVALID_HANDLE);
  b3World *w = b3GetWorldFromId(world);
  if (!w->inUse)
    OGB3_OBS_RETURN(observe_capture, OGB3_INVALID_HANDLE);
  if (w->locked || w->workerCount != 1)
    OGB3_OBS_RETURN(observe_capture, OGB3_UNSUPPORTED);
  uint64_t fingerprint = ogb3_build_fingerprint();
  if (!fingerprint)
    OGB3_OBS_RETURN(observe_capture, OGB3_CAPACITY);
  if (w->endEventArrayIndex < 0 || w->endEventArrayIndex > 1)
    OGB3_OBS_RETURN(observe_capture, OGB3_CORRUPT);
  int pending_index = w->endEventArrayIndex;
  if (w->sensorEndEvents[pending_index].count < 0 ||
      w->contactEndEvents[pending_index].count < 0)
    OGB3_OBS_RETURN(observe_capture, OGB3_CORRUPT);
  uint32_t queue_limit = OGB3_SNAPSHOT_PENDING_END_CAPACITY;
#ifdef OGB3_TESTING
  if (pending_limit < queue_limit)
    queue_limit = pending_limit;
#endif
  if ((uint32_t)w->sensorEndEvents[pending_index].count > queue_limit ||
      (uint32_t)w->contactEndEvents[pending_index].count > queue_limit)
    OGB3_OBS_RETURN(observe_capture, OGB3_CAPACITY);
  uint32_t body_count = 0;
  for (int i = 0; i < w->bodies.count; i++)
    if (w->bodies.data[i].id == i)
      body_count++;
  uint32_t limit = OGB3_SNAPSHOT_BODY_CAPACITY;
#ifdef OGB3_TESTING
  if (pose_limit < limit)
    limit = pose_limit;
#endif
  if (body_count > limit)
    OGB3_OBS_RETURN(observe_capture, OGB3_CAPACITY);
  Resource *r = wrapper_calloc(1, sizeof(*r));
  ogb3_snapshot *s = wrapper_calloc(1, sizeof(*s));
  if (!r || !s) {
    ogb3_snapshot_internal_free(r);
    ogb3_snapshot_internal_free(s);
    OGB3_OBS_RETURN(observe_capture, OGB3_OUT_OF_MEMORY);
  }
  r->refs = 1;
  r->version = OGB3_SNAPSHOT_VERSION;
  r->fingerprint = fingerprint;
  int native_before = b3GetByteCount();
  r->recording = b3CreateRecording(0);
  if (!r->recording) {
    drop(r);
    ogb3_snapshot_internal_free(s);
    OGB3_OBS_RETURN(observe_capture, OGB3_OUT_OF_MEMORY);
  }
  OGB3_OBS_BEGIN(observe_serialize, OGB3_OBS_SNAPSHOT_SERIALIZE_V1);
  b3SerializeWorld(w, &r->image, r->recording);
  int count = r->recording->registry.entries.count;
  r->slots = wrapper_calloc((size_t)(count ? count : 1), sizeof(*r->slots));
  if (!r->slots) {
    OGB3_OBS_END(observe_serialize, OGB3_OBS_STATUS_UNAVAILABLE_V1);
    drop(r);
    ogb3_snapshot_internal_free(s);
    OGB3_OBS_RETURN(observe_capture, OGB3_OUT_OF_MEMORY);
  }
  for (int i = 0; i < count; i++) {
    const b3GeometryEntry *g = r->recording->registry.entries.data + i;
    r->slots[i].kind = g->kind;
    r->slots[i].byteCount = g->byteCount;
    r->slots[i].bytes = g->bytes;
    r->geometry_bytes += g->byteCount;
  }
  OGB3_OBS_END(observe_serialize, OGB3_OBS_STATUS_UNAVAILABLE_V1);
  OGB3_OBS_BEGIN(observe_normalize, OGB3_OBS_SNAPSHOT_NORMALIZE_V1);
  int32_t status = ogb3_state_dump_alloc_internal(
      packed, &r->normalized, &r->normalized_size);
  OGB3_OBS_END(observe_normalize, status);
  OGB3_OBS_BEGIN(observe_finalize, status ? 0 : OGB3_OBS_SNAPSHOT_FINALIZE_V1);
  if (!status)
    status = cache_bodies(r, w, body_count);
  if (!status)
    status = cache_pending(r, w);
  if (status) {
    drop(r);
    ogb3_snapshot_internal_free(s);
    OGB3_OBS_END(observe_finalize, status);
    OGB3_OBS_RETURN(observe_capture, status);
  }
  r->complete = 0;
  r->complete_ready = 0;
  r->motion = b3HashWorldState(w);
  r->native_requested_bytes = (uint64_t)(b3GetByteCount() - native_before);
  s->resource = r;
#ifdef OGB3_TESTING
  test_fresh_fault(r);
#endif
  status = fresh_finish(s);
  if (status) {
    ogb3_snapshot_release(s);
    OGB3_OBS_END(observe_finalize, status);
    OGB3_OBS_RETURN(observe_capture, status);
  }
  *out = s;
  OGB3_OBS_END(observe_finalize, OGB3_OK);
  OGB3_OBS_RETURN(observe_capture, OGB3_OK);
}
int32_t ogb3_snapshot_clone(const ogb3_snapshot *s, ogb3_snapshot **out) {
  if (!out)
    return OGB3_INVALID_ARGUMENT;
  *out = NULL;
  int32_t status = validate(s);
  if (status)
    return status;
  ogb3_snapshot *clone = ogb3_snapshot_internal_alloc(sizeof(*clone));
  if (!clone)
    return OGB3_OUT_OF_MEMORY;
  if (s->resource->refs == UINT32_MAX) {
    ogb3_snapshot_internal_free(clone);
    return OGB3_CAPACITY;
  }
  clone->resource = s->resource;
  clone->resource->refs++;
  *out = clone;
  return OGB3_OK;
}
void ogb3_snapshot_release(ogb3_snapshot *s) {
  if (s) {
    drop(s->resource);
    ogb3_snapshot_internal_free(s);
  }
}

int32_t ogb3_snapshot_restore(uint32_t packed, const ogb3_snapshot *s) {
  int32_t status = validate(s);
  if (status)
    return status;
  b3WorldId id;
  memcpy(&id, &packed, sizeof(id));
  if (!b3World_IsValid(id))
    return OGB3_INVALID_HANDLE;
  b3World *w = b3GetWorldFromId(id);
  if (!w->inUse)
    return OGB3_INVALID_HANDLE;
  if (w->locked || w->workerCount != 1 || w->recording)
    return OGB3_UNSUPPORTED;
  /* Reserve every fallible wrapper allocation before touching native state. */
  Lease *lease = wrapper_calloc(1, sizeof(*lease));
  if (!lease)
    return OGB3_OUT_OF_MEMORY;
#ifdef OGB3_TESTING
  if (fail_stage == 1) {
    ogb3_snapshot_internal_free(lease);
    return OGB3_OUT_OF_MEMORY;
  }
#endif
  if (b3GetWorldCount() >= B3_MAX_WORLDS) {
    ogb3_snapshot_internal_free(lease);
    return OGB3_CAPACITY;
  }
  b3WorldDef def = b3DefaultWorldDef();
  def.workerCount = 1;
  b3WorldId candidate = b3CreateWorld(&def);
  if (!b3World_IsValid(candidate)) {
    ogb3_snapshot_internal_free(lease);
    return OGB3_CAPACITY;
  }
  b3World *c = b3GetWorldFromId(candidate);
#ifdef OGB3_TESTING
  if (fail_stage == 2) {
    b3DestroyWorld(candidate);
    ogb3_snapshot_internal_free(lease);
    return OGB3_OUT_OF_MEMORY;
  }
#endif
  Resource *r = s->resource;
  b3RecReader reader = {0};
  reader.ok = true;
  reader.replayWorldId = candidate;
  reader.slots = r->slots;
  reader.slotCount = r->recording->registry.entries.count;
  /* Only a sealed locally created resource with a full structural pass reaches
   * this call. Upstream allocations abort on exhaustion; there is no fallible
   * allocation API or post-allocation false return in this accepted path. */
  bool loaded =
      b3DeserializeIntoShell(r->image.data, r->image.size, c, &reader);
  if (!loaded) {
    /* An exact-build invariant failure cannot be returned as recoverable:
     * upstream partial worlds do not satisfy normal destructor invariants. */
    abort();
  }
  /* The pinned sensor append macro performs pointer arithmetic and memcpy
   * even for zero hits. Match constructor storage minima after the serializer
   * restores only logical counts; capacities are not normalized state. */
  for (int i = 0; i < c->sensors.count; ++i) {
    b3Sensor *sensor = c->sensors.data + i;
    b3Array_Reserve(sensor->hits, 4);
    b3Array_Reserve(sensor->overlaps1, 16);
    b3Array_Reserve(sensor->overlaps2, 16);
  }
  /* Restore future delivery queues in the disposable candidate. IDs target
   * the published destination, not the temporary candidate world slot. */
  import_pending(r, c, w->worldId);
#ifdef OGB3_TESTING
  if (fail_stage == 3) {
    b3DestroyWorld(candidate);
    ogb3_snapshot_internal_free(lease);
    return OGB3_OUT_OF_MEMORY;
  }
#endif
  if (r->refs == UINT32_MAX) {
    b3DestroyWorld(candidate);
    ogb3_snapshot_internal_free(lease);
    return OGB3_CAPACITY;
  }
  r->refs++;
  /* Swap simulation-owned storage only. Destination identity, callbacks,
   * worker scratch, host userData and scheduler remain destination-owned. */
#define SWAP(f)                                                                \
  do {                                                                         \
    unsigned char tmp[sizeof(w->f)];                                           \
    memcpy(tmp, &w->f, sizeof(tmp));                                           \
    memcpy(&w->f, &c->f, sizeof(tmp));                                         \
    memcpy(&c->f, tmp, sizeof(tmp));                                           \
  } while (0)
  SWAP(broadPhase);
  SWAP(constraintGraph);
  SWAP(manifoldAllocators);
  SWAP(manifoldAllocatorMutex);
  SWAP(bodyIdPool);
  SWAP(shapeIdPool);
  SWAP(contactIdPool);
  SWAP(jointIdPool);
  SWAP(islandIdPool);
  SWAP(solverSetIdPool);
  SWAP(bodies);
  SWAP(shapes);
  SWAP(fatAABBs);
  SWAP(contacts);
  SWAP(joints);
  SWAP(islands);
  SWAP(solverSets);
  SWAP(sensors);
  SWAP(sensorEndEvents);
  SWAP(contactEndEvents);
  SWAP(hullDatabase);
  SWAP(names);
  SWAP(gravity);
  SWAP(hitEventThreshold);
  SWAP(restitutionThreshold);
  SWAP(maxLinearSpeed);
  SWAP(contactSpeed);
  SWAP(contactHertz);
  SWAP(contactDampingRatio);
  SWAP(contactRecycleDistance);
  SWAP(restitutionIterations);SWAP(enableRestitutionPropagation);SWAP(isotropicInertiaTolerance);
  SWAP(compoundShapeCount);SWAP(simdWidth);
  SWAP(stepIndex);
  SWAP(splitIslandId);
  SWAP(inv_h);
  SWAP(inv_dt);
  SWAP(endEventArrayIndex);
  SWAP(maxCapacity);
  SWAP(enableSleep);
  SWAP(enableWarmStarting);
  SWAP(enableContinuous);
  SWAP(enableSpeculative);
#undef SWAP
  /* Destructor of old published simulation must see its original shape host
   * teardown callback; host callbacks are never called while staging. */
  c->destroyDebugShape = w->destroyDebugShape;
  c->userDebugShapeContext = w->userDebugShapeContext;
  b3DestroyWorld(candidate);
  ogb3_snapshot_world_detach(packed);
  lease->world = packed;
  lease->resource = r;
  lease->next = leases;
  leases = lease;
  /* Completed outputs are not checkpoint inputs. The candidate supplied empty
   * completed end buffers plus the captured future delivery queues. Keep those
   * queues; clear only completed/transient outputs and their body linkage. */
  for (int i = 0; i < w->bodies.count; i++)
    w->bodies.data[i].bodyMoveIndex = B3_NULL_INDEX;
  w->bodyMoveEvents.count = 0;
  w->sensorBeginEvents.count = 0;
  w->contactBeginEvents.count = 0;
  w->contactHitEvents.count = 0;
  w->jointEvents.count = 0;
  return OGB3_OK;
}
static void storage_values(const ogb3_snapshot *s, uint64_t *normalized,
                           uint64_t *wrapper, uint64_t *native) {
  Resource *r = s->resource;
  *normalized = r->normalized_size;
  *wrapper =
      sizeof(*s) + sizeof(*r) + r->normalized_size +
      (uint64_t)r->body_count * sizeof(*r->bodies) +
      (uint64_t)r->sensor_pending_count * sizeof(*r->sensor_pending) +
      (uint64_t)r->contact_pending_count * sizeof(*r->contact_pending) +
      (uint64_t)(r->recording->registry.entries.count ? r->recording->registry.entries.count
                                              : 1) *
          sizeof(*r->slots);
  *native = r->native_requested_bytes;
}
int32_t ogb3_snapshot_storage(const ogb3_snapshot *s, uint64_t *normalized,
                              uint64_t *wrapper, uint64_t *native) {
  if (!normalized || !wrapper || !native)
    return OGB3_INVALID_ARGUMENT;
  int32_t status = validate(s);
  if (status)
    return status;
  storage_values(s, normalized, wrapper, native);
  return OGB3_OK;
}
typedef struct SnapshotInfoValues {
  uint64_t used, capacity, geometry, normalized, wrapper, native;
  uint32_t count;
} SnapshotInfoValues;
static SnapshotInfoValues info_values(const ogb3_snapshot *s) {
  const Resource *r = s->resource;
  SnapshotInfoValues v = {.used = r->image.size,
                          .capacity = r->image.capacity,
                          .geometry = r->geometry_bytes,
                          .count = r->recording->registry.entries.count};
  storage_values(s, &v.normalized, &v.wrapper, &v.native);
  return v;
}
static void publish_info(SnapshotInfoValues v, uint64_t *used,
                         uint64_t *capacity, uint64_t *geometry,
                         uint32_t *count, uint64_t *normalized,
                         uint64_t *wrapper, uint64_t *native) {
  *used = v.used;
  *capacity = v.capacity;
  *geometry = v.geometry;
  *count = v.count;
  *normalized = v.normalized;
  *wrapper = v.wrapper;
  *native = v.native;
}
/* Hidden cross-module helper; ONLY an immediately checked LOCAL constructor
 * owner may reach this function. It is not in the public header/DSO exports. */
void ogb3_snapshot_local_info(const ogb3_snapshot *s, uint64_t *used,
                              uint64_t *capacity, uint64_t *geometry,
                              uint32_t *count, uint64_t *normalized,
                              uint64_t *wrapper, uint64_t *native) {
  SnapshotInfoValues v = info_values(s);
  publish_info(v, used, capacity, geometry, count, normalized, wrapper, native);
}
/* Capture finishes its private full structural checks and seal initialization;
 * clone finishes full existing-resource validate(s), before returning a local
 * owner. No callback/alias can observe it between that constructor boundary and
 * these pure metadata reads. Public getters/clone/restore checks are unchanged.
 */
int32_t ogb3_snapshot_capture_info(uint32_t world, ogb3_snapshot **out,
                                   uint64_t *used, uint64_t *capacity,
                                   uint64_t *geometry, uint32_t *count,
                                   uint64_t *normalized, uint64_t *wrapper,
                                   uint64_t *native) {
  if (!out)
    return OGB3_INVALID_ARGUMENT;
  *out = NULL;
  if (!used || !capacity || !geometry || !count || !normalized || !wrapper ||
      !native)
    return OGB3_INVALID_ARGUMENT;
  ogb3_snapshot *local = NULL;
  int32_t status = ogb3_snapshot_capture(world, &local);
  if (status) {
    if (local)
      ogb3_snapshot_release(local);
    return status;
  }
  SnapshotInfoValues v = info_values(local);
  publish_info(v, used, capacity, geometry, count, normalized, wrapper, native);
  *out = local;
  return OGB3_OK;
}
int32_t ogb3_snapshot_clone_info(const ogb3_snapshot *source,
                                 ogb3_snapshot **out, uint64_t *used,
                                 uint64_t *capacity, uint64_t *geometry,
                                 uint32_t *count, uint64_t *normalized,
                                 uint64_t *wrapper, uint64_t *native) {
  if (!out)
    return OGB3_INVALID_ARGUMENT;
  *out = NULL;
  if (!used || !capacity || !geometry || !count || !normalized || !wrapper ||
      !native)
    return OGB3_INVALID_ARGUMENT;
  ogb3_snapshot *local = NULL;
  int32_t status = ogb3_snapshot_clone(source, &local);
  if (status) {
    if (local)
      ogb3_snapshot_release(local);
    return status;
  }
  SnapshotInfoValues v = info_values(local);
  publish_info(v, used, capacity, geometry, count, normalized, wrapper, native);
  *out = local;
  return OGB3_OK;
}
int32_t ogb3_snapshot_info(const ogb3_snapshot *s, uint64_t *used,
                           uint64_t *capacity, uint64_t *geometry,
                           uint32_t *count, uint64_t *normalized,
                           uint64_t *wrapper, uint64_t *native) {
  if (!used || !capacity || !geometry || !count || !normalized || !wrapper ||
      !native)
    return OGB3_INVALID_ARGUMENT;
  int32_t status =
      validate(s); /* One identical full seal + structural check. */
  if (status)
    return status;
  const Resource *r = s->resource;
  storage_values(s, normalized, wrapper, native);
  *used = r->image.size;
  *capacity = r->image.capacity;
  *geometry = r->geometry_bytes;
  *count = r->recording->registry.entries.count;
  return OGB3_OK;
}
int32_t ogb3_snapshot_metrics(const ogb3_snapshot *s, uint64_t *used,
                              uint64_t *capacity, uint64_t *geometry,
                              uint32_t *count) {
  if (!used || !capacity || !geometry || !count)
    return OGB3_INVALID_ARGUMENT;
  int32_t status = validate(s);
  if (status)
    return status;
  const Resource *r = s->resource;
  *used = r->image.size;
  *capacity = r->image.capacity;
  *geometry = r->geometry_bytes;
  *count = r->recording->registry.entries.count;
  return OGB3_OK;
}
int32_t ogb3_snapshot_dump(const ogb3_snapshot *s, uint8_t *bytes,
                           uint64_t capacity, uint64_t *required) {
  if (!required || (!bytes && capacity))
    return OGB3_INVALID_ARGUMENT;
  int32_t status = validate(s);
  if (status)
    return status;
  Resource *r = s->resource;
  *required = r->normalized_size;
  if (!bytes)
    return OGB3_OK;
  if (capacity < r->normalized_size)
    return OGB3_CAPACITY;
  memcpy(bytes, r->normalized, (size_t)r->normalized_size);
  return OGB3_OK;
}
int32_t ogb3_snapshot_digest(const ogb3_snapshot *s, uint64_t *complete,
                             uint64_t *motion) {
  if (!complete || !motion)
    return OGB3_INVALID_ARGUMENT;
  int32_t status = validate(s);
  if (status)
    return status;
  Resource *r = s->resource;
  if (!r->complete_ready) {
    r->complete = hash_bytes(14695981039346656037ull, r->normalized,
                             (size_t)r->normalized_size);
    r->complete_ready = 1;
  }
  *complete = r->complete;
  *motion = r->motion;
  return OGB3_OK;
}
#ifdef OGB3_TESTING
/* Tests can submit deliberately bad candidate bytes but cannot bless them. This
 * gate is the only raw-image test surface and never loads changed input. */
int32_t ogb3_snapshot_test_pending_corrupt_restore(uint32_t world,
                                                   ogb3_snapshot *s) {
  if (!s->resource->sensor_pending_count)
    return OGB3_INVALID_ARGUMENT;
  s->resource->sensor_pending[0].visitor ^= UINT64_C(1) << 32;
  int32_t status = ogb3_snapshot_restore(world, s);
  s->resource->sensor_pending[0].visitor ^= UINT64_C(1) << 32;
  return status;
}
int32_t ogb3_snapshot_test_incompatible(uint32_t world, ogb3_snapshot *s) {
  uint32_t saved = s->resource->version;
  s->resource->version++;
  int32_t status = ogb3_snapshot_restore(world, s);
  s->resource->version = saved;
  return status;
}
const uint8_t *ogb3_snapshot_test_image(const ogb3_snapshot *s,
                                        uint64_t *size) {
  *size = s->resource->image.size;
  return s->resource->image.data;
}
int32_t ogb3_snapshot_test_restore_bytes(uint32_t world, const ogb3_snapshot *s,
                                         const uint8_t *data, uint64_t size) {
  int32_t status = validate(s);
  if (status)
    return status;
  if (!data || size > (uint64_t)s->resource->image.size)
    return OGB3_CORRUPT;
  Resource *r = s->resource;
  uint8_t *saved_data = r->image.data;
  int saved_size = r->image.size;
  r->image.data = (uint8_t *)data;
  r->image.size = (int)size;
  status = ogb3_snapshot_restore(world, s);
  r->image.data = saved_data;
  r->image.size = saved_size;
  return status;
}
#endif
