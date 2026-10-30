package replay_net_test
import "core:testing"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

@(test)
observer_display_capability_is_confirmed_and_cleared_on_reconnect :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 testing.expect(t,!f.clients[2].observer_names_negotiated)
 for _ in 0..<30 {fixture_step(&f)}
 testing.expect(t,net.server_observer_names(&f.server,4) && f.clients[2].observer_names_negotiated)
 wire:=tr.memory_transport(&f.endpoints[3]);tr.close(&wire);net.server_pump(&f.server,f.clock*1000/60)
 testing.expect(t,!net.server_observer_names(&f.server,4))
 tr.memory_open(&f.network,&f.endpoints[3],4);net.client_reconnect(&f.clients[2],tr.memory_transport(&f.endpoints[3]))
 testing.expect(t,!f.clients[2].observer_names_negotiated)
 f.clients[2].snapshot_parts_enabled=false
 for _ in 0..<30 {fixture_step(&f)}
 testing.expect(t,!net.server_observer_names(&f.server,4) && !f.clients[2].observer_names_negotiated)
}

@(test)
legacy_feature_reply_keeps_observer_display_claims_disabled :: proc(t:^testing.T) {
 f:Fixture;fixture_init(&f);defer fixture_destroy(&f)
 for _ in 0..<30 {fixture_step(&f)}
 c:=&f.clients[2];testing.expect(t,c.observer_names_negotiated)
 // An older protocol-7 server confirms only the pre-existing reply flags.
 schema:sc.Schema;assert(sc.init(&schema,Checkpoint_Features).error==.None);defer sc.destroy(&schema)
 packet:=Checkpoint_Features{c.generation,c.serial,net.FACT_REPAIR_FEATURE|net.RECENT_ACTIONS_FEATURE,1024}
 bytes:[128]u8;assert(sc.pack(&schema,packet,{kind=16,epoch=c.cfg.epoch,content=c.cfg.content},bytes[:]).error==.None)
 tr.send(&f.server.wire,4,.Reliable,bytes[:sc.HEADER_BYTES+schema.wire_size])
 for _ in 0..<5 {fixture_step(&f)}
 testing.expect(t,!c.observer_names_negotiated && c.fact_repair_negotiated && c.action_copies_negotiated)
}
