#include "native_observe_internal.h"
#include "owned_snapshot.h"
#include "recovery_codec.h"
#include "state_dump.h"
#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
static uint64_t cookie, ticks;
static int clock_mode;
#if defined(OGB3_TESTING) && OGB3_TESTING
extern void ogb3_snapshot_test_fail_allocation_after(int64_t);
extern void ogb3_recovery_test_fail_build_after(int64_t);
#endif
static uint32_t clock_read(void *user, uint64_t *out) {
  ogb3_obs_block_v1 *block = user;
  if (clock_mode == 1) return 0;
  if (clock_mode == 4) return 2; /* Only exactly1 means available. */
  if (clock_mode == 2) {*out = ticks ? --ticks : 0; return 1;}
  if (clock_mode == 3) {
    assert(ogb3_test_native_observe_end_v1(cookie, block->scope_token) == OGB3_UNSUPPORTED);
  }
  *out = ++ticks;
  return 1;
}
static ogb3_obs_config_v1 config(uint32_t mode, ogb3_obs_block_v1 *b) {
  return (ogb3_obs_config_v1){1,mode,OGB3_OBS_ALL_PHASES_V1,
      mode == OGB3_OBS_TIMED_V1 ? clock_read : NULL,
      mode == OGB3_OBS_TIMED_V1 ? b : NULL};
}
static void closed(const ogb3_obs_block_v1 *b) {
  assert(b->state==OGB3_OBS_CLOSED_V1 && !b->stack_depth &&
         !b->error_flags && !b->clock_reads);
  for (uint32_t i=0;i<b->count;i++)
    assert(!b->spans[i].start_us && !b->spans[i].end_us);
}
/* Real errors and reconstruction/cleanup must retain the original result and
 * leave the observer stack balanced, including allocation failures. */
static void codec_paths(ogb3_obs_block_v1 *b, ogb3_world world,
                        const ogb3_snapshot *snapshot) {
  ogb3_recovery_config cfg;assert(!ogb3_recovery_config_default(&cfg));cfg.profile=1;
  ogb3_recovery_asset asset={.id=1,.kind=OGB3_RECOVERY_SPHERE,.radius=.25f};
  ogb3_recovery_catalog *catalog=NULL;
  assert(!ogb3_recovery_catalog_create(&cfg,&asset,1,&catalog));
  ogb3_obs_config_v1 c=config(1,b);uint64_t token=0,required=0;
  assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
  assert(!ogb3_recovery_world_admit(catalog,world,0,&required,NULL));
  assert(!ogb3_recovery_write(catalog,snapshot,NULL,0,&required,NULL));
  uint8_t *bytes=malloc((size_t)required);assert(bytes);
  assert(!ogb3_recovery_write(catalog,snapshot,bytes,required,&required,NULL));
  ogb3_snapshot *restored=NULL;
  assert(!ogb3_recovery_read(catalog,bytes,required,0,&restored,NULL));
  assert(restored);ogb3_snapshot_release(restored);
  assert(!ogb3_test_native_observe_end_v1(cookie,token));closed(b);
  uint32_t phases=0;for(uint32_t i=0;i<b->count;i++) phases|=1u<<(b->spans[i].phase-1);
  assert((phases&0x7fc0u)==0x7fc0u); /* All actual codec phases7..15. */

  assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
  assert(ogb3_world_step_fixed(0)==OGB3_INVALID_HANDLE);
  restored=(ogb3_snapshot *)(uintptr_t)1;
  assert(ogb3_snapshot_capture(0,&restored)==OGB3_INVALID_HANDLE && !restored);
  assert(ogb3_recovery_read(catalog,bytes,required-1,0,&restored,NULL)!=OGB3_OK && !restored);
  assert(ogb3_recovery_read(NULL,bytes,required,0,&restored,NULL)==OGB3_INVALID_ARGUMENT && !restored);
  assert(ogb3_recovery_write(NULL,snapshot,NULL,0,&required,NULL)==OGB3_INVALID_ARGUMENT);
  assert(ogb3_recovery_world_admit(catalog,0,0,&required,NULL)==OGB3_INVALID_HANDLE);
  assert(!ogb3_test_native_observe_end_v1(cookie,token));closed(b);
  for(uint32_t i=0;i<b->count;i++) assert(b->spans[i].native_status!=OGB3_OK);
#if defined(OGB3_TESTING) && OGB3_TESTING
  /* Count-only query above sets required=0 on invalid world admission. */
  assert(!ogb3_recovery_write(catalog,snapshot,NULL,0,&required,NULL));
  assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
  ogb3_snapshot_test_fail_allocation_after(0);
  assert(ogb3_snapshot_capture(world,&restored)==OGB3_OUT_OF_MEMORY && !restored);
  ogb3_snapshot_test_fail_allocation_after(-1);
  ogb3_recovery_test_fail_build_after(0);
  assert(ogb3_recovery_read(catalog,bytes,required,0,&restored,NULL)==OGB3_OUT_OF_MEMORY && !restored);
  ogb3_recovery_test_fail_build_after(-1);
  assert(!ogb3_test_native_observe_end_v1(cookie,token));closed(b);
#endif
  free(bytes);ogb3_recovery_catalog_release(catalog);
}
int main(void) {
  ogb3_domain_contract domain;
  assert(!ogb3_domain_contract_get(&domain)); cookie = domain.cookie;
  ogb3_obs_abi_v1 abi;
  assert(!ogb3_test_native_observe_abi_v1(cookie,&abi));
  assert(abi.block_bytes==49392 && abi.span_bytes==48 && abi.span_capacity==1024 && abi.stack_capacity==16 && abi.native_static_storage_bytes>0);
  ogb3_obs_block_v1 *b=malloc(sizeof(*b)), *prior=malloc(sizeof(*b));assert(b&&prior);
  memset(b,0xa5,sizeof(*b));memcpy(prior,b,sizeof(*b));
  ogb3_obs_config_v1 c=config(OGB3_OBS_STRUCTURE_ONLY_V1,b);
  uint64_t token=77;
  assert(ogb3_test_native_observe_begin_v1(cookie^1,&c,b,sizeof(*b),&token)==OGB3_INCOMPATIBLE && token==77 && !memcmp(b,prior,sizeof(*b)));
  c.abi_version=2;assert(ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token)==OGB3_INCOMPATIBLE);c.abi_version=1;
  c.mode=0;assert(ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token)==OGB3_INVALID_ARGUMENT);c.mode=1;
  c.phase_mask=0;assert(ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token)==OGB3_INVALID_ARGUMENT);c.phase_mask=OGB3_OBS_ALL_PHASES_V1;
  assert(ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b)-1,&token)==OGB3_INVALID_ARGUMENT);
  assert(ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&b->scope_token)==OGB3_INVALID_ARGUMENT);
  assert(token==77 && !memcmp(b,prior,sizeof(*b)));
  c.clock_user=b;assert(ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token)==OGB3_INVALID_ARGUMENT);c.clock_user=NULL;
  c=config(2,b);c.clock_user=prior;assert(ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token)==OGB3_INVALID_ARGUMENT);
  c=config(1,b);
  ogb3_allocation_stats engine_before,wrapper_before,engine_after,wrapper_after;
  assert(!ogb3_engine_allocation_stats(&engine_before));assert(!ogb3_snapshot_allocation_stats(&wrapper_before));
  assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
  uint64_t second=9;assert(ogb3_test_native_observe_begin_v1(cookie,&c,prior,sizeof(*b),&second)==OGB3_UNSUPPORTED && second==9);
  uint64_t parent=ogb3_obs_enter(2), child=ogb3_obs_enter(4);
  ogb3_obs_leave(child,OGB3_OUT_OF_MEMORY);ogb3_obs_leave(parent,OGB3_OK);
  assert(!ogb3_test_native_observe_end_v1(cookie,token));
  assert(b->count==2 && b->spans[1].parent_id==1 && b->spans[1].native_status==OGB3_OUT_OF_MEMORY && !b->clock_reads && !b->error_flags && !b->stack_depth);
  assert(ogb3_test_native_observe_end_v1(cookie,token)==OGB3_INVALID_HANDLE);
  assert(!ogb3_obs_enter(2));
  uint64_t old_token=token;
  c.phase_mask=OGB3_OBS_PHASE_BIT_V1(2)|OGB3_OBS_PHASE_BIT_V1(4);
  assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
  assert(token!=old_token && ogb3_test_native_observe_end_v1(cookie,old_token)==OGB3_INVALID_HANDLE);
  assert(ogb3_test_native_observe_end_v1(cookie^1,token)==OGB3_INCOMPATIBLE && b->state==OGB3_OBS_ACTIVE_V1);
  parent=ogb3_obs_enter(2);uint64_t omitted=ogb3_obs_enter(3);assert(!omitted);
  child=ogb3_obs_enter(4);ogb3_obs_leave(child,0);ogb3_obs_leave(omitted,0);ogb3_obs_leave(parent,0);
  child=ogb3_obs_enter(4);ogb3_obs_leave(child,0);
  assert(!ogb3_test_native_observe_end_v1(cookie,token));closed(b);
  assert(b->count==3 && b->root_count==2 && b->spans[1].parent_id==1 && b->spans[2].parent_id==0 && b->spans[2].root_ordinal==2);
  assert(!ogb3_engine_allocation_stats(&engine_after));assert(!ogb3_snapshot_allocation_stats(&wrapper_after));
  assert(!memcmp(&engine_before,&engine_after,sizeof(engine_before)) && !memcmp(&wrapper_before,&wrapper_after,sizeof(wrapper_before)));
  for (int mode=0;mode<5;mode++) {
    clock_mode=mode;ticks=mode==2?100:0;c=config(2,b);
    assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
    parent=ogb3_obs_enter(2);ogb3_obs_leave(parent,OGB3_OK);
    assert(!ogb3_test_native_observe_end_v1(cookie,token));
    assert(b->clock_reads==2);
    if (!mode) assert(!b->error_flags);
    if (mode==1 || mode==4) assert(b->error_flags&OGB3_OBS_ERROR_CLOCK_FAILED_V1);
    if (mode==2) assert(b->error_flags&OGB3_OBS_ERROR_CLOCK_REGRESSED_V1);
    if (mode==3) assert(b->error_flags&OGB3_OBS_ERROR_SCOPE_REENTRY_V1);
  }
  c=config(1,b);assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
  for (int i=0;i<1025;i++) {parent=ogb3_obs_enter(2);ogb3_obs_leave(parent,0);}
  assert(!ogb3_test_native_observe_end_v1(cookie,token));assert(b->count==1024 && b->overflow_count==1 && (b->error_flags&1));
  assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
  uint64_t stack[17];for (int i=0;i<17;i++) stack[i]=ogb3_obs_enter(2);
  for (int i=16;i>=0;i--) ogb3_obs_leave(stack[i],0);
  assert(!ogb3_test_native_observe_end_v1(cookie,token));assert(b->nesting_errors==1 && !b->stack_depth);
  assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));ogb3_obs_enter(2);
  assert(!ogb3_test_native_observe_end_v1(cookie,token));assert(b->error_flags&OGB3_OBS_ERROR_UNCLOSED_V1);
  /* Real entry/exit and all original Native constructors remain intact. */
  ogb3_world_def def;ogb3_world world;assert(!ogb3_world_def_default(&def));assert(!ogb3_world_create(&def,&world));
  assert(!ogb3_test_native_observe_begin_v1(cookie,&c,b,sizeof(*b),&token));
  assert(!ogb3_world_step_fixed(world));ogb3_snapshot *snapshot=NULL;assert(!ogb3_snapshot_capture(world,&snapshot));
  assert(!ogb3_test_native_observe_end_v1(cookie,token));assert(!b->error_flags && !b->stack_depth && !b->clock_reads);
  assert(b->root_count==2 && b->spans[0].phase==1 && b->spans[1].phase==2);
  codec_paths(b,world,snapshot);
  ogb3_snapshot_release(snapshot);assert(!ogb3_world_destroy(world));
  ogb3_allocation_stats e,w;assert(!ogb3_engine_allocation_stats(&e));assert(!ogb3_snapshot_allocation_stats(&w));assert(!e.live_bytes&&!w.live_bytes);
  printf("native observer control/layout/status/clock/overflow/depth/cleanup PASS static_bytes=%llu\n",(unsigned long long)abi.native_static_storage_bytes);
  free(prior);free(b);return 0;
}
