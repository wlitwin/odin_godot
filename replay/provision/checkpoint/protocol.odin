package replay_checkpoint

import "core:crypto"
import "core:crypto/hmac"
import auth "godot:replay/authority"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

VERSION :: u16(3)
REQUEST_KIND :: u16(0x6351)
REPLY_KIND :: u16(0x6352)
UPSTREAM_KIND :: u16(0x6353)
DOWNSTREAM_KIND :: u16(0x6354)
TRANSFER_BASE :: u16(0x6360)
PACKET_BYTES :: 2048
Verb :: enum u8 {Upload, Download, Status, Restore}
Request :: struct {
	version: u16,
	verb: Verb,
	room, content, sequence, generation: u64,
	identity: auth.Identity,
	nonce: auth.Nonce,
	revision, contract: u64,
	point: auth.Point,
	authority_epoch:u64,
	payload:Payload,
}
Reply :: struct {request: Request, request_hash: [32]u8, error: Error, transfer: u64, complete: bool, publication: Publication,
	view:auth.View,recovery_result:auth.Error,replayed:bool,payload:Payload}
Data :: struct {
	room, content, sequence, generation, transfer: u64,
	identity: auth.Identity,
	nonce: auth.Nonce,
	request_hash: [32]u8,
	count: u16,
	bytes: [tf.CHUNK_BYTES+128]u8,
}
Codecs :: struct {request, reply, data: sc.Schema}
codecs_init :: proc(c:^Codecs,allocator:=context.allocator)->bool {
	if c.request.initialized || c.reply.initialized || c.data.initialized {return false}
	if sc.init(&c.request,Request,allocator=allocator).error!=.None || sc.init(&c.reply,Reply,allocator=allocator).error!=.None || sc.init(&c.data,Data,allocator=allocator).error!=.None || max(c.request.wire_size,c.reply.wire_size,c.data.wire_size)+sc.HEADER_BYTES+32>PACKET_BYTES {codecs_destroy(c);return false}
	return true
}
codecs_destroy :: proc(c:^Codecs) {sc.destroy(&c.request);sc.destroy(&c.reply);sc.destroy(&c.data)}
request_valid :: proc(q:Request)->bool {
	if q.version!=VERSION || q.verb>.Restore || q.room==0 || q.content==0 || q.sequence==0 || q.generation==0 || !auth.identity_valid(q.identity) || q.nonce==(auth.Nonce{}) {return false}
	if q.verb!=.Upload && q.payload!=(Payload{}) {return false}
	if q.verb==.Upload && q.payload!=(Payload{}) && (!payload_valid(q.payload) || q.payload.kind!=PACKAGE_KIND) {return false}
	if q.verb==.Restore {return q.authority_epoch>0 && q.revision>0 && auth.point_valid(q.point) && q.point.scope.room==q.room && q.point.scope.content==q.content}
	if q.authority_epoch!=0 {return false}
	if q.verb==.Upload {return auth.point_valid(q.point) && q.point.scope.room==q.room && q.point.scope.content==q.content}
	return q.point==(auth.Point{}) && (q.verb!=.Status || q.revision==0)
}
request_pack :: proc(c:^Codecs,q:Request,key:auth.Key,dst:[]u8)->int {
	if !request_valid(q) {return 0};return pack(&c.request,q,key,REQUEST_KIND,q.content,q.sequence,dst)
}
@(private)
mac :: proc(key:auth.Key,kind:u16,bytes:[]u8)->[32]u8 {
	k:=key;h:hmac.Context;hmac.init(&h,.SHA256,k[:])
	domain:="replay-room-checkpoint-v3";hmac.update(&h,transmute([]u8)domain)
	tag_kind:=[2]u8{u8(kind),u8(kind>>8)};hmac.update(&h,tag_kind[:]);hmac.update(&h,bytes)
	tag:[32]u8;hmac.final(&h,tag[:]);return tag
}
@(private)
authenticated :: proc(key:auth.Key,kind:u16,bytes:[]u8)->bool {
	if key==(auth.Key{}) || len(bytes)<sc.HEADER_BYTES+32 || len(bytes)>PACKET_BYTES {return false}
	tag:=mac(key,kind,bytes[:len(bytes)-32]);return crypto.compare_constant_time(tag[:],bytes[len(bytes)-32:])==1
}
@(private)
pack :: proc(c:^sc.Schema,value:$T,key:auth.Key,kind:u16,content,sequence:u64,dst:[]u8)->int {
	n:=sc.HEADER_BYTES+c.wire_size
	if !c.initialized || len(dst)<n+32 || sc.pack(c,value,{kind=kind,epoch=u64(VERSION),content=content,tick=sequence},dst[:n]).error!=.None {return 0}
	tag:=mac(key,kind,dst[:n]);copy(dst[n:n+32],tag[:]);return n+32
}
@(private)
read :: proc(c:^sc.Schema,value:^$T,bytes:[]u8,kind:u16,content:u64)->bool {
	if !c.initialized || len(bytes)!=sc.HEADER_BYTES+c.wire_size+32 {return false}
	_,r:=sc.unpack(c,value,bytes[:len(bytes)-32],{kind=kind,epoch=u64(VERSION),content=content});return r.error==.None
}

// Signed wrapper for the existing bounded transfer engine. The embedding owns
// reads/polling. TLS still supplies confidentiality and authenticates the server.
Lane :: struct {wire:tr.Transport,peer:tr.Peer_Id,key:auth.Key,request:Request,request_hash:[32]u8,transfer:u64,out_kind:u16,channel:tr.Channel,codecs:^Codecs,txb:[PACKET_BYTES]u8}
@(private)
lane_wire :: proc(l:^Lane)->tr.Transport {return {user=l,send=lane_send,connected=lane_connected}}
@(private)
lane_connected :: proc(user:rawptr,peer:tr.Peer_Id)->bool {l:=cast(^Lane)user;return peer==l.peer && tr.peer_connected(&l.wire,peer)}
@(private)
lane_send :: proc(user:rawptr,peer:tr.Peer_Id,delivery:tr.Channel,bytes:[]u8)->tr.Send_Result {
	l:=cast(^Lane)user
	if peer!=l.peer || len(bytes)>tf.CHUNK_BYTES+128 || l.transfer==0 {return .Invalid}
	q:=l.request;d:=Data{room=q.room,content=q.content,sequence=q.sequence,generation=q.generation,transfer=l.transfer,identity=q.identity,nonce=q.nonce,request_hash=l.request_hash,count=u16(len(bytes))}
	copy(d.bytes[:],bytes);n:=pack(&l.codecs.data,d,l.key,l.out_kind,q.content,q.sequence,l.txb[:])
	if n==0 {return .Invalid};return tr.send(&l.wire,peer,l.channel,l.txb[:n])
}
@(private)
lane_read :: proc(l:^Lane,from:tr.Peer_Id,bytes:[]u8,kind:u16)->(Data,bool) {
	d:Data;q:=l.request
	if from!=l.peer || !authenticated(l.key,kind,bytes) || !read(&l.codecs.data,&d,bytes,kind,q.content) {return {},false}
	meta,_,_:=sc.inspect(bytes[:len(bytes)-32])
	return d,d.room==q.room && d.content==q.content && d.sequence==q.sequence && meta.tick==q.sequence && d.generation==q.generation && d.identity==q.identity && d.nonce==q.nonce && d.request_hash==l.request_hash && d.transfer==l.transfer && d.count>0 && int(d.count)<=len(d.bytes)
}
