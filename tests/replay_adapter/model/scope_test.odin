package adapter_test
import "core:testing"
import v "godot:replay/view"
import rgd "godot:replay/godot"
Key :: struct {run:u32,floor:u8}
@(test)
scope_policy_is_explicit_and_failures_preserve_tracker :: proc(t:^testing.T) {
 tracker:v.Scope_Tracker(Key)
 first,error:=v.scope_update(&tracker,{1,0,10},Key{1,1},true);testing.expect(t,error==.None && first.revision==1)
 same,_:=v.scope_update(&tracker,{1,0,11},Key{1,1},true);testing.expect_value(t,same,first)
 changed,_:=v.scope_update(&tracker,{1,0,12},Key{1,2},true);testing.expect(t,changed.revision==2)
 rewind,_:=v.scope_update(&tracker,{1,0,5},Key{1,2},true);testing.expect(t,rewind.revision==3)
 retained,_:=v.scope_update(&tracker,{1,0,4},Key{1,2},false);testing.expect_value(t,retained,rewind)
 reset,_:=v.scope_update(&tracker,{1,1,4},Key{1,2},false);testing.expect(t,reset.revision==4)
 epoch,_:=v.scope_update(&tracker,{2,0,4},Key{1,2},false);testing.expect(t,epoch.epoch==2 && epoch.revision==5)
 before:=tracker
 _,error=v.scope_update(&tracker,{1,0,5},Key{1,2},false);testing.expect(t,error==.Stale && tracker==before)
 tracker.revision=max(u64);before=tracker
 _,error=v.scope_update(&tracker,{3,0,6},Key{1,2},false);testing.expect(t,error==.Exhausted && tracker==before)
}

@(test)
explicit_bake_bounds_reject_narrowing_and_preserve_first_diagnostic :: proc(t:^testing.T) {
 ctx:rgd.Bake_Context
 testing.expect_value(t,rgd.bake_integer(&ctx,u8,255,0,255,"$.damage"),u8(255))
 testing.expect(t,ctx.report.error==.None)
 testing.expect_value(t,rgd.bake_integer(&ctx,u8,256,0,255,"$.damage"),u8(0))
 before:=ctx.report
 testing.expect_value(t,rgd.bake_integer(&ctx,u16,10,0,100,"$.other"),u16(0))
 testing.expect_value(t,ctx.report,before)
 ctx={};rgd.bake_integer(&ctx,u8,1,0,1000,"$.bad_bounds")
 testing.expect(t,ctx.report.error!=.None)
}
