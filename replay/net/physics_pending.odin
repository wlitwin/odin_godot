package replay_net

import "core:mem"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"

@(private)
client_physics_drop_pending :: proc(c:^Client($S,$C,$A,$E,$N)){
	if c.physics.pending_checkpoint!=nil {r.complete_checkpoint_destroy(c.physics.pending_checkpoint);mem.free(c.physics.pending_checkpoint,c.allocator);c.physics.pending_checkpoint=nil}
	complete_data_destroy(&c.physics.pending);c.has_pending=false
}
@(private)
client_physics_request :: proc(c:^Client($S,$C,$A,$E,$N),tick:u64){
	if c.request_sequence==max(u64){c.phase=.Failed;return};c.request_sequence+=1
	packet:=Request_Packet{generation=c.generation,serial=c.serial,sequence=c.request_sequence}
	client_send(c,&c.codecs.request,.Physics_Request,packet,tick,.Reliable)
}
@(private)
server_physics_request :: proc(s:^Server($S,$C,$A,$E,$N),index:int,bytes:[]u8,expected:sc.Envelope_Meta){
	meta,_,report:=sc.inspect(bytes);packet:Request_Packet
	_,decoded:=sc.unpack(&s.codecs.request,&packet,bytes,expected)
	peer:=&s.peers[index]
	if report.error!=.None || decoded.error!=.None || packet.generation!=peer.generation || packet.serial!=peer.serial || packet.sequence==0 ||
	   packet.sequence<=peer.request_seen || meta.tick==0 || meta.tick>s.timeline.head || s.timeline.head-meta.tick>=PHYSICS_HISTORY {s.stats.rejected_packets+=1;return}
	peer.request_seen=packet.sequence
	complete_data_destroy(&s.physics.tx[index].data);s.physics.tx[index]={}
	if error:=server_physics_prepare(s,index,.Snapshot,meta.tick);error==.None{server_physics_parts_flush(s,index)}
}

// Only a same-accepted-prefix invariant mismatch enters this first-desync slot.
// Normal prediction repair never calls this function or replaces an artifact.
@(private)
client_physics_desync :: proc(c:^Client($S,$C,$A,$E,$N),expected,actual:bd.Frame_View,tick:u64)->Error{
	if c.physics.trace.ready {c.phase=.Failed;return .None}
	first:=c.timeline.confirmed<tick?c.timeline.confirmed+1:tick
	count:=tick-first+1
	n:=4+int(count)*c.physics.schemas.accepted.wire_size
	if n>bd.DEFAULT_LIMITS.max_input_bytes {c.phase=.Failed;return .Capacity}
	if error:=c.model.complete_codec.reserve(c.model.complete_codec.catalog,u64(n*2));error!=.None{return error}
	inputs,allocation_error:=mem.alloc_bytes(n*2,allocator=c.allocator)
	if allocation_error!=.None {c.model.complete_codec.release(c.model.complete_codec.catalog,u64(n*2));return .Capacity}
	defer {delete(inputs,c.allocator);c.model.complete_codec.release(c.model.complete_codec.catalog,u64(n*2))}
	accepted,predicted:=inputs[:n],inputs[n:]
	complete_put32(accepted[:4],u32(count));complete_put32(predicted[:4],u32(count))
	for i in 0..<int(count){
		at_tick:=first+u64(i);known,found:=accepted_read(&c.physics.accepted,at_tick);if !found{return .Invalid_Frame}
		prior,input_found:=r.read_input(&c.timeline,at_tick);if !input_found {prior=known.batch}
		guess:=Accepted_Input(C,A,N){version=ACCEPTED_PHYSICS_VERSION,epoch=c.cfg.epoch,tick=at_tick,batch=prior}
		at:=4+i*c.physics.schemas.accepted.wire_size
		if sc.encode(&c.physics.schemas.accepted,known,accepted[at:at+c.physics.schemas.accepted.wire_size]).error!=.None ||
		   sc.encode(&c.physics.schemas.accepted,guess,predicted[at:at+c.physics.schemas.accepted.wire_size]).error!=.None{return .Invalid_Frame}
	}
	trace_bytes:=n*2
	for part in bd.Part {trace_bytes+=len(expected.parts[part])+len(actual.parts[part])}
	if error:=c.model.complete_codec.reserve(c.model.complete_codec.catalog,u64(trace_bytes));error!=.None{return error}
	info:=bd.Trace_Context{from_tick=first,to_tick=max(c.timeline.head,tick),depth=u32(max(c.timeline.head,tick)-first+1),source=u64(c.authority),sequence=c.physics.pending_id,accepted_inputs=accepted,predicted_inputs=predicted}
	error:=bd.trace_capture(&c.physics.trace,expected,actual,info,allocator=c.allocator)
	if error!=.None {c.model.complete_codec.release(c.model.complete_codec.catalog,u64(trace_bytes));return .Invalid_Frame}
	c.physics.trace_charge=u64(trace_bytes);c.phase=.Failed
	return .None
}

@(private)
client_physics_apply_pending :: proc(c:^Client($S,$C,$A,$E,$N))->Error{
	if c.physics==nil || c.physics.pending_checkpoint==nil{return .None}
	checkpoint:=c.physics.pending_checkpoint;tick:=checkpoint.frame.tick
	verified:Physics_Verification
	inspection,inspect_error:=complete_inspect(c.physics.pending.bytes,c.model.complete_codec.identity,c.cfg.epoch)
	if inspect_error!=.None {client_physics_drop_pending(c);return .Invalid_Frame}
	if c.physics.waiting_tick!=0 {
		if tick!=c.physics.waiting_tick{return .None}
		error:=client_physics_desync(c,inspection.frame,c.physics.actual_mismatch.frame,tick)
		complete_view_destroy(&c.physics.actual_mismatch);client_physics_drop_pending(c);return error
	}
	if c.spectator {
		known:=c.physics.signatures[tick%PHYSICS_HISTORY]
		if known.epoch==c.cfg.epoch && known.tick==tick && bd.compare(known,inspection.signature)!=.Match {client_physics_drop_pending(c);return .Invalid_Frame}
	}
	c.physics.signatures[tick%PHYSICS_HISTORY]=inspection.signature
	if tick>c.timeline.head {
		// Drivers can catch up through signed accepted facts. Spectators do not
		// predict, so their validated complete snapshot remains the catch-up path.
		if !c.spectator && tick-c.timeline.confirmed>PHYSICS_REPAIR {client_physics_drop_pending(c);return .None}
		if c.facts_contiguous<tick{return .None}
		if c.spectator {
			if c.journal.confirmed>tick {client_physics_drop_pending(c);return .Invalid_Frame}
			gap:=tick-c.journal.confirmed
			if gap>=PHYSICS_HISTORY {client_physics_drop_pending(c);client_resync(c,.History_Missing,tick);return .None}
			for at:=c.journal.confirmed+1;at<=tick;at+=1 {if c.facts[at%PHYSICS_HISTORY].tick!=at {client_physics_drop_pending(c);client_resync(c,.History_Missing,at);return .None}}
			// Reserve all possible confirmation notifications before importing.
			// A deferred import lets the existing presentation drain run this pump.
			if len(c.journal.queue)-c.journal.queue_count<int(gap)*WIRE_EVENTS*2 {return .None}
		} else if len(c.journal.queue)-c.journal.queue_count<PHYSICS_REPAIR*WIRE_EVENTS*2{return .Presentation}
		if error:=r.reset_complete(&c.timeline,checkpoint,c.cfg.epoch);error!=.None{client_physics_drop_pending(c);return .Simulation}
		if error:=client_physics_confirm(c,tick);error!=.None{return error}
		c.stats.snapshot_catchups+=1;c.view_reset+=1
	} else if tick>c.timeline.confirmed {
		if c.facts_contiguous<tick{return .None}
		if error:=client_physics_apply_accepted(c,&verified);error!=.None{return error}
		if c.physics.waiting_tick!=0{return .None}
		if c.timeline.confirmed<tick{return .None}
	}
	if physics_verification_matches(verified,inspection.signature,c.physics.pending_id,c.generation,c.serial) {
		c.physics.verified_compares+=1
	} else {
		c.physics.full_compares+=1
	started,timed:=profile_start(c.profile_clock)
	defer profile_finish(&c.profile_metrics,.Physics_Compare,c.profile_clock,started,timed,c.profile_user,c.profile_sample)
	local,local_error:=r.capture_complete(&c.timeline,tick,c.allocator)
	if local_error!=.None {client_physics_drop_pending(c);return .Invalid_Frame};defer r.complete_checkpoint_destroy(&local)
	actual,actual_error:=complete_view(c.model.complete_codec,&local,&c.physics.schemas.state,&c.physics.schemas.occurrence,c.allocator)
	if actual_error!=.None{return actual_error};defer complete_view_destroy(&actual)
	signature,sign_error:=bd.sign(actual.frame)
	if sign_error!=.None{return .Invalid_Frame}
	if bd.compare(inspection.signature,signature)!=.Match {error:=client_physics_desync(c,inspection.frame,actual.frame,tick);client_physics_drop_pending(c);return error}
	}
	c.authority_frame=checkpoint.frame
	if tick==c.timeline.head {c.held=c.pending.held}
	client_note_observed(c,checkpoint.frame,c.pending.snapshot_id)
	client_retire(c,min(c.pending.action_settled,c.last_outcome))
	client_input_feedback(c,c.pending.input_newest,tick)
	client_physics_drop_pending(c)
	return .None
}

// Drop transient network owners when rebinding scope or requesting a full reset.
// Published Timeline state and the first diagnostic artifact remain owned.
@(private)
client_physics_reset_transient :: proc(c:^Client($S,$C,$A,$E,$N)){
	if c.physics==nil{return}
	client_physics_drop_pending(c)
	for &assembly in c.physics.assemblies {complete_data_destroy(&assembly.data);assembly={}}
	complete_view_destroy(&c.physics.actual_mismatch);c.physics.waiting_tick=0
}
