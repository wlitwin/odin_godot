package replay_external_wasm

import "base:runtime"
import "core:mem"
import r "godot:replay"
import f "../fixture"

backing: [4 * 1024 * 1024]u8
old_capability: r.Execution
observed: r.Error
profile_tick:u64
profile_clock :: proc()->u64{profile_tick+=1;return profile_tick}

probe :: proc(game:^f.Game,input:f.Input,ctx:^r.Step(i64)) {
	_,observed=r.execution_pointer(old_capability,f.IDENTITY)
	f.step(game,input,ctx)
}

@(export)
verify :: proc "c" () -> u32 {
	context=runtime.default_context()
	arena:mem.Arena;mem.arena_init(&arena,backing[:])
	context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator
	stats:f.Stats
	initial,owner:=f.checkpoint(i64,&stats,history=4)
	timeline:r.Timeline(f.Game,f.Input,i64)
	if r.init_complete(&timeline,&initial,f.step,{4,4})!=.None {return 1}
	profile_tick=0;timeline.external.clock=profile_clock
	if r.advance(&timeline,f.Input{delta=3}).error!=.None {return 2}
	profile:=timeline.external_profile
	if profile.open.samples!=1||profile.model.samples!=1||profile.capture.samples!=1{return 10}
	if profile.open.errors!=0||profile.model.errors!=0||profile.capture.errors!=0{return 11}
	if profile.open.total_ns==0||profile.model.total_ns==0||profile.capture.total_ns==0{return 12}
	timeline.external.clock=nil
	old_capability=stats.last_capability
	saved,error:=r.capture_complete(&timeline,1);if error!=.None {return 3}
	r.destroy(&timeline)
	r.complete_checkpoint_destroy(&initial);f.owner_destroy(&owner)
	if r.init_complete(&timeline,&saved,probe,{4,4})!=.None {return 4}
	if r.advance(&timeline,f.Input{delta=4}).error!=.None {return 5}
	if observed!=.Stale_Execution {return 6}
	actual,actual_error:=r.capture_complete(&timeline,2);if actual_error!=.None || f.value(&actual)!=7 {return 7}
	if r.audit(&timeline,2).error!=.None {return 8}
	r.destroy(&timeline);r.complete_checkpoint_destroy(&saved);r.complete_checkpoint_destroy(&actual)
	if stats.images!=0 || stats.executions!=0 || stats.domains!=0 {return 9}
	return 0
}
