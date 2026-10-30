#+build darwin, linux
package replay_provision_sqlite

import "core:crypto"
import "core:mem"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import ck "godot:replay/provision/checkpoint"
import a "godot:replay/assets"

PUBLICATION_VERSION :: ck.PUBLICATION_VERSION
PUBLICATION_KIND :: ck.PUBLICATION_KIND
Publication :: ck.Publication
Stored_Checkpoint :: ck.Saved
stored_checkpoint_destroy :: ck.saved_destroy

publication_valid :: ck.publication_valid

// Trusted storage operation, not a public authorization endpoint or authority
// grant. The complete expected coordinator record fences a competing writer.
// Metadata and checkpoint bytes commit in one existing FULL/WAL transaction.
checkpoint_publish :: proc(s:^Store,expected:auth.Record,expected_publication:u64,point:auth.Point,bytes:[]u8,
                           model:net.Model($S,$C,$A,$E,$N),expected_contract:^u64=nil,guard:ck.Commit_Guard={},payload:[]u8=nil,assets:ck.Asset_Policy={})->(Publication,Error) {
	expected:=expected
	if !s.ready || s.connection.transaction || !auth.record_valid(expected) || expected.epoch==0 || !auth.point_valid(point) || point.scope.room!=expected.room || point.scope.content!=expected.content || point.scope.epoch!=expected.epoch || len(bytes)<sc.HEADER_BYTES || len(bytes)>net.MAX_CHECKPOINT_BYTES || len(bytes)!=int(point.archive.bytes) || rec.hash(bytes)!=point.archive.hash {return {},.Invalid}
	cp:net.Checkpoint(S,C,A,N);defer net.checkpoint_destroy(&cp)
	if net.checkpoint_decode(&cp,bytes,model,expected.content)!=.None || !cp.settings.require_permit || cp.header.epoch!=expected.epoch || cp.frame.tick!=point.archive.tick {return {},.Schema}
	if expected_contract!=nil && cp.header.contract!=expected_contract^ {return {},.Schema}
	view:=a.Bundle_View{root=bytes}
	if len(payload)>0 {v,error:=ck.package_view(payload,point);if error!=.None {return {},.Schema};view=v}
	if ck.assets_validate(assets,bytes,&view)!=.None {return {},.Schema}
	owner:auth.Member;allowed:=false
	for member in expected.members {if member.identity==expected.owner {
		owner=member;allowed=member.enabled && member.can_host && member.trusted_authority && (expected.policy.mode==.Cooperative || member.infrastructure);break
	}}
	if !allowed {return {},.Invalid}
	if cp.header.local_seat!=0 {
		matches:=false
		for peer in cp.peers {if peer.local && peer.seat==cp.header.local_seat && peer.token_hash==owner.game_token_hash {matches=true;break}}
		if !matches {return {},.Invalid}
	} else if expected.policy.mode!=.Dedicated {return {},.Invalid}
	if !execute(s,"BEGIN IMMEDIATE;") {return {},.Write}
	s.connection.transaction=true;committed:=false
	defer {if !committed {execute(s,"ROLLBACK;")};s.connection.transaction=false;crypto.zero_explicit(raw_data(s.buffer),len(s.buffer))}
	previous,found,loaded:=publication_load(s,expected.room,expected.content,s.allocator);defer stored_checkpoint_destroy(&previous)
	if loaded!=.None {return {},loaded}
	if found && previous.publication.publisher==expected.owner && previous.publication.point==point && previous.publication.contract==cp.header.contract {
		previous_view:=a.Bundle_View{root=previous.bytes}
		if len(previous.payload)>0 {v,error:=ck.package_view(previous.payload,point);if error!=.None {return {},.Schema};previous_view=v}
		if ck.assets_validate(assets,previous.bytes,&previous_view)!=.None {return {},.Schema}
		// A lost acknowledgement can be replayed without writing or reviving the
		// old authority, even if another coordinator decision has since committed.
		return previous.publication,.None
	}
	current,present,error:=load(s,expected.room,expected.content);defer crypto.zero_explicit(&current,size_of(current))
	if error!=.None {return {},error}
	if !present || current.record!=expected || current.record.released {return {},.Conflict}
	if (found && previous.publication.revision!=expected_publication) || (!found && expected_publication!=0) || expected_publication==max(u64) {return {},.Conflict}
	if found {
		old:=previous.publication.point
		if point.scope.epoch<old.scope.epoch || (point.scope.epoch==old.scope.epoch && (point.archive.sequence<=old.archive.sequence || point.archive.tick<old.archive.tick)) {return {},.Conflict}
	}
	next:=Publication{PUBLICATION_VERSION,expected_publication+1,expected.revision,expected.coordinator_generation,cp.header.contract,expected.owner,point}
	metadata:=make([]u8,sc.HEADER_BYTES+s.publication_codec.wire_size,s.allocator);defer delete(metadata,s.allocator)
	if sc.pack(&s.publication_codec,next,{kind=PUBLICATION_KIND,epoch=u64(PUBLICATION_VERSION),tick=next.revision,content=expected.content},metadata).error!=.None {return {},.Schema}
	statement:sql.Statement
	query:cstring=found ? "UPDATE replay_room_checkpoint SET metadata=?2,bytes=?3 WHERE room=?1;" : "INSERT INTO replay_room_checkpoint(room,metadata,bytes) VALUES(?1,?2,?3);"
	if sql.sqlite3_prepare_v2(s.connection.db,query,-1,&statement,nil)!=0 {return {},.Write}
	key:=room_key(expected.room)
	ok:=sql.sqlite3_bind_blob(statement,1,raw_data(key[:]),8,nil)==0 && sql.sqlite3_bind_blob(statement,2,raw_data(metadata),i32(len(metadata)),nil)==0 && sql.sqlite3_bind_blob(statement,3,raw_data(bytes),i32(len(bytes)),nil)==0 && sql.sqlite3_step(statement)==101
	sql.sqlite3_finalize(statement)
	if !ok {return {},.Write}
	if !package_store(s,expected.room,payload) {return {},.Write}
	if guard.allow!=nil && !guard.allow(guard.user,expected) {return {},.Conflict}
	if !execute(s,"COMMIT;") {return {},.Write}
	committed=true
	return next,.None
}

// Returns an owned copy. Integrity/context checks precede publication to the
// caller. A model-specific load below additionally validates the whole checkpoint.
publication_load :: proc(s:^Store,room,content:u64,allocator:=context.allocator)->(Stored_Checkpoint,bool,Error) {
	if !s.ready || room==0 || content==0 {return {},false,.Invalid}
	statement:sql.Statement
	if sql.sqlite3_prepare_v2(s.connection.db,"SELECT c.metadata,c.bytes,p.bytes,p.room FROM replay_room_checkpoint c LEFT JOIN replay_room_checkpoint_package p ON p.room=c.room WHERE c.room=?1;",-1,&statement,nil)!=0 {return {},false,.Read}
	defer sql.sqlite3_finalize(statement)
	key:=room_key(room);if sql.sqlite3_bind_blob(statement,1,raw_data(key[:]),8,nil)!=0 {return {},false,.Read}
	result:=sql.sqlite3_step(statement);if result==101 {return {},false,.None};if result!=100 {return {},false,.Read}
	meta_count:=sql.sqlite3_column_bytes(statement,0);meta_ptr:=sql.sqlite3_column_blob(statement,0)
	count:=sql.sqlite3_column_bytes(statement,1);ptr:=sql.sqlite3_column_blob(statement,1)
	if meta_count!=i32(sc.HEADER_BYTES+s.publication_codec.wire_size) || meta_ptr==nil || count<sc.HEADER_BYTES || count>net.MAX_CHECKPOINT_BYTES || ptr==nil {return {},false,.Read}
	publication:Publication
	meta,decoded:=sc.unpack(&s.publication_codec,&publication,(cast([^]u8)meta_ptr)[:meta_count],{kind=PUBLICATION_KIND,epoch=u64(PUBLICATION_VERSION),content=content})
	if decoded.error!=.None || !publication_valid(publication) || meta.tick!=publication.revision || publication.point.scope.room!=room || publication.point.scope.content!=content || publication.point.archive.bytes!=u32(count) {return {},false,.Read}
	data:=(cast([^]u8)ptr)[:count]
	if rec.hash(data)!=publication.point.archive.hash {return {},false,.Read}
	inner,fingerprint,inspected:=sc.inspect(data)
	if inspected.error!=.None || inner.kind!=net.CHECKPOINT_KIND || inner.epoch!=publication.point.scope.epoch || inner.content!=content || inner.tick!=publication.point.archive.tick {return {},false,.Read}
	_,_,valid:=sc.unpack_bytes(fingerprint,data,inner);if valid.error!=.None {return {},false,.Read}
	payload_count:=sql.sqlite3_column_bytes(statement,2);payload_ptr:=sql.sqlite3_column_blob(statement,2)
	if payload_count<0 || payload_count>net.MAX_CHECKPOINT_BYTES || (payload_count!=0 && payload_ptr==nil) {return {},false,.Read}
	if sql.sqlite3_column_blob(statement,3)!=nil && payload_count<sc.HEADER_BYTES {return {},false,.Read}
	payload:[]u8
	if payload_count>0 {
		borrowed:=(cast([^]u8)payload_ptr)[:payload_count]
		if _,error:=ck.package_view(borrowed,publication.point);error!=.None {return {},false,.Read}
		payload=make([]u8,payload_count,allocator);copy(payload,borrowed)
	}
	owned:=make([]u8,len(data),allocator);copy(owned,data)
	if sql.sqlite3_step(statement)!=101 {delete(owned,allocator);delete(payload,allocator);return {},false,.Read}
	return {ready=true,publication=publication,bytes=owned,allocator=allocator,payload=payload},true,.None
}

checkpoint_load :: proc(s:^Store,room,content:u64,model:net.Model($S,$C,$A,$E,$N),allocator:=context.allocator,assets:ck.Asset_Policy={})->(Stored_Checkpoint,bool,Error) {
	value,found,error:=publication_load(s,room,content,allocator)
	if error!=.None || !found {return value,found,error}
	cp:net.Checkpoint(S,C,A,N);defer net.checkpoint_destroy(&cp)
	if net.checkpoint_decode(&cp,value.bytes,model,content,allocator)!=.None || !cp.settings.require_permit || cp.header.contract!=value.publication.contract {stored_checkpoint_destroy(&value);return {},false,.Schema}
	view:=a.Bundle_View{root=value.bytes}
	if len(value.payload)>0 {v,error:=ck.package_view(value.payload,value.publication.point);if error!=.None {stored_checkpoint_destroy(&value);return {},false,.Schema};view=v}
	if ck.assets_validate(assets,value.bytes,&view)!=.None {stored_checkpoint_destroy(&value);return {},false,.Schema}
	return value,true,.None
}

@(private)
package_store :: proc(s:^Store,room:u64,bytes:[]u8)->bool {
	statement:sql.Statement
	query:cstring=len(bytes)==0 ? "DELETE FROM replay_room_checkpoint_package WHERE room=?1;" : "INSERT INTO replay_room_checkpoint_package(room,bytes) VALUES(?1,?2) ON CONFLICT(room) DO UPDATE SET bytes=excluded.bytes;"
	if sql.sqlite3_prepare_v2(s.connection.db,query,-1,&statement,nil)!=0 {return false};defer sql.sqlite3_finalize(statement)
	key:=room_key(room)
	if sql.sqlite3_bind_blob(statement,1,raw_data(key[:]),8,nil)!=0 {return false}
	if len(bytes)>0 && sql.sqlite3_bind_blob(statement,2,raw_data(bytes),i32(len(bytes)),nil)!=0 {return false}
	return sql.sqlite3_step(statement)==101
}
