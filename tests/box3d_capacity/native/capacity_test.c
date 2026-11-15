#include "api.h"
#include "authoring_catalog.h"
#include "owned_snapshot.h"
#include "recovery_codec.h"
#include "state_dump.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OK(call) do { ogb3_status s_ = (call); if (s_) { \
  fprintf(stderr, "capacity test line %d: status %d\n", __LINE__, s_); abort(); } } while (0)

static void equal_worlds(ogb3_world left, ogb3_world right) {
  uint64_t a = 0, b = 0;
  OK(ogb3_state_dump(left, NULL, 0, &a));
  OK(ogb3_state_dump(right, NULL, 0, &b));
  assert(a == b);
  uint8_t *x = malloc((size_t)a), *y = malloc((size_t)b);
  assert(x && y);
  OK(ogb3_state_dump(left, x, a, &a));
  OK(ogb3_state_dump(right, y, b, &b));
  assert(memcmp(x, y, (size_t)a) == 0);
  free(x); free(y);
}

int main(void) {
  ogb3_recovery_config config;
  OK(ogb3_recovery_config_default(&config));
  const uint32_t bodies = config.max_bodies < 1000 ? config.max_bodies : 1000;
  uint32_t joints = config.max_joints < 100 ? config.max_joints : 100;
  if (joints >= bodies) joints = bodies - 1;
  assert(bodies > joints && bodies > 1);
  ogb3_recovery_asset assets[] = {
    {.id = 1, .kind = OGB3_RECOVERY_BOX, .a = {.1f,.1f,.1f}},
    {.id = 2, .kind = OGB3_RECOVERY_BOX, .a = {8.5f,.25f,8.5f}},
  };
  ogb3_recovery_catalog *catalog = NULL;
  OK(ogb3_recovery_catalog_create(&config, assets, 2, &catalog));
  ogb3_world_def wd;
  OK(ogb3_world_def_default(&wd));
  wd.gravity = (ogb3_vec3){0};
  ogb3_world world = 0, restored = 0;
  OK(ogb3_world_create(&wd, &world));
  ogb3_body anchor = 0;
  for (uint32_t i = 0; i < bodies; ++i) {
    ogb3_body_def bd;
    ogb3_shape_def sd;
    ogb3_body body;
    ogb3_shape shape;
    OK(ogb3_body_def_default(&bd));
    OK(ogb3_shape_def_default(&sd));
    bd.type = i ? OGB3_DYNAMIC : OGB3_STATIC;
    bd.pose.position = i ? (ogb3_vec3){((float)((i - 1) % 32) - 15.5f) * .5f, .1f, ((float)((i - 1) / 32) - 15.5f) * .5f}
                        : (ogb3_vec3){0, -.25f, 0};
    OK(ogb3_body_create(world, &bd, &body));
    OK(ogb3_recovery_catalog_shape(catalog, i ? 1 : 2, body, &sd, &shape));
    if (i == 0) anchor = body;
    if (i > 0 && i <= joints) {
      ogb3_hinge_def hd;
      ogb3_joint joint;
      OK(ogb3_hinge_def_default(&hd));
      hd.body_a = anchor; hd.body_b = body;
      hd.local_frame_a.position = bd.pose.position;
      hd.local_frame_a.position.y += .25f;
      OK(ogb3_joint_hinge_create(world, &hd, &joint));
    }
  }
  for (unsigned tick = 0; tick < 12; ++tick) OK(ogb3_world_step_fixed(world));
  ogb3_world_counters counts;
  OK(ogb3_world_get_counters(world, &counts));
  assert(counts.body_count == bodies && counts.shape_count == bodies && counts.joint_count == joints);
  if (bodies >= 1000) assert(counts.contact_count > 147);
  uint64_t required = 0;
  OK(ogb3_recovery_world_admit(catalog, world, 0, &required, NULL));
  ogb3_snapshot *image = NULL, *decoded = NULL;
  OK(ogb3_snapshot_capture(world, &image));
  OK(ogb3_recovery_write(catalog, image, NULL, 0, &required, NULL));
  uint8_t *wire = malloc((size_t)required);
  assert(wire);
  OK(ogb3_recovery_write(catalog, image, wire, required, &required, NULL));
  OK(ogb3_recovery_read(catalog, wire, required, 0, &decoded, NULL));
  OK(ogb3_world_create(&wd, &restored));
  OK(ogb3_snapshot_restore(restored, decoded));
  equal_worlds(world, restored);
  for (unsigned tick = 0; tick < 8; ++tick) {
    OK(ogb3_world_step_fixed(world));
    OK(ogb3_world_step_fixed(restored));
    equal_worlds(world, restored);
  }
  // A lower per-world recovery quota still rejects oversized candidates.
  ogb3_recovery_config lower = config;
  lower.max_bodies = bodies - 1;
  ogb3_recovery_catalog *limited = NULL;
  OK(ogb3_recovery_catalog_create(&lower, assets, 2, &limited));
  assert(ogb3_recovery_world_admit(limited, world, 0, &required, NULL) == OGB3_CAPACITY);
  ogb3_recovery_catalog_release(limited);
  free(wire);
  ogb3_snapshot_release(decoded);
  ogb3_snapshot_release(image);
  OK(ogb3_world_destroy(restored));
  OK(ogb3_world_destroy(world));
  ogb3_recovery_catalog_release(catalog);
  ogb3_allocation_stats engine, wrapper;
  OK(ogb3_engine_allocation_stats(&engine));
  OK(ogb3_snapshot_allocation_stats(&wrapper));
  assert(engine.live_bytes == 0 && wrapper.live_bytes == 0);
  printf("CAPACITY_NATIVE_OK bodies=%u joints=%u contacts=%u canonical_roundtrip=exact continued_steps=8 cleanup=zero\n", bodies, joints, counts.contact_count);
  return 0;
}
