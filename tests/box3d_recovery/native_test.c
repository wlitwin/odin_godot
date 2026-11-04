#include "api.h"
#include "box3d/box3d.h"
#include "owned_snapshot.h"
#include "recovery_codec.h"
#include "state_dump.h"
#include "state_dump_internal.h"
extern void ogb3_snapshot_internal_free(void *);
extern void ogb3_state_dump_test_reset_walks(void);
extern uint64_t ogb3_state_dump_test_walks(void);
extern void ogb3_state_dump_test_after_alloc(void (*)(uint32_t));
extern void ogb3_snapshot_test_fail_allocation_after(int64_t);
extern void ogb3_snapshot_test_fresh_fault(uint32_t);
extern void ogb3_snapshot_test_reset_seal_walks(void);
extern uint64_t ogb3_snapshot_test_seal_walks(void);
extern uint64_t ogb3_snapshot_test_stored_seal(const ogb3_snapshot *);
extern uint64_t ogb3_snapshot_test_compute_seal(const ogb3_snapshot *);
extern uint64_t ogb3_snapshot_test_pending_counts(const ogb3_snapshot *);
extern void ogb3_recovery_test_fail_build_after(int64_t);
extern void ogb3_recovery_test_rehash(uint8_t *, uint64_t);
extern ogb3_status ogb3_recovery_test_mutate(const ogb3_recovery_catalog *,
                                             const uint8_t *, uint64_t,
                                             uint32_t, uint8_t *, uint64_t,
                                             uint64_t *);
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#define OK(x)                                                                  \
  do {                                                                         \
    int test_status = (x);                                                     \
    if (test_status) {                                                         \
      fprintf(stderr, "status=%d line=%d\n", test_status, __LINE__);           \
      abort();                                                                 \
    }                                                                          \
  } while (0)
static void equal(ogb3_world a, ogb3_world b) {
  uint64_t n, m;
  OK(ogb3_state_dump(a, NULL, 0, &n));
  OK(ogb3_state_dump(b, NULL, 0, &m));
  assert(n == m);
  uint8_t *x = malloc(n), *y = malloc(m);
  OK(ogb3_state_dump(a, x, n, &n));
  OK(ogb3_state_dump(b, y, m, &m));
  if (memcmp(x, y, n)) {
    size_t i = 0;
    while (i < n && x[i] == y[i])
      i++;
    fprintf(stderr, "dump mismatch at%zu\n", i);
    abort();
  }
  free(x);
  free(y);
}
/* Focused branch1: unchanged public query/fill is three complete traversals;
 * a fresh owned constructor must count once/fill once with identical bytes. */
static void check_fresh_failure_outputs(ogb3_world, const char *);
static void check_count_once_parity(ogb3_world world, const char *label) {
  assert(ogb3_build_fingerprint()); /* prewarm before counting */
  uint64_t n = 0, required = 0;
  ogb3_state_dump_test_reset_walks();
  OK(ogb3_state_dump(world, NULL, 0, &n));
  uint8_t *public_bytes = malloc((size_t)n), *out = malloc((size_t)n);
  assert(public_bytes && out && n > 0);
  OK(ogb3_state_dump(world, public_bytes, n, &required));
  assert(required == n && ogb3_state_dump_test_walks() == 3);
  memset(out, 0xa5, (size_t)n);
  assert(ogb3_state_dump(world, out, n - 1, &required) == OGB3_CAPACITY &&
         required == n);
  for (uint64_t i = 0; i < n; i++) assert(out[i] == 0xa5);

  ogb3_snapshot *snapshot = NULL;
  ogb3_state_dump_test_reset_walks();
  ogb3_snapshot_test_reset_seal_walks();
  OK(ogb3_snapshot_capture(world, &snapshot));
  assert(snapshot && ogb3_state_dump_test_walks() == 2);
  printf("fresh pending %s sensors%u contacts%u\n", label,
         (uint32_t)ogb3_snapshot_test_pending_counts(snapshot),
         (uint32_t)(ogb3_snapshot_test_pending_counts(snapshot)>>32));
  if (!strcmp(label,"poststep-pending-sensor-end"))
    assert((uint32_t)ogb3_snapshot_test_pending_counts(snapshot)==1);
  if (!strcmp(label,"poststep-pending-contact-end"))
    assert((ogb3_snapshot_test_pending_counts(snapshot)>>32)==1);
  assert(ogb3_snapshot_test_seal_walks() == 1);
  uint64_t original_seal = ogb3_snapshot_test_stored_seal(snapshot);
  assert(original_seal == ogb3_snapshot_test_compute_seal(snapshot));
  assert(ogb3_snapshot_test_seal_walks() == 2);
  OK(ogb3_snapshot_dump(snapshot, out, n, &required));
  assert(ogb3_snapshot_test_seal_walks() == 3); /* Public reseal unchanged. */
  assert(required == n && !memcmp(out, public_bytes, (size_t)n));
  uint64_t complete, motion;
  OK(ogb3_snapshot_digest(snapshot, &complete, &motion));
  assert(ogb3_snapshot_test_seal_walks() == 4);
  uint64_t world_complete, world_motion;
  OK(ogb3_state_digest(world, &world_complete, &world_motion));
  assert(complete == world_complete && motion == world_motion);
  uint64_t info[6], getter[6]; uint32_t info_count, getter_count;
  ogb3_snapshot *atomic = NULL;
  ogb3_snapshot_test_reset_seal_walks();
  OK(ogb3_snapshot_capture_info(world, &atomic, info, info + 1, info + 2,
                                &info_count, info + 3, info + 4, info + 5));
  assert(atomic && ogb3_snapshot_test_seal_walks() == 1 &&
         ogb3_snapshot_test_stored_seal(atomic) == original_seal);
  OK(ogb3_snapshot_info(atomic, getter, getter + 1, getter + 2, &getter_count,
                        getter + 3, getter + 4, getter + 5));
  assert(ogb3_snapshot_test_seal_walks() == 2 && info_count == getter_count &&
         !memcmp(info, getter, sizeof(info)));
  ogb3_snapshot *clone = NULL;
  OK(ogb3_snapshot_clone(atomic, &clone));
  assert(ogb3_snapshot_test_seal_walks() == 3 && clone);
  ogb3_snapshot_release(clone);ogb3_snapshot_release(atomic);
  ogb3_snapshot_release(snapshot);

  ogb3_allocation_stats before, after;
  OK(ogb3_snapshot_allocation_stats(&before));
  uint8_t *owned = NULL;
  uint64_t size = 0;
  ogb3_state_dump_test_reset_walks();
  OK(ogb3_state_dump_alloc_internal(world, &owned, &size));
  assert(owned && size == n && ogb3_state_dump_test_walks() == 2 &&
         !memcmp(owned, public_bytes, (size_t)n));
  OK(ogb3_snapshot_allocation_stats(&after));
  assert(after.total_calls == before.total_calls + 1 &&
         after.total_bytes == before.total_bytes + n &&
         after.live_bytes == before.live_bytes + n);
  ogb3_snapshot_internal_free(owned);
  OK(ogb3_snapshot_allocation_stats(&after));
  assert(after.live_bytes == before.live_bytes);
  free(public_bytes); free(out);
  printf("count-once %s publicwalks3 constructorwalks2 exactbytes%llu PASS\n",
         label, (unsigned long long)n);
  printf("fresh-seal %s constructor1/public-reseal1/original-seal-Info-digests "
         "exact PASS\n", label);
  check_fresh_failure_outputs(world, label);
}

static void check_fresh_failure_outputs(ogb3_world world, const char *label) {
  uint64_t before_complete, before_motion;
  OK(ogb3_state_digest(world, &before_complete, &before_motion));
  for (int info_mode = 0; info_mode < 2; info_mode++) {
    for (uint32_t mode = 1; mode <= 10; mode++) {
      ogb3_allocation_stats native_before, wrapper_before, native_after, wrapper_after;
      OK(ogb3_engine_allocation_stats(&native_before));
      OK(ogb3_snapshot_allocation_stats(&wrapper_before));
      uint64_t info[6];for(int i=0;i<6;i++) info[i]=UINT64_MAX;
      uint32_t count=UINT32_MAX;
      ogb3_snapshot *owner=(ogb3_snapshot *)(uintptr_t)1;
      ogb3_snapshot_test_reset_seal_walks();
      ogb3_snapshot_test_fresh_fault(mode);
      int status=info_mode ? ogb3_snapshot_capture_info(world,&owner,info,info+1,
          info+2,&count,info+3,info+4,info+5) : ogb3_snapshot_capture(world,&owner);
      assert(status==(mode<=3?OGB3_INCOMPATIBLE:OGB3_CORRUPT) && !owner);
      assert(ogb3_snapshot_test_seal_walks()==0); /* Reject BEFORE sealing. */
      for(int i=0;i<6;i++) assert(info[i]==UINT64_MAX);
      assert(count==UINT32_MAX);
      OK(ogb3_engine_allocation_stats(&native_after));
      OK(ogb3_snapshot_allocation_stats(&wrapper_after));
      assert(native_before.live_bytes==native_after.live_bytes &&
             wrapper_before.live_bytes==wrapper_after.live_bytes);
      /* One-shot control is already cleared; no new callback/trust surface. */
      OK(ogb3_snapshot_capture(world,&owner));ogb3_snapshot_release(owner);
    }
  }
  int saw_oom=0,saw_success=0;
  ogb3_snapshot_test_fresh_fault(0);
  for(int64_t fail=0;fail<32;fail++) {
    ogb3_allocation_stats n0,w0,n1,w1;
    OK(ogb3_engine_allocation_stats(&n0));OK(ogb3_snapshot_allocation_stats(&w0));
    uint64_t info[6];for(int i=0;i<6;i++) info[i]=UINT64_MAX;
    uint32_t count=UINT32_MAX;ogb3_snapshot *owner=NULL;
    ogb3_snapshot_test_fail_allocation_after(fail);
    int status=ogb3_snapshot_capture_info(world,&owner,info,info+1,info+2,&count,
                                         info+3,info+4,info+5);
    ogb3_snapshot_test_fail_allocation_after(-1);
    if(status==OGB3_OK) {assert(owner);ogb3_snapshot_release(owner);saw_success=1;}
    else {assert(status==OGB3_OUT_OF_MEMORY && !owner);saw_oom++;
      for(int i=0;i<6;i++) assert(info[i]==UINT64_MAX);assert(count==UINT32_MAX);}
    OK(ogb3_engine_allocation_stats(&n1));OK(ogb3_snapshot_allocation_stats(&w1));
    assert(n0.live_bytes==n1.live_bytes && w0.live_bytes==w1.live_bytes);
    if(saw_success) break;
  }
  assert(saw_oom && saw_success);
  uint64_t after_complete,after_motion;
  OK(ogb3_state_digest(world,&after_complete,&after_motion));
  assert(before_complete==after_complete && before_motion==after_motion);
  printf("fresh-finish %s 20metadata/preflight/pending faults +%d wrapperOOM "
         "Info/out/world/ownership preservation PASS\n",label,saw_oom);
}

typedef struct LockedDumpTest { ogb3_world world; int calls; } LockedDumpTest;
static bool check_locked_dump(b3ShapeId a, b3ShapeId b, void *context) {
  (void)a; (void)b;
  LockedDumpTest *test = context;
  ogb3_snapshot *snapshot = (ogb3_snapshot *)(uintptr_t)1;
  uint8_t *out = NULL;
  uint64_t size = 0;
  assert(ogb3_snapshot_capture(test->world, &snapshot) == OGB3_UNSUPPORTED &&
         !snapshot);
  assert(ogb3_state_dump_alloc_internal(test->world, &out, &size) ==
             OGB3_INVALID_ARGUMENT && !out && !size);
  test->calls++;
  return true;
}

static void check_count_once_fixtures(void) {
  ogb3_world_def wd;
  ogb3_world world;
  OK(ogb3_world_def_default(&wd));
  wd.gravity = (ogb3_vec3){0};
  OK(ogb3_world_create(&wd, &world));
  check_count_once_parity(world, "empty");
  ogb3_body_def bd;
  ogb3_shape_def sd;
  ogb3_body body;
  ogb3_shape shape;
  OK(ogb3_body_def_default(&bd)); OK(ogb3_shape_def_default(&sd));
  bd.pose.position.x = 50;
  OK(ogb3_body_create(world, &bd, &body));
  OK(ogb3_shape_capsule(body, &sd, &(ogb3_vec3){0, -.25f, 0},
                         &(ogb3_vec3){0, .25f, 0}, .2f, &shape));
  ogb3_vec3 hull[] = {{0, 0, 0}, {1, 0, 0}, {0, 1, 0}, {0, 0, 1}};
  ogb3_geometry *geometry = NULL;
  OK(ogb3_geometry_hull(hull, 4, &geometry));
  OK(ogb3_shape_geometry(body, &sd, geometry, &shape));
  ogb3_geometry_release(geometry);
  ogb3_vec3 mesh[] = {{0, 0, 0}, {1, 0, 0}, {0, 0, 1}};
  uint32_t indices[] = {0, 1, 2};
  OK(ogb3_geometry_mesh(mesh, 3, indices, 1, &geometry));
  OK(ogb3_shape_geometry(body, &sd, geometry, &shape));
  ogb3_geometry_release(geometry);
  check_count_once_parity(world, "capsule-hull-mesh-owned-geometry");

  bd.pose.position = (ogb3_vec3){0};
  OK(ogb3_body_create(world, &bd, &body));
  sd.is_sensor = sd.enable_sensor_events = 1;
  OK(ogb3_shape_box(body, &sd, &(ogb3_vec3){2, 2, 2}, &shape));
  bd.type = OGB3_DYNAMIC;
  ogb3_body visitor;
  OK(ogb3_body_create(world, &bd, &visitor));
  sd.is_sensor = 0;
  OK(ogb3_shape_sphere(visitor, &sd, &(ogb3_vec3){0}, .25f, &shape));
  OK(ogb3_world_step_fixed(world));
  uint32_t events;
  ogb3_sensor_event event_data[8];
  OK(ogb3_world_sensor_events(world, event_data, 8, &events));
  assert(events == 1);
  /* Destroying the sensor queues its known end immediately; destroying only
   * the visitor is detected by the next sensor step, not this pending buffer. */
  OK(ogb3_body_destroy(body));
  OK(ogb3_body_destroy(visitor));
  check_count_once_parity(world, "poststep-pending-sensor-end");
  OK(ogb3_world_destroy(world));

  OK(ogb3_world_create(&wd, &world));
  OK(ogb3_shape_def_default(&sd));sd.enable_contact_events=1;
  OK(ogb3_body_def_default(&bd));
  OK(ogb3_body_create(world,&bd,&body));
  OK(ogb3_shape_sphere(body,&sd,&(ogb3_vec3){0},1,&shape));
  bd.type=OGB3_DYNAMIC;bd.pose.position.x=1.5f;
  OK(ogb3_body_create(world,&bd,&visitor));
  OK(ogb3_shape_sphere(visitor,&sd,&(ogb3_vec3){0},1,&shape));
  OK(ogb3_world_step_fixed(world));OK(ogb3_body_destroy(visitor));
  check_count_once_parity(world,"poststep-pending-contact-end");
  OK(ogb3_world_destroy(world));

  /* Public engine custom filtering runs synchronously with the world locked.
   * It only tests rejection; no snapshot/solver state is mutated by it. */
  OK(ogb3_world_create(&wd, &world));
  b3WorldId native_world;
  _Static_assert(sizeof(native_world) == sizeof(world), "world packing");
  memcpy(&native_world, &world, sizeof(world));
  LockedDumpTest test = {world, 0};
  b3World_SetCustomFilterCallback(native_world, check_locked_dump, &test);
  b3ShapeDef native_shape = b3DefaultShapeDef();
  native_shape.enableCustomFiltering = true;
  b3Sphere sphere = {{0, 0, 0}, .5f};
  for (int i = 0; i < 2; i++) {
    OK(ogb3_body_def_default(&bd));
    bd.type = i ? OGB3_DYNAMIC : OGB3_STATIC;
    OK(ogb3_body_create(world, &bd, &body));
    b3BodyId native_body;
    _Static_assert(sizeof(native_body) == sizeof(body), "body packing");
    memcpy(&native_body, &body, sizeof(body));
    b3CreateSphereShape(native_body, &native_shape, &sphere);
  }
  OK(ogb3_world_step_fixed(world));
  assert(test.calls > 0);
  b3World_SetCustomFilterCallback(native_world, NULL, NULL);
  OK(ogb3_world_destroy(world));
  puts("count-once locked helper and unsupported constructor noowner PASS");
}

/* Focused branch2: controlled test interference after the actual allocation.
 * This is not a concurrent-mutation or application reentry contract. */
static ogb3_body after_alloc_body;
static int after_alloc_mode, after_alloc_calls;
static void change_after_alloc(uint32_t world) {
  after_alloc_calls++;
  /* The one-shot hook must already be cleared before this nested helper. */
  if (after_alloc_mode == 1) {
    OK(ogb3_world_destroy(world));
  } else if (after_alloc_mode == 2) {
    ogb3_body_def def;
    OK(ogb3_body_def_default(&def));
    OK(ogb3_body_create(world, &def, &after_alloc_body));
  } else {
    OK(ogb3_body_destroy(after_alloc_body));
  }
  if (after_alloc_mode != 1) {
    uint8_t *nested = NULL;
    uint64_t size = 0;
    OK(ogb3_state_dump_alloc_internal(world, &nested, &size));
    assert(nested && size);
    ogb3_snapshot_internal_free(nested);
  }
}
static void check_count_once_failures(void) {
  ogb3_allocation_stats engine_start, wrapper_start;
  OK(ogb3_engine_allocation_stats(&engine_start));
  OK(ogb3_snapshot_allocation_stats(&wrapper_start));
  uint8_t *out = (uint8_t *)(uintptr_t)1;
  uint64_t size = UINT64_MAX;
  assert(ogb3_state_dump_alloc_internal(0, NULL, &size) ==
         OGB3_INVALID_ARGUMENT && size == UINT64_MAX);
  assert(ogb3_state_dump_alloc_internal(0, &out, NULL) ==
         OGB3_INVALID_ARGUMENT && out == (uint8_t *)(uintptr_t)1);
  assert(ogb3_state_dump_alloc_internal(0, &out, &size) == OGB3_INVALID_HANDLE &&
         out == (uint8_t *)(uintptr_t)1 && size == UINT64_MAX);
  for (int constructor = 0; constructor < 2; constructor++) {
   for (int mode = 0; mode <= 3; mode++) {
    ogb3_world_def def; ogb3_world world;
    OK(ogb3_world_def_default(&def)); OK(ogb3_world_create(&def, &world));
    if (mode == 3) {
      ogb3_body_def bd; OK(ogb3_body_def_default(&bd));
      OK(ogb3_body_create(world, &bd, &after_alloc_body));
    }
    ogb3_allocation_stats before, after;
    OK(ogb3_snapshot_allocation_stats(&before));
    out = NULL; size = 0; after_alloc_mode = mode; after_alloc_calls = 0;
    if (mode == 0) ogb3_snapshot_test_fail_allocation_after(0);
    else ogb3_state_dump_test_after_alloc(change_after_alloc);
    ogb3_snapshot *snapshot = (ogb3_snapshot *)(uintptr_t)1;
    int status = constructor ? ogb3_snapshot_capture(world, &snapshot) :
                               ogb3_state_dump_alloc_internal(world, &out, &size);
    ogb3_snapshot_test_fail_allocation_after(-1);
    ogb3_state_dump_test_after_alloc(NULL);
    assert(status == (mode == 0 ? OGB3_OUT_OF_MEMORY :
                      mode == 1 ? OGB3_INVALID_HANDLE : OGB3_CORRUPT));
    assert(!out && !size && after_alloc_calls == (mode != 0));
    if (constructor) assert(!snapshot);
    OK(ogb3_snapshot_allocation_stats(&after));
    assert(after.live_bytes == before.live_bytes);
    if (mode != 1) {
      /* A subsequent success also proves no test callback remained armed. */
      OK(ogb3_state_dump_alloc_internal(world, &out, &size));
      assert(out && size); ogb3_snapshot_internal_free(out);
      OK(ogb3_world_destroy(world));
    }
   }
  }
  ogb3_allocation_stats engine, wrapper;
  OK(ogb3_engine_allocation_stats(&engine));
  OK(ogb3_snapshot_allocation_stats(&wrapper));
  assert(engine.live_bytes == engine_start.live_bytes &&
         wrapper.live_bytes == wrapper_start.live_bytes);
  puts("count-once null/invalid/OOM/postalloc-invalidation/grow/shrink "
       "atomic-outputs+cleanup PASS");
}
extern const uint8_t *ogb3_snapshot_test_image(const ogb3_snapshot *,
                                               uint64_t *);
static void check_info(const ogb3_snapshot *s) {
  uint64_t used, capacity, geometry, normalized, wrapper, native;
  uint32_t count;
  OK(ogb3_snapshot_metrics(s, &used, &capacity, &geometry, &count));
  OK(ogb3_snapshot_storage(s, &normalized, &wrapper, &native));
  uint64_t values[6] = {0};
  uint32_t geometry_count = 0;
  ogb3_snapshot_test_fail_allocation_after(0);
  int status =
      ogb3_snapshot_info(s, values, values + 1, values + 2, &geometry_count,
                         values + 3, values + 4, values + 5);
  ogb3_snapshot_test_fail_allocation_after(-1);
  assert(status == 0);
  assert(values[0] == used && values[1] == capacity && values[2] == geometry &&
         geometry_count == count && values[3] == normalized &&
         values[4] == wrapper && values[5] == native);
  for (int missing = 0; missing < 7; missing++) {
    for (int j = 0; j < 6; j++)
      values[j] = UINT64_MAX;
    geometry_count = UINT32_MAX;
    assert(
        ogb3_snapshot_info(
            s, missing == 0 ? NULL : values, missing == 1 ? NULL : values + 1,
            missing == 2 ? NULL : values + 2,
            missing == 3 ? NULL : &geometry_count,
            missing == 4 ? NULL : values + 3, missing == 5 ? NULL : values + 4,
            missing == 6 ? NULL : values + 5) == OGB3_INVALID_ARGUMENT);
    for (int j = 0; j < 6; j++)
      assert(values[j] == UINT64_MAX);
    assert(geometry_count == UINT32_MAX);
  }
  uint64_t bytes;
  uint8_t *image = (uint8_t *)ogb3_snapshot_test_image(s, &bytes);
  assert(bytes > 0);
  image[0] ^= 1;
  assert(ogb3_snapshot_info(s, values, values + 1, values + 2, &geometry_count,
                            values + 3, values + 4,
                            values + 5) == OGB3_CORRUPT);
  image[0] ^= 1;
  for (int j = 0; j < 6; j++)
    assert(values[j] == UINT64_MAX);
  assert(geometry_count == UINT32_MAX);
  ogb3_snapshot *clone;
  OK(ogb3_snapshot_clone(s, &clone));
  OK(ogb3_snapshot_info(clone, values, values + 1, values + 2, &geometry_count,
                        values + 3, values + 4, values + 5));
  assert(values[0] == used && values[3] == normalized && values[4] == wrapper &&
         values[5] == native);
  ogb3_snapshot_release(clone);
}
static void check_atomic_info(ogb3_world world, const ogb3_snapshot *source) {
  uint64_t values[6];
  uint32_t count;
  ogb3_snapshot *owner = NULL;
  ogb3_allocation_stats e0, w0;
  OK(ogb3_engine_allocation_stats(&e0));
  OK(ogb3_snapshot_allocation_stats(&w0));
  for (int clone = 0; clone < 2; clone++)
    for (int missing = 0; missing < 7; missing++) {
      for (int j = 0; j < 6; j++)
        values[j] = UINT64_MAX;
      count = UINT32_MAX;
      owner = (ogb3_snapshot *)(uintptr_t)1;
      int result =
          clone ? ogb3_snapshot_clone_info(source, &owner,
                                           missing == 0 ? NULL : values,
                                           missing == 1 ? NULL : values + 1,
                                           missing == 2 ? NULL : values + 2,
                                           missing == 3 ? NULL : &count,
                                           missing == 4 ? NULL : values + 3,
                                           missing == 5 ? NULL : values + 4,
                                           missing == 6 ? NULL : values + 5)
                : ogb3_snapshot_capture_info(world, &owner,
                                             missing == 0 ? NULL : values,
                                             missing == 1 ? NULL : values + 1,
                                             missing == 2 ? NULL : values + 2,
                                             missing == 3 ? NULL : &count,
                                             missing == 4 ? NULL : values + 3,
                                             missing == 5 ? NULL : values + 4,
                                             missing == 6 ? NULL : values + 5);
      assert(result == OGB3_INVALID_ARGUMENT && !owner);
      for (int j = 0; j < 6; j++)
        assert(values[j] == UINT64_MAX);
      assert(count == UINT32_MAX);
    }
  assert(ogb3_snapshot_capture_info(0, &owner, values, values + 1, values + 2,
                                    &count, values + 3, values + 4,
                                    values + 5) == OGB3_INVALID_HANDLE &&
         !owner);
  uint64_t image_size;
  uint8_t *image = (uint8_t *)ogb3_snapshot_test_image(source, &image_size);
  image[0] ^= 1;
  assert(ogb3_snapshot_clone_info(source, &owner, values, values + 1,
                                  values + 2, &count, values + 3, values + 4,
                                  values + 5) == OGB3_CORRUPT &&
         !owner);
  image[0] ^= 1;
  for (int j = 0; j < 6; j++)
    assert(values[j] == UINT64_MAX);
  assert(count == UINT32_MAX);
  ogb3_snapshot_test_fail_allocation_after(0);
  int result =
      ogb3_snapshot_clone_info(source, &owner, values, values + 1, values + 2,
                               &count, values + 3, values + 4, values + 5);
  ogb3_snapshot_test_fail_allocation_after(-1);
  assert(result == OGB3_OUT_OF_MEMORY && !owner);
  int success = 0;
  for (int64_t fail = 0; fail < 80; fail++) {
    for (int j = 0; j < 6; j++)
      values[j] = UINT64_MAX;
    count = UINT32_MAX;
    ogb3_snapshot_test_fail_allocation_after(fail);
    result = ogb3_snapshot_capture_info(world, &owner, values, values + 1,
                                        values + 2, &count, values + 3,
                                        values + 4, values + 5);
    ogb3_snapshot_test_fail_allocation_after(-1);
    if (!result) {
      success = 1;
      uint64_t x[6];
      uint32_t n;
      OK(ogb3_snapshot_info(owner, x, x + 1, x + 2, &n, x + 3, x + 4, x + 5));
      assert(!memcmp(x, values, sizeof(x)) && n == count);
      ogb3_snapshot_release(owner);
      printf("atomic capture_info wrapper failpoints=%lld PASS\n",
             (long long)fail);
      break;
    }
    assert(result == OGB3_OUT_OF_MEMORY && !owner);
    for (int j = 0; j < 6; j++)
      assert(values[j] == UINT64_MAX);
    assert(count == UINT32_MAX);
    ogb3_allocation_stats e, w;
    OK(ogb3_engine_allocation_stats(&e));
    OK(ogb3_snapshot_allocation_stats(&w));
    assert(e.live_bytes == e0.live_bytes && w.live_bytes == w0.live_bytes);
  }
  assert(success);
  OK(ogb3_snapshot_clone_info(source, &owner, values, values + 1, values + 2,
                              &count, values + 3, values + 4, values + 5));
  uint64_t x[6];
  uint32_t n;
  OK(ogb3_snapshot_info(owner, x, x + 1, x + 2, &n, x + 3, x + 4, x + 5));
  assert(!memcmp(x, values, sizeof(x)) && n == count);
  ogb3_snapshot_release(owner);
  puts("atomic checked capture/clone metadata "
       "parity/default/clone/source-death/corrupt/failure/outputs PASS");
}
extern uint64_t ogb3_snapshot_test_hash_bytes(uint64_t, const void *, size_t);
static uint64_t hash_reference(uint64_t h, const uint8_t *p, size_t n) {
  for (size_t i = 0; i < n; i++)
    h = (h ^ p[i]) * UINT64_C(1099511628211);
  return h;
}
static void check_hash_vectors(void) {
  uint8_t data[1040];
  uint64_t random = UINT64_C(0x7643cae381dfa920);
  const uint64_t seeds[] = {0, 1, UINT64_MAX, UINT64_C(14695981039346656037)};
  size_t cases = 0;
  for (int pattern = 0; pattern < 4; pattern++) {
    for (size_t i = 0; i < sizeof(data); i++) {
      random = random * UINT64_C(6364136223846793005) + 1;
      data[i] = pattern == 0   ? 0
                : pattern == 1 ? 255
                : pattern == 2 ? (i % 17 == 3 ? (uint8_t)(random >> 56) : 0)
                               : (uint8_t)(random >> 56);
    }
    for (size_t offset = 0; offset < 16; offset++)
      for (size_t n = 0; n <= 1024; n++)
        for (size_t seed = 0; seed < 4; seed++) {
          uint64_t start = seeds[seed] ^ ((uint64_t)n << 32) ^ offset;
          assert(ogb3_snapshot_test_hash_bytes(start, data + offset, n) ==
                 hash_reference(start, data + offset, n));
          cases++;
        }
  }
  assert(ogb3_snapshot_test_hash_bytes(UINT64_C(14695981039346656037), "", 0) ==
         UINT64_C(14695981039346656037));
  assert(ogb3_snapshot_test_hash_bytes(UINT64_C(14695981039346656037), "a",
                                       1) == UINT64_C(0xaf63dc4c8601ec8c));
  assert(ogb3_snapshot_test_hash_bytes(UINT64_C(14695981039346656037), "foobar",
                                       6) == UINT64_C(0x85944171f73967e8));
  printf("FNV exact byte-reference vectors=%zu lengths0..1024 offsets0..15 "
         "zero/dense/sparse/random fourseeds PASS\n",
         cases);
}
static void hash_equal(uint64_t seed, const uint8_t *data, size_t size) {
  assert(ogb3_snapshot_test_hash_bytes(seed,data,size)==
         hash_reference(seed,data,size));
}
static void check_zero_subruns(void) {
  /* Proof for EVERY seed, not a finite-seed extrapolation: a zero byte maps
   * h to h*P mod2^64. Composition gives h*P^k for k=2/4/8; unsigned arithmetic
   * wraps exactly. Nonzero groups execute the original ordered byte rounds.
   * The following finite controls independently check the implementation. */
  const uint64_t p=UINT64_C(1099511628211),p2=p*p,p4=p2*p2,p8=p4*p4;
  assert(p2==UINT64_C(0x000366000002e329) &&
         p4==UINT64_C(0x9ffaac085635bc91) &&
         p8==UINT64_C(0x1efac7090aef4a21));
  const uint64_t seeds[]={0,1,UINT64_MAX,UINT64_C(14695981039346656037),
                         UINT64_C(0x123456789abcdef0)};
  uint8_t data[112]={0};size_t cases=0;
  assert(ogb3_snapshot_test_hash_bytes(UINT64_MAX,NULL,0)==UINT64_MAX);
  for(unsigned bit=0;bit<64;bit++) {
    for(size_t n=0;n<=64;n++) {
      hash_equal(UINT64_C(1)<<bit,data,n);
      hash_equal(~(UINT64_C(1)<<bit),data,n);cases+=2;
    }
  }
  /* All65536 two-byte patterns at every0..15 input alignment. */
  for(unsigned value=0;value<=UINT16_MAX;value++) {
    for(size_t offset=0;offset<16;offset++) {
      data[offset]=(uint8_t)value;data[offset+1]=(uint8_t)(value>>8);
      for(size_t k=0;k<sizeof(seeds)/sizeof(*seeds);k++) {
        hash_equal(seeds[k],data+offset,2);cases++;
      }
    }
  }
  /* Everybyte value in everyposition of mixed8/16-byte blocks, all alignments
   * and everyprefix/tail length, including high-bit nonzero byte values. */
  for(unsigned value=0;value<=UINT8_MAX;value++) {
    for(size_t position=0;position<16;position++) {
      for(size_t offset=0;offset<16;offset++) {
        memset(data,0,sizeof(data));data[offset+position]=(uint8_t)value;
        for(size_t n=0;n<=24;n++) {
          hash_equal(seeds[(value+position+offset+n)%5],data+offset,n);cases++;
        }
      }
    }
  }
  /* Explicit zero-run starts/ends crossing2/4/8 group boundaries within
   * otherwise dense nonzero buffers; all offsets and lengths0..48. */
  for(size_t offset=0;offset<16;offset++) {
    for(size_t start=0;start<24;start++) {
      for(size_t run=1;run<=12;run++) {
        memset(data,0xa5,sizeof(data));memset(data+offset+start,0,run);
        for(size_t n=0;n<=48;n++) {
          hash_equal(seeds[(offset+start+run+n)%5],data+offset,n);cases++;
        }
      }
    }
  }
  printf("FNV zero2/4/8 algebra/allseed-bitbasis/all16bitpatterns/allbytevalues "
         "mixedcross-boundaries/align0..15/shorttails cases%zu PASS\n",cases);

  long page=sysconf(_SC_PAGESIZE);assert(page>=256);
  uint8_t *map=mmap(NULL,(size_t)page*3,PROT_NONE,MAP_PRIVATE|MAP_ANONYMOUS,-1,0);
  assert(map!=MAP_FAILED && !mprotect(map+page,(size_t)page,PROT_READ|PROT_WRITE));
  size_t guarded=0;
  for(size_t n=0;n<=128;n++) {
    uint8_t *end=map+2*page-n; /* n0 points AT inaccessible page: no read. */
    for(unsigned pattern=0;pattern<4;pattern++) {
      for(size_t i=0;i<n;i++) end[i]=pattern==0?0:pattern==1?255:
          pattern==2?(i%5==0?0x80:0):(uint8_t)(i*37+1);
      for(size_t k=0;k<5;k++) {hash_equal(seeds[k],end,n);guarded++;}
    }
  }
  /* Start immediately after the inaccessible preceding page too. */
  for(size_t n=0;n<=128;n++) {
    memset(map+page,0x5a,n);
    for(size_t k=0;k<5;k++) {hash_equal(seeds[k],map+page,n);guarded++;}
  }
  assert(!munmap(map,(size_t)page*3));
  printf("FNV guardedend/start exact-readable-length0..128 cases%zu PASS\n",guarded);
}
static void check_read_info(const ogb3_recovery_catalog *c, const uint8_t *data,
                            uint64_t size) {
  uint64_t v[6];
  uint32_t count;
  ogb3_snapshot *owner = NULL;
  ogb3_recovery_diagnostic diag;
  for (int missing = 0; missing < 7; missing++) {
    for (int j = 0; j < 6; j++)
      v[j] = UINT64_MAX;
    count = UINT32_MAX;
    owner = (ogb3_snapshot *)(uintptr_t)1;
    assert(ogb3_recovery_read_info(
               c, data, size, 0, &owner, missing == 0 ? NULL : v,
               missing == 1 ? NULL : v + 1, missing == 2 ? NULL : v + 2,
               missing == 3 ? NULL : &count, missing == 4 ? NULL : v + 3,
               missing == 5 ? NULL : v + 4, missing == 6 ? NULL : v + 5,
               &diag) == OGB3_INVALID_ARGUMENT &&
           !owner);
    for (int j = 0; j < 6; j++)
      assert(v[j] == UINT64_MAX);
    assert(count == UINT32_MAX);
  }
  assert(ogb3_recovery_read_info(c, data, size - 1, 0, &owner, v, v + 1, v + 2,
                                 &count, v + 3, v + 4, v + 5,
                                 &diag) != OGB3_OK &&
         !owner);
  for (int j = 0; j < 6; j++)
    assert(v[j] == UINT64_MAX);
  assert(count == UINT32_MAX);
  OK(ogb3_recovery_read_info(c, data, size, 0, &owner, v, v + 1, v + 2, &count,
                             v + 3, v + 4, v + 5, &diag));
  uint64_t expected[6];
  uint32_t n;
  OK(ogb3_snapshot_info(owner, expected, expected + 1, expected + 2, &n,
                        expected + 3, expected + 4, expected + 5));
  assert(!memcmp(expected, v, sizeof(v)) && count == n);
  ogb3_snapshot_release(owner);
  puts("atomic fullread_info "
       "parity/source-death/missingoutput/truncatednoowner PASS");
}
int main(int argc, char **argv) {
  setvbuf(stdout, NULL, _IONBF, 0);
  check_hash_vectors();
  check_zero_subruns();
  ogb3_recovery_config cfg;
  OK(ogb3_recovery_config_default(&cfg));
  ogb3_recovery_asset assets[] = {
      {.id = 1, .kind = OGB3_RECOVERY_BOX, .a = {5, .5f, 5}},
      {.id = 2, .kind = OGB3_RECOVERY_BOX, .a = {.5f, .5f, .5f}},
      {.id = 3, .kind = OGB3_RECOVERY_SPHERE, .radius = 4}};
  ogb3_recovery_catalog *catalog;
  OK(ogb3_recovery_catalog_create(&cfg, assets, 3, &catalog));
  if (argc == 3 && !strcmp(argv[1], "reject-identity")) {
    FILE *input = fopen(argv[2], "rb");
    assert(input);
    assert(!fseek(input, 0, SEEK_END));
    long n = ftell(input);
    assert(n > 0 && n <= OGB3_RECOVERY_MAX_BYTES);
    rewind(input);
    uint8_t *data = malloc((size_t)n);
    assert(data && fread(data, 1, (size_t)n, input) == (size_t)n);
    fclose(input);
    ogb3_snapshot *result = NULL;
    assert(ogb3_recovery_read(catalog, data, (uint64_t)n, 0, &result, NULL) ==
               OGB3_INCOMPATIBLE &&
           !result);
    free(data);
    ogb3_recovery_catalog_release(catalog);
    ogb3_allocation_stats engine, wrapper;
    OK(ogb3_engine_allocation_stats(&engine));
    OK(ogb3_snapshot_allocation_stats(&wrapper));
    assert(!engine.live_bytes && !wrapper.live_bytes);
    puts("different build/target packet rejected Incompatible before native "
         "reconstruction; owners zero PASS");
    return 0;
  }
  check_count_once_failures();
  check_count_once_fixtures();
  ogb3_world_def wd;
  ogb3_world a, b;
  OK(ogb3_world_def_default(&wd));
  OK(ogb3_world_create(&wd, &a));
  OK(ogb3_world_create(&wd, &b));
  ogb3_body_def bd;
  ogb3_shape_def sd;
  ogb3_shape shape;
  ogb3_body floor, body;
  OK(ogb3_body_def_default(&bd));
  OK(ogb3_shape_def_default(&sd));
  OK(ogb3_body_create(a, &bd, &floor));
  OK(ogb3_shape_box(floor, &sd, &assets[0].a, &shape));
  sd.enable_sensor_events = 1;
  bd.type = OGB3_DYNAMIC;
  bd.pose.position.y = .99f;
  OK(ogb3_body_create(a, &bd, &body));
  OK(ogb3_shape_box(body, &sd, &assets[1].a, &shape));
  bd.pose.position.x = 1.1f;
  ogb3_body other;
  OK(ogb3_body_create(a, &bd, &other));
  OK(ogb3_shape_box(other, &sd, &assets[1].a, &shape));
  bd.type = OGB3_STATIC;
  bd.pose.position = (ogb3_vec3){0, 1, 0};
  ogb3_body sensor;
  OK(ogb3_body_create(a, &bd, &sensor));
  sd.is_sensor = 1;
  sd.enable_sensor_events = 1;
  OK(ogb3_shape_sphere(sensor, &sd, &(ogb3_vec3){0}, 4, &shape));
  ogb3_hinge_def hd;
  ogb3_joint hinge;
  OK(ogb3_hinge_def_default(&hd));
  hd.body_a = floor;
  hd.body_b = body;
  hd.local_frame_a.position.y = .99f;
  hd.collide_connected = 1;
  hd.enable_motor = 1;
  hd.max_motor_torque = 2;
  OK(ogb3_joint_hinge_create(a, &hd, &hinge));
  for (int i = 0; i < 3; i++)
    OK(ogb3_world_step_fixed(a));
  check_count_once_parity(a, "contact-hinge-sensor");
  ogb3_snapshot *s;
  OK(ogb3_snapshot_capture(a, &s));
  ogb3_recovery_diagnostic diag = {0};
  uint64_t size = 0;
  int status = ogb3_recovery_write(catalog, s, NULL, 0, &size, &diag);
  printf("write status%d size%llu section%u record%u reason%u\n", status,
         (unsigned long long)size, diag.section, diag.record, diag.reason);
  assert(status == 0);
  uint8_t *bytes = malloc(size);
  OK(ogb3_recovery_write(catalog, s, bytes, size, &size, &diag));
  if (argc == 2) {
    FILE *wire = fopen(argv[1], "wb");
    assert(wire && fwrite(bytes, 1, size, wire) == size);
    assert(fclose(wire) == 0);
  }
  ogb3_snapshot *decoded = NULL;
  status = ogb3_recovery_read(catalog, bytes, size, 0, &decoded, &diag);
  printf("read status%d section%u record%u field%u reason%u offset%llu\n",
         status, diag.section, diag.record, diag.field, diag.reason,
         (unsigned long long)diag.offset);
  assert(status == 0);
  check_read_info(catalog, bytes, size);
  check_info(s);
  check_atomic_info(a, s);
  check_atomic_info(a, decoded);
  check_info(decoded); /* decoded source candidate is destroyed */
  puts("combined info "
       "parity/clone/source-death/onecheck/corrupt/missing-output/failpoint "
       "PASS");

  ogb3_allocation_stats engine_before, wrapper_before;
  OK(ogb3_engine_allocation_stats(&engine_before));
  OK(ogb3_snapshot_allocation_stats(&wrapper_before));
  uint64_t published_before, motion_before;
  OK(ogb3_state_digest(a, &published_before, &motion_before));
  uint64_t live_required = 0;
  OK(ogb3_recovery_world_admit(catalog, a, 0, &live_required, &diag));
  assert(live_required == size);
  ogb3_allocation_stats admit_engine, admit_wrapper;
  OK(ogb3_engine_allocation_stats(&admit_engine));
  OK(ogb3_snapshot_allocation_stats(&admit_wrapper));
  assert(admit_engine.total_calls == engine_before.total_calls &&
         admit_engine.live_bytes == engine_before.live_bytes &&
         admit_wrapper.live_bytes == wrapper_before.live_bytes);
  assert(ogb3_recovery_world_admit(catalog, 0, 0, &live_required, &diag) ==
             OGB3_INVALID_HANDLE &&
         live_required == 0);
  assert(ogb3_recovery_world_admit(catalog, a, UINT64_MAX, &live_required,
                                   &diag) == OGB3_CAPACITY &&
         live_required == 0);
  puts("live admission full-size parity, invalid/budget controls, no engine "
       "allocations/mutation PASS");
  int admit_success = 0;
  for (int64_t fail = 0; fail < 120; fail++) {
    ogb3_snapshot_test_fail_allocation_after(fail);
    status = ogb3_recovery_world_admit(catalog, a, 0, &live_required, &diag);
    ogb3_snapshot_test_fail_allocation_after(-1);
    if (!status) {
      admit_success = 1;
      assert(live_required == size);
      printf("live admit wrapper failpoints=%lld noengineallocation PASS\n",
             (long long)fail);
      break;
    }
    assert(status == OGB3_OUT_OF_MEMORY);
    ogb3_allocation_stats e, w;
    OK(ogb3_engine_allocation_stats(&e));
    OK(ogb3_snapshot_allocation_stats(&w));
    assert(e.total_calls == engine_before.total_calls &&
           e.live_bytes == engine_before.live_bytes &&
           w.live_bytes == wrapper_before.live_bytes);
  }
  assert(admit_success);
  uint8_t *bad = malloc(OGB3_RECOVERY_MAX_BYTES);
  assert(bad);
  for (uint32_t code = 1; code <= 24; code++) {
    uint64_t bad_size = 0;
    status = ogb3_recovery_test_mutate(catalog, bytes, size, code, bad,
                                       OGB3_RECOVERY_MAX_BYTES, &bad_size);
    if (status == OGB3_UNSUPPORTED)
      continue;
    assert(status == 0);
    ogb3_snapshot *rejected = NULL;
    ogb3_allocation_stats before, after;
    OK(ogb3_engine_allocation_stats(&before));
    status = ogb3_recovery_read(catalog, bad, bad_size, 0, &rejected, &diag);
    if (code == 11) {
      assert(status == 0);
      ogb3_world temporary;
      OK(ogb3_world_create(&wd, &temporary));
      OK(ogb3_snapshot_restore(temporary, rejected));
      OK(ogb3_world_step_fixed(temporary));
      OK(ogb3_world_destroy(temporary));
      ogb3_snapshot_release(rejected);
    } else {
      if (status == 0)
        fprintf(stderr, "semantic mutation accepted code%u\n", code);
      assert(status != 0 && !rejected);
      OK(ogb3_engine_allocation_stats(&after));
      assert(after.total_calls == before.total_calls);
    }
    OK(ogb3_engine_allocation_stats(&after));
    assert(after.live_bytes == engine_before.live_bytes);
    ogb3_allocation_stats owned;
    OK(ogb3_snapshot_allocation_stats(&owned));
    assert(owned.live_bytes == wrapper_before.live_bytes);
  }
  for (uint64_t cut = 0; cut < size; cut += cut < 256 ? 1 : 71) {
    ogb3_snapshot *rejected = NULL;
    assert(ogb3_recovery_read(catalog, bytes, cut, 0, &rejected, &diag) != 0 &&
           !rejected);
  }
  /* Float classes and hard identity/length/ordering controls have valid
   * payload checksums. Invalid input must not allocate native pieces. */
  const struct {
    uint32_t offset, value;
  } fields[] = {
      {208, 0x7fc00000u}, {208, 0x7f800000u}, {208, 0x7f7fffffu},
      {192, 2},           {196, 2},           {200, 0xffffffffu},
  };
  for (unsigned i = 0; i < sizeof(fields) / sizeof(fields[0]); i++) {
    memcpy(bad, bytes, size);
    for (unsigned j = 0; j < 4; j++)
      bad[fields[i].offset + j] = (uint8_t)(fields[i].value >> (8 * j));
    ogb3_recovery_test_rehash(bad, size);
    ogb3_snapshot *result = NULL;
    ogb3_allocation_stats before, after;
    OK(ogb3_engine_allocation_stats(&before));
    assert(ogb3_recovery_read(catalog, bad, size, 0, &result, &diag) !=
               OGB3_OK &&
           !result);
    OK(ogb3_engine_allocation_stats(&after));
    assert(before.total_calls == after.total_calls);
  }
  for (unsigned offset = 24; offset <= 176; offset += 8) {
    if (offset == 32 || offset == 144 || offset == 152 || offset == 160 ||
        offset == 168)
      continue;
    memcpy(bad, bytes, size);
    bad[offset] ^= 1;
    ogb3_snapshot *result = NULL;
    assert(ogb3_recovery_read(catalog, bad, size, 0, &result, &diag) ==
               OGB3_INCOMPATIBLE &&
           !result);
  }
  ogb3_snapshot *limited = NULL;
  assert(ogb3_recovery_read(catalog, bytes, size, UINT64_MAX, &limited,
                            &diag) == OGB3_CAPACITY &&
         !limited);
  uint32_t random = 0x43b3c0deu, accepted = 0;
  for (unsigned i = 0; i < 384; i++) {
    memcpy(bad, bytes, size);
    random = random * 1664525u + 1013904223u;
    uint64_t offset = 192 + random % (size - 192);
    bad[offset] ^= (uint8_t)(1u << (random >> 29));
    ogb3_recovery_test_rehash(bad, size);
    ogb3_snapshot *result = NULL;
    status = ogb3_recovery_read(catalog, bad, size, 0, &result, &diag);
    if (!status) {
      accepted++;
      ogb3_world temporary;
      OK(ogb3_world_create(&wd, &temporary));
      OK(ogb3_snapshot_restore(temporary, result));
      ogb3_snapshot_release(result);
      for (int tick = 0; tick < 8; tick++)
        OK(ogb3_world_step_fixed(temporary));
      OK(ogb3_world_destroy(temporary));
    } else
      assert(!result);
    ogb3_allocation_stats e, w;
    OK(ogb3_engine_allocation_stats(&e));
    OK(ogb3_snapshot_allocation_stats(&w));
    assert(e.live_bytes == engine_before.live_bytes &&
           w.live_bytes == wrapper_before.live_bytes);
  }
  printf("rechecksummed scalar fuzz384 accepted%u each stepped8, all rejected "
         "owners null/balanced PASS\n",
         accepted);
  int write_success = 0;
  for (int64_t fail = 0; fail < 240; fail++) {
    uint64_t required = 0;
    ogb3_snapshot_test_fail_allocation_after(fail);
    status = ogb3_recovery_write(catalog, s, NULL, 0, &required, &diag);
    ogb3_snapshot_test_fail_allocation_after(-1);
    if (!status) {
      write_success = 1;
      printf("write wrapper failpoints complete count=%lld\n", (long long)fail);
      break;
    }
    assert(status == OGB3_OUT_OF_MEMORY);
    ogb3_allocation_stats e, w;
    OK(ogb3_engine_allocation_stats(&e));
    OK(ogb3_snapshot_allocation_stats(&w));
    assert(e.live_bytes == engine_before.live_bytes &&
           w.live_bytes == wrapper_before.live_bytes);
  }
  assert(write_success);
  int wrapper_success = 0;
  for (int64_t fail = 0; fail < 600; fail++) {
    ogb3_snapshot *result = NULL;
    ogb3_snapshot_test_fail_allocation_after(fail);
    uint64_t metadata[6];
    for (int j = 0; j < 6; j++)
      metadata[j] = UINT64_MAX;
    uint32_t geometry_count = UINT32_MAX;
    status = ogb3_recovery_read_info(
        catalog, bytes, size, 0, &result, metadata, metadata + 1, metadata + 2,
        &geometry_count, metadata + 3, metadata + 4, metadata + 5, &diag);
    ogb3_snapshot_test_fail_allocation_after(-1);
    if (status) {
      for (int j = 0; j < 6; j++)
        assert(metadata[j] == UINT64_MAX);
      assert(geometry_count == UINT32_MAX);
    }
    if (status == 0) {
      ogb3_snapshot_release(result);
      wrapper_success = 1;
      printf("wrapper failpoints complete count=%lld\n", (long long)fail);
      break;
    }
    assert(status == OGB3_OUT_OF_MEMORY && !result);
    ogb3_allocation_stats e, w;
    OK(ogb3_engine_allocation_stats(&e));
    OK(ogb3_snapshot_allocation_stats(&w));
    if (e.live_bytes != engine_before.live_bytes ||
        w.live_bytes != wrapper_before.live_bytes)
      fprintf(stderr, "allocation leak fail%lld e%llu w%llu\n", (long long)fail,
              (unsigned long long)e.live_bytes,
              (unsigned long long)w.live_bytes);
    assert(e.live_bytes == engine_before.live_bytes &&
           w.live_bytes == wrapper_before.live_bytes);
  }
  assert(wrapper_success);
  int native_success = 0;
  for (int64_t fail = 0; fail < 240; fail++) {
    ogb3_snapshot *result = NULL;
    ogb3_recovery_test_fail_build_after(fail);
    status = ogb3_recovery_read(catalog, bytes, size, 0, &result, &diag);
    ogb3_recovery_test_fail_build_after(-1);
    if (status == 0) {
      ogb3_snapshot_release(result);
      native_success = 1;
      printf("native ledger failpoints complete count=%lld\n", (long long)fail);
      break;
    }
    assert(status == OGB3_OUT_OF_MEMORY && !result);
    ogb3_allocation_stats e, w;
    OK(ogb3_engine_allocation_stats(&e));
    OK(ogb3_snapshot_allocation_stats(&w));
    assert(e.live_bytes == engine_before.live_bytes &&
           w.live_bytes == wrapper_before.live_bytes);
  }
  assert(native_success);
  free(bad);
  uint64_t published_after, motion_after;
  OK(ogb3_state_digest(a, &published_after, &motion_after));
  assert(published_before == published_after && motion_before == motion_after);
  puts("semantic controls, truncations, wrapper/native-ledger failpoints, "
       "unchanged publication PASS");
  OK(ogb3_snapshot_restore(b, decoded));
  equal(a, b);
  /* Allocation/free order and generation behavior must survive decoding, not
   * only a suffix with an unchanged object set. */
  ogb3_body other_b;
  OK(ogb3_body_retarget(b, other, &other_b));
  OK(ogb3_body_destroy(other));
  OK(ogb3_body_destroy(other_b));
  ogb3_body_def future_def;
  OK(ogb3_body_def_default(&future_def));
  future_def.type = OGB3_DYNAMIC;
  future_def.pose.position = (ogb3_vec3){.2f, 2, 0};
  ogb3_body future_a, future_b;
  OK(ogb3_body_create(a, &future_def, &future_a));
  OK(ogb3_body_create(b, &future_def, &future_b));
  ogb3_body_key key_a, key_b;
  OK(ogb3_body_get_key(future_a, &key_a));
  OK(ogb3_body_get_key(future_b, &key_b));
  assert(key_a == key_b);
  ogb3_shape_def future_shape;
  OK(ogb3_shape_def_default(&future_shape));
  ogb3_shape shape_a, shape_b;
  OK(ogb3_shape_box(future_a, &future_shape, &assets[1].a, &shape_a));
  OK(ogb3_shape_box(future_b, &future_shape, &assets[1].a, &shape_b));
  ogb3_shape_key shape_key_a, shape_key_b;
  OK(ogb3_shape_get_key(shape_a, &shape_key_a));
  OK(ogb3_shape_get_key(shape_b, &shape_key_b));
  assert(shape_key_a == shape_key_b);
  ogb3_joint hinge_b;
  OK(ogb3_joint_retarget(b, hinge, &hinge_b));
  OK(ogb3_joint_destroy(hinge));
  OK(ogb3_joint_destroy(hinge_b));
  ogb3_hinge_def hd_b = hd;
  OK(ogb3_body_retarget(b, hd.body_a, &hd_b.body_a));
  OK(ogb3_body_retarget(b, hd.body_b, &hd_b.body_b));
  OK(ogb3_joint_hinge_create(a, &hd, &hinge));
  OK(ogb3_joint_hinge_create(b, &hd_b, &hinge_b));
  ogb3_joint_key joint_key_a, joint_key_b;
  OK(ogb3_joint_get_key(hinge, &joint_key_a));
  OK(ogb3_joint_get_key(hinge_b, &joint_key_b));
  assert(joint_key_a == joint_key_b);
  equal(a, b);
  puts("future body/shape/joint reuse and generations after decode PASS");
  for (int i = 0; i < 120; i++) {
    OK(ogb3_world_step_fixed(a));
    OK(ogb3_world_step_fixed(b));
    equal(a, b);
  }
  printf("canonical roundtrip+120suffix PASS bytes=%llu\n",
         (unsigned long long)size);
  ogb3_snapshot_release(s);
  ogb3_snapshot_release(decoded);
  ogb3_recovery_catalog_release(catalog);
  OK(ogb3_world_destroy(a));
  OK(ogb3_world_destroy(b));
  free(bytes);
  ogb3_allocation_stats e, w;
  OK(ogb3_engine_allocation_stats(&e));
  OK(ogb3_snapshot_allocation_stats(&w));
  printf("allocation metrics engine_peak=%llu wrapper_peak=%llu "
         "engine_calls=%llu wrapper_calls=%llu\n",
         (unsigned long long)e.high_water_bytes,
         (unsigned long long)w.high_water_bytes,
         (unsigned long long)e.total_calls, (unsigned long long)w.total_calls);
  assert(!e.live_bytes && !w.live_bytes);
  puts("balanced ownership PASS");
  return 0;
}
