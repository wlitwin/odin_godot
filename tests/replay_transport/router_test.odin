package replay_transport_test

import "core:testing"
import tr "godot:replay/transport"

route_byte :: proc(user: rawptr, from: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> int {return int(bytes[0])}

@(test)
third_lane_shares_the_background_budget_and_preserves_primary_reserve :: proc(t: ^testing.T) {
	m: tr.Memory; tr.memory_init(&m, cfg = {2, 16, 65536, 128}); defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint; tr.memory_open(&m, &a, 1); tr.memory_open(&m, &b, 2)
	wa, wb := tr.memory_transport(&a), tr.memory_transport(&b); defer tr.close(&wa); defer tr.close(&wb)
	router: tr.Router; defer tr.router_destroy(&router)
	cfg := tr.DEFAULT_ROUTER_CONFIG
	cfg.burst_bytes, cfg.egress_per_pump, cfg.primary_reserve = 65536, 65536, 8192
	testing.expect(t, !tr.router_init(&router, wa, route_byte, cfg, lane_count = tr.MAX_ROUTER_LANES + 1))
	testing.expect(t, tr.router_init(&router, wa, route_byte, cfg, lane_count = 3))
	testing.expect_value(t, len(router.lanes), 3)
	primary, backup, content := tr.router_transport(&router, 0), tr.router_transport(&router, 1), tr.router_transport(&router, 2)
	bytes := make([]u8, 24000); defer delete(bytes)
	tr.router_pump(&router, 0)
	testing.expect_value(t, tr.send(&backup, 2, .Unreliable, bytes), tr.Send_Result.Sent)
	testing.expect_value(t, tr.send(&content, 2, .Unreliable, bytes), tr.Send_Result.Sent)
	testing.expect_value(t, tr.send(&content, 2, .Unreliable, bytes[:16000]), tr.Send_Result.Backpressure)
	testing.expect_value(t, tr.send(&primary, 2, .Reliable, bytes[:16000]), tr.Send_Result.Sent)
	testing.expect_value(t, router.stats.tx_bytes, u64(64000))
}

@(test)
router_background_overflow_does_not_block_gameplay_and_small_reads_retain_packets :: proc(t: ^testing.T) {
	m: tr.Memory
	tr.memory_init(&m, cfg = {2, 16, 65536, 128})
	defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1); tr.memory_open(&m, &b, 2)
	wa, wb := tr.memory_transport(&a), tr.memory_transport(&b)
	defer tr.close(&wa); defer tr.close(&wb)
	router: tr.Router
	defer tr.router_destroy(&router)
	cfg := tr.DEFAULT_ROUTER_CONFIG; cfg.packets_per_lane = 1
	testing.expect(t, tr.router_init(&router, wb, route_byte, cfg))
	background := [3]u8{1, 7, 8}
	game := [3]u8{0, 9, 10}
	tr.send(&wa, 2, .Unreliable, background[:])
	tr.send(&wa, 2, .Unreliable, background[:])
	tr.send(&wa, 2, .Reliable, game[:])
	tr.memory_advance(&m, 1); tr.router_pump(&router, 1)
	primary, secondary := tr.router_transport(&router, 0), tr.router_transport(&router, 1)
	buffer: [10]u8
	testing.expect_value(t, tr.receive(&primary, buffer[:1]).state, tr.Receive_State.Buffer_Too_Small)
	packet := tr.receive(&primary, buffer[:])
	testing.expect_value(t, packet.state, tr.Receive_State.Received)
	testing.expect_value(t, packet.from, tr.Peer_Id(1))
	testing.expect_value(t, packet.channel, tr.Channel.Reliable)
	testing.expect_value(t, buffer[1], u8(9))
	testing.expect_value(t, tr.receive(&secondary, buffer[:]).state, tr.Receive_State.Received)
	testing.expect_value(t, router.stats.dropped[1], u64(1))
}

@(test)
router_preserves_reliable_queue_overflow_and_wrapped_payload_bytes :: proc(t: ^testing.T) {
	m: tr.Memory
	tr.memory_init(&m, cfg = {2, 8, 65536, 128})
	defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1); tr.memory_open(&m, &b, 2)
	wa, wb := tr.memory_transport(&a), tr.memory_transport(&b)
	defer tr.close(&wa); defer tr.close(&wb)
	router: tr.Router
	defer tr.router_destroy(&router)
	cfg := tr.DEFAULT_ROUTER_CONFIG; cfg.bytes_per_lane, cfg.packets_per_lane = 65536, 1
	tr.router_init(&router, wb, route_byte, cfg)
	primary := tr.router_transport(&router, 0)
	bytes := make([]u8, 40000); defer delete(bytes)
	for &value, i in bytes {value = u8(i % 251)}
	tr.send(&wa, 2, .Reliable, bytes[:])
	tr.send(&wa, 2, .Reliable, bytes[:])
	tr.memory_advance(&m, 1); tr.router_pump(&router, 1)
	testing.expect(t, router.pending)
	received := make([]u8, len(bytes)); defer delete(received)
	testing.expect_value(t, tr.receive(&primary, received).state, tr.Receive_State.Received)
	tr.router_pump(&router, 2)
	testing.expect(t, !router.pending)
	testing.expect_value(t, tr.receive(&primary, received).state, tr.Receive_State.Received)
	for value, i in bytes {testing.expect_value(t, received[i], value)}
	testing.expect_value(t, router.stats.dropped[0], u64(0))
}

@(test)
router_combines_output_budgets_and_reserves_capacity_for_gameplay :: proc(t: ^testing.T) {
	m: tr.Memory
	tr.memory_init(&m, cfg = {2, 16, 65536, 128})
	defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1); tr.memory_open(&m, &b, 2)
	wa, wb := tr.memory_transport(&a), tr.memory_transport(&b)
	defer tr.close(&wa); defer tr.close(&wb)
	router: tr.Router
	defer tr.router_destroy(&router)
	cfg := tr.DEFAULT_ROUTER_CONFIG
	cfg.egress_per_second, cfg.egress_per_pump, cfg.burst_bytes, cfg.primary_reserve = 8192, 65536, 65536, 8192
	tr.router_init(&router, wa, route_byte, cfg)
	primary, secondary := tr.router_transport(&router, 0), tr.router_transport(&router, 1)
	bytes := make([]u8, 20000); defer delete(bytes)
	testing.expect_value(t, tr.send(&primary, 2, .Reliable, bytes), tr.Send_Result.Backpressure)
	tr.router_pump(&router, 0)
	testing.expect_value(t, tr.send(&secondary, 2, .Unreliable, bytes), tr.Send_Result.Sent)
	testing.expect_value(t, tr.send(&secondary, 2, .Unreliable, bytes), tr.Send_Result.Sent)
	testing.expect_value(t, tr.send(&secondary, 2, .Unreliable, bytes), tr.Send_Result.Backpressure)
	testing.expect_value(t, tr.send(&primary, 2, .Reliable, bytes), tr.Send_Result.Sent)
	tr.router_pump(&router, 0) // repeated pumping at one timestamp cannot refill tokens
	testing.expect_value(t, tr.send(&primary, 2, .Reliable, bytes), tr.Send_Result.Backpressure)
	tr.router_pump(&router, 2000)
	testing.expect_value(t, tr.send(&primary, 2, .Reliable, bytes), tr.Send_Result.Sent)
	testing.expect(t, router.stats.tx_bytes <= u64(cfg.burst_bytes + cfg.egress_per_second * 2))
	testing.expect(t, !tr.router_pump(&router, 1999))
}
