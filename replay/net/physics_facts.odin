package replay_net

import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"

@(private)
server_physics_send_fact :: proc(s:^Server($S,$C,$A,$E,$N),index:int,tick:u64)->bool{
	peer:=&s.peers[index]
	entry,found:=server_accepted(s,tick);if !found{return false}
	fact:=&s.facts[tick%PHYSICS_HISTORY];if fact.tick!=tick{return false}
	signature:bd.Signature
	reused:=false
	tx:=&s.physics.tx[index]
	// A locally constructed Snapshot already owns the canonical full5 bytes
	// and its signed header. Copy that value before any transport callback;
	// never borrow transfer storage across send or reuse another scope/tick.
	if tx.purpose==.Snapshot && tx.tick==tick && tx.generation==peer.generation && tx.serial==peer.serial && len(tx.data.bytes)>=COMPLETE_HEADER_BYTES {
		candidate,error:=bd.signature_decode(tx.data.bytes[32:COMPLETE_HEADER_BYTES])
		if error==.None && candidate.identity==s.model.complete_codec.identity && candidate.epoch==s.cfg.epoch && candidate.tick==tick {
			signature=candidate;reused=true
		}
	}
	if !reused {
		checkpoint,error:=r.capture_complete(&s.timeline,tick,s.allocator);if error!=.None{return false}
		defer r.complete_checkpoint_destroy(&checkpoint)
		view,view_error:=complete_view(s.model.complete_codec,&checkpoint,&s.physics.schemas.state,&s.physics.schemas.occurrence,s.allocator)
		if view_error!=.None{return false};defer complete_view_destroy(&view)
		sign_error:bd.Error
		signature,sign_error=bd.sign(view.frame);if sign_error!=.None{return false}
	}
	length:=s.physics.schemas.fact.wire_size+s.physics.schemas.accepted.wire_size+bd.SIGNATURE_BYTES+int(fact.count)*s.physics.schemas.occurrence.wire_size
	if length+sc.HEADER_BYTES>len(s.txb){return false}
	body:=s.txb[sc.HEADER_BYTES:sc.HEADER_BYTES+length];at:=0
	header:=Physics_Fact_Header{peer.generation,peer.serial,ACCEPTED_PHYSICS_VERSION,u32(fact.count)}
	if sc.encode(&s.physics.schemas.fact,header,body[:s.physics.schemas.fact.wire_size]).error!=.None{return false};at+=s.physics.schemas.fact.wire_size
	if sc.encode(&s.physics.schemas.accepted,entry,body[at:at+s.physics.schemas.accepted.wire_size]).error!=.None{return false};at+=s.physics.schemas.accepted.wire_size
	if _,error:=bd.signature_encode(signature,body[at:at+bd.SIGNATURE_BYTES]);error!=.None{return false};at+=bd.SIGNATURE_BYTES
	for event in fact.events[:fact.count] {
		if sc.encode(&s.physics.schemas.occurrence,event,body[at:at+s.physics.schemas.occurrence.wire_size]).error!=.None{return false}
		at+=s.physics.schemas.occurrence.wire_size
	}
	meta:=sc.Envelope_Meta{kind=u16(Kind.Physics_Facts),epoch=s.cfg.epoch,tick=tick,content=s.cfg.content}
	if sc.pack_bytes(s.physics.schemas.fact.fingerprint,meta,body,s.txb).error!=.None{return false}
	return server_send(s,peer.connection,.Reliable,s.txb[:sc.HEADER_BYTES+length])==.Sent
}

@(private)
server_physics_peer_flush :: proc(s:^Server($S,$C,$A,$E,$N),index:int){
	peer:=&s.peers[index];tx:=&s.physics.tx[index]
	// Preserve the existing runner contract: a new Welcome includes the tick
	// that applies membership. A pump alone cannot publish an unjoined world.
	if peer.phase==.Pending && !peer.checkpoint_pending{return}
	if peer.checkpoint_pending || peer.phase==.Pending {
		if len(tx.data.bytes)==0 {if error:=server_physics_prepare(s,index,.Welcome);error!=.None{return}}
		server_physics_parts_flush(s,index)
		if peer.phase!=.Running{return}
	}
	// Construct an already-due image before its fact, retaining fact-before-
	// chunk delivery. This reuses existing owned transfer storage and avoids a
	// second checkpoint/view solely to sign the same current tick.
	attempted_snapshot:=false;attempted_tick:u64
	if len(tx.data.bytes)==0 && s.timeline.head!=0 && s.timeline.head-peer.snapshot_sent>=u64(s.cfg.snapshot_every) {
		attempted_snapshot=true;attempted_tick=s.timeline.head
		_=server_physics_prepare(s,index,.Snapshot)
	}
	for _ in 0..<8 {
		if peer.facts_sent>=s.timeline.head{break}
		if s.timeline.head-peer.facts_sent>=PHYSICS_HISTORY{peer.checkpoint_pending=true;return}
		if !server_physics_send_fact(s,index,peer.facts_sent+1){break}
		peer.facts_sent+=1
	}
	if len(tx.data.bytes)!=0 {server_physics_parts_flush(s,index);return}
	if s.timeline.head-peer.snapshot_sent>=u64(s.cfg.snapshot_every) && (!attempted_snapshot || attempted_tick!=s.timeline.head) {
		if error:=server_physics_prepare(s,index,.Snapshot);error!=.None{return}
		server_physics_parts_flush(s,index)
	}
}

@(private)
physics_verdicts_valid :: proc(entry:Accepted_Input($C,$A,$N),events:[]r.Occurrence(Net_Event($E)))->bool{
	seen:[N]bool
	for occurrence in events {
		event:=occurrence.value
		if event.kind!=.Action_Result {continue}
		if event.seat==0 || int(event.seat)>N{return false}
		seat:=int(event.seat-1)
		if seen[seat] || !entry.batch.has_action[seat] || event.sequence!=entry.batch.sequences[seat] ||
		   event.applied!=entry.decisions.applied[seat] || event.reason!=entry.decisions.verdicts[seat]{return false}
		seen[seat]=true
	}
	for present,seat in entry.batch.has_action {if present!=seen[seat]{return false}}
	return true
}
