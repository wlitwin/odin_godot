package replay_transport_test

import "core:reflect"
import "core:testing"
import tr "godot:replay/transport"

@(test)
queued_packets_own_bytes_and_receive_backpressure_preserves_them :: proc(t: ^testing.T) {
	m: tr.Memory
	tr.memory_init(&m, cfg = {2, 2, 8, 64})
	defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1)
	tr.memory_open(&m, &b, 2)
	ta, tb := tr.memory_transport(&a), tr.memory_transport(&b)
	defer tr.close(&ta)
	defer tr.close(&tb)
	bytes := [2]u8{3, 4}
	testing.expect_value(t, tr.send(&ta, 2, .Reliable, bytes[:]), tr.Send_Result.Sent)
	bytes = {8, 9}
	tr.memory_advance(&m, 0)
	short: [1]u8
	received := tr.receive(&tb, short[:])
	testing.expect_value(t, received.state, tr.Receive_State.Buffer_Too_Small)
	testing.expect_value(t, received.count, 2)
	testing.expect_value(t, received.from, tr.Peer_Id(1))
	out: [8]u8
	received = tr.receive(&tb, out[:])
	testing.expect_value(t, received.state, tr.Receive_State.Received)
	testing.expect_value(t, out[0], u8(3))
	testing.expect_value(t, out[1], u8(4))
	testing.expect_value(t, tr.receive(&tb, out[:]).state, tr.Receive_State.Empty)
}

@(test)
reliable_channel_survives_blackout_in_order :: proc(t: ^testing.T) {
	m: tr.Memory
	tr.memory_init(&m, cfg = {2, 8, 8, 128}, faults = {loss_permyriad = 10000, retry_ticks = 2})
	defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1)
	tr.memory_open(&m, &b, 2)
	ta, tb := tr.memory_transport(&a), tr.memory_transport(&b)
	defer tr.close(&ta)
	defer tr.close(&tb)
	for i in u8(1) ..= 3 {
		packet := [1]u8{i}
		tr.send(&ta, 2, .Reliable, packet[:])
	}
	drop := [1]u8{9}
	tr.send(&ta, 2, .Unreliable, drop[:])
	tr.memory_advance(&m, 10)
	out: [8]u8
	testing.expect_value(t, tr.receive(&tb, out[:]).state, tr.Receive_State.Empty)
	tr.memory_set_faults(&m, tr.DEFAULT_FAULTS)
	tr.memory_advance(&m, 12)
	for i in u8(1) ..= 3 {
		testing.expect_value(t, tr.receive(&tb, out[:]).state, tr.Receive_State.Received)
		testing.expect_value(t, out[0], i)
	}
	testing.expect_value(t, tr.receive(&tb, out[:]).state, tr.Receive_State.Empty)
	testing.expect_value(t, m.trace_dropped, 0)
}

@(test)
unreliable_duplication_and_capacity_are_explicit :: proc(t: ^testing.T) {
	m: tr.Memory
	tr.memory_init(&m, cfg = {2, 2, 4, 64}, faults = {duplicate_permyriad = 10000, retry_ticks = 1})
	defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1)
	tr.memory_open(&m, &b, 2)
	ta, tb := tr.memory_transport(&a), tr.memory_transport(&b)
	defer tr.close(&ta)
	defer tr.close(&tb)
	packet := [1]u8{7}
	testing.expect_value(t, tr.send(&ta, 2, .Unreliable, packet[:]), tr.Send_Result.Sent)
	testing.expect_value(t, tr.send(&ta, 2, .Reliable, packet[:]), tr.Send_Result.Backpressure)
	tr.memory_advance(&m, 0)
	out: [4]u8
	for _ in 0 ..< 2 {testing.expect_value(t, tr.receive(&tb, out[:]).state, tr.Receive_State.Received)}
	tr.close(&tb)
	testing.expect_value(t, tr.send(&ta, 2, .Reliable, packet[:]), tr.Send_Result.Disconnected)
	testing.expect_value(t, tr.send(&ta, 0, .Reliable, packet[:]), tr.Send_Result.Invalid)
}

@(test)
same_seed_and_schedule_reproduce_fault_trace_and_output :: proc(t: ^testing.T) {
	first, second: tr.Memory
	cfg := tr.Memory_Config{3, 64, 8, 4096}
	faults := tr.Faults{latency_ticks = 2, jitter_ticks = 8, loss_permyriad = 3500, duplicate_permyriad = 2000, retry_ticks = 3}
	tr.memory_init(&first, 42, cfg, faults)
	tr.memory_init(&second, 42, cfg, faults)
	defer tr.memory_destroy(&first)
	defer tr.memory_destroy(&second)
	networks := [2]^tr.Memory{&first, &second}
	for network in networks {
		a, b: tr.Memory_Endpoint
		tr.memory_open(network, &a, 1)
		tr.memory_open(network, &b, 2)
		ta, tb := tr.memory_transport(&a), tr.memory_transport(&b)
		last_reliable := -1
		for tick in u64(0) ..< 100 {
			packet := [2]u8{u8(tick), u8(tick * 3)}
			mode := tick % 2 == 0 ? tr.Channel.Reliable : tr.Channel.Unreliable
			tr.send(&ta, 2, mode, packet[:])
			tr.memory_advance(network, tick)
			out: [8]u8
			for {
				received := tr.receive(&tb, out[:])
				if received.state != .Received {break}
				if received.channel == .Reliable {
					testing.expect(t, int(out[0]) > last_reliable)
					last_reliable = int(out[0])
				}
			}
		}
		tr.close(&ta)
		tr.close(&tb)
	}
	testing.expect_value(t, first.trace_dropped, 0)
	testing.expect_value(t, first.trace_hash, second.trace_hash)
	testing.expect(t, reflect.equal(first.trace[:first.trace_count], second.trace[:second.trace_count], true))
}

@(test)
real_transport_delay_preserves_backpressure_and_connection_state :: proc(t: ^testing.T) {
	m: tr.Memory
	tr.memory_init(&m, cfg = {2, 4, 8, 64})
	defer tr.memory_destroy(&m)
	a, b: tr.Memory_Endpoint
	tr.memory_open(&m, &a, 1)
	tr.memory_open(&m, &b, 2)
	wa, wb := tr.memory_transport(&a), tr.memory_transport(&b)
	d: tr.Delay
	testing.expect(t, tr.delay_init(&d, wb, 120, 1))
	wrapped := tr.delay_transport(&d)
	defer tr.close(&wa)
	defer tr.close(&wrapped)
	bytes := [2]u8{1, 2}
	tr.send(&wa, 2, .Reliable, bytes[:])
	tr.memory_advance(&m, 0)
	tr.delay_time(&d, 10)
	tr.poll(&wrapped)
	out: [2]u8
	testing.expect_value(t, tr.receive(&wrapped, out[:]).state, tr.Receive_State.Empty)
	tr.delay_time(&d, 130)
	testing.expect_value(t, tr.receive(&wrapped, out[:1]).state, tr.Receive_State.Buffer_Too_Small)
	testing.expect_value(t, tr.receive(&wrapped, out[:]).state, tr.Receive_State.Received)
	testing.expect_value(t, out, bytes)
	testing.expect(t, tr.peer_connected(&wrapped, 1))
	tr.close(&wa)
	testing.expect(t, !tr.peer_connected(&wrapped, 1))
}
