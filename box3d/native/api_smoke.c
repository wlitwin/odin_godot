#include "api.h"
#include "owned_snapshot.h"
#include <assert.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#define OK(x) assert((x) == OGB3_OK)
static void maximum_public_worlds(void) {
  ogb3_world worlds[OGB3_WORLD_CAPACITY];
  ogb3_world_def def;
  OK(ogb3_world_def_default(&def));
  /* No explicit fingerprint call before filling every public world slot. The
   * first public create must have bootstrapped and cached the probe already. */
  for (uint32_t i = 0; i < OGB3_WORLD_CAPACITY; ++i)
    OK(ogb3_world_create(&def, &worlds[i]));
  uint64_t cached = ogb3_build_fingerprint();
  assert(cached != 0);
  ogb3_world excess = UINT32_MAX;
  assert(ogb3_world_create(&def, &excess) == OGB3_CAPACITY && excess == 0);
  ogb3_snapshot *snapshot = NULL;
  OK(ogb3_snapshot_capture(worlds[0], &snapshot));
  assert(snapshot != NULL);
  ogb3_vec3 gravity;
  OK(ogb3_world_get_gravity(worlds[1], &gravity));
  gravity.y -= 3;
  OK(ogb3_world_set_gravity(worlds[1], &gravity));
  ogb3_allocation_stats before, after;
  OK(ogb3_engine_allocation_stats(&before));
  assert(ogb3_snapshot_restore(worlds[1], snapshot) == OGB3_CAPACITY);
  OK(ogb3_engine_allocation_stats(&after));
  assert(before.live_bytes == after.live_bytes);
  ogb3_vec3 unchanged;
  OK(ogb3_world_get_gravity(worlds[1], &unchanged));
  assert(unchanged.y == gravity.y);
  assert(ogb3_build_fingerprint() == cached);
  /* Free exactly the scratch slot required for restore, then prove capture's
   * owned resource remains usable at the documented capacity boundary. */
  OK(ogb3_world_destroy(worlds[OGB3_WORLD_CAPACITY - 1]));
  OK(ogb3_snapshot_restore(worlds[1], snapshot));
  ogb3_snapshot_release(snapshot);
  for (uint32_t i = 0; i + 1 < OGB3_WORLD_CAPACITY; ++i)
    OK(ogb3_world_destroy(worlds[i]));
  OK(ogb3_engine_allocation_stats(&after));
  assert(after.live_bytes == 0);
  puts("PASS world capacity: cached fingerprint, saturated capture, atomic "
       "restore rejection, spare-slot restore and zero engine leaks");
}
static void body_type_roundtrip(void) {
  ogb3_world_def wd;
  OK(ogb3_world_def_default(&wd));
  wd.gravity = (ogb3_vec3){0, 0, 0};
  ogb3_world w;
  OK(ogb3_world_create(&wd, &w));
  ogb3_body_def def;
  OK(ogb3_body_def_default(&def));
  def.type = OGB3_DYNAMIC;
  ogb3_body body;
  OK(ogb3_body_create(w, &def, &body));
  ogb3_shape_def sd;
  OK(ogb3_shape_def_default(&sd));
  ogb3_shape shape;
  OK(ogb3_shape_box(body, &sd, &(ogb3_vec3){.25f, .25f, .25f}, &shape));
  ogb3_body_key key;
  OK(ogb3_body_get_key(body, &key));
  float mass;
  OK(ogb3_body_get_mass(body, &mass));
  assert(mass > 0);
  assert(ogb3_body_set_type(body, -1) == OGB3_INVALID_ARGUMENT);
  assert(ogb3_body_set_type(body, 3) == OGB3_INVALID_ARGUMENT);
  OK(ogb3_body_set_type(body, OGB3_KINEMATIC));
  OK(ogb3_body_get_mass(body, &mass));
  assert(mass == 0);
  ogb3_snapshot *immediate = NULL;
  OK(ogb3_snapshot_capture(w, &immediate));
  ogb3_body_state immediate_state;
  OK(ogb3_snapshot_body_state(immediate, key, &immediate_state));
  assert(immediate_state.type == OGB3_KINEMATIC && immediate_state.mass == 0);
  ogb3_snapshot_release(immediate);
  OK(ogb3_body_set_velocity(body, &(ogb3_vec3){.25f, 0, 0},
                            &(ogb3_vec3){0, 0, 0}));
  OK(ogb3_world_step_fixed(w));
  ogb3_snapshot *saved = NULL;
  OK(ogb3_snapshot_capture(w, &saved));
  ogb3_body_state state;
  OK(ogb3_snapshot_body_state(saved, key, &state));
  assert(state.type == OGB3_KINEMATIC && state.mass == 0 && state.pose.position.x > 0);
  OK(ogb3_world_destroy(w));
  OK(ogb3_world_create(&wd, &w));
  OK(ogb3_snapshot_restore(w, saved));
  ogb3_snapshot_release(saved);
  OK(ogb3_body_resolve(w, key, &body));
  OK(ogb3_body_set_type(body, OGB3_DYNAMIC));
  ogb3_body_key same;
  OK(ogb3_body_get_key(body, &same));
  OK(ogb3_body_get_mass(body, &mass));
  assert(same == key && mass > 0);
  OK(ogb3_world_step_fixed(w));
  OK(ogb3_world_destroy(w));
  puts("PASS body type: invalid refusal, kinematic cache/source-free restore, dynamic mass and stable identity");
}
/* Box3D caps spin at a quarter turn per step unless a body allows fast
 * rotation. The flag must survive a snapshot restore and a Kinematic to
 * Dynamic switch, which is how Replay steps and how games put balls in play. */
static void fast_rotation(void) {
  ogb3_world_def wd;
  OK(ogb3_world_def_default(&wd));
  wd.gravity = (ogb3_vec3){0, 0, 0};
  for (uint32_t allow = 0; allow <= 1; ++allow) {
    ogb3_world w;
    OK(ogb3_world_create(&wd, &w));
    ogb3_body_def def;
    OK(ogb3_body_def_default(&def));
    assert(def.allow_fast_rotation == 0);
    def.type = OGB3_KINEMATIC;
    def.allow_fast_rotation = allow;
    ogb3_body body;
    OK(ogb3_body_create(w, &def, &body));
    ogb3_shape_def sd;
    OK(ogb3_shape_def_default(&sd));
    ogb3_shape shape;
    OK(ogb3_shape_sphere(body, &sd, &(ogb3_vec3){0, 0, 0}, .035f, &shape));
    ogb3_body_key key;
    OK(ogb3_body_get_key(body, &key));
    ogb3_snapshot *saved = NULL;
    OK(ogb3_snapshot_capture(w, &saved));
    OK(ogb3_world_destroy(w));
    OK(ogb3_world_create(&wd, &w));
    OK(ogb3_snapshot_restore(w, saved));
    ogb3_snapshot_release(saved);
    OK(ogb3_body_resolve(w, key, &body));
    OK(ogb3_body_set_type(body, OGB3_DYNAMIC));
    OK(ogb3_body_set_velocity(body, &(ogb3_vec3){0, 0, 0},
                              &(ogb3_vec3){200, 0, 0}));
    OK(ogb3_world_step_fixed(w));
    ogb3_snapshot *after = NULL;
    OK(ogb3_snapshot_capture(w, &after));
    ogb3_body_state state;
    OK(ogb3_snapshot_body_state(after, key, &state));
    ogb3_snapshot_release(after);
    float spin = state.angular_velocity.x;
    assert(allow ? spin > 190 : spin < 50);
    OK(ogb3_world_destroy(w));
  }
  ogb3_world w;
  OK(ogb3_world_create(&wd, &w));
  ogb3_body_def bad;
  OK(ogb3_body_def_default(&bad));
  bad.allow_fast_rotation = 2;
  ogb3_body body;
  assert(ogb3_body_create(w, &bad, &body) == OGB3_INVALID_ARGUMENT);
  OK(ogb3_world_destroy(w));
  puts("PASS fast rotation: capped at a quarter turn per step without the flag, "
       "kept with it through restore and a Kinematic to Dynamic switch");
}
/* A sphere rolling (or resting) on a static floor for one second; returns its
 * final velocity. */
static ogb3_vec3 roll_on_floor(float rolling_resistance, ogb3_vec3 conveyor,
                               ogb3_vec3 start) {
  ogb3_world_def wd;
  OK(ogb3_world_def_default(&wd));
  ogb3_world w;
  OK(ogb3_world_create(&wd, &w));
  ogb3_body_def fd;
  OK(ogb3_body_def_default(&fd));
  fd.pose.position.y = -.5f;
  ogb3_body floor;
  OK(ogb3_body_create(w, &fd, &floor));
  ogb3_shape_def sd;
  OK(ogb3_shape_def_default(&sd));
  sd.tangent_velocity = conveyor;
  ogb3_shape shape;
  OK(ogb3_shape_box(floor, &sd, &(ogb3_vec3){50, .5f, 50}, &shape));
  ogb3_body_def bd;
  OK(ogb3_body_def_default(&bd));
  bd.type = OGB3_DYNAMIC;
  bd.allow_fast_rotation = 1;
  bd.pose.position.y = .25f;
  bd.linear_velocity = start;
  bd.angular_velocity = (ogb3_vec3){start.z / .25f, 0, -start.x / .25f};
  ogb3_body ball;
  OK(ogb3_body_create(w, &bd, &ball));
  OK(ogb3_shape_def_default(&sd));
  sd.rolling_resistance = rolling_resistance;
  OK(ogb3_shape_sphere(ball, &sd, &(ogb3_vec3){0, 0, 0}, .25f, &shape));
  for (int i = 0; i < 60; ++i)
    OK(ogb3_world_step_fixed(w));
  ogb3_vec3 v, wv;
  OK(ogb3_body_get_velocity(ball, &v, &wv));
  OK(ogb3_world_destroy(w));
  return v;
}
/* ABI 2 world, body and shape settings reach Box3D and are range-checked. */
static void abi2_settings(void) {
  ogb3_world_def wd;
  OK(ogb3_world_def_default(&wd));
  assert(wd.contact_speed == 0 && wd.restitution_iterations == 0 &&
         wd.enable_sleep == 1 && wd.enable_continuous == 1);
  ogb3_world w;
  ogb3_world_def bad = wd;
  bad.contact_hertz = -1;
  assert(ogb3_world_create(&bad, &w) == OGB3_INVALID_ARGUMENT);
  bad = wd;
  bad.isotropic_inertia_tolerance = 2;
  assert(ogb3_world_create(&bad, &w) == OGB3_INVALID_ARGUMENT);
  bad = wd;
  bad.restitution_iterations = 64;
  assert(ogb3_world_create(&bad, &w) == OGB3_INVALID_ARGUMENT);
  wd.contact_speed = 3;
  wd.restitution_threshold = 1;
  wd.gravity = (ogb3_vec3){0, 0, 0};
  OK(ogb3_world_create(&wd, &w));
  ogb3_body_def def;
  OK(ogb3_body_def_default(&def));
  def.type = OGB3_DYNAMIC;
  def.motion_locks = 64;
  ogb3_body body;
  assert(ogb3_body_create(w, &def, &body) == OGB3_INVALID_ARGUMENT);
  def.motion_locks = OGB3_LOCK_LINEAR_X;
  def.linear_velocity = (ogb3_vec3){1, 0, 1};
  OK(ogb3_body_create(w, &def, &body));
  ogb3_shape_def sd;
  OK(ogb3_shape_def_default(&sd));
  ogb3_shape shape;
  sd.rolling_resistance = -1;
  assert(ogb3_shape_box(body, &sd, &(ogb3_vec3){.25f, .25f, .25f}, &shape) ==
         OGB3_INVALID_ARGUMENT);
  sd.rolling_resistance = 0;
  OK(ogb3_shape_box(body, &sd, &(ogb3_vec3){.25f, .25f, .25f}, &shape));
  OK(ogb3_world_step_fixed(w));
  ogb3_pose pose;
  OK(ogb3_body_get_pose(body, &pose));
  assert(pose.position.x == 0 && pose.position.z > 0);
  OK(ogb3_world_destroy(w));
  float free_roll = roll_on_floor(0, (ogb3_vec3){0, 0, 0}, (ogb3_vec3){2, 0, 0}).x;
  float resisted = roll_on_floor(.5f, (ogb3_vec3){0, 0, 0}, (ogb3_vec3){2, 0, 0}).x;
  assert(free_roll > 1.8f && resisted < free_roll - .5f);
  ogb3_vec3 carried = roll_on_floor(0, (ogb3_vec3){1, 0, 0}, (ogb3_vec3){0, 0, 0});
  assert(fabsf(carried.x) > .1f);
  puts("PASS ABI 2 settings: world tuning range checks, motion locks, rolling "
       "resistance and conveyor tangent velocity reach Box3D");
}
int main(void) {
  assert(ogb3_abi_version() == 2);
  /* Before initialization the scale is settable and validated. */
  assert(ogb3_set_length_units_per_meter(0.0f) == OGB3_INVALID_ARGUMENT);
  assert(ogb3_set_length_units_per_meter(NAN) == OGB3_INVALID_ARGUMENT);
  OK(ogb3_set_length_units_per_meter(1.0f));
  assert(ogb3_get_length_units_per_meter() == 1.0f);
  uint32_t size, align, offset;
  uint32_t forged_valid;
  OK(ogb3_world_valid(1, &forged_valid));
  assert(!forged_valid);
  OK(ogb3_abi_layout(OGB3_T_BODY_DEF, 1, &size, &align, &offset));
  assert(size == 104 && align == 4 && offset == 4); /* ABI 2 body settings */
  maximum_public_worlds();
  /* Worlds now exist: the engine is initialized, so only the current scale is
   * accepted and a change is refused rather than silently ignored. */
  assert(ogb3_set_length_units_per_meter(2.0f) == OGB3_UNSUPPORTED);
  OK(ogb3_set_length_units_per_meter(1.0f));
  assert(ogb3_get_length_units_per_meter() == 1.0f);
  body_type_roundtrip();
  fast_rotation();
  abi2_settings();
  ogb3_world_def wd;
  OK(ogb3_world_def_default(&wd));
  ogb3_world w;
  OK(ogb3_world_create(&wd, &w));
  uint32_t valid;
  OK(ogb3_world_valid(w, &valid));
  assert(valid);
  assert(ogb3_world_step(w, NAN, 4) == OGB3_INVALID_ARGUMENT);
  assert(ogb3_world_step(w, 1.0f / 60, 0) == OGB3_INVALID_ARGUMENT);
  ogb3_body_def bd;
  OK(ogb3_body_def_default(&bd));
  ogb3_body ground, body;
  bd.pose.position.y = -1;
  OK(ogb3_body_create(w, &bd, &ground));
  ogb3_shape_def sd;
  OK(ogb3_shape_def_default(&sd));
  ogb3_shape floor, ball;
  OK(ogb3_shape_box(ground, &sd, &(ogb3_vec3){10, 1, 10}, &floor));
  bd.pose.rotation.w = 1.0001f;
  assert(ogb3_body_create(w, &bd, &body) == OGB3_INVALID_ARGUMENT);
  bd.pose.rotation.w = 1;
  bd.type = OGB3_DYNAMIC;
  bd.pose.position.y = 4;
  OK(ogb3_body_create(w, &bd, &body));
  sd.enable_sensor_events = 1;
  OK(ogb3_shape_sphere(body, &sd, &(ogb3_vec3){0}, 0.5f, &ball));
  float mass;
  OK(ogb3_body_get_mass(body, &mass));
  assert(mass > 0);
  for (int tick = 0; tick < 180; tick++)
    OK(ogb3_world_step_fixed(w));
  ogb3_pose p;
  OK(ogb3_body_get_pose(body, &p));
  assert(p.position.y > 0.45f && p.position.y < 0.55f);
  OK(ogb3_body_apply_impulse(body, &(ogb3_vec3){0, mass * 3, 0}, NULL, 1));
  ogb3_vec3 v, a;
  OK(ogb3_body_get_velocity(body, &v, &a));
  assert(v.y > 2.9f);
  ogb3_query_filter filter = {UINT64_MAX, UINT64_MAX};
  uint32_t count;
  assert(ogb3_world_overlap_aabb(w, &(ogb3_vec3){-20, -5, -20},
                                 &(ogb3_vec3){20, 20, 20}, &filter, NULL, 0,
                                 &count) == OGB3_CAPACITY &&
         count == 2);
  ogb3_shape found[4];
  OK(ogb3_world_overlap_aabb(w, &(ogb3_vec3){-20, -5, -20},
                             &(ogb3_vec3){20, 20, 20}, &filter, found, 4,
                             &count));
  assert(count == 2);
  ogb3_ray_hit hits[4];
  OK(ogb3_world_cast_ray(w, &(ogb3_vec3){0, 10, 0}, &(ogb3_vec3){0, -20, 0},
                         &filter, hits, 4, &count));
  assert(count == 2);
  for (uint32_t i = 0; i < count; i++)
    assert(hits[i].fraction > 0 && hits[i].fraction < 1);
  /* Sensor outputs are copied and report capacity without exposing native
   * buffers. */
  ogb3_body sensor_body;
  bd.type = OGB3_STATIC;
  bd.pose.position.y = 0.5f;
  OK(ogb3_body_create(w, &bd, &sensor_body));
  sd.is_sensor = sd.enable_sensor_events = 1;
  ogb3_shape sensor;
  OK(ogb3_shape_box(sensor_body, &sd, &(ogb3_vec3){2, 2, 2}, &sensor));
  OK(ogb3_world_step_fixed(w));
  ogb3_sensor_event events[8];
  OK(ogb3_world_sensor_events(w, events, 8, &count));
  assert(count > 0);
  assert(events[0].began == 1);
  /* Hinge motor actually drives a dynamic body around the local Z axis. */
  ogb3_body motor_body;
  OK(ogb3_body_def_default(&bd));
  bd.type = OGB3_DYNAMIC;
  bd.pose.position.y = 5;
  bd.gravity_scale = 0;
  bd.enable_sleep = 0;
  OK(ogb3_body_create(w, &bd, &motor_body));
  OK(ogb3_shape_def_default(&sd));
  ogb3_shape motor_shape;
  OK(ogb3_shape_box(motor_body, &sd, &(ogb3_vec3){0.2f, 0.5f, 0.2f},
                    &motor_shape));
  ogb3_hinge_def hd;
  OK(ogb3_hinge_def_default(&hd));
  hd.body_a = ground;
  hd.body_b = motor_body;
  hd.local_frame_a.position.y = 6.0f;
  hd.enable_motor = 1;
  hd.motor_speed = 2;
  hd.max_motor_torque = 100;
  ogb3_joint joint;
  OK(ogb3_joint_hinge_create(w, &hd, &joint));
  for (int i = 0; i < 30; i++)
    OK(ogb3_world_step_fixed(w));
  float angle;
  OK(ogb3_joint_hinge_get_angle(joint, &angle));
  assert(fabsf(angle) > 0.1f);
  OK(ogb3_joint_destroy(joint));
  /* Mesh input copies outlive the caller's resource reference. */
  ogb3_geometry *mesh;
  ogb3_vec3 verts[] = {{20, 0, 0}, {20, 0, 2}, {22, 0, 0}};
  uint32_t indices[] = {0, 1, 2};
  OK(ogb3_geometry_mesh(verts, 3, indices, 1, &mesh));
  ogb3_shape mesh_shape;
  OK(ogb3_shape_def_default(&sd));
  sd.enable_sensor_events = 1;
  assert(ogb3_shape_geometry(ground, &sd, mesh, &mesh_shape) ==
         OGB3_UNSUPPORTED);
  sd.enable_sensor_events = 0;
  OK(ogb3_shape_geometry(ground, &sd, mesh, &mesh_shape));
  ogb3_geometry_release(mesh);
  assert(ogb3_body_set_type(ground, OGB3_KINEMATIC) == OGB3_UNSUPPORTED);
  assert(ogb3_body_set_type(ground, OGB3_DYNAMIC) == OGB3_UNSUPPORTED);
  /* Unsupported transitions must not leave the upstream world locked. */
  OK(ogb3_body_set_type(ground, OGB3_STATIC));
  OK(ogb3_world_step_fixed(w));
  OK(ogb3_body_destroy(body));
  assert(ogb3_body_destroy(body) == OGB3_INVALID_HANDLE);
  OK(ogb3_shape_valid(ball, &valid));
  assert(!valid);
  ogb3_shape invalid = UINT64_C(0x80000000);
  OK(ogb3_shape_valid(invalid, &valid));
  assert(!valid);
  OK(ogb3_world_destroy(w));
  assert(ogb3_world_destroy(w) == OGB3_INVALID_HANDLE);
  ogb3_allocation_stats stats;
  OK(ogb3_engine_allocation_stats(&stats));
  assert(stats.total_calls > 0 && stats.high_water_bytes > 0 &&
         stats.live_bytes == 0);
  puts("PASS flat ABI: static/shared lifecycle, collisions, impulse, sensor, "
       "query capacity, hinge motor, mesh lease, invalid input and zero engine "
       "leaks");
  return 0;
}
