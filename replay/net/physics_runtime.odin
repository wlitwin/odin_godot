package replay_net

import "core:mem"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Physics_Schemas :: struct {
	state, occurrence, accepted, decisions: sc.Schema,
	chunk, ack, fact: sc.Schema,
}
Physics_Metadata :: struct($N:int) {tick:u64,decisions:Accepted_Decisions(N)}
Physics_Input_Receipt :: struct {tick,generation:u64,digest:bd.Digest}
Physics_Action_Receipt :: struct {sequence,tick:u64,digest:bd.Digest}
Physics_Sent_View :: struct {proof:Sent_View,generation,serial:u64}
Physics_Tx :: struct {
	data:Complete_Data,
	id,tick,generation,serial:u64,
	purpose:Complete_Purpose,
	part:int,
	waiting_ack:bool,
	digest:bd.Digest,
}
Physics_Assembly :: struct {
	id,tick,generation,serial:u64,
	purpose:Complete_Purpose,
	digest:bd.Digest,
	data:Complete_Data,
	mask:[32]u64,
	received,parts:int,
}
Physics_Chunk_Header :: struct {
	generation,serial,id:u64,
	total,index,parts,purpose:u32,
	digest:bd.Digest,
}
Physics_Ack :: struct {generation,serial,id:u64,digest:bd.Digest}
Physics_Fact_Header :: struct {generation,serial:u64,version,count:u32}

Server_Physics :: struct($S,$C,$A,$E:typeid,$N:int){
	allocator:mem.Allocator,
	schemas:Physics_Schemas,
	metadata:[]Physics_Metadata(N),
	views:[MAX_PEERS][PHYSICS_HISTORY]Physics_Sent_View,
	input_receipts:[MAX_PEERS][PHYSICS_HISTORY]Physics_Input_Receipt,
	action_receipts:[MAX_PEERS][ACTION_CAPACITY]Physics_Action_Receipt,
	tx:[MAX_PEERS]Physics_Tx,
	next_id:u64,
	charged:u64,
	trace:bd.Trace,
	last_frame_error:r.Error,
}
Client_Physics :: struct($S,$C,$A,$E:typeid,$N:int){
	allocator:mem.Allocator,
	schemas:Physics_Schemas,
	accepted:Accepted_Ledger(C,A,N),
	assemblies:[2]Physics_Assembly,
	pending:Complete_Data,
	pending_checkpoint:^r.Complete_Checkpoint(S,Net_Event(E)),
	pending_purpose:Complete_Purpose,
	pending_id:u64,
	charged:u64,
	trace:bd.Trace,
	trace_charge:u64,
	signatures:[PHYSICS_HISTORY]bd.Signature,
	actual_mismatch:Complete_View,
	waiting_tick:u64,
	repairs,confirmed_matches,verified_compares,full_compares:u64,
	last_planned_depth,last_checked_prefix,last_executed_steps:u64,
	last_frame_error:r.Error,
}

physics_config_default :: proc()->Config {
	cfg:=DEFAULT_CONFIG
	cfg.history=128;cfg.hz=60;cfg.lead=2;cfg.max_prediction=8;cfg.max_future=8
	cfg.max_rewind=8;cfg.max_view_span=8;cfg.snapshot_every=3;cfg.watch_delay=0
	cfg.egress_bytes_per_second=8*1024*1024;cfg.egress_bytes_per_pump=256*1024
	return cfg
}
@(private)
physics_config_valid :: proc(model:Model($S,$C,$A,$E,$N),cfg:Config)->bool{
	return model.complete_state && complete_codec_valid(model.complete_codec) &&
	       cfg.history==128 && cfg.hz==60 && cfg.max_prediction<=8 && cfg.max_future<=8 && cfg.lead<=6 &&
	       cfg.max_rewind<=8 && cfg.snapshot_every<=8 && cfg.egress_bytes_per_pump>=COMPLETE_PART_BYTES+512 &&
	       model.group.id==0 && model.replication.id==0 && model.control_timing==.Scheduled
}
@(private)
physics_schemas_init :: proc(s:^Physics_Schemas,$S,$C,$A,$E:typeid,$N:int,model:Model(S,C,A,E,N),allocator:mem.Allocator)->Error{
	if sc.init(&s.state,S,allocator=allocator).error!=.None ||
	   sc.init(&s.occurrence,r.Occurrence(Net_Event(E)),allocator=allocator).error!=.None ||
	   sc.init(&s.accepted,Accepted_Input(C,A,N),allocator=allocator).error!=.None ||
	   sc.init(&s.decisions,Accepted_Decisions(N),allocator=allocator).error!=.None ||
	   sc.init(&s.chunk,Physics_Chunk_Header,allocator=allocator).error!=.None ||
	   sc.init(&s.ack,Physics_Ack,allocator=allocator).error!=.None ||
	   sc.init(&s.fact,Physics_Fact_Header,allocator=allocator).error!=.None {return .Invalid_Schema}
	game,error:=complete_game_schema(&s.state,&s.occurrence,model.complete_codec.game_rules)
	if error!=.None || game!=model.complete_codec.identity.game_schema {return .Checkpoint_Contract}
	controls,actions:sc.Schema;defer sc.destroy(&controls);defer sc.destroy(&actions)
	if sc.init(&controls,C,allocator=allocator).error!=.None || sc.init(&actions,A,allocator=allocator).error!=.None {return .Invalid_Schema}
	inputs,input_error:=complete_input_schema(&s.accepted,&controls,&actions,&s.decisions)
	if input_error!=.None || inputs!=model.complete_codec.identity.input_schema {return .Checkpoint_Contract}
	if s.state.wire_size>65536 || s.accepted.wire_size+s.fact.wire_size+WIRE_EVENTS*s.occurrence.wire_size+bd.SIGNATURE_BYTES+sc.HEADER_BYTES>tr.MAX_PACKET_BYTES {return .Capacity}
	return .None
}
@(private)
physics_schemas_destroy :: proc(s:^Physics_Schemas){
	sc.destroy(&s.state);sc.destroy(&s.occurrence);sc.destroy(&s.accepted);sc.destroy(&s.decisions)
	sc.destroy(&s.chunk);sc.destroy(&s.ack);sc.destroy(&s.fact);s^={}
}

@(private)
server_physics_init :: proc(s:^Server($S,$C,$A,$E,$N))->Error{
	bytes:=u64(size_of(Server_Physics(S,C,A,E,N)))+u64(PHYSICS_HISTORY)*size_of(Physics_Metadata(N))
	if error:=s.model.complete_codec.reserve(s.model.complete_codec.catalog,bytes);error!=.None {return error}
	pointer,allocation_error:=mem.alloc(size_of(Server_Physics(S,C,A,E,N)),align_of(Server_Physics(S,C,A,E,N)),s.allocator)
	if allocation_error!=.None {s.model.complete_codec.release(s.model.complete_codec.catalog,bytes);return .Capacity}
	s.physics=cast(^Server_Physics(S,C,A,E,N))pointer
	s.physics^={allocator=s.allocator,charged=bytes}
	if error:=physics_schemas_init(&s.physics.schemas,S,C,A,E,N,s.model,s.allocator);error!=.None {return error}
	s.physics.metadata=make([]Physics_Metadata(N),PHYSICS_HISTORY,s.allocator)
	return .None
}
@(private)
server_physics_destroy :: proc(s:^Server($S,$C,$A,$E,$N)){
	if s.physics==nil {return}
	p:=s.physics
	for &tx in p.tx {complete_data_destroy(&tx.data)}
	bd.trace_destroy(&p.trace);physics_schemas_destroy(&p.schemas);delete(p.metadata,p.allocator)
	s.model.complete_codec.release(s.model.complete_codec.catalog,p.charged)
	mem.free(p,p.allocator);s.physics=nil
}
@(private)
client_physics_init :: proc(c:^Client($S,$C,$A,$E,$N))->Error{
	bytes:=u64(size_of(Client_Physics(S,C,A,E,N)))+u64(PHYSICS_HISTORY)*size_of(Accepted_Input(C,A,N))
	if bytes>8*1024*1024 {return .Capacity}
	if error:=c.model.complete_codec.reserve(c.model.complete_codec.catalog,bytes);error!=.None {return error}
	pointer,allocation_error:=mem.alloc(size_of(Client_Physics(S,C,A,E,N)),align_of(Client_Physics(S,C,A,E,N)),c.allocator)
	if allocation_error!=.None {c.model.complete_codec.release(c.model.complete_codec.catalog,bytes);return .Capacity}
	c.physics=cast(^Client_Physics(S,C,A,E,N))pointer
	c.physics^={allocator=c.allocator,charged=bytes}
	if error:=physics_schemas_init(&c.physics.schemas,S,C,A,E,N,c.model,c.allocator);error!=.None {return error}
	return accepted_ledger_init(&c.physics.accepted,c.cfg.epoch,0,8*1024*1024,c.allocator)
}
@(private)
client_physics_destroy :: proc(c:^Client($S,$C,$A,$E,$N)){
	if c.physics==nil {return}
	p:=c.physics
	for &assembly in p.assemblies {complete_data_destroy(&assembly.data)}
	complete_data_destroy(&p.pending)
	if p.pending_checkpoint!=nil {r.complete_checkpoint_destroy(p.pending_checkpoint);mem.free(p.pending_checkpoint,p.allocator)}
	if p.trace_charge!=0 {c.model.complete_codec.release(c.model.complete_codec.catalog,p.trace_charge)}
	bd.trace_destroy(&p.trace);complete_view_destroy(&p.actual_mismatch);accepted_ledger_destroy(&p.accepted);physics_schemas_destroy(&p.schemas)
	c.model.complete_codec.release(c.model.complete_codec.catalog,p.charged)
	mem.free(p,p.allocator);c.physics=nil
}

@(private)
physics_contract :: proc(base:u64,identity:bd.Identity)->u64{
	byte:[8]u8;for i in 0..<8 {byte[i]=u8(base>>uint(i*8))}
	one:=[?]u8{1};view:=bd.Frame_View{identity=identity,epoch=1,parts={.Solver=one[:],.Game=nil,.Side=nil,.Observations=nil,.Occurrences=nil}}
	signature,error:=bd.sign(view);if error!=.None {return 0}
	fields:=[?]bd.Descriptor{{tag="legacy",bytes=byte[:]},{tag="physics",bytes=signature.complete[:]}}
	digest,hash_error:=bd.hash_descriptors("odin-godot.replay.net-contract.v1",fields[:]);if hash_error!=.None{return 0}
	result:u64;for i in 0..<8 {result|=u64(digest[i])<<uint(i*8)};return result
}
