/* Production archive control and bounded scalar/SIMD comparison. This measures
 * the named C composite, not the Odin adapter or Godot/browser rendering. */
#include "api.h"
#include "authoring_catalog.h"
#include "owned_snapshot.h"
#include "recovery_codec.h"
#include "state_dump.h"
#include <assert.h>
#include <emscripten/emscripten.h>
#include <emscripten/heap.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OK(call) do { ogb3_status status_ = (call); if (status_) { \
  fprintf(stderr, "status%d line%d\n", status_, __LINE__); abort(); } } while (0)

static ogb3_world new_world(void) {
  ogb3_world_def definition; ogb3_world world = 0;
  OK(ogb3_world_def_default(&definition)); definition.enable_sleep = 0;
  OK(ogb3_world_create(&definition, &world)); return world;
}

static ogb3_body box(ogb3_world world, int type, ogb3_vec3 position, ogb3_vec3 half) {
  ogb3_body_def body; ogb3_body handle = 0;
  OK(ogb3_body_def_default(&body)); body.type = type;
  body.pose.position = position; body.enable_sleep = 0;
  OK(ogb3_body_create(world, &body, &handle));
  ogb3_shape_def shape; ogb3_shape out = 0;
  OK(ogb3_shape_def_default(&shape)); OK(ogb3_shape_box(handle, &shape, &half, &out));
  return handle;
}

static void equal(ogb3_world a, ogb3_world b) {
  uint64_t n = 0, m = 0;
  OK(ogb3_state_dump(a, NULL, 0, &n)); OK(ogb3_state_dump(b, NULL, 0, &m));
  assert(n == m); uint8_t *x = malloc(n), *y = malloc(m); assert(x && y);
  OK(ogb3_state_dump(a, x, n, &n)); OK(ogb3_state_dump(b, y, m, &m));
  assert(!memcmp(x, y, n)); free(x); free(y);
}

int main(void) {
  ogb3_domain_contract domain; OK(ogb3_domain_contract_get(&domain));
  assert(domain.pointer_bits == 32 && domain.logical_version == 4 && domain.cookie);
  uint32_t size = 0, alignment = 0, offset = 0;
  OK(ogb3_authoring_asset_layout(3, &size, &alignment, &offset));
  assert(size == sizeof(ogb3_recovery_asset_v2));
  assert(alignment == _Alignof(ogb3_recovery_asset_v2));
  double resolution = 1e9;
  for (unsigned i = 0; i < 4096; ++i) {
    double before = emscripten_get_now(), after = emscripten_get_now();
    if (after > before && after - before < resolution) resolution = after - before;
  }
  ogb3_world source = new_world(); ogb3_body bodies[20];
  box(source, OGB3_STATIC, (ogb3_vec3){0, -.5f, 0}, (ogb3_vec3){8, .5f, 8});
  for (unsigned i = 0; i < 20; ++i)
    bodies[i] = box(source, OGB3_DYNAMIC,
      (ogb3_vec3){((int)(i % 4) - 2) * 1.05f, .5f + (i / 4 % 2) * 1.05f,
                  ((int)(i / 8) - 1) * 1.1f}, (ogb3_vec3){.5f, .5f, .5f});
  ogb3_recovery_config config; OK(ogb3_recovery_config_default(&config));
  ogb3_recovery_asset assets[] = {
    {.id=1, .kind=OGB3_RECOVERY_BOX, .a={8,.5f,8}},
    {.id=2, .kind=OGB3_RECOVERY_BOX, .a={.5f,.5f,.5f}}
  };
  ogb3_recovery_catalog *catalog = NULL;
  OK(ogb3_recovery_catalog_create(&config, assets, 2, &catalog));
  ogb3_snapshot *history[8] = {0};
  uint64_t required = 0;
  for (unsigned tick = 0; tick < 256; ++tick) {
    double begin = emscripten_get_now();
    if (tick % 17 == 0) {
      ogb3_vec3 impulse = {.03f, .01f, -.02f};
      OK(ogb3_body_apply_impulse(bodies[tick % 20], &impulse, NULL, 1));
    }
    OK(ogb3_world_step_fixed(source));
    ogb3_snapshot_release(history[tick % 8]); history[tick % 8] = NULL;
    OK(ogb3_snapshot_capture(source, &history[tick % 8]));
    OK(ogb3_recovery_world_admit(catalog, source, 0, &required, NULL));
    double elapsed = emscripten_get_now() - begin;
    printf("WASM_BACKEND_SAMPLE {\"sequence\":%u,\"milliseconds\":%.9f}\n", tick, elapsed);
  }
  ogb3_snapshot *saved = history[7], *decoded = NULL; uint64_t n = 0;
  OK(ogb3_recovery_write(catalog, saved, NULL, 0, &n, NULL));
  assert(n && n <= OGB3_RECOVERY_MAX_BYTES && n == required);
  uint8_t *bytes = malloc(n), *again = malloc(n); assert(bytes && again);
  OK(ogb3_recovery_write(catalog, saved, bytes, n, &n, NULL));
  uint64_t digest_before, motion_before, digest_after, motion_after;
  OK(ogb3_state_digest(source, &digest_before, &motion_before));
  ogb3_snapshot *rejected = (void *)(uintptr_t)1;
  assert(ogb3_recovery_read(catalog, bytes, n - 1, 0, &rejected, NULL) != OGB3_OK && !rejected);
  bytes[0] ^= 1; rejected = (void *)(uintptr_t)1;
  assert(ogb3_recovery_read(catalog, bytes, n, 0, &rejected, NULL) != OGB3_OK && !rejected);
  bytes[0] ^= 1;
  OK(ogb3_state_digest(source, &digest_after, &motion_after));
  assert(digest_before == digest_after && motion_before == motion_after);
  OK(ogb3_recovery_read(catalog, bytes, n, 0, &decoded, NULL));
  uint64_t m = 0; OK(ogb3_recovery_write(catalog, decoded, again, n, &m, NULL));
  assert(n == m && !memcmp(bytes, again, n));
  OK(ogb3_world_destroy(source));
  ogb3_world a = new_world(), b = new_world();
  OK(ogb3_snapshot_restore(a, saved)); OK(ogb3_snapshot_restore(b, decoded)); equal(a, b);
  for (unsigned i = 0; i < 8; ++i) ogb3_snapshot_release(history[i]);
  ogb3_snapshot_release(decoded); ogb3_recovery_catalog_release(catalog);
  for (unsigned i = 0; i < 32; ++i) {
    OK(ogb3_world_step_fixed(a)); OK(ogb3_world_step_fixed(b)); equal(a, b);
  }
  OK(ogb3_world_destroy(a)); OK(ogb3_world_destroy(b)); free(bytes); free(again);
  ogb3_allocation_stats native, wrapper;
  OK(ogb3_engine_allocation_stats(&native)); OK(ogb3_snapshot_allocation_stats(&wrapper));
  assert(!native.live_bytes && !wrapper.live_bytes);
  printf("WASM_BACKEND_RESULT {\"ok\":true,\"pointer_bits\":32,\"asset_size\":%u,"
         "\"asset_alignment\":%u,\"samples\":256,\"bodies\":21,\"canonical_bytes\":%llu,"
         "\"source_free_steps\":32,\"native_live\":0,\"wrapper_live\":0,"
         "\"timer_min_positive_ms\":%.9f,\"native_peak\":%llu,\"wrapper_peak\":%llu,"
         "\"wasm_linear_memory_bytes\":%u}\n",
         size, alignment, (unsigned long long)n, resolution,
         (unsigned long long)native.high_water_bytes, (unsigned long long)wrapper.high_water_bytes,
         (unsigned)emscripten_get_heap_size());
  return 0;
}
