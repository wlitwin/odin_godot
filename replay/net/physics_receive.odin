package replay_net

import "core:mem"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import sc "godot:replay/schema"

@(private)
client_physics_part :: proc(c:^Client($S,$C,$A,$E,$N),bytes:[]u8,expected:sc.Envelope_Meta)->Error{
	meta,body,report:=sc.unpack_bytes(c.physics.schemas.chunk.fingerprint,bytes,expected)
	header:Physics_Chunk_Header;size:=c.physics.schemas.chunk.wire_size
	if report.error!=.None || len(body)<size || sc.decode(&c.physics.schemas.chunk,&header,body[:size]).error!=.None {c.stats.rejected_packets+=1;return .None}
	purpose:=Complete_Purpose(header.purpose)
	if header.generation==0 || header.serial==0 || header.id==0 || header.total<COMPLETE_HEADER_BYTES+32 || header.total>COMPLETE_MAX_BYTES ||
	   (purpose!=.Welcome && purpose!=.Snapshot) || header.parts!=u32((int(header.total)+COMPLETE_PART_BYTES-1)/COMPLETE_PART_BYTES) ||
	   header.parts==0 || header.parts>32 || header.index>=header.parts ||
	   len(body)-size!=min(COMPLETE_PART_BYTES,int(header.total)-int(header.index)*COMPLETE_PART_BYTES) {c.stats.rejected_packets+=1;return .None}
	if purpose==.Snapshot && (c.phase!=.Running || header.generation!=c.generation || header.serial!=c.serial) {c.stats.rejected_packets+=1;return .None}
	if purpose==.Welcome && (header.generation<c.generation || header.generation==c.generation && header.serial<c.serial) {return .None}
	index:=purpose==.Welcome?0:1
	assembly:=&c.physics.assemblies[index]
	if assembly.id!=header.id {
		if assembly.id>header.id{return .None}
		if error:=c.model.complete_codec.reserve(c.model.complete_codec.catalog,u64(header.total));error!=.None {c.stats.rejected_packets+=1;return .None}
		storage,allocation_error:=mem.alloc_bytes(int(header.total),allocator=c.allocator)
		if allocation_error!=.None {c.model.complete_codec.release(c.model.complete_codec.catalog,u64(header.total));return .Capacity}
		owned,owner_error:=complete_data_adopt(storage,c.allocator,c.model.complete_codec)
  if owner_error!=.None{delete(storage,c.allocator);c.model.complete_codec.release(c.model.complete_codec.catalog,u64(header.total));return owner_error}
		complete_data_destroy(&assembly.data)
		assembly^={id=header.id,tick=meta.tick,generation=header.generation,serial=header.serial,purpose=purpose,digest=header.digest,
		 data=owned,parts=int(header.parts)}
	}
	if len(assembly.data.bytes)!=int(header.total) || assembly.tick!=meta.tick || assembly.generation!=header.generation || assembly.serial!=header.serial || assembly.digest!=header.digest || assembly.parts!=int(header.parts) {
		complete_data_destroy(&assembly.data);assembly^={};c.stats.rejected_packets+=1;return .None
	}
	start:=int(header.index)*COMPLETE_PART_BYTES;source:=body[size:];bit:=u64(1)<<uint(header.index)
	if assembly.mask[0]&bit!=0 {
		if string(assembly.data.bytes[start:start+len(source)])!=string(source) {complete_data_destroy(&assembly.data);assembly^={};c.stats.rejected_packets+=1}
		return .None
	}
	copy(assembly.data.bytes[start:start+len(source)],source);assembly.mask[0]|=bit;assembly.received+=1
	if assembly.received!=assembly.parts{return .None}
	defer {complete_data_destroy(&assembly.data);assembly^={}}
	if bd.hash_bytes(assembly.data.bytes)!=assembly.digest {c.stats.rejected_packets+=1;return .None}
	inspect_started,inspect_timed:=profile_start(c.profile_clock)
	inspection,inspect_error:=complete_inspect(assembly.data.bytes,c.model.complete_codec.identity,c.cfg.epoch)
	profile_finish(&c.profile_metrics,.Physics_Inspect,c.profile_clock,inspect_started,inspect_timed,c.profile_user,c.profile_sample)
	if inspect_error!=.None || inspection.purpose!=purpose || inspection.signature.tick!=meta.tick {c.stats.rejected_packets+=1;return .None}
	if purpose==.Welcome {
		packet:Welcome_Packet(S,C,N)
		if len(inspection.metadata)<c.codecs.welcome.wire_size || sc.decode(&c.codecs.welcome,&packet,inspection.metadata[:c.codecs.welcome.wire_size]).error!=.None ||
		   packet.generation!=header.generation || packet.serial!=header.serial || packet.frame.tick!=meta.tick || packet.completed_count>ACTION_CAPACITY ||
		   int(packet.seat)>N || (packet.seat==0)!=c.spectator || !replica_valid(c.model,packet.frame.state,packet.held,Recipient{packet.seat,c.spectator}) || !welcome_valid(packet) {c.stats.rejected_packets+=1;return .None}
		if packet.generation==c.generation && packet.serial==c.serial && c.has_world {client_physics_ack(c,header);return .None}
		_,window_error:=physics_window_decode(c,inspection.metadata,c.codecs.welcome.wire_size,c.cfg.epoch,meta.tick)
		if window_error!=.None{c.stats.rejected_packets+=1;return .None}
		decode_started,decode_timed:=profile_start(c.profile_clock)
		checkpoint,decode_error:=complete_decode_image(c.model.complete_codec,inspection,packet.frame,&c.physics.schemas.state,&c.physics.schemas.occurrence,c.allocator)
		profile_finish(&c.profile_metrics,.Physics_Decode,c.profile_clock,decode_started,decode_timed,c.profile_user,c.profile_sample)
		if decode_error!=.None {c.stats.rejected_packets+=1;return .None};defer r.complete_checkpoint_destroy(&checkpoint)
		client_welcome_core(c,packet,&checkpoint)
		if c.has_world && c.generation==header.generation && c.serial==header.serial {
			for &entry in c.physics.accepted.entries {entry={}}
			c.physics.accepted.epoch=c.cfg.epoch;c.physics.accepted.baseline=packet.frame.tick;c.physics.accepted.newest=packet.frame.tick
			client_physics_ack(c,header)
		}
		return .None
	}
	packet:Snapshot_Packet(S,C,N)
	if len(inspection.metadata)<c.codecs.snapshot.wire_size || sc.decode(&c.codecs.snapshot,&packet,inspection.metadata[:c.codecs.snapshot.wire_size]).error!=.None ||
	   packet.generation!=c.generation || packet.serial!=c.serial || packet.frame.tick!=meta.tick || packet.snapshot_id!=header.id ||
	   !replica_valid(c.model,packet.frame.state,packet.held,Recipient{c.seat,c.spectator}) {c.stats.rejected_packets+=1;return .None}
	window,window_error:=physics_window_decode(c,inspection.metadata,c.codecs.snapshot.wire_size,c.cfg.epoch,meta.tick)
	if window_error!=.None{c.stats.rejected_packets+=1;return .None}
	decode_started,decode_timed:=profile_start(c.profile_clock)
	checkpoint,decode_error:=complete_decode_image(c.model.complete_codec,inspection,packet.frame,&c.physics.schemas.state,&c.physics.schemas.occurrence,c.allocator)
	profile_finish(&c.profile_metrics,.Physics_Decode,c.profile_clock,decode_started,decode_timed,c.profile_user,c.profile_sample)
	if decode_error!=.None {c.stats.rejected_packets+=1;return .None}
	if error:=client_physics_merge_window(c,&window,meta.tick);error!=.None {r.complete_checkpoint_destroy(&checkpoint);c.stats.rejected_packets+=1;return .None}
	if c.physics.pending_checkpoint!=nil {r.complete_checkpoint_destroy(c.physics.pending_checkpoint);mem.free(c.physics.pending_checkpoint,c.allocator)}
	complete_data_destroy(&c.physics.pending)
	c.physics.pending_checkpoint=new(r.Complete_Checkpoint(S,Net_Event(E)),c.allocator);c.physics.pending_checkpoint^=checkpoint
	c.physics.pending=assembly.data;assembly.data={};c.physics.pending_id=header.id;c.physics.pending_purpose=purpose
	c.pending=packet;c.has_pending=true
	client_physics_ack(c,header)
	return client_physics_apply_pending(c)
}

@(private)
client_physics_ack :: proc(c:^Client($S,$C,$A,$E,$N),header:Physics_Chunk_Header){
	ack:=Physics_Ack{header.generation,header.serial,header.id,header.digest}
	client_send(c,&c.physics.schemas.ack,.Physics_Ack,ack,c.timeline.head,.Reliable)
}
