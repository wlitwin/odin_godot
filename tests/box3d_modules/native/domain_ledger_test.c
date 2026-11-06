/* Native P4 support controls. This tests accounting, not an allocator hard cap.
 */
#include "api.h"
#include "owned_snapshot.h"
#include "state_dump.h"
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OK(x) assert((x) == OGB3_OK)
#define LIMIT OGB3_HOST_LIMIT_BYTES
static uint64_t cookie;
static unsigned controls;
static ogb3_host_ledger_stats stats(void) {
  ogb3_host_ledger_stats s;
  OK(ogb3_host_ledger_get(cookie, &s));
  assert(s.live_bytes ==
         s.engine_live_bytes + s.snapshot_live_bytes + s.host_live_bytes);
  assert(s.admitted_bytes == s.live_bytes + s.host_reserved_bytes);
  assert(s.limit_bytes == LIMIT &&
         s.owner_capacity == OGB3_HOST_OWNER_CAPACITY);
  ++controls;
  return s;
}
static void unchanged(ogb3_host_ledger_stats before) {
  ogb3_host_ledger_stats after = stats();
  assert(!memcmp(&before, &after, sizeof after));
}
static void failure(ogb3_status status, ogb3_status expected,
                    ogb3_host_ledger_stats before) {
  assert(status == expected);
  unchanged(before);
  ++controls;
}
static void check_layout(uint32_t type, uint32_t bytes, const uint32_t *fields,
                         uint32_t count) {
  uint32_t size, align, offset;
  OK(ogb3_abi_layout(type, UINT32_MAX, &size, &align, &offset));
  assert(size == bytes && align == 8 && offset == 0);
  for (uint32_t i = 0; i < count; ++i) {
    OK(ogb3_abi_layout(type, i, &size, &align, &offset));
    assert(size == bytes && align == 8 && offset == fields[i]);
  }
  size = 11;
  align = 22;
  offset = 33;
  assert(ogb3_abi_layout(type, count, &size, &align, &offset) ==
         OGB3_INVALID_ARGUMENT);
  assert(size == 11 && align == 22 && offset == 33);
  ++controls;
}
static uint8_t *dump(ogb3_world w, uint64_t *size) {
  OK(ogb3_state_dump(w, NULL, 0, size));
  uint8_t *p = malloc(*size);
  assert(p);
  OK(ogb3_state_dump(w, p, *size, size));
  return p;
}
int main(void) {
  ogb3_allocation_stats engine0, wrapper0, engine1, wrapper1;
  OK(ogb3_engine_allocation_stats(&engine0));
  OK(ogb3_snapshot_allocation_stats(&wrapper0));
  assert(!engine0.total_calls && !wrapper0.total_calls);
  ogb3_domain_contract c, same;
  OK(ogb3_domain_contract_get(&c));
  cookie = c.cookie;
  assert(cookie && c.size == sizeof c && c.version == 1 && c.abi_version == 2 &&
         c.logical_version == OGB3_STATE_DUMP_VERSION && c.resource_version == 2 &&
         c.recovery_version == 1 && c.pointer_bits == 8 * sizeof(void *) &&
         c.endian == 1);
  uint8_t bits = 0, target_bits = 0;
  for (unsigned i = 0; i < 32; ++i) {
    bits |= c.build[i];
    target_bits |= c.target[i];
  }
  assert(bits && target_bits);
  OK(ogb3_domain_contract_get(&same));
  assert(!memcmp(&c, &same, sizeof c));
  OK(ogb3_domain_contract_check(&c));
  assert(ogb3_domain_contract_get(NULL) == OGB3_INVALID_ARGUMENT);
  assert(ogb3_domain_contract_check(NULL) == OGB3_INVALID_ARGUMENT);
  for (unsigned i = 0; i < sizeof c; ++i) {
    ogb3_domain_contract changed = c;
    ((uint8_t *)&changed)[i] ^= 1;
    assert(ogb3_domain_contract_check(&changed) == OGB3_INCOMPATIBLE);
  }
  const uint32_t co[] = {0, 8, 12, 16, 20, 24, 28, 32, 36, 40, 72};
  const uint32_t oo[] = {0, 8, 16, 24};
  const uint32_t so[] = {0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 84};
  check_layout(OGB3_T_DOMAIN_CONTRACT, 104, co, 11);
  check_layout(OGB3_T_HOST_OWNER_INFO, 32, oo, 4);
  check_layout(OGB3_T_HOST_LEDGER_STATS, 88, so, 12);
  ogb3_host_ledger_stats zero = stats();
  assert(!zero.owner_count && !zero.live_bytes && !zero.admitted_bytes);
  assert(zero.ledger_storage_bytes >= 256 * 40);
  ogb3_host_owner a = 0, b = 0, out = 123;
  OK(ogb3_host_owner_open(cookie, 11, 1, &a));
  OK(ogb3_host_owner_open(cookie, 22, 1, &b));
  assert(a && b && a != b);
  ogb3_host_ledger_stats before = stats();
  failure(ogb3_host_owner_open(cookie, 11, 1, &out), OGB3_INVALID_ARGUMENT,
          before);
  assert(out == 123);
  failure(ogb3_host_owner_open(cookie, 0, 2, &out), OGB3_INVALID_ARGUMENT,
          before);
  failure(ogb3_host_owner_open(cookie, 11, 0, &out), OGB3_INVALID_ARGUMENT,
          before);
  failure(ogb3_host_owner_open(cookie, 11, 2, NULL), OGB3_INVALID_ARGUMENT,
          before);
  failure(ogb3_host_owner_open(cookie ^ 1, 11, 2, &out), OGB3_INCOMPATIBLE,
          before);
  failure(ogb3_host_owner_set(cookie ^ 1, a, 1, 2), OGB3_INCOMPATIBLE, before);
  failure(ogb3_host_owner_close(cookie ^ 1, a), OGB3_INCOMPATIBLE, before);
  ogb3_host_owner_info info, sentinel;
  memset(&sentinel, 0xab, sizeof sentinel);
  info = sentinel;
  assert(ogb3_host_owner_get(cookie ^ 1, a, &info) == OGB3_INCOMPATIBLE);
  assert(!memcmp(&info, &sentinel, sizeof info));
  ogb3_host_ledger_stats poisoned;
  memset(&poisoned, 0xab, sizeof poisoned);
  ogb3_host_ledger_stats untouched = poisoned;
  assert(ogb3_host_ledger_get(cookie ^ 1, &poisoned) == OGB3_INCOMPATIBLE);
  assert(!memcmp(&poisoned, &untouched, sizeof poisoned));
  const uint64_t bad[] = {0,
                          UINT64_MAX,
                          UINT64_C(1) << 32,
                          1,
                          a ^ (UINT64_C(1) << 32),
                          (UINT64_C(1) << 32) | (OGB3_HOST_OWNER_CAPACITY + 1)};
  for (unsigned i = 0; i < sizeof bad / sizeof *bad; ++i) {
    failure(ogb3_host_owner_set(cookie, bad[i], 1, 2), OGB3_INVALID_HANDLE,
            before);
    failure(ogb3_host_owner_close(cookie, bad[i]), OGB3_INVALID_HANDLE, before);
    info = sentinel;
    assert(ogb3_host_owner_get(cookie, bad[i], &info) == OGB3_INVALID_HANDLE);
    assert(!memcmp(&info, &sentinel, sizeof info));
  }
  uint64_t required = 777;
  failure(ogb3_host_memory_check(cookie, 0, 1, 0, 0, 0, &required),
          OGB3_INVALID_ARGUMENT, before);
  assert(required == 777);
  failure(ogb3_host_memory_check(cookie, a, 0, 0, 0, 0, NULL),
          OGB3_INVALID_ARGUMENT, before);
  OK(ogb3_host_owner_set(cookie, a, 16 * 1024 * 1024, 8 * 1024 * 1024));
  OK(ogb3_host_owner_set(cookie, b, 32 * 1024 * 1024, 8 * 1024 * 1024));
  before = stats();
  assert(before.admitted_bytes == LIMIT &&
         before.host_live_bytes == 48 * 1024 * 1024 &&
         before.host_reserved_bytes == 16 * 1024 * 1024);
  OK(ogb3_host_memory_check(cookie, 0, 0, 0, 0, 0, &required));
  assert(required == LIMIT);
  unchanged(before);
  required = 777;
  failure(ogb3_host_memory_check(cookie, 0, 0, 0, 1, 0, &required),
          OGB3_CAPACITY, before);
  failure(ogb3_host_memory_check(cookie, 0, 0, 0, 0, 1, &required),
          OGB3_CAPACITY, before);
  failure(ogb3_host_memory_check(cookie, a, 0, 0, UINT64_MAX, 1, &required),
          OGB3_CAPACITY, before);
  assert(required == 777);
  failure(ogb3_host_owner_set(cookie, a, 16 * 1024 * 1024 + 1, 8 * 1024 * 1024),
          OGB3_CAPACITY, before);
  failure(ogb3_host_owner_set(cookie, a, UINT64_MAX, 1), OGB3_CAPACITY, before);
  /* One atomic reservation->owned conversion; no double charging own token. */
  OK(ogb3_host_memory_check(cookie, a, 24 * 1024 * 1024, 0, 0, 0, &required));
  assert(required == LIMIT);
  unchanged(before);
  OK(ogb3_host_owner_set(cookie, a, 24 * 1024 * 1024, 0));
  assert(stats().admitted_bytes == LIMIT);
  OK(ogb3_host_owner_get(cookie, a, &info));
  assert(info.producer == 11 && info.component == 1 &&
         info.live_bytes == 24 * 1024 * 1024 && !info.reserved_bytes);
  OK(ogb3_host_owner_close(cookie, a));
  before = stats();
  failure(ogb3_host_owner_close(cookie, a), OGB3_INVALID_HANDLE, before);
  OK(ogb3_host_owner_open(cookie, 11, 1, &out));
  assert(out != a);
  before = stats();
  failure(ogb3_host_owner_set(cookie, a, 1, 2), OGB3_INVALID_HANDLE, before);
  OK(ogb3_host_owner_close(cookie, out));
  OK(ogb3_host_owner_close(cookie, b));
  ogb3_host_owner slots[OGB3_HOST_OWNER_CAPACITY];
  for (unsigned i = 0; i < OGB3_HOST_OWNER_CAPACITY; ++i)
    OK(ogb3_host_owner_open(cookie, 1, i + 1, &slots[i]));
  before = stats();
  out = 123;
  assert(before.owner_count == OGB3_HOST_OWNER_CAPACITY);
  failure(ogb3_host_owner_open(cookie, 2, 1, &out), OGB3_CAPACITY, before);
  assert(out == 123);
  for (unsigned i = 0; i < OGB3_HOST_OWNER_CAPACITY; ++i)
    OK(ogb3_host_owner_close(cookie, slots[i]));
  assert(!stats().admitted_bytes);
  /* Metadata and every ledger test so far have not initialized/allocated. */
  OK(ogb3_engine_allocation_stats(&engine1));
  OK(ogb3_snapshot_allocation_stats(&wrapper1));
  assert(!memcmp(&engine0, &engine1, sizeof engine0));
  assert(!memcmp(&wrapper0, &wrapper1, sizeof wrapper0));

  ogb3_world_def wd;
  ogb3_world w;
  OK(ogb3_world_def_default(&wd));
  OK(ogb3_world_create(&wd, &w));
  ogb3_body_def bd;
  ogb3_body body;
  OK(ogb3_body_def_default(&bd));
  bd.type = OGB3_DYNAMIC;
  OK(ogb3_body_create(w, &bd, &body));
  ogb3_shape_def sd;
  ogb3_shape shape;
  ogb3_vec3 half = {.5f, .5f, .5f};
  OK(ogb3_shape_def_default(&sd));
  OK(ogb3_shape_box(body, &sd, &half, &shape));
  OK(ogb3_world_step_fixed(w));
  ogb3_snapshot *image;
  OK(ogb3_snapshot_capture(w, &image));
  OK(ogb3_host_owner_open(cookie, 11, 1, &a));
  OK(ogb3_host_owner_open(cookie, 22, 1, &b));
  OK(ogb3_host_owner_set(cookie, a, 1000, 3000));
  OK(ogb3_host_owner_set(cookie, b, 2000, 4000));
  before = stats();
  OK(ogb3_engine_allocation_stats(&engine0));
  OK(ogb3_snapshot_allocation_stats(&wrapper0));
  assert(before.engine_live_bytes == engine0.live_bytes &&
         before.snapshot_live_bytes == wrapper0.live_bytes);
  assert(before.engine_live_bytes && before.snapshot_live_bytes);
  assert(before.admitted_bytes ==
         engine0.live_bytes + wrapper0.live_bytes + 10000);
  uint64_t n0, n1;
  uint8_t *d0 = dump(w, &n0);
  failure(ogb3_host_owner_set(cookie, a, LIMIT, 1), OGB3_CAPACITY, before);
  OK(ogb3_host_memory_check(cookie, a, 1000, 3000, 123, 456, &required));
  assert(required == before.admitted_bytes + 579);
  uint8_t *d1 = dump(w, &n1);
  assert(n0 == n1 && !memcmp(d0, d1, n0));
  free(d0);
  free(d1);
  OK(ogb3_engine_allocation_stats(&engine1));
  OK(ogb3_snapshot_allocation_stats(&wrapper1));
  assert(!memcmp(&engine0, &engine1, sizeof engine0));
  assert(!memcmp(&wrapper0, &wrapper1, sizeof wrapper0));
  OK(ogb3_world_destroy(w));
  assert(stats().snapshot_live_bytes && stats().engine_live_bytes);
  ogb3_snapshot_release(image);
  OK(ogb3_host_owner_close(cookie, a));
  OK(ogb3_host_owner_close(cookie, b));
  assert(!stats().live_bytes);
  /* Existing unchecked native APIs can exceed admission; shrinking/closing a
   * host charge must still work so cleanup never requires more allocation. */
  OK(ogb3_host_owner_open(cookie, 11, 1, &a));
  OK(ogb3_host_owner_set(cookie, a, LIMIT, 0));
  OK(ogb3_world_create(&wd, &w));
  assert(stats().admitted_bytes > LIMIT);
  OK(ogb3_host_owner_set(cookie, a, LIMIT - 1, 0));
  before = stats();
  assert(before.admitted_bytes > LIMIT);
  failure(ogb3_host_owner_set(cookie, a, LIMIT, 0), OGB3_CAPACITY, before);
  OK(ogb3_host_owner_close(cookie, a));
  OK(ogb3_world_destroy(w));
  ogb3_host_ledger_stats final = stats();
  assert(!final.owner_count && !final.host_live_bytes &&
         !final.host_reserved_bytes && !final.engine_live_bytes &&
         !final.snapshot_live_bytes && !final.admitted_bytes);
  printf("domain ledger PASS controls=%u owner_capacity=%u "
         "static_overhead_bytes=%llu updates=%llu\n",
         controls, final.owner_capacity,
         (unsigned long long) final.ledger_storage_bytes,
         (unsigned long long) final.successful_updates);
  return 0;
}
