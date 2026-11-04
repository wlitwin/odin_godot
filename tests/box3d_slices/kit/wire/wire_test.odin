package kit_slice_wire_test

import "core:testing"
import "core:mem"
import sim "godot:kit/sim"
import "base:runtime"
import bg "godot:box3d/godot"
import bh "godot:box3d/godot/host"
import bm "godot:box3d/godot/meter"
import p "godot:kit/physics"
import n "godot:kit/net"
import s "godot:kit/session"
import ng "godot:kit/netgd"

LIB :: #config(BOX3D_LIBRARY,"")
foreign import native {"system:"+LIB}
when ODIN_OS==.Linux {foreign import math "system:m"}
foreign native {
 @(link_name="ogb3_domain_contract_get") contract_get::proc(^bg.Domain_Contract)->bg.Status---
 @(link_name="ogb3_engine_allocation_stats") engine_stats::proc(^bg.Allocation_Stats)->bg.Status---
 @(link_name="ogb3_snapshot_allocation_stats") wrapper_stats::proc(^bg.Allocation_Stats)->bg.Status---
 @(link_name="ogb3_host_owner_open") owner_open::proc(u64,u64,u64,^u64)->bg.Status---
 @(link_name="ogb3_host_owner_set") owner_set::proc(u64,u64,u64,u64)->bg.Status---
 @(link_name="ogb3_host_owner_close") owner_close::proc(u64,u64)->bg.Status---
 @(link_name="ogb3_host_ledger_get") ledger_get::proc(u64,^bg.Ledger_Stats)->bg.Status---
}
Code :: struct {references:u64}
@(private) depth:u32
enter :: proc "c"(_:rawptr)->bg.Status {depth+=1;return bg.OK}
leave :: proc "c"(_:rawptr) {depth-=1}
protected :: proc "c"(_:rawptr)->bg.Status {return depth!=0?bg.OK:bg.INCOMPATIBLE}
pin :: proc "c"(_:rawptr,code:rawptr) {(cast(^Code)code).references+=1}
unpin :: proc "c"(_:rawptr,code:rawptr) {(cast(^Code)code).references-=1}
// Explicit unit-only validator; actual Core validates dladdr image membership.
procedure :: proc "c"(_:rawptr,_:rawptr,pointer:rawptr)->bg.Status {return pointer!=nil?bg.OK:bg.INCOMPATIBLE}
Fixture :: struct {
 server,client:s.Session,
 wire:ng.Session_Wire,
 count:u32,
 received:[16]u8,
 marker:u64,
}
server_send :: proc(user:rawptr,to:s.Peer_Id,bytes:[]u8,channel:s.Channel) {
 f:=cast(^Fixture)user
 if to==100 || to==s.BROADCAST_PEER {r:=n.reader_make(bytes);s.session_handle_packet(&f.client,s.HOST_PEER,&r,channel)}
}
client_send :: proc(user:rawptr,to:s.Peer_Id,bytes:[]u8,channel:s.Channel) {
 f:=cast(^Fixture)user;r:=n.reader_make(bytes);s.session_handle_packet(&f.server,100,&r,channel)
}
receive :: proc(user:rawptr,from:n.Player_Id,peer:s.Peer_Id,r:^n.Reader) {
 f:=cast(^Fixture)user
 assert(from==2 && peer==100)
 f.received[f.count]=n.read_u8(r);f.count+=1
}

@(test)
bounded_owned_wire_preserves_reliable_queue_and_releases_after_source_death :: proc(t:^testing.T) {
 contract:bg.Domain_Contract;testing.expect_value(t,contract_get(&contract),bg.OK)
 api:=bg.Native_API{contract,engine_stats,wrapper_stats,owner_open,owner_set,owner_close,ledger_get}
 testing.expect_value(t,bh.registry_init(api,{enter=enter,leave=leave,protected=protected,code_retain=pin,code_drop=unpin,procedure=procedure}),bg.OK)
 code:Code;service:bg.Service;testing.expect_value(t,bh.producer_create(&code,&service),bg.OK)
 testing.expect_value(t,bg.module_install(&service),bg.OK)
 testing.expect_value(t,enter(nil),bg.OK)
 previous,status:=bh.origin_enter(service.user);testing.expect_value(t,status,bg.OK)
 weak:u64;testing.expect_value(t,bh.context_create(service.user,&weak),bg.OK)
 source_backing:=context.allocator;source:=new(u64,source_backing);testing.expect_value(t,bh.context_bind(weak,source,8),bg.OK)
 bh.origin_leave(previous);previous,status=bh.origin_enter(service.user,weak);testing.expect_value(t,status,bg.OK)
 managed,me:=p.sdk_context_create();testing.expect_value(t,me,sim.World_Error.Ok)
 alloc:=bm.allocator(managed.memory);context.allocator=alloc
 f:=new(Fixture,alloc);f.marker=0x123456789abcdef
 callback_owner,ce:=p.sdk_user_owner_create(managed.memory,f,u64(size_of(f^)),f,u64(size_of(f^)));testing.expect_value(t,ce,sim.World_Error.Ok)
 lease,ls:=bm.block_lease(managed.memory,f,u64(size_of(f^)),&f.wire,u64(size_of(f.wire)));testing.expect_value(t,ls,bg.OK)
 wire_owner,we:=p.sdk_owner_create(true,lease);testing.expect_value(t,we,sim.World_Error.Ok)
 cfg:=ng.Wire_Config{allocator=alloc,owner=wire_owner,user_data=&f.wire,allocator_owner=managed.detached,allocator_data=alloc.data,max_delayed_packets=2,max_delayed_bytes=6,max_peers=2,seed=1}
 f.server.allocator=alloc;f.client.allocator=alloc
 s.session_set_transport(&f.server,f,server_send);s.session_set_transport(&f.client,f,client_send)
 s.session_host_start(&f.server,"host");s.session_client_start(&f.client,1234,"client");s.session_client_join(&f.client)
 testing.expect(t,f.client.joined && f.client.me==2)
 s.session_app_route(&f.server,4,f,receive)
 before,_:=bm.stats(managed.memory)
 bad:=cfg;bad.user_data=f
 testing.expect_value(t,ng.wire_configure(&f.wire,bad),ng.Wire_Error.Owner)
 after,_:=bm.stats(managed.memory);testing.expect_value(t,after,before)
 testing.expect_value(t,ng.wire_configure(&f.wire,cfg),ng.Wire_Error.Ok)
 f.wire.ses=&f.server;f.wire.kind=55
 ng.wire_set_latency(&f.wire,100,1000)
 first:=[4]u8{55,s.SES_APP,4,1};second:=[4]u8{55,s.SES_APP,4,2};third:=[4]u8{55,s.SES_APP,4,3}
 testing.expect_value(t,ng.wire_receive_bytes(&f.wire,100,first[:],1),ng.Wire_Error.Ok)
 first[3]=99
 testing.expect_value(t,ng.wire_receive_bytes(&f.wire,100,second[:],1.01),ng.Wire_Error.Ok)
 testing.expect(t,f.wire.delayed[0].due<=f.wire.delayed[1].due)
 testing.expect_value(t,f.wire.delayed[0].data[2],u8(1))
 pointers:=[2]rawptr{raw_data(f.wire.delayed[0].data),raw_data(f.wire.delayed[1].data)}
 testing.expect_value(t,ng.wire_receive_bytes(&f.wire,100,third[:],1.02),ng.Wire_Error.Capacity)
 testing.expect_value(t,ng.wire_status(&f.wire).queued_bytes,u64(6))
 testing.expect_value(t,rawptr(raw_data(f.wire.delayed[0].data)),pointers[0]);testing.expect_value(t,rawptr(raw_data(f.wire.delayed[1].data)),pointers[1])
 ng.wire_pump(&f.wire,100)
 testing.expect_value(t,f.count,u32(0));testing.expect_value(t,f.marker,u64(0x123456789abcdef))
 testing.expect_value(t,ng.wire_status(&f.wire).error,ng.Wire_Error.Capacity)
 testing.expect_value(t,ng.wire_peer_left(&f.wire,100),ng.Wire_Error.Ok)
 testing.expect_value(t,ng.wire_status(&f.wire).queued_bytes,u64(0));testing.expect_value(t,ng.wire_status(&f.wire).retired_packets,u64(2))
 testing.expect_value(t,ng.wire_detach(&f.wire),ng.Wire_Error.Ok)
 testing.expect_value(t,ng.wire_configure(&f.wire,cfg),ng.Wire_Error.Ok)
 f.wire.ses=&f.server;f.wire.kind=55;ng.wire_set_latency(&f.wire,100,1000)
 first[3]=1
 testing.expect_value(t,ng.wire_receive_bytes(&f.wire,100,first[:],1),ng.Wire_Error.Ok)
 testing.expect_value(t,ng.wire_receive_bytes(&f.wire,100,second[:],1.01),ng.Wire_Error.Ok)
 ng.wire_pump(&f.wire,100)
 testing.expect_value(t,f.count,u32(2));testing.expect_value(t,mem.compare(f.received[:2],[]u8{1,2}),0)
 testing.expect_value(t,ng.wire_status(&f.wire).queued_bytes,u64(0))
 // Exact callback/Wire block leases, not the borrowed source Scene, keep data
 // alive after the caller's source allocation requests retirement.
 free(f,alloc)
 testing.expect(t,bm.owns(managed.memory,f,u64(size_of(Fixture))))
 testing.expect_value(t,bh.context_invalidate(weak),bg.OK)
 testing.expect_value(t,ng.wire_receive_bytes(&f.wire,100,third[:],101),ng.Wire_Error.Owner)
 ng.wire_pump(&f.wire,101);testing.expect_value(t,f.count,u32(2))
 testing.expect_value(t,ng.wire_detach(&f.wire),ng.Wire_Error.Ok)
 testing.expect_value(t,ng.wire_detach(&f.wire),ng.Wire_Error.Ok)
 s.session_destroy(&f.client);s.session_destroy(&f.server)
 testing.expect_value(t,p.sdk_user_owner_destroy(&callback_owner),sim.World_Error.Ok)
 testing.expect_value(t,wire_owner.drop(wire_owner.user),bg.OK)
 testing.expect_value(t,p.sdk_context_destroy(&managed),sim.World_Error.Ok)
 free(source,source_backing);testing.expect_value(t,bh.context_release(weak),bg.OK)
 bh.origin_leave(previous);leave(nil)
 testing.expect_value(t,code.references,u64(0));testing.expect_value(t,depth,u32(0))
 testing.expect_value(t,bh.producer_destroy(service.user),bg.OK);testing.expect_value(t,bh.registry_shutdown(),bg.OK)
}
