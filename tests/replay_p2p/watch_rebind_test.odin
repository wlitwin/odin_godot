package replay_p2p_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import rb "godot:replay/p2p"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"

@(test)
spectator_rebind_retains_world_fences_old_stream_and_continues_from_another_player :: proc(t:^testing.T) {
	f:Watch_Fixture;watch_setup(&f);defer watch_cleanup(&f)
	for _ in 0..<240 {testing.expect_value(t,watch_cycle(&f,120),rb.Error.None)}
	before,known:=rb.watch_current(&f.watch);testing.expect(t,known && before.tick==120)
	reset:=f.watch.reset;chain:=f.watch.states[f.watch.active].chain
	anchor,error:=rb.watch_rebind(&f.watch,1,tr.memory_transport(&f.endpoints[1]),78,f.game.clock*1000/60)
	testing.expect_value(t,error,rb.Error.None)
	retained,_:=rb.watch_current(&f.watch);testing.expect(t,reflect.equal(before,retained) && f.watch.rebind_pending && f.watch.stats.rebinds==1)
	testing.expect(t,anchor.tick==before.tick && anchor.chain==chain && f.watch.transfer.latest.archive.sequence==0)
	// Retired traffic uses the same physical sender ID. Only the new binding
	// identifies the new stream; old offers must not alter or install anything.
	for _ in 0..<12 {testing.expect_value(t,watch_cycle(&f,132),rb.Error.None)}
	retained,_=rb.watch_current(&f.watch);testing.expect(t,reflect.equal(before,retained) && f.watch.transfer.stats.rejected>0)
	rb.watch_source_destroy(&f.source)
	cfg:=rec.DEFAULT_CONFIG;cfg.retry_ms,cfg.timeout_ms=30,500
	testing.expect_value(t,rb.watch_source_init(&f.source,&f.game.peers[1],2,tr.memory_transport(&f.endpoints[0]),78,cfg,resume=&anchor),rb.Error.None)
	for _ in 0..<500 {testing.expect_value(t,watch_cycle(&f,240),rb.Error.None)}
	actual,_:=rb.watch_current(&f.watch);expected,_:=r.current(&f.game.peers[1].timeline)
	testing.expect(t,reflect.equal(actual,expected) && actual.tick==240 && !f.watch.rebind_pending)
	testing.expect_value(t,f.watch.reset,reset)
	testing.expect_value(t,f.watch.states[f.watch.active].chain,f.game.peers[1].chain)
	expect_reference(t,&f.game,240)
}

@(test)
replacement_source_rejects_bad_or_evicted_anchors_without_changing_its_player :: proc(t:^testing.T) {
	f:Watch_Fixture;watch_setup(&f);defer watch_cleanup(&f)
	for _ in 0..<160 {testing.expect_value(t,watch_cycle(&f,120),rb.Error.None)}
	anchor,error:=rb.watch_anchor(&f.watch);testing.expect_value(t,error,rb.Error.None)
	peer:=&f.game.peers[1];before,_:=r.current(&peer.timeline);chain:=peer.chain
	for kind in 0..<6 {
		bad:=anchor
		switch kind {case 0:bad.contract+=1;case 1:bad.session+=1;case 2:bad.epoch+=1;case 3:bad.content+=1;case 4:bad.chain+=1;case 5:bad.digest+=1}
		source:rb.Watch_Source(World,Input,Event,2)
		result:=rb.watch_source_init(&source,peer,2,tr.memory_transport(&f.endpoints[0]),78,resume=&bad)
		testing.expect_value(t,result,kind<4 ? rb.Error.Invalid_Archive : rb.Error.Diverged)
		testing.expect(t,!source.ready)
		rb.watch_source_destroy(&source)
	}
	after,_:=r.current(&peer.timeline);testing.expect(t,reflect.equal(before,after) && chain==peer.chain && peer.phase==.Running)
	for _ in 0..<150 {cycle(&f.game,240)}
	source:rb.Watch_Source(World,Input,Event,2);defer rb.watch_source_destroy(&source)
	testing.expect_value(t,rb.watch_source_init(&source,peer,2,tr.memory_transport(&f.endpoints[0]),78,resume=&anchor),rb.Error.History)
	testing.expect(t,!source.ready && peer.phase==.Running)
}

@(test)
watch_rebind_validation_is_atomic_and_cannot_clear_divergence :: proc(t:^testing.T) {
	f:Watch_Fixture;watch_setup(&f);defer watch_cleanup(&f)
	for _ in 0..<160 {testing.expect_value(t,watch_cycle(&f,120),rb.Error.None)}
	before,_:=rb.watch_current(&f.watch);scope:=f.watch.transfer.scope;receipt:=f.watch.transfer.latest;now:=f.watch.transfer.clock.now
	wire:=tr.memory_transport(&f.endpoints[1])
	_,same:=rb.watch_rebind(&f.watch,1,wire,77,now);testing.expect_value(t,same,rb.Error.Invalid_Config)
	_,back:=rb.watch_rebind(&f.watch,1,wire,78,now-1);testing.expect_value(t,back,rb.Error.Time)
	_,missing:=rb.watch_rebind(&f.watch,1,{},78,now);testing.expect_value(t,missing,rb.Error.Transport)
	_,source:=rb.watch_rebind(&f.watch,0,wire,78,now);testing.expect_value(t,source,rb.Error.Invalid_Config)
	f.watch.states[f.watch.active].timeline.busy=true
	_,busy:=rb.watch_rebind(&f.watch,1,wire,78,now);testing.expect_value(t,busy,rb.Error.Not_Ready)
	f.watch.states[f.watch.active].timeline.busy=false
	f.watch.error=.Diverged
	_,diverged:=rb.watch_rebind(&f.watch,1,wire,78,now);testing.expect_value(t,diverged,rb.Error.Not_Ready)
	after,_:=rb.watch_current(&f.watch)
	testing.expect(t,reflect.equal(before,after) && scope==f.watch.transfer.scope && receipt==f.watch.transfer.latest && f.watch.stats.rebinds==0)
}

@(test)
replacement_source_rechecks_retention_before_its_first_publication :: proc(t:^testing.T) {
	f:Watch_Fixture;watch_setup(&f);defer watch_cleanup(&f)
	for _ in 0..<160 {testing.expect_value(t,watch_cycle(&f,120),rb.Error.None)}
	anchor,error:=rb.watch_anchor(&f.watch);testing.expect_value(t,error,rb.Error.None)
	source:rb.Watch_Source(World,Input,Event,2);defer rb.watch_source_destroy(&source)
	testing.expect_value(t,rb.watch_source_init(&source,&f.game.peers[1],2,tr.memory_transport(&f.endpoints[0]),78,resume=&anchor),rb.Error.None)
	for _ in 0..<160 {cycle(&f.game,240)}
	testing.expect_value(t,rb.watch_source_pump(&source,f.game.clock*1000/60),rb.Error.History)
	testing.expect_value(t,source.publications,u64(0))
}

@(test)
replacement_source_cannot_skip_the_required_overlap_with_a_fresh_baseline :: proc(t:^testing.T) {
	f:Watch_Fixture;watch_setup(&f);defer watch_cleanup(&f)
	for _ in 0..<160 {testing.expect_value(t,watch_cycle(&f,120),rb.Error.None)}
	before,_:=rb.watch_current(&f.watch)
	_,error:=rb.watch_rebind(&f.watch,1,tr.memory_transport(&f.endpoints[1]),78,f.game.clock*1000/60);testing.expect_value(t,error,rb.Error.None)
	rb.watch_source_destroy(&f.source)
	for _ in 0..<150 {cycle(&f.game,240)}
	// Omit the anchor deliberately: normal fresh viewing would trust this
	// current baseline, but a rebind must prove the spectator's existing state.
	testing.expect_value(t,rb.watch_source_init(&f.source,&f.game.peers[1],2,tr.memory_transport(&f.endpoints[0]),78),rb.Error.None)
	for _ in 0..<100 {if watch_cycle(&f,240)==.History {break}}
	testing.expect_value(t,f.watch.error,rb.Error.History)
	after,_:=rb.watch_current(&f.watch);testing.expect(t,reflect.equal(before,after) && f.watch.rebind_pending)
}
