package replay_comms

import "core:mem"
import sc "godot:replay/schema"
import lb "godot:replay/lobby"
import tr "godot:replay/transport"

TEXT_BYTES :: 240
HISTORY :: 64
OUTBOX :: 128
MAX_PEERS :: 32
PENDING :: 8
@(private)
PACKET_KIND :: u16(0x434d)
Kind :: enum u8 {None, Say, Marker, System}
Result :: enum u8 {None, Not_Ready, Invalid, Capacity, Rate_Limited, Permission, Scope_Changed}
Payload :: struct {kind:Kind,text:[TEXT_BYTES]u8,length:u16,position:[3]f32,tag:u32}
Id :: struct {epoch,sequence:u64}
Entry :: struct {id:Id,seat:u16,identity:[32]u8,name:lb.Name,value:Payload}
Scope :: struct {room,epoch,content:u64}
Binding :: struct {peer:tr.Peer_Id,generation:u64,seat:u16,identity:[32]u8,spectator:bool,name:lb.Name,observer_name_allowed:bool}
Receipt :: struct {submission:u64,result:Result,value:Payload}
@(private)
Delivery :: struct {entry:Entry,historical:bool}
@(private)
Wire_Kind :: enum u8 {None,Request,Ack,Deliver}
@(private)
Packet :: struct {version:u16,room,binding,request:u64,kind:Wire_Kind,result:Result,delivery:Delivery}
@(private)
Peer :: struct {
	binding:Binding,
	queue:[OUTBOX]Delivery,head,count:int,
	request_seen:u64,last_result:Result,reply:bool,
	tokens:f64,token_at:u64,
}
Comms :: struct {
	ready,bound,authority,enabled:bool,
	allocator:mem.Allocator,codec:sc.Schema,
	wire:tr.Transport,scope:Scope,local:Binding,
	peers:[]Peer,
	local_tokens:f64,local_token_at:u64,
	sequence:u64,
	lines:[HISTORY]Entry,line_count:int,last_id:Id,
	markers:[32]Entry,marker_count:int,
	pending:[PENDING]Payload,pending_names:[PENDING]lb.Name,pending_ids:[PENDING]u64,pending_head,pending_count:int,
	issued:u64,receipts:[PENDING]Receipt,receipt_head,receipt_count:int,
	request,next_send:u64,request_active:bool,
	last_result:Result,result_serial,history_serial,rejected,duplicates,scope_drops,marker_drops:u64,
	now:u64,time_set:bool,
	rxb,txb:[1024]u8,
}

init :: proc(c:^Comms,allocator:=context.allocator)->bool {
	if c.ready {return false}
	c.allocator=allocator
	if sc.init(&c.codec,Packet,allocator=allocator).error!=.None {return false}
	if c.codec.wire_size+sc.HEADER_BYTES>len(c.txb) {sc.destroy(&c.codec);return false}
	c.peers=make([]Peer,MAX_PEERS,allocator);c.ready=true;return true
}
destroy :: proc(c:^Comms) {sc.destroy(&c.codec);delete(c.peers,c.allocator);c^={}}
handles :: proc(bytes:[]u8)->bool {
	meta,_,report:=sc.inspect(bytes)
	return report.error==.None && meta.kind==PACKET_KIND && len(bytes)<=1024
}
