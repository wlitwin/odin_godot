package kit_session

// kit/session — player identity and the shared roster: who is in this run,
// under which stable Player_Id, connected or not. The session core of the
// friendslop toolkit (phase 1), grown from the acid test's session node.
//
// THE IDENTITY MODEL: a player IS a reconnect token — a random u64 secret the
// client generates once and persists (the game saves it; the tests pass it in).
// The host maps token → Player_Id forever: reconnecting with the same token —
// from a NEW transport peer, after a crash, mid-game — reclaims the same id,
// and with it (in later bricks) name, stats, and owned entities. Player_Ids
// are never derived from transport peer ids, which is what makes reconnect
// (and post-v1 host migration) possible at all. Departed players stay in the
// roster as disconnected for exactly this reason.
//
// ENGINE-FREE, like kit/net: the game script owns the sockets and the framing.
// The contract is three hookups —
//   * send:            the session hands complete message bytes + a target
//                      peer to the game, which prefixes ITS session kind byte
//                      and ships them on the reliable channel (kit/netgd).
//   * handle_packet:   the game routes its session kind byte back here.
//   * peer up/down:    the game forwards the transport's connect/disconnect
//                      signals (session join is a JOIN message, not a socket
//                      event — a connected-but-never-joined peer is nobody).
// Everything the game needs to REACT to comes out of one event queue, drained
// per frame (session_poll) — no callbacks into half-initialized script state.
//
// v1 has no host migration: the host vanishing ends the run (Ev_Host_Left —
// the game shows its "run over" screen). Backup-host snapshots (a later
// brick) keep the door open.

import knet "godot:kit/net"
import "core:strings"

// Which wire the message rides — maps to kit/netgd's channel plan.
Channel :: enum u8 {
	Reliable, // commands, results, state batches, roster, pings
	Stream,   // owner-stream snapshots: unreliable-ordered, last-value
}

// A TRANSPORT peer id — distinct from knet.Player_Id on purpose: peers are
// socket seats (reassigned on reconnect, meaningless across runs), players
// are identities. The type keeps the two from silently crossing at API
// boundaries (a bug class every reviewer flagged).
Peer_Id :: distinct int

// The transport hookup. `to_peer` is a transport peer id (ENet/WebRTC/Steam
// semantics belong to the game+netgd layer; the session never broadcasts —
// it targets connected players individually).
Send_Proc :: proc(user: rawptr, to_peer: Peer_Id, bytes: []u8, channel: Channel)

// ENet/SceneMultiplayer convention: the host is always transport peer 1.
HOST_PEER :: Peer_Id(1)

// A disconnected player's seat.
NO_PEER :: Peer_Id(0)

Player :: struct {
	id:        knet.Player_Id,
	name:      string, // owned by the session
	peer:      Peer_Id, // transport seat; NO_PEER while disconnected
	connected: bool,
}

// ---- events: everything the game reacts to, drained per frame --------------

Ev_Welcomed :: struct {
	me: knet.Player_Id, // (client) the host accepted us; the roster is seeded
}

Ev_Player_Joined :: struct {
	id:     knet.Player_Id,
	rejoin: bool, // reclaimed an existing identity (reconnect)
}

Ev_Player_Left :: struct {
	id: knet.Player_Id, // stays in the roster, disconnected (may reconnect)
}

Ev_Host_Left :: struct {} // (client) the run is over — v1 has no migration

Ev_Join_Failed :: struct {} // (client) no WELCOME within the join timeout — surface it, don't hang on "Joining..."

// Why a join was refused — each reason is a different sentence to the player.
Deny_Reason :: enum u8 {
	Full, // at max_players (Session_Config)
	Locked, // the host closed the door (session_set_locked)
	Banned, // a kicked-with-ban token came back
}

Ev_Join_Denied :: struct {
	reason: Deny_Reason, // (client) the host said no — deliberately
}

Ev_Kicked :: struct {} // (client) removed on purpose — distinct from Ev_Host_Left

Ev_Backup_Target :: struct {
	player: knet.Player_Id, // (host) the designated backup holder changed — compute and
	// session_set_successor_info how peers can find them if you want LIVE migration
}

Ev_Succession :: struct {
	successor: knet.Player_Id, // (client) the host is gone and THIS player holds the
	// backup — if it's you, take over; otherwise rejoin them (session_successor has
	// the transport info). Re-fires on every failed reconnect: a natural retry pulse.
}

Ev_Spawned :: struct {
	id:    knet.Net_Id, // (client) the factory made it and the snapshot applied
	type:  Entity_Type,
	owner: knet.Player_Id,
}

Ev_Despawned :: struct {
	id: knet.Net_Id, // (client) already removed; the factory's free ran
}

Ev_Owner_Changed :: struct {
	id:    knet.Net_Id, // whose owner-stream fields changed hands
	owner: knet.Player_Id, // who streams it now (INVALID = nobody — it rests)
	prev:  knet.Player_Id,
}

Ev_Stats_Updated :: struct {} // (client) a stat snapshot landed — repaint scoreboards

Ev_Backup_Received :: struct {
	size: int, // (client) we are the designated backup host; the blob is stored
}

Ev_State_Applied :: struct {
	entities: int, // (client) a host state batch landed on this many entities
}

Ev_Command_Executed :: struct {
	ok:     bool, // (host) a client command ran (or was rejected) authoritatively
	player: knet.Player_Id, // who issued it
	entity: knet.Net_Id, // what it targeted
	cmd:    u16, // which command in the target's set
}

Ev_Command_Confirmed :: struct {
	seq: knet.Intent_Seq, // (client) prediction stands
}

Ev_Command_Rejected :: struct {
	seq:    knet.Intent_Seq, // (client) truth applied (or revert fallback)
	entity: knet.Net_Id,
}

Event :: union {
	Ev_Welcomed,
	Ev_Player_Joined,
	Ev_Player_Left,
	Ev_Host_Left,
	Ev_Join_Failed,
	Ev_Join_Denied,
	Ev_Kicked,
	Ev_Backup_Target,
	Ev_Succession,
	Ev_Spawned,
	Ev_Despawned,
	Ev_Owner_Changed,
	Ev_Stats_Updated,
	Ev_Backup_Received,
	Ev_State_Applied,
	Ev_Command_Executed,
	Ev_Command_Confirmed,
	Ev_Command_Rejected,
}

// ---- the stat registry ---------------------------------------------------------
//
// Generic named counters on the player record: kills, deaths, damage, score —
// whatever the game declares. HOST-accumulated (gameplay mutates them on the
// authority only) and replicated to everyone as a full snapshot at a low rate
// when dirty (~2 Hz: display data, not simulation data). Stats live on the
// PLAYER, so they survive disconnects and come back with a reclaimed identity
// like everything else. Column 0 is always "ping": the host pings its clients
// and feeds each player's measured RTT (ms) in automatically.

Stat_Col :: distinct u8

MAX_STAT_COLS :: 16

// Always declared, always fed by the session itself.
STAT_PING :: Stat_Col(0)

// ---- entity factories --------------------------------------------------------
//
// The game's kind of thing: a small u16 the host stamps on every spawn so
// remote peers know WHAT to create (the values come in the same message).
Entity_Type :: distinct u16

// Client-side: create the local counterpart of a spawned entity — instantiate
// the node/scene for `type`, return its struct + command set. Returning nil
// skips the entity safely (unknown type: the wire carries its length). This is
// the one place the session CALLS INTO the game synchronously — the registry
// needs the pointer before the snapshot can apply; react to the spawn itself
// via Ev_Spawned, which fires right after.
Make_Entity_Proc :: proc(user: rawptr, type: Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (entity: rawptr, set: ^knet.Command_Set)

// Client-side: the entity was despawned and already removed from the registry
// — free the node/struct.
Free_Entity_Proc :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr)

// Host-side: called SYNCHRONOUSLY right after a client command executes (ok
// or rejected) — before any same-frame command can touch the entity again.
// This is the sanctioned spot for THE CROSS-ENTITY HALF of a command: a
// command proc may only mutate its target (that's what the predict/revert/
// reject-truth machinery protects), so "loot chest → items appear in MY bag"
// is a chest-only proc that records what it took in a non-replicated scratch
// field, plus this hook crediting the issuer's entity — a host-authoritative
// mutation that reaches everyone as an ordinary delta. The loser of a race
// gets a rejected chest command and no credit: phantom items are impossible.
// The host's OWN commands fire it too (the generated wrappers call it on the
// authority branch), so the hook is the single home for cross-entity halves —
// no "inline authority half" beside each issue site.
Command_Hook :: knet.Command_Hook

// ---- wire (sub-framed: the game's session kind byte comes first, then ours) --

@(private)
SES_JOIN :: u8(0) // client -> host  [token u64][name string]
@(private)
SES_WELCOME :: u8(1) // host -> client  [your_id][count u16] x ([id][name][connected u8])
@(private)
SES_UPSERT :: u8(2) // host -> others  [id][name][connected u8][rejoin u8]
@(private)
SES_LEFT :: u8(3) // host -> all     [id]
@(private)
SES_BYE :: u8(4) // client -> host  graceful leave (no payload)
@(private)
SES_STATE :: u8(5) // host -> all     registry delta batch, per net tick
@(private)
SES_CMD :: u8(6) // client -> host  command header + args
@(private)
SES_RESULT :: u8(7) // host -> issuer  confirm / reject+truth
@(private)
SES_STREAM :: u8(8) // owner -> all    owner-stream batch (Channel.Stream)
@(private)
SES_PING :: u8(9) // any -> any      [local_send f64]
@(private)
SES_PONG :: u8(10) // reply           [echoed_send][remote_time]
@(private)
SES_SPAWN :: u8(11) // host -> all    [type u16][id][owner][len u16][full fields]
@(private)
SES_DESPAWN :: u8(12) // host -> all  [id]
@(private)
SES_WORLD :: u8(13) // host -> one    [count u16] x the SES_SPAWN tuple (join snapshot)
@(private)
SES_STATS :: u8(14) // host -> all    [cols u8] x [name] + [players u16] x ([id][cols x i64])
@(private)
SES_BACKUP :: u8(15) // host -> ONE   the full re-hostable session snapshot (opaque to the client)
@(private)
SES_APP :: u8(16) // any -> any      [tag u8][payload] — routed to the registered app handler
@(private)
SES_DENIED :: u8(17) // host -> joiner  [reason u8] — the join was refused (full/locked/banned)
@(private)
SES_KICKED :: u8(18) // host -> one     you were removed on purpose (not a host crash)
@(private)
SES_SETOWNER :: u8(19) // host -> all   [id][owner] — ownership transfer (carry/mount/possess)
@(private)
SES_SUCCESSOR :: u8(20) // host -> all  [player][info] — who carries the torch if I die, and how to find them

// ---- app messages: the extension point for sibling kit packages ---------------
//
// SES_APP lets packages built ON TOP of the session (kit/comms is the first)
// ride its transport hookup instead of asking the game for another kind byte
// and another send glue proc: they register a handler under a small tag and
// ship bytes with session_app_send. The session applies its seat gates before
// routing — on the host `from` is the resolved sender (unseated peers are
// nobody and get dropped); on a client `from` is PLAYER_ID_INVALID and the
// handler checks from_peer == HOST_PEER when authority matters.

MAX_APP_TAGS :: 8

App_Handler :: proc(user: rawptr, from: knet.Player_Id, from_peer: Peer_Id, r: ^knet.Reader)

@(private)
App_Route :: struct {
	user:    rawptr,
	handler: App_Handler,
}

// Register `handler` for app messages under `tag`. Call any time before
// traffic flows (routes survive session_host_start/client_start/host_resume).
session_app_route :: proc(s: ^Session, tag: u8, user: rawptr, handler: App_Handler) {
	assert(int(tag) < MAX_APP_TAGS)
	s.app[tag] = App_Route{user = user, handler = handler}
}

// Start an app message under `tag`: returns the session's scratch writer with
// the framing already in place — write the payload straight into it, then
// session_app_flush. Skips the build-your-own-writer-then-copy dance of
// session_app_send (payload bytes are written exactly once). One app message
// in flight at a time between begin and flush.
session_app_begin :: proc(s: ^Session, tag: u8) -> ^knet.Writer {
	assert(int(tag) < MAX_APP_TAGS)
	knet.writer_reset(&s.app_w)
	knet.write_u8(&s.app_w, SES_APP)
	knet.write_u8(&s.app_w, tag)
	return &s.app_w
}

// Ship the message started by session_app_begin. `to_peer` is a transport
// peer (HOST_PEER, a seated player's peer, or BROADCAST_PEER).
session_app_flush :: proc(s: ^Session, to_peer: Peer_Id) {
	s.send(s.send_user, to_peer, knet.writer_bytes(&s.app_w), .Reliable)
}

// Ship app payload bytes under `tag` on the reliable channel — the one-call
// form when the payload already exists as a slice (begin/flush avoids the
// extra copy when you are building it anyway).
session_app_send :: proc(s: ^Session, to_peer: Peer_Id, tag: u8, bytes: []u8) {
	w := session_app_begin(s, tag)
	append(&w.buf, ..bytes)
	session_app_flush(s, to_peer)
}

// Ship app payload bytes to a PLAYER — resolves the seat on the authority, so
// callers never touch peer ids. Disconnected target (or the host itself —
// transports have no loopback): dropped silently.
session_app_send_to :: proc(s: ^Session, player: knet.Player_Id, tag: u8, bytes: []u8) {
	assert(s.is_host, "player-addressed sends resolve seats on the authority")
	p, ok := s.players[player]
	if !ok || !p.connected || p.id == s.me {
		return
	}
	session_app_send(s, p.peer, tag, bytes)
}

// Remote entities render this far in the past (~3 net ticks at 20 Hz): almost
// always a bracketing sample pair, smooth through jitter and single drops.
DEFAULT_INTERP_DELAY :: 0.15

// Predictions whose result never arrives revert after this long.
DEFAULT_COMMAND_TIMEOUT :: 3.0 // seconds — far beyond any sane RTT

// No WELCOME within this long of session_client_start -> Ev_Join_Failed
// (generous for a slow handshake, finite for a dead address; without it a
// failed join hangs on "Joining..." forever).
DEFAULT_JOIN_TIMEOUT :: 15.0 // seconds

// How often the designated backup host's snapshot refreshes.
DEFAULT_BACKUP_INTERVAL :: 5.0 // seconds

// Every tunable the session bakes a time constant from, set ONCE before
// *_start via session_configure (like all pre-start wiring, it survives
// re-init). Zero-valued fields mean the defaults above — a zero config is the
// out-of-the-box session. All durations are SECONDS; the session converts to
// ticks itself, so changing tick_hz never silently rescales your timeouts.
Session_Config :: struct {
	tick_hz:         int, // net ticks per second (0 = knet.DEFAULT_TICK_HZ, 20)
	interp_delay:    f64, // how far in the past remote entities render
	command_timeout: f64, // prediction auto-revert horizon
	join_timeout:    f64, // client_start -> Ev_Join_Failed horizon
	backup_interval: f64, // backup-host snapshot refresh cadence
	max_players:     int, // NEW joins refused past this many connected (0 = unlimited; rejoins always reclaim their seat)
}

Session :: struct {
	is_host:   bool,
	me:        knet.Player_Id,
	players:   map[knet.Player_Id]Player,
	events:    [dynamic]Event,
	send:      Send_Proc,
	send_user: rawptr,
	cfg:       Session_Config, // survives re-init; resolved fields below

	// resolved from cfg at *_start (read these, not cfg, mid-run)
	tick_hz:         int,
	pending_max_age: u64, // ticks
	join_timeout:    int, // ticks

	// the replicated world (kit/net): the session drives the per-tick walks
	reg:          knet.Registry,
	ctx:          knet.Command_Ctx,
	ticker:       knet.Ticker,
	clocks:       map[Peer_Id]knet.Clock_Sync, // per transport peer, fed by ping/pong
	pongs:        int, // pong samples applied (games gate "clock is warm" on this)
	now:          f64, // the game's monotonic seconds, updated each session_tick
	replicating:  bool, // host: the world is LIVE (deltas flow; joiners get SES_WORLD)
	interp_delay: f64,

	// entity types + client-side factories
	types:         map[knet.Net_Id]Entity_Type, // host: for (re-)announcing spawns
	factory_user:  rawptr,
	factory_make:  Make_Entity_Proc,
	factory_free:  Free_Entity_Proc,
	cmd_hook_user: rawptr,
	cmd_hook:      Command_Hook, // host: the cross-entity half of commands

	// the stat registry (host accumulates; everyone reads)
	stat_names:  [dynamic]string, // owned; index = column
	stats:       map[knet.Player_Id][MAX_STAT_COLS]i64,
	stats_dirty: bool, // host: snapshot goes out on the next low-rate tick

	// backup hosting (migration-readiness): the host periodically ships a
	// complete re-hostable snapshot to the ELDEST connected client
	backup_every:     u64, // net ticks between refreshes (default 100 = 5s)
	backup_tick:      u64, // host: when the last one shipped
	backup_target:    knet.Player_Id, // host: who holds it
	backup:           []u8, // client: the latest payload (opaque; owned; split via session_backup_parts)
	backup_at:        f64, // client: when it arrived (session now)
	backup_blob_user: rawptr, // pre-start wiring: the game's blob writer rides every backup
	backup_blob:      Backup_Blob_Proc,

	// SUCCESSION (live migration): the host names the backup holder and how
	// to reach them BEFORE dying; every peer holds the answer when the
	// lights go out.
	succ_info:      []u8, // host: the game's transport rendezvous blob (owned)
	successor:      knet.Player_Id, // client: who carries the torch
	successor_info: []u8, // client: how to find them (owned; see session_successor)

	// app-message routes (kit/comms and friends; survive re-init)
	app:   [MAX_APP_TAGS]App_Route,
	app_w: knet.Writer, // scratch for session_app_begin/flush (reused per message)

	// host bookkeeping
	next_player: knet.Player_Id,
	tokens:      map[u64]knet.Player_Id, // reconnect identity, forever
	by_peer:     map[Peer_Id]knet.Player_Id,
	denied:      map[u64]knet.Player_Id, // banned token hashes -> who they were (run-scoped)
	locked:      bool, // host: new joins refused (rejoins still reclaim their seat)

	// client bookkeeping
	token:       u64, // our reconnect secret (the game persists it across runs)
	name:        string, // owned; the name we asked for
	joined:      bool, // WELCOME received
	join_waited: int, // ticks since client_start without a WELCOME (-1 = not waiting)
}

@(private = "file")
session_init :: proc(s: ^Session) {
	// RE-ENTRANT: host_start / client_start / host_resume may run on a
	// session that already ran (back to lobby -> rehost, host after a failed
	// join). Tear down the previous RUN's state — otherwise the old
	// registry/ctx maps leak and stat_names grows a duplicate "ping" column
	// that ships to every client — while preserving everything a game wires
	// BEFORE start: transport, factory, hooks, app routes, interp tuning.
	if len(s.stat_names) > 0 {
		knet.registry_destroy(&s.reg)
		knet.command_ctx_destroy(&s.ctx)
		for _, p in s.players {
			delete(p.name)
		}
		clear(&s.players)
		clear(&s.events)
		clear(&s.tokens)
		clear(&s.by_peer)
		clear(&s.denied)
		s.locked = false
		clear(&s.clocks)
		clear(&s.types)
		for n in s.stat_names {
			delete(n)
		}
		clear(&s.stat_names)
		clear(&s.stats)
		delete(s.backup)
		s.backup = nil
		delete(s.succ_info)
		s.succ_info = nil
		delete(s.successor_info)
		s.successor_info = nil
		s.successor = {}
		delete(s.name)
		s.name = ""
		s.is_host = false
		s.joined = false
		s.replicating = false
		s.stats_dirty = false
		s.pongs = 0
		s.next_player = {}
		s.backup_tick = 0
		s.backup_target = {}
		s.backup_at = 0
	}
	// Resolve the config (zero fields = defaults). Durations are configured in
	// seconds and baked to tick counts HERE, against the configured rate.
	s.tick_hz = s.cfg.tick_hz > 0 ? s.cfg.tick_hz : knet.DEFAULT_TICK_HZ
	hz := f64(s.tick_hz)
	s.interp_delay = s.cfg.interp_delay > 0 ? s.cfg.interp_delay : DEFAULT_INTERP_DELAY
	s.pending_max_age = u64((s.cfg.command_timeout > 0 ? s.cfg.command_timeout : DEFAULT_COMMAND_TIMEOUT) * hz)
	s.join_timeout = int((s.cfg.join_timeout > 0 ? s.cfg.join_timeout : DEFAULT_JOIN_TIMEOUT) * hz)
	s.backup_every = u64((s.cfg.backup_interval > 0 ? s.cfg.backup_interval : DEFAULT_BACKUP_INTERVAL) * hz)

	s.reg = knet.registry_make()
	s.ctx = knet.command_ctx_make()
	s.ticker = knet.ticker_make(s.tick_hz)
	if s.app_w.buf == nil {
		s.app_w = knet.writer_make()
	}
	// Commands always go host-ward through the session's own framing.
	s.ctx.send = ctx_send_command
	s.ctx.send_user = s
	// Re-mirror the cross-entity hook (installed in ready(), which runs
	// before any *_start recreates this ctx — the survives-start contract).
	s.ctx.hook = s.cmd_hook
	s.ctx.hook_user = s.cmd_hook_user
	append(&s.stat_names, strings.clone("ping")) // STAT_PING, fed by the session
}

// Reconnect tokens are stored HASHED, so the backup snapshot can carry the
// token->player table to a would-be new host without handing anyone the
// secrets themselves (a rejoining client sends its raw token; any host —
// original or resumed — hashes and matches). splitmix64: good avalanche,
// zero dependencies.
@(private = "file")
token_hash :: proc(token: u64) -> u64 {
	z := token + 0x9E3779B97F4A7C15
	z = (z ~ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ~ (z >> 27)) * 0x94D049BB133111EB
	return z ~ (z >> 31)
}

session_destroy :: proc(s: ^Session) {
	for _, p in s.players {
		delete(p.name)
	}
	delete(s.players)
	delete(s.events)
	delete(s.tokens)
	delete(s.by_peer)
	delete(s.denied)
	delete(s.name)
	knet.registry_destroy(&s.reg)
	knet.command_ctx_destroy(&s.ctx)
	delete(s.clocks)
	delete(s.types)
	for n in s.stat_names {
		delete(n)
	}
	delete(s.stat_names)
	delete(s.stats)
	delete(s.backup)
	delete(s.succ_info)
	delete(s.successor_info)
	knet.writer_destroy(&s.app_w)
	s^ = {}
}

// Set the session's tunables (see Session_Config) — call before *_start; the
// config survives re-init like all pre-start wiring. A zero config restores
// every default.
session_configure :: proc(s: ^Session, cfg: Session_Config) {
	s.cfg = cfg
}

// The resolved net tick rate — what cooldown ticks, tick-count cadences, and
// px/tick↔px/s conversions should be computed against. Valid from *_start;
// before that it answers what the current config WOULD resolve to.
session_tick_hz :: proc(s: ^Session) -> int {
	if s.tick_hz > 0 {
		return s.tick_hz
	}
	return s.cfg.tick_hz > 0 ? s.cfg.tick_hz : knet.DEFAULT_TICK_HZ
}

// Install the transport hookup (netgd.wire_attach calls this; hand-rolled
// transports and tests call it directly). Survives *_start like all pre-start
// wiring.
session_set_transport :: proc(s: ^Session, user: rawptr, send: Send_Proc) {
	s.send = send
	s.send_user = user
}

// ---- stats: declare / mutate (host) / read (anyone) ---------------------------

// Host: declare (or find) a named column. Idempotent by name — safe to call
// from ready() on every run. Clients get columns from the wire.
session_stat_column :: proc(s: ^Session, name: string) -> Stat_Col {
	assert(s.is_host, "the authority declares stat columns; clients receive them")
	if col, ok := session_stat_find(s, name); ok {
		return col
	}
	assert(len(s.stat_names) < MAX_STAT_COLS, "too many stat columns")
	append(&s.stat_names, strings.clone(name))
	s.stats_dirty = true
	return Stat_Col(len(s.stat_names) - 1)
}

// Look a column up by name — how clients resolve what the scoreboard shows.
session_stat_find :: proc(s: ^Session, name: string) -> (Stat_Col, bool) {
	for n, i in s.stat_names {
		if n == name {
			return Stat_Col(i), true
		}
	}
	return 0, false
}

session_stat_names :: proc(s: ^Session) -> []string {
	return s.stat_names[:]
}

// NOTE: all row reads use the comma-ok form — a plain missing-key index of a
// map with a large value type faults in the current compiler (found by the
// acid test's crash reporter; a missing player must read as an all-zero row).
session_stat_set :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, value: i64) {
	assert(s.is_host, "stats are host-accumulated")
	row, _ := s.stats[player]
	if row[col] == value {
		return
	}
	row[col] = value
	s.stats[player] = row
	s.stats_dirty = true
}

session_stat_add :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, delta: i64) {
	assert(s.is_host, "stats are host-accumulated")
	row, _ := s.stats[player]
	row[col] += delta
	s.stats[player] = row
	s.stats_dirty = true
}

session_stat :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col) -> i64 {
	row, ok := s.stats[player]
	if !ok {
		return 0
	}
	return row[col]
}

// Install the client-side entity factory (do it before joining).
session_set_factory :: proc(s: ^Session, user: rawptr, make_entity: Make_Entity_Proc, free_entity: Free_Entity_Proc) {
	s.factory_user = user
	s.factory_make = make_entity
	s.factory_free = free_entity
}

// Install the host-side command hook (see Command_Hook; survives session start).
// Mirrored onto the command ctx so the generated wrappers fire it for the
// authority's own local issues too.
session_set_command_hook :: proc(s: ^Session, user: rawptr, hook: Command_Hook) {
	s.cmd_hook_user = user
	s.cmd_hook = hook
	s.ctx.hook = hook
	s.ctx.hook_user = user
}

// The Command_Ctx send hook: wrap raw command bytes in session framing and
// ship them to the host. Installed by session_init — the generated `<proc>_cmd`
// wrappers reach the wire without the game writing any glue.
@(private = "file")
ctx_send_command :: proc(user: rawptr, bytes: []u8) {
	s := cast(^Session)user
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_CMD)
	append(&w.buf, ..bytes)
	s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

// ---- the replicated world ----------------------------------------------------

// Host: spawn an entity into the session. Allocates its net id, records its
// type, and — once the world is live — announces it to every seated peer
// (reliable, so the spawn always precedes any delta naming the id). The HOST
// game creates its own entity however it likes; remote peers create theirs
// through the factory when the announcement arrives. (Prefer the
// session_spawn_make / session_spawn_send pair, which routes the host's own
// creation through the SAME factory clients use — this one remains for
// games that build entities by hand.)
session_spawn :: proc(s: ^Session, type: Entity_Type, entity: rawptr, set: ^knet.Command_Set, owner := knet.PLAYER_ID_INVALID) -> knet.Net_Id {
	assert(s.is_host, "only the authority spawns; clients create via the factory")
	id := knet.registry_spawn(&s.reg, entity, set, owner)
	s.types[id] = type
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_SPAWN)
		write_spawn_tuple(s, &w, id)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
	return id
}

// Host: spawn THROUGH THE FACTORY — the same Make_Entity_Proc clients run,
// so every entity type's creation is written exactly once. Two-phase because
// the spawn announcement carries a field snapshot: make, set your per-spawn
// fields on the returned entity, then session_spawn_send. Ev_Spawned fires
// here (the host reacts to spawns like any peer).
session_spawn_make :: proc(s: ^Session, type: Entity_Type, owner := knet.PLAYER_ID_INVALID) -> (entity: rawptr, id: knet.Net_Id) {
	assert(s.is_host, "only the authority spawns; clients create via the factory")
	assert(s.factory_make != nil, "session_spawn_make needs session_set_factory")
	id = s.reg.next_id
	s.reg.next_id += 1
	set: ^knet.Command_Set
	entity, set = s.factory_make(s.factory_user, type, id, owner)
	assert(entity != nil, "the factory returned nil for a host-side spawn")
	knet.registry_insert(&s.reg, id, entity, set, owner)
	s.types[id] = type
	append(&s.events, Ev_Spawned{id = id, type = type, owner = owner})
	return
}

// Second half of session_spawn_make: announce the spawn (with the fields as
// they stand NOW) to every seated peer.
session_spawn_send :: proc(s: ^Session, id: knet.Net_Id) {
	assert(s.is_host)
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_SPAWN)
		write_spawn_tuple(s, &w, id)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
}

// TELEPORT: the OWNER of `id` declares a discontinuity in its streamed
// fields (a respawn, a level change, a blink) — remote peers snap to the far
// side of the jump instead of interpolating a slide across the map. Call it
// on the same frame you write the jumped position; it costs one byte that
// already rides every stream snapshot.
session_teleport :: proc(s: ^Session, id: knet.Net_Id) {
	knet.registry_teleport(&s.reg, id)
}

// Host: OWNERSHIP TRANSFER — hand an entity's owner-stream authority to a
// player (PLAYER_ID_INVALID hands it back to nobody: it rests where it is,
// host-authoritative deltas still flow). Carrying, mounting, possession,
// dragging a downed friend — all of them are this one call from a command
// hook. Remote screens snap (never interpolate) across the handoff, the old
// owner stops streaming by construction, and Ev_Owner_Changed fires on
// every peer — the new owner starts gluing the entity to itself off that
// event, role-free. Ordered with spawns and deltas on the reliable channel.
session_set_owner :: proc(s: ^Session, id: knet.Net_Id, owner: knet.Player_Id) {
	assert(s.is_host, "the authority hands things over; clients ask via commands")
	prev := session_owner_of(s, id)
	if prev == owner {
		return
	}
	if !knet.registry_set_owner(&s.reg, id, owner) {
		return
	}
	append(&s.events, Ev_Owner_Changed{id = id, owner = owner, prev = prev})
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_SETOWNER)
		knet.write_net_id(&w, id)
		knet.write_player_id(&w, owner)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
}

// Host: remove an entity from the session and tell everyone. SYMMETRIC with
// clients: the installed factory free proc runs here too (so node/map
// cleanup is written once), and Ev_Despawned fires. Clients' in-flight
// predictions on the entity clean up on their own (results/expiry handle a
// missing entity).
session_despawn :: proc(s: ^Session, id: knet.Net_Id) {
	assert(s.is_host)
	entity: rawptr
	if e, ok := s.reg.entries[id]; ok {
		entity = e.entity
	}
	if !knet.registry_remove(&s.reg, id) {
		return
	}
	delete_key(&s.types, id)
	if s.factory_free != nil {
		s.factory_free(s.factory_user, id, entity)
	}
	append(&s.events, Ev_Despawned{id = id})
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_DESPAWN)
		knet.write_net_id(&w, id)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
}

// Host: the world is set up — go live. Commits shadows, ships the full world
// (SES_WORLD) to every ALREADY-seated client, and from here on the per-tick
// delta walk broadcasts and every later joiner gets SES_WORLD right behind
// its WELCOME: drop-in mid-game join is the same code path as being early.
session_start_replicating :: proc(s: ^Session) {
	assert(s.is_host)
	knet.registry_commit_shadows(&s.reg)
	s.replicating = true
	for _, p in s.players {
		if !p.connected || p.id == s.me {
			continue
		}
		send_world(s, p.peer)
	}
}

// [type][id][owner][len][full fields] — len makes unknown types skippable.
@(private = "file")
write_spawn_tuple :: proc(s: ^Session, w: ^knet.Writer, id: knet.Net_Id) {
	e, _ := knet.registry_get(&s.reg, id)
	knet.write_u16(w, u16(s.types[id]))
	knet.write_net_id(w, id)
	knet.write_player_id(w, e.owner)
	n := knet.desc_data_size(e.set.entity_desc)
	assert(n <= int(max(u16)))
	knet.write_u16(w, u16(n))
	knet.write_full(w, e.entity, e.set.entity_desc)
}

@(private = "file")
send_world :: proc(s: ^Session, peer: Peer_Id) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_WORLD)
	assert(knet.registry_count(&s.reg) <= int(max(u16)))
	knet.write_u16(&w, u16(knet.registry_count(&s.reg)))
	for id in s.types {
		write_spawn_tuple(s, &w, id)
	}
	s.send(s.send_user, peer, knet.writer_bytes(&w), .Reliable)
}

// Client: one incoming spawn tuple — factory-create (or reconcile onto an
// entity we already have: a same-session rejoin re-receives the world), apply
// the snapshot, event. Unknown types skip by length.
@(private = "file")
apply_spawn_tuple :: proc(s: ^Session, r: ^knet.Reader) {
	type := Entity_Type(knet.read_u16(r))
	id := knet.read_net_id(r)
	owner := knet.read_player_id(r)
	n := int(knet.read_u16(r))
	if r.err || r.off + n > len(r.data) {
		r.err = true
		return
	}
	body := knet.reader_make(r.data[r.off:r.off + n])
	r.off += n

	if e, exists := knet.registry_get(&s.reg, id); exists {
		knet.apply_full(&body, e.entity, e.set.entity_desc)
		return
	}
	if s.factory_make == nil {
		return
	}
	entity, set := s.factory_make(s.factory_user, type, id, owner)
	if entity == nil || set == nil {
		return // unknown type: skipped whole, by length
	}
	knet.registry_insert(&s.reg, id, entity, set, owner)
	s.types[id] = type
	knet.apply_full(&body, entity, set.entity_desc)
	append(&s.events, Ev_Spawned{id = id, type = type, owner = owner})
}

// Drive the session once per frame. `now` is the game's monotonic seconds
// (any base — it stamps stream rings and clock pings). Returns how many net
// ticks fired and how many remote entities were stream-sampled this frame.
session_tick :: proc(s: ^Session, dt: f64, now: f64) -> (ticks: int, sampled: int) {
	s.now = now
	ticks = knet.ticker_advance(&s.ticker, dt)
	for _ in 0 ..< ticks {
		net_tick(s)
	}
	sampled = knet.registry_sample_streams(&s.reg, now - s.interp_delay, s.me)
	return
}

@(private = "file")
net_tick :: proc(s: ^Session) {
	t := s.ticker.tick
	s.ctx.now_tick = t

	if !s.is_host && !s.joined && s.join_waited >= 0 {
		s.join_waited += 1
		if s.join_waited > s.join_timeout {
			s.join_waited = -1
			append(&s.events, Ev_Join_Failed{})
		}
	}

	if s.is_host && s.replicating {
		// Host state: ONE batched delta message for every dirty entity, to
		// every joined peer, reliable (the shadow commits on send — a dropped
		// delta would be lost forever; spawn/despawn shares this channel so
		// ids are always known before a batch names them).
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_STATE)
		if dirty := knet.registry_write_deltas(&w, &s.reg); dirty > 0 {
			broadcast(s, knet.writer_bytes(&w), .Reliable)
			// The HOST gets the state event too: its own tick just changed
			// these entities, and event-driven repaint code should not need
			// a role branch (a host inventory once went stale for six
			// phases because it didn't get this).
			append(&s.events, Ev_State_Applied{entities = dirty})
		}
	}

	// Owner streams: last-value snapshots of every entity WE own, unreliable
	// (a drop is superseded by the next tick's snapshot). Any peer can own.
	{
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_STREAM)
		if knet.registry_write_streams(&w, &s.reg, s.me, s.now) > 0 {
			broadcast(s, knet.writer_bytes(&w), .Stream)
		}
	}

	// Clock pings, ~1/s: clients ping the host; the HOST pings every seated
	// client — that is where the automatic ping stat comes from. (Per-peer
	// mesh pings for sender-stamped stream timelines come later.)
	if s.joined && t % u64(s.tick_hz) == u64(s.tick_hz / 4) {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_PING)
		knet.ping_write(&w, s.now)
		if s.is_host {
			for _, p in s.players {
				if p.connected && p.id != s.me {
					s.send(s.send_user, p.peer, knet.writer_bytes(&w), .Reliable)
				}
			}
		} else {
			s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
		}
	}

	// Stats: host feeds the ping column from its per-peer clocks and ships the
	// full snapshot at a LOW rate (~2/s) when something changed (display data).
	if s.is_host && t % u64(max(s.tick_hz / 2, 1)) == 0 {
		for _, p in s.players {
			if !p.connected || p.id == s.me {
				continue
			}
			if c := s.clocks[p.peer]; c.initialized {
				session_stat_set(s, p.id, STAT_PING, i64(c.rtt * 1000))
			}
		}
		// Stats flow in the LOBBY too (the player list shows ping pre-game);
		// only the world waits for replicating.
		if s.stats_dirty {
			s.stats_dirty = false
			send_stats(s)
		}
		// Backup hosting: keep the ELDEST connected client holding a fresh
		// re-hostable snapshot — refreshed on the interval, and immediately
		// when the target changes (first client seats, old target leaves).
		if s.replicating {
			target := backup_target(s)
			if target != knet.PLAYER_ID_INVALID &&
			   (target != s.backup_target || t - s.backup_tick >= s.backup_every) {
				if target != s.backup_target {
					// The torch-bearer changed: tell the game (it computes
					// the rendezvous info) — the successor broadcast follows
					// from session_set_successor_info.
					append(&s.events, Ev_Backup_Target{player = target})
				}
				s.backup_target = target
				s.backup_tick = t
				p, _ := s.players[target]
				send_backup(s, p.peer)
			}
		}
	}

	// Loud auto-revert: a silent host must read as "no" — and the rejection
	// carries the REAL seq/entity so UI keyed on either matches the timeout
	// path just like the explicit-reject path.
	expired := make([dynamic]knet.Expired_Command, context.temp_allocator)
	if knet.registry_expire_pending(&s.reg, &s.ctx, s.pending_max_age, s.me, &expired) > 0 {
		for x in expired {
			append(&s.events, Ev_Command_Rejected{seq = x.seq, entity = x.entity})
		}
	}
}

// Transport-level "everyone but me" (engine semantics: netgd relays peer 0 to
// all other peers, server-relayed for clients). World traffic uses this — only
// the HOST knows other players' transport peers, but any peer may own streamed
// entities. Roster messages stay host-targeted (they need per-peer exclusion).
BROADCAST_PEER :: Peer_Id(0)

@(private = "file")
broadcast :: proc(s: ^Session, bytes: []u8, channel: Channel) {
	s.send(s.send_user, BROADCAST_PEER, bytes, channel)
}

// This peer's clock estimate for `peer` (zero value until a pong lands).
session_clock :: proc(s: ^Session, peer: Peer_Id) -> knet.Clock_Sync {
	return s.clocks[peer]
}

// The eldest connected client (lowest Player_Id) — deterministic, stable
// across everything except that player leaving.
@(private = "file")
backup_target :: proc(s: ^Session) -> knet.Player_Id {
	best := knet.PLAYER_ID_INVALID
	for _, p in s.players {
		if !p.connected || p.id == s.me {
			continue
		}
		if best == knet.PLAYER_ID_INVALID || p.id < best {
			best = p.id
		}
	}
	return best
}

// The re-hostable snapshot: everything needed to BECOME the host of this
// run — identity table (hashed tokens), roster names, allocation cursors,
// the stat registry, and every entity as a spawn tuple. session_host_resume
// parses it. Two consumers: the backup-host wire (below) and kit/save, which
// wraps it in a versioned file envelope — saving a run and surviving a dead
// host are the SAME contract.
//
// Layout: [next_player u64]
//         [cols u8] x [name string]
//         [players u16] x ([id u64][name string][token_hash u64][cols x i64])
//         [next_net_id u32]
//         [entities u16] x the SES_SPAWN tuple
session_snapshot :: proc(s: ^Session, w: ^knet.Writer) {
	assert(s.is_host, "the authority owns the truth being snapshotted")
	knet.write_u64(w, u64(s.next_player))
	knet.write_u8(w, u8(len(s.stat_names)))
	for n in s.stat_names {
		knet.write_string(w, n)
	}
	assert(len(s.players) <= int(max(u16)))
	knet.write_u16(w, u16(len(s.players)))
	for _, p in s.players {
		knet.write_player_id(w, p.id)
		knet.write_string(w, p.name)
		hash := u64(0)
		for h, id in s.tokens {
			if id == p.id {
				hash = h
			}
		}
		knet.write_u64(w, hash) // 0 for the host itself (hosts never JOINed)
		row, _ := s.stats[p.id]
		for i in 0 ..< len(s.stat_names) {
			knet.write_i64(w, row[i])
		}
	}
	knet.write_u32(w, u32(s.reg.next_id))
	assert(knet.registry_count(&s.reg) <= int(max(u16)))
	knet.write_u16(w, u16(knet.registry_count(&s.reg)))
	for id in s.types {
		write_spawn_tuple(s, w, id)
	}
}

// Host-side state the SESSION cannot know about — wave directors, AI
// clocks, quest flags — written into every backup so a would-be new host
// resumes the CAMPAIGN, not just the roster and entities (the same split
// kit/save's envelope makes; write the same bytes in both).
Backup_Blob_Proc :: proc(user: rawptr, w: ^knet.Writer)

// Install the game-blob writer for backups (pre-start wiring; survives
// *_start like the rest). Without one, backups carry an empty blob and a
// takeover restores the world but not the campaign around it.
session_set_backup_blob :: proc(s: ^Session, user: rawptr, write: Backup_Blob_Proc) {
	s.backup_blob_user = user
	s.backup_blob = write
}

// Split a received backup payload into the game's blob and the re-hostable
// session snapshot (what session_host_resume eats). ok=false when no backup
// has arrived (we were never the designated holder) or it is malformed.
// Returns COPIES (temp-allocated by default) on purpose: the resume you are
// about to run RE-INITS the session, which frees the stored payload —
// slices into it would dangle exactly when you need them.
session_backup_parts :: proc(s: ^Session, allocator := context.temp_allocator) -> (game_blob: []u8, snapshot: []u8, ok: bool) {
	if len(s.backup) < 4 {
		return nil, nil, false
	}
	r := knet.reader_make(s.backup)
	n := int(knet.read_u32(&r))
	if r.err || r.off + n > len(s.backup) {
		return nil, nil, false
	}
	game_blob = make([]u8, n, allocator)
	copy(game_blob, s.backup[r.off:r.off + n])
	snapshot = make([]u8, len(s.backup) - r.off - n, allocator)
	copy(snapshot, s.backup[r.off + n:])
	return game_blob, snapshot, true
}

// Host: how peers find the successor if you die — an opaque transport blob
// (address:port for ENet, a lobby id for Steam, a room code for WebRTC).
// Call from Ev_Backup_Target (the session names WHO; the transport layer
// knows WHERE); broadcast immediately and to every later joiner. With no
// info set, host loss stays v1-shaped: Ev_Host_Left, run over, no auto arc.
session_set_successor_info :: proc(s: ^Session, info: []u8) {
	assert(s.is_host)
	delete(s.succ_info)
	s.succ_info = make([]u8, len(info))
	copy(s.succ_info, info)
	send_successor(s, BROADCAST_PEER)
}

// Client: who carries the torch, and the host-provided rendezvous blob.
session_successor :: proc(s: ^Session) -> (knet.Player_Id, []u8) {
	return s.successor, s.successor_info
}

@(private = "file")
send_successor :: proc(s: ^Session, to: Peer_Id) {
	if len(s.succ_info) == 0 {
		return
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_SUCCESSOR)
	knet.write_player_id(&w, s.backup_target)
	knet.write_bytes(&w, s.succ_info)
	if to == BROADCAST_PEER {
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	} else {
		s.send(s.send_user, to, knet.writer_bytes(&w), .Reliable)
	}
}

@(private = "file")
send_backup :: proc(s: ^Session, peer: Peer_Id) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_BACKUP)
	// [blob_len u32][game blob][session snapshot] — parts split it back out.
	blob := knet.writer_make()
	defer knet.writer_destroy(&blob)
	if s.backup_blob != nil {
		s.backup_blob(s.backup_blob_user, &blob)
	}
	knet.write_u32(&w, u32(len(knet.writer_bytes(&blob))))
	append(&w.buf, ..knet.writer_bytes(&blob))
	session_snapshot(s, &w)
	s.send(s.send_user, peer, knet.writer_bytes(&w), .Reliable)
}

// Become the host of a run someone else was hosting, from a backup blob this
// session (or a previous run's session) received as the designated backup.
// Call on a FRESH session with the factory already installed; `me` is the
// caller's own Player_Id from the dead run. Every other player comes back
// disconnected — they rejoin with their tokens and reclaim ids, stats, and
// owned entities exactly like any reconnect. The dead run's HOST has no
// token (hosts never JOIN), so in v1 it returns as a NEW player.
// Returns false on a corrupt blob (destroy the session and start clean).
session_host_resume :: proc(s: ^Session, me: knet.Player_Id, name: string, backup: []u8) -> bool {
	assert(s.factory_make != nil, "resume recreates entities through the factory — install it first")
	session_init(s)
	s.is_host = true
	s.ctx.is_authority = true
	s.me = me
	s.ctx.me = me
	s.joined = true

	r := knet.reader_make(backup)
	s.next_player = knet.Player_Id(knet.read_u64(&r))
	cols := int(knet.read_u8(&r))
	if r.err || cols > MAX_STAT_COLS {
		return false
	}
	for n in s.stat_names { // replace the init-time default schema wholesale
		delete(n)
	}
	clear(&s.stat_names)
	for _ in 0 ..< cols {
		append(&s.stat_names, strings.clone(knet.read_string(&r)))
	}
	players := int(knet.read_u16(&r))
	if r.err {
		return false
	}
	for _ in 0 ..< players {
		id := knet.read_player_id(&r)
		pname := knet.read_string(&r)
		hash := knet.read_u64(&r)
		row: [MAX_STAT_COLS]i64
		for i in 0 ..< cols {
			row[i] = knet.read_i64(&r)
		}
		if r.err {
			return false
		}
		mine := id == me
		s.players[id] = Player {
			id        = id,
			name      = strings.clone(mine ? name : pname),
			peer      = mine ? HOST_PEER : 0,
			connected = mine,
		}
		if hash != 0 {
			s.tokens[hash] = id
		}
		s.stats[id] = row
	}
	next_net := knet.Net_Id(knet.read_u32(&r))
	entities := int(knet.read_u16(&r))
	if r.err {
		return false
	}
	for _ in 0 ..< entities {
		apply_spawn_tuple(s, &r)
		if r.err {
			return false
		}
	}
	s.reg.next_id = max(s.reg.next_id, next_net)
	knet.registry_commit_shadows(&s.reg)
	s.replicating = true // the world is live: rejoiners get SES_WORLD + stats
	s.stats_dirty = true
	return true
}

// Full stat snapshot: schema + every player's row. Small (16 cols x 8 players
// ≈ 1KB) and rare (~2 Hz when dirty) — no delta machinery to get wrong.
@(private = "file")
send_stats :: proc(s: ^Session, to_peer := BROADCAST_PEER) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_STATS)
	knet.write_u8(&w, u8(len(s.stat_names)))
	for n in s.stat_names {
		knet.write_string(&w, n)
	}
	assert(len(s.players) <= int(max(u16)))
	knet.write_u16(&w, u16(len(s.players)))
	for _, p in s.players {
		knet.write_player_id(&w, p.id)
		row, _ := s.stats[p.id]
		for i in 0 ..< len(s.stat_names) {
			knet.write_i64(&w, row[i])
		}
	}
	if to_peer == BROADCAST_PEER {
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	} else {
		s.send(s.send_user, to_peer, knet.writer_bytes(&w), .Reliable)
	}
}

// Drain one queued event (call until ok=false each frame).
session_poll :: proc(s: ^Session) -> (ev: Event, ok: bool) {
	if len(s.events) == 0 {
		return nil, false
	}
	ev = s.events[0]
	ordered_remove(&s.events, 0)
	return ev, true
}

session_player :: proc(s: ^Session, id: knet.Player_Id) -> (Player, bool) {
	p, ok := s.players[id]
	return p, ok
}

// The player currently seated as the AUTHORITY — by transport seat, not by
// id: a resumed host returns under its old id, so "player 1" is wrong the
// moment a run has been saved and brought back.
session_host :: proc(s: ^Session) -> knet.Player_Id {
	for id, p in s.players {
		if p.connected && p.peer == HOST_PEER {
			return id
		}
	}
	return knet.PLAYER_ID_INVALID
}

// Every player, sorted by id (= join order) — the shape every roster UI
// wants; departed players stay listed by design.
session_roster :: proc(s: ^Session, allocator := context.temp_allocator) -> []Player {
	out := make([dynamic]Player, 0, len(s.players), allocator)
	for _, p in s.players {
		append(&out, p)
	}
	for i in 1 ..< len(out) {
		for j := i; j > 0 && out[j].id < out[j - 1].id; j -= 1 {
			out[j], out[j - 1] = out[j - 1], out[j]
		}
	}
	return out[:]
}

// Which player owns an entity (PLAYER_ID_INVALID = the host/world) — saves
// games keeping their own reverse maps.
session_owner_of :: proc(s: ^Session, id: knet.Net_Id) -> knet.Player_Id {
	if e, ok := s.reg.entries[id]; ok {
		return e.owner
	}
	return knet.PLAYER_ID_INVALID
}

session_count :: proc(s: ^Session, connected_only := false) -> int {
	if !connected_only {
		return len(s.players)
	}
	n := 0
	for _, p in s.players {
		if p.connected {
			n += 1
		}
	}
	return n
}

// ---- host ------------------------------------------------------------------

// Become the session authority. The host is a full player too (name, id,
// stats) — it just never JOINs over the wire.
session_host_start :: proc(s: ^Session, name: string) {
	session_init(s)
	s.is_host = true
	s.ctx.is_authority = true
	s.next_player = 1
	s.me = s.next_player
	s.ctx.me = s.me
	s.next_player += 1
	s.players[s.me] = Player {
		id        = s.me,
		name      = strings.clone(name),
		peer      = HOST_PEER,
		connected = true,
	}
	s.joined = true
}

// Host: close (or reopen) the door. Locked = NEW joins are refused with
// .Locked; players already in the roster still reconnect freely — their seat
// is theirs. The standard move once a run starts, if drop-in isn't wanted.
session_set_locked :: proc(s: ^Session, locked: bool) {
	assert(s.is_host, "the authority owns the door")
	s.locked = locked
}

// Host: remove a player on purpose. The target learns it was deliberate
// (Ev_Kicked — not a mystery host-crash), everyone else sees an ordinary
// departure, and with `ban` the token's hash lands on the denied list so the
// same identity bounces off host_handle_join with .Banned for the rest of
// the RUN (bans are run-scoped; persist them yourself if forever matters).
// Returns the seat the player held so the game can also drop the transport
// connection (netgd.drop_peer) — without that the kicked client still holds
// a socket it can talk on, even though the session ignores unseated peers.
session_kick :: proc(s: ^Session, player: knet.Player_Id, ban := false) -> (was: Peer_Id, ok: bool) {
	assert(s.is_host, "the authority moderates")
	p, exists := s.players[player]
	if !exists || !p.connected || player == s.me {
		return NO_PEER, false
	}
	if ban {
		for hash, id in s.tokens {
			if id == player {
				s.denied[hash] = player
			}
		}
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_KICKED)
	s.send(s.send_user, p.peer, knet.writer_bytes(&w), .Reliable)

	was = p.peer
	delete_key(&s.by_peer, p.peer)
	mark_left(s, player)
	left := knet.writer_make()
	defer knet.writer_destroy(&left)
	knet.write_u8(&left, SES_LEFT)
	knet.write_player_id(&left, player)
	host_broadcast(s, knet.writer_bytes(&left), except = player)
	return was, true
}

// The transport told us a peer vanished. A peer that never joined is nobody;
// a player's departure is broadcast and the roster keeps them (disconnected)
// so the same token can reclaim the identity later.
session_peer_disconnected :: proc(s: ^Session, peer: Peer_Id) {
	if !s.is_host {
		if peer == HOST_PEER {
			append(&s.events, Ev_Host_Left{})
			if s.successor != knet.PLAYER_ID_INVALID && s.successor != 0 {
				// LIVE MIGRATION: everyone already knows who carries the
				// torch. Fires again on every failed reconnect — the retry
				// pulse for peers chasing a successor that isn't up yet.
				append(&s.events, Ev_Succession{successor = s.successor})
			}
		}
		return
	}
	id, was := s.by_peer[peer]
	if !was {
		return
	}
	delete_key(&s.by_peer, peer)
	mark_left(s, id)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_LEFT)
	knet.write_player_id(&w, id)
	host_broadcast(s, knet.writer_bytes(&w), except = id)
}

@(private = "file")
mark_left :: proc(s: ^Session, id: knet.Player_Id) {
	p := s.players[id]
	p.connected = false
	p.peer = NO_PEER
	s.players[id] = p
	append(&s.events, Ev_Player_Left{id = id})
}

@(private = "file")
host_broadcast :: proc(s: ^Session, bytes: []u8, except := knet.PLAYER_ID_INVALID) {
	for _, p in s.players {
		if !p.connected || p.id == s.me || p.id == except {
			continue
		}
		s.send(s.send_user, p.peer, bytes, .Reliable)
	}
}

@(private = "file")
deny_join :: proc(s: ^Session, peer: Peer_Id, reason: Deny_Reason) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_DENIED)
	knet.write_u8(&w, u8(reason))
	s.send(s.send_user, peer, knet.writer_bytes(&w), .Reliable)
}

@(private = "file")
host_handle_join :: proc(s: ^Session, peer: Peer_Id, r: ^knet.Reader) {
	token := knet.read_u64(r)
	name := knet.read_string(r)
	if r.err {
		return
	}

	// The gates, in order of severity. A RETURNING identity passes lock and
	// capacity — its seat is its own (that is the whole reconnect promise);
	// only a ban shuts a known token out.
	hash := token_hash(token)
	id, known := s.tokens[hash]
	if _, banned := s.denied[hash]; banned {
		deny_join(s, peer, .Banned)
		return
	}
	if !known {
		if s.locked {
			deny_join(s, peer, .Locked)
			return
		}
		if s.cfg.max_players > 0 && session_count(s, connected_only = true) >= s.cfg.max_players {
			deny_join(s, peer, .Full)
			return
		}
	}
	rejoin := false
	if known {
		// The token IS the identity: reclaim it. If the roster still shows the
		// player connected, the old peer is a zombie (crashed socket that
		// hasn't timed out) — the new connection takes over.
		rejoin = true
		p := s.players[id]
		if p.connected && p.peer != peer {
			delete_key(&s.by_peer, p.peer)
		}
		delete(p.name)
		p.name = strings.clone(name)
		p.peer = peer
		p.connected = true
		s.players[id] = p
	} else {
		id = s.next_player
		s.next_player += 1
		s.tokens[token_hash(token)] = id
		s.players[id] = Player {
			id        = id,
			name      = strings.clone(name),
			peer      = peer,
			connected = true,
		}
	}
	s.by_peer[peer] = id

	// WELCOME the joiner with the full roster (their own entry included —
	// clients learn `me` from your_id).
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_WELCOME)
	knet.write_player_id(&w, id)
	assert(len(s.players) <= int(max(u16)))
	knet.write_u16(&w, u16(len(s.players)))
	for _, p in s.players {
		knet.write_player_id(&w, p.id)
		knet.write_string(&w, p.name)
		knet.write_bool(&w, p.connected)
	}
	s.send(s.send_user, peer, knet.writer_bytes(&w), .Reliable)

	// Everyone else learns about (or re-learns) the joiner.
	up := knet.writer_make()
	defer knet.writer_destroy(&up)
	knet.write_u8(&up, SES_UPSERT)
	knet.write_player_id(&up, id)
	knet.write_string(&up, name)
	knet.write_bool(&up, true)
	knet.write_bool(&up, rejoin)
	host_broadcast(s, knet.writer_bytes(&up), except = id)

	// DROP-IN JOIN: a live world follows the welcome on the same ordered
	// channel — the joiner materializes everything before any delta can name
	// an id it doesn't know. (Deltas broadcast before this arrive at the
	// still-unseated client and are dropped; SES_WORLD supersedes them.)
	// The current scoreboard always rides along; the world only once live.
	if s.replicating {
		send_world(s, peer)
	}
	send_stats(s, peer)
	send_successor(s, peer)

	append(&s.events, Ev_Player_Joined{id = id, rejoin = rejoin})
}

// ---- client ------------------------------------------------------------------

// Remember who we are; the JOIN goes out when the game confirms the transport
// is up (session_client_join). `token` is the persistent reconnect secret.
session_client_start :: proc(s: ^Session, token: u64, name: string) {
	session_init(s)
	s.is_host = false
	s.token = token
	s.name = strings.clone(name)
	s.join_waited = 0 // the join-timeout clock arms; Ev_Join_Failed if no WELCOME
}

// Transport is connected: ask the host to seat us.
session_client_join :: proc(s: ^Session) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_JOIN)
	knet.write_u64(&w, s.token)
	knet.write_string(&w, s.name)
	s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

// Graceful goodbye (the host also handles the plain transport disconnect —
// this just makes the departure immediate instead of timeout-shaped).
session_client_leave :: proc(s: ^Session) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_BYE)
	s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

@(private = "file")
roster_upsert :: proc(s: ^Session, id: knet.Player_Id, name: string, connected: bool, peer := NO_PEER) {
	if old, had := s.players[id]; had {
		delete(old.name)
	}
	s.players[id] = Player {
		id        = id,
		name      = strings.clone(name),
		peer      = peer,
		connected = connected,
	}
}

@(private = "file")
client_handle_welcome :: proc(s: ^Session, r: ^knet.Reader) {
	me := knet.read_player_id(r)
	count := int(knet.read_u16(r))
	if r.err {
		return
	}
	for _ in 0 ..< count {
		id := knet.read_player_id(r)
		name := knet.read_string(r)
		connected := knet.read_bool(r)
		if r.err {
			return // partial roster is fine: entries already applied are valid
		}
		roster_upsert(s, id, name, connected)
	}
	s.me = me
	s.ctx.me = me
	s.joined = true
	s.join_waited = -1 // the join-timeout clock disarms
	append(&s.events, Ev_Welcomed{me = me})
}

// ---- shared receive path -----------------------------------------------------

// The game routes its session kind byte here with the rest of the packet.
// `from_peer` is the transport sender (hosts route by it; clients only ever
// hear from the host — except streams, which any owning peer may broadcast).
session_handle_packet :: proc(s: ^Session, from_peer: Peer_Id, r: ^knet.Reader) {
	kind := knet.read_u8(r)
	if r.err {
		return
	}
	switch kind {
	// ---- roster ----
	case SES_JOIN:
		if s.is_host {
			host_handle_join(s, from_peer, r)
		}
	case SES_BYE:
		if s.is_host {
			session_peer_disconnected(s, from_peer)
		}
	case SES_WELCOME:
		if !s.is_host {
			client_handle_welcome(s, r)
		}
	case SES_DENIED:
		if s.is_host || s.joined {
			return
		}
		reason := knet.read_u8(r)
		if r.err || reason > u8(max(Deny_Reason)) {
			return
		}
		s.join_waited = -1 // a deliberate no beats the timeout to the punch
		append(&s.events, Ev_Join_Denied{reason = Deny_Reason(reason)})
	case SES_KICKED:
		if s.is_host || !s.joined {
			return
		}
		// Deliberate removal: stop participating (no more pings/streams at
		// the host) and tell the game — it shows its "you're out" screen and
		// tears the transport down. The host will also drop the socket;
		// whichever lands first, Ev_Kicked already explained it.
		s.joined = false
		append(&s.events, Ev_Kicked{})
	case SES_UPSERT:
		if s.is_host {
			return
		}
		id := knet.read_player_id(r)
		name := knet.read_string(r)
		connected := knet.read_bool(r)
		rejoin := knet.read_bool(r)
		if r.err {
			return
		}
		roster_upsert(s, id, name, connected)
		append(&s.events, Ev_Player_Joined{id = id, rejoin = rejoin})
	case SES_LEFT:
		if s.is_host {
			return
		}
		id := knet.read_player_id(r)
		if r.err {
			return
		}
		if p, had := s.players[id]; had {
			p.connected = false
			p.peer = 0
			s.players[id] = p
			append(&s.events, Ev_Player_Left{id = id})
		}

	// ---- the replicated world (clients ignore it all until SEATED: a spawn
	// arriving before our WELCOME would collide with the SES_WORLD that
	// follows it — everything pre-seat is superseded by that snapshot) ----
	case SES_WORLD:
		if s.is_host || !s.joined {
			return
		}
		count := int(knet.read_u16(r))
		for _ in 0 ..< count {
			apply_spawn_tuple(s, r)
			if r.err {
				return
			}
		}
		knet.registry_commit_shadows(&s.reg)
	case SES_SPAWN:
		if s.is_host || !s.joined {
			return
		}
		apply_spawn_tuple(s, r)
	case SES_SUCCESSOR:
		if s.is_host || !s.joined {
			return
		}
		succ := knet.read_player_id(r)
		info := knet.read_bytes(r)
		if r.err {
			return
		}
		s.successor = succ
		delete(s.successor_info)
		s.successor_info = make([]u8, len(info))
		copy(s.successor_info, info)
	case SES_SETOWNER:
		if s.is_host || !s.joined {
			return
		}
		id := knet.read_net_id(r)
		owner := knet.read_player_id(r)
		if r.err {
			return
		}
		prev := session_owner_of(s, id)
		if knet.registry_set_owner(&s.reg, id, owner) {
			append(&s.events, Ev_Owner_Changed{id = id, owner = owner, prev = prev})
		}
	case SES_DESPAWN:
		if s.is_host || !s.joined {
			return
		}
		id := knet.read_net_id(r)
		if r.err {
			return
		}
		e, exists := knet.registry_get(&s.reg, id)
		if !exists {
			return
		}
		knet.registry_remove(&s.reg, id)
		delete_key(&s.types, id)
		if s.factory_free != nil {
			s.factory_free(s.factory_user, id, e.entity)
		}
		append(&s.events, Ev_Despawned{id = id})
	case SES_BACKUP:
		if s.is_host || !s.joined {
			return
		}
		// We are the designated backup host: keep the blob, opaque, replacing
		// any older one. Parsing happens only if we ever resume.
		blob := r.data[r.off:]
		delete(s.backup)
		s.backup = make([]u8, len(blob))
		copy(s.backup, blob)
		s.backup_at = s.now
		append(&s.events, Ev_Backup_Received{size = len(blob)})
	case SES_STATS:
		if s.is_host || !s.joined {
			return
		}
		cols := int(knet.read_u8(r))
		if r.err || cols > MAX_STAT_COLS {
			return
		}
		// Schema first (the host may declare columns mid-run): rebuild ours.
		names: [MAX_STAT_COLS]string
		for i in 0 ..< cols {
			names[i] = knet.read_string(r)
		}
		players := int(knet.read_u16(r))
		if r.err {
			return
		}
		for n in s.stat_names {
			delete(n)
		}
		clear(&s.stat_names)
		for i in 0 ..< cols {
			append(&s.stat_names, strings.clone(names[i]))
		}
		for _ in 0 ..< players {
			id := knet.read_player_id(r)
			row: [MAX_STAT_COLS]i64
			for i in 0 ..< cols {
				row[i] = knet.read_i64(r)
			}
			if r.err {
				return
			}
			s.stats[id] = row
		}
		append(&s.events, Ev_Stats_Updated{})
	case SES_STATE:
		if s.is_host || !s.joined {
			return
		}
		n := knet.registry_apply_deltas(r, &s.reg, &s.ctx)
		if !r.err {
			append(&s.events, Ev_State_Applied{entities = n})
		}
	case SES_CMD:
		if !s.is_host {
			return
		}
		// Dedup keyed by PLAYER id, not transport peer: a reconnecting player's
		// retransmits stay exactly-once across the peer change. A command from
		// a peer that never JOINed is from nobody — dropped.
		pid, seated := s.by_peer[from_peer]
		if !seated {
			return
		}
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_RESULT)
		responded, ok, h := knet.registry_host_command(&s.reg, &s.ctx, u64(pid), r, &w)
		if !responded {
			return
		}
		s.send(s.send_user, from_peer, knet.writer_bytes(&w), .Reliable)
		// The hook runs BEFORE the result ships onward in game terms: scratch
		// state the proc left on the entity is still exactly this command's.
		if s.cmd_hook != nil {
			s.cmd_hook(s.cmd_hook_user, pid, h.entity, h.cmd, ok)
		}
		append(&s.events, Ev_Command_Executed{ok = ok, player = pid, entity = h.entity, cmd = h.cmd})
	case SES_RESULT:
		if s.is_host {
			return
		}
		res := knet.registry_client_result(&s.reg, &s.ctx, r, s.me)
		if res.seq == 0 {
			return // truncated header: not a result at all (seqs start at 1)
		}
		if res.ok {
			append(&s.events, Ev_Command_Confirmed{seq = res.seq})
		} else {
			// A truncated truth snapshot already fell back to the local revert
			// inside command_reject — the rejection event holds either way.
			append(&s.events, Ev_Command_Rejected{seq = res.seq, entity = res.entity})
		}
	case SES_STREAM:
		if !s.joined {
			return
		}
		_ = knet.registry_stream_time(r) // sender stamp (clock-mapped timelines later)
		_ = knet.registry_apply_streams(r, &s.reg, s.me, s.now)
	case SES_APP:
		tag := knet.read_u8(r)
		if r.err || int(tag) >= MAX_APP_TAGS {
			return
		}
		route := s.app[tag]
		if route.handler == nil {
			return
		}
		from := knet.PLAYER_ID_INVALID
		if s.is_host {
			// Same trust gate as commands: a peer that never JOINed is nobody.
			pid, seated := s.by_peer[from_peer]
			if !seated {
				return
			}
			from = pid
		} else if !s.joined {
			return // pre-seat app traffic is superseded by post-seat state
		}
		route.handler(route.user, from, from_peer, r)
	case SES_PING:
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_PONG)
		knet.ping_answer(r, &w, s.now)
		if !r.err {
			s.send(s.send_user, from_peer, knet.writer_bytes(&w), .Reliable)
		}
	case SES_PONG:
		c := s.clocks[from_peer]
		if knet.pong_apply(r, &c, s.now) {
			s.clocks[from_peer] = c
			s.pongs += 1
		}
	}
}
