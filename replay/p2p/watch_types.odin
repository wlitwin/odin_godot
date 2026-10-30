package replay_p2p

import "core:mem"
import r "godot:replay"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

WATCH_KIND :: u16(0x7142)
WATCH_VERSION :: u16(1)
MAX_WATCH_BYTES :: 1024 * 1024

Watch_Stats :: struct {installed, replayed, resets, skipped_ticks, bytes, rebinds: u64}
Watch_Reset :: struct {sequence, previous_tick, baseline_tick: u64}
Watch_Anchor :: struct {session, epoch, content, contract, tick, chain, digest:u64}

// A read-only confirmed-history consumer. Never occupies a player roster slot.
// Owns storage; transport is borrowed. Keep it at a stable address.
Watch :: struct($S, $I, $E: typeid, $N: int) {
	allocator: mem.Allocator,
	ready, has_world: bool,
	states: [2]Runner(S, I, E, N),
	active: int,
	contract, initial_tick, initial_hash: u64,
	codecs: Watch_Codecs,
	transfer: rec.Blob_Receiver,
	rxb: []u8,
	stats: Watch_Stats,
	reset: Watch_Reset,
	error: Error,
	report: Replay_Report,
	rebind_pending:bool,
}

// One bounded transfer stream per admitted spectator. The peer is borrowed;
// spectators' receipts never enter the peer's input/confirmation frontiers.
Watch_Source :: struct($S, $I, $E: typeid, $N: int) {
	allocator: mem.Allocator,
	ready: bool,
	peer: ^Runner(S, I, E, N),
	transfer: rec.Sender,
	codecs: Watch_Codecs,
	rxb: []u8,
	interval_ms, next_at: u64,
	publications: u64,
	resume_anchor:Watch_Anchor,
	resume_pending:bool,
}

@(private)
Watch_Header :: struct {version: u16, contract, initial_tick, initial_hash, base_tick, head, base_chain, base_digest, chain: u64, events, ticks: u32}
@(private)
Watch_Tick :: struct($I: typeid, $N: int) {inputs: [N]I, chain: u64}
@(private)
Watch_Codecs :: struct {header, frame, event, tick: sc.Schema, fingerprint: u64}
