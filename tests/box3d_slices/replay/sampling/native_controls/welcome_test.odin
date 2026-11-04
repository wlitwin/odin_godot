package sampling_native_controls

import "core:fmt"
import "core:testing"
import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import common "godot:examples/box3d_common"
import adapter "godot:examples/replay_box3d/shared/adapter"

@(test)
ahead_snapshot_then_later_welcome_in_one_pump_does_not_double_bootstrap :: proc(t:^testing.T){
 world,game,status:=common.world(4,1);testing.expect_value(t,status,b.Status.Ok)
 config:=b.recovery_config_default();config.profile=common.PROFILE;assets:=common.assets()
 catalog,cs:=b.recovery_catalog_create(config,assets[:]);testing.expect_value(t,cs,b.Status.Ok);defer b.recovery_catalog_destroy(&catalog)
 provider:=adapter.config(&catalog,4);codec:adapter.Codec
 testing.expect(t,ph.network_codec_init(&codec,&catalog,provider,adapter.rules(4,1))==.None);defer ph.network_codec_destroy(&codec)
 initial,ie:=ph.checkpoint_make(r.Frame(common.Game){state=game},net.Net_Event(common.Event),world,provider);testing.expect_value(t,ie,r.Error.None);b.world_destroy(&world)
 memory:tr.Memory;testing.expect(t,tr.memory_init(&memory,cfg={2,64,tr.MAX_PACKET_BYTES,4096}));defer tr.memory_destroy(&memory)
 endpoints:[2]tr.Memory_Endpoint;for &endpoint,index in endpoints{testing.expect(t,tr.memory_open(&memory,&endpoint,tr.Peer_Id(index+1)))}
 server:=new(net.Server(common.Game,common.Control,common.Action,common.Event,2));defer free(server)
 client:=new(net.Client(common.Game,common.Control,common.Action,common.Event,2));defer free(client)
 defer net.server_destroy(server);defer net.client_destroy(client)
 cfg:=net.physics_config_default();cfg.snapshot_every=1
 testing.expect(t,net.server_init_complete(server,&initial,adapter.model(&codec),tr.memory_transport(&endpoints[0]),cfg,local_seat=1)==.None)
 r.complete_checkpoint_destroy(&initial)
 testing.expect(t,net.server_set_local_token(server,net.Token{0=1})==.None)
 testing.expect(t,net.client_init(client,adapter.model(&codec),tr.memory_transport(&endpoints[1]),net.Token{0=2},cfg=cfg)==.None)
 net.client_pump(client,0);tr.memory_advance(&memory,0);net.server_pump(server,0);net.server_step(server);tr.memory_advance(&memory,0);net.client_pump(client,0)
 testing.expect_value(t,client.phase,net.Phase.Running)
 // Keep ordinary prediction held at its existing bootstrap head. Advance and
 // acknowledge real authoritative packets until confirmation catches that head.
 for server.timeline.head<client.timeline.head{
  tr.memory_advance(&memory,0);testing.expect(t,net.server_pump(server,0)==.None);testing.expect(t,net.server_step(server)==.None)
  tr.memory_advance(&memory,0);testing.expect(t,net.client_pump(client,0)==.None)
 }
 testing.expect_value(t,client.timeline.head,client.timeline.confirmed)
 tr.memory_advance(&memory,0);net.server_pump(server,0)
 testing.expect(t,net.server_step(server)==.None) // valid ahead Snapshot remains queued
 // Existing Hello schema/credential produces a later complete Welcome. No
 // local Client phase/head/clock/pose field is assigned by this fixture.
 schema:=&client.codecs.hello;bytes:=make([]u8,sc.HEADER_BYTES+schema.wire_size);defer delete(bytes);body:=bytes[sc.HEADER_BYTES:]
 for field in schema.fields{
  value:u64
  switch field.path{
  case "$.contract":value=client.contract
  case "$.spectator":value=0
  case "$.sent_ms":value=0
  case "$.incarnation":value=client.incarnation
  case:
   found:=false;for byte,index in client.token{if field.path==fmt.tprintf("$.token[%d]",index){value=u64(byte);found=true;break}}
   testing.expect(t,found)
  }
  for i in 0..<field.width{body[field.wire_offset+i]=u8(value>>uint(i*8))}
 }
 testing.expect(t,sc.pack_bytes(schema.fingerprint,{kind=1,epoch=client.cfg.epoch,content=client.cfg.content},body,bytes).error==.None)
 wire:=tr.memory_transport(&endpoints[1]);testing.expect_value(t,tr.send(&wire,1,.Reliable,bytes),tr.Send_Result.Sent)
 tr.memory_advance(&memory,0);testing.expect(t,net.server_pump(server,0)==.None);tr.memory_advance(&memory,0)
 before_catchups,before_serial:=client.stats.snapshot_catchups,client.serial
 testing.expect(t,net.client_pump(client,0)==.None)
 depth:=client.timeline.head-client.timeline.confirmed
 testing.expect_value(t,client.stats.snapshot_catchups,before_catchups+1)
 testing.expect_value(t,client.serial,before_serial+1)
 testing.expect_value(t,depth,u64(client.lead_ticks));testing.expect(t,depth<=u64(client.cfg.max_prediction))
 fmt.printf("REPLAY_SAMPLING_LATER_WELCOME catchups=%d serial=%d->%d held_depth=%d lead=%d\n",client.stats.snapshot_catchups-before_catchups,before_serial,client.serial,depth,client.lead_ticks)
}
