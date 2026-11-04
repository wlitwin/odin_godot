#include "authoring_catalog.h"
#include "state_dump.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OK(call) do { ogb3_status s_ = (call); if (s_) { \
  fprintf(stderr, "status=%d line=%d\n", s_, __LINE__); abort(); \
} } while (0)

typedef struct { uint8_t *data; uint64_t size; } Bytes;
typedef struct { uint64_t native, wrapper; } Live;

static Live live(void) {
  ogb3_allocation_stats native, wrapper;
  OK(ogb3_engine_allocation_stats(&native));
  OK(ogb3_snapshot_allocation_stats(&wrapper));
  return (Live){native.live_bytes, wrapper.live_bytes};
}
static void same_live(Live expected) {
  Live actual = live();
  assert(actual.native == expected.native && actual.wrapper == expected.wrapper);
}
static ogb3_world world(void) {
  ogb3_world_def d;
  OK(ogb3_world_def_default(&d));
  d.gravity = (ogb3_vec3){0}; d.enable_sleep = 0;
  ogb3_world w = 0;
  OK(ogb3_world_create(&d, &w));
  return w;
}
static ogb3_body body(ogb3_world w, float x) {
  ogb3_body_def d;
  OK(ogb3_body_def_default(&d));
  d.type = OGB3_STATIC; d.pose.position.x = x; d.enable_sleep = 0;
  ogb3_body out = 0;
  OK(ogb3_body_create(w, &d, &out));
  assert(out);
  return out;
}
static ogb3_shape shape(const ogb3_recovery_catalog *catalog, ogb3_body owner) {
  ogb3_shape_def d;
  OK(ogb3_shape_def_default(&d));
  ogb3_shape out = 0;
  OK(ogb3_recovery_catalog_shape(catalog, 1, owner, &d, &out));
  assert(out);
  return out;
}
static void counts(ogb3_world w, uint32_t bodies, uint32_t shapes) {
  ogb3_world_counters c;
  OK(ogb3_world_get_counters(w, &c));
  assert(c.body_count == bodies && c.shape_count == shapes);
}
static Bytes dump(ogb3_world w) {
  Bytes out = {0};
  OK(ogb3_state_dump(w, NULL, 0, &out.size));
  assert(out.size && out.size <= SIZE_MAX);
  out.data = malloc((size_t)out.size); assert(out.data);
  OK(ogb3_state_dump(w, out.data, out.size, &out.size));
  return out;
}
static void unchanged(ogb3_world w, Bytes expected) {
  Bytes actual = dump(w);
  assert(actual.size == expected.size);
  assert(!memcmp(actual.data, expected.data, (size_t)actual.size));
  free(actual.data);
}
static void equal(ogb3_world a, ogb3_world b) {
  Bytes expected = dump(a); unchanged(b, expected); free(expected.data);
}
static Bytes encode(const ogb3_recovery_catalog *catalog, const ogb3_snapshot *image) {
  Bytes out = {0};
  OK(ogb3_recovery_write(catalog, image, NULL, 0, &out.size, NULL));
  assert(out.size && out.size <= OGB3_RECOVERY_MAX_BYTES);
  out.data = malloc((size_t)out.size); assert(out.data);
  uint64_t written = 0;
  OK(ogb3_recovery_write(catalog, image, out.data, out.size, &written, NULL));
  assert(written == out.size);
  return out;
}
static ogb3_snapshot *decode(const ogb3_recovery_catalog *catalog, Bytes bytes) {
  ogb3_snapshot *out = NULL;
  OK(ogb3_recovery_read(catalog, bytes.data, bytes.size, 0, &out, NULL));
  assert(out);
  Bytes again = encode(catalog, out);
  assert(again.size == bytes.size && !memcmp(again.data, bytes.data, (size_t)bytes.size));
  free(again.data);
  return out;
}

/* TEST CALLER COMPOSITION, not a new backend API or raw-capture limit. A caller
 * obtains an owned candidate only after the public precommit admission passes.
 * No existing/published world is restored or changed by this helper. */
static ogb3_status admitted_capture(const ogb3_recovery_catalog *catalog,
                                   ogb3_world candidate, ogb3_snapshot **out,
                                   uint64_t *required) {
  *out = NULL;
  ogb3_status status = ogb3_recovery_world_admit(catalog, candidate, 0, required, NULL);
  if (status) return status;
  return ogb3_snapshot_capture(candidate, out);
}

/* Two isolated groups: bodies=35->36 with shapes still35; shapes=35->36 with
 * bodies still1. These are actual trusted mutations of a detached candidate.
 * Preservation is measured AFTER that mutation and against a separate world. */
static void profile_edge(int shape_edge) {
  Live baseline = live();
  ogb3_recovery_config config;
  OK(ogb3_recovery_config_default(&config));
  assert(config.max_bodies == 35 && config.max_shapes == 35);
  ogb3_recovery_asset_v2 asset = {
    .version = OGB3_AUTHORING_ASSET_VERSION, .struct_bytes = sizeof(asset),
    .base = {.id = 1, .kind = OGB3_RECOVERY_BOX, .a = {.25f, .25f, .25f}}
  };
  ogb3_recovery_catalog *catalog = NULL;
  OK(ogb3_recovery_catalog_create_v3(&config, &asset, 1, &catalog));
  ogb3_recovery_identity identity;
  OK(ogb3_recovery_identity_get(catalog, &identity));
  assert(identity.recovery_format == 3);
  ogb3_world candidate = world(), published = world();
  ogb3_body sole = 0;
  for (unsigned i = 0; i < 35; ++i) {
    ogb3_body owner;
    if (shape_edge) {
      if (!sole) sole = body(candidate, 0);
      owner = sole;
    } else owner = body(candidate, 2.0f * i);
    (void)shape(catalog, owner);
  }
  OK(ogb3_world_step_fixed(candidate));
  counts(candidate, shape_edge ? 1 : 35, 35);
  uint64_t required = 0;
  ogb3_snapshot *valid = NULL;
  OK(admitted_capture(catalog, candidate, &valid, &required));
  assert(valid && required);
  Bytes valid_wire = encode(catalog, valid);
  assert(valid_wire.size == required);
  ogb3_snapshot *decoded = decode(catalog, valid_wire);
  OK(ogb3_snapshot_restore(published, decoded));
  equal(candidate, published);
  Bytes published_before = dump(published);

  ogb3_body extra_body = 0; ogb3_shape extra_shape = 0;
  if (shape_edge) extra_shape = shape(catalog, sole);
  else extra_body = body(candidate, 70);
  counts(candidate, shape_edge ? 1 : 36, shape_edge ? 36 : 35);
  Bytes mutated_before = dump(candidate);
  Live before_refusal = live();
  ogb3_snapshot *refused = (ogb3_snapshot *)(uintptr_t)1;
  required = UINT64_MAX;
  assert(admitted_capture(catalog, candidate, &refused, &required) == OGB3_CAPACITY);
  assert(!refused && required == 0);
  same_live(before_refusal);
  unchanged(candidate, mutated_before); unchanged(published, published_before);

  /* Raw capture is intentionally allowed. It is NOT the profile boundary.
   * Canonical export of this real over-cap image must refuse before emitting
   * any bytes; no fake36-count wire or private decoder/parser is used. */
  ogb3_snapshot *raw = NULL;
  OK(ogb3_snapshot_capture(candidate, &raw)); assert(raw);
  uint8_t *output = malloc(OGB3_RECOVERY_MAX_BYTES); assert(output);
  memset(output, 0xa5, OGB3_RECOVERY_MAX_BYTES);
  before_refusal = live(); required = 0;
  assert(ogb3_recovery_write(catalog, raw, NULL, 0, &required, NULL) == OGB3_CAPACITY);
  same_live(before_refusal);
  assert(ogb3_recovery_write(catalog, raw, output, OGB3_RECOVERY_MAX_BYTES,
                           &required, NULL) == OGB3_CAPACITY);
  for (size_t i = 0; i < OGB3_RECOVERY_MAX_BYTES; ++i) assert(output[i] == 0xa5);
  same_live(before_refusal);
  unchanged(candidate, mutated_before); unchanged(published, published_before);
  Bytes old_again = encode(catalog, decoded);
  assert(old_again.size == valid_wire.size &&
         !memcmp(old_again.data, valid_wire.data, (size_t)valid_wire.size));
  free(old_again.data); free(output); ogb3_snapshot_release(raw);
  free(mutated_before.data);

  /* Remove ONLY the intentional extra and prove normal valid admission,
   * canonical reconstruction, publication and continuation still work. Pool
   * capacity may legitimately remain grown; no false high-water==live oracle. */
  if (shape_edge) OK(ogb3_shape_destroy(extra_shape));
  else OK(ogb3_body_destroy(extra_body));
  OK(ogb3_world_step_fixed(candidate));
  counts(candidate, shape_edge ? 1 : 35, 35);
  ogb3_snapshot *resumed = NULL; required = 0;
  OK(admitted_capture(catalog, candidate, &resumed, &required));
  assert(resumed && required);
  Bytes resumed_wire = encode(catalog, resumed);
  ogb3_snapshot *recovered = decode(catalog, resumed_wire);
  OK(ogb3_snapshot_restore(published, recovered));
  equal(candidate, published);
  OK(ogb3_world_step_fixed(candidate)); OK(ogb3_world_step_fixed(published));
  equal(candidate, published);

  free(resumed_wire.data); free(valid_wire.data); free(published_before.data);
  ogb3_snapshot_release(recovered); ogb3_snapshot_release(resumed);
  ogb3_snapshot_release(decoded); ogb3_snapshot_release(valid);
  OK(ogb3_world_destroy(published)); OK(ogb3_world_destroy(candidate));
  ogb3_recovery_catalog_release(catalog);
  same_live(baseline);
  printf("BOUNDS_NATIVE group=%s edge35=valid candidate36=Capacity owned_publication=empty "
         "raw_factory=trusted published_solver=unchanged canonical_resume=valid cleanup=balanced\n",
         shape_edge ? "shapes" : "bodies");
}

int main(void) {
  assert(ogb3_build_fingerprint());
  Live baseline = live();
  profile_edge(0); profile_edge(1);
  same_live(baseline);
  assert(!baseline.native && !baseline.wrapper);
  puts("Native profile edges: two groups PASS; solver-only, not SDK/full5/CPU evidence");
  return 0;
}
