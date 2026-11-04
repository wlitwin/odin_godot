package box3d_native_diagnostics_test

import "core:testing"
import "core:mem"
import b "godot:box3d"
import d "godot:box3d/diagnostics"
import sc "godot:replay/schema"

Game :: struct {rng:u64,body:b.Body_Key,spawn_generation,previous_input:u32}
Observation :: struct {sensor,visitor:b.Shape_Key,began:u32}
Observations :: struct {count:u32,events:[4]Observation}
Occurrences :: struct {count:u32}
View :: struct {frame:d.Frame_View}

must :: proc(status:b.Status) {if status!=.Ok {panic("native diagnostic fixture failed")}}
zero_native_owners :: proc(t:^testing.T) {
	engine,es:=b.engine_allocation_stats();must(es)
	owned,os:=b.snapshot_allocation_stats();must(os)
	testing.expect_value(t,engine.live_bytes,u64(0));testing.expect_value(t,owned.live_bytes,u64(0))
}
world :: proc()->b.World {def:=b.world_def_default();def.gravity={};w,s:=b.world_create(def);must(s);return w}
body :: proc(w:b.World,kind:b.Body_Type)->b.Body {def:=b.body_def_default();def.type=kind;v,s:=b.body_create(w,def);must(s);return v}
capture_observations :: proc(w:b.World)->Observations {
	events:[4]b.Sensor_Event;n,s:=b.world_sensor_events(w,events[:]);must(s)
	out:=Observations{count=n}
	for e,i in events[:n] {key,ks:=b.shape_key_from_handle(e.sensor);must(ks);visitor,vs:=b.shape_key_from_handle(e.visitor);must(vs);out.events[i]={key,visitor,e.began}}
	return out
}
canonical :: proc(schema:^sc.Schema,value:$T)->[]u8 {
	out:=make([]u8,schema.wire_size);if sc.encode(schema,value,out).error!=.None {panic("test canonical value failed")};return out
}
view :: proc(w:b.World,game:Game,observations:Observations)->View {
	game_schema,obs_schema,event_schema:sc.Schema
	assert(sc.init(&game_schema,Game).error==.None);defer sc.destroy(&game_schema)
	assert(sc.init(&obs_schema,Observations).error==.None);defer sc.destroy(&obs_schema)
	assert(sc.init(&event_schema,Occurrences).error==.None);defer sc.destroy(&event_schema)
	descriptors:=[2]d.Descriptor{{"occurrences",event_schema.canonical[:]},{"state",game_schema.canonical[:]}}
	game_id,ge:=d.hash_descriptors("native-diagnostics-fixture",descriptors[:]);assert(ge==.None)
	// Test-only metadata. Production peers use the recovery catalog's verified
	// exact build/target identity and registered asset/profile contract.
	identity:=d.Identity{solver_format=b.STATE_DUMP_VERSION,recovery_format=1,game_format=1,observation_format=1,profile=0x44494147,
		build_target=d.hash_bytes(transmute([]u8)string("coherent-test-archive-supplied-by-runner")),
		assets=d.hash_bytes(transmute([]u8)string("native-diagnostic-box-sphere-fixture")),
		solver_schema=d.hash_bytes(transmute([]u8)string(b.STATE_COVERAGE_ID)),game_schema=game_id,
		observation_schema=d.hash_bytes(obs_schema.canonical[:]),input_schema=d.hash_bytes(transmute([]u8)string("native-test-prior-input-u32"))}
	result:=View{frame={identity=identity,epoch=1,tick=1}}
	n,ns:=b.world_dump(w,nil);must(ns);result.frame.parts[.Solver]=make([]u8,int(n));_,ns=b.world_dump(w,result.frame.parts[.Solver]);must(ns)
	result.frame.parts[.Game]=canonical(&game_schema,game)
	result.frame.parts[.Observations]=canonical(&obs_schema,observations)
	result.frame.parts[.Occurrences]=canonical(&event_schema,Occurrences{})
	return result
}
destroy_view :: proc(value:^View) {for p in d.Part {delete(value.frame.parts[p])};value^={}}
signature :: proc(v:View)->d.Signature {sig,error:=d.sign(v.frame);assert(error==.None);return sig}

@(test)
solver_only_change_survives_equal_motion_and_game_and_is_actionable :: proc(t:^testing.T) {
	defer zero_native_owners(t)
	w:=world();defer must(b.world_destroy(&w))
	body:=body(w,.Dynamic);key,ks:=b.body_key(body);must(ks)
	_,ss:=b.shape_sphere(body,b.shape_def_default(),0.25);must(ss)
	must(b.world_step_fixed(w));game:=Game{rng=77,body=key,spawn_generation=2,previous_input=9}
	before:=view(w,game,{});defer destroy_view(&before)
	motion_before,ms:=b.world_digests(w);must(ms)
	checkpoint,cs:=b.snapshot_capture(w);must(cs);defer must(b.snapshot_destroy(&checkpoint))
	must(b.world_set_gravity(w,{0,-1,0}))
	after:=view(w,game,{});defer destroy_view(&after)
	motion_after,mas:=b.world_digests(w);must(mas)
	testing.expect_value(t,motion_before.motion_digest,motion_after.motion_digest)
	testing.expect_value(t,d.compare(signature(before),signature(after)),d.Difference.Solver)
	testing.expect(t,mem.compare(before.frame.parts[.Game],after.frame.parts[.Game])==0)
	trace:d.Trace;defer d.trace_destroy(&trace)
	testing.expect_value(t,d.trace_capture(&trace,before.frame,after.frame,{from_tick=1,to_tick=1,depth=0}),d.Error.None)
	testing.expect_value(t,trace.difference,d.Difference.Solver)
	testing.expect(t,trace.first_byte>=4 && trace.first_byte<16)
	must(b.snapshot_restore(w,&checkpoint))
	restored:=view(w,game,{});defer destroy_view(&restored)
	testing.expect_value(t,d.compare(signature(before),signature(restored)),d.Difference.Match)
}

@(test)
pending_event_solver_and_completed_observation_contract_are_separate :: proc(t:^testing.T) {
	defer zero_native_owners(t)
	baseline:=world();defer must(b.world_destroy(&baseline))
	sensor:=body(baseline,.Static);visitor:=body(baseline,.Dynamic)
	sd:=b.shape_def_default();sd.is_sensor=1;sd.enable_sensor_events=1
	_,ss:=b.shape_box(sensor,sd,{1,1,1});must(ss);sd.is_sensor=0
	_,vs:=b.shape_sphere(visitor,sd,0.25);must(vs)
	key,ks:=b.body_key(visitor);must(ks);game:=Game{rng=88,body=key,previous_input=4}
	must(b.world_step_fixed(baseline));observations:=capture_observations(baseline)
	testing.expect(t,observations.count==1 && observations.events[0].began==1)
	// A post-step destruction creates a future end while preserving the owned
	// same-tick observation. Raw completed native outputs are cleared on restore.
	must(b.body_destroy(&sensor));checkpoint,cs:=b.snapshot_capture(baseline);must(cs)
	clone,cl:=b.snapshot_clone(&checkpoint);must(cl);must(b.snapshot_destroy(&checkpoint))
	restored:=world();defer must(b.world_destroy(&restored));must(b.snapshot_restore(restored,&clone));must(b.snapshot_destroy(&clone))
	a:=view(baseline,game,observations);defer destroy_view(&a)
	z:=view(restored,game,observations);defer destroy_view(&z)
	testing.expect_value(t,d.compare(signature(a),signature(z)),d.Difference.Match)
	missing:=view(restored,game,{});defer destroy_view(&missing)
	testing.expect_value(t,d.compare(signature(a),signature(missing)),d.Difference.Observations)
	for tick in 0..<60 {
		must(b.world_step_fixed(baseline));must(b.world_step_fixed(restored))
		left,right:=capture_observations(baseline),capture_observations(restored)
		testing.expect_value(t,left,right)
		if tick==0 {testing.expect(t,left.count==1 && left.events[0].began==0)}else {testing.expect_value(t,left.count,u32(0))}
		l:=view(baseline,game,left);r:=view(restored,game,right)
		testing.expect_value(t,d.compare(signature(l),signature(r)),d.Difference.Match)
		destroy_view(&l);destroy_view(&r)
	}
}
