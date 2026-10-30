package replay_p2p_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"
import game "../../examples/replay_duel/shared/duel"

@(test)
duel_projectile_lifetimes_and_deaths_converge_through_peer_rollback :: proc(t: ^testing.T) {
	network: tr.Memory
	tr.memory_init(&network, seed = 73, cfg = {2, 512, 8192, 65536}, faults = {latency_ticks = 3, jitter_ticks = 2, loss_permyriad = 1000, duplicate_permyriad = 1000, retry_ticks = 3})
	defer tr.memory_destroy(&network)
	endpoints: [2]tr.Memory_Endpoint
	peers: [2]rb.Runner(game.World, game.Input, game.Event, 2)
	roster := [2]tr.Peer_Id{1, 2}
	for &endpoint, i in endpoints {tr.memory_open(&network, &endpoint, roster[i])}
	for &peer, i in peers {
		testing.expect_value(t, rb.init(&peer, r.Frame(game.World){state = game.initial(42)}, game.model(), roster, u16(i), tr.memory_transport(&endpoints[i])), rb.Error.None)
	}
	defer {for &peer in peers {rb.destroy(&peer)}; for &endpoint in endpoints {wire := tr.memory_transport(&endpoint); tr.close(&wire)}}
	for clock in u64(0) ..< 1800 {
		tr.memory_advance(&network, clock)
		for &peer, i in peers {
			testing.expect_value(t, rb.pump(&peer, clock * 1000 / 60), rb.Error.None)
			if peer.phase == .Running && peer.timeline.head < 1200 {
				result := rb.advance(&peer, game.corpus_input(peer.timeline.head + u64(peer.cfg.delay) + 1, i))
				testing.expect(t, result.error == .None || result.error == .Waiting)
			}
		}
	}
	reference := game.initial(42)
	for tick in u64(1) ..= 1200 {
		input: [2]game.Input
		if tick > 2 {for &value, i in input {value = game.corpus_input(tick, i)}}
		storage: [64]r.Occurrence(game.Event)
		ctx := r.Step(game.Event){tick = tick, epoch = 1, events = storage[:]}
		game.step(&reference, input, &ctx)
		testing.expect_value(t, ctx.error, r.Error.None)
	}
	for &peer in peers {
		frame, _ := r.current(&peer.timeline)
		testing.expect_value(t, frame.tick, u64(1200))
		testing.expect_value(t, peer.timeline.confirmed, u64(1200))
		testing.expect(t, reflect.equal(frame.state, reference))
		testing.expect(t, peer.stats.rollbacks > 0)
	}
	testing.expect_value(t, peers[0].chain, peers[1].chain)
	testing.expect(t, reference.kills[0] > 0 && reference.kills[1] > 0 && reference.shots > 50)
}
