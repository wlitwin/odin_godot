package replay_p2p_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"

Archive :: rb.Archive(World, Input, Event, 2)

roundtrip :: proc(t: ^testing.T, peer: ^Peer, decoded: ^Archive) {
	a: Archive; defer rb.archive_destroy(&a)
	testing.expect_value(t, rb.archive_capture(peer, &a), rb.Error.None)
	bytes, err := rb.archive_encode(&a, model()); defer delete(bytes)
	testing.expect_value(t, err, rb.Error.None)
	testing.expect_value(t, rb.archive_decode(decoded, bytes, model(), peer.cfg.content), rb.Error.None)
	testing.expect(t, reflect.equal(a.header, decoded.header))
	testing.expect(t, reflect.equal(a.base, decoded.base))
	testing.expect(t, reflect.equal(a.ticks, decoded.ticks, true))
	testing.expect(t, reflect.equal(a.inputs[:], decoded.inputs[:], true))
}

reset_transport :: proc(f: ^Fixture) {
	for &endpoint in f.endpoints {wire := tr.memory_transport(&endpoint); tr.close(&wire)}
	tr.memory_destroy(&f.network)
	assert(tr.memory_init(&f.network, seed = 99, cfg = {2, 512, 16384, 65536}, faults = {latency_ticks = 3, jitter_ticks = 1, loss_permyriad = 1000, retry_ticks = 3}))
	for &endpoint, i in f.endpoints {assert(tr.memory_open(&f.network, &endpoint, tr.Peer_Id(i + 1)))}
	f.clock = 0
}

@(test)
archive_roundtrip_preserves_speculation_inputs_hashes_and_future_progress :: proc(t: ^testing.T) {
	f: Fixture; setup(&f, {latency_ticks = 3, jitter_ticks = 1, loss_permyriad = 1000, retry_ticks = 3}); defer cleanup(&f)
	clock := Profile_Time{increment = 7, valid = true}
	rb.profile_set(&f.peers[0], profile_clock(&clock))
	for _ in 0 ..< 140 {cycle(&f, 300)}
	archives: [2]Archive
	defer for &a in archives {rb.archive_destroy(&a)}
	for &peer, i in f.peers {
		roundtrip(t, &peer, &archives[i])
		testing.expect(t, archives[i].header.base_tick > 0)
		testing.expect(t, archives[i].header.head > archives[i].header.confirmed)
		rb.destroy(&peer)
	}
	reset_transport(&f)
	for &peer, i in f.peers {
		testing.expect_value(t, rb.restore(&peer, &archives[i], model(), [2]tr.Peer_Id{1, 2}, u16(i), tr.memory_transport(&f.endpoints[i])), rb.Error.None)
		testing.expect_value(t, peer.timeline.head, archives[i].header.head)
		testing.expect_value(t, peer.chain, archives[i].header.chain)
		testing.expect_value(t, peer.sampled, archives[i].header.sampled)
		testing.expect(t, peer.profile.clock.read == nil && len(peer.profile.captures) == 0)
	}
	for _ in 0 ..< 500 {cycle(&f, 300)}
	expect_reference(t, &f, 300)
}

@(test)
restore_handshake_rebases_delivery_to_the_other_archives_durable_frontier :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer cleanup(&f)
	for _ in 0 ..< 80 {cycle(&f, 30)}
	archives: [2]Archive
	defer for &a in archives {rb.archive_destroy(&a)}
	roundtrip(t, &f.peers[1], &archives[1])
	for _ in 0 ..< 40 {
		tr.memory_advance(&f.network, f.clock)
		for &peer in f.peers {rb.pump(&peer, f.clock * 1000 / 60)}
		p := &f.peers[0]
		rb.advance(p, control(p.timeline.head + 3, 0))
		f.clock += 1
	}
	roundtrip(t, &f.peers[0], &archives[0])
	testing.expect(t, archives[0].peers.acknowledged[1] > archives[1].peers.received[0])
	for &peer in f.peers {rb.destroy(&peer)}
	reset_transport(&f)
	for &peer, i in f.peers {testing.expect_value(t, rb.restore(&peer, &archives[i], model(), [2]tr.Peer_Id{1, 2}, u16(i), tr.memory_transport(&f.endpoints[i])), rb.Error.None)}
	for _ in 0 ..< 350 {cycle(&f, 160)}
	expect_reference(t, &f, 160)
}

@(test)
archive_corruption_bounds_and_wrong_replay_fail_without_installation :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer cleanup(&f)
	for _ in 0 ..< 60 {cycle(&f, 50)}
	a, decoded: Archive; defer rb.archive_destroy(&a); defer rb.archive_destroy(&decoded)
	rb.archive_capture(&f.peers[0], &a)
	bytes, _ := rb.archive_encode(&a, model()); defer delete(bytes)
	testing.expect_value(t, rb.archive_decode(&decoded, bytes[:len(bytes) - 1], model(), 1), rb.Error.Invalid_Archive)
	bytes[len(bytes) - 1] ~= 1
	testing.expect_value(t, rb.archive_decode(&decoded, bytes, model(), 1), rb.Error.Invalid_Archive)
	bytes[len(bytes) - 1] ~= 1
	testing.expect_value(t, rb.archive_decode(&decoded, bytes, model(), 2), rb.Error.Invalid_Archive)
	testing.expect_value(t, rb.archive_decode(&decoded, bytes, model(), 1), rb.Error.None)
	peer: Peer; defer rb.destroy(&peer)
	decoded.ticks[0].digest ~= 1
	report: rb.Replay_Report
	testing.expect_value(t, rb.restore(&peer, &decoded, model(), [2]tr.Peer_Id{1, 2}, 0, {}, report = &report), rb.Error.Replay_Mismatch)
	testing.expect_value(t, report.error, rb.Error.Replay_Mismatch)
	testing.expect_value(t, report.tick, decoded.ticks[0].tick)
	testing.expect(t, report.expected != report.actual)
	testing.expect(t, !peer.ready && len(peer.timeline.records) == 0)
	decoded.settings.delay = max(u32)
	testing.expect(t, !rb.archive_valid(&decoded, model()))
	a.header.inputs = max(u32)
	testing.expect(t, !rb.archive_valid(&a, model()))
}

@(test)
divergence_recording_replays_original_execution_and_locates_changed_execution :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer cleanup(&f)
	bad := model()
	bad.step = proc(w: ^World, inputs: [2]Input, ctx: ^r.Step(Event)) {model_step(w, inputs, ctx); if ctx.tick == 12 {w.x[0] += 1}}
	f.peers[1].model = bad
	for _ in 0 ..< 100 {
		tr.memory_advance(&f.network, f.clock)
		for &peer, i in f.peers {
			if peer.phase == .Diverged {continue}
			rb.pump(&peer, f.clock * 1000 / 60)
			if peer.phase == .Running {rb.advance(&peer, control(peer.timeline.head + 3, i))}
		}
		if f.peers[1].phase == .Diverged {break}
		f.clock += 1
	}
	testing.expect_value(t, f.peers[1].phase, rb.Phase.Diverged)
	a, decoded: Archive; defer rb.archive_destroy(&a); defer rb.archive_destroy(&decoded)
	testing.expect_value(t, rb.archive_capture(&f.peers[1], &a), rb.Error.None)
	bytes, err := rb.archive_encode(&a, bad); defer delete(bytes)
	testing.expect_value(t, err, rb.Error.None)
	testing.expect_value(t, rb.archive_decode(&decoded, bytes, bad, 1), rb.Error.None)
	replayed: Peer; defer rb.destroy(&replayed)
	report: rb.Replay_Report
	testing.expect_value(t, rb.restore(&replayed, &decoded, bad, [2]tr.Peer_Id{1, 2}, 1, {}, report = &report), rb.Error.None)
	testing.expect_value(t, replayed.phase, rb.Phase.Diverged)
	testing.expect(t, reflect.equal(replayed.mismatch, f.peers[1].mismatch))
	testing.expect_value(t, rb.advance(&replayed, Input{}).error, rb.Error.Not_Ready)
	rb.destroy(&replayed)
	testing.expect_value(t, rb.restore(&replayed, &decoded, model(), [2]tr.Peer_Id{1, 2}, 1, {}, report = &report), rb.Error.Replay_Mismatch)
	testing.expect_value(t, report.tick, u64(12))
	testing.expect(t, report.expected != report.actual && !replayed.ready)
	decoded.header.mismatch.peer = decoded.header.local
	testing.expect(t, !rb.archive_valid(&decoded, model()))
}

@(test)
overflowing_configuration_cannot_wrap_into_an_unbounded_delay_loop :: proc(t: ^testing.T) {
	p: Peer; defer rb.destroy(&p)
	cfg := rb.DEFAULT_CONFIG; cfg.delay = max(u32)
	testing.expect_value(t, rb.init(&p, r.Frame(World){}, model(), [2]tr.Peer_Id{1, 2}, 0, {}, cfg), rb.Error.Invalid_Config)
}

@(test)
restore_refuses_to_recapture_inputs_that_other_peers_already_received :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer cleanup(&f)
	for _ in 0 ..< 80 {cycle(&f, 30)}
	archives: [2]Archive; defer for &a in archives {rb.archive_destroy(&a)}
	roundtrip(t, &f.peers[0], &archives[0])
	for _ in 0 ..< 90 {cycle(&f, 70)}
	roundtrip(t, &f.peers[1], &archives[1])
	testing.expect(t, archives[1].peers.received[0] > archives[0].header.sampled)
	for &peer in f.peers {rb.destroy(&peer)}
	reset_transport(&f)
	for &peer, i in f.peers {testing.expect_value(t, rb.restore(&peer, &archives[i], model(), [2]tr.Peer_Id{1, 2}, u16(i), tr.memory_transport(&f.endpoints[i])), rb.Error.None)}
	for _ in 0 ..< 30 {
		tr.memory_advance(&f.network, f.clock)
		for &peer in f.peers {rb.pump(&peer, f.clock * 1000 / 60)}
		f.clock += 1
	}
	testing.expect_value(t, f.peers[0].phase, rb.Phase.Failed)
	testing.expect_value(t, f.peers[0].error, rb.Error.History)
	testing.expect_value(t, f.peers[0].timeline.head, archives[0].header.head)
	testing.expect_value(t, f.peers[0].sampled, archives[0].header.sampled)
}
