package replay_p2p

import "core:mem"
import "core:reflect"
import r "godot:replay"
import tr "godot:replay/transport"

ARCHIVE_VERSION :: u16(1)
ARCHIVE_KIND :: u16(0x7141)
MAX_ARCHIVE_BYTES :: 16 * 1024 * 1024

Archive_Settings :: struct {session, epoch, content: u64, hz, history, delay, max_prediction, events_per_tick: u32, retry_ms, timeout_ms: u64}
Archive_Header :: struct {
	version: u16,
	protocol, initial_tick, initial_hash, contract, base_tick, head, confirmed, sampled, chain: u64,
	local: u16,
	phase: Phase,
	base_events, ticks, inputs, hashes: u32,
	mismatch: Mismatch,
}
Archive_Peers :: struct($N: int) {roster: [N]tr.Peer_Id, received, acknowledged: [N]u64, remote_hash: [N]Hash_Record}
Archive_Tick :: struct($I: typeid, $N: int) {tick: u64, inputs: [N]I, digest: u64}
Archive_Input :: struct($I: typeid) {peer: u16, tick: u64, value: I}
Archive_Hash :: struct {tick, value: u64}
Replay_Report :: struct {error: Error, tick, expected, actual: u64}

// Owned values; no runtime pointers or transport resources are serialized.
Archive :: struct($S, $I, $E: typeid, $N: int) {
	allocator: mem.Allocator,
	ready: bool,
	header: Archive_Header,
	settings: Archive_Settings,
	peers: Archive_Peers(N),
	base: r.Frame(S),
	base_held: [N]I,
	base_events: []r.Occurrence(E),
	ticks: []Archive_Tick(I, N),
	inputs: [dynamic]Archive_Input(I),
	hashes: [dynamic]Archive_Hash,
}

archive_destroy :: proc(a: ^Archive($S, $I, $E, $N)) {
	delete(a.base_events, a.allocator); delete(a.ticks, a.allocator)
	delete(a.inputs); delete(a.hashes); a^ = {}
}

archive_capture :: proc(p: ^Runner($S, $I, $E, $N), a: ^Archive(S, I, E, N), allocator := context.allocator) -> Error {
	if !p.ready || p.dirty != 0 || p.phase == .Failed || !archive_empty(a) {return .Not_Ready}
	base_tick := max(p.initial_tick, p.timeline.head >= u64(p.cfg.history - 1) ? p.timeline.head - u64(p.cfg.history - 1) : 0)
	base, found := r.read(&p.timeline, base_tick)
	if !found {return .History}
	tmp: Archive(S, I, E, N)
	committed := false; defer if !committed {archive_destroy(&tmp)}
	tmp.allocator = allocator
	tmp.header = {version = ARCHIVE_VERSION, protocol = VERSION, initial_tick = p.initial_tick, initial_hash = p.initial_hash,
	              contract = p.contract, base_tick = base_tick, head = p.timeline.head, confirmed = p.timeline.confirmed,
	              sampled = p.sampled, chain = p.chain, local = p.local, phase = p.phase, mismatch = p.mismatch}
	tmp.settings = archive_settings(p.cfg)
	tmp.peers = {p.roster, p.received, p.acknowledged, p.remote_hash}
	tmp.base = base
	if base_tick == p.initial_tick {for &input in tmp.base_held {input = p.model.neutral}} else {
		tmp.base_held, found = r.read_input(&p.timeline, base_tick)
		if !found {return .History}
	}
	n, err := r.copy_events(&p.timeline, base_tick, p.event_scratch)
	if err != .None {return .History}
	tmp.base_events = make([]r.Occurrence(E), n, allocator); copy(tmp.base_events, p.event_scratch[:n])
	tmp.ticks = make([]Archive_Tick(I, N), int(p.timeline.head - base_tick), allocator)
	for &tick, i in tmp.ticks {
		at := base_tick + u64(i) + 1
		input, known := r.read_input(&p.timeline, at)
		digest, hashed := frame_digest(p, at, 0xcbf29ce484222325)
		if !known || !hashed {return .History}
		tick = {at, input, digest}
	}
	tmp.inputs = make([dynamic]Archive_Input(I), 0, len(p.inputs), allocator)
	for input, index in p.inputs {if input.valid {append(&tmp.inputs, Archive_Input(I){u16(index / p.cfg.history), input.tick, input.value})}}
	tmp.hashes = make([dynamic]Archive_Hash, 0, len(p.hashes), allocator)
	for hash in p.hashes {if hash.valid {append(&tmp.hashes, Archive_Hash{hash.tick, hash.value})}}
	tmp.header.base_events, tmp.header.ticks, tmp.header.inputs, tmp.header.hashes = u32(n), u32(len(tmp.ticks)), u32(len(tmp.inputs)), u32(len(tmp.hashes))
	tmp.ready = true
	if !archive_valid(&tmp, p.model) {return .Invalid_Archive}
	a^ = tmp; committed = true
	return .None
}

archive_valid :: proc(a: ^Archive($S, $I, $E, $N), model: Model(S, I, E, N)) -> bool {
	if !a.ready || a.header.version != ARCHIVE_VERSION || a.header.protocol != VERSION || int(a.header.local) >= N ||
	   !config_valid(archive_config(a.settings), a.header.initial_tick) || a.header.phase == .Failed || a.header.phase > .Diverged ||
	   a.header.base_tick < a.header.initial_tick || a.base.tick != a.header.base_tick || a.header.confirmed < a.base.tick ||
	   a.header.head < a.header.confirmed || a.header.head - a.base.tick >= u64(a.settings.history) ||
	   a.header.head - a.header.confirmed > u64(a.settings.max_prediction) || a.header.head > max(u64) - u64(a.settings.history) ||
	   a.header.sampled < a.header.head + u64(a.settings.delay) || a.header.sampled > a.header.head + u64(a.settings.delay) + 1 {return false}
	if model.state_valid == nil || model.input_valid == nil || !model.state_valid(a.base.state) {return false}
	if len(a.base_events) != int(a.header.base_events) || len(a.base_events) > int(a.settings.events_per_tick) ||
	   len(a.ticks) != int(a.header.ticks) || u64(len(a.ticks)) != a.header.head - a.base.tick ||
	   len(a.inputs) != int(a.header.inputs) || len(a.inputs) > N * int(a.settings.history) ||
	   len(a.hashes) != int(a.header.hashes) || len(a.hashes) > int(a.settings.history) {return false}
	for input in a.base_held {if !model.input_valid(input) {return false}}
	for event, i in a.base_events {
		if event.id.tick != a.base.tick || event.id.epoch != a.settings.epoch {return false}
		for previous in a.base_events[:i] {if previous.id == event.id {return false}}
	}
	for tick, i in a.ticks {
		if tick.tick != a.base.tick + u64(i) + 1 {return false}
		for input in tick.inputs {if !model.input_valid(input) {return false}}
	}
	minimum := a.header.head
	for peer, i in a.peers.roster {
		if peer == 0 {return false}; for j in 0 ..< i {if a.peers.roster[j] == peer {return false}}
		if a.peers.received[i] < a.header.initial_tick + u64(a.settings.delay) || a.peers.received[i] > a.header.head + u64(a.settings.history) - 1 ||
		   a.peers.acknowledged[i] < a.header.initial_tick + u64(a.settings.delay) || a.peers.acknowledged[i] > a.header.sampled {return false}
		minimum = min(minimum, a.peers.received[i])
		hash := a.peers.remote_hash[i]
		if hash.valid && (hash.tick < a.header.initial_tick || hash.tick >= a.header.head + u64(a.settings.history)) {return false}
	}
	if minimum != a.header.confirmed || a.peers.received[a.header.local] != a.header.sampled {return false}
	input_slots: [N][1024]u64
	for input in a.inputs {
		if int(input.peer) >= N || input.tick <= a.header.initial_tick || input.tick >= a.header.head + u64(a.settings.history) || !model.input_valid(input.value) {return false}
		index := input.tick % u64(a.settings.history)
		if input_slots[input.peer][index] != 0 {return false}; input_slots[input.peer][index] = input.tick
		if input.peer == a.header.local && input.tick > a.header.sampled {return false}
		if input.tick > a.header.confirmed && input.tick <= a.header.head {
			if !reflect.equal(input.value, a.ticks[int(input.tick - a.base.tick - 1)].inputs[input.peer]) {return false}
		}
	}
	for received, i in a.peers.received {
		for tick := max(a.header.confirmed + 1, a.header.initial_tick + 1); tick <= received; tick += 1 {if input_slots[i][tick % u64(a.settings.history)] != tick {return false}}
	}
	for ack, i in a.peers.acknowledged {if i != int(a.header.local) {
		if a.header.sampled - ack > u64(a.settings.history) {return false}
		for tick := ack + 1; tick <= a.header.sampled; tick += 1 {if input_slots[a.header.local][tick % u64(a.settings.history)] != tick {return false}}
	}}
	hash_slots: [1024]u64
	base_found, last_found := false, false
	for hash in a.hashes {
		if hash.tick < a.header.initial_tick || hash.tick > a.header.confirmed {return false}
		index := hash.tick % u64(a.settings.history)
		if hash_slots[index] != 0 {return false}; hash_slots[index] = hash.tick + 1
		if hash.tick == a.base.tick {base_found = true}
		if hash.tick == a.header.confirmed {last_found = hash.value == a.header.chain}
	}
	for tick := a.base.tick; tick <= a.header.confirmed; tick += 1 {if hash_slots[tick % u64(a.settings.history)] != tick + 1 {return false}}
	if a.header.phase == .Diverged {
		m := a.header.mismatch
		if int(m.peer) >= N || m.peer == a.header.local || m.tick < a.header.initial_tick || m.tick > a.header.confirmed || m.local_hash == m.remote_hash {return false}
		remote := a.peers.remote_hash[m.peer]
		if !remote.valid || remote.tick != m.tick || remote.value != m.remote_hash {return false}
		found := false
		for hash in a.hashes {if hash.tick == m.tick {found = hash.value == m.local_hash; break}}
		if !found {return false}
	}
	return base_found && last_found
}

restore :: proc(p: ^Runner($S, $I, $E, $N), a: ^Archive(S, I, E, N), model: Model(S, I, E, N),
                roster: [N]tr.Peer_Id, local: u16, wire: tr.Transport, allocator := context.allocator, report: ^Replay_Report = nil) -> (error: Error) {
	if report != nil {report^ = {}}
	defer if report != nil {report.error = error}
	if p.ready {return .Not_Ready}
	if a.header.local != local || a.peers.roster != roster || !archive_valid(a, model) {return .Invalid_Archive}
	if err := init(p, a.base, model, roster, local, wire, archive_config(a.settings), allocator); err != .None {return err}
	committed := false; defer if !committed {destroy(p)}
	if contract_for(a.header.initial_hash, p.cfg, roster, p.state_codec.fingerprint, p.input_codec.fingerprint, p.event_codec.fingerprint) != a.header.contract {return .Invalid_Archive}
	if r.seed_checkpoint_events(&p.timeline, a.base_events) != .None {return .Invalid_Archive}
	for &input in p.inputs {input = {}}
	for &hash in p.hashes {hash = {}}
	for hash in a.hashes {p.hashes[hash.tick % u64(p.cfg.history)] = {hash.tick, hash.value, true}}
	p.chain = p.hashes[a.base.tick % u64(p.cfg.history)].value
	if a.base.tick == a.header.initial_tick {
		digest, ok := frame_digest(p, a.base.tick, 0xcbf29ce484222325)
		if !ok || digest != a.header.initial_hash || digest != p.chain {return .Invalid_Archive}
	}
	for tick in a.ticks {
		if r.advance(&p.timeline, tick.inputs).error != .None {if report != nil {report^ = {.Replay_Mismatch, tick.tick, tick.digest, 0}}; return .Replay_Mismatch}
		digest, ok := frame_digest(p, tick.tick, 0xcbf29ce484222325)
		if !ok || digest != tick.digest {if report != nil {report^ = {.Replay_Mismatch, tick.tick, tick.digest, digest}}; return .Replay_Mismatch}
		if tick.tick <= a.header.confirmed {
			expected := p.hashes[tick.tick % u64(p.cfg.history)]
			if !expected.valid || expected.tick != tick.tick || !hash_frame(p, tick.tick) || p.chain != expected.value {
				if report != nil {report^ = {.Replay_Mismatch, tick.tick, expected.value, p.chain}}
				return .Replay_Mismatch
			}
		}
	}
	if p.chain != a.header.chain || r.confirm_through(&p.timeline, a.header.confirmed) != .None {return .Invalid_Archive}
	for input in a.inputs {slot := input_slot(p, int(input.peer), input.tick); slot^ = {input.tick, input.value, true}}
	p.held = a.base_held
	if len(a.ticks) > 0 {p.held = a.ticks[len(a.ticks) - 1].inputs}
	p.initial_tick, p.initial_hash, p.contract, p.sampled, p.hash_tick = a.header.initial_tick, a.header.initial_hash, a.header.contract, a.header.sampled, a.header.confirmed
	p.received, p.acknowledged, p.remote_hash = a.peers.received, a.peers.acknowledged, a.peers.remote_hash
	p.phase, p.mismatch = a.header.phase == .Diverged ? .Diverged : .Connecting, a.header.mismatch
	if p.phase == .Diverged {p.error = .Diverged}
	committed = true
	if report != nil {report^ = {}}
	return .None
}

@(private)
archive_empty :: proc(a: ^Archive($S, $I, $E, $N)) -> bool {return !a.ready && len(a.base_events) == 0 && len(a.ticks) == 0 && cap(a.inputs) == 0 && cap(a.hashes) == 0}
@(private)
archive_settings :: proc(c: Config) -> Archive_Settings {return {c.session, c.epoch, c.content, c.hz, u32(c.history), c.delay, c.max_prediction, u32(c.events_per_tick), c.retry_ms, c.timeout_ms}}
@(private)
archive_config :: proc(c: Archive_Settings) -> Config {return {c.session, c.epoch, c.content, c.hz, int(c.history), c.delay, c.max_prediction, int(c.events_per_tick), c.retry_ms, c.timeout_ms}}
