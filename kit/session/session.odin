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
import "core:fmt"
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
	dedicated: bool, // an INFRASTRUCTURE seat (a dedicated server), not a person:
	// fields no avatar, hidden from rosters/scoreboards, uncounted by player
	// gates. Only the authority can hold one (session_host_start's flag).
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

Ev_Host_Left :: struct {} // (client) the host is gone. Alone it ends the run; with
// succession armed, Ev_Succession fires BESIDE it and the run survives — the
// named bearer runs the takeover recipe, everyone else rejoins the successor
// info (see "Backup hosting and resume" in session.md).

Ev_Join_Failed :: struct {} // (client) no WELCOME within the join timeout — surface it, don't hang on "Joining..."

// Why a join was refused — each reason is a different sentence to the player.
Deny_Reason :: enum u8 {
	Full, // at max_players (Session_Config)
	Locked, // the host closed the door (session_set_locked)
	Banned, // a kicked-with-ban token came back
	Version, // the builds disagree — Session_Config.fingerprint mismatch: a
	// version-skewed peer's descriptors would misparse every delta into
	// garbage fields, so the door refuses it with a sentence instead
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
	// EVERY peer, and only once the entity is BORN — its spawn-time fields
	// are set. Clients hear it after the snapshot applies; the host at
	// session_spawn_send / session_spawn (never at spawn_make, whose entity
	// is still an empty shell awaiting the caller's fields).
	id:    knet.Net_Id,
	type:  Entity_Type,
	owner: knet.Player_Id,
}

Ev_Resynced :: struct {
	// (client) a KNOWN entity's fields just caught up WHOLESALE — a spawn
	// tuple applied over it (interest re-entry, a world snapshot over live
	// state, a redundant spawn). The jump is not gameplay: re-seed any
	// seen_* edge scratch here, or old wounds present as fresh hits.
	id:    knet.Net_Id,
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

Ev_Entity_Changed :: struct {
	id: knet.Net_Id, // one entity a state batch touched (opt-in: Session_Config.change_events)
}

Ev_Blob_Changed :: struct {
	id:   knet.Net_Id, // this entity's blob changed — read it with session_blob
	size: int,
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
	Ev_Resynced,
	Ev_Despawned,
	Ev_Owner_Changed,
	Ev_Stats_Updated,
	Ev_Backup_Received,
	Ev_State_Applied,
	Ev_Entity_Changed,
	Ev_Blob_Changed,
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

// A column HANDLE, 1-based on purpose: the zero value is INVALID and every
// read/write asserts on it. Why: `session_stat_column` registers on the HOST
// (typically in a Start handler) — a Stat_Col stored there is zero-value on
// every client, and when 0 meant "column 0" a client's read silently returned
// the auto-fed PING (homestead's acid caught a resource gate passing on 254
// milliseconds of latency). Now the same mistake is a loud assert pointing at
// `session_stat_find` — resolve BY NAME on peers that didn't register.
Stat_Col :: distinct u8

MAX_STAT_COLS :: 16

STAT_COL_INVALID :: Stat_Col(0) // the zero value: never a real column

// Always declared, always fed by the session itself.
STAT_PING :: Stat_Col(1)

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
SES_WELCOME :: u8(1) // host -> client  [your_id][count u16] x ([id][name][connected u8][dedicated u8])
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
// EXPORTED, unlike its siblings: the transport layer reads this kind off the
// wire — it is the ONE kind a loss shim may drop (unreliable, last-value
// semantics: the next batch supersedes; everything else is ordered-reliable
// and must arrive). kit/netgd's gauge and shim are the consumers.
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
// EXPORTED, unlike its siblings: kit/netgd's byte gauge splits this kind by
// its tag byte (the sim lane, comms, and game messages each wear one), so
// the netgraph can name what the app bucket actually carries.
SES_APP :: u8(16) // any -> any      [tag u8][payload] — routed to the registered app handler
@(private)
SES_DENIED :: u8(17) // host -> joiner  [reason u8] — the join was refused (full/locked/banned)
@(private)
SES_KICKED :: u8(18) // host -> one     you were removed on purpose (not a host crash)
@(private)
SES_SETOWNER :: u8(19) // host -> all   [id][owner] — ownership transfer (carry/mount/possess)
@(private)
SES_SUCCESSOR :: u8(20) // host -> all  [player][info] — who carries the torch if I die, and how to find them
@(private)
SES_BLOB :: u8(21) // host -> all  [id][ver u32][len u32][bytes] — an entity blob changed

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
	// A tag collision is LOUD: two subsystems on one tag silently steal each
	// other's packets (kxfer's default tag once landed on a game's own tag).
	// The HANDLER proc identifies the subsystem — re-registering the same
	// handler stays legal (re-init builds fresh structs, so the user pointer
	// changes), and a nil handler is an explicit UNROUTE (comms_destroy).
	prev := s.app[tag]
	assert(
		handler == nil || prev.handler == nil || prev.handler == handler,
		"session_app_route: tag already routed to a different handler — pick distinct tag bytes",
	)
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
// peer (HOST_PEER, a seated player's peer, or BROADCAST_PEER). `channel`
// defaults to reliable — the right lane for anything event-shaped or that a
// consumer must not miss. Pass .Stream ONLY for tick-stamped, self-
// superseding payloads where the next send makes a lost one worthless
// (kit/sim's inputs and snapshot batches — the first taker): the receive
// side routes both channels identically, but nothing re-delivers a dropped
// .Stream message and nothing orders it against the reliable lane.
session_app_flush :: proc(s: ^Session, to_peer: Peer_Id, channel: Channel = .Reliable) {
	s.send(s.send_user, to_peer, knet.writer_bytes(&s.app_w), channel)
}

// Ship app payload bytes under `tag` — the one-call form when the payload
// already exists as a slice (begin/flush avoids the extra copy when you are
// building it anyway). Same channel rule as session_app_flush.
session_app_send :: proc(s: ^Session, to_peer: Peer_Id, tag: u8, bytes: []u8, channel: Channel = .Reliable) {
	w := session_app_begin(s, tag)
	append(&w.buf, ..bytes)
	session_app_flush(s, to_peer, channel)
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
	change_events:   bool, // emit Ev_Entity_Changed per dirty entity per tick (repaint THAT, not everything). Off by default: at friendslop scale repaint-everything is usually fine
	fingerprint:     u64, // the build's WIRE CONTRACT hash. 0 (the default) =
	// use the generated NET_FINGERPRINT — scriptgen's guard file registers it
	// at load (default_net_fingerprint), so the version gate is ON without any
	// wiring. Set explicitly only to override (a hand-rolled multi-module
	// contract), or to FINGERPRINT_NONE to disable the gate on purpose.
	// Nonzero on BOTH ends: the join carries it and a mismatch is denied
	// with .Version — a skewed build's descriptors would misparse every delta
	// into garbage fields, the least debuggable failure a playtest can produce.
	// A nonzero HOST also refuses fingerprint-less clients (pre-check builds).
}

// The generated guard file's @(init) parks the module's NET_FINGERPRINT here,
// so a game that never touches Session_Config.fingerprint still gets the
// version gate — the right thing, by default. (One value per scripts dll; a
// multi-net-module build overrides via cfg.fingerprint instead.)
default_net_fingerprint: u64

// Explicit "no version gate" for Session_Config.fingerprint — distinguishable
// from 0, which means "use the generated default".
FINGERPRINT_NONE :: u64(0xFFFFFFFFFFFFFFFF)

Session :: struct {
	is_host:   bool,
	dedicated: bool, // this authority is a DEDICATED SERVER: its seat is
	// infrastructure (see Player.dedicated) and succession never arms — a
	// dead server restarts, it does not migrate (the token/backup machinery
	// belongs to the friends-host-for-friends peer model).
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
	ran:          bool, // session_init completed at least once — gates the re-entrant teardown
	interp_delay: f64,
	later:        knet.Later, // session_present's queue — drained every session_tick

	// entity types + client-side factories
	types:         map[knet.Net_Id]Entity_Type, // host: for (re-)announcing spawns
	unsent:        map[knet.Net_Id]u64, // host: spawn_make'd, spawn_send still owed (tick-stamped)
	factory_user:  rawptr,
	factory_make:  Make_Entity_Proc,

	// The write guard's extra exemption (session_set_guard_exempt): "this
	// entity's delta-lane divergence is legal right now". kboot.boot_lane
	// installs one that knows about the sim lane's in-flight verbs.
	guard_exempt:      knet.Guard_Exempt_Proc,
	guard_exempt_user: rawptr,
	factory_free:  Free_Entity_Proc,
	game_user:     rawptr, // session_set_game's explicit override (nil = the factory user)
	cmd_hook_user: rawptr,
	cmd_hook:      Command_Hook, // host: the cross-entity half of commands (the catch-all)
	type_hooks:    map[Entity_Type]Type_Hook_Entry, // host: per-type routing (wins over the catch-all)

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

	// interest management (interest.odin) — off until session_set_interest
	interest_r:    f32,
	interest_hys:  f32,
	interest_user: rawptr,
	locator:       Locator_Proc,
	focus:         map[knet.Player_Id][2]f32, // host: each peer's eyes
	interest:      map[u64]bool, // host: (player, entity) pairs currently near
	aoi_client:    bool, // client: the welcome said streams route via the host
}

@(private = "file")
session_init :: proc(s: ^Session) {
	// RE-ENTRANT: host_start / client_start / host_resume may run on a
	// session that already ran (back to lobby -> rehost, host after a failed
	// join). Tear down the previous RUN's state — otherwise the old
	// registry/ctx maps leak and stat_names grows a duplicate "ping" column
	// that ships to every client — while preserving everything a game wires
	// BEFORE start: transport, factory, hooks, app routes, interp tuning.
	// Pending presentations are dropped even on a FIRST start: session_present
	// can legally run before any *_start (a lobby flourish), and those queued
	// against a zero clock must not fire into the new run.
	knet.later_clear(&s.later)
	// `ran` (not stat_names) gates the teardown: a FAILED host_resume leaves
	// stat_names empty but the roster/tokens/registry partially populated —
	// judging by a side effect would skip the teardown exactly then, leaking
	// the dead run's players into the next one.
	if s.ran {
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
		clear(&s.unsent)
		for n in s.stat_names {
			delete(n)
		}
		clear(&s.stat_names)
		clear(&s.stats)
		clear(&s.focus)
		clear(&s.interest)
		s.aoi_client = false
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
		s.dedicated = false
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
	s.ran = true
	if s.app_w.buf == nil {
		s.app_w = knet.writer_make()
	}
	// Commands always go host-ward through the session's own framing.
	s.ctx.send = ctx_send_command
	s.ctx.send_user = s
	// Re-install the hook dispatcher (hooks are wired in ready(), which runs
	// before any *_start recreates this ctx — the survives-start contract).
	// game_user rides the same contract: `_then` consequences keep their game
	// pointer across rehosts and resumes (explicit session_set_game wins,
	// else the factory's user).
	s.ctx.hook = ctx_hook_dispatch
	s.ctx.hook_user = s
	s.ctx.game_user = s.game_user != nil ? s.game_user : s.factory_user
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
	delete(s.focus)
	delete(s.interest)
	delete(s.type_hooks)
	delete(s.by_peer)
	delete(s.denied)
	delete(s.name)
	knet.registry_destroy(&s.reg)
	knet.command_ctx_destroy(&s.ctx)
	delete(s.clocks)
	delete(s.types)
	delete(s.unsent)
	for n in s.stat_names {
		delete(n)
	}
	delete(s.stat_names)
	delete(s.stats)
	delete(s.backup)
	delete(s.succ_info)
	delete(s.successor_info)
	knet.later_destroy(&s.later)
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

// The session's monotonic NET-TICK clock — the same counter commands and the
// delta walk are stamped with. Games with tick-paced sims (kit/ai's director,
// cooldown decay loops) read it here instead of accumulating their own:
// a hand-rolled counter silently diverges across resume/migration. LOCAL to
// this session's lifetime — never persist it, never compare it across peers.
session_tick_no :: proc(s: ^Session) -> u64 {
	return s.ticker.tick
}

// The render-timeline lag: remote-owned entities DRAW this many seconds in
// the past (stream sampling's buffer). It is also therefore the delay that
// re-aligns a wire-fresh consequence with the rendered simulation that
// caused it — see session_present and "The two timelines" in docs/kit/net.md.
session_interp_delay :: proc(s: ^Session) -> f64 {
	return s.interp_delay
}

// Present a consequence on the RIGHT timeline — the whole two-timelines
// discipline in one call. `mine` states the one fact the kit cannot derive
// from dirty bytes: whether THIS peer's own simulation caused the event (the
// claimer, the striker, the authority whose AI did it). Your own sim presents
// NOW (your screen is the truth everyone else is waiting to see); everyone
// else's showing is queued for now + interp_delay, landing within jitter of
// the rendered cause — because event and stream crossed the same wire, so
// transit cancels. State never waits: mutate replicated fields immediately
// like always; hand ONLY the showing (hide the node, burst, sound) to this.
//
// One presentation proc holds the whole effect — no verb enums, no drain
// switch, no per-role branches at the call site:
//
//     // the taken-edge, ONE place, every peer:
//     ksess.session_present(&g.ses, id == g.my_claim, g, present_gem_gone, id)
//
//     present_gem_gone :: proc(user: rawptr, id: knet.Net_Id, a: u64) {
//         self := cast(^Golf)user
//         if node, ok := self.nodes[id]; ok { gd.set_bool(cast(gd.Object)node, "visible", false) }
//     }
//
// `extra` adds seconds on top (an authority lingering a despawn PAST the
// slowest observer's showing — the edge-outlives-observers rule). The queue
// drains inside session_tick; a *_start/resume drops whatever was pending
// (those effects were about the old run's world).
session_present :: proc(s: ^Session, mine: bool, user: rawptr, cb: knet.Later_Proc, id := knet.NET_ID_INVALID, a := u64(0), extra := 0.0) {
	if mine && extra == 0 {
		cb(user, id, a)
		return
	}
	delay := extra + (mine ? 0 : s.interp_delay)
	knet.later_push(&s.later, s.now + delay, user, cb, id, a)
}

// Install the transport hookup (netgd.wire_attach calls this; hand-rolled
// transports and tests call it directly). Survives *_start like all pre-start
// wiring.
session_set_transport :: proc(s: ^Session, user: rawptr, send: Send_Proc) {
	s.send = send
	s.send_user = user
}

// Install the write guard's extra exemption (see registry_write_guard) —
// pre-start wiring like the transport/factory installers. kboot.boot_lane
// installs the sim lane's ("a tick-scheduled verb is in flight on this
// entity"); games without a lane never need one.
session_set_guard_exempt :: proc(s: ^Session, user: rawptr, exempt: knet.Guard_Exempt_Proc) {
	s.guard_exempt = exempt
	s.guard_exempt_user = user
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
	return Stat_Col(len(s.stat_names)) // 1-based handle (index + 1)
}

// Look a column up by name — how clients resolve what the scoreboard shows.
session_stat_find :: proc(s: ^Session, name: string) -> (Stat_Col, bool) {
	for n, i in s.stat_names {
		if n == name {
			return Stat_Col(i + 1), true
		}
	}
	return STAT_COL_INVALID, false
}

// Handle -> row index, with THE trap turned into a message: a zero-value
// Stat_Col is a column that was registered on another peer (or never).
@(private = "file")
stat_idx :: proc(col: Stat_Col) -> int {
	assert(
		col != STAT_COL_INVALID,
		"zero-value Stat_Col — session_stat_column registers on the HOST; on a peer that didn't register, resolve by name with session_stat_find (cheap — do it per read)",
	)
	return int(col) - 1
}

session_stat_names :: proc(s: ^Session) -> []string {
	return s.stat_names[:]
}

// NOTE: all row reads use the comma-ok form — a plain missing-key index of a
// map with a large value type faults in the current compiler (found by the
// acid test's crash reporter; a missing player must read as an all-zero row).
session_stat_set :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, value: i64) {
	assert(s.is_host, "stats are host-accumulated")
	idx := stat_idx(col)
	row, _ := s.stats[player]
	if row[idx] == value {
		return
	}
	row[idx] = value
	s.stats[player] = row
	s.stats_dirty = true
}

session_stat_add :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col, delta: i64) {
	assert(s.is_host, "stats are host-accumulated")
	idx := stat_idx(col)
	row, _ := s.stats[player]
	row[idx] += delta
	s.stats[player] = row
	s.stats_dirty = true
}

session_stat :: proc(s: ^Session, player: knet.Player_Id, col: Stat_Col) -> i64 {
	idx := stat_idx(col)
	row, ok := s.stats[player]
	if !ok {
		return 0
	}
	return row[idx]
}

// Install the client-side entity factory (do it before joining). The factory's
// `user` doubles as THE game pointer — what every `<verb>_then` consequence
// proc receives as its game param — unless session_set_game named a different
// one (kboot's boot_entities does: its factory user is the Boot, so it names
// the game explicitly). Survives starts via session_init's re-install.
session_set_factory :: proc(s: ^Session, user: rawptr, make_entity: Make_Entity_Proc, free_entity: Free_Entity_Proc) {
	s.factory_user = user
	s.factory_make = make_entity
	s.factory_free = free_entity
	if s.game_user == nil {
		s.ctx.game_user = user
	}
}

// Name THE game pointer explicitly — what `<verb>_then` consequences receive.
// Only needed when the factory's user is NOT the game (a driver like kboot's
// boot_entities sits between); defaults to the factory user otherwise. Wins
// regardless of call order and survives starts.
session_set_game :: proc(s: ^Session, user: rawptr) {
	s.game_user = user
	s.ctx.game_user = user
}

// Install the host-side command hook (see Command_Hook; survives session
// start). This is the CATCH-ALL: entities whose type has a
// session_set_type_hook route there instead. All hooks reach the ctx through
// one dispatcher, so the generated wrappers fire them for the authority's
// own local issues too.
session_set_command_hook :: proc(s: ^Session, user: rawptr, hook: Command_Hook) {
	s.cmd_hook_user = user
	s.cmd_hook = hook
	s.ctx.hook = ctx_hook_dispatch
	s.ctx.hook_user = s
}

Type_Hook_Entry :: struct {
	user: rawptr,
	hook: Command_Hook,
}

// PER-TYPE hook routing: commands on entities of `type` fire THIS hook
// instead of the catch-all. Why it exists: command ids collide across types
// (every type's first command is 0), so a single hook must classify the
// entity before switching on cmd — a page of is-it-a-chest chains that grows
// into a misclassification liability. Routed by the session's own type
// table, the wrong-type bug is structurally impossible, and each type's
// consequences live next to its verbs. Survives starts, like the catch-all.
session_set_type_hook :: proc(s: ^Session, type: Entity_Type, user: rawptr, hook: Command_Hook) {
	s.type_hooks[type] = Type_Hook_Entry{user = user, hook = hook}
	s.ctx.hook = ctx_hook_dispatch
	s.ctx.hook_user = s
}

// The one place every executed command's hook fires — the host's own local
// issues (via ctx) and the clients' (the SES_CMD handler) both land here.
@(private = "file")
session_dispatch_hook :: proc(s: ^Session, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	if t, known := s.types[entity]; known {
		if th, routed := s.type_hooks[t]; routed {
			th.hook(th.user, player, entity, cmd, ok)
			return
		}
	}
	if s.cmd_hook != nil {
		s.cmd_hook(s.cmd_hook_user, player, entity, cmd, ok)
	}
}

@(private = "file")
ctx_hook_dispatch :: proc(user: rawptr, player: knet.Player_Id, entity: knet.Net_Id, cmd: u16, ok: bool) {
	session_dispatch_hook(cast(^Session)user, player, entity, cmd, ok)
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
	append(&s.events, Ev_Spawned{id = id, type = type, owner = owner}) // pre-filled entity: born now
	return id
}

// Host: spawn THROUGH THE FACTORY — the same Make_Entity_Proc clients run,
// so every entity type's creation is written exactly once. Two-phase because
// the spawn announcement carries a field snapshot: make, set your per-spawn
// fields on the returned entity, then session_spawn_send — which is where
// Ev_Spawned fires (the entity is BORN once its fields are set; an event at
// make time would hand the game an empty shell).
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
	// The send is OWED: a make whose send never comes is a half-spawn that
	// exists on the host and on late joiners (SES_WORLD walks the registry)
	// but never on already-seated peers — per-join-order worlds. net_tick
	// asserts if this entry survives a tick boundary.
	s.unsent[id] = s.ticker.tick
	return
}

// Second half of session_spawn_make: announce the spawn (with the fields as
// they stand NOW) to every seated peer.
session_spawn_send :: proc(s: ^Session, id: knet.Net_Id) {
	assert(s.is_host)
	delete_key(&s.unsent, id) // the owed send arrived
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_SPAWN)
		write_spawn_tuple(s, &w, id)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
	if e, ok := knet.registry_get(&s.reg, id); ok {
		append(&s.events, Ev_Spawned{id = id, type = s.types[id], owner = e.owner})
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

// STREAM FREQUENCY: the OWNER of `id` streams its position at (about) `hz`,
// instead of the full net-tick rate. THE bandwidth lever for many cheap AI,
// distant, or slow-moving entities — half the rate is half that entity's
// stream bytes. Say it in Hz, like tick_hz: `session_set_stream_hz(s, mob, 30)`.
//
// A stream can only fire on a net tick, so the rate SNAPS to the nearest
// achievable tick_hz/N (at 60Hz: 60, 30, 20, 15, 12, 10, …). The achieved Hz
// is returned so you can see the snap — request 25 at a 60 base and you get 30.
// hz <= 0 or >= tick_hz means every tick (the default, full rate).
//
// KEEP THE PERIOD UNDER interp_delay (1/hz < interp_delay) for entities that
// INTERPOLATE, or remote motion stutters — the ring runs out of samples to
// blend. A 10Hz stream (100ms) needs interp_delay >= ~200ms; that's fine for a
// board game whose pieces SNAP (they move discretely — no blend to starve) but
// wrong for a runner sliding across the floor. Only the sender's batch changes;
// hp/other host DELTAS are untouched (event-driven already) and authoritative
// hit tests read full-precision struct state at full rate. Send-side local hint,
// not replicated — re-apply after a host migration, like interest.
session_set_stream_hz :: proc(s: ^Session, id: knet.Net_Id, hz: int) -> (actual_hz: int) {
	rate := session_tick_hz(s)
	if hz <= 0 || hz >= rate {
		knet.registry_set_stream_tier(&s.reg, id, 1)
		return rate
	}
	// Nearest divisor: round(rate/hz), clamped so the u8 tier can't overflow
	// or go below "every other tick".
	tier := (rate + hz / 2) / hz
	tier = clamp(tier, 2, 255)
	knet.registry_set_stream_tier(&s.reg, id, u8(tier))
	return rate / tier
}

// The raw divisor form of session_set_stream_hz, for exact control or when you
// think in "every Nth tick" (tests, tools). 0/1 = every tick. Most games want
// the Hz form above.
session_set_stream_tier :: proc(s: ^Session, id: knet.Net_Id, tier: u8) {
	knet.registry_set_stream_tier(&s.reg, id, tier)
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
	if !knet.registry_set_owner(&s.reg, id, owner, s.now) {
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

// Host: replace an entity's BLOB — the variable-length escape hatch. One
// opaque payload per entity, shipped reliably to every peer when YOU say it
// changed (no diffing, no interpolation, no prediction interplay — it is not
// a field). It rides every full snapshot, so late joiners, backup hosts, and
// saves carry it with no extra code. Ev_Blob_Changed fires on every peer
// (this one included). For per-tick state use replicated fields; for
// event-shaped things use app messages — a blob is for variable-length state
// a NEW observer must be able to see.
session_set_blob :: proc(s: ^Session, id: knet.Net_Id, data: []u8) {
	assert(s.is_host, "blobs are host truth; clients ask via commands or app messages")
	if !knet.registry_set_blob(&s.reg, id, data) {
		return
	}
	append(&s.events, Ev_Blob_Changed{id = id, size = len(data)})
	if s.replicating {
		_, ver := knet.registry_blob(&s.reg, id)
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_BLOB)
		knet.write_net_id(&w, id)
		knet.write_u32(&w, ver)
		knet.write_u32(&w, u32(len(data)))
		append(&w.buf, ..data)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
}

// The entity's current blob — a view, valid until the next set/apply/despawn;
// copy it if you keep it. Empty slice = never set (or cleared).
session_blob :: proc(s: ^Session, id: knet.Net_Id) -> []u8 {
	data, _ := knet.registry_blob(&s.reg, id)
	return data
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
	delete_key(&s.unsent, id) // a make despawned before its send owes nothing
	interest_forget_entity(s, id)
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

// [type][id][owner][len u16][full fields][blob_ver u32][blob_len u32][blob]
// — both lengths make unknown types skippable whole. The blob section is why
// entity blobs need no separate catch-up path: joins, backups, and saves all
// serialize entities through this one tuple.
@(private) // interest.odin's re-entry resync writes these too
write_spawn_tuple :: proc(s: ^Session, w: ^knet.Writer, id: knet.Net_Id) {
	e, _ := knet.registry_get(&s.reg, id)
	knet.write_u16(w, u16(s.types[id]))
	knet.write_net_id(w, id)
	knet.write_player_id(w, e.owner)
	n := knet.desc_wire_size(e.set.entity_desc)
	assert(n <= int(max(u16)))
	knet.write_u16(w, u16(n))
	knet.write_full(w, e.entity, e.set.entity_desc)
	knet.write_u32(w, e.blob_ver)
	knet.write_u32(w, u32(len(e.blob)))
	append(&w.buf, ..e.blob)
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

	// The blob section is consumed up front — every early-out below (already
	// known, no factory, unknown type) must leave the reader past this tuple.
	blob_ver := knet.read_u32(r)
	blob_n := int(knet.read_u32(r))
	if r.err || blob_n < 0 || r.off + blob_n > len(r.data) { // <0: 32-bit wrap on hostile lengths
		r.err = true
		return
	}
	blob := r.data[r.off:r.off + blob_n]
	r.off += blob_n

	if e, exists := knet.registry_get(&s.reg, id); exists {
		knet.apply_full(&body, e.entity, e.set.entity_desc)
		knet.registry_bless(&s.reg, id) // the resync is framework truth (write guard)
		// A known entity caught up wholesale (interest re-entry, snapshot
		// over live state). The game hears it as Ev_Resynced, NOT a second
		// Ev_Spawned — the entity was never gone HERE. The jump is history,
		// not gameplay: the edge mirrors re-seed SILENTLY (no `<field>_edge`
		// fires), and any hand-rolled seen_* scratch re-seeds off this event.
		knet.registry_edges_commit(&s.reg, id)
		append(&s.events, Ev_Resynced{id = id, type = type, owner = owner})
		if knet.registry_apply_blob(&s.reg, id, blob_ver, blob) {
			append(&s.events, Ev_Blob_Changed{id = id, size = blob_n})
		}
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
	knet.registry_bless(&s.reg, id) // spawn dress baseline (write guard)
	append(&s.events, Ev_Spawned{id = id, type = type, owner = owner})
	// Blob event AFTER Ev_Spawned: by the time the game hears about the blob,
	// the entity it decorates exists on this peer.
	if knet.registry_apply_blob(&s.reg, id, blob_ver, blob) {
		append(&s.events, Ev_Blob_Changed{id = id, size = blob_n})
	}
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
	// The delta-lane WRITE GUARD (kit/net registry.odin): on a client, a
	// host-lane field that moved outside the framework since its last bless
	// is a local rogue write — the canonical silent-divergence bug, named
	// within one net tick instead of never. Costs the host's own diff walk;
	// stripped whole (walk and all) under `-disable-assert`.
	when !ODIN_DISABLE_ASSERT {
		if ticks > 0 && !s.is_host {
			if cls, field, id, found := knet.registry_write_guard(&s.reg, &s.ctx, s.guard_exempt, s.guard_exempt_user); found {
				assert(
					false,
					fmt.tprintf(
						"WRITE GUARD: %s.%s (net id %d) changed on a CLIENT outside the framework — " +
						"host-lane replicated fields are the authority's to write; a client's local write never replicates (it silently diverges). " +
						"Route the change through a verb (`<verb>_cmd`) or compute it on the authority (`_then` / an authority step); " +
						"presentation belongs in halves, not in replicated fields.",
						cls, field, u32(id),
					),
				)
			}
		}
	}
	// Presentations whose render time has come (session_present) fire here,
	// AFTER sampling — the rendered world they align with is current.
	knet.later_drain(&s.later, now)
	// The `<field>_edge` halves: NET delta-lane changes since last frame —
	// this frame's applies, reverts, and the host's own mutations alike (one
	// pass, zero role branches). Runs on the game's stack like everything
	// else in this proc; the game pointer is the `_then` contract's.
	session_run_edges(s)
	return
}

// Run the `<field>_edge` pass NOW — diff every edge-declaring entity against
// its mirror, fire the halves for what changed, commit. session_tick already
// runs it once per frame, and the pass is IDEMPOTENT (diff-then-commit), so
// extra calls cost a memcmp and fire nothing new. The one caller that needs
// it: an AUTHORITY whose game tick mutates delta-lane state AFTER the frame's
// session_tick (the classic `for ticks {my_game_tick}` loop) — call this
// right after that loop and the host's own edges fire the SAME frame its
// mutations happened, exactly like the hand-rolled polls they replaced (one
// frame matters when the half moves something the next tick's world reads —
// cavecrawl's respawn walk-out was the worked lesson: a frame of un-teleported
// full-hp host at point-blank range is one more rock through a friend).
session_run_edges :: proc(s: ^Session) {
	_ = knet.registry_edges_tick(&s.reg, s.game_user != nil ? s.game_user : s.factory_user)
}

@(private = "file")
net_tick :: proc(s: ^Session) {
	t := s.ticker.tick
	s.ctx.now_tick = t

	// The spawn pair's contract: make, set fields, SEND — same frame. An
	// entry that survives a tick boundary is a forgotten session_spawn_send,
	// which reads as an entity that exists for late joiners (SES_WORLD walks
	// the registry) but never for already-seated peers. Loud beats haunted.
	for id, made in s.unsent {
		if t > made + 1 {
			assert(
				false,
				fmt.tprintf("entity %d (type %d) was session_spawn_make'd but never session_spawn_send'd — the pair is make, set fields, send (same frame)", u32(id), u16(s.types[id])),
			)
		}
	}

	if !s.is_host && !s.joined && s.join_waited >= 0 {
		s.join_waited += 1
		if s.join_waited > s.join_timeout {
			s.join_waited = -1
			append(&s.events, Ev_Join_Failed{})
		}
	}

	if s.is_host && s.replicating {
		changed: [dynamic]knet.Net_Id
		changed_out: ^[dynamic]knet.Net_Id
		if s.cfg.change_events {
			changed = make([dynamic]knet.Net_Id, context.temp_allocator)
			changed_out = &changed
		}
		dirty := 0
		if interest_on(s) {
			// Freshness is local: refresh who-sees-what (ENTER resyncs ride
			// along), then compose per-recipient delta batches — one shadow
			// commit either way.
			interest_tick(s)
			dirty = interest_send_state(s, changed_out)
		} else {
			// Host state: ONE batched delta message for every dirty entity,
			// to every joined peer, reliable (the shadow commits on send — a
			// dropped delta would be lost forever).
			w := knet.writer_make()
			defer knet.writer_destroy(&w)
			knet.write_u8(&w, SES_STATE)
			if dirty = knet.registry_write_deltas(&w, &s.reg, changed_out); dirty > 0 {
				broadcast(s, knet.writer_bytes(&w), .Reliable)
			}
		}
		if dirty > 0 {
			// The HOST gets the state event too: its own tick just changed
			// these entities, and event-driven repaint code should not need
			// a role branch (a host inventory once went stale for six
			// phases because it didn't get this).
			append(&s.events, Ev_State_Applied{entities = dirty})
			for id in changed {
				append(&s.events, Ev_Entity_Changed{id = id})
			}
		}
	}

	// Owner streams: last-value snapshots of every entity WE own, unreliable
	// (a drop is superseded by the next tick's snapshot). Any peer can own.
	// Routing depends on interest: normally the transport's relay fans the
	// batch out; with interest on, the HOST is the router — its own batch is
	// split per recipient here, and clients send theirs to the host (the
	// SES_STREAM handler forwards), which costs no extra hop: the relay was
	// that same machine all along.
	{
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_STREAM)
		if knet.registry_write_streams(&w, &s.reg, s.me, s.now, t) > 0 {
			if interest_on(s) {
				interest_route_streams(s, knet.writer_bytes(&w)[1:], 0)
			} else if !s.is_host && s.aoi_client {
				s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Stream)
			} else {
				broadcast(s, knet.writer_bytes(&w), .Stream)
			}
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
		// Never on a DEDICATED server: migration is the peer model's answer
		// to a host who is also a player leaving; a server just restarts.
		if s.replicating && !s.dedicated {
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

@(private) // interest.odin composes per-peer sends beside this
broadcast :: proc(s: ^Session, bytes: []u8, channel: Channel) {
	s.send(s.send_user, BROADCAST_PEER, bytes, channel)
}

// This peer's clock estimate for `peer` (zero value until a pong lands).
session_clock :: proc(s: ^Session, peer: Peer_Id) -> knet.Clock_Sync {
	return s.clocks[peer]
}

// A timeline every peer roughly agrees on: the HOST's session clock.
// Schedule shared moments against it — "the round ends at world_time + 30"
// replicates as one f64 field and every screen counts down in sync (within
// about half a ping). Before the first pong lands a client answers with its
// own clock; gate on s.pongs > 0 if the difference matters to you.
session_world_time :: proc(s: ^Session) -> f64 {
	if s.is_host {
		return s.now
	}
	c := s.clocks[HOST_PEER]
	if !c.initialized {
		return s.now
	}
	return knet.clock_remote_now(&c, s.now)
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
	if r.err || n < 0 || r.off + n > len(s.backup) { // <0: 32-bit wrap on hostile lengths
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
// owned entities exactly like any reconnect. That includes the dead HOST,
// if it started with a token (session_host_start's `token` param); without
// one it returns as a NEW player.
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
	if r.err || cols == 0 || cols > MAX_STAT_COLS { // 0: even a fresh run has "ping"
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
		// The host is a reader of the scoreboard too, and it never hears its
		// own broadcast — without this, a game that repaints only on
		// Ev_Stats_Updated ships a board that is permanently empty on the
		// host's screen (both games independently discovered the workaround
		// of refreshing at show time; now the event fires everywhere).
		append(&s.events, Ev_Stats_Updated{})
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

// `players_only` skips dedicated seats — the count for anything gating on
// PEOPLE (min-players, "everyone ready", max_players): a server is not a
// player, however real its seat is to the wire.
session_count :: proc(s: ^Session, connected_only := false, players_only := false) -> int {
	if !connected_only && !players_only {
		return len(s.players)
	}
	n := 0
	for _, p in s.players {
		if connected_only && !p.connected {continue}
		if players_only && p.dedicated {continue}
		n += 1
	}
	return n
}

// ---- host ------------------------------------------------------------------

// Become the session authority. The host is a full player too (name, id,
// stats) — it just never JOINs over the wire. Pass the game's persistent
// reconnect `token` so the host holds an identity like everyone else: its
// hash rides every backup snapshot, and if this host dies mid-run it can
// rejoin the resumed session and reclaim its own seat (stats, entities)
// exactly like a client. Zero = the v1 shape: a dead host returns as a
// NEW player.
//
// `dedicated` makes this authority a SERVER, not a player: its seat is
// flagged infrastructure on every roster (games field it no avatar; kit UI
// hides it; player gates don't count it) and SUCCESSION NEVER ARMS — a dead
// server restarts, it does not migrate. The friends-host-for-friends model
// is untouched; this is the always-on/public-hosting escape hatch.
session_host_start :: proc(s: ^Session, name: string, token: u64 = 0, dedicated := false) {
	session_init(s)
	s.is_host = true
	s.dedicated = dedicated
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
		dedicated = dedicated,
	}
	if token != 0 {
		s.token = token
		s.tokens[token_hash(token)] = s.me
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
	fp := knet.read_u64(r)
	if r.err {
		// A pre-fingerprint build's JOIN ends at the name — read that as "no
		// fingerprint" and let the gate below give it a sentence (only this
		// trailing read can newly err: a torn packet returned above).
		fp = 0
		r.err = false
	}

	// The FIRST gate: the builds must speak the same wire. A version-skewed
	// peer's descriptors would misparse every delta into garbage fields — no
	// other gate matters if this one fails, and the reconnect promise cannot
	// survive a wire the two ends disagree on.
	if want := wire_fingerprint(s.cfg.fingerprint); want != 0 && fp != want {
		deny_join(s, peer, .Version)
		return
	}

	// The gates, in order of severity. A RETURNING identity passes lock and
	// capacity — its seat is its own (that is the whole reconnect promise);
	// only a ban shuts a known token out.
	hash := token_hash(token)
	id, known := s.tokens[hash]
	if known {
		if p, live := s.players[id]; live && p.connected {
			// A known token whose seat is still CONNECTED is never a reconnect:
			// the wire cannot tell a crashed-socket zombie from a LIVE second
			// instance sharing the machine's identity file (a couch test, extra
			// browser tabs — same-origin storage hands every tab the same
			// token; the third tab was seizing the second's seat). Seat it as
			// a NEW player instead of hijacking the live one: the transport
			// reaps real zombies within seconds, and a genuinely dead seat
			// (its row disconnected — the crashed client, the old host on a
			// resumed session) reclaims as ever; the revenant and the chase
			// both ride that path. The shared hash then maps to the newest
			// seat; same-file identities stay ambiguous by nature — distinct
			// tokens (SY_TOKEN-style) are the real answer for deliberate
			// same-machine play. (This subsumes the old id == s.me guard: a
			// live host is just the most obvious connected seat.)
			known = false
		}
	}
	if _, banned := s.denied[hash]; banned {
		deny_join(s, peer, .Banned)
		return
	}
	if !known {
		if s.locked {
			deny_join(s, peer, .Locked)
			return
		}
		// max_players caps PEOPLE — a dedicated server's own seat never eats one.
		if s.cfg.max_players > 0 && session_count(s, connected_only = true, players_only = true) >= s.cfg.max_players {
			deny_join(s, peer, .Full)
			return
		}
	}
	rejoin := false
	if known {
		// The token IS the identity and its seat sits DISCONNECTED (the guard
		// above routes live-seat matches to the fresh-join arm): reclaim it.
		rejoin = true
		p := s.players[id]
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
		knet.write_bool(&w, p.dedicated) // the server seat announces itself
	}
	knet.write_bool(&w, s.interest_r > 0 && s.locator != nil) // stream routing (interest.odin)
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
	knet.write_u64(&w, wire_fingerprint(s.cfg.fingerprint))
	s.send(s.send_user, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

// The kit's own wire revision, folded into every nonzero fingerprint before it
// rides SES_JOIN — a kit upgrade that changes the wire then refuses skewed
// peers even when the game's declarations didn't move. Bump on wire changes.
PROTOCOL_REV :: u64(3) // 1: pre-fingerprint kit · 2: SES_JOIN carries a fingerprint · 3: the wire frame byte carries the stream-channel bit (netgd)

@(private = "file")
FP_SALT :: u64(0x9E3779B97F4A7C15) + PROTOCOL_REV // the golden-ratio constant, rev-shifted
// (added, not multiplied: a typed compile-time u64 multiply that overflows
// trips an LLVM-backend assert in current Odin — a compiler crash, not an error)

@(private = "file")
wire_fingerprint :: proc(cfg_fp: u64) -> u64 {
	fp := cfg_fp
	if fp == 0 {
		fp = default_net_fingerprint // the generated guard file's @(init) value
	}
	if fp == 0 || fp == FINGERPRINT_NONE {
		return 0 // unchecked stays unchecked — never salted into a phantom value
	}
	return fp ~ FP_SALT
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
roster_upsert :: proc(s: ^Session, id: knet.Player_Id, name: string, connected: bool, peer := NO_PEER, dedicated := false) {
	if old, had := s.players[id]; had {
		delete(old.name)
	}
	s.players[id] = Player {
		id        = id,
		name      = strings.clone(name),
		peer      = peer,
		connected = connected,
		dedicated = dedicated,
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
		dedicated := knet.read_bool(r)
		if r.err {
			return // partial roster is fine: entries already applied are valid
		}
		roster_upsert(s, id, name, connected, dedicated = dedicated)
	}
	s.me = me
	s.ctx.me = me
	// Interest routing (older hosts simply end the payload here: read_bool
	// on an exhausted reader yields false — broadcast, the old behavior).
	s.aoi_client = knet.read_bool(r)
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
		if knet.registry_set_owner(&s.reg, id, owner, s.now) {
			append(&s.events, Ev_Owner_Changed{id = id, owner = owner, prev = prev})
		}
	case SES_BLOB:
		if s.is_host || !s.joined {
			return
		}
		id := knet.read_net_id(r)
		ver := knet.read_u32(r)
		n := int(knet.read_u32(r))
		if r.err || n < 0 || r.off + n > len(r.data) { // <0: 32-bit wrap on hostile lengths
			return
		}
		if knet.registry_apply_blob(&s.reg, id, ver, r.data[r.off:r.off + n]) {
			append(&s.events, Ev_Blob_Changed{id = id, size = n})
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
		changed: [dynamic]knet.Net_Id
		changed_out: ^[dynamic]knet.Net_Id
		if s.cfg.change_events {
			changed = make([dynamic]knet.Net_Id, context.temp_allocator)
			changed_out = &changed
		}
		n := knet.registry_apply_deltas(r, &s.reg, &s.ctx, changed_out)
		if !r.err {
			append(&s.events, Ev_State_Applied{entities = n})
			for id in changed {
				append(&s.events, Ev_Entity_Changed{id = id})
			}
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
		session_dispatch_hook(s, pid, h.entity, h.cmd, ok)
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
		raw := r.data[r.off:] // the batch, pre-parse (the host may forward it)
		_ = knet.registry_stream_time(r) // sender stamp (clock-mapped timelines later)
		_ = knet.registry_apply_streams(r, &s.reg, s.me, s.now)
		if interest_on(s) {
			interest_route_streams(s, raw, from_peer)
		}
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
