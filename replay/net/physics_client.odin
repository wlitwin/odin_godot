package replay_net

import "core:reflect"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"
import view "godot:replay/view"

@(private)
client_physics_fact :: proc(c:^Client($S,$C,$A,$E,$N),bytes:[]u8,expected:sc.Envelope_Meta)->Error{
	if c.phase!=.Running{return .None}
	meta,body,report:=sc.unpack_bytes(c.physics.schemas.fact.fingerprint,bytes,expected)
	header:Physics_Fact_Header;at:=c.physics.schemas.fact.wire_size
	if report.error!=.None || len(body)<at || sc.decode(&c.physics.schemas.fact,&header,body[:at]).error!=.None ||
	   header.generation!=c.generation || header.serial!=c.serial || header.version!=ACCEPTED_PHYSICS_VERSION || header.count>WIRE_EVENTS {c.stats.rejected_packets+=1;return .None}
	if len(body)!=at+c.physics.schemas.accepted.wire_size+bd.SIGNATURE_BYTES+int(header.count)*c.physics.schemas.occurrence.wire_size {c.stats.rejected_packets+=1;return .None}
	entry:Accepted_Input(C,A,N)
	if sc.decode(&c.physics.schemas.accepted,&entry,body[at:at+c.physics.schemas.accepted.wire_size]).error!=.None || entry.epoch!=c.cfg.epoch || entry.tick!=meta.tick || !accepted_validate(entry,c.model) {c.stats.rejected_packets+=1;return .None};at+=c.physics.schemas.accepted.wire_size
	signature,signature_error:=bd.signature_decode(body[at:at+bd.SIGNATURE_BYTES]);at+=bd.SIGNATURE_BYTES
	if signature_error!=.None || signature.identity!=c.model.complete_codec.identity || signature.epoch!=c.cfg.epoch || signature.tick!=entry.tick {c.stats.rejected_packets+=1;return .None}
	fact:=Facts_Packet(E){generation=c.generation,serial=c.serial,tick=entry.tick,count=u16(header.count)}
	for &event,index in fact.events[:header.count] {
		n:=c.physics.schemas.occurrence.wire_size
		if sc.decode(&c.physics.schemas.occurrence,&event,body[at:at+n]).error!=.None || event.id.epoch!=c.cfg.epoch || event.id.tick!=entry.tick {c.stats.rejected_packets+=1;return .None};at+=n
		for prior in fact.events[:index] {if prior.id==event.id {c.stats.rejected_packets+=1;return .None}}
	}
	if !physics_verdicts_valid(entry,fact.events[:fact.count]) {c.stats.rejected_packets+=1;return .None}
	if entry.tick<=c.physics.accepted.baseline{return .None}
	if error:=accepted_can_note(&c.physics.accepted,entry,c.timeline.confirmed,c.timeline.head,max(c.authority_tick_seen,entry.tick));error!=.None {c.stats.rejected_inputs+=1;return .None}
	prior:=&c.facts[entry.tick%PHYSICS_HISTORY]
	if prior.tick==entry.tick && !reflect.equal(prior^,fact) {c.stats.rejected_packets+=1;return .None}
	old_signature:=c.physics.signatures[entry.tick%PHYSICS_HISTORY]
	if old_signature.epoch==c.cfg.epoch && old_signature.tick==entry.tick && old_signature!=signature {c.stats.rejected_packets+=1;return .None}
	if entry.tick-c.timeline.confirmed>=PHYSICS_HISTORY {client_resync(c,.Facts_Overflow,entry.tick);return .None}
	_ = accepted_note(&c.physics.accepted,entry,c.timeline.confirmed,c.timeline.head,max(c.authority_tick_seen,entry.tick))
	c.physics.signatures[entry.tick%PHYSICS_HISTORY]=signature
	prior^=fact;c.authority_tick_seen=max(c.authority_tick_seen,entry.tick)
	for c.facts_contiguous<max(u64) {
		next:=c.facts_contiguous+1;_,found:=accepted_read(&c.physics.accepted,next)
		if !found || c.facts[next%PHYSICS_HISTORY].tick!=next{break};c.facts_contiguous=next
	}
	c.last_received=c.now
	// Coalesce partial prefixes at the existing pump presentation boundary.
	// Apply a complete predicted tail now, before farther facts can reach H128.
	if c.facts_contiguous>=c.timeline.head {return client_physics_apply_accepted(c)}
	return .None
}

@(private)
client_physics_merge_window :: proc(c:^Client($S,$C,$A,$E,$N),window:^Physics_Window(C,A,E,N),authority_head:u64)->Error{
	for i in 0..<window.count {
		entry:=window.entries[i]
		if !physics_verdicts_valid(entry,window.events[i][:window.event_counts[i]]){return .Invalid_Input}
		prior,found:=accepted_read(&c.physics.accepted,entry.tick)
		if found && !reflect.equal(prior,entry){return .Invalid_Input}
		if entry.tick<=c.timeline.confirmed || entry.tick<=c.physics.accepted.baseline {continue}
		if error:=accepted_can_note(&c.physics.accepted,entry,c.timeline.confirmed,c.timeline.head,authority_head);error!=.None{return error}
		fact:=&c.facts[entry.tick%PHYSICS_HISTORY]
		if fact.tick==entry.tick && (int(fact.count)!=window.event_counts[i] || !reflect.equal(fact.events[:fact.count],window.events[i][:window.event_counts[i]],true)){return .Invalid_Input}
	}
	for i in 0..<window.count {
		entry:=window.entries[i]
		if entry.tick<=c.timeline.confirmed || entry.tick<=c.physics.accepted.baseline{continue}
		_ = accepted_note(&c.physics.accepted,entry,c.timeline.confirmed,c.timeline.head,authority_head)
		fact:=&c.facts[entry.tick%PHYSICS_HISTORY]
		fact^={generation=c.generation,serial=c.serial,tick=entry.tick,count=u16(window.event_counts[i])};copy(fact.events[:],window.events[i][:window.event_counts[i]])
	}
	c.authority_tick_seen=max(c.authority_tick_seen,authority_head)
	for c.facts_contiguous<max(u64) {
		next:=c.facts_contiguous+1;_,found:=accepted_read(&c.physics.accepted,next)
		if !found || c.facts[next%PHYSICS_HISTORY].tick!=next{break};c.facts_contiguous=next
	}
	return .None
}

Physics_Verification :: struct {
	valid:bool,
	signature:bd.Signature,
	pending_id,generation,serial:u64,
}

// Operation-local proof only; callers must never retain it for a later packet.
physics_verification_matches :: proc(proof:Physics_Verification,expected:bd.Signature,pending_id,generation,serial:u64)->bool {
	return proof.valid && pending_id!=0 && proof.pending_id==pending_id && proof.generation==generation && proof.serial==serial && proof.signature==expected
}

@(private)
Physics_Check :: struct($S,$C,$A,$E:typeid,$N:int){client:^Client(S,C,A,E,N),expected:bd.Signature,actual:Complete_View,mismatch:bool,held:[N]C}

@(private)
client_physics_apply_accepted :: proc(c:^Client($S,$C,$A,$E,$N),verified:^Physics_Verification=nil)->Error{
	if verified!=nil {verified^={}}
	if c.physics.waiting_tick!=0 || c.spectator || !c.has_world{return .None}
	first:=c.timeline.confirmed+1
	target:=min(c.facts_contiguous,c.timeline.head)
	for target>=first {
		sig:=c.physics.signatures[target%PHYSICS_HISTORY]
		if sig.epoch==c.cfg.epoch && sig.tick==target {break}
		target-=1
	}
	if target<first{return .None}
	if c.timeline.head-first+1>PHYSICS_REPAIR {client_resync(c,.History_Missing,first);return .None}
	// Reserve presentation queue headroom before committing simulation work.
	if len(c.journal.queue)-c.journal.queue_count<PHYSICS_REPAIR*WIRE_EVENTS*2 {return .Presentation}
	scope_id,scope_generation,scope_serial:=c.physics.pending_id,c.generation,c.serial
	context_value:=Physics_Check(S,C,A,E,N){client=c,expected=c.physics.signatures[target%PHYSICS_HISTORY],held=c.held}
	rewrite:=r.Input_Rewrite(Batch(C,A,N)){user=&context_value,apply=proc(pointer:rawptr,tick:u64,original:Batch(C,A,N))->Batch(C,A,N){
		context_value:=cast(^Physics_Check(S,C,A,E,N))pointer;c:=context_value.client
		accepted,found:=accepted_read(&c.physics.accepted,tick)
		if found {context_value.held=accepted.batch.controls;return accepted.batch}
		input:=original
		for &control,seat in input.controls {if seat+1!=int(c.seat){context_value.held[seat]=c.model.hold(context_value.held[seat]);control=context_value.held[seat];input.has_action[seat]=false;input.actions[seat]={};input.sequences[seat]=0;input.rejections[seat]=.None}}
		return input
	}}
	check:=r.Revision_Check(S,Net_Event(E)){tick=target,user=&context_value,check=proc(pointer:rawptr,checkpoint:^r.Complete_Checkpoint(S,Net_Event(E)))->r.Error{
		context_value:=cast(^Physics_Check(S,C,A,E,N))pointer;c:=context_value.client
		actual,error:=complete_view(c.model.complete_codec,checkpoint,&c.physics.schemas.state,&c.physics.schemas.occurrence,c.allocator)
		if error!=.None{return .Resource_Limit}
		signature,sign_error:=bd.sign(actual.frame)
		if sign_error!=.None{complete_view_destroy(&actual);return .External_State}
		if bd.compare(context_value.expected,signature)!=.Match {context_value.actual=actual;context_value.mismatch=true;return .Diverged_External}
		complete_view_destroy(&actual);return .None
	}}
	c.physics.last_planned_depth=c.timeline.head-first+1;c.physics.last_checked_prefix=target-first+1
	started,timed:=profile_start(c.profile_clock)
	result:=r.revise_inputs_checked(&c.timeline,first,rewrite,check)
	c.physics.last_executed_steps=u64(result.steps)
	profile_finish(&c.profile_metrics,.Physics_Repair,c.profile_clock,started,timed,c.profile_user,c.profile_sample)
	if result.error!=.None {
		c.physics.last_frame_error=result.error
		if context_value.mismatch {
			complete_view_destroy(&c.physics.actual_mismatch);c.physics.actual_mismatch=context_value.actual;c.physics.waiting_tick=target
			client_physics_request(c,target);return .None
		}
		complete_view_destroy(&context_value.actual)
		if result.error==.Repair_Limit || result.error==.Resource_Limit || result.error==.History_Missing {client_resync(c,.History_Missing,first);return .None}
		return .Simulation
	}
	c.physics.repairs+=1;c.stats.corrections+=1;c.stats.replayed_ticks+=u64(result.steps);c.held=context_value.held
	if error:=client_physics_confirm(c,target);error!=.None{return error}
	if verified!=nil && scope_id!=0 && scope_id==c.physics.pending_id && scope_generation==c.generation && scope_serial==c.serial && context_value.expected.epoch==c.cfg.epoch && context_value.expected.identity==c.model.complete_codec.identity {
		verified^={valid=true,signature=context_value.expected,pending_id=scope_id,generation=scope_generation,serial=scope_serial}
	}
	return .None
}

@(private)
client_physics_confirm :: proc(c:^Client($S,$C,$A,$E,$N),target:u64)->Error{
	previous:=c.journal.confirmed
	for tick:=previous+1;tick<=target && tick!=0;tick+=1 {
		fact:=&c.facts[tick%PHYSICS_HISTORY];if fact.tick!=tick{return .Invalid_Frame}
		if error:=view.sync_tick(&c.journal,tick,fact.events[:fact.count]);error!=.None{return client_presentation_failure(c,.Authority_Batch,tick,error)}
		for occurrence in fact.events[:fact.count] {event:=occurrence.value;if event.kind==.Action_Result && event.seat==c.seat {client_outcome(c,Action_Outcome{event.sequence,tick,event.applied,event.reason})}}
	}
	if error:=r.confirm_through(&c.timeline,target);error!=.None{return .Simulation}
	if error:=view.advance_time(&c.journal,target,c.journal.watch_tick);error!=.None{return client_presentation_failure(c,.Confirmation,target,error)}
	for tick:=target+1;tick<=c.timeline.head && tick!=0;tick+=1 {if error:=client_sync_predicted(c,tick);error!=.None{return error}}
	for tick:=previous+1;tick<=target && tick!=0;tick+=1 {
		if frame,found:=r.read_values(&c.timeline,tick);found {client_note_observed(c,frame,0)}
	}
	c.watch_clock=f64(target)
	c.physics.confirmed_matches+=1
	return .None
}

@(private)
client_physics_present :: proc(c:^Client($S,$C,$A,$E,$N),dt:f64)->Error{
	if error:=client_physics_apply_pending(c);error!=.None{return error}
	if error:=client_physics_apply_accepted(c);error!=.None{return error}
	watch:=max(c.journal.watch_tick,c.timeline.confirmed)
	if error:=view.advance_time(&c.journal,c.journal.confirmed,watch);error!=.None{return client_presentation_failure(c,.Watch,watch,error)}
	return .None
}
