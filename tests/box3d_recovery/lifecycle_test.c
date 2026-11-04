#include "api.h"
#include "box3d/box3d.h"
#include "owned_snapshot.h"
#include "recovery_codec.h"
#include "state_dump.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define OK(x)                                                                  \
  do {                                                                         \
    ogb3_status result_ = (x);                                                 \
    if (result_) {                                                             \
      fprintf(stderr, "line%d status%d\n", __LINE__, result_);                 \
      abort();                                                                 \
    }                                                                          \
  } while (0)
static const ogb3_recovery_asset assets[] = {
    {.id = 1, .kind = OGB3_RECOVERY_BOX, .a = {5, .5f, 5}},
    {.id = 2, .kind = OGB3_RECOVERY_BOX, .a = {.5f, .5f, .5f}},
    {.id = 3, .kind = OGB3_RECOVERY_SPHERE, .radius = 4},
    {.id = 4, .kind = OGB3_RECOVERY_SPHERE, .radius = .25f},
    {.id = 5,
     .kind = OGB3_RECOVERY_CAPSULE,
     .a = {0, -.25f, 0},
     .b = {0, .25f, 0},
     .radius = .2f}};
static b3WorldId native(ogb3_world w) {
  b3WorldId id;
  memcpy(&id, &w, sizeof(id));
  return id;
}
static void equal(ogb3_world a, ogb3_world b) {
  uint64_t na, nb;
  OK(ogb3_state_dump(a, NULL, 0, &na));
  OK(ogb3_state_dump(b, NULL, 0, &nb));
  assert(na == nb);
  uint8_t *pa = malloc(na), *pb = malloc(nb);
  assert(pa && pb);
  OK(ogb3_state_dump(a, pa, na, &na));
  OK(ogb3_state_dump(b, pb, nb, &nb));
  assert(!memcmp(pa, pb, na));
  free(pa);
  free(pb);
}
static uint8_t *encode(const ogb3_recovery_catalog *c, ogb3_world w,
                       uint64_t *n) {
  ogb3_snapshot *s;
  OK(ogb3_snapshot_capture(w, &s));
  ogb3_recovery_diagnostic diag={0};ogb3_status write_status=ogb3_recovery_write(c,s,NULL,0,n,&diag);
  if(write_status)fprintf(stderr,"lifecycle write status%d section%u record%u field%u reason%u\n",write_status,diag.section,diag.record,diag.field,diag.reason);
  OK(write_status);
  uint8_t *p = malloc(*n);
  assert(p);
  memset(p, 0xa5, *n);
  uint64_t required = 0;
  assert(ogb3_recovery_write(c, s, p, *n - 1, &required, NULL) ==
             OGB3_CAPACITY &&
         required == *n);
  for (uint64_t i = 0; i < *n; i++)
    assert(p[i] == 0xa5);
  OK(ogb3_recovery_write(c, s, p, *n, n, NULL));
  ogb3_snapshot_release(s);
  return p;
}
static void roundtrip(const ogb3_recovery_catalog *c, ogb3_world source,
                      int suffix) {
  uint64_t n;
  uint8_t *p = encode(c, source, &n);
  ogb3_snapshot *s = NULL;
  ogb3_recovery_diagnostic d;
  ogb3_status status = ogb3_recovery_read(c, p, n, 0, &s, &d);
  if (status)
    fprintf(stderr, "read%d section%u record%u reason%u\n", status, d.section,
            d.record, d.reason);
  assert(status == 0);
  ogb3_world_def def;
  ogb3_world target;
  OK(ogb3_world_def_default(&def));
  OK(ogb3_world_create(&def, &target));
  OK(ogb3_snapshot_restore(target, s));
  ogb3_snapshot_release(s);
  free(p);
  equal(source, target);
  for (int i = 0; i < suffix; i++) {
    OK(ogb3_world_step_fixed(source));
    OK(ogb3_world_step_fixed(target));
    equal(source, target);
  }
  OK(ogb3_world_destroy(target));
}
static ogb3_body body(ogb3_world w, int type, ogb3_vec3 p, int enabled) {
  ogb3_body_def d;
  ogb3_body b;
  OK(ogb3_body_def_default(&d));
  d.type = type;
  d.pose.position = p;
  d.is_enabled = enabled;
  OK(ogb3_body_create(w, &d, &b));
  return b;
}
static void defaults_and_assets(const ogb3_recovery_catalog *c) {
  ogb3_world_def def;
  ogb3_world w;
  OK(ogb3_world_def_default(&def));
  OK(ogb3_world_create(&def, &w));
  roundtrip(c, w, 0);
  ogb3_shape_def sd;
  ogb3_shape s;
  OK(ogb3_shape_def_default(&sd));
  ogb3_body floor = body(w, OGB3_STATIC, (ogb3_vec3){0, -.5f, 0}, 1);
  OK(ogb3_shape_box(floor, &sd, &assets[0].a, &s));
  ogb3_body dyn = body(w, OGB3_DYNAMIC, (ogb3_vec3){0, .25f, 0}, 1);
  OK(ogb3_shape_sphere(dyn, &sd, &assets[3].a, assets[3].radius, &s));
  ogb3_body capsule = body(w, OGB3_DYNAMIC, (ogb3_vec3){.5f, .45f, 0}, 1);
  OK(ogb3_shape_capsule(capsule, &sd, &assets[4].a, &assets[4].b,
                        assets[4].radius, &s));
  ogb3_body disabled = body(w, OGB3_DYNAMIC, (ogb3_vec3){3, 3, 0}, 0);
  OK(ogb3_shape_capsule(disabled, &sd, &assets[4].a, &assets[4].b,
                        assets[4].radius, &s));
  ogb3_body kinematic = body(w, OGB3_KINEMATIC, (ogb3_vec3){4, 3, 0}, 1);
  OK(ogb3_shape_box(kinematic, &sd, &assets[1].a, &s));
  (void)body(w, OGB3_DYNAMIC, (ogb3_vec3){6, 4, 0},
             1); /* shapeless minExtent sentinel */
  ogb3_hinge_def hd;
  ogb3_joint hinge;
  OK(ogb3_hinge_def_default(&hd));
  hd.body_a = floor;
  hd.body_b = dyn;
  hd.local_frame_a.position.y = .75f;
  hd.collide_connected = 1;
  OK(ogb3_joint_hinge_create(w, &hd, &hinge));
  roundtrip(c, w,
            40); /* zero-step native defaults including FLT_MAX thresholds */
  OK(ogb3_joint_destroy(hinge));
  OK(ogb3_joint_hinge_create(w, &hd, &hinge));
  roundtrip(c, w, 40); /* newly prepared zero caches after time has advanced */
  OK(ogb3_body_set_awake(capsule, 0));
  roundtrip(c, w, 1);
  OK(ogb3_body_set_awake(capsule, 1));
  roundtrip(c, w, 8);
  OK(ogb3_world_destroy(w));
  puts("default/static/kinematic/disabled/shapeless/capsule/sphere/hinge reuse "
       "PASS");
}
static void pending_retired(const ogb3_recovery_catalog *c) {
  ogb3_world_def def;
  ogb3_world w, target;
  OK(ogb3_world_def_default(&def));
  OK(ogb3_world_create(&def, &w));
  OK(ogb3_world_create(&def, &target));
  ogb3_shape_def sd;
  ogb3_shape s;
  OK(ogb3_shape_def_default(&sd));
  sd.enable_contact_events = 1;
  sd.enable_sensor_events = 1;
  ogb3_body floor = body(w, OGB3_STATIC, (ogb3_vec3){0, -.5f, 0}, 1);
  OK(ogb3_shape_box(floor, &sd, &assets[0].a, &s));
  ogb3_body visitor = body(w, OGB3_DYNAMIC, (ogb3_vec3){0, .49f, 0}, 1);
  OK(ogb3_shape_box(visitor, &sd, &assets[1].a, &s));
  ogb3_body sensor = body(w, OGB3_STATIC, (ogb3_vec3){0, 1, 0}, 1);
  sd.is_sensor = 1;
  OK(ogb3_shape_sphere(sensor, &sd, &assets[2].a, 4, &s));
  OK(ogb3_world_step_fixed(w));
  OK(ogb3_body_destroy(visitor));
  /* Reuse the retired body's slots before encoding; pending keys retain their
   * former generations, not the current allocation's identity. */
  ogb3_body replacement = body(w, OGB3_DYNAMIC, (ogb3_vec3){8, 8, 0}, 1);
  sd.is_sensor = 0;
  OK(ogb3_shape_sphere(replacement, &sd, &assets[3].a, .25f, &s));
  uint64_t n;
  uint8_t *p = encode(c, w, &n);
  ogb3_snapshot *decoded;
  OK(ogb3_recovery_read(c, p, n, 0, &decoded, NULL));
  free(p);
  OK(ogb3_snapshot_restore(target, decoded));
  ogb3_snapshot_release(decoded);
  equal(w, target);
  for (int tick = 0; tick < 2; tick++) {
    OK(ogb3_world_step_fixed(w));
    OK(ogb3_world_step_fixed(target));
    equal(w, target);
    b3SensorEvents a = b3World_GetSensorEvents(native(w)),
                   b = b3World_GetSensorEvents(native(target));
    b3ContactEvents x = b3World_GetContactEvents(native(w)),
                    y = b3World_GetContactEvents(native(target));
    assert(a.endCount == b.endCount && x.endCount == y.endCount);
    assert(a.endCount == (tick == 0 ? 1 : 0));
    assert(x.endCount == (tick == 0 ? 1 : 0));
  }
  uint64_t saved;
  uint8_t *wire = encode(c, w, &saved);
  OK(ogb3_world_destroy(w));
  OK(ogb3_recovery_read(c, wire, saved, 0, &decoded, NULL));
  free(wire);
  OK(ogb3_snapshot_restore(target, decoded));
  ogb3_snapshot_release(decoded);
  OK(ogb3_world_step_fixed(target));
  OK(ogb3_world_destroy(target));
  puts("retired pending sensor/contact keys exactly once and source "
       "destruction PASS");
}
static void unsupported_assets(const ogb3_recovery_catalog *c) {
  ogb3_world_def def;
  ogb3_world w;
  OK(ogb3_world_def_default(&def));
  OK(ogb3_world_create(&def, &w));
  ogb3_body b = body(w, OGB3_STATIC, (ogb3_vec3){0}, 1);
  ogb3_shape_def sd;
  ogb3_shape shape;
  OK(ogb3_shape_def_default(&sd));
  ogb3_vec3 points[] = {{-1, 0, -1}, {1, 0, -1}, {1, 0, 1}, {-1, 0, 1}};
  uint32_t indices[] = {0, 2, 1, 0, 3, 2};
  ogb3_geometry *mesh;
  OK(ogb3_geometry_mesh(points, 4, indices, 2, &mesh));
  OK(ogb3_shape_geometry(b, &sd, mesh, &shape));
  ogb3_geometry_release(mesh);
  ogb3_snapshot *image;
  OK(ogb3_snapshot_capture(w, &image));
  ogb3_allocation_stats before, after;
  OK(ogb3_engine_allocation_stats(&before));
  uint64_t required = 0;
  assert(ogb3_recovery_world_admit(c, w, 0, &required, NULL) ==
         OGB3_UNSUPPORTED);
  assert(ogb3_recovery_write(c, image, NULL, 0, &required, NULL) ==
         OGB3_UNSUPPORTED);
  OK(ogb3_engine_allocation_stats(&after));
  assert(before.total_calls == after.total_calls);
  ogb3_snapshot_release(image);
  OK(ogb3_world_destroy(w));
  OK(ogb3_world_create(&def, &w));
  b = body(w, OGB3_STATIC, (ogb3_vec3){0}, 1);
  OK(ogb3_shape_box(b, &sd, &(ogb3_vec3){1, 1, 1}, &shape));
  OK(ogb3_snapshot_capture(w, &image));
  assert(ogb3_recovery_world_admit(c, w, 0, &required, NULL) ==
         OGB3_UNSUPPORTED);
  assert(ogb3_recovery_write(c, image, NULL, 0, &required, NULL) ==
         OGB3_UNSUPPORTED);
  ogb3_snapshot_release(image);
  OK(ogb3_world_destroy(w));
  puts("mesh and undeclared geometry rejected before scratch creation PASS");
}
int main(void) {
  ogb3_recovery_config cfg;
  OK(ogb3_recovery_config_default(&cfg));
  ogb3_recovery_catalog *c = NULL;
  ogb3_recovery_config wrong = cfg;
  wrong.build_target[0] ^= 1;
  assert(ogb3_recovery_catalog_create(&wrong, assets, 5, &c) ==
             OGB3_INCOMPATIBLE &&
         !c);
  ogb3_recovery_asset bad[5];
  memcpy(bad, assets, sizeof(bad));
  bad[1].id = bad[0].id;
  assert(ogb3_recovery_catalog_create(&cfg, bad, 5, &c) ==
             OGB3_INVALID_ARGUMENT &&
         !c);
  OK(ogb3_recovery_catalog_create(&cfg, assets, 5, &c));
  ogb3_recovery_catalog *clone;
  OK(ogb3_recovery_catalog_clone(c, &clone));
  ogb3_recovery_identity a, b;
  OK(ogb3_recovery_identity_get(c, &a));
  OK(ogb3_recovery_identity_get(clone, &b));
  assert(!memcmp(&a, &b, sizeof(a)));
  ogb3_recovery_catalog_release(c);
  c = clone;
  unsupported_assets(c);
  defaults_and_assets(c);
  pending_retired(c);
  ogb3_recovery_catalog_release(c);
  ogb3_allocation_stats engine, wrapper;
  OK(ogb3_engine_allocation_stats(&engine));
  OK(ogb3_snapshot_allocation_stats(&wrapper));
  assert(!engine.live_bytes && !wrapper.live_bytes);
  puts("all recovery owners released PASS");
}
