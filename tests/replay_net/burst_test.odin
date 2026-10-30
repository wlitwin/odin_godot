package replay_net_test
import "core:testing"
import net "godot:replay/net"
import sc "godot:replay/schema"

@(test)
sender_burst_is_bounded_to_a_quarter_second_or_one_complete_packet :: proc(t:^testing.T) {
 f:Parts_Fixture;parts_init(&f);defer parts_destroy(&f)
 for _ in 0..<100 {parts_step(&f)}
 f.server.cfg.egress_bytes_per_pump=1024*1024
 // Replenish through the ordinary pump, then advance without elapsed time.
 // An application's catch-up batch must not dump seconds of saved credit.
 now:=f.clock*1000/60
 testing.expect_value(t,net.server_pump(&f.server,now),net.Error.None)
 before:=f.server.stats.tx_bytes
 for _ in 0..<100 {testing.expect_value(t,net.server_step(&f.server),net.Error.None)}
 largest:=max(f.server.codecs.welcome.wire_size,max(f.server.codecs.snapshot.wire_size,f.server.codecs.facts.wire_size))+sc.HEADER_BYTES
 limit:=max(f.server.cfg.egress_bytes_per_second/4,largest)
 testing.expect(t,f.server.stats.tx_bytes-before<=u64(limit))
 testing.expect(t,f.server.stats.egress_deferred>0)
}
