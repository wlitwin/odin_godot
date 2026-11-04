/* Native acceptance tests. Private mutation controls deliberately modify fields
 * omitted by the upstream motion hash while retaining equal current poses. */
#define _POSIX_C_SOURCE 200112L
#include "api.h"
#include "block_allocator.h"
#include "body.h"
#include "box3d/box3d.h"
#include "box3d/collision.h"
#include "broad_phase.h"
#include "contact.h"
#include "joint.h"
#include "owned_snapshot.h"
#include "physics_world.h"
#include "recording.h"
#include "shape.h"
#include "state_dump.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define CHECK(x)                                                               \
  do {                                                                         \
    if (!(x)) {                                                                \
      fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #x);             \
      exit(1);                                                                 \
    }                                                                          \
  } while (0)
#define OK(x) CHECK((x) == OGB3_OK)
extern void ogb3_snapshot_test_fail_stage(int);
extern int32_t ogb3_snapshot_test_pending_corrupt_restore(uint32_t,
                                                          ogb3_snapshot *);
extern void ogb3_snapshot_test_pose_limit(uint32_t);
extern void ogb3_snapshot_test_pending_limit(uint32_t);
extern void ogb3_snapshot_test_fail_allocation_after(int64_t);
extern int32_t ogb3_snapshot_test_incompatible(uint32_t, ogb3_snapshot *);
extern const uint8_t *ogb3_snapshot_test_image(const ogb3_snapshot *,
                                               uint64_t *);
extern int32_t ogb3_snapshot_test_restore_bytes(uint32_t, const ogb3_snapshot *,
                                                const uint8_t *, uint64_t);
static uint64_t allocations, allocated_bytes, active_bytes, peak_bytes;
typedef struct Allocation {
  void *base;
  uint64_t bytes;
} Allocation;
static void *alloc_fn(size_t size, int32_t alignment) {
  size_t align = (size_t)alignment;
  if (align < sizeof(void *))
    align = sizeof(void *);
  void *base = NULL;
  CHECK(posix_memalign(&base, align,
                       (size_t)size + align + sizeof(Allocation)) == 0);
  uintptr_t addr = ((uintptr_t)base + sizeof(Allocation) + align - 1) &
                   ~(uintptr_t)(align - 1);
  Allocation *a = (Allocation *)addr - 1;
  a->base = base;
  a->bytes = size;
  allocations++;
  allocated_bytes += size;
  active_bytes += size;
  if (active_bytes > peak_bytes)
    peak_bytes = active_bytes;
  return (void *)addr;
}
static void free_fn(void *p, size_t size) {
  if (p) {
    Allocation *a = (Allocation *)p - 1;
    CHECK(a->bytes == (uint64_t)size);
    CHECK(active_bytes >= a->bytes);
    active_bytes -= a->bytes;
    free(a->base);
  }
}
static b3WorldId native_world(ogb3_world id) {
  b3WorldId x;
  memcpy(&x, &id, sizeof(x));
  return x;
}
static b3BodyId native_body(ogb3_body id) {
  b3BodyId x;
  memcpy(&x, &id, sizeof(x));
  return x;
}
static b3ShapeId native_shape(ogb3_shape id) {
  b3ShapeId x;
  memcpy(&x, &id, sizeof(x));
  return x;
}
static b3JointId native_joint(ogb3_joint id) {
  b3JointId x;
  memcpy(&x, &id, sizeof(x));
  return x;
}
static ogb3_world world_new(void) {
  ogb3_world_def d;
  ogb3_world w;
  OK(ogb3_world_def_default(&d));
  OK(ogb3_world_create(&d, &w));
  return w;
}
static ogb3_body box(ogb3_world w, int type, float x, float y, float z,
                     float hx, float hy, float hz, ogb3_shape *out) {
  ogb3_body_def b;
  ogb3_shape_def s;
  ogb3_body id;
  ogb3_shape shape;
  OK(ogb3_body_def_default(&b));
  b.type = type;
  b.pose.position = (ogb3_vec3){x, y, z};
  OK(ogb3_body_create(w, &b, &id));
  OK(ogb3_shape_def_default(&s));
  s.enable_sensor_events = 1;
  s.enable_contact_events = 1;
  ogb3_vec3 half = {hx, hy, hz};
  OK(ogb3_shape_box(id, &s, &half, &shape));
  if (out)
    *out = shape;
  return id;
}
typedef struct {
  ogb3_world w;
  ogb3_body body, ground;
  ogb3_shape shape, sensor;
  ogb3_joint joint;
} Fixture;
static Fixture fixture(void) {
  Fixture f = {0};
  f.w = world_new();
  f.ground = box(f.w, OGB3_STATIC, 0, -1, 0, 15, 1, 15, NULL);
  for (int i = 0; i < 20; i++) {
    ogb3_body b = box(f.w, OGB3_DYNAMIC, (float)(i % 5) - 2,
                      0.51f + 1.1f * (i / 5), 0, .5f, .5f, .5f, &f.shape);
    if (i == 0)
      f.body = b;
  }
  ogb3_body_def bd;
  ogb3_shape_def sd;
  ogb3_body sensorbody;
  OK(ogb3_body_def_default(&bd));
  bd.type = OGB3_STATIC;
  bd.pose.position = (ogb3_vec3){0, 2, 0};
  OK(ogb3_body_create(f.w, &bd, &sensorbody));
  OK(ogb3_shape_def_default(&sd));
  sd.is_sensor = 1;
  sd.enable_sensor_events = 1;
  ogb3_vec3 center = {0};
  OK(ogb3_shape_sphere(sensorbody, &sd, &center, 2, &f.sensor));
  ogb3_hinge_def jd;
  OK(ogb3_hinge_def_default(&jd));
  jd.body_a = f.ground;
  jd.body_b = f.body;
  jd.enable_motor = 1;
  jd.motor_speed = .5f;
  jd.max_motor_torque = 2;
  jd.collide_connected = 1;
  OK(ogb3_joint_hinge_create(f.w, &jd, &f.joint));
  return f;
}
static uint64_t owned_live(void) {
  ogb3_allocation_stats stats;
  OK(ogb3_snapshot_allocation_stats(&stats));
  return stats.live_bytes;
}
static uint64_t digest(ogb3_world w) {
  uint64_t a, b;
  OK(ogb3_state_digest(w, &a, &b));
  return a;
}
static void equal_worlds(ogb3_world a, ogb3_world b) {
  uint64_t na, nb;
  OK(ogb3_state_dump(a, NULL, 0, &na));
  OK(ogb3_state_dump(b, NULL, 0, &nb));
  CHECK(na == nb);
  uint8_t *aa = malloc(na), *bb = malloc(nb);
  CHECK(aa && bb);
  OK(ogb3_state_dump(a, aa, na, &na));
  OK(ogb3_state_dump(b, bb, nb, &nb));
  if (memcmp(aa, bb, na)) {
    uint64_t i = 0;
    while (i < na && aa[i] == bb[i])
      i++;
    fprintf(stderr,
            "first normalized mismatch offset=%llu a=%u b=%u bytes=%llu\n",
            (unsigned long long)i, aa[i], bb[i], (unsigned long long)na);
    CHECK(0);
  }
  free(aa);
  free(bb);
}
static void block_allocator_alignment(void) {
  int stride = (int)sizeof(void *) + 4;
  b3BlockAllocator allocator = b3CreateBlockAllocator(stride, 0);
  void *a = b3AllocateElement(&allocator), *b = b3AllocateElement(&allocator),
       *c = b3AllocateElement(&allocator);
  CHECK(allocator.elementSize>=stride);
  CHECK(allocator.elementSize%B3_BLOCK_ALIGNMENT==0);
  CHECK((uintptr_t)a%B3_BLOCK_ALIGNMENT==0);
  CHECK((uintptr_t)b%B3_BLOCK_ALIGNMENT==0);
  CHECK((uintptr_t)c%B3_BLOCK_ALIGNMENT==0);
  b3FreeElement(&allocator, a);
  b3FreeElement(&allocator, b);
  b3FreeElement(&allocator, c);
  CHECK(b3AllocateElement(&allocator) == c);
  CHECK(b3AllocateElement(&allocator) == b);
  CHECK(b3AllocateElement(&allocator) == a);
  b3FreeElement(&allocator, a);
  b3FreeElement(&allocator, b);
  b3FreeElement(&allocator, c);
  CHECK(allocator.allocationCount == 0);
  b3DestroyBlockAllocator(&allocator);
  printf("block_allocator_alignment odd_request=%d manifold_stride=%zu "
         "pointer_alignment=%zu free_list_order_preserved=1 PASS\n",
         stride, sizeof(b3Manifold), _Alignof(void *));
}
typedef struct {int removed_index,count;} TreeQueryCheck;
static bool remaining_tree_proxy(int proxy,uint64_t shape,void*context){
  (void)proxy;TreeQueryCheck*c=context;CHECK(shape!=(uint64_t)c->removed_index);c->count++;return true;
}
static void broadphase_last_move_destroy(void) {
  for (int type = OGB3_KINEMATIC; type <= OGB3_DYNAMIC; type++) {
    ogb3_world w = world_new();
    OK(ogb3_world_set_gravity(w, &(ogb3_vec3){0}));
    ogb3_body bodies[3];
    ogb3_shape shapes[3];
    for (int i = 0; i < 3; i++)
      bodies[i] = box(w, type, 3.0f * i, 0, 0, .25f, .25f, .25f, &shapes[i]);
    OK(ogb3_world_step_fixed(w));
    b3World *world = b3GetWorldFromId(native_world(w));
    b3DynamicTree *tree = &world->broadPhase.trees[type];
    int selected = -1;
    for (int i = 0; i < 3; i++) {
      int proxy = B3_PROXY_ID(
          world->shapes.data[native_shape(shapes[i]).index1 - 1].proxyKey);
      int node = tree->proxies[proxy].node;
      int parent = tree->parents[node];
      if (parent != B3_NULL_INDEX &&
          tree->parents[parent] != B3_NULL_INDEX) {
        selected = i;
        break;
      }
    }
    CHECK(selected >= 0);
    OK(ogb3_body_set_velocity(bodies[selected], &(ogb3_vec3){0, 50, 0},
                              &(ogb3_vec3){0}));
    OK(ogb3_world_step_fixed(w));
    int moved[3];
    CHECK(b3DynamicTree_GatherMovedProxies(tree,moved)==1);
    CHECK(b3IsNodeMoved(tree->nodes));
    int removed_index=native_shape(shapes[selected]).index1-1;
    OK(ogb3_body_destroy(bodies[selected]));
    CHECK(b3DynamicTree_GatherMovedProxies(tree,moved)==0);
    CHECK(tree->proxyCount==2);
    /* New paired-tree removal refits ancestors directly or leaves explicit
     * rebuild work. Preserve the actual safety/query guarantee in either case. */
    TreeQueryCheck query={removed_index,0};
    b3AABB all={{-1000,-1000,-1000},{1000,1000,1000}};
    b3DynamicTree_Query(tree,all,~UINT64_C(0),false,remaining_tree_proxy,&query);
    CHECK(query.count==2);
    b3DynamicTree_Validate(tree);
    OK(ogb3_world_step_fixed(w));
    b3DynamicTree_Validate(tree);
    b3DynamicTree_ValidateNoMoved(tree);
    query.count=0;
    b3DynamicTree_Query(tree,all,~UINT64_C(0),false,remaining_tree_proxy,&query);
    CHECK(query.count==2);
    OK(ogb3_world_destroy(w));
  }
  puts("broadphase_last_moved_proxy_destroy dynamic/kinematic "
       "last_moved_destroy_survivor_queries_and_tree_invariants PASS");
}
static void mutation_controls(void) {
  Fixture f = fixture();
  for (int i = 0; i < 60; i++)
    OK(ogb3_world_step_fixed(f.w));
  b3World *w = b3GetWorldFromId(native_world(f.w));
  uint64_t complete = digest(f.w), motion, other;
  OK(ogb3_state_digest(f.w, &other, &motion));
  w->gravity.y -= 1;
  CHECK(digest(f.w) != complete);
  uint64_t m2;
  OK(ogb3_state_digest(f.w, &other, &m2));
  CHECK(motion == m2);
  w->gravity.y += 1;
  b3Body *b = b3GetBodyFullId(w, native_body(f.body));
  float sleep = b->sleepTime;
  b->sleepTime += .25f;
  CHECK(digest(f.w) != complete);
  b->sleepTime = sleep;
  b3Joint *j = b3GetJointFullId(w, native_joint(f.joint));
  b3JointSim *sim = b3GetJointSim(w, j);
  float motor = sim->revoluteJoint.motorSpeed;
  sim->revoluteJoint.motorSpeed += 1;
  CHECK(digest(f.w) != complete);
  sim->revoluteJoint.motorSpeed = motor;
  int contacts = 0;
  for (int i = 0; i < w->contacts.count; i++) {
    b3Contact *c = w->contacts.data + i;
    if (c->contactId == i && c->manifoldCount && c->manifolds[0].pointCount) {
      float impulse = c->manifolds[0].points[0].normalImpulse;
      c->manifolds[0].points[0].normalImpulse += .1f;
      CHECK(digest(f.w) != complete);
      c->manifolds[0].points[0].normalImpulse = impulse;
      contacts++;
      break;
    }
  }
  CHECK(contacts);
  int pool = w->bodyIdPool.nextIndex;
  w->bodyIdPool.nextIndex++;
  CHECK(digest(f.w) != complete);
  w->bodyIdPool.nextIndex = pool;
  CHECK(digest(f.w) == complete);
  ogb3_body one = box(f.w, OGB3_DYNAMIC, 10, 10, 0, .2f, .2f, .2f, NULL);
  ogb3_body two = box(f.w, OGB3_DYNAMIC, 11, 10, 0, .2f, .2f, .2f, NULL);
  box(f.w, OGB3_DYNAMIC, 12, 10, 0, .2f, .2f, .2f, NULL);
  OK(ogb3_body_destroy(one));
  OK(ogb3_body_destroy(two));
  CHECK(w->bodyIdPool.freeArray.count >= 2);
  uint64_t ordered = digest(f.w);
  int first = w->bodyIdPool.freeArray.data[0];
  w->bodyIdPool.freeArray.data[0] = w->bodyIdPool.freeArray.data[1];
  w->bodyIdPool.freeArray.data[1] = first;
  CHECK(digest(f.w) != ordered);
  OK(ogb3_world_destroy(f.w));
  puts(
      "mutation_controls "
      "gravity/contact_impulse/joint_motor/sleep/id_pool/free_list_order PASS");
}
static void rollback_lifecycle(void) {
  Fixture a = fixture(), b = fixture();
  equal_worlds(a.w, b.w);
  int sensor_begins = 0;
  for (int i = 0; i < 90; i++) {
    OK(ogb3_world_step_fixed(a.w));
    OK(ogb3_world_step_fixed(b.w));
    equal_worlds(a.w, b.w);
    sensor_begins +=
        b3GetWorldFromId(native_world(a.w))->sensorBeginEvents.count;
  }
  CHECK(sensor_begins > 0);
  b3Body_SetUserData(native_body(a.body), (void *)(uintptr_t)0x1234);
  b3Shape_SetUserData(native_shape(a.shape), (void *)(uintptr_t)0x2345);
  b3Joint_SetUserData(native_joint(a.joint), (void *)(uintptr_t)0x3456);
  ogb3_snapshot *s = NULL, *clone = NULL;
  OK(ogb3_snapshot_capture(a.w, &s));
  OK(ogb3_snapshot_clone(s, &clone));
  uint64_t used, cap, geometry;
  uint32_t count;
  OK(ogb3_snapshot_metrics(s, &used, &cap, &geometry, &count));
  CHECK(used > 0 && cap >= used && geometry > 0 && count > 0);
  uint64_t normalized, wrapper, native;
  OK(ogb3_snapshot_storage(s, &normalized, &wrapper, &native));
  CHECK(normalized > 0 && wrapper > normalized && native > cap + geometry);
  uint8_t *baseline[181];
  uint64_t sizes[181];
  for (int tick = 0; tick <= 180; tick++) {
    if (tick)
      OK(ogb3_world_step_fixed(b.w));
    OK(ogb3_state_dump(b.w, NULL, 0, &sizes[tick]));
    baseline[tick] = malloc(sizes[tick]);
    CHECK(baseline[tick]);
    OK(ogb3_state_dump(b.w, baseline[tick], sizes[tick], &sizes[tick]));
  }
  OK(ogb3_snapshot_restore(b.w, clone));
  uint64_t saved = digest(a.w);
  ogb3_body future = box(a.w, OGB3_DYNAMIC, 4, 8, 0, .3f, .3f, .3f, NULL);
  OK(ogb3_world_step_fixed(a.w));
  CHECK(b3GetWorldFromId(native_world(a.w))->bodyMoveEvents.count > 0);
  OK(ogb3_snapshot_restore(a.w, s));
  CHECK(digest(a.w) == saved);
  equal_worlds(a.w, b.w);
  CHECK(!b3Body_IsValid(native_body(future)));
  ogb3_body replacement = box(a.w, OGB3_DYNAMIC, 5, 8, 0, .3f, .3f, .3f, NULL);
  CHECK(replacement == future);
  OK(ogb3_snapshot_restore(a.w, s));
  CHECK(b3Body_GetUserData(native_body(a.body)) == NULL);
  CHECK(b3Shape_GetUserData(native_shape(a.shape)) == NULL);
  CHECK(b3Joint_GetUserData(native_joint(a.joint)) == NULL);
  b3World *w = b3GetWorldFromId(native_world(a.w));
  CHECK(w->bodyMoveEvents.count == 0 && w->sensorBeginEvents.count == 0 &&
        w->contactBeginEvents.count == 0 && w->contactHitEvents.count == 0 &&
        w->jointEvents.count == 0);
  for (int i = 0; i < 2; i++)
    CHECK(w->sensorEndEvents[i].count == 0 &&
          w->contactEndEvents[i].count == 0);
  b3Body_SetUserData(native_body(a.body), (void *)(uintptr_t)0x9999);
  CHECK(digest(a.w) == saved);
  for (int i = 0; i < 2; i++) {
    OK(ogb3_snapshot_restore(a.w, s));
    OK(ogb3_snapshot_restore(b.w, clone));
    equal_worlds(a.w, b.w);
    for (int tick = 1; tick <= 180; tick++) {
      OK(ogb3_world_step_fixed(a.w));
      OK(ogb3_world_step_fixed(b.w));
      equal_worlds(a.w, b.w);
      uint64_t n = 0;
      OK(ogb3_state_dump(a.w, NULL, 0, &n));
      CHECK(n == sizes[tick]);
      uint8_t *actual = malloc(n);
      CHECK(actual);
      OK(ogb3_state_dump(a.w, actual, n, &n));
      if (memcmp(actual, baseline[tick], n)) {
        fprintf(stderr, "independent baseline mismatch branch=%d tick=%d\n", i,
                tick);
        CHECK(0);
      }
      free(actual);
    }
  }
  OK(ogb3_snapshot_restore(a.w, s));
  OK(ogb3_body_set_awake(a.body, 0));
  CHECK(!b3Body_IsAwake(native_body(a.body)));
  OK(ogb3_snapshot_restore(a.w, s));
  OK(ogb3_body_set_awake(a.body, 1));
  CHECK(b3Body_IsAwake(native_body(a.body)));
  /* Both double-buffered end arrays must be erased even destroy-before-step. */
  OK(ogb3_shape_destroy(a.sensor));
  CHECK(w->sensorEndEvents[0].count + w->sensorEndEvents[1].count > 0);
  OK(ogb3_snapshot_restore(a.w, s));
  for (int i = 0; i < 2; i++)
    CHECK(w->sensorEndEvents[i].count == 0 &&
          w->contactEndEvents[i].count == 0);
  for (int tick = 0; tick <= 180; tick++)
    free(baseline[tick]);
  ogb3_snapshot_release(s);
  OK(ogb3_world_destroy(a.w));
  OK(ogb3_snapshot_restore(b.w, clone));
  ogb3_snapshot_release(clone);
  OK(ogb3_world_step_fixed(b.w));
  OK(ogb3_world_destroy(b.w));
  printf("rollback_lifecycle independent_world_ticks=90 "
         "scratch_replay_ticks=360 registry_entries=%u geometry_bytes=%llu "
         "image_used=%llu image_capacity=%llu PASS\n",
         count, (unsigned long long)geometry, (unsigned long long)used,
         (unsigned long long)cap);
}
static void failed_candidates(void) {
  Fixture f = fixture();
  for (int i = 0; i < 30; i++)
    OK(ogb3_world_step_fixed(f.w));
  ogb3_snapshot *s;
  OK(ogb3_snapshot_capture(f.w, &s));
  uint64_t before = digest(f.w), n;
  const uint8_t *data = ogb3_snapshot_test_image(s, &n);
  uint8_t *copy = malloc(n);
  CHECK(copy);
  memcpy(copy, data, n);
  int native_count = b3GetWorldCount();
  uint64_t native_bytes = active_bytes, wrapper_bytes = owned_live();
  CHECK(ogb3_snapshot_test_incompatible(f.w, s) == OGB3_INCOMPATIBLE);
  CHECK(digest(f.w) == before);
  uint64_t cuts[] = {0, 1, 15, 16, 112, n / 2, n - 1};
  for (unsigned i = 0; i < sizeof(cuts) / sizeof(cuts[0]); i++) {
    CHECK(ogb3_snapshot_test_restore_bytes(f.w, s, copy, cuts[i]) ==
          OGB3_CORRUPT);
    CHECK(digest(f.w) == before);
    CHECK(b3GetWorldCount() == native_count);
    CHECK(active_bytes == native_bytes);
    CHECK(owned_live() == wrapper_bytes);
  }
  uint64_t offsets[] = {0, 4, 8, 12, 16, 112, n / 2, n - 1};
  for (unsigned i = 0; i < sizeof(offsets) / sizeof(offsets[0]); i++) {
    copy[offsets[i]] ^= 0xff;
    CHECK(ogb3_snapshot_test_restore_bytes(f.w, s, copy, n) == OGB3_CORRUPT);
    copy[offsets[i]] ^= 0xff;
    CHECK(digest(f.w) == before);
    CHECK(active_bytes == native_bytes);
    CHECK(owned_live() == wrapper_bytes);
  }
  for (int stage = 1; stage <= 3; stage++) {
    ogb3_snapshot_test_fail_stage(stage);
    CHECK(ogb3_snapshot_restore(f.w, s) == OGB3_OUT_OF_MEMORY);
    CHECK(digest(f.w) == before);
    CHECK(b3GetWorldCount() == native_count);
    CHECK(active_bytes == native_bytes);
    CHECK(owned_live() == wrapper_bytes);
  }
  ogb3_snapshot_test_fail_stage(0);
  for (int64_t allocation = 0; allocation < 5; allocation++) {
    ogb3_snapshot_test_fail_allocation_after(allocation);
    ogb3_snapshot *failed = NULL;
    CHECK(ogb3_snapshot_capture(f.w, &failed) == OGB3_OUT_OF_MEMORY);
    CHECK(failed == NULL);
    ogb3_snapshot_test_fail_allocation_after(-1);
    CHECK(digest(f.w) == before);
    CHECK(owned_live() == wrapper_bytes);
    CHECK(active_bytes == native_bytes);
  }
  ogb3_snapshot_test_fail_allocation_after(0);
  CHECK(ogb3_snapshot_restore(f.w, s) == OGB3_OUT_OF_MEMORY);
  ogb3_snapshot_test_fail_allocation_after(-1);
  CHECK(owned_live() == wrapper_bytes);
  OK(ogb3_snapshot_restore(f.w, s));
  free(copy);
  ogb3_snapshot_release(s);
  OK(ogb3_world_destroy(f.w));
  puts("failed_candidates truncated=7 corrupt=8 failpoints=3 "
       "actual_wrapper_allocation_failures=6 published_preserved=1 "
       "candidate_allocations_released=1 PASS");
}
static void compound_alignment_cases(void) {
  b3Vec3 points[] = {{-2, 0, -2}, {2, 0, -2}, {2, 0, 2}, {-2, 0, 2}};
  int32_t indices[] = {0, 2, 1, 0, 3, 2};
  uint8_t material_ids[] = {0, 0};
  b3MeshDef md = {0};
  md.vertices = points;
  md.vertexCount = 4;
  md.indices = indices;
  md.triangleCount = 2;
  md.materialIndices = material_ids;
  b3MeshData *m1 = b3CreateMesh(&md, NULL, 0);
  CHECK(m1);
  md.triangleCount = 1;
  b3MeshData *m2 = b3CreateMesh(&md, NULL, 0);
  CHECK(m2);
  b3BoxHull h1 = b3MakeBoxHull(.2f, .3f, .4f),
            h2 = b3MakeBoxHull(.3f, .4f, .5f);
  b3SurfaceMaterial material = b3DefaultSurfaceMaterial();
  for (int count = 1; count <= 2; count++) {
    b3CompoundHullDef hulls[2] = {0};
    b3CompoundMeshDef meshes[2] = {0};
    b3CompoundCapsuleDef capsules[2] = {0};
    b3CompoundSphereDef spheres[2] = {0};
    for (int i = 0; i < count; i++) {
      hulls[i].hull = i ? &h2.base : &h1.base;
      hulls[i].transform = b3Transform_identity;
      hulls[i].transform.p.x = 3.0f * i;
      hulls[i].material = material;
      meshes[i].meshData = i ? m2 : m1;
      meshes[i].transform = b3Transform_identity;
      meshes[i].scale = (b3Vec3){1, 1, 1};
      meshes[i].materials = &material;
      meshes[i].materialCount = 1;
      capsules[i].capsule = (b3Capsule){{0, 0, 0}, {0, 1, 0}, .2f};
      capsules[i].material = material;
      spheres[i].sphere = (b3Sphere){{0, 0, 0}, .2f};
      spheres[i].material = material;
    }
    b3CompoundDef cd = {0};
    cd.hulls = hulls;
    cd.hullCount = count;
    cd.meshes = meshes;
    cd.meshCount = count;
    cd.capsules = capsules;
    cd.capsuleCount = count;
    cd.spheres = spheres;
    cd.sphereCount = count;
    b3CompoundData *c = b3CreateCompound(&cd);
    CHECK(c);
    CHECK(((uintptr_t)c+c->nodeOffset) % _Alignof(b3TreeNode) == 0);
    CHECK(((uintptr_t)c + c->materialOffset) % _Alignof(b3SurfaceMaterial) ==
          0);
    CHECK(((uintptr_t)c + c->capsuleOffset) % _Alignof(b3CompoundCapsule) == 0);
    CHECK(((uintptr_t)c + c->sphereOffset) % _Alignof(b3CompoundSphere) == 0);
    for (int i = 0; i < count * 4; i++) {
      b3ChildShape child = b3GetCompoundChild(c, i);
      if (child.type == b3_hullShape)
        CHECK((uintptr_t)child.hull % _Alignof(b3HullData) == 0);
      if (child.type == b3_meshShape)
        CHECK((uintptr_t)child.mesh.data % _Alignof(b3MeshData) == 0);
    }
    ogb3_world source = world_new(), dest = world_new();
    b3BodyDef bd = b3DefaultBodyDef();
    b3BodyId body = b3CreateBody(native_world(source), &bd);
    b3ShapeDef sd = b3DefaultShapeDef();
    b3CreateBakedCompoundShape(body, &sd, c);
    b3World *source_world = b3GetWorldFromId(native_world(source));
    b3Shape *compound_shape = source_world->shapes.data;
    CHECK(compound_shape->materials != NULL &&
          compound_shape->materialCount > 0);
    uint64_t active_digest = digest(source);
    compound_shape->material.friction = 91.0f;
    compound_shape->material.restitution = 81.0f;
    CHECK(digest(source) == active_digest);
    float active_friction = compound_shape->materials[0].friction;
    compound_shape->materials[0].friction += .25f;
    CHECK(digest(source) != active_digest);
    compound_shape->materials[0].friction = active_friction;
    ogb3_snapshot *s;
    OK(ogb3_snapshot_capture(source, &s));
    OK(ogb3_snapshot_restore(dest, s));
    equal_worlds(source, dest);
    OK(ogb3_world_destroy(source));
    b3DestroyCompound(c);
    ogb3_snapshot_release(s);
    box(dest, OGB3_DYNAMIC, 0, 4, 0, .3f, .3f, .3f, NULL);
    for (int tick = 0; tick < 120; tick++)
      OK(ogb3_world_step_fixed(dest));
    OK(ogb3_world_destroy(dest));
  }
  b3DestroyMesh(m1);
  b3DestroyMesh(m2);
  puts("compound_alignment odd/even1/2 all_capsule/hull/mesh/sphere arrays "
       "aligned inactive_material_ignored/active_material_detected "
       "snapshot_lifetime_and_240_contact_ticks PASS");
}
static void allocation_keys_and_historical_states(void) {
  Fixture f = fixture();
  ogb3_world dest = world_new();
  for (int i = 0; i < 30; i++)
    OK(ogb3_world_step_fixed(f.w));
  ogb3_body_key bk = 0;
  ogb3_shape_key sk = 0;
  ogb3_joint_key jk = 0;
  OK(ogb3_body_get_key(f.body, &bk));
  OK(ogb3_shape_get_key(f.shape, &sk));
  OK(ogb3_joint_get_key(f.joint, &jk));
  CHECK(bk && sk && jk);
  ogb3_world_counters counts;
  OK(ogb3_world_get_counters(f.w, &counts));
  CHECK(counts.body_count == 22 && counts.shape_count == 22 &&
        counts.contact_count > 0 && counts.joint_count == 1);
  uint32_t size, align, offset;
  OK(ogb3_abi_layout(OGB3_T_WORLD_COUNTERS, 0, &size, &align, &offset));
  CHECK(size == sizeof(counts) && offset == 0);
  OK(ogb3_abi_layout(OGB3_T_BODY_STATE, 0, &size, &align, &offset));
  CHECK(size == sizeof(ogb3_body_state) && offset == 0);
  ogb3_body unchanged = UINT64_MAX;
  CHECK(ogb3_body_resolve(f.w, 0, &unchanged) == OGB3_INVALID_ARGUMENT);
  CHECK(unchanged == UINT64_MAX);
  CHECK(ogb3_body_resolve(f.w, (UINT64_C(1) << 48) | 1, &unchanged) ==
        OGB3_INVALID_ARGUMENT);
  CHECK(unchanged == UINT64_MAX);
  CHECK(ogb3_body_resolve(f.w, UINT32_MAX, &unchanged) ==
        OGB3_INVALID_ARGUMENT);
  CHECK(unchanged == UINT64_MAX);
  CHECK(ogb3_body_resolve(f.w, 10000, &unchanged) == OGB3_INVALID_HANDLE);
  CHECK(unchanged == UINT64_MAX);
  CHECK(ogb3_body_resolve(0, bk, &unchanged) == OGB3_INVALID_HANDLE);
  CHECK(unchanged == UINT64_MAX);
  ogb3_body_key missing = 99;
  CHECK(ogb3_body_get_key(0, &missing) == OGB3_INVALID_HANDLE);
  CHECK(missing == 99);
  uint64_t bytes = active_bytes, owners = owned_live();
  ogb3_snapshot *failed = NULL;
  ogb3_snapshot_test_pose_limit(1);
  CHECK(ogb3_snapshot_capture(f.w, &failed) == OGB3_CAPACITY);
  CHECK(!failed && active_bytes == bytes && owned_live() == owners);
  ogb3_snapshot_test_pose_limit(OGB3_SNAPSHOT_BODY_CAPACITY);
  ogb3_snapshot *s, *clone;
  OK(ogb3_snapshot_capture(f.w, &s));
  OK(ogb3_snapshot_clone(s, &clone));
  ogb3_body_state expected;
  OK(ogb3_snapshot_body_state(s, bk, &expected));
  CHECK(expected.key == bk && expected.type == OGB3_DYNAMIC &&
        expected.is_enabled);
  ogb3_pose pose;
  OK(ogb3_body_get_pose(f.body, &pose));
  CHECK(!memcmp(&expected.pose, &pose, sizeof(pose)));
  uint64_t normalized, wrapper, native;
  OK(ogb3_snapshot_storage(s, &normalized, &wrapper, &native));
  CHECK(wrapper >= normalized + (uint64_t)counts.body_count * sizeof(expected));
  uint32_t required = 0;
  OK(ogb3_snapshot_body_states(s, NULL, 0, &required));
  CHECK(required == counts.body_count);
  ogb3_body_state array[22];
  memset(array, 0x5a, sizeof(array));
  ogb3_body_state sentinel[22];
  memcpy(sentinel, array, sizeof(array));
  CHECK(ogb3_snapshot_body_states(s, array, 21, &required) == OGB3_CAPACITY);
  CHECK(!memcmp(array, sentinel, sizeof(array)));
  OK(ogb3_snapshot_body_states(s, array, 22, &required));
  for (unsigned i = 1; i < required; i++)
    CHECK((uint32_t)array[i - 1].key < (uint32_t)array[i].key);
  ogb3_body_state rejected;
  memset(&rejected, 0x5a, sizeof(rejected));
  ogb3_body_state prior = rejected;
  CHECK(ogb3_snapshot_body_state(s, bk ^ (UINT64_C(1) << 32), &rejected) ==
        OGB3_INVALID_HANDLE);
  CHECK(!memcmp(&rejected, &prior, sizeof(prior)));
  uint64_t native_calls = allocations;
  ogb3_allocation_stats before, after;
  OK(ogb3_snapshot_allocation_stats(&before));
  int worlds = b3GetWorldCount();
  for (int i = 0; i < 100; i++)
    OK(ogb3_snapshot_body_state(s, bk, &rejected));
  OK(ogb3_snapshot_allocation_stats(&after));
  CHECK(before.total_calls == after.total_calls &&
        allocations == native_calls && worlds == b3GetWorldCount());
  OK(ogb3_world_destroy(f.w));
  ogb3_snapshot_release(s);
  OK(ogb3_snapshot_body_state(clone, bk, &rejected));
  CHECK(!memcmp(&expected, &rejected, sizeof(expected)));
  OK(ogb3_snapshot_restore(dest, clone));
  ogb3_body body;
  ogb3_shape shape;
  ogb3_joint joint;
  OK(ogb3_body_resolve(dest, bk, &body));
  OK(ogb3_shape_resolve(dest, sk, &shape));
  OK(ogb3_joint_resolve(dest, jk, &joint));
  CHECK(body != f.body && shape != f.shape && joint != f.joint);
  ogb3_body_key key;
  OK(ogb3_body_get_key(body, &key));
  CHECK(key == bk);
  OK(ogb3_body_get_pose(body, &pose));
  CHECK(!memcmp(&expected.pose, &pose, sizeof(pose)));
  ogb3_snapshot_release(clone);
  OK(ogb3_world_step_fixed(dest));
  OK(ogb3_body_destroy(body));
  CHECK(ogb3_body_resolve(dest, bk, &unchanged) == OGB3_INVALID_HANDLE);
  CHECK(ogb3_joint_resolve(dest, jk, &joint) == OGB3_INVALID_HANDLE);
  OK(ogb3_shape_destroy(shape));
  CHECK(ogb3_shape_resolve(dest, sk, &shape) == OGB3_INVALID_HANDLE);
  ogb3_shape_key decoded = 0;
  OK(ogb3_shape_key_from_handle(shape, &decoded));
  CHECK(decoded == sk);
  decoded = 99;
  CHECK(ogb3_shape_get_key(shape, &decoded) == OGB3_INVALID_HANDLE);
  CHECK(decoded == 99);
  CHECK(ogb3_shape_key_from_handle(0, &decoded) == OGB3_INVALID_ARGUMENT);
  CHECK(decoded == 99);
  OK(ogb3_world_destroy(dest));
  puts("allocation_keys_and_historical_states checked_body/shape/joint "
       "resolution source_destroy clone/cache/bulk/capacity "
       "no_scratch_or_allocating_reads PASS");
}
static uint64_t shape_event_key(b3ShapeId id) {
  return (uint32_t)id.index1 | ((uint64_t)id.generation << 32);
}
static uint64_t contact_event_key(b3ContactId id) {
  return (uint32_t)id.index1 | ((uint64_t)id.generation << 32);
}
static void equal_image_world(const ogb3_snapshot *s, ogb3_world world) {
  uint64_t expected_size, actual_size;
  OK(ogb3_snapshot_dump(s, NULL, 0, &expected_size));
  OK(ogb3_state_dump(world, NULL, 0, &actual_size));
  CHECK(expected_size == actual_size);
  uint8_t *expected = malloc(expected_size), *actual = malloc(actual_size);
  CHECK(expected && actual);
  OK(ogb3_snapshot_dump(s, expected, expected_size, &expected_size));
  OK(ogb3_state_dump(world, actual, actual_size, &actual_size));
  CHECK(!memcmp(expected, actual, actual_size));
  free(expected);
  free(actual);
}
static void pending_end_queues(void) {
  uint64_t initial_native = active_bytes, initial_owned = owned_live();
  ogb3_world source = world_new(), dest = world_new();
  OK(ogb3_world_set_gravity(source, &(ogb3_vec3){0}));
  ogb3_body_def bd;
  ogb3_shape_def sd;
  ogb3_body floor, sensor, visitor;
  ogb3_shape floor_shape, sensor_shape, visitor_shape;
  OK(ogb3_body_def_default(&bd));
  OK(ogb3_shape_def_default(&sd));
  sd.enable_contact_events = 1;
  bd.pose.position.y = -1;
  OK(ogb3_body_create(source, &bd, &floor));
  OK(ogb3_shape_box(floor, &sd, &(ogb3_vec3){5, 1, 5}, &floor_shape));
  bd.pose.position.y = .5f;
  OK(ogb3_body_create(source, &bd, &sensor));
  sd.is_sensor = sd.enable_sensor_events = 1;
  OK(ogb3_shape_box(sensor, &sd, &(ogb3_vec3){1, .5f, 1}, &sensor_shape));
  bd.type = OGB3_DYNAMIC;
  bd.enable_sleep = 0;
  bd.pose.position.y = .25f;
  OK(ogb3_body_create(source, &bd, &visitor));
  sd.is_sensor = 0;
  OK(ogb3_shape_sphere(visitor, &sd, &(ogb3_vec3){0}, .25f, &visitor_shape));
  OK(ogb3_world_step_fixed(source));
  b3World *w = b3GetWorldFromId(native_world(source));
  CHECK(b3World_GetSensorEvents(native_world(source)).beginCount == 1);
  CHECK(b3World_GetContactEvents(native_world(source)).beginCount == 1);
  OK(ogb3_body_destroy(sensor));
  OK(ogb3_body_destroy(visitor));
  int index = w->endEventArrayIndex;
  CHECK(w->sensorEndEvents[index].count == 1 &&
        w->contactEndEvents[index].count == 1);
  uint64_t complete = digest(source), motion = b3HashWorldState(w);
  w->sensorEndEvents[index].count = 0;
  CHECK(digest(source) != complete);
  CHECK(b3HashWorldState(w) == motion);
  w->sensorEndEvents[index].count = 1;
  b3SensorEndTouchEvent original = w->sensorEndEvents[index].data[0];
  w->sensorEndEvents[index].data[0].visitorShapeId.generation ^= 1;
  CHECK(digest(source) != complete);
  w->sensorEndEvents[index].data[0] = original;
  w->sensorEndEvents[index].data[1] = original;
  w->sensorEndEvents[index].data[1].visitorShapeId.generation ^= 1;
  w->sensorEndEvents[index].count = 2;
  uint64_t ordered = digest(source);
  w->sensorEndEvents[index].data[0] = w->sensorEndEvents[index].data[1];
  w->sensorEndEvents[index].data[1] = original;
  CHECK(digest(source) != ordered);
  w->sensorEndEvents[index].data[0] = original;
  w->sensorEndEvents[index].count = 1;
  CHECK(digest(source) == complete);
  w->contactEndEvents[index].data[0].contactId.generation ^=
      UINT32_C(0x80000000);
  CHECK(digest(source) != complete);
  /* Preserve all32 contact-generation bits while dropping host/padding. */
  w->contactEndEvents[index].data[0].contactId.padding = 7;
  uint64_t queued = digest(source);
  w->contactEndEvents[index].data[0].contactId.padding = 0;
  CHECK(digest(source) == queued);
  b3ContactEndTouchEvent expected_contact = w->contactEndEvents[index].data[0];
  uint64_t native_bytes = active_bytes, owned_bytes = owned_live();
  int worlds = b3GetWorldCount();
  ogb3_snapshot_test_pending_limit(0);
  ogb3_snapshot *capacity_failed = NULL;
  CHECK(ogb3_snapshot_capture(source, &capacity_failed) == OGB3_CAPACITY);
  CHECK(!capacity_failed);
  ogb3_snapshot_test_pending_limit(OGB3_SNAPSHOT_PENDING_END_CAPACITY);
  CHECK(active_bytes == native_bytes && owned_live() == owned_bytes &&
        digest(source) == queued);
  for (int64_t fail = 0; fail < 7; fail++) {
    ogb3_snapshot_test_fail_allocation_after(fail);
    ogb3_snapshot *failed = NULL;
    CHECK(ogb3_snapshot_capture(source, &failed) == OGB3_OUT_OF_MEMORY);
    CHECK(!failed);
    ogb3_snapshot_test_fail_allocation_after(-1);
    CHECK(digest(source) == queued);
    CHECK(active_bytes == native_bytes && owned_live() == owned_bytes &&
          b3GetWorldCount() == worlds);
  }
  ogb3_snapshot *s, *clone;
  OK(ogb3_snapshot_capture(source, &s));
  OK(ogb3_snapshot_clone(s, &clone));
  uint64_t dest_before = digest(dest);
  native_bytes = active_bytes;
  owned_bytes = owned_live();
  CHECK(ogb3_snapshot_test_pending_corrupt_restore(dest, s) == OGB3_CORRUPT);
  CHECK(digest(dest) == dest_before);
  CHECK(active_bytes == native_bytes && owned_live() == owned_bytes);
  ogb3_snapshot_test_fail_stage(3);
  CHECK(ogb3_snapshot_restore(dest, s) == OGB3_OUT_OF_MEMORY);
  ogb3_snapshot_test_fail_stage(0);
  CHECK(digest(dest) == dest_before);
  CHECK(active_bytes == native_bytes && owned_live() == owned_bytes &&
        b3GetWorldCount() == worlds);
  OK(ogb3_world_step_fixed(source));
  CHECK(b3World_GetSensorEvents(native_world(source)).endCount == 1);
  CHECK(b3World_GetContactEvents(native_world(source)).endCount == 1);
  OK(ogb3_snapshot_restore(source, s));
  equal_image_world(s, source);
  CHECK(b3World_GetSensorEvents(native_world(source)).endCount == 0);
  CHECK(b3World_GetContactEvents(native_world(source)).endCount == 0);
  OK(ogb3_snapshot_restore(source, s));
  equal_image_world(s, source);
  ogb3_body replacement =
      box(source, OGB3_DYNAMIC, 4, 4, 0, .2f, .2f, .2f, NULL);
  (void)replacement;
  ogb3_snapshot *spawned;
  OK(ogb3_snapshot_capture(source, &spawned));
  OK(ogb3_world_step_fixed(source));
  b3SensorEvents sensor_events = b3World_GetSensorEvents(native_world(source));
  b3ContactEvents contact_events =
      b3World_GetContactEvents(native_world(source));
  CHECK(sensor_events.endCount == 1 && contact_events.endCount == 1);
  CHECK(shape_event_key(sensor_events.endEvents[0].visitorShapeId) ==
        shape_event_key(original.visitorShapeId));
  CHECK(contact_event_key(contact_events.endEvents[0].contactId) ==
        contact_event_key(expected_contact.contactId));
  CHECK(!b3Shape_IsValid(sensor_events.endEvents[0].visitorShapeId));
  OK(ogb3_world_step_fixed(source));
  CHECK(b3World_GetSensorEvents(native_world(source)).endCount == 0 &&
        b3World_GetContactEvents(native_world(source)).endCount == 0);
  OK(ogb3_world_destroy(source));
  ogb3_snapshot_release(s);
  OK(ogb3_snapshot_restore(dest, clone));
  equal_image_world(clone, dest);
  CHECK(b3World_GetSensorEvents(native_world(dest)).endCount == 0 &&
        b3World_GetContactEvents(native_world(dest)).endCount == 0);
  box(dest, OGB3_DYNAMIC, 4, 4, 0, .2f, .2f, .2f, NULL);
  equal_image_world(spawned, dest);
  ogb3_snapshot_release(spawned);
  ogb3_snapshot_release(clone);
  OK(ogb3_world_step_fixed(dest));
  sensor_events = b3World_GetSensorEvents(native_world(dest));
  contact_events = b3World_GetContactEvents(native_world(dest));
  CHECK(sensor_events.endCount == 1 && contact_events.endCount == 1);
  uint16_t destination = native_world(dest).index1 - 1;
  CHECK(sensor_events.endEvents[0].sensorShapeId.world0 == destination &&
        sensor_events.endEvents[0].visitorShapeId.world0 == destination);
  CHECK(contact_events.endEvents[0].shapeIdA.world0 == destination &&
        contact_events.endEvents[0].shapeIdB.world0 == destination &&
        contact_events.endEvents[0].contactId.world0 == destination &&
        contact_events.endEvents[0].contactId.padding == 0);
  CHECK(shape_event_key(sensor_events.endEvents[0].sensorShapeId) ==
        shape_event_key(original.sensorShapeId));
  CHECK(shape_event_key(sensor_events.endEvents[0].visitorShapeId) ==
        shape_event_key(original.visitorShapeId));
  CHECK(contact_event_key(contact_events.endEvents[0].contactId) ==
        contact_event_key(expected_contact.contactId));
  CHECK(!b3Shape_IsValid(sensor_events.endEvents[0].visitorShapeId));
  OK(ogb3_world_step_fixed(dest));
  CHECK(b3World_GetSensorEvents(native_world(dest)).endCount == 0 &&
        b3World_GetContactEvents(native_world(dest)).endCount == 0);
  OK(ogb3_world_destroy(dest));
  CHECK(active_bytes == initial_native && owned_live() == initial_owned);
  puts("pending_end_queues sensor/contact post_step_destroy "
       "same/scratch/source_destroy clone next_step_once "
       "ID_generation/order/hash/seal/allocation_failure PASS");
}
static void geometry_lifetime(void) {
  ogb3_world w = world_new();
  b3WorldId nw = native_world(w);
  b3BodyDef bd = b3DefaultBodyDef();
  b3BodyId body = b3CreateBody(nw, &bd);
  b3ShapeDef sd = b3DefaultShapeDef();
  b3Vec3 vertices[] = {{-3, 0, -3}, {3, 0, -3}, {3, 0, 3}, {-3, 0, 3}};
  int32_t indices[] = {0, 2, 1, 0, 3, 2};
  uint8_t materials[] = {0, 0};
  b3MeshDef md = {0};
  md.vertices = vertices;
  md.vertexCount = 4;
  md.indices = indices;
  md.triangleCount = 2;
  md.materialIndices = materials;
  b3MeshData *m = b3CreateMesh(&md, NULL, 0);
  CHECK(m);
  b3CreateMeshShape(body, &sd, m, (b3Vec3){1, 1, 1});
  float heights[] = {0, 0, 0, 0};
  uint8_t hm[] = {0};
  b3HeightFieldDef hd = {0};
  hd.heights = heights;
  hd.materialIndices = hm;
  hd.countX = 2;
  hd.countZ = 2;
  hd.scale = (b3Vec3){1, 1, 1};
  hd.globalMinimumHeight = -1;
  hd.globalMaximumHeight = 1;
  b3HeightFieldData *h = b3CreateHeightField(&hd);
  CHECK(h);
  b3CreateHeightFieldShape(body, &sd, h);
  b3BoxHull bh = b3MakeBoxHull(.5f, .5f, .5f);
  b3CompoundHullDef ch = {0};
  ch.hull = &bh.base;
  ch.transform = b3Transform_identity;
  ch.material = b3DefaultSurfaceMaterial();
  b3CompoundDef cd = {0};
  cd.hulls = &ch;
  cd.hullCount = 1;
  b3CompoundData *c = b3CreateCompound(&cd);
  CHECK(c);
  b3CreateBakedCompoundShape(body, &sd, c);
  box(w, OGB3_DYNAMIC, 0, 5, 0, .4f, .4f, .4f, NULL);
  ogb3_snapshot *s, *clone;
  OK(ogb3_snapshot_capture(w, &s));
  OK(ogb3_snapshot_clone(s, &clone));
  uint64_t used, cap, bytes;
  uint32_t count;
  OK(ogb3_snapshot_metrics(s, &used, &cap, &bytes, &count));
  CHECK(count == 4);
  ogb3_world dest = world_new();
  OK(ogb3_snapshot_restore(dest, s));
  equal_worlds(w, dest);
  OK(ogb3_world_destroy(w));
  b3DestroyMesh(m);
  b3DestroyHeightField(h);
  b3DestroyCompound(c);
  ogb3_snapshot_release(s);
  OK(ogb3_snapshot_restore(dest, clone));
  ogb3_snapshot_release(clone);
  for (int i = 0; i < 120; i++)
    OK(ogb3_world_step_fixed(dest));
  OK(ogb3_world_destroy(dest));
  printf("geometry_lifetime hull/mesh/heightfield/compound retained_bytes=%llu "
         "clone/source_destroyed_before_step=1 PASS\n",
         (unsigned long long)bytes);
}
static void dump_contract(void) {
  ogb3_world w = world_new();
  box(w, OGB3_DYNAMIC, 0, 2, 0, .5f, .5f, .5f, NULL);
  uint64_t required = 0;
  OK(ogb3_state_dump(w, NULL, 0, &required));
  CHECK(required > 0);
  uint8_t *bytes = malloc(required);
  memset(bytes, 0xa5, required);
  uint64_t check = required;
  CHECK(ogb3_state_dump(w, bytes, required - 1, &check) == OGB3_CAPACITY);
  CHECK(check == required);
  for (uint64_t i = 0; i < required; i++)
    CHECK(bytes[i] == 0xa5);
  OK(ogb3_state_dump(w, bytes, required, &check));
  CHECK(check == required);
  ogb3_snapshot *s;
  OK(ogb3_snapshot_capture(w, &s));
  uint8_t *copy = malloc(required);
  OK(ogb3_snapshot_dump(s, copy, required, &check));
  CHECK(memcmp(bytes, copy, required) == 0);
  uint64_t dc, dm, sc, sm;
  OK(ogb3_state_digest(w, &dc, &dm));
  OK(ogb3_snapshot_digest(s, &sc, &sm));
  CHECK(dc == sc && dm == sm);
  free(bytes);
  free(copy);
  ogb3_snapshot_release(s);
  OK(ogb3_world_destroy(w));
  puts("dump_contract sizing/no_partial_write/snapshot_bytes_and_digests PASS");
}
int main(void) {
  setvbuf(stdout, NULL, _IONBF, 0);
  uint64_t invalid_required = 0;
  ogb3_snapshot *invalid_snapshot = NULL;
  CHECK(ogb3_state_dump(0, NULL, 0, &invalid_required) == OGB3_INVALID_HANDLE);
  CHECK(ogb3_state_dump(1, NULL, 0, &invalid_required) == OGB3_INVALID_HANDLE);
  CHECK(ogb3_snapshot_capture(0, &invalid_snapshot) == OGB3_INVALID_HANDLE);
  CHECK(ogb3_snapshot_capture(1, &invalid_snapshot) == OGB3_INVALID_HANDLE);
  CHECK(invalid_snapshot == NULL);
  /* A foreign bare-engine owner can saturate the domain before our first
   * initialization. Never run a fingerprint probe or change its allocator. */
  b3WorldId bare[B3_MAX_WORLDS];
  b3WorldDef bare_def = b3DefaultWorldDef();
  bare_def.workerCount = 1;
  for (int i = 0; i < B3_MAX_WORLDS; i++)
    bare[i] = b3CreateWorld(&bare_def);
  int bare_bytes = b3GetByteCount();
  CHECK(ogb3_build_fingerprint() == 0);
  uint32_t packed_bare;
  memcpy(&packed_bare, &bare[0], sizeof(packed_bare));
  CHECK(ogb3_snapshot_capture(packed_bare, &invalid_snapshot) == OGB3_CAPACITY);
  CHECK(invalid_snapshot == NULL);
  CHECK(b3GetByteCount() == bare_bytes);
  CHECK(owned_live() == 0);
  for (int i = 0; i < B3_MAX_WORLDS; i++)
    b3DestroyWorld(bare[i]);
  CHECK(b3GetByteCount() == 0);
  puts("bare_engine_full_domain "
       "first_fingerprint_zero/capture_capacity/no_allocator_takeover PASS");
  ogb3_world initialize = world_new();
  OK(ogb3_world_destroy(initialize));
  b3SetAllocator(alloc_fn, free_fn);
  block_allocator_alignment();
  broadphase_last_move_destroy();
  dump_contract();
  mutation_controls();
  rollback_lifecycle();
  failed_candidates();
  compound_alignment_cases();
  allocation_keys_and_historical_states();
  geometry_lifetime();
  pending_end_queues();
  CHECK(b3GetWorldCount() == 0);
  CHECK(active_bytes == 0);
  CHECK(owned_live() == 0);
  ogb3_allocation_stats owned;
  OK(ogb3_snapshot_allocation_stats(&owned));
  CHECK(owned.total_calls > 0 && owned.total_bytes > 0 &&
        owned.high_water_bytes > 0);
  printf("owned_wrapper_allocations calls=%llu total_bytes=%llu "
         "peak_bytes=%llu final_bytes=%llu PASS\n",
         (unsigned long long)owned.total_calls,
         (unsigned long long)owned.total_bytes,
         (unsigned long long)owned.high_water_bytes,
         (unsigned long long)owned.live_bytes);
  printf("{\"coverage\":\"%s\",\"version\":%u,\"allocations\":%llu,\"allocated_"
         "bytes\":%llu,\"peak_native_bytes\":%llu,\"final_native_bytes\":%llu,"
         "\"result\":\"PASS\"}\n",
         ogb3_state_coverage(), ogb3_state_version(),
         (unsigned long long)allocations, (unsigned long long)allocated_bytes,
         (unsigned long long)peak_bytes, (unsigned long long)active_bytes);
  return 0;
}
