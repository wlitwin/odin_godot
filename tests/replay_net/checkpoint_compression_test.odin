package replay_net_test
import "core:testing"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

@(test)
checkpoint_compression_requires_current_connection_advertisement :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 // An older endpoint sends no Features packet.
 f.clients[1].snapshot_parts_enabled=false
 testing.expect(t,!net.server_checkpoint_compression(&f.server,2))
 testing.expect(t,!net.server_checkpoint_shuffle(&f.server,2))
 testing.expect(t,!net.server_checkpoint_reliable(&f.server,2))
 for _ in 0..<30 {fixture_step(&f)}
 testing.expect(t,net.server_checkpoint_compression(&f.server,2))
 testing.expect(t,net.server_checkpoint_shuffle(&f.server,2))
 testing.expect(t,net.server_checkpoint_reliable(&f.server,2))
 testing.expect(t,!net.server_checkpoint_compression(&f.server,3))
 wire:=tr.memory_transport(&f.endpoints[1]);tr.close(&wire)
 net.server_pump(&f.server,f.clock*1000/60)
 testing.expect(t,!net.server_checkpoint_compression(&f.server,2))
 testing.expect(t,!net.server_checkpoint_shuffle(&f.server,2))
 testing.expect(t,!net.server_checkpoint_reliable(&f.server,2))
 tr.memory_open(&f.network,&f.endpoints[1],2)
 net.client_reconnect(&f.clients[0],tr.memory_transport(&f.endpoints[1]))
 f.clients[0].snapshot_parts_enabled=false
 for _ in 0..<30 {fixture_step(&f)}
 testing.expect_value(t,f.clients[0].phase,net.Phase.Running)
 testing.expect(t,!net.server_checkpoint_compression(&f.server,2))
 testing.expect(t,!net.server_checkpoint_shuffle(&f.server,2))
 testing.expect(t,!net.server_checkpoint_reliable(&f.server,2))
}

@(test)
checkpoint_layout_capability_is_separate_immutable_and_requires_compression :: proc(t:^testing.T) {
 for mode in 0..<4 {
  f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
  f.clients[0].snapshot_parts_enabled=false
  for _ in 0..<30 {fixture_step(&f)}
  c:=&f.clients[0]
  bits:=mode==0 ? net.CHECKPOINT_COMPRESSION_FEATURE : mode==1 ? net.CHECKPOINT_COMPRESSION_FEATURE|net.CHECKPOINT_SHUFFLE_FEATURE : mode==2 ? net.CHECKPOINT_SHUFFLE_FEATURE : net.CHECKPOINT_RELIABLE_FEATURE
  packet:=Checkpoint_Features{c.generation,c.serial,bits,1024}
  codec:sc.Schema;assert(sc.init(&codec,Checkpoint_Features).error==.None);defer sc.destroy(&codec)
  bytes:[128]u8;assert(sc.pack(&codec,packet,{kind=16,epoch=c.cfg.epoch,content=c.cfg.content},bytes[:]).error==.None)
  wire:=tr.memory_transport(&f.endpoints[1]);tr.send(&wire,1,.Reliable,bytes[:sc.HEADER_BYTES+codec.wire_size])
  for _ in 0..<5 {fixture_step(&f)}
  testing.expect_value(t,net.server_checkpoint_compression(&f.server,2),mode<2)
  testing.expect_value(t,net.server_checkpoint_shuffle(&f.server,2),mode==1)
  testing.expect_value(t,net.server_checkpoint_reliable(&f.server,2),mode==3)
  if mode==0 {
   packet.features|=net.CHECKPOINT_SHUFFLE_FEATURE|net.CHECKPOINT_RELIABLE_FEATURE
   sc.pack(&codec,packet,{kind=16,epoch=c.cfg.epoch,content=c.cfg.content},bytes[:]);tr.send(&wire,1,.Reliable,bytes[:sc.HEADER_BYTES+codec.wire_size])
   for _ in 0..<5 {fixture_step(&f)}
   testing.expect(t,!net.server_checkpoint_shuffle(&f.server,2))
 testing.expect(t,!net.server_checkpoint_reliable(&f.server,2))
  }
 }
}
Checkpoint_Features :: struct {generation,serial,features:u64,part_bytes:u16}
