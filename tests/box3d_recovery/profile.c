/* Observational native-only phase probe. No admission depends on these clocks.
 */
#include "api.h"
#include "owned_snapshot.h"
#include "recovery_codec.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define OK(x) assert((x) == OGB3_OK)
static double now(void) {
  struct timespec t;
  assert(!clock_gettime(CLOCK_MONOTONIC, &t));
  return t.tv_sec * 1e3 + t.tv_nsec / 1e6;
}
static const ogb3_recovery_asset assets[] = {
    {.id = 1, .kind = 1, .a = {6, .25f, 6}},
    {.id = 2, .kind = 1, .a = {.25f, .25f, .25f}},
    {.id = 3, .kind = 2, .radius = 4},
    {.id = 4, .kind = 2, .radius = .15f},
    {.id = 5, .kind = 3, .a = {0, -.25f, 0}, .b = {0, .25f, 0}, .radius = .2f},
    {.id = 6, .kind = 1, .a = {.5f, .5f, .5f}}};
int main(void) {
  ogb3_recovery_config cfg;
  OK(ogb3_recovery_config_default(&cfg));
  ogb3_recovery_catalog *c;
  OK(ogb3_recovery_catalog_create(&cfg, assets, 6, &c));
  ogb3_world_def wd;
  ogb3_world w;
  OK(ogb3_world_def_default(&wd));
  OK(ogb3_world_create(&wd, &w));
  ogb3_body_def bd;
  ogb3_shape_def sd;
  ogb3_body floor, bodies[32], sensor;
  ogb3_shape sh;
  OK(ogb3_body_def_default(&bd));
  OK(ogb3_shape_def_default(&sd));
  sd.enable_sensor_events = 1;
  sd.enable_contact_events = 1;
  bd.pose.position.y = -.25f;
  OK(ogb3_body_create(w, &bd, &floor));
  OK(ogb3_shape_box(floor, &sd, &assets[0].a, &sh));
  bd.pose.position.y = 1;
  OK(ogb3_body_create(w, &bd, &sensor));
  sd.is_sensor = 1;
  OK(ogb3_shape_sphere(sensor, &sd, &assets[2].a, 4, &sh));
  sd.is_sensor = 0;
  for (int i = 0; i < 32; i++) {
    bd.type = OGB3_DYNAMIC;
    bd.pose.position = (ogb3_vec3){(i % 5 - 2) * .6f, .45f + (i / 25) * .55f,
                                   (i / 5 % 5 - 2) * .6f};
    OK(ogb3_body_create(w, &bd, bodies + i));
    OK(ogb3_shape_box(bodies[i], &sd, &assets[1].a, &sh));
  }
  ogb3_hinge_def hd;
  ogb3_joint j;
  OK(ogb3_hinge_def_default(&hd));
  hd.body_a = floor;
  hd.body_b = bodies[0];
  hd.local_frame_a.position = (ogb3_vec3){-1.2f, .7f, -1.2f};
  hd.enable_motor = hd.enable_limit = 1;
  hd.motor_speed = .75f;
  hd.max_motor_torque = 2;
  hd.lower_angle = -.5f;
  hd.upper_angle = .5f;
  OK(ogb3_joint_hinge_create(w, &hd, &j));
  for (int tick = 1; tick <= 160; tick++) {
    if (tick % 30 == 0)
      OK(ogb3_body_apply_impulse(bodies[tick % 32], &(ogb3_vec3){.01f, .2f, 0},
                                 NULL, 1));
    if (tick == 60)
      OK(ogb3_body_set_awake(bodies[7], 0));
    if (tick == 61)
      OK(ogb3_body_set_awake(bodies[7], 1));
    OK(ogb3_world_step_fixed(w));
    if (tick == 80)
      OK(ogb3_body_destroy(sensor));
  }
  ogb3_snapshot *s;
  OK(ogb3_snapshot_capture(w, &s));
  uint64_t size;
  OK(ogb3_recovery_write(c, s, NULL, 0, &size, NULL));
  uint8_t *wire = malloc(size);
  assert(wire);
  OK(ogb3_recovery_write(c, s, wire, size, &size, NULL));
  const char *names[] = {"native_read_owned", "snapshot_write_query",
                         "live_world_admit", "native_read_info_owned"};
  for (int mode = 0; mode < 4; mode++) {
    double sum = 0, max = 0, min = 1e9;
    for (int i = 0; i < 120; i++) {
      double start = now();
      uint64_t required = 0;
      ogb3_snapshot *decoded = NULL;
      if (mode == 0)
        OK(ogb3_recovery_read(c, wire, size, 0, &decoded, NULL));
      else if (mode == 1)
        OK(ogb3_recovery_write(c, s, NULL, 0, &required, NULL));
      else if(mode==2)
        OK(ogb3_recovery_world_admit(c, w, 0, &required, NULL));
      else { uint64_t v[6];uint32_t count;OK(ogb3_recovery_read_info(c,wire,size,0,&decoded,v,v+1,v+2,&count,v+3,v+4,v+5,NULL)); }
      double elapsed = now() - start;
      if (decoded)
        ogb3_snapshot_release(decoded);
      if (mode==1||mode==2)
        assert(required == size);
      sum += elapsed;
      if (elapsed > max)
        max = elapsed;
      if (elapsed < min)
        min = elapsed;
    }
    printf("{\"phase\":\"%s\",\"iterations\":120,\"bytes\":%llu,\"mean_ms\":%."
           "6f,\"max_ms\":%.6f,\"min_ms\":%.6f}\n",
           names[mode], (unsigned long long)size, sum / 120, max, min);
  }
  double sum[6] = {0}, maximum[6] = {0};
  for (int i = 0; i < 120; i++) {
    ogb3_snapshot *fresh, *clone, *atomic;
    uint64_t v[6];
    uint32_t count;
    double start = now();
    OK(ogb3_snapshot_capture(w, &fresh));
    double mark = now();
    sum[0] += mark - start;
    if (mark - start > maximum[0])
      maximum[0] = mark - start;
    start = now();
    OK(ogb3_snapshot_info(fresh, v, v + 1, v + 2, &count, v + 3, v + 4, v + 5));
    mark = now();
    sum[1] += mark - start;
    if (mark - start > maximum[1])
      maximum[1] = mark - start;
    start = now();
    OK(ogb3_snapshot_clone(fresh, &clone));
    mark = now();
    sum[2] += mark - start;
    if (mark - start > maximum[2])
      maximum[2] = mark - start;
    start = now();
    OK(ogb3_snapshot_info(clone, v, v + 1, v + 2, &count, v + 3, v + 4, v + 5));
    mark = now();
    sum[3] += mark - start;
    if (mark - start > maximum[3])
      maximum[3] = mark - start;
    ogb3_snapshot_release(clone);
    ogb3_snapshot_release(fresh);
    start = now();
    OK(ogb3_snapshot_capture_info(w, &atomic, v, v + 1, v + 2, &count, v + 3,
                                  v + 4, v + 5));
    mark = now();
    sum[4] += mark - start;
    if (mark - start > maximum[4])
      maximum[4] = mark - start;
    ogb3_snapshot_release(atomic);
    start = now();
    OK(ogb3_snapshot_clone_info(s, &atomic, v, v + 1, v + 2, &count, v + 3,
                                v + 4, v + 5));
    mark = now();
    sum[5] += mark - start;
    if (mark - start > maximum[5])
      maximum[5] = mark - start;
    ogb3_snapshot_release(atomic);
  }
  const char *constructor_names[] = {
      "fresh_snapshot_capture", "immediate_snapshot_info", "snapshot_clone",
      "clone_snapshot_info",    "atomic_capture_info",     "atomic_clone_info"};
  for (int i = 0; i < 6; i++)
    printf("{\"phase\":\"%s\",\"iterations\":120,\"mean_ms\":%.6f,\"max_ms\":%."
           "6f}\n",
           constructor_names[i], sum[i] / 120, maximum[i]);
  free(wire);
  ogb3_snapshot_release(s);
  ogb3_recovery_catalog_release(c);
  OK(ogb3_world_destroy(w));
  ogb3_allocation_stats e, o;
  OK(ogb3_engine_allocation_stats(&e));
  OK(ogb3_snapshot_allocation_stats(&o));
  assert(!e.live_bytes && !o.live_bytes);
}
