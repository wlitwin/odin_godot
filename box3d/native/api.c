#include "native_observe_internal.h"
/* Local flat ABI over the pinned MIT Box3D engine. See THIRD_PARTY_NOTICES.txt.
 */
#include "api.h"
#include "api_internal.h"
#include "box3d/box3d.h"
#include "box3d/constants.h" /* pinned B3_MAX_WORLDS, not high-water b3GetMaxWorldCount */
#include "physics_world.h" /* pinned inUse validity guard */
#include "body.h"
#include "shape.h"
#include "rollback_shim.h"
#include "simd.h" /* explicit width selection for the pinned single-worker profile */
#ifdef OGB3_HAS_SNAPSHOTS
#include "owned_snapshot.h"
#endif
#ifdef OGB3_HAS_STATE_DUMP
#include "state_dump.h"
#endif
#ifdef OGB3_HAS_RECOVERY
#include "recovery_codec.h"
#endif
#include <assert.h>
#include <limits.h>
#include <math.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

_Static_assert(sizeof(float) == 4 && sizeof(b3Pos) == 12 &&
                   sizeof(b3Vec3) == 12,
               "single precision ABI");
_Static_assert(sizeof(b3WorldId) == 4 && sizeof(b3BodyId) == 8 &&
                   sizeof(b3ShapeId) == 8 && sizeof(b3JointId) == 8,
               "handle ABI");
_Static_assert(offsetof(b3BodyId, index1) == 0 &&
                   offsetof(b3BodyId, world0) == 4 &&
                   offsetof(b3BodyId, generation) == 6,
               "body ID layout");
_Static_assert(offsetof(b3ShapeId, index1) == 0 &&
                   offsetof(b3ShapeId, world0) == 4 &&
                   offsetof(b3ShapeId, generation) == 6,
               "shape ID layout");
_Static_assert(offsetof(b3JointId, index1) == 0 &&
                   offsetof(b3JointId, world0) == 4 &&
                   offsetof(b3JointId, generation) == 6,
               "joint ID layout");
_Static_assert(offsetof(b3WorldId, index1) == 0 &&
                   offsetof(b3WorldId, generation) == 2,
               "world ID layout");
_Static_assert(b3_staticBody == OGB3_STATIC &&
                   b3_kinematicBody == OGB3_KINEMATIC &&
                   b3_dynamicBody == OGB3_DYNAMIC,
               "body enum");
static b3WorldId world_id(uint32_t x) {
  b3WorldId y;
  memcpy(&y, &x, sizeof y);
  return y;
}
static uint32_t world_bits(b3WorldId x) {
  uint32_t y;
  memcpy(&y, &x, sizeof y);
  return y;
}
static b3BodyId body_id(uint64_t x) {
  b3BodyId y;
  memcpy(&y, &x, sizeof y);
  return y;
}
static uint64_t body_bits(b3BodyId x) {
  uint64_t y;
  memcpy(&y, &x, sizeof y);
  return y;
}
static b3ShapeId shape_id(uint64_t x) {
  b3ShapeId y;
  memcpy(&y, &x, sizeof y);
  return y;
}
static uint64_t shape_bits(b3ShapeId x) {
  uint64_t y;
  memcpy(&y, &x, sizeof y);
  return y;
}
static b3JointId joint_id(uint64_t x) {
  b3JointId y;
  memcpy(&y, &x, sizeof y);
  return y;
}
static uint64_t joint_bits(b3JointId x) {
  uint64_t y;
  memcpy(&y, &x, sizeof y);
  return y;
}
static b3Vec3 vec(ogb3_vec3 v) { return (b3Vec3){v.x, v.y, v.z}; }
static ogb3_vec3 outvec(b3Vec3 v) { return (ogb3_vec3){v.x, v.y, v.z}; }
static b3Quat quat(ogb3_quat q) { return (b3Quat){{q.x, q.y, q.z}, q.w}; }
static int validvec(const ogb3_vec3 *v) {
  return v && isfinite(v->x) && isfinite(v->y) && isfinite(v->z);
}
static int validpose(const ogb3_pose *p) {
  if (!p || !validvec(&p->position))
    return 0;
  const ogb3_quat *q = &p->rotation;
  float n = q->x * q->x + q->y * q->y + q->z * q->z + q->w * q->w;
  return isfinite(n) && b3IsNormalizedQuat(quat(*q));
}
static int world_is_valid(ogb3_world w) {
  b3WorldId id = world_id(w);
  return b3World_IsValid(id) && b3GetWorldFromId(id)->inUse;
}
#define ARG(x)                                                                 \
  do {                                                                         \
    if (!(x))                                                                  \
      return OGB3_INVALID_ARGUMENT;                                            \
  } while (0)
#define WORLD(x)                                                               \
  do {                                                                         \
    if (!world_is_valid(x))                                                    \
      return OGB3_INVALID_HANDLE;                                              \
  } while (0)
#define BODY(x)                                                                \
  do {                                                                         \
    if (!b3Body_IsValid(body_id(x)))                                           \
      return OGB3_INVALID_HANDLE;                                              \
  } while (0)
#define SHAPE(x)                                                               \
  do {                                                                         \
    if (!(shape_id(x).index1 > 0 && b3Shape_IsValid(shape_id(x))))             \
      return OGB3_INVALID_HANDLE;                                              \
  } while (0)
#define JOINT(x)                                                               \
  do {                                                                         \
    if (!(joint_id(x).index1 > 0 && b3Joint_IsValid(joint_id(x))))             \
      return OGB3_INVALID_HANDLE;                                              \
  } while (0)
static int nonnegative(float x) { return isfinite(x) && x >= 0; }
/* Nonnegative and within the snapshot codec's 1e6 bound, so any created world
 * stays restorable. */
static int bounded(float x) { return nonnegative(x) && x <= 1e6f; }

/* Process-global, single caller counters. Box3D's allocator OOM is an
 * assertion, not a recoverable status; these measure engine requested bytes
 * only. */
static ogb3_allocation_stats allocations;
static int initialized;
static uint64_t fingerprint;
static float length_units_per_meter = 1.0f;
/* The address identifies this loaded engine image, even when another image
 * contains byte-identical code. It is never a portable identity. The host is
 * responsible for keeping this image loaded throughout owner/callback use. */
static unsigned char domain_anchor;
typedef struct {
  uint64_t producer, component, live, reserved;
  uint32_t generation, active;
} host_slot;
static host_slot host_slots[OGB3_HOST_OWNER_CAPACITY];
static uint64_t host_live, host_reserved, host_committed_peak, host_updates;
static uint32_t host_count;
_Static_assert(sizeof(uintptr_t) <= sizeof(uint64_t), "domain cookie width");
_Static_assert(sizeof(ogb3_domain_contract) == 104 &&
                   sizeof(ogb3_host_owner_info) == 32 &&
                   sizeof(ogb3_host_ledger_stats) == 88,
               "fixed domain/ledger ABI");
static uint64_t domain_cookie(void) {
  return (uint64_t)(uintptr_t)&domain_anchor;
}
#ifndef OGB3_RECOVERY_BUILD_ID
#define OGB3_RECOVERY_BUILD_ID "unverified"
#endif
#ifndef OGB3_NATIVE_TARGET_ID
#define OGB3_NATIVE_TARGET_ID "unverified"
#endif
static int decode_build_hash(const char *s, uint8_t out[32]) {
  if (strlen(s) != 64)
    return 0;
  for (unsigned i = 0; i < 32; ++i) {
    unsigned byte = 0;
    for (unsigned j = 0; j < 2; ++j) {
      unsigned char c = (unsigned char)s[2 * i + j];
      unsigned n;
      if (c >= '0' && c <= '9')
        n = c - '0';
      else if (c >= 'a' && c <= 'f')
        n = c - 'a' + 10;
      else
        return 0;
      byte = 16 * byte + n;
    }
    out[i] = (uint8_t)byte;
  }
  return 1;
}
static ogb3_status domain_contract(ogb3_domain_contract *out) {
  ogb3_domain_contract c = {0};
  c.cookie = domain_cookie();
  c.size = sizeof c;
  c.version = OGB3_DOMAIN_CONTRACT_VERSION;
  c.abi_version = ogb3_abi_version();
#ifdef OGB3_HAS_STATE_DUMP
  c.logical_version = OGB3_STATE_DUMP_VERSION;
#endif
#ifdef OGB3_HAS_SNAPSHOTS
  c.resource_version = OGB3_SNAPSHOT_VERSION;
#endif
#ifdef OGB3_HAS_RECOVERY
  c.recovery_version = OGB3_RECOVERY_FORMAT;
#endif
  c.pointer_bits = sizeof(void *) * CHAR_BIT;
  const uint32_t endian = 1;
  c.endian = *(const uint8_t *)&endian ? 1 : 2;
  if (!decode_build_hash(OGB3_RECOVERY_BUILD_ID, c.build) ||
      !decode_build_hash(OGB3_NATIVE_TARGET_ID, c.target))
    return OGB3_INCOMPATIBLE;
  *out = c;
  return OGB3_OK;
}
ogb3_status ogb3_domain_contract_get(ogb3_domain_contract *out) {
  ARG(out);
  return domain_contract(out);
}
ogb3_status ogb3_domain_contract_check(const ogb3_domain_contract *expected) {
  ARG(expected);
  ogb3_domain_contract current;
  ogb3_status s = domain_contract(&current);
  if (s != OGB3_OK)
    return s;
  return memcmp(&current, expected, sizeof current) == 0 ? OGB3_OK
                                                         : OGB3_INCOMPATIBLE;
}
static int add_bytes(uint64_t *sum, uint64_t n) {
  if (n > UINT64_MAX - *sum)
    return 0;
  *sum += n;
  return 1;
}
static ogb3_status host_observe(ogb3_host_ledger_stats *out) {
  ogb3_allocation_stats snapshot = {0};
#ifdef OGB3_HAS_SNAPSHOTS
  ogb3_status s = ogb3_snapshot_allocation_stats(&snapshot);
  if (s != OGB3_OK)
    return s;
#endif
  ogb3_host_ledger_stats v = {0};
  v.engine_live_bytes = allocations.live_bytes;
  v.snapshot_live_bytes = snapshot.live_bytes;
  v.host_live_bytes = host_live;
  v.host_reserved_bytes = host_reserved;
  v.live_bytes = allocations.live_bytes;
  if (!add_bytes(&v.live_bytes, snapshot.live_bytes) ||
      !add_bytes(&v.live_bytes, host_live))
    return OGB3_CAPACITY;
  v.admitted_bytes = v.live_bytes;
  if (!add_bytes(&v.admitted_bytes, host_reserved))
    return OGB3_CAPACITY;
  v.limit_bytes = OGB3_HOST_LIMIT_BYTES;
  v.committed_peak_bytes = host_committed_peak;
  v.successful_updates = host_updates;
  v.ledger_storage_bytes = sizeof host_slots + sizeof host_live +
                           sizeof host_reserved + sizeof host_committed_peak +
                           sizeof host_updates + sizeof host_count;
  v.owner_count = host_count;
  v.owner_capacity = OGB3_HOST_OWNER_CAPACITY;
  *out = v;
  return OGB3_OK;
}
static host_slot *host_find(ogb3_host_owner token) {
  uint32_t index1 = (uint32_t)token;
  uint32_t generation = (uint32_t)(token >> 32);
  if (!index1 || index1 > OGB3_HOST_OWNER_CAPACITY || !generation)
    return NULL;
  host_slot *s = &host_slots[index1 - 1];
  return s->active && s->generation == generation ? s : NULL;
}
static void host_committed(uint64_t total) {
  if (total > host_committed_peak)
    host_committed_peak = total;
  if (host_updates != UINT64_MAX)
    ++host_updates;
}
ogb3_status ogb3_host_ledger_get(uint64_t cookie, ogb3_host_ledger_stats *out) {
  if (cookie != domain_cookie())
    return OGB3_INCOMPATIBLE;
  ARG(out);
  return host_observe(out);
}
ogb3_status ogb3_host_owner_open(uint64_t cookie, uint64_t producer,
                                 uint64_t component, ogb3_host_owner *out) {
  if (cookie != domain_cookie())
    return OGB3_INCOMPATIBLE;
  ARG(out && producer && component);
  host_slot *available = NULL;
  for (unsigned i = 0; i < OGB3_HOST_OWNER_CAPACITY; ++i) {
    host_slot *s = &host_slots[i];
    if (s->active && s->producer == producer && s->component == component)
      return OGB3_INVALID_ARGUMENT;
    if (!s->active && s->generation != UINT32_MAX && !available)
      available = s;
  }
  if (!available)
    return OGB3_CAPACITY;
  ogb3_host_ledger_stats observed;
  ogb3_status status = host_observe(&observed);
  if (status != OGB3_OK)
    return status;
  available->generation++;
  available->producer = producer;
  available->component = component;
  available->live = available->reserved = 0;
  available->active = 1;
  ++host_count;
  host_committed(observed.admitted_bytes);
  *out = ((uint64_t)available->generation << 32) |
         (uint64_t)(available - host_slots + 1);
  return OGB3_OK;
}
ogb3_status ogb3_host_owner_get(uint64_t cookie, ogb3_host_owner token,
                                ogb3_host_owner_info *out) {
  if (cookie != domain_cookie())
    return OGB3_INCOMPATIBLE;
  ARG(out);
  const host_slot *s = host_find(token);
  if (!s)
    return OGB3_INVALID_HANDLE;
  *out =
      (ogb3_host_owner_info){s->producer, s->component, s->live, s->reserved};
  return OGB3_OK;
}
static ogb3_status host_proposed(host_slot *slot, uint64_t live,
                                 uint64_t reserved, uint64_t additional_live,
                                 uint64_t additional_reserved,
                                 uint64_t *required) {
  ogb3_host_ledger_stats observed;
  ogb3_status status = host_observe(&observed);
  if (status != OGB3_OK)
    return status;
  uint64_t total = observed.admitted_bytes;
  if (slot) {
    assert(total >= slot->live && total - slot->live >= slot->reserved);
    total -= slot->live;
    total -= slot->reserved;
  }
  if (!add_bytes(&total, live) || !add_bytes(&total, reserved) ||
      !add_bytes(&total, additional_live) ||
      !add_bytes(&total, additional_reserved))
    return OGB3_CAPACITY;
  *required = total;
  return OGB3_OK;
}
ogb3_status ogb3_host_memory_check(uint64_t cookie, ogb3_host_owner token,
                                   uint64_t proposed_live,
                                   uint64_t proposed_reserved,
                                   uint64_t additional_live,
                                   uint64_t additional_reserved,
                                   uint64_t *required) {
  if (cookie != domain_cookie())
    return OGB3_INCOMPATIBLE;
  ARG(required);
  host_slot *slot = host_find(token);
  if (token && !slot)
    return OGB3_INVALID_HANDLE;
  ARG(token || (!proposed_live && !proposed_reserved));
  uint64_t total;
  ogb3_status status =
      host_proposed(slot, proposed_live, proposed_reserved, additional_live,
                    additional_reserved, &total);
  if (status != OGB3_OK)
    return status;
  if (total > OGB3_HOST_LIMIT_BYTES)
    return OGB3_CAPACITY;
  *required = total;
  return OGB3_OK;
}
ogb3_status ogb3_host_owner_set(uint64_t cookie, ogb3_host_owner token,
                                uint64_t live, uint64_t reserved) {
  if (cookie != domain_cookie())
    return OGB3_INCOMPATIBLE;
  host_slot *slot = host_find(token);
  if (!slot)
    return OGB3_INVALID_HANDLE;
  uint64_t total;
  ogb3_status status = host_proposed(slot, live, reserved, 0, 0, &total);
  if (status != OGB3_OK)
    return status;
  if (total > OGB3_HOST_LIMIT_BYTES &&
      (live > UINT64_MAX - reserved ||
       live + reserved > slot->live + slot->reserved))
    return OGB3_CAPACITY;
  /* The previous combined token contribution was admitted without overflow. */
  host_live = host_live - slot->live + live;
  host_reserved = host_reserved - slot->reserved + reserved;
  slot->live = live;
  slot->reserved = reserved;
  host_committed(total);
  return OGB3_OK;
}
ogb3_status ogb3_host_owner_close(uint64_t cookie, ogb3_host_owner token) {
  if (cookie != domain_cookie())
    return OGB3_INCOMPATIBLE;
  host_slot *slot = host_find(token);
  if (!slot)
    return OGB3_INVALID_HANDLE;
  ogb3_host_ledger_stats observed;
  ogb3_status status = host_observe(&observed);
  if (status != OGB3_OK)
    return status;
  host_live -= slot->live;
  host_reserved -= slot->reserved;
  slot->active = 0;
  --host_count;
  host_committed(observed.admitted_bytes - slot->live - slot->reserved);
  return OGB3_OK;
}
_Static_assert(B3_MAX_WORLDS == OGB3_WORLD_CAPACITY, "public world capacity");
typedef struct {
  void *base;
  uint64_t bytes;
} allocation_header;
static void *engine_alloc(size_t size, int32_t alignment) {
  size_t a = (size_t)alignment;
  if (a < sizeof(void *))
    a = sizeof(void *);
  if (alignment <= 0 || (a & (a - 1)) != 0 ||
      a > SIZE_MAX - sizeof(allocation_header) ||
      size > SIZE_MAX - a - sizeof(allocation_header))
    return NULL;
  void *base = malloc(size + a + sizeof(allocation_header));
  if (!base)
    return NULL;
  uintptr_t p = ((uintptr_t)base + sizeof(allocation_header) + a - 1) &
                ~(uintptr_t)(a - 1);
  allocation_header h = {base, (uint64_t)size};
  memcpy((void *)(p - sizeof h), &h, sizeof h);
  allocations.total_calls++;
  allocations.total_bytes += (uint64_t)size;
  allocations.live_bytes += (uint64_t)size;
  if (allocations.live_bytes > allocations.high_water_bytes)
    allocations.high_water_bytes = allocations.live_bytes;
  return (void *)p;
}
static void engine_free(void *p, size_t size) {
  if (!p)
    return;
  allocation_header h;
  memcpy(&h, (char *)p - sizeof h, sizeof h);
  assert(h.bytes == (uint64_t)size);
  assert(allocations.live_bytes >= h.bytes);
  allocations.live_bytes -= h.bytes;
  free(h.base);
}
static ogb3_status initialize(void) {
  if (initialized)
    return OGB3_OK;
  /* Installing our allocator over another owner's live allocations is unsafe.
   * In particular, never ask the upstream probe for a 129th world. */
  int count = b3GetWorldCount();
  if (count != 0)
    return count >= B3_MAX_WORLDS ? OGB3_CAPACITY : OGB3_UNSUPPORTED;
  b3SetLengthUnitsPerMeter(length_units_per_meter);
  b3SetAllocator(engine_alloc, engine_free);
  /* Keep the admitted four-wide profile independent of runtime AVX2 dispatch. */
  b3SetSIMDWidth(4);
  initialized = 1;
  /* The probe owns a temporary world. Bootstrap it while the domain is empty,
   * before the first public world or geometry resource consumes an engine slot.
   */
  fingerprint = b3r_determinism_fingerprint();
  return fingerprint ? OGB3_OK : OGB3_CAPACITY;
}
ogb3_status ogb3_engine_allocation_stats(ogb3_allocation_stats *out) {
  ARG(out);
  *out = allocations;
  return OGB3_OK;
}
uint32_t ogb3_abi_version(void) { return 2; }
ogb3_status ogb3_set_length_units_per_meter(float units) {
  ARG(isfinite(units) && units >= 0.001f && units <= 1000.0f);
  /* Fixed once the engine is initialized: tolerances and the fingerprint
   * already used the current value. Repeating it is harmless. */
  if (initialized)
    return units == length_units_per_meter ? OGB3_OK : OGB3_UNSUPPORTED;
  length_units_per_meter = units;
  return OGB3_OK;
}
float ogb3_get_length_units_per_meter(void) { return length_units_per_meter; }
uint64_t ogb3_build_fingerprint(void) {
  if (fingerprint)
    return fingerprint;
  /* A zero result is an unavailable diagnostic, never a compatibility token.
   * This check precedes initialization and avoids any allocator/global change
   * when a caller has already filled the native world domain. */
  if (b3GetWorldCount() >= B3_MAX_WORLDS || initialize() != OGB3_OK)
    return 0;
  return fingerprint;
}

ogb3_status ogb3_world_def_default(ogb3_world_def *d) {
  ARG(d);
  memset(d, 0, sizeof *d);
  d->gravity = (ogb3_vec3){0, -10, 0};
  d->enable_sleep = 1;
  d->enable_continuous = 1;
  return OGB3_OK;
}
ogb3_status ogb3_body_def_default(ogb3_body_def *d) {
  ARG(d);
  memset(d, 0, sizeof *d);
  b3BodyDef b = b3DefaultBodyDef();
  d->type = b.type;
  d->pose.rotation.w = 1;
  d->gravity_scale = b.gravityScale;
  d->sleep_threshold = b.sleepThreshold;
  d->angular_damping = b.angularDamping;
  d->enable_sleep = b.enableSleep;
  d->is_awake = b.isAwake;
  d->is_enabled = b.isEnabled;
  d->allow_fast_rotation = b.allowFastRotation;
  return OGB3_OK;
}
ogb3_status ogb3_shape_def_default(ogb3_shape_def *d) {
  ARG(d);
  memset(d, 0, sizeof *d);
  b3ShapeDef b = b3DefaultShapeDef();
  d->category_bits = b.filter.categoryBits;
  d->mask_bits = b.filter.maskBits;
  d->density = b.density;
  d->friction = b.baseMaterial.friction;
  d->restitution = b.baseMaterial.restitution;
  return OGB3_OK;
}
ogb3_status ogb3_hinge_def_default(ogb3_hinge_def *d) {
  ARG(d);
  memset(d, 0, sizeof *d);
  d->local_frame_a.rotation.w = d->local_frame_b.rotation.w = 1;
  return OGB3_OK;
}
ogb3_status ogb3_world_create(const ogb3_world_def *d, ogb3_world *out) {
  ARG(out);
  *out = 0;
  ARG(d && validvec(&d->gravity) && d->enable_sleep <= 1 &&
      d->enable_continuous <= 1 && bounded(d->restitution_threshold) &&
      bounded(d->hit_event_threshold) && bounded(d->contact_hertz) &&
      bounded(d->contact_damping_ratio) && bounded(d->contact_speed) &&
      bounded(d->maximum_linear_speed) &&
      isfinite(d->isotropic_inertia_tolerance) &&
      d->isotropic_inertia_tolerance >= 0 &&
      d->isotropic_inertia_tolerance <= 1 &&
      d->restitution_iterations <= B3_MAX_RESTITUTION_ITERATIONS &&
      d->enable_restitution_propagation <= 1);
  ogb3_status init_status = initialize();
  if (init_status != OGB3_OK)
    return init_status;
  if (b3GetWorldCount() >= B3_MAX_WORLDS)
    return OGB3_CAPACITY;
  b3WorldDef b = b3DefaultWorldDef();
  b.gravity = vec(d->gravity);
  b.enableSleep = d->enable_sleep;
  b.enableContinuous = d->enable_continuous;
  /* 0 keeps Box3D's (length-scaled) default. */
  if (d->restitution_threshold > 0)
    b.restitutionThreshold = d->restitution_threshold;
  if (d->hit_event_threshold > 0)
    b.hitEventThreshold = d->hit_event_threshold;
  if (d->contact_hertz > 0)
    b.contactHertz = d->contact_hertz;
  if (d->contact_damping_ratio > 0)
    b.contactDampingRatio = d->contact_damping_ratio;
  if (d->contact_speed > 0)
    b.contactSpeed = d->contact_speed;
  if (d->maximum_linear_speed > 0)
    b.maximumLinearSpeed = d->maximum_linear_speed;
  if (d->isotropic_inertia_tolerance > 0)
    b.isotropicInertiaTolerance = d->isotropic_inertia_tolerance;
  if (d->restitution_iterations > 0)
    b.restitutionIterations = (int)d->restitution_iterations;
  b.enableRestitutionPropagation = d->enable_restitution_propagation;
  b.workerCount = 1;
  *out = world_bits(b3CreateWorld(&b));
  return *out ? OGB3_OK : OGB3_OUT_OF_MEMORY;
}

typedef struct lease {
  uint32_t world;
  ogb3_geometry *geometry;
  struct lease *next;
} lease;
static lease *leases;
void ogb3_geometry_release(ogb3_geometry *g) {
  if (!g)
    return;
  assert(g->refs > 0);
  if (--g->refs == 0) {
    if (g->kind == 1)
      b3DestroyHull(g->data);
    else
      b3DestroyMesh(g->data);
#ifdef OGB3_HAS_SNAPSHOTS
    ogb3_snapshot_internal_free(g);
#else
    free(g);
#endif
  }
}
static ogb3_status retain_geometry(uint32_t w, ogb3_geometry *g) {
  for (lease *l = leases; l; l = l->next)
    if (l->world == w && l->geometry == g)
      return OGB3_OK;
  lease *l = malloc(sizeof *l);
  if (!l)
    return OGB3_OUT_OF_MEMORY;
  g->refs++;
  *l = (lease){w, g, leases};
  leases = l;
  return OGB3_OK;
}
ogb3_status ogb3_world_destroy(ogb3_world w) {
  WORLD(w);
  b3DestroyWorld(world_id(w));
#ifdef OGB3_HAS_SNAPSHOTS
  ogb3_snapshot_world_detach(w);
#endif
  lease **p = &leases;
  while (*p) {
    lease *l = *p;
    if (l->world == w) {
      *p = l->next;
      ogb3_geometry_release(l->geometry);
      free(l);
    } else
      p = &l->next;
  }
  return OGB3_OK;
}
ogb3_status ogb3_world_valid(ogb3_world w, uint32_t *out) {
  ARG(out);
  *out = world_is_valid(w);
  return OGB3_OK;
}
ogb3_status ogb3_world_step(ogb3_world w, float dt, uint32_t substeps) {
  WORLD(w);
  ARG(isfinite(dt) && dt > 0 && substeps > 0 && substeps <= 128);
  b3World_Step(world_id(w), dt, (int)substeps);
  return OGB3_OK;
}
ogb3_status ogb3_world_step_fixed(ogb3_world w) {
  OGB3_OBS_BEGIN(observe_fixed, OGB3_OBS_STEP_FIXED_V1);
  OGB3_OBS_RETURN(observe_fixed, ogb3_world_step(w, 1.0f / 60.0f, 4));
}
ogb3_status ogb3_world_get_gravity(ogb3_world w, ogb3_vec3 *out) {
  ARG(out);
  WORLD(w);
  *out = outvec(b3World_GetGravity(world_id(w)));
  return OGB3_OK;
}
ogb3_status ogb3_world_set_gravity(ogb3_world w, const ogb3_vec3 *v) {
  ARG(validvec(v));
  WORLD(w);
  b3World_SetGravity(world_id(w), vec(*v));
  return OGB3_OK;
}
ogb3_status ogb3_body_create(ogb3_world w, const ogb3_body_def *d,
                             ogb3_body *out) {
  ARG(out);
  *out = 0;
  WORLD(w);
  ARG(d && d->type >= 0 && d->type <= 2 && validpose(&d->pose) &&
      validvec(&d->linear_velocity) && validvec(&d->angular_velocity) &&
      nonnegative(d->linear_damping) && nonnegative(d->angular_damping) &&
      isfinite(d->gravity_scale) && nonnegative(d->sleep_threshold) &&
      d->enable_sleep <= 1 && d->is_awake <= 1 && d->is_bullet <= 1 &&
      d->is_enabled <= 1 && d->allow_fast_rotation <= 1 &&
      d->motion_locks <= OGB3_LOCK_ALL && bounded(d->safety_factor) &&
      d->disable_contact_recycling <= 1);
  b3BodyDef b = b3DefaultBodyDef();
  b.type = (b3BodyType)d->type;
  b.position = vec(d->pose.position);
  b.rotation = quat(d->pose.rotation);
  b.linearVelocity = vec(d->linear_velocity);
  b.angularVelocity = vec(d->angular_velocity);
  b.linearDamping = d->linear_damping;
  b.angularDamping = d->angular_damping;
  b.gravityScale = d->gravity_scale;
  b.sleepThreshold = d->sleep_threshold;
  b.enableSleep = d->enable_sleep;
  b.isAwake = d->is_awake;
  b.isBullet = d->is_bullet;
  b.isEnabled = d->is_enabled;
  b.allowFastRotation = d->allow_fast_rotation;
  b.motionLocks.linearX = (d->motion_locks & OGB3_LOCK_LINEAR_X) != 0;
  b.motionLocks.linearY = (d->motion_locks & OGB3_LOCK_LINEAR_Y) != 0;
  b.motionLocks.linearZ = (d->motion_locks & OGB3_LOCK_LINEAR_Z) != 0;
  b.motionLocks.angularX = (d->motion_locks & OGB3_LOCK_ANGULAR_X) != 0;
  b.motionLocks.angularY = (d->motion_locks & OGB3_LOCK_ANGULAR_Y) != 0;
  b.motionLocks.angularZ = (d->motion_locks & OGB3_LOCK_ANGULAR_Z) != 0;
  if (d->safety_factor > 0)
    b.safetyFactor = d->safety_factor;
  b.enableContactRecycling = !d->disable_contact_recycling;
  *out = body_bits(b3CreateBody(world_id(w), &b));
  return *out ? OGB3_OK : OGB3_OUT_OF_MEMORY;
}
ogb3_status ogb3_body_destroy(ogb3_body b) {
  BODY(b);
  b3DestroyBody(body_id(b));
  return OGB3_OK;
}
ogb3_status ogb3_body_valid(ogb3_body b, uint32_t *out) {
  ARG(out);
  *out = b3Body_IsValid(body_id(b));
  return OGB3_OK;
}
ogb3_status ogb3_body_identity(ogb3_body b, uint32_t *index,
                               uint32_t *generation) {
  ARG(index && generation);
  BODY(b);
  b3BodyId id = body_id(b);
  *index = (uint32_t)id.index1;
  *generation = id.generation;
  return OGB3_OK;
}
ogb3_status ogb3_body_get_pose(ogb3_body b, ogb3_pose *out) {
  ARG(out);
  BODY(b);
  out->position = outvec(b3Body_GetPosition(body_id(b)));
  b3Quat q = b3Body_GetRotation(body_id(b));
  out->rotation = (ogb3_quat){q.v.x, q.v.y, q.v.z, q.s};
  return OGB3_OK;
}
ogb3_status ogb3_body_set_pose(ogb3_body b, const ogb3_pose *p) {
  ARG(validpose(p));
  BODY(b);
  b3Body_SetTransform(body_id(b), vec(p->position), quat(p->rotation));
  return OGB3_OK;
}
ogb3_status ogb3_body_set_type(ogb3_body b, int32_t type) {
  ARG(type >= OGB3_STATIC && type <= OGB3_DYNAMIC);
  BODY(b);
  b3BodyId id = body_id(b);
  b3World *world = b3GetUnlockedWorld(id.world0);
  if (!world)
    return OGB3_UNSUPPORTED;
  b3Body *value = b3GetBodyFullId(world, id);
  if (type != OGB3_STATIC) {
    /* The pinned upstream setter returns from this unsupported branch after
     * locking the world. Reject it before entry, preserving both state and
     * the world's usable lock state. No allocation/count cap is introduced. */
    for (int index = value->headShapeId; index != B3_NULL_INDEX;) {
      b3Shape *shape = world->shapes.data + index;
      if (shape->type == b3_compoundShape || shape->type == b3_heightShape ||
          shape->type == b3_meshShape)
        return OGB3_UNSUPPORTED;
      index = shape->nextShapeId;
    }
  }
  b3Body_SetType(id, (b3BodyType)type);
  return OGB3_OK;
}
ogb3_status ogb3_body_get_velocity(ogb3_body b, ogb3_vec3 *v, ogb3_vec3 *a) {
  ARG(v && a);
  BODY(b);
  *v = outvec(b3Body_GetLinearVelocity(body_id(b)));
  *a = outvec(b3Body_GetAngularVelocity(body_id(b)));
  return OGB3_OK;
}
ogb3_status ogb3_body_set_velocity(ogb3_body b, const ogb3_vec3 *v,
                                   const ogb3_vec3 *a) {
  ARG(validvec(v) && validvec(a));
  BODY(b);
  b3Body_SetLinearVelocity(body_id(b), vec(*v));
  b3Body_SetAngularVelocity(body_id(b), vec(*a));
  return OGB3_OK;
}
ogb3_status ogb3_body_apply_impulse(ogb3_body b, const ogb3_vec3 *v,
                                    const ogb3_vec3 *p, uint32_t wake) {
  ARG(validvec(v) && (!p || validvec(p)) && wake <= 1);
  BODY(b);
  if (p)
    b3Body_ApplyLinearImpulse(body_id(b), vec(*v), vec(*p), wake);
  else
    b3Body_ApplyLinearImpulseToCenter(body_id(b), vec(*v), wake);
  return OGB3_OK;
}
ogb3_status ogb3_body_apply_angular_impulse(ogb3_body b, const ogb3_vec3 *v,
                                            uint32_t wake) {
  ARG(validvec(v) && wake <= 1);
  BODY(b);
  b3Body_ApplyAngularImpulse(body_id(b), vec(*v), wake);
  return OGB3_OK;
}
ogb3_status ogb3_body_set_awake(ogb3_body b, uint32_t awake) {
  ARG(awake <= 1);
  BODY(b);
  b3Body_SetAwake(body_id(b), awake);
  return OGB3_OK;
}
ogb3_status ogb3_body_get_awake(ogb3_body b, uint32_t *out) {
  ARG(out);
  BODY(b);
  *out = b3Body_IsAwake(body_id(b));
  return OGB3_OK;
}
ogb3_status ogb3_body_get_mass(ogb3_body b, float *out) {
  ARG(out);
  BODY(b);
  *out = b3Body_GetMass(body_id(b));
  return OGB3_OK;
}

ogb3_status ogb3_geometry_hull(const ogb3_vec3 *p, uint32_t n,
                               ogb3_geometry **out) {
  ARG(out);
  *out = NULL;
  ARG(p && n >= 4 && n <= INT_MAX);
  ogb3_status init_status = initialize();
  if (init_status != OGB3_OK)
    return init_status;
  for (uint32_t i = 0; i < n; i++)
    ARG(validvec(p + i));
  b3Vec3 *points = malloc(n * sizeof *points);
  if (!points)
    return OGB3_OUT_OF_MEMORY;
  for (uint32_t i = 0; i < n; i++)
    points[i] = vec(p[i]);
  b3HullData *data = b3CreateHull(points, (int)n, 256);
  free(points);
  if (!data)
    return OGB3_INVALID_ARGUMENT;
  ogb3_geometry *g =
#ifdef OGB3_HAS_SNAPSHOTS
      ogb3_snapshot_internal_alloc(sizeof *g);
#else
      malloc(sizeof *g);
#endif
  if (!g) {
    b3DestroyHull(data);
    return OGB3_OUT_OF_MEMORY;
  }
  *g = (ogb3_geometry){1, 1, data};
  *out = g;
  return OGB3_OK;
}
ogb3_status ogb3_geometry_mesh(const ogb3_vec3 *p, uint32_t n,
                               const uint32_t *idx, uint32_t triangles,
                               ogb3_geometry **out) {
  ARG(out);
  *out = NULL;
  ARG(p && idx && n >= 3 && n <= INT_MAX && triangles > 0 &&
      triangles <= INT_MAX / 3);
  ogb3_status init_status = initialize();
  if (init_status != OGB3_OK)
    return init_status;
  for (uint32_t i = 0; i < n; i++)
    ARG(validvec(p + i));
  for (uint32_t i = 0; i < triangles * 3; i++)
    ARG(idx[i] < n);
  b3Vec3 *points = malloc(n * sizeof *points);
  int32_t *indices = malloc(triangles * 3 * sizeof *indices);
  if (!points || !indices) {
    free(points);
    free(indices);
    return OGB3_OUT_OF_MEMORY;
  }
  for (uint32_t i = 0; i < n; i++)
    points[i] = vec(p[i]);
  for (uint32_t i = 0; i < triangles * 3; i++)
    indices[i] = (int32_t)idx[i];
  b3MeshDef d = {0};
  d.vertices = points;
  d.indices = indices;
  d.vertexCount = (int)n;
  d.triangleCount = (int)triangles;
  d.identifyEdges = true;
  b3MeshData *data = b3CreateMesh(&d, NULL, 0);
  free(points);
  free(indices);
  if (!data)
    return OGB3_INVALID_ARGUMENT;
  ogb3_geometry *g =
#ifdef OGB3_HAS_SNAPSHOTS
      ogb3_snapshot_internal_alloc(sizeof *g);
#else
      malloc(sizeof *g);
#endif
  if (!g) {
    b3DestroyMesh(data);
    return OGB3_OUT_OF_MEMORY;
  }
  *g = (ogb3_geometry){1, 2, data};
  *out = g;
  return OGB3_OK;
}
static int shape_def(const ogb3_shape_def *d, b3ShapeDef *b) {
  if (!d || !nonnegative(d->density) || !nonnegative(d->friction) ||
      !nonnegative(d->restitution) || d->is_sensor > 1 ||
      d->enable_sensor_events > 1 || d->enable_contact_events > 1 ||
      !bounded(d->rolling_resistance) || !validvec(&d->tangent_velocity) ||
      fabsf(d->tangent_velocity.x) > 1e6f ||
      fabsf(d->tangent_velocity.y) > 1e6f ||
      fabsf(d->tangent_velocity.z) > 1e6f || d->skip_contact_creation > 1 ||
      d->disable_speculative_contact > 1)
    return 0;
  *b = b3DefaultShapeDef();
  b->filter.categoryBits = d->category_bits;
  b->filter.maskBits = d->mask_bits;
  b->filter.groupIndex = d->group_index;
  b->density = d->density;
  b->baseMaterial.friction = d->friction;
  b->baseMaterial.restitution = d->restitution;
  b->isSensor = d->is_sensor;
  b->enableSensorEvents = d->enable_sensor_events;
  b->enableContactEvents = d->enable_contact_events;
  b->baseMaterial.rollingResistance = d->rolling_resistance;
  b->baseMaterial.tangentVelocity = vec(d->tangent_velocity);
  b->invokeContactCreation = !d->skip_contact_creation;
  b->enableSpeculativeContact = !d->disable_speculative_contact;
  return 1;
}
ogb3_status ogb3_shape_box(ogb3_body body, const ogb3_shape_def *d,
                           const ogb3_vec3 *half, ogb3_shape *out) {
  ARG(out);
  *out = 0;
  BODY(body);
  ARG(validvec(half) && half->x > 0 && half->y > 0 && half->z > 0);
  b3ShapeDef b;
  ARG(shape_def(d, &b));
  b3BoxHull box = b3MakeBoxHull(half->x, half->y, half->z);
  *out = shape_bits(b3CreateHullShape(body_id(body), &b, &box.base));
  return *out ? OGB3_OK : OGB3_OUT_OF_MEMORY;
}
ogb3_status ogb3_shape_sphere(ogb3_body body, const ogb3_shape_def *d,
                              const ogb3_vec3 *center, float radius,
                              ogb3_shape *out) {
  ARG(out);
  *out = 0;
  BODY(body);
  ARG(validvec(center) && isfinite(radius) && radius > 0);
  b3ShapeDef b;
  ARG(shape_def(d, &b));
  b3Sphere s = {vec(*center), radius};
  *out = shape_bits(b3CreateSphereShape(body_id(body), &b, &s));
  return *out ? OGB3_OK : OGB3_OUT_OF_MEMORY;
}
ogb3_status ogb3_shape_capsule(ogb3_body body, const ogb3_shape_def *d,
                               const ogb3_vec3 *a, const ogb3_vec3 *c,
                               float radius, ogb3_shape *out) {
  ARG(out);
  *out = 0;
  BODY(body);
  ARG(validvec(a) && validvec(c) && isfinite(radius) && radius > 0);
  b3ShapeDef b;
  ARG(shape_def(d, &b));
  b3Capsule s = {vec(*a), vec(*c), radius};
  *out = shape_bits(b3CreateCapsuleShape(body_id(body), &b, &s));
  return *out ? OGB3_OK : OGB3_OUT_OF_MEMORY;
}
ogb3_status ogb3_shape_geometry(ogb3_body body, const ogb3_shape_def *d,
                                ogb3_geometry *g, ogb3_shape *out) {
  ARG(out);
  *out = 0;
  BODY(body);
  ARG(g);
  b3ShapeDef b;
  ARG(shape_def(d, &b));
  if (g->kind == 2) {
    if (d->is_sensor || d->enable_sensor_events)
      return OGB3_UNSUPPORTED;
    ARG(b3Body_GetType(body_id(body)) == b3_staticBody && !d->is_sensor);
    ogb3_status status =
        retain_geometry(world_bits(b3Body_GetWorld(body_id(body))), g);
    if (status)
      return status;
    *out = shape_bits(
        b3CreateMeshShape(body_id(body), &b, g->data, (b3Vec3){1, 1, 1}));
  } else if (g->kind == 1)
    *out = shape_bits(b3CreateHullShape(body_id(body), &b, g->data));
  else
    return OGB3_INVALID_ARGUMENT;
  return *out ? OGB3_OK : OGB3_OUT_OF_MEMORY;
}
ogb3_status ogb3_shape_destroy(ogb3_shape s) {
  SHAPE(s);
  b3DestroyShape(shape_id(s), true);
  return OGB3_OK;
}
ogb3_status ogb3_shape_valid(ogb3_shape s, uint32_t *out) {
  ARG(out);
  *out = shape_id(s).index1 > 0 && b3Shape_IsValid(shape_id(s));
  return OGB3_OK;
}
ogb3_status ogb3_shape_get_body(ogb3_shape s, ogb3_body *out) {
  ARG(out);
  SHAPE(s);
  *out = body_bits(b3Shape_GetBody(shape_id(s)));
  return OGB3_OK;
}
ogb3_status ogb3_shape_get_aabb(ogb3_shape s, ogb3_vec3 *lo, ogb3_vec3 *hi) {
  ARG(lo && hi);
  SHAPE(s);
  b3AABB a = b3Shape_GetAABB(shape_id(s));
  *lo = outvec(a.lowerBound);
  *hi = outvec(a.upperBound);
  return OGB3_OK;
}
typedef struct {
  void *out;
  uint32_t cap, count;
} query;
static bool overlap(b3ShapeId s, void *ctx) {
  query *q = ctx;
  if (q->count < q->cap)
    ((ogb3_shape *)q->out)[q->count] = shape_bits(s);
  q->count++;
  return true;
}
static float ray(b3ShapeId s, b3Pos p, b3Vec3 n, float f, uint64_t material,
                 int triangle, int child, void *ctx) {
  (void)material;
  (void)triangle;
  (void)child;
  query *q = ctx;
  if (q->count < q->cap)
    ((ogb3_ray_hit *)q->out)[q->count] =
        (ogb3_ray_hit){shape_bits(s), outvec(p), outvec(n), f, 0};
  q->count++;
  return 1;
}
ogb3_status ogb3_world_overlap_aabb(ogb3_world w, const ogb3_vec3 *lo,
                                    const ogb3_vec3 *hi,
                                    const ogb3_query_filter *f, ogb3_shape *out,
                                    uint32_t cap, uint32_t *count) {
  ARG(count && f && validvec(lo) && validvec(hi) && lo->x <= hi->x &&
      lo->y <= hi->y && lo->z <= hi->z && (!cap || out));
  WORLD(w);
  query q = {out, cap, 0};
  b3World_OverlapAABB(world_id(w), (b3AABB){vec(*lo), vec(*hi)},
                      (b3QueryFilter){.categoryBits = f->category_bits,
                                      .maskBits = f->mask_bits},
                      overlap, &q);
  *count = q.count;
  return cap < q.count ? OGB3_CAPACITY : OGB3_OK;
}
ogb3_status ogb3_world_cast_ray(ogb3_world w, const ogb3_vec3 *origin,
                                const ogb3_vec3 *translation,
                                const ogb3_query_filter *f, ogb3_ray_hit *out,
                                uint32_t cap, uint32_t *count) {
  ARG(count && f && validvec(origin) && validvec(translation) && (!cap || out));
  WORLD(w);
  query q = {out, cap, 0};
  b3World_CastRay(world_id(w), vec(*origin), vec(*translation),
                  (b3QueryFilter){.categoryBits = f->category_bits,
                                  .maskBits = f->mask_bits},
                  ray, &q);
  *count = q.count;
  return cap < q.count ? OGB3_CAPACITY : OGB3_OK;
}
ogb3_status ogb3_world_sensor_events(ogb3_world w, ogb3_sensor_event *out,
                                     uint32_t cap, uint32_t *count) {
  ARG(count && (!cap || out));
  WORLD(w);
  b3SensorEvents e = b3World_GetSensorEvents(world_id(w));
  uint32_t total = (uint32_t)(e.beginCount + e.endCount);
  for (uint32_t i = 0; i < total && i < cap; i++) {
    if (i < (uint32_t)e.beginCount)
      out[i] = (ogb3_sensor_event){shape_bits(e.beginEvents[i].sensorShapeId),
                                   shape_bits(e.beginEvents[i].visitorShapeId),
                                   1, 0};
    else {
      uint32_t j = i - (uint32_t)e.beginCount;
      out[i] =
          (ogb3_sensor_event){shape_bits(e.endEvents[j].sensorShapeId),
                              shape_bits(e.endEvents[j].visitorShapeId), 0, 0};
    }
  }
  *count = total;
  return cap < total ? OGB3_CAPACITY : OGB3_OK;
}
ogb3_status ogb3_joint_hinge_create(ogb3_world w, const ogb3_hinge_def *d,
                                    ogb3_joint *out) {
  ARG(out);
  *out = 0;
  WORLD(w);
  ARG(d && validpose(&d->local_frame_a) && validpose(&d->local_frame_b) &&
      isfinite(d->lower_angle) && isfinite(d->upper_angle) &&
      d->lower_angle <= d->upper_angle && d->lower_angle >= -3.1101767f &&
      d->upper_angle <= 3.1101767f && isfinite(d->motor_speed) &&
      nonnegative(d->max_motor_torque) && d->enable_limit <= 1 &&
      d->enable_motor <= 1 && d->collide_connected <= 1 &&
      d->body_a != d->body_b);
  BODY(d->body_a);
  BODY(d->body_b);
  ARG(world_bits(b3Body_GetWorld(body_id(d->body_a))) == w &&
      world_bits(b3Body_GetWorld(body_id(d->body_b))) == w);
  ARG(b3Body_GetType(body_id(d->body_a)) != b3_staticBody ||
      b3Body_GetType(body_id(d->body_b)) != b3_staticBody);
  b3RevoluteJointDef b = b3DefaultRevoluteJointDef();
  b.base.bodyIdA = body_id(d->body_a);
  b.base.bodyIdB = body_id(d->body_b);
  b.base.localFrameA = (b3Transform){vec(d->local_frame_a.position),
                                     quat(d->local_frame_a.rotation)};
  b.base.localFrameB = (b3Transform){vec(d->local_frame_b.position),
                                     quat(d->local_frame_b.rotation)};
  b.base.collideConnected = d->collide_connected;
  b.lowerAngle = d->lower_angle;
  b.upperAngle = d->upper_angle;
  b.enableLimit = d->enable_limit;
  b.enableMotor = d->enable_motor;
  b.motorSpeed = d->motor_speed;
  b.maxMotorTorque = d->max_motor_torque;
  *out = joint_bits(b3CreateRevoluteJoint(world_id(w), &b));
  return *out ? OGB3_OK : OGB3_OUT_OF_MEMORY;
}
ogb3_status ogb3_joint_destroy(ogb3_joint j) {
  JOINT(j);
  b3DestroyJoint(joint_id(j), true);
  return OGB3_OK;
}
ogb3_status ogb3_joint_valid(ogb3_joint j, uint32_t *out) {
  ARG(out);
  *out = joint_id(j).index1 > 0 && b3Joint_IsValid(joint_id(j));
  return OGB3_OK;
}
ogb3_status ogb3_joint_hinge_set_motor(ogb3_joint j, uint32_t enabled,
                                       float speed, float torque) {
  ARG(enabled <= 1 && isfinite(speed) && nonnegative(torque));
  JOINT(j);
  ARG(b3Joint_GetType(joint_id(j)) == b3_revoluteJoint);
  b3RevoluteJoint_EnableMotor(joint_id(j), enabled);
  b3RevoluteJoint_SetMotorSpeed(joint_id(j), speed);
  b3RevoluteJoint_SetMaxMotorTorque(joint_id(j), torque);
  b3Joint_WakeBodies(joint_id(j));
  return OGB3_OK;
}
ogb3_status ogb3_joint_hinge_get_angle(ogb3_joint j, float *out) {
  ARG(out);
  JOINT(j);
  ARG(b3Joint_GetType(joint_id(j)) == b3_revoluteJoint);
  *out = b3RevoluteJoint_GetAngle(joint_id(j));
  return OGB3_OK;
}

ogb3_status ogb3_abi_layout(uint32_t type, uint32_t field, uint32_t *size,
                            uint32_t *align, uint32_t *offset) {
  ARG(size && align && offset);
  if (type >= OGB3_T_DOMAIN_CONTRACT && type <= OGB3_T_HOST_LEDGER_STATS) {
    static const uint32_t contract_offsets[] = {
        offsetof(ogb3_domain_contract, cookie),
        offsetof(ogb3_domain_contract, size),
        offsetof(ogb3_domain_contract, version),
        offsetof(ogb3_domain_contract, abi_version),
        offsetof(ogb3_domain_contract, logical_version),
        offsetof(ogb3_domain_contract, resource_version),
        offsetof(ogb3_domain_contract, recovery_version),
        offsetof(ogb3_domain_contract, pointer_bits),
        offsetof(ogb3_domain_contract, endian),
        offsetof(ogb3_domain_contract, build),
        offsetof(ogb3_domain_contract, target)};
    static const uint32_t owner_offsets[] = {
        offsetof(ogb3_host_owner_info, producer),
        offsetof(ogb3_host_owner_info, component),
        offsetof(ogb3_host_owner_info, live_bytes),
        offsetof(ogb3_host_owner_info, reserved_bytes)};
    static const uint32_t ledger_offsets[] = {
        offsetof(ogb3_host_ledger_stats, engine_live_bytes),
        offsetof(ogb3_host_ledger_stats, snapshot_live_bytes),
        offsetof(ogb3_host_ledger_stats, host_live_bytes),
        offsetof(ogb3_host_ledger_stats, host_reserved_bytes),
        offsetof(ogb3_host_ledger_stats, live_bytes),
        offsetof(ogb3_host_ledger_stats, admitted_bytes),
        offsetof(ogb3_host_ledger_stats, limit_bytes),
        offsetof(ogb3_host_ledger_stats, committed_peak_bytes),
        offsetof(ogb3_host_ledger_stats, successful_updates),
        offsetof(ogb3_host_ledger_stats, ledger_storage_bytes),
        offsetof(ogb3_host_ledger_stats, owner_count),
        offsetof(ogb3_host_ledger_stats, owner_capacity)};
    const uint32_t *fields;
    uint32_t count, bytes, alignment;
    if (type == OGB3_T_DOMAIN_CONTRACT) {
      fields = contract_offsets;
      count = sizeof contract_offsets / sizeof *contract_offsets;
      bytes = sizeof(ogb3_domain_contract);
      alignment = _Alignof(ogb3_domain_contract);
    } else if (type == OGB3_T_HOST_OWNER_INFO) {
      fields = owner_offsets;
      count = sizeof owner_offsets / sizeof *owner_offsets;
      bytes = sizeof(ogb3_host_owner_info);
      alignment = _Alignof(ogb3_host_owner_info);
    } else {
      fields = ledger_offsets;
      count = sizeof ledger_offsets / sizeof *ledger_offsets;
      bytes = sizeof(ogb3_host_ledger_stats);
      alignment = _Alignof(ogb3_host_ledger_stats);
    }
    ARG(field == UINT32_MAX || field < count);
    *size = bytes;
    *align = alignment;
    *offset = field == UINT32_MAX ? 0 : fields[field];
    return OGB3_OK;
  }
  switch (type) {
  case 1: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_vec3, x), offsetof(ogb3_vec3, y), offsetof(ogb3_vec3, z)};
    *size = sizeof(ogb3_vec3);
    *align = _Alignof(ogb3_vec3);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 3);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 2: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_quat, x), offsetof(ogb3_quat, y), offsetof(ogb3_quat, z),
        offsetof(ogb3_quat, w)};
    *size = sizeof(ogb3_quat);
    *align = _Alignof(ogb3_quat);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 4);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 3: {
    static const uint32_t offsets[] = {offsetof(ogb3_pose, position),
                                       offsetof(ogb3_pose, rotation)};
    *size = sizeof(ogb3_pose);
    *align = _Alignof(ogb3_pose);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 2);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 4: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_world_def, gravity),
        offsetof(ogb3_world_def, enable_sleep),
        offsetof(ogb3_world_def, enable_continuous),
        offsetof(ogb3_world_def, restitution_threshold),
        offsetof(ogb3_world_def, hit_event_threshold),
        offsetof(ogb3_world_def, contact_hertz),
        offsetof(ogb3_world_def, contact_damping_ratio),
        offsetof(ogb3_world_def, contact_speed),
        offsetof(ogb3_world_def, maximum_linear_speed),
        offsetof(ogb3_world_def, isotropic_inertia_tolerance),
        offsetof(ogb3_world_def, restitution_iterations),
        offsetof(ogb3_world_def, enable_restitution_propagation)};
    *size = sizeof(ogb3_world_def);
    *align = _Alignof(ogb3_world_def);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 12);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 5: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_body_def, type),
        offsetof(ogb3_body_def, pose),
        offsetof(ogb3_body_def, linear_velocity),
        offsetof(ogb3_body_def, angular_velocity),
        offsetof(ogb3_body_def, linear_damping),
        offsetof(ogb3_body_def, angular_damping),
        offsetof(ogb3_body_def, gravity_scale),
        offsetof(ogb3_body_def, sleep_threshold),
        offsetof(ogb3_body_def, enable_sleep),
        offsetof(ogb3_body_def, is_awake),
        offsetof(ogb3_body_def, is_bullet),
        offsetof(ogb3_body_def, is_enabled),
        offsetof(ogb3_body_def, allow_fast_rotation),
        offsetof(ogb3_body_def, motion_locks),
        offsetof(ogb3_body_def, safety_factor),
        offsetof(ogb3_body_def, disable_contact_recycling)};
    *size = sizeof(ogb3_body_def);
    *align = _Alignof(ogb3_body_def);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 16);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 6: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_shape_def, category_bits),
        offsetof(ogb3_shape_def, mask_bits),
        offsetof(ogb3_shape_def, group_index),
        offsetof(ogb3_shape_def, density),
        offsetof(ogb3_shape_def, friction),
        offsetof(ogb3_shape_def, restitution),
        offsetof(ogb3_shape_def, is_sensor),
        offsetof(ogb3_shape_def, enable_sensor_events),
        offsetof(ogb3_shape_def, enable_contact_events),
        offsetof(ogb3_shape_def, rolling_resistance),
        offsetof(ogb3_shape_def, tangent_velocity),
        offsetof(ogb3_shape_def, skip_contact_creation),
        offsetof(ogb3_shape_def, disable_speculative_contact)};
    *size = sizeof(ogb3_shape_def);
    *align = _Alignof(ogb3_shape_def);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 13);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 7: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_hinge_def, body_a),
        offsetof(ogb3_hinge_def, body_b),
        offsetof(ogb3_hinge_def, local_frame_a),
        offsetof(ogb3_hinge_def, local_frame_b),
        offsetof(ogb3_hinge_def, lower_angle),
        offsetof(ogb3_hinge_def, upper_angle),
        offsetof(ogb3_hinge_def, motor_speed),
        offsetof(ogb3_hinge_def, max_motor_torque),
        offsetof(ogb3_hinge_def, enable_limit),
        offsetof(ogb3_hinge_def, enable_motor),
        offsetof(ogb3_hinge_def, collide_connected)};
    *size = sizeof(ogb3_hinge_def);
    *align = _Alignof(ogb3_hinge_def);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 11);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 8: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_query_filter, category_bits),
        offsetof(ogb3_query_filter, mask_bits)};
    *size = sizeof(ogb3_query_filter);
    *align = _Alignof(ogb3_query_filter);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 2);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 9: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_ray_hit, shape), offsetof(ogb3_ray_hit, point),
        offsetof(ogb3_ray_hit, normal), offsetof(ogb3_ray_hit, fraction),
        offsetof(ogb3_ray_hit, reserved)};
    *size = sizeof(ogb3_ray_hit);
    *align = _Alignof(ogb3_ray_hit);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 5);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 10: {
    static const uint32_t offsets[] = {offsetof(ogb3_sensor_event, sensor),
                                       offsetof(ogb3_sensor_event, visitor),
                                       offsetof(ogb3_sensor_event, began),
                                       offsetof(ogb3_sensor_event, reserved)};
    *size = sizeof(ogb3_sensor_event);
    *align = _Alignof(ogb3_sensor_event);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 4);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 11: {
    *size = sizeof(ogb3_allocation_stats);
    *align = _Alignof(ogb3_allocation_stats);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 4);
    *offset = field * 8;
    return OGB3_OK;
  }
  case 12: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_world_counters, body_count),
        offsetof(ogb3_world_counters, shape_count),
        offsetof(ogb3_world_counters, contact_count),
        offsetof(ogb3_world_counters, joint_count),
        offsetof(ogb3_world_counters, island_count),
        offsetof(ogb3_world_counters, tree_height)};
    *size = sizeof(ogb3_world_counters);
    *align = _Alignof(ogb3_world_counters);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 6);
    *offset = offsets[field];
    return OGB3_OK;
  }
  case 13: {
    static const uint32_t offsets[] = {
        offsetof(ogb3_body_state, key),
        offsetof(ogb3_body_state, pose),
        offsetof(ogb3_body_state, linear_velocity),
        offsetof(ogb3_body_state, angular_velocity),
        offsetof(ogb3_body_state, mass),
        offsetof(ogb3_body_state, type),
        offsetof(ogb3_body_state, is_awake),
        offsetof(ogb3_body_state, is_enabled)};
    *size = sizeof(ogb3_body_state);
    *align = _Alignof(ogb3_body_state);
    if (field == UINT32_MAX) {
      *offset = 0;
      return OGB3_OK;
    }
    ARG(field < 8);
    *offset = offsets[field];
    return OGB3_OK;
  }
  default:
    return OGB3_INVALID_ARGUMENT;
  }
}

ogb3_status ogb3_body_retarget(ogb3_world w, ogb3_body from, ogb3_body *out) {
  ARG(out);
  *out = 0;
  WORLD(w);
  b3BodyId id = body_id(from);
  ARG(id.index1 > 0);
  id.world0 = world_id(w).index1 - 1;
  if (!b3Body_IsValid(id))
    return OGB3_INVALID_HANDLE;
  *out = body_bits(id);
  return OGB3_OK;
}

ogb3_status ogb3_shape_retarget(ogb3_world w, ogb3_shape from,
                                ogb3_shape *out) {
  ARG(out);
  *out = 0;
  WORLD(w);
  b3ShapeId id = shape_id(from);
  ARG(id.index1 > 0);
  id.world0 = world_id(w).index1 - 1;
  if (!b3Shape_IsValid(id))
    return OGB3_INVALID_HANDLE;
  *out = shape_bits(id);
  return OGB3_OK;
}

ogb3_status ogb3_joint_retarget(ogb3_world w, ogb3_joint from,
                                ogb3_joint *out) {
  ARG(out);
  *out = 0;
  WORLD(w);
  b3JointId id = joint_id(from);
  ARG(id.index1 > 0);
  id.world0 = world_id(w).index1 - 1;
  if (!b3Joint_IsValid(id))
    return OGB3_INVALID_HANDLE;
  *out = joint_bits(id);
  return OGB3_OK;
}

static int canonical_key(uint64_t key) {
  return (uint32_t)key > 0 && (uint32_t)key <= INT32_MAX &&
         (key >> 32) <= UINT16_MAX;
}
#define KEY_FUNCTIONS(kind, Native, VALID, BITS, UNPACK)                       \
  ogb3_status ogb3_##kind##_get_key(ogb3_##kind value,                         \
                                    ogb3_##kind##_key *out) {                  \
    ARG(out);                                                                  \
    Native id = UNPACK(value);                                                 \
    if (id.index1 <= 0 || !VALID(id))                                          \
      return OGB3_INVALID_HANDLE;                                              \
    *out = (uint32_t)id.index1 | ((uint64_t)id.generation << 32);              \
    return OGB3_OK;                                                            \
  }                                                                            \
  ogb3_status ogb3_##kind##_resolve(ogb3_world world, ogb3_##kind##_key key,   \
                                    ogb3_##kind *out) {                        \
    ARG(out && canonical_key(key));                                            \
    WORLD(world);                                                              \
    Native id = {0};                                                           \
    id.index1 = (int32_t)(uint32_t)key;                                        \
    id.world0 = world_id(world).index1 - 1;                                    \
    id.generation = (uint16_t)(key >> 32);                                     \
    if (!VALID(id))                                                            \
      return OGB3_INVALID_HANDLE;                                              \
    *out = BITS(id);                                                           \
    return OGB3_OK;                                                            \
  }
KEY_FUNCTIONS(body, b3BodyId, b3Body_IsValid, body_bits, body_id)
KEY_FUNCTIONS(shape, b3ShapeId, b3Shape_IsValid, shape_bits, shape_id)
KEY_FUNCTIONS(joint, b3JointId, b3Joint_IsValid, joint_bits, joint_id)
#undef KEY_FUNCTIONS
ogb3_status ogb3_world_get_counters(ogb3_world world,
                                    ogb3_world_counters *out) {
  ARG(out);
  WORLD(world);
  if (b3GetWorldFromId(world_id(world))->locked)
    return OGB3_INVALID_ARGUMENT;
  b3Counters c = b3World_GetCounters(world_id(world));
  int values[] = {c.bodyCount,  c.shapeCount,  c.contactCount,
                  c.jointCount, c.islandCount, c.treeHeight};
  for (unsigned i = 0; i < 6; i++)
    if (values[i] < 0)
      return OGB3_CORRUPT;
  *out = (ogb3_world_counters){
      (uint32_t)c.bodyCount,  (uint32_t)c.shapeCount,  (uint32_t)c.contactCount,
      (uint32_t)c.jointCount, (uint32_t)c.islandCount, (uint32_t)c.treeHeight};
  return OGB3_OK;
}

ogb3_status ogb3_shape_key_from_handle(ogb3_shape from, ogb3_shape_key *out) {
  ARG(out);
  b3ShapeId id = shape_id(from);
  ARG(id.index1 > 0 && id.world0 < B3_MAX_WORLDS);
  *out = (uint32_t)id.index1 | ((uint64_t)id.generation << 32);
  return OGB3_OK;
}
