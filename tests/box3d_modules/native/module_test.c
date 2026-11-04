#include "api.h"
#include <assert.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#define OK(x) assert((x) == OGB3_OK)
typedef struct {
  void *handle;
  ogb3_status (*contract)(ogb3_domain_contract *);
  ogb3_status (*open)(uint64_t, uint64_t, uint64_t, ogb3_host_owner *);
  ogb3_status (*set)(uint64_t, ogb3_host_owner, uint64_t, uint64_t);
  ogb3_status (*close)(uint64_t, ogb3_host_owner);
  ogb3_status (*stats)(uint64_t, ogb3_host_ledger_stats *);
  ogb3_status (*check)(const ogb3_domain_contract *);
} producer;
static producer load(const char *path) {
  producer p = {0};
  p.handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
  if (!p.handle)
    fprintf(stderr, "dlopen %s: %s\n", path, dlerror());
  assert(p.handle);
#define LOAD(field, name)                                                      \
  do {                                                                         \
    void *symbol = dlsym(p.handle, name);                                      \
    assert(symbol && sizeof symbol == sizeof p.field);                         \
    memcpy(&p.field, &symbol, sizeof symbol);                                  \
  } while (0)
  LOAD(contract, "producer_contract");
  LOAD(open, "producer_open");
  LOAD(set, "producer_set");
  LOAD(close, "producer_close");
  LOAD(stats, "producer_stats");
  LOAD(check, "producer_check");
#undef LOAD
  return p;
}
int main(int argc, char **argv) {
  assert(argc == 4);
  producer a = load(argv[1]), b = load(argv[2]), duplicate = load(argv[3]);
  ogb3_domain_contract ca, cb, cd;
  OK(a.contract(&ca));
  OK(b.contract(&cb));
  OK(duplicate.contract(&cd));
  assert(!memcmp(&ca, &cb, sizeof ca));
  assert(ca.cookie && cd.cookie && ca.cookie != cd.cookie);
  /* Same-source/static builds can have an identical build hash; the actual
   * loaded-image cookie still rejects it. Never touch foreign world pointers.
   */
  assert(!memcmp(ca.build, cd.build, 32) && !memcmp(ca.target, cd.target, 32));
  assert(a.check(&cd) == OGB3_INCOMPATIBLE);
  assert(duplicate.check(&ca) == OGB3_INCOMPATIBLE);
  OK(a.check(&cb));
  ogb3_host_owner oa, ob;
  OK(a.open(ca.cookie, 101, 1, &oa));
  OK(b.open(cb.cookie, 202, 1, &ob));
  OK(a.set(ca.cookie, oa, 16 * 1024 * 1024, 8 * 1024 * 1024));
  OK(b.set(cb.cookie, ob, 32 * 1024 * 1024, 8 * 1024 * 1024));
  ogb3_host_ledger_stats sa, sb, sd;
  OK(a.stats(ca.cookie, &sa));
  OK(b.stats(cb.cookie, &sb));
  assert(!memcmp(&sa, &sb, sizeof sa) && sa.owner_count == 2);
  assert(sa.admitted_bytes == OGB3_HOST_LIMIT_BYTES && !sa.engine_live_bytes &&
         !sa.snapshot_live_bytes);
  assert(b.set(cb.cookie, ob, 32 * 1024 * 1024 + 1, 8 * 1024 * 1024) ==
         OGB3_CAPACITY);
  OK(a.stats(ca.cookie, &sb));
  assert(!memcmp(&sa, &sb, sizeof sa));
  assert(duplicate.set(ca.cookie, oa, 0, 0) == OGB3_INCOMPATIBLE);
  assert(a.set(cd.cookie, oa, 0, 0) == OGB3_INCOMPATIBLE);
  OK(duplicate.stats(cd.cookie, &sd));
  assert(!sd.admitted_bytes && !sd.owner_count);
  /* Native token data survives unloading one caller module. Host producer code
   * leases/capsules are the enclosing Godot test's responsibility. */
  assert(dlclose(a.handle) == 0);
  OK(b.close(cb.cookie, oa));
  OK(b.close(cb.cookie, ob));
  OK(b.stats(cb.cookie, &sb));
  assert(!sb.owner_count && !sb.admitted_bytes && !sb.host_reserved_bytes);
  assert(dlclose(duplicate.handle) == 0);
  assert(dlclose(b.handle) == 0);
  puts("domain modules PASS two producers one domain; forbidden static copy "
       "rejected; native/host owners zero");
  return 0;
}
