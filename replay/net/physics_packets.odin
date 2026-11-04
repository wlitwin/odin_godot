package replay_net

import "core:mem"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"

Physics_Window :: struct($C,$A,$E:typeid,$N:int){
	count:int,
	entries:[8]Accepted_Input(C,A,N),
	events:[8][WIRE_EVENTS]r.Occurrence(Net_Event(E)),
	event_counts:[8]int,
}

@(private)
server_accepted :: proc(s:^Server($S,$C,$A,$E,$N),tick:u64)->(Accepted_Input(C,A,N),bool){
	if s.physics==nil {return {},false}
	metadata:=s.physics.metadata[tick%PHYSICS_HISTORY]
	input,found:=r.read_input(&s.timeline,tick)
	if !found || metadata.tick!=tick {return {},false}
	return {version=ACCEPTED_PHYSICS_VERSION,epoch=s.cfg.epoch,tick=tick,batch=input,decisions=metadata.decisions},true
}

@(private)
physics_metadata_encode :: proc(s:^Server($S,$C,$A,$E,$N),tick:u64,base_schema:^sc.Schema,base:$Packet)->(data:[]u8,error:Error){
	window:Physics_Window(C,A,E,N)
	first:=tick>7?tick-7:1
	for at:=first;at<=tick && at!=0;at+=1 {
		entry,found:=server_accepted(s,at)
		if !found {window.count=0;continue} // a complete reset has no unknown pre-baseline history
		index:=window.count;window.entries[index]=entry
		fact:=&s.facts[at%PHYSICS_HISTORY]
		if fact.tick!=at {return nil,.Invalid_Frame}
		window.event_counts[index]=int(fact.count);copy(window.events[index][:],fact.events[:fact.count]);window.count+=1
	}
	n:=base_schema.wire_size+4
	for i in 0..<window.count {n+=s.physics.schemas.accepted.wire_size+4+window.event_counts[i]*s.physics.schemas.occurrence.wire_size}
	if n>65536 {return nil,.Capacity}
	if error:=s.model.complete_codec.reserve(s.model.complete_codec.catalog,u64(n));error!=.None{return nil,error}
	allocation_error:mem.Allocator_Error
	data,allocation_error=mem.alloc_bytes(n,allocator=s.allocator)
	if allocation_error!=.None{s.model.complete_codec.release(s.model.complete_codec.catalog,u64(n));return nil,.Capacity}
	if sc.encode(base_schema,base,data[:base_schema.wire_size]).error!=.None {delete(data,s.allocator);s.model.complete_codec.release(s.model.complete_codec.catalog,u64(n));return nil,.Invalid_Frame}
	at:=base_schema.wire_size;complete_put32(data[at:at+4],u32(window.count));at+=4
	for i in 0..<window.count {
		if sc.encode(&s.physics.schemas.accepted,window.entries[i],data[at:at+s.physics.schemas.accepted.wire_size]).error!=.None {error=.Invalid_Frame;break}
		at+=s.physics.schemas.accepted.wire_size;complete_put32(data[at:at+4],u32(window.event_counts[i]));at+=4
		for event in window.events[i][:window.event_counts[i]] {
			if sc.encode(&s.physics.schemas.occurrence,event,data[at:at+s.physics.schemas.occurrence.wire_size]).error!=.None {error=.Invalid_Frame;break}
			at+=s.physics.schemas.occurrence.wire_size
		}
	}
	if error!=.None {delete(data,s.allocator);s.model.complete_codec.release(s.model.complete_codec.catalog,u64(n));return nil,error}
	return data,.None
}

@(private)
physics_window_decode :: proc(c:^Client($S,$C,$A,$E,$N),bytes:[]u8,base_bytes:int,epoch,tick:u64)->(Physics_Window(C,A,E,N),Error){
	window:Physics_Window(C,A,E,N)
	if len(bytes)<base_bytes+4 {return {},.Invalid_Frame}
	at:=base_bytes;window.count=int(complete_get32(bytes[at:at+4]));at+=4
	if window.count>8 || u64(window.count)>tick {return {},.Invalid_Frame}
	for i in 0..<window.count {
		n:=c.physics.schemas.accepted.wire_size
		if n>len(bytes)-at {return {},.Invalid_Frame}
		if sc.decode(&c.physics.schemas.accepted,&window.entries[i],bytes[at:at+n]).error!=.None {return {},.Invalid_Frame};at+=n
		entry:=&window.entries[i]
		if entry.epoch!=epoch || entry.tick!=tick-u64(window.count-i)+1 || !accepted_validate(entry^,c.model) {return {},.Invalid_Input}
		if len(bytes)-at<4 {return {},.Invalid_Frame}
		count:=int(complete_get32(bytes[at:at+4]));at+=4
		if count>WIRE_EVENTS || count*c.physics.schemas.occurrence.wire_size>len(bytes)-at {return {},.Invalid_Frame}
		window.event_counts[i]=count
		for &event,index in window.events[i][:count] {
			n:=c.physics.schemas.occurrence.wire_size
			if sc.decode(&c.physics.schemas.occurrence,&event,bytes[at:at+n]).error!=.None || event.id.epoch!=epoch || event.id.tick!=entry.tick {return {},.Invalid_Frame};at+=n
			for prior in window.events[i][:index] {if prior.id==event.id {return {},.Invalid_Frame}}
		}
	}
	if at!=len(bytes) {return {},.Invalid_Frame}
	return window,.None
}

@(private)
server_physics_prepare :: proc(s:^Server($S,$C,$A,$E,$N),index:int,purpose:Complete_Purpose,target_tick:u64=0)->Error{
	peer:=&s.peers[index];tx:=&s.physics.tx[index]
	if len(tx.data.bytes)!=0 {return .Wrong_Phase}
	tick:=target_tick==0?s.timeline.head:target_tick
	checkpoint,capture_error:=r.capture_complete(&s.timeline,tick,s.allocator)
	if capture_error!=.None{return .Simulation};defer r.complete_checkpoint_destroy(&checkpoint)
	metadata:[]u8
	error:Error
	serial:=peer.serial
	if purpose==.Welcome {
		if serial==max(u64){return .Capacity};serial+=1
		packet:=Welcome_Packet(S,C,N){generation=peer.generation,serial=serial,seat=peer.seat,echo_ms=peer.echo_ms,
		 action_settled=peer.action_settled,action_received=peer.action_received,frame=checkpoint.frame,held=s.held,completed_count=u8(peer.recent_count)}
		for i in 0..<peer.recent_count {packet.completed[i]=peer.recent[(peer.recent_head+i)%ACTION_CAPACITY]}
		metadata,error=physics_metadata_encode(s,checkpoint.frame.tick,&s.codecs.welcome,packet)
	} else {
		held:=s.held
		if input,found:=r.read_input(&s.timeline,tick);found {held=input.controls}
		packet:=Snapshot_Packet(S,C,N){snapshot_id=s.physics.next_id+1,generation=peer.generation,serial=serial,
		 action_settled=peer.action_settled,input_newest=peer.input_newest,frame=checkpoint.frame,held=held}
		metadata,error=physics_metadata_encode(s,checkpoint.frame.tick,&s.codecs.snapshot,packet)
	}
	if error!=.None{return error}
	defer {s.model.complete_codec.release(s.model.complete_codec.catalog,u64(len(metadata)));delete(metadata,s.allocator)}
	data,encode_error:=complete_encode(s.model.complete_codec,&checkpoint,purpose,metadata,&s.physics.schemas.state,&s.physics.schemas.occurrence,s.allocator)
	if encode_error!=.None{return encode_error}
	if s.physics.next_id==max(u64){complete_data_destroy(&data);return .Capacity}
	s.physics.next_id+=1
	tx^={data=data,id=s.physics.next_id,tick=checkpoint.frame.tick,generation=peer.generation,serial=serial,purpose=purpose,digest=bd.hash_bytes(data.bytes)}
	if purpose==.Welcome {peer.serial=serial;peer.welcome_view={}}
	return .None
}

@(private)
server_physics_parts_flush :: proc(s:^Server($S,$C,$A,$E,$N),index:int){
	peer:=&s.peers[index];tx:=&s.physics.tx[index]
	if len(tx.data.bytes)==0 || tx.waiting_ack {return}
	parts:=(len(tx.data.bytes)+COMPLETE_PART_BYTES-1)/COMPLETE_PART_BYTES
	for tx.part<parts {
		start:=tx.part*COMPLETE_PART_BYTES;n:=min(COMPLETE_PART_BYTES,len(tx.data.bytes)-start)
		header:=Physics_Chunk_Header{tx.generation,tx.serial,tx.id,u32(len(tx.data.bytes)),u32(tx.part),u32(parts),u32(tx.purpose),tx.digest}
		size:=s.physics.schemas.chunk.wire_size
		body:=s.txb[sc.HEADER_BYTES:sc.HEADER_BYTES+size+n]
		if sc.encode(&s.physics.schemas.chunk,header,body[:size]).error!=.None{return}
		copy(body[size:],tx.data.bytes[start:start+n])
		meta:=sc.Envelope_Meta{kind=u16(Kind.Physics_Part),epoch=s.cfg.epoch,tick=tx.tick,content=s.cfg.content}
		if sc.pack_bytes(s.physics.schemas.chunk.fingerprint,meta,body,s.txb).error!=.None{return}
		if server_send(s,peer.connection,.Reliable,s.txb[:sc.HEADER_BYTES+len(body)])!=.Sent{return}
		tx.part+=1
	}
	tx.waiting_ack=true
	if tx.purpose==.Welcome {
		peer.checkpoint_pending=false;peer.phase=.Running;peer.facts_sent=max(peer.facts_sent,tx.tick)
		peer.welcome_view={tick=tx.tick,sent_ms=s.now,valid=true}
	}
	if tx.purpose==.Snapshot {s.physics.views[index][tx.tick%PHYSICS_HISTORY]={proof={id=tx.id,tick=tx.tick,sent_ms=s.now,valid=true},generation=tx.generation,serial=tx.serial}}
	peer.snapshot_sent=tx.tick
}

@(private)
server_physics_ack :: proc(s:^Server($S,$C,$A,$E,$N),index:int,bytes:[]u8,expected:sc.Envelope_Meta){
	ack:Physics_Ack;_,report:=sc.unpack(&s.physics.schemas.ack,&ack,bytes,expected)
	peer:=&s.peers[index];tx:=&s.physics.tx[index]
	if report.error!=.None || ack.generation!=peer.generation || ack.serial!=peer.serial || ack.id!=tx.id || ack.digest!=tx.digest || !tx.waiting_ack {s.stats.rejected_acks+=1;return}
	complete_data_destroy(&tx.data);tx^={}
}
