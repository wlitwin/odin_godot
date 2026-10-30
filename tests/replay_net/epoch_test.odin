package replay_net_test

import "core:testing"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

@(test)
opt_in_epoch_query_joins_newer_direct_host_without_relaxing_running_epoch :: proc(t:^testing.T) {
 schema:sc.Schema;testing.expect_value(t,sc.init(&schema,Epoch_Test_Packet).error,sc.Error.None);defer sc.destroy(&schema)
 cfg:=net.DEFAULT_CONFIG;cfg.epoch=9
 f:Fixture;fixture_init(&f,{latency_ticks=3,retry_ticks=3},cfg);defer fixture_destroy(&f)
 c:=&f.clients[0];net.client_destroy(c);cfg.epoch=1;cfg.content=f.server.cfg.content
 testing.expect_value(t,net.client_init(c,model(),tr.memory_transport(&f.endpoints[1]),{0=1},cfg=cfg),net.Error.None)
 f.server.epoch_discovery=true
 testing.expect_value(t,net.client_discover_epoch(c,{0=91}),net.Error.None)
 for _ in 0..<100 {fixture_step(&f,true)}
 testing.expect_value(t,c.phase,net.Phase.Running);testing.expect_value(t,c.cfg.epoch,u64(9))
 testing.expect_value(t,c.timeline.epoch,u64(9));testing.expect_value(t,c.journal.epoch,u64(9))
 testing.expect(t,c.has_world && c.seat>0 && !c.epoch_query_pending)
 testing.expect_value(t,net.client_discover_epoch(c,{0=92}),net.Error.Wrong_Phase)
 // Ordinary gameplay remains scoped to the admitted epoch.
 packet:[1024]u8;body:=Epoch_Test_Packet{{0=91},c.contract}
 n:=sc.HEADER_BYTES+c.codecs.epoch_query.wire_size
 sc.pack(&schema,body,{kind=21,epoch=10,content=c.cfg.content},packet[:])
 tr.send(&f.server.wire,2,.Reliable,packet[:n])
 for _ in 0..<10 {fixture_step(&f)}
 testing.expect_value(t,c.cfg.epoch,u64(9));testing.expect_value(t,c.phase,net.Phase.Running)
}
Epoch_Test_Packet :: struct {nonce:net.Token,contract:u64}

@(test)
epoch_reply_requires_challenge_contract_content_source_and_no_installed_world :: proc(t:^testing.T) {
 schema:sc.Schema;testing.expect_value(t,sc.init(&schema,Epoch_Test_Packet).error,sc.Error.None);defer sc.destroy(&schema)
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f);c:=&f.clients[0]
 testing.expect_value(t,net.client_discover_epoch(c,{}),net.Error.Invalid_Input)
 testing.expect_value(t,net.client_discover_epoch(c,c.token),net.Error.Invalid_Input)
 c.cfg.require_permit=true;testing.expect_value(t,net.client_discover_epoch(c,{0=91}),net.Error.Invalid_Input);c.cfg.require_permit=false
 testing.expect_value(t,net.client_discover_epoch(c,{0=91}),net.Error.None)
 tr.memory_advance(&f.network,0);net.client_pump(c,0)
 for &packet in f.network.packets {packet.active=false}
 for variant in 0..<7 {
  body:=Epoch_Test_Packet{{0=91},c.contract};meta:=sc.Envelope_Meta{kind=21,epoch=7,content=c.cfg.content}
  wire:=f.server.wire
  switch variant {case 0:body.nonce={0=92};case 1:body.contract+=1;case 2:meta.content+=1;case 3:meta.epoch=0;case 4:meta.tick=1;case 5:wire=tr.memory_transport(&f.endpoints[2]);case 6:c.has_world=true}
  bytes:[128]u8;report:=sc.pack(&schema,body,meta,bytes[:])
  if variant==3 {testing.expect_value(t,report.error,sc.Error.Invalid_Header);continue}
  testing.expect_value(t,report.error,sc.Error.None)
  tr.send(&wire,2,.Reliable,bytes[:sc.HEADER_BYTES+c.codecs.epoch_query.wire_size])
  tr.memory_advance(&f.network,u64(variant+1));net.client_pump(c,u64(variant+1))
  testing.expect_value(t,c.cfg.epoch,u64(1));testing.expect(t,c.epoch_query_pending);c.has_world=false
 }
 bytes:[128]u8;sc.pack(&schema,Epoch_Test_Packet{{0=91},c.contract},{kind=21,epoch=7,content=c.cfg.content},bytes[:])
 tr.send(&f.server.wire,2,.Reliable,bytes[:sc.HEADER_BYTES+c.codecs.epoch_query.wire_size])
 tr.memory_advance(&f.network,8);net.client_pump(c,8)
 testing.expect_value(t,c.cfg.epoch,u64(7));testing.expect(t,!c.epoch_query_pending && !c.has_world && c.phase==.Joining)
}

@(test)
epoch_query_is_opt_in_credential_free_and_does_not_reserve_a_seat :: proc(t:^testing.T) {
 schema:sc.Schema;testing.expect_value(t,sc.init(&schema,Epoch_Test_Packet).error,sc.Error.None);defer sc.destroy(&schema)
 for enabled in ([2]bool{false,true}) {
  f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
  f.server.epoch_discovery=enabled
  c:=&f.clients[0];testing.expect_value(t,net.client_discover_epoch(c,{0=99}),net.Error.None)
  tr.memory_advance(&f.network,0);net.client_pump(c,0)
  query_seen:=false
  for packet,i in f.network.packets {if packet.active && packet.to==1 {
   bytes:=f.network.bytes[i*f.network.config.packet_bytes:i*f.network.config.packet_bytes+packet.count]
   meta,_,report:=sc.inspect(bytes);testing.expect(t,report.error==.None && meta.kind==20)
   body:Epoch_Test_Packet;_,decoded:=sc.unpack(&schema,&body,bytes,meta);testing.expect_value(t,decoded.error,sc.Error.None)
   testing.expect(t,body.nonce!=(c.token) && body.contract==c.contract);query_seen=true
  }}
  testing.expect(t,query_seen)
  tr.memory_advance(&f.network,1);net.server_pump(&f.server,1)
  for peer in f.server.peers {testing.expect(t,peer.phase==.Vacant)}
  tr.memory_advance(&f.network,2);net.client_pump(c,2)
  testing.expect_value(t,c.epoch_query_pending,!enabled)
 }
 // Even an accidentally enabled leased server never answers discovery queries.
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 f.server.epoch_discovery=true;f.server.cfg.require_permit=true
 f.server.permit={allow=proc(_:rawptr,_:u64)->bool{return true}}
 net.client_discover_epoch(&f.clients[0],{0=91});tr.memory_advance(&f.network,0);net.client_pump(&f.clients[0],0)
 tr.memory_advance(&f.network,1);net.server_pump(&f.server,1)
 tr.memory_advance(&f.network,2);net.client_pump(&f.clients[0],2)
 testing.expect(t,f.clients[0].epoch_query_pending)
}
