package replay_transfer_test

import "core:testing"
import tf "godot:replay/transfer"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

SCOPE :: tf.Scope{7,2,3,4}
PAYLOAD_KIND :: u16(777)
FINGERPRINT :: u64(0x626c6f62)
Fixture :: struct {
 memory: tr.Memory,
 endpoints: [2]tr.Memory_Endpoint,
 sender: tf.Sender,
 receiver: tf.Blob_Receiver,
 clock: u64,
 installed: u32,
 reject: bool,
 digest: [32]u8,
}
init :: proc(f: ^Fixture, faults := tr.DEFAULT_FAULTS, cap: int = 65536) {
 assert(tr.memory_init(&f.memory,42,{2,256,1200,131072},faults))
 for &endpoint,i in f.endpoints {assert(tr.memory_open(&f.memory,&endpoint,tr.Peer_Id(i+1)))}
 assert(tf.sender_init(&f.sender,SCOPE,2,tr.memory_transport(&f.endpoints[0]),archive_kind=PAYLOAD_KIND,max_bytes=cap)==.None)
 assert(tf.blob_init(&f.receiver,SCOPE,1,tr.memory_transport(&f.endpoints[1]),PAYLOAD_KIND,
 proc(user:rawptr,archive:tf.Archive,bytes:[]u8)->bool {
  f := cast(^Fixture)user
  _,body,report:=sc.unpack_bytes(FINGERPRINT,bytes,{kind=PAYLOAD_KIND,epoch=SCOPE.epoch,content=SCOPE.content})
  if f.reject || report.error != .None {return false}
  f.digest=tf.hash(body); f.installed+=1; return true
 },f,max_bytes=cap)==.None)
}
destroy :: proc(f: ^Fixture) {
 tf.sender_destroy(&f.sender); tf.blob_destroy(&f.receiver)
 for &ep in f.endpoints {wire:=tr.memory_transport(&ep); tr.close(&wire)}
 tr.memory_destroy(&f.memory)
}
pump :: proc(f: ^Fixture) {
 f.clock+=10; tr.memory_advance(&f.memory,f.clock)
 buffer:[1200]u8
 a,b:=tr.memory_transport(&f.endpoints[0]),tr.memory_transport(&f.endpoints[1])
 for {
  p:=tr.receive(&a,buffer[:]); if p.state!=.Received {break}
  tf.sender_receive(&f.sender,p.from,buffer[:p.count],f.clock)
 }
 for {
  p:=tr.receive(&b,buffer[:]); if p.state!=.Received {break}
  tf.blob_receive(&f.receiver,p.from,buffer[:p.count],f.clock,p.channel)
 }
 tf.sender_update(&f.sender,f.clock); tf.blob_update(&f.receiver,f.clock)
}
packet :: proc(payload: []u8, tick: u64) -> []u8 {
 bytes:=make([]u8,sc.HEADER_BYTES+len(payload))
 assert(sc.pack_bytes(FINGERPRINT,{kind=PAYLOAD_KIND,epoch=SCOPE.epoch,tick=tick,content=SCOPE.content},payload,bytes).error==.None)
 return bytes
}

@(test)
content_transfer_survives_faults_and_installs_only_validated_candidates :: proc(t: ^testing.T) {
 f:Fixture; faults:=tr.DEFAULT_FAULTS
 faults.latency_ticks,faults.jitter_ticks,faults.loss_permyriad,faults.duplicate_permyriad=30,20,1000,1000
 init(&f,faults); defer destroy(&f)
 payload:=make([]u8,32000); defer delete(payload)
 for &b,i in payload {b=u8(i%251)}
 bytes:=packet(payload,1); defer delete(bytes)
 testing.expect_value(t,tf.sender_begin(&f.sender,bytes,0),tf.Error.None)
 for _ in 0..<1500 {pump(&f); if f.sender.phase==.Complete {break}}
 testing.expect_value(t,f.sender.phase,tf.Phase.Complete)
 testing.expect_value(t,f.installed,u32(1)); testing.expect_value(t,f.digest,tf.hash(payload))
 before:=f.receiver.latest
 f.reject=true
 next:=packet(payload,2); defer delete(next)
 testing.expect_value(t,tf.sender_begin(&f.sender,next,f.clock),tf.Error.None)
 for _ in 0..<1500 {pump(&f); if f.sender.phase==.Failed {break}}
 testing.expect_value(t,f.sender.phase,tf.Phase.Failed)
 testing.expect_value(t,f.sender.remote_failure,tf.Failure.Archive)
 testing.expect_value(t,f.installed,u32(1)); testing.expect_value(t,f.receiver.latest,before)
}

@(test)
per_transfer_byte_cap_limits_allocation_and_rejects_oversized_offers :: proc(t: ^testing.T) {
 f:Fixture; init(&f,cap=4096); defer destroy(&f)
 testing.expect_value(t,len(f.receiver.bytes),4096)
 payload:=make([]u8,4096); defer delete(payload)
 bytes:=packet(payload,1); defer delete(bytes)
 testing.expect_value(t,tf.sender_begin(&f.sender,bytes,0),tf.Error.Capacity)
 capture:Capture; sender:tf.Sender; defer tf.sender_destroy(&sender)
 tf.sender_init(&sender,SCOPE,2,capture_wire(&capture),archive_kind=PAYLOAD_KIND)
 tf.sender_begin(&sender,bytes,0); tf.sender_update(&sender,0)
 testing.expect_value(t,tf.blob_receive(&f.receiver,1,capture.bytes[:capture.count],0),tf.Received.Rejected)
 testing.expect(t,!f.receiver.active && f.installed==0)
 testing.expect_value(t,tf.blob_receive(&f.receiver,2,capture.bytes[:capture.count],0),tf.Received.Rejected)
}

@(test)
sender_update_respects_a_smaller_callers_output_allowance :: proc(t:^testing.T) {
 f:Fixture;init(&f);defer destroy(&f)
 payload:[32000]u8;bytes:=packet(payload[:],1);defer delete(bytes)
 tf.sender_begin(&f.sender,bytes,0)
 testing.expect_value(t,tf.sender_update(&f.sender,0,0),tf.Error.None)
 testing.expect_value(t,f.sender.stats.tx_bytes,u64(0))
 testing.expect_value(t,tf.sender_update(&f.sender,0,100),tf.Error.None)
 testing.expect_value(t,f.sender.stats.tx_bytes,u64(0))
 testing.expect_value(t,tf.sender_update(&f.sender,0,164),tf.Error.None)
 testing.expect_value(t,f.sender.stats.tx_bytes,u64(164))
 for _ in 0..<10 {pump(&f)}
 before:=f.sender.stats.tx_bytes
 tf.sender_update(&f.sender,f.clock,0)
 testing.expect_value(t,f.sender.stats.tx_bytes,before)
}
