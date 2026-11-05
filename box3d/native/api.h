/* Framework-neutral Box3D ABI v1. Exact pinned build, single-thread caller.
 * Coordinates: meters, Y-up, right handed. Quaternions x,y,z,w.
 * Initialize PODs with defaults. All booleans are u32 0/1. No upstream structs
 * cross this boundary. Handles are memcpy-packed native IDs, local to a build;
 * they are not durable entity identities or a network format.
 * Calls and any host callbacks must not reenter this backend. Host callback
 * configuration stays fixed; this ABI does not expose callback setters. */
#ifndef OGB3_API_H
#define OGB3_API_H
#include <stdint.h>
#if defined(__GNUC__)
#define OGB3_API __attribute__((visibility("default")))
#else
#define OGB3_API
#endif
#ifdef __cplusplus
extern "C" {
#endif
typedef int32_t ogb3_status;
enum {
  OGB3_OK = 0,
  OGB3_INVALID_ARGUMENT = 1,
  OGB3_INVALID_HANDLE = 2,
  OGB3_OUT_OF_MEMORY = 3,
  OGB3_CAPACITY = 4,
  OGB3_UNSUPPORTED = 5,
  OGB3_INCOMPATIBLE = 6,
  OGB3_CORRUPT = 7
};
/* Exact pinned engine capacity, including temporary restore worlds. Capture
 * needs no spare slot after initialization; restore needs one spare slot. */
#define OGB3_WORLD_CAPACITY 128u
typedef uint32_t ogb3_world;
typedef uint64_t ogb3_body;
typedef uint64_t ogb3_shape;
typedef uint64_t ogb3_joint;
/* World-independent allocation keys: low32 index1, high32 generation (u16).
 * Keys are not permanent game/entity IDs. Zero/noncanonical keys are invalid.
 */
typedef uint64_t ogb3_body_key;
typedef uint64_t ogb3_shape_key;
typedef uint64_t ogb3_joint_key;
typedef struct ogb3_geometry ogb3_geometry;
typedef struct {
  float x, y, z;
} ogb3_vec3;
typedef struct {
  float x, y, z, w;
} ogb3_quat;
typedef struct {
  ogb3_vec3 position;
  ogb3_quat rotation;
} ogb3_pose;
typedef struct {
  uint32_t body_count, shape_count, contact_count, joint_count, island_count,
      tree_height; /* max(dynamic, kinematic), excludes static tree */
} ogb3_world_counters;
typedef struct {
  ogb3_body_key key;
  ogb3_pose pose;
  ogb3_vec3 linear_velocity, angular_velocity;
  float mass;
  int32_t type;
  uint32_t is_awake, is_enabled;
} ogb3_body_state;
typedef struct {
  ogb3_vec3 gravity;
  uint32_t enable_sleep, enable_continuous;
} ogb3_world_def;
enum { OGB3_STATIC = 0, OGB3_KINEMATIC = 1, OGB3_DYNAMIC = 2 };
typedef struct {
  int32_t type;
  ogb3_pose pose;
  ogb3_vec3 linear_velocity, angular_velocity;
  float linear_damping, angular_damping, gravity_scale, sleep_threshold;
  uint32_t enable_sleep, is_awake, is_bullet, is_enabled;
} ogb3_body_def;
typedef struct {
  uint64_t category_bits, mask_bits;
  int32_t group_index;
  float density, friction, restitution;
  uint32_t is_sensor, enable_sensor_events, enable_contact_events;
} ogb3_shape_def;
typedef struct {
  ogb3_body body_a, body_b;
  ogb3_pose local_frame_a, local_frame_b; /* hinge axis is local Z */
  float lower_angle, upper_angle, motor_speed, max_motor_torque;
  uint32_t enable_limit, enable_motor, collide_connected;
} ogb3_hinge_def;
typedef struct {
  uint64_t category_bits, mask_bits;
} ogb3_query_filter;
typedef struct {
  ogb3_shape shape;
  ogb3_vec3 point, normal;
  float fraction;
  uint32_t reserved;
} ogb3_ray_hit;
typedef struct {
  ogb3_shape sensor, visitor;
  uint32_t began, reserved;
} ogb3_sensor_event;
/* ABI type IDs for size/alignment/field-offset checks. field_index is
 * declaration order (including grouped fields), UINT32_MAX queries
 * size/alignment only. */
enum {
  OGB3_T_VEC3 = 1,
  OGB3_T_QUAT,
  OGB3_T_POSE,
  OGB3_T_WORLD_DEF,
  OGB3_T_BODY_DEF,
  OGB3_T_SHAPE_DEF,
  OGB3_T_HINGE_DEF,
  OGB3_T_QUERY_FILTER,
  OGB3_T_RAY_HIT,
  OGB3_T_SENSOR_EVENT,
  OGB3_T_ALLOCATION_STATS,
  OGB3_T_WORLD_COUNTERS,
  OGB3_T_BODY_STATE,
  OGB3_T_DOMAIN_CONTRACT,
  OGB3_T_HOST_OWNER_INFO,
  OGB3_T_HOST_LEDGER_STATS
};
typedef struct {
  uint64_t total_calls, total_bytes, live_bytes, high_water_bytes;
} ogb3_allocation_stats;
/* Engine allocator only, cumulative since first world/geometry initialization;
 * includes engine recording allocations, excludes wrapper malloc and snapshot
 * owner malloc. Upstream engine OOM is fatal/asserting, not recoverable status.
 * One ogb3 engine instance per process; do not mix allocator/global-unit
 * owners. */
OGB3_API ogb3_status ogb3_engine_allocation_stats(ogb3_allocation_stats *);
/* Loaded-image identity, NOT a build fingerprint or durable/network ID. The
 * cookie is the address of a hidden image-local anchor, valid only while that
 * image stays loaded. A host must pin the DSO and reject a different cookie
 * BEFORE passing any handles/pointers. C cannot infer a caller's module.
 * These calls do not initialize the engine, allocate, or create a world.
 * build/target are SHA256 bytes embedded from effective verified CMake inputs;
 * build is the source+configuration identity (not recovery's derived digest).
 * endian: 1=little, 2=big. No pointers/strings/native structs cross this POD.
 */
#define OGB3_DOMAIN_CONTRACT_VERSION 1u
#define OGB3_HOST_OWNER_CAPACITY 256u
#define OGB3_HOST_LIMIT_BYTES UINT64_C(67108864)
typedef struct {
  uint64_t cookie;
  uint32_t size, version, abi_version, logical_version, resource_version,
      recovery_version, pointer_bits, endian;
  uint8_t build[32], target[32];
} ogb3_domain_contract; /* 104 bytes, alignment 8 on supported targets */
OGB3_API ogb3_status ogb3_domain_contract_get(ogb3_domain_contract *);
OGB3_API ogb3_status
ogb3_domain_contract_check(const ogb3_domain_contract *expected);
typedef uint64_t
    ogb3_host_owner; /* opaque, domain-local capability, not auth */
typedef struct {
  uint64_t producer, component, live_bytes, reserved_bytes;
} ogb3_host_owner_info;
typedef struct {
  uint64_t engine_live_bytes, snapshot_live_bytes, host_live_bytes,
      host_reserved_bytes, live_bytes, admitted_bytes, limit_bytes,
      committed_peak_bytes, successful_updates, ledger_storage_bytes;
  uint32_t owner_count, owner_capacity;
} ogb3_host_ledger_stats; /* 88 bytes on supported targets */
/* One bounded ledger in this native image; single caller/nonreentrant. Distinct
 * nonzero producer/component pairs may register once. The host supplies actual
 * producer/component identities; neither a world nor Odin typeid identifies a
 * producer. Tokens reject malformed/stale/released values; possession is not
 * security authentication. All outputs and ledger state survive failed calls.
 * Cookie mismatch = INCOMPATIBLE; bad token = INVALID_HANDLE; duplicate pair
 * or missing output/zero producer/component = INVALID_ARGUMENT; byte overflow,
 * no slot or over budget = CAPACITY.
 *
 * set replaces this token's ABSOLUTE live/reserved contribution atomically.
 * Reservations are owned promises, not allocated bytes. Convert reservation to
 * live in one set; release every failed/unused reservation. close removes both
 * contributions and invalidates the token; call after freeing owned storage.
 * Neither close nor a nonincreasing set is prevented by a native allocation
 * that has already put the domain over budget (cleanup must remain possible).
 *
 * check performs the same proposed replacement without changing anything.
 * token=0 means no replacement (proposed_live/reserved MUST be zero).
 * Additional live/reserved are ONLY unregistered extras, never
 * already-registered charges. required = engine requested + snapshot-wrapper
 * requested ONCE + other tokens
 * + proposed own live/reserved + additional live/reserved. <=64MiB is accepted.
 * This is admission/accounting, not an allocator hard cap or recovered engine
 * OOM guarantee. Legacy native allocation APIs retain their existing semantics.
 *
 * stats observes current bytes even if over budget. committed_peak samples
 * successful ledger mutations only, NOT all engine allocation peaks. Static
 * ledger storage is reported separately as overhead, not host requested bytes.
 * Metadata/ledger operations allocate nothing and never step/mutate a world.
 */
OGB3_API ogb3_status ogb3_host_owner_open(uint64_t cookie, uint64_t producer,
                                          uint64_t component,
                                          ogb3_host_owner *out);
OGB3_API ogb3_status ogb3_host_owner_set(uint64_t cookie, ogb3_host_owner,
                                         uint64_t live, uint64_t reserved);
OGB3_API ogb3_status ogb3_host_owner_get(uint64_t cookie, ogb3_host_owner,
                                         ogb3_host_owner_info *out);
OGB3_API ogb3_status ogb3_host_owner_close(uint64_t cookie, ogb3_host_owner);
OGB3_API ogb3_status ogb3_host_memory_check(uint64_t cookie, ogb3_host_owner,
                                            uint64_t proposed_live,
                                            uint64_t proposed_reserved,
                                            uint64_t additional_live,
                                            uint64_t additional_reserved,
                                            uint64_t *required);
OGB3_API ogb3_status ogb3_host_ledger_get(uint64_t cookie,
                                          ogb3_host_ledger_stats *out);
/* Retarget snapshot-era local identity into a restored destination world;
 * verifies destination object generation, not application entity identity. */
OGB3_API ogb3_status ogb3_body_retarget(ogb3_world, ogb3_body, ogb3_body *);
OGB3_API ogb3_status ogb3_shape_retarget(ogb3_world, ogb3_shape, ogb3_shape *);
OGB3_API ogb3_status ogb3_joint_retarget(ogb3_world, ogb3_joint, ogb3_joint *);
OGB3_API ogb3_status ogb3_body_identity(ogb3_body, uint32_t *index1,
                                        uint32_t *generation);
OGB3_API uint32_t ogb3_abi_version(void);
OGB3_API ogb3_status ogb3_abi_layout(uint32_t type, uint32_t field_index,
                                     uint32_t *size, uint32_t *alignment,
                                     uint32_t *offset);
/* Diagnostic only; not a complete-state digest. Complete digest: state_dump.h.
 * Prewarmed before the first public world/geometry creation and then cached.
 * Returns zero if an unprimed probe cannot safely initialize (no world slot or
 * another owner already has live native worlds). Zero is NOT a compatibility
 * token. Snapshot capture/validation report OGB3_CAPACITY for this condition.
 */
OGB3_API uint64_t ogb3_build_fingerprint(void);
/* Process-wide length scale: Box3D's lengthUnitsPerMeter, default 1. Contact
 * slop (0.005 m x units), speculative distance and AABB margins scale with it,
 * so scenes much smaller than a metre (a 3 cm ball) can use e.g. 0.1. Set it
 * before the first world, geometry or ogb3_build_fingerprint call in the
 * process; after that only the current value is accepted (OGB3_UNSUPPORTED).
 * The determinism fingerprint is computed with the chosen value, so processes
 * using different values never match. Kit/Replay are validated with 1 only. */
OGB3_API ogb3_status ogb3_set_length_units_per_meter(float units);
OGB3_API float ogb3_get_length_units_per_meter(void);
OGB3_API ogb3_status ogb3_world_def_default(ogb3_world_def *);
OGB3_API ogb3_status ogb3_body_def_default(ogb3_body_def *);
OGB3_API ogb3_status ogb3_shape_def_default(ogb3_shape_def *);
OGB3_API ogb3_status ogb3_hinge_def_default(ogb3_hinge_def *);
OGB3_API ogb3_status ogb3_world_create(const ogb3_world_def *, ogb3_world *);
OGB3_API ogb3_status ogb3_world_destroy(ogb3_world);
OGB3_API ogb3_status ogb3_world_valid(ogb3_world, uint32_t *);
OGB3_API ogb3_status ogb3_world_get_counters(ogb3_world, ogb3_world_counters *);
/* Checked live-handle->key and key->destination resolution. Native failure
 * leaves output unchanged. All private ID construction stays in C. */
OGB3_API ogb3_status ogb3_body_get_key(ogb3_body, ogb3_body_key *);
OGB3_API ogb3_status ogb3_shape_get_key(ogb3_shape, ogb3_shape_key *);
/* Structural identity decoding for copied sensor-end IDs, which may refer to
 * destroyed shapes/worlds. This does NOT establish liveness or game identity.
 * Resolution into execution remains checked by ogb3_shape_resolve. */
OGB3_API ogb3_status ogb3_shape_key_from_handle(ogb3_shape, ogb3_shape_key *);
OGB3_API ogb3_status ogb3_joint_get_key(ogb3_joint, ogb3_joint_key *);
OGB3_API ogb3_status ogb3_body_resolve(ogb3_world, ogb3_body_key, ogb3_body *);
OGB3_API ogb3_status ogb3_shape_resolve(ogb3_world, ogb3_shape_key,
                                        ogb3_shape *);
OGB3_API ogb3_status ogb3_joint_resolve(ogb3_world, ogb3_joint_key,
                                        ogb3_joint *);
OGB3_API ogb3_status ogb3_world_step(ogb3_world, float seconds,
                                     uint32_t substeps);
OGB3_API ogb3_status ogb3_world_step_fixed(ogb3_world); /* 1/60 s, 4 substeps */
OGB3_API ogb3_status ogb3_world_get_gravity(ogb3_world, ogb3_vec3 *);
OGB3_API ogb3_status ogb3_world_set_gravity(ogb3_world, const ogb3_vec3 *);
OGB3_API ogb3_status ogb3_body_create(ogb3_world, const ogb3_body_def *,
                                      ogb3_body *);
OGB3_API ogb3_status ogb3_body_destroy(ogb3_body);
OGB3_API ogb3_status ogb3_body_valid(ogb3_body, uint32_t *);
OGB3_API ogb3_status ogb3_body_get_pose(ogb3_body, ogb3_pose *);
OGB3_API ogb3_status ogb3_body_set_pose(ogb3_body, const ogb3_pose *);
/* Compatible flat API addition; POD layouts/ABI1 are unchanged. Mesh and
 * height/compound bodies remain static-only. */
OGB3_API ogb3_status ogb3_body_set_type(ogb3_body, int32_t);
OGB3_API ogb3_status ogb3_body_get_velocity(ogb3_body, ogb3_vec3 *,
                                            ogb3_vec3 *);
OGB3_API ogb3_status ogb3_body_set_velocity(ogb3_body, const ogb3_vec3 *,
                                            const ogb3_vec3 *);
OGB3_API ogb3_status ogb3_body_apply_impulse(
    ogb3_body, const ogb3_vec3 *, const ogb3_vec3 *world_point,
    uint32_t wake); /* NULL point = center */
OGB3_API ogb3_status ogb3_body_apply_angular_impulse(ogb3_body,
                                                     const ogb3_vec3 *,
                                                     uint32_t wake);
OGB3_API ogb3_status ogb3_body_set_awake(ogb3_body, uint32_t);
OGB3_API ogb3_status ogb3_body_get_awake(ogb3_body, uint32_t *);
OGB3_API ogb3_status ogb3_body_get_mass(ogb3_body, float *);
/* Immutable geometry owns copied inputs. Release caller ref at any time after
 * shape creation: each destination world retains a lease until world_destroy,
 * including destroyed-shape history. Predeclare bounded assets for this spike.
 * Meshes require static bodies and do not support sensor or sensor-event flags.
 * Snapshot resources independently own restored geometry (owned_snapshot.h). */
OGB3_API ogb3_status ogb3_geometry_hull(const ogb3_vec3 *points, uint32_t count,
                                        ogb3_geometry **);
OGB3_API ogb3_status ogb3_geometry_mesh(const ogb3_vec3 *vertices,
                                        uint32_t vertex_count,
                                        const uint32_t *indices,
                                        uint32_t triangle_count,
                                        ogb3_geometry **);
OGB3_API void ogb3_geometry_release(ogb3_geometry *);
OGB3_API ogb3_status ogb3_shape_box(ogb3_body, const ogb3_shape_def *,
                                    const ogb3_vec3 *half_extents,
                                    ogb3_shape *);
OGB3_API ogb3_status ogb3_shape_sphere(ogb3_body, const ogb3_shape_def *,
                                       const ogb3_vec3 *center, float radius,
                                       ogb3_shape *);
OGB3_API ogb3_status ogb3_shape_capsule(ogb3_body, const ogb3_shape_def *,
                                        const ogb3_vec3 *, const ogb3_vec3 *,
                                        float radius, ogb3_shape *);
OGB3_API ogb3_status ogb3_shape_geometry(ogb3_body, const ogb3_shape_def *,
                                         ogb3_geometry *, ogb3_shape *);
OGB3_API ogb3_status ogb3_shape_destroy(ogb3_shape);
OGB3_API ogb3_status ogb3_shape_valid(ogb3_shape, uint32_t *);
OGB3_API ogb3_status ogb3_shape_get_body(ogb3_shape, ogb3_body *);
OGB3_API ogb3_status ogb3_shape_get_aabb(ogb3_shape, ogb3_vec3 *lower,
                                         ogb3_vec3 *upper);
/* Arrays are caller-owned copies. *count = total available; CAPACITY means a
 * prefix was copied. NULL array with zero capacity is a valid size query.
 * Query order follows the engine; consumers may sort by stable application ID.
 */
OGB3_API ogb3_status ogb3_world_overlap_aabb(ogb3_world, const ogb3_vec3 *,
                                             const ogb3_vec3 *,
                                             const ogb3_query_filter *,
                                             ogb3_shape *, uint32_t capacity,
                                             uint32_t *count);
OGB3_API ogb3_status ogb3_world_cast_ray(ogb3_world, const ogb3_vec3 *origin,
                                         const ogb3_vec3 *translation,
                                         const ogb3_query_filter *,
                                         ogb3_ray_hit *, uint32_t capacity,
                                         uint32_t *count);
OGB3_API ogb3_status ogb3_world_sensor_events(ogb3_world, ogb3_sensor_event *,
                                              uint32_t capacity,
                                              uint32_t *count);
OGB3_API ogb3_status ogb3_joint_hinge_create(ogb3_world, const ogb3_hinge_def *,
                                             ogb3_joint *);
OGB3_API ogb3_status ogb3_joint_destroy(ogb3_joint);
OGB3_API ogb3_status ogb3_joint_valid(ogb3_joint, uint32_t *);
OGB3_API ogb3_status ogb3_joint_hinge_set_motor(ogb3_joint, uint32_t enabled,
                                                float speed, float max_torque);
OGB3_API ogb3_status ogb3_joint_hinge_get_angle(ogb3_joint, float *);
#ifdef __cplusplus
}
#endif
#endif
