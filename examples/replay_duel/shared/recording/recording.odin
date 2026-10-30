package duel_recording

import rb "godot:replay/p2p"
import game "../duel"

Report :: struct {
	error: rb.Error,
	phase: rb.Phase,
	base, head, confirmed, chain: u64,
	disagreement: rb.Mismatch,
	replay: rb.Replay_Report,
}

// Pure archive inspection/replay; no transport, filesystem, or Godot calls.
verify :: proc(bytes: []u8) -> Report {
	a: rb.Archive(game.World, game.Input, game.Event, 2)
	defer rb.archive_destroy(&a)
	if err := rb.archive_decode(&a, bytes, game.model(), game.CONTENT); err != .None {return {error = err}}
	result := Report{phase = a.header.phase, base = a.base.tick, head = a.header.head, confirmed = a.header.confirmed, chain = a.header.chain, disagreement = a.header.mismatch}
	p: rb.Runner(game.World, game.Input, game.Event, 2)
	defer rb.destroy(&p)
	result.error = rb.restore(&p, &a, game.model(), a.peers.roster, a.header.local, {}, report = &result.replay)
	return result
}
