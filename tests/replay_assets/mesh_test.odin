package replay_assets_test

import "core:testing"
import a "godot:replay/assets"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Network :: struct {
 memory:tr.Memory,
 endpoints:[4]tr.Memory_Endpoint,
 caches:[3]a.Cache,
 meshes:[3]a.Mesh,
 now:u64,
}
network_init :: proc(n: ^Network) {
 faults:=tr.DEFAULT_FAULTS; faults.latency_ticks,faults.jitter_ticks,faults.loss_permyriad,faults.duplicate_permyriad=30,20,1000,1000
 assert(tr.memory_init(&n.memory,123,{4,256,65536,65536},faults))
 for &e,i in n.endpoints {assert(tr.memory_open(&n.memory,&e,tr.Peer_Id(i+1)))}
 for &c,i in n.caches {
  assert(a.cache_init(&c,{8,128*1024,512*1024})==.None)
  assert(a.mesh_init(&n.meshes[i],&c,tr.memory_transport(&n.endpoints[i]))==.None)
 }
}
network_destroy :: proc(n: ^Network) {
 for &m in n.meshes {a.mesh_destroy(&m)}
 for &c in n.caches {a.cache_destroy(&c)}
 for &e in n.endpoints {wire:=tr.memory_transport(&e);tr.close(&wire)}
 tr.memory_destroy(&n.memory)
}
network_step :: proc(n: ^Network, from: int=0) {
 n.now+=10; tr.memory_advance(&n.memory,n.now)
 for i in from..<len(n.meshes) {assert(a.mesh_frame(&n.meshes[i],n.now)==.None)}
}

@(test)
watched_assets_cross_both_directions_fill_a_late_cache_and_survive_source_loss :: proc(t: ^testing.T) {
 n:Network; network_init(&n); defer network_destroy(&n)
 first:=make([]u8,25000); second:=make([]u8,42000); defer delete(first); defer delete(second)
 for &b,i in first {b=u8(i%251)}; for &b,i in second {b=u8(i%239)}
 ref1,_:=a.cache_put(&n.caches[0],first); ref2,_:=a.cache_put(&n.caches[1],second)
 refs:=[2]a.Ref{ref1,ref2}
 for i in 0..<2 {a.mesh_watch(&n.meshes[i],refs[:])}
 a.mesh_bind(&n.meshes[0],2,{7,1,102,99}); a.mesh_bind(&n.meshes[1],1,{7,1,102,99})
 for _ in 0..<2000 {network_step(&n);if a.mesh_complete(&n.meshes[0]) && a.mesh_complete(&n.meshes[1]) {break}}
 testing.expect(t,a.mesh_complete(&n.meshes[0]) && a.mesh_complete(&n.meshes[1]))
 testing.expect_value(t,n.caches[0].bytes,67000); testing.expect_value(t,n.caches[1].bytes,67000)
 a.mesh_watch(&n.meshes[2],refs[:]); a.mesh_bind(&n.meshes[0],3,{7,1,103,99});a.mesh_bind(&n.meshes[2],1,{7,1,103,99})
 for _ in 0..<2000 {network_step(&n);if a.mesh_complete(&n.meshes[2]) {break}}
 testing.expect(t,a.mesh_complete(&n.meshes[2]))
 for &m in n.meshes {testing.expect(t,m.stats.tx_bytes<=u64(m.cfg.bytes_per_update*2)+n.now*u64(m.cfg.bytes_per_second)/1000)}
 // The first source is gone. Surviving caches serve a new binding/epoch.
 wire:=tr.memory_transport(&n.endpoints[0]);tr.close(&wire)
 a.mesh_unbind(&n.meshes[1],1);a.mesh_unbind(&n.meshes[2],1)
 a.mesh_watch(&n.meshes[2],nil);a.cache_discard(&n.caches[2],ref1);a.mesh_watch(&n.meshes[2],refs[:])
 a.mesh_bind(&n.meshes[1],3,{7,2,203,99});a.mesh_bind(&n.meshes[2],2,{7,2,203,99})
 for _ in 0..<2000 {network_step(&n,1);if a.mesh_complete(&n.meshes[2]) {break}}
 testing.expect(t,a.mesh_complete(&n.meshes[2]))
 actual,err:=a.cache_copy(&n.caches[2],ref1);defer delete(actual)
 testing.expect_value(t,err,a.Error.None);testing.expect_value(t,a.reference(actual),ref1)
 // A validly framed old-epoch request cannot schedule work on the new binding.
 request:=struct{room,binding:u64,ref:a.Ref}{7,203,ref1}
 codec:sc.Schema;sc.init(&codec,type_of(request));defer sc.destroy(&codec)
 buffer:[160]u8;sc.pack(&codec,request,{kind=a.REQUEST_KIND,epoch=1,content=99},buffer[:])
 stale_wire:=tr.memory_transport(&n.endpoints[2]); before:=n.meshes[1].stats.rejected
 faults:=tr.DEFAULT_FAULTS;tr.memory_set_faults(&n.memory,faults)
 tr.send(&stale_wire,2,.Unreliable,buffer[:sc.HEADER_BYTES+codec.wire_size])
 for _ in 0..<20 {network_step(&n,1)}
 testing.expect(t,n.meshes[1].stats.rejected>before)
}

@(test)
unwatched_cache_entries_are_not_served_and_watch_updates_do_not_multiply_pins :: proc(t: ^testing.T) {
 n:Network; network_init(&n);defer network_destroy(&n)
 bytes:=[4]u8{1,2,3,4};ref,_:=a.cache_put(&n.caches[0],bytes[:]);refs:=[1]a.Ref{ref}
 a.mesh_bind(&n.meshes[0],2,{7,1,102,99});a.mesh_bind(&n.meshes[1],1,{7,1,102,99})
 a.mesh_watch(&n.meshes[1],refs[:])
 for _ in 0..<100 {network_step(&n)}
 testing.expect(t,!a.cache_has(&n.caches[1],ref))
 for _ in 0..<10 {a.mesh_watch(&n.meshes[0],refs[:])}
 for _ in 0..<1000 {network_step(&n);if a.mesh_complete(&n.meshes[1]) {break}}
 testing.expect(t,a.mesh_complete(&n.meshes[1]))
 testing.expect_value(t,a.cache_discard(&n.caches[0],ref),a.Error.Pinned)
 a.mesh_watch(&n.meshes[0],nil)
 testing.expect_value(t,a.cache_discard(&n.caches[0],ref),a.Error.None)
}

@(test)
per_peer_policy_and_content_validation_gate_actual_transfer :: proc(t: ^testing.T) {
 n:Network;network_init(&n);defer network_destroy(&n)
 payload:=make([]u8,24000);defer delete(payload)
 for &b,i in payload {b=u8(i%251)}
 ref,_:=a.cache_put(&n.caches[0],payload);refs:=[1]a.Ref{ref}
 for &m in n.meshes {a.mesh_watch(&m,refs[:])}
 n.meshes[0].authorize=proc(user:rawptr,peer:tr.Peer_Id,ref:a.Ref)->bool{return peer==2}
 n.meshes[1].validator=proc(user:rawptr,ref:a.Ref,bytes:[]u8)->bool{return false}
 for i in 1..<3 {
  a.mesh_bind(&n.meshes[0],tr.Peer_Id(i+1),{7,1,u64(101+i),99})
  a.mesh_bind(&n.meshes[i],1,{7,1,u64(101+i),99})
 }
 for _ in 0..<300 {network_step(&n)}
 testing.expect(t,!a.cache_has(&n.caches[1],ref) && !a.cache_has(&n.caches[2],ref))
 testing.expect(t,n.meshes[1].stats.rejected>0)
 testing.expect_value(t,n.meshes[2].stats.installed,u64(0))
 n.meshes[1].validator=nil
 for _ in 0..<1000 {network_step(&n);if a.mesh_complete(&n.meshes[1]) {break}}
 testing.expect(t,a.mesh_complete(&n.meshes[1]) && !a.mesh_complete(&n.meshes[2]))
 testing.expect(t,a.cache_has(&n.caches[0],ref))
}

@(test)
admitted_offers_upload_before_gameplay_references_are_required :: proc(t:^testing.T) {
 n:Network;network_init(&n);defer network_destroy(&n)
 payload:=make([]u8,24000);defer delete(payload)
 ref,_:=a.cache_put(&n.caches[1],payload);refs:=[1]a.Ref{ref}
 a.mesh_bind(&n.meshes[0],2,{7,1,102,99},accept_offers=true)
 a.mesh_bind(&n.meshes[1],1,{7,1,102,99})
 a.mesh_announce(&n.meshes[1],refs[:])
 for _ in 0..<1500 {network_step(&n);if a.cache_has(&n.caches[0],ref) {break}}
 testing.expect(t,a.cache_has(&n.caches[0],ref))
 testing.expect_value(t,n.meshes[0].count,0)
 testing.expect_value(t,a.cache_discard(&n.caches[0],ref),a.Error.Pinned)
 // Revoking offer admission drops its retention pin.
 a.mesh_bind(&n.meshes[0],2,{7,1,102,99},accept_offers=false)
 testing.expect_value(t,a.cache_discard(&n.caches[0],ref),a.Error.None)
 for _ in 0..<100 {network_step(&n)}
 testing.expect(t,!a.cache_has(&n.caches[0],ref))
}
