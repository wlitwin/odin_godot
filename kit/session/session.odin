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

import "base:intrinsics"
import "core:fmt"
import "core:mem"
import "core:strings"
import knet "godot:kit/net"

// Which wire the message rides — maps to kit/netgd's channel plan.
Channel :: enum u8 {
	Reliable, // commands, results, state batches, roster, pings
	Stream, // owner-stream snapshots: unreliable-ordered, last-value
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

// Optional transport half used by automatic traffic-policy kicks. The session
// revokes the player seat; netgd installs a deferred socket close so SES_KICKED
// can flush first. Hand-written transports may install the same hook.
Drop_Peer_Proc :: proc(user: rawptr, peer: Peer_Id)

// A fixed vocabulary from the transport boundary through the session event
// queue. No remote text is admitted, so these records are safe to retain,
// aggregate, or serialize in production.
Disconnect_Reason :: enum u8 {
	Unknown,
	Graceful,
	Transport_Lost,
	Timeout,
	Kicked,
	Banned,
	Traffic_Policy,
	Protocol,
}

disconnect_reason_valid :: proc(reason: Disconnect_Reason) -> bool {
	return reason >= .Unknown && reason <= .Protocol
}

Production_Log_Kind :: enum u8 {
	Malformed_Packet,
	Action_Rejected,
	Traffic_Refused,
	Disconnected,
}

Production_Log_Record :: struct {
	kind:          Production_Log_Kind,
	disconnect:    Disconnect_Reason,
	action_reason: knet.Action_Reject_Reason,
	action_model:  knet.Action_Model,
	player:        knet.Player_Id,
	peer:          Peer_Id,
	stage:         Authority_Ingress_Stage,
	class:         Traffic_Class,
	bytes:         u32,
	count:         u64,
}

Production_Log_Hook :: proc(user: rawptr, record: Production_Log_Record)
PRODUCTION_LOG_EVENTS_PER_SECOND :: 16

// ENet/SceneMultiplayer convention: the host is always transport peer 1.
HOST_PEER :: Peer_Id(1)

// A disconnected player's seat.
NO_PEER :: Peer_Id(0)

Player :: struct {
	id:        knet.Player_Id,
	name:      string, // owned by the session
	peer:      Peer_Id, // transport seat; NO_PEER while disconnected
	connected: bool,
	// A WATCHING seat: sees the whole world, owns nothing, counts toward
	// nothing. Player gates skip it (session_count's players_only), it can
	// never hold the torch (backup_target), and the host drops its commands
	// and streams outright — a spectator's wire is receive-only past the
	// join. It bypasses max_players on purpose: a full room can be watched.
	spectator: bool,
	dedicated: bool, // an INFRASTRUCTURE seat (a dedicated server), not a person:
	// fields no avatar, hidden from rosters/scoreboards, uncounted by player
	// gates. Only the authority can hold one (session_host_start's flag).
}

// ---- events: everything the game reacts to, drained per frame --------------

// I HOLD A SEAT NOW — every role, once per seat taken: the host at
// session_host_start, a client at its WELCOME (just before Ev_Welcomed). The
// role-free "seated" moment: per-seat declares (your profile row, your
// cosmetics, a greeting) belong in its half and run the same way on either
// side — the host no longer hand-calls them at its own start because
// Ev_Welcomed is the client's alone. Not re-fired by a host takeover: the
// heir's seat is the seat it already held (its profile row rode across).
Ev_Seated :: struct {
	me: knet.Player_Id,
}

Ev_Welcomed :: struct {
	me: knet.Player_Id, // (client) the host accepted us; the roster is seeded
}

Ev_Player_Joined :: struct {
	id:     knet.Player_Id,
	rejoin: bool, // reclaimed an existing identity (reconnect)
}

Ev_Player_Left :: struct {
	id:     knet.Player_Id, // stays in the roster, disconnected (may reconnect)
	reason: Disconnect_Reason,
}

Ev_Host_Left :: struct {reason: Disconnect_Reason} // (client) the host is gone. Alone it ends the run; with
// succession armed, Ev_Succession fires BESIDE it and the run survives — the
// named bearer runs the takeover recipe, everyone else rejoins the successor
// info (see "Backup hosting and resume" in session.md).

Ev_Join_Failed :: struct {reason: Disconnect_Reason} // (client) no WELCOME within the join timeout — surface it, don't hang on "Joining..."

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

Ev_Kicked :: struct {reason: Disconnect_Reason} // (client) deliberate removal, including policy kicks/bans

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
	ok:     bool, // compatibility mirror: reason == .None
	reason: knet.Action_Reject_Reason,
	model:  knet.Action_Model,
	seq:    knet.Intent_Seq,
	player: knet.Player_Id, // who issued it
	entity: knet.Net_Id, // what it targeted
	cmd:    u16, // stable command id in the target's set
}

Ev_Command_Confirmed :: struct {
	seq:    knet.Intent_Seq, // (client) prediction/scheduled issue stands
	entity: knet.Net_Id,
	cmd:    u16,
	model:  knet.Action_Model,
}

Ev_Command_Rejected :: struct {
	seq:    knet.Intent_Seq, // (client) truth applied (or revert fallback)
	entity: knet.Net_Id,
	cmd:    u16,
	model:  knet.Action_Model,
	reason: knet.Action_Reject_Reason,
}

Event :: union {
	Ev_Seated,
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
	Ev_Profile_Changed,
}

// ---- the stat registry: stats.odin -------------------------------------------
// ---- backup hosting + succession: backup.odin --------------------------------

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
Make_Entity_Proc :: proc(
	user: rawptr,
	type: Entity_Type,
	id: knet.Net_Id,
	owner: knet.Player_Id,
) -> (
	entity: rawptr,
	set: ^knet.Command_Set,
)

// Client-side: the entity was despawned and already removed from the registry
// — free the node/struct.
Free_Entity_Proc :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr)

// Host-side, optional: the authority's OWN spawn is BORN — called SYNCHRONOUSLY
// inside session_spawn / session_spawn_send, in place of queueing Ev_Spawned,
// the instant the entity's spawn fields are set and announced. Without it the
// host hears its own spawns like everyone else: from the event queue, at the
// next poll — which on a frame loop is the NEXT frame for any spawn made
// after the drain (a host step, a timer, a later _process), one rendered
// frame with the node undressed. The client path (apply_spawn_tuple) stays
// queued on purpose: a joiner's world arrives in one packet behind its
// WELCOME, and hearing spawns before Ev_Welcomed / mid-snapshot would be a
// worse ordering than a same-frame batch. kboot installs this from
// boot_entities when it holds the game's generated dispatcher.
Born_Proc :: proc(user: rawptr, ev: Ev_Spawned)

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
SES_LEFT :: u8(3) // host -> all     [id][Disconnect_Reason u8]
@(private)
SES_BYE :: u8(4) // client -> host  [Disconnect_Reason.Graceful u8]
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
SES_KICKED :: u8(18) // host -> one     [Disconnect_Reason u8]
@(private)
SES_SETOWNER :: u8(19) // host -> all   [id][owner] — ownership transfer (carry/mount/possess)
@(private)
SES_SUCCESSOR :: u8(20) // host -> all  [player][info] — who carries the torch if I die, and how to find them
@(private)
SES_BLOB :: u8(21) // host -> all  [id][ver u32][len u32][bytes] — an entity blob changed

SES_DECLARE :: u8(22) // client -> host  [size u16][row bytes] — my profile row (profile.odin)
SES_PROFILES :: u8(23) // host -> all    [size u16][players u16] x ([id][row]) — the profile table
SES_AOI :: u8(24) // host -> all    [aoi bool] — stream filtering changed MID-RUN (session_set_interest after clients joined; the welcome covers everyone later)

// One past the highest SES_* id — the ONE number a new wire kind bumps,
// right here beside its constant. netgd's per-kind gauge derives its table
// size from this, so a new kind can never alias onto another row's tally.
SES_KIND_COUNT :: 25

// The kinds' display names, indexed by the constants above — id and label
// live in ONE file, a screen apart (netgd's gauge copies these rows at load;
// its old hand-mirrored twin had already drifted by count once). A new kind
// adds its constant, bumps SES_KIND_COUNT, and names itself here; a missing
// name renders "" in the traffic line — visible, never another row's label.
SES_KIND_NAMES := [SES_KIND_COUNT]string {
	int(SES_JOIN) = "join",
	int(SES_WELCOME) = "welcome",
	int(SES_UPSERT) = "upsert",
	int(SES_LEFT) = "left",
	int(SES_BYE) = "bye",
	int(SES_STATE) = "state",
	int(SES_CMD) = "cmd",
	int(SES_RESULT) = "result",
	int(SES_STREAM) = "stream",
	int(SES_PING) = "ping",
	int(SES_PONG) = "pong",
	int(SES_SPAWN) = "spawn",
	int(SES_DESPAWN) = "despawn",
	int(SES_WORLD) = "world",
	int(SES_STATS) = "stats",
	int(SES_BACKUP) = "backup",
	int(SES_APP) = "app",
	int(SES_DENIED) = "denied",
	int(SES_KICKED) = "kicked",
	int(SES_SETOWNER) = "setowner",
	int(SES_SUCCESSOR) = "successor",
	int(SES_BLOB) = "blob",
	int(SES_DECLARE) = "declare",
	int(SES_PROFILES) = "profiles",
	int(SES_AOI) = "aoi",
}

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

// Raw/typed app messages are gameplay messages, not bulk transfer. This still
// leaves ample room for composed sim snapshots; larger assets use kit/xfer.
APP_MESSAGE_MAX_BYTES :: 256 * 1024
PLAYER_NAME_MAX_BYTES :: 256
RECORDING_MAX_BYTES :: 64 * 1024 * 1024

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
	s.app[tag] = App_Route {
		user    = user,
		handler = handler,
	}
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
	bytes := knet.writer_bytes(&s.app_w)
	assert(
		len(bytes) >= 2 && len(bytes) - 2 <= APP_MESSAGE_MAX_BYTES,
		"app message exceeds APP_MESSAGE_MAX_BYTES — use kit/xfer for bulk payloads",
	)
	session_send_packet(s, to_peer, bytes, channel)
}

// ---- typed app messages: a fixed-shape payload, decoded for you ------------
//
// The bare route (session_app_route) hands the receiver a raw Reader to parse by
// hand — the rawptr surface every game re-wrote a read loop against. A TYPED
// route carries a raw fixed-shape payload struct: session_app_send frames it, and the
// receiver's handler is called with the decoded value, no read code. The game
// owns the route record (like kcombat.Fire_Route), so the kit keeps no per-route
// heap or globals — parallel sessions never collide. The runtime #assert refuses
// direct pointer shapes; generated routes additionally require the recursive
// canonical ABI (fixed widths, bounded values, no hidden padding). For text or
// variable-length data, frame it yourself on a bare route.
Typed_Route :: struct($T: typeid) {
	handler: proc(user: rawptr, from: knet.Player_Id, msg: T),
	user:    rawptr,
}

// Route `tag` to a TYPED handler. `route` is a game-owned Typed_Route(T) (a field
// on your struct); it holds the handler + user so the generated dispatch thunk
// can reach them. Same survives-*_start and tag-collision rules as
// session_app_route.
session_app_listen :: proc(
	s: ^Session,
	tag: u8,
	route: ^Typed_Route($T),
	user: rawptr,
	handler: proc(user: rawptr, from: knet.Player_Id, msg: T),
) {
	#assert(
		intrinsics.type_is_nearly_simple_compare(T) &&
		!intrinsics.type_is_pointer(T) &&
		!intrinsics.type_is_multi_pointer(T),
		"session_app_listen: the payload T must be POD (no strings, slices, maps, or pointers — frame those yourself on a bare session_app_route)",
	)
	#assert(size_of(T) <= APP_MESSAGE_MAX_BYTES, "typed app payload exceeds APP_MESSAGE_MAX_BYTES")
	route.handler = handler
	route.user = user
	session_app_route(s, tag, route, app_typed_dispatch(T))
}

// The per-T dispatch thunk: decode the POD payload and hand it to the typed
// handler. Concrete per T (the nested proc resolves T at instantiation), so
// there is exactly one for each payload type the program routes.
@(private = "file")
app_typed_dispatch :: proc($T: typeid) -> App_Handler {
	return proc(user: rawptr, from: knet.Player_Id, from_peer: Peer_Id, r: ^knet.Reader) {
			route := cast(^Typed_Route(T))user
			if r.err || len(knet.reader_remaining(r)) != size_of(T) {
				r.err = true
				return // a short/trailing/garbled payload never reaches the handler
			}
			msg: T
			mem.copy(&msg, &r.data[r.off], size_of(T))
			r.off += size_of(T)
			route.handler(route.user, from, msg)
		}
}

// Send a TYPED payload under `tag` to `to_peer`. The POD bytes are framed once
// (no build-a-writer dance) and decoded by the matching session_app_listen.
session_app_send_typed :: proc(
	s: ^Session,
	tag: u8,
	msg: $T,
	to_peer: Peer_Id,
	channel: Channel = .Reliable,
) {
	#assert(
		intrinsics.type_is_nearly_simple_compare(T) &&
		!intrinsics.type_is_pointer(T) &&
		!intrinsics.type_is_multi_pointer(T),
		"session_app_send: the payload T must be POD (no strings, slices, maps, or pointers)",
	)
	#assert(size_of(T) <= APP_MESSAGE_MAX_BYTES, "typed app payload exceeds APP_MESSAGE_MAX_BYTES")
	m := msg
	w := session_app_begin(s, tag)
	append(&w.buf, ..(cast([^]u8)&m)[:size_of(T)])
	session_app_flush(s, to_peer, channel)
}

// Send a TYPED payload to a PLAYER — the seat-addressed twin of
// session_app_send_typed (resolves the seat→peer on the authority, like
// session_app_send_to), for a directed message: a whisper, a private reply.
// Host-only; a disconnected target or the host itself (no transport loopback) is
// dropped silently.
session_app_send_typed_to :: proc(
	s: ^Session,
	player: knet.Player_Id,
	tag: u8,
	msg: $T,
	channel: Channel = .Reliable,
) {
	#assert(
		intrinsics.type_is_nearly_simple_compare(T) &&
		!intrinsics.type_is_pointer(T) &&
		!intrinsics.type_is_multi_pointer(T),
		"session_app_send_typed_to: the payload T must be POD (no strings, slices, maps, or pointers)",
	)
	#assert(size_of(T) <= APP_MESSAGE_MAX_BYTES, "typed app payload exceeds APP_MESSAGE_MAX_BYTES")
	assert(s.is_host, "player-addressed sends resolve seats on the authority")
	p, ok := s.players[player]
	if !ok || !p.connected || p.id == s.me {
		return
	}
	m := msg
	w := session_app_begin(s, tag)
	append(&w.buf, ..(cast([^]u8)&m)[:size_of(T)])
	session_app_flush(s, p.peer, channel)
}

// Ship app payload bytes under `tag` — the one-call form when the payload
// already exists as a slice (begin/flush avoids the extra copy when you are
// building it anyway). Same channel rule as session_app_flush.
session_app_send :: proc(
	s: ^Session,
	to_peer: Peer_Id,
	tag: u8,
	bytes: []u8,
	channel: Channel = .Reliable,
) {
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

// Remote entities render this many NET TICKS in the past: almost always a
// bracketing sample pair, smooth through jitter and single drops. The default
// DERIVES from the configured rate (3 ticks = the old fixed 0.15s at the
// 20 Hz default) — a 60 Hz game used to inherit 9 ticks of needless latency,
// a 10 Hz game only 1.5 ticks of buffer (not even a stable pair).
DEFAULT_INTERP_TICKS :: 3.0

// The default adaptive ceiling (Session_Config.interp_delay_max = 0): 12 ticks =
// 0.6s at 20 Hz, which covers a ~1s-RTT link (rtt/2 = 0.5s) with jitter room to
// spare. A game on truly worse links raises it explicitly.
DEFAULT_INTERP_MAX_TICKS :: 12.0

// Predictions whose result never arrives revert after this long.
DEFAULT_COMMAND_TIMEOUT :: 3.0 // seconds — far beyond any sane RTT

// No WELCOME within this long of session_client_start -> Ev_Join_Failed
// (generous for a slow handshake, finite for a dead address; without it a
// failed join hangs on "Joining..." forever).
DEFAULT_JOIN_TIMEOUT :: 15.0 // seconds

// How often the designated backup host's snapshot refreshes.
DEFAULT_BACKUP_INTERVAL :: 5.0 // seconds

// NEW joins refused past this many present people (Deny_Reason.Full). This is
// a 2-8 friendslop framework: an unbounded lobby is a CHOICE a game states
// (max_players < 0), never an accident of the zero value — the old 0=unlimited
// default meant every game that never thought about it shipped uncapped.
DEFAULT_MAX_PLAYERS :: 8

// Every tunable the session bakes a time constant from, set ONCE before
// *_start via session_configure (like all pre-start wiring, it survives
// re-init). Zero-valued fields mean the defaults above — a zero config is the
// out-of-the-box session. All durations are SECONDS; the session converts to
// ticks itself, so changing tick_hz never silently rescales your timeouts.
Session_Config :: struct {
	tick_hz:          int, // net ticks per second (0 = knet.DEFAULT_TICK_HZ, 20)
	interp_delay:     f64, // how far in the past remote entities render
	// Adaptive interp delay (OFF by default — a set/default interp_delay keeps
	// meaning exactly what it does). When on, interp_delay SLEWS to track the
	// worst active link's need (rtt/2 + 2*jitter + margin) instead of holding one
	// number that can't serve both a LAN and a 120ms link: it GROWS promptly for
	// correctness headroom and SHRINKS slowly + hysteretically so it never shrinks
	// into a latency spike (see interp.odin). interp_delay above becomes the FLOOR
	// (adapting never renders fresher than you asked, and starts there);
	// interp_delay_max is the ceiling (0 = a generous kit default).
	interp_adapt:     bool,
	interp_delay_max: f64, // adaptive ceiling, seconds (0 = DEFAULT_INTERP_MAX_TICKS / hz)
	command_timeout:  f64, // prediction auto-revert horizon
	join_timeout:     f64, // client_start -> Ev_Join_Failed horizon
	backup_interval:  f64, // backup-host snapshot refresh cadence
	max_players:      int, // NEW joins refused past this many present people (0 = DEFAULT_MAX_PLAYERS, 8; negative = unlimited on purpose; rejoins always reclaim their seat)
	change_events:    bool, // emit Ev_Entity_Changed per dirty entity per tick (repaint THAT, not everything). Off by default: at friendslop scale repaint-everything is usually fine
	// Per-peer STREAM bandwidth cap, bytes per tick (0 = unlimited, the default).
	// When set, each peer receives only the highest-priority owner-stream updates
	// that fit — priority is STALENESS (ticks since that peer last got that
	// entity), so nothing starves, with distance as the tiebreak (near first).
	// The lever the O(entities x peers) send needs at scale; requires interest
	// management (session_set_interest) since only the per-peer routing it turns
	// on can budget a peer at all — a broadcast fans out through the relay whole.
	stream_budget:    int,
	// Authority-ingress token buckets. The reliable/stream limits apply to the
	// whole channel per transport peer; actions is the narrower per-player
	// command budget shared by co-op and simulation verbs. Zero disables a
	// dimension; named network profiles install bounded defaults.
	traffic:          Traffic_Config,
	fingerprint:      u64, // the build's WIRE CONTRACT hash. 0 (the default) =
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

// session_mix_fingerprint — fold a game's CONTENT contract into the wire
// fingerprint. The generated NET_FINGERPRINT hashes wire SHAPES (struct
// layouts, entity ids, verb signatures) but NOT a byte-keyed content table's
// VALUE mapping: an item id -> definition registry, a name -> id tag table,
// anything where "the wire byte is an index into game content". Reorder or
// rename such a table between builds and the join door still PASSES (the shapes
// match), then byte 7 decodes as the wrong thing on the receiving peer — a
// silent state scramble, the least debuggable failure a playtest produces.
//
// Fold the table's CANONICAL text in here and a drifted build is refused at the
// door as a .Version mismatch, exactly like a shape skew. Assign the result to
// Session_Config.fingerprint (before *_start):
//
//     cfg.fingerprint = ksession.session_mix_fingerprint(0, kitems.items_contract(&table))
//
// base = 0 means "the generated shape fingerprint" — the common case: you are
// ADDING your content to the default gate, not replacing it. (A bare
// `cfg.fingerprint = my_hash` would DROP the shape check entirely, since
// wire_fingerprint uses cfg.fingerprint INSTEAD of the default when nonzero.)
// Pass a nonzero base only to keep folding into a value you already composed.
//
// The string is hashed order-DEPENDENTLY (FNV-1a, the kit's stable-hash law);
// a table whose registration order is not itself meaningful must be
// canonicalized (sorted) by the caller first — see kitems.items_contract for
// the worked shape.
session_mix_fingerprint :: proc(base: u64, s: string) -> u64 {
	fp := base
	if fp == 0 {
		fp = default_net_fingerprint // add onto the generated shape hash, don't replace it
	}
	// FNV-1a over the bytes, seeded by the base (the kit's stable-hash law —
	// decl.fnv1a64 / knet.registry_state_hash; folded inline because both live in
	// packages this one need not import for one loop).
	for x in transmute([]u8)s {
		fp = (fp ~ u64(x)) * 0x100000001b3
	}
	// Never land on a sentinel: 0 = "use the default", FINGERPRINT_NONE = "gate
	// off". Either would silently turn a game's deliberate content-fold into the
	// opposite of what it asked for, so nudge off both.
	if fp == 0 || fp == FINGERPRINT_NONE {
		fp = 0x9E3779B97F4A7C15
	}
	return fp
}

// Everything a game wires BEFORE *_start, surviving every re-init: transport,
// factory, hooks, routes, config, tuning. The scope RULE, enforced by shape:
// a field here is never touched by the run teardown; a field in Session_Run
// dies wholesale at every re-init. New fields must pick a struct — there is
// no third place to leak from (the profile-table leak was a field parked in
// the wrong scope with a hand-maintained teardown list to forget it in).
Session_Wiring :: struct {
	// The allocator every ROOT reinstalls as context.allocator — the session's
	// tier of the kit's three-allocator rule (docs/kit/session.md, "The
	// allocator tiers"). kit/net's `_make` procs take an allocator EXPLICITLY;
	// kit/sim's Lane and this Session STORE one and rebind it at every entry;
	// comms/xfer/items/ui stay ambient. Zero (the default) adopts the caller's
	// context.allocator at the FIRST *_start — resolved in session_init and
	// kept across re-inits (Session_Wiring survives the run wipe), exactly as
	// the Lane adopts context.allocator at lane_init. Set it before *_start for
	// a custom allocator. Why STORED and not ambient: roster name clones,
	// profile rows, stat names, backup blobs, and the registry's per-entity
	// shadows are allocated from a dozen entry points but ALL freed in
	// run_destroy/session_destroy — a fully-ambient session was correct only
	// while context.allocator was IDENTICAL at init, at every packet, and at
	// destroy, the precise assumption kit/sim's Lane fix had to abandon (a
	// handler-side alloc and its teardown free rode different allocators).
	allocator:         mem.Allocator,
	send:              Send_Proc,
	send_user:         rawptr,
	drop_peer:         Drop_Peer_Proc,
	drop_peer_user:    rawptr,
	cfg:               Session_Config, // resolved into Session_Run at *_start
	traffic_hook:      Traffic_Hook,
	traffic_hook_user: rawptr,
	log_hook:          Production_Log_Hook,
	log_hook_user:     rawptr,

	// entity factory + command hooks
	factory_user:      rawptr,
	factory_make:      Make_Entity_Proc,
	factory_free:      Free_Entity_Proc,
	game_user:         rawptr, // session_set_game's explicit override (nil = the factory user)
	born_user:         rawptr,
	born:              Born_Proc, // host: its own spawns delivered at the send (nil = queued like every other peer's)
	cmd_hook_user:     rawptr,
	cmd_hook:          Command_Hook, // host: the cross-entity half of commands (the catch-all)
	type_hooks:        map[Entity_Type]Type_Hook_Entry, // host: per-type routing (wins over the catch-all)
	// Per-TYPE owner-stream rate (session_set_type_stream_hz): applied to
	// every insert of that type — the host's own spawn, a client's wire spawn,
	// the heir's resume rebuild — so the hint is a declaration, not a chore
	// each spawn site (and every takeover) has to remember. 0/absent = full rate.
	type_stream_hz:    map[Entity_Type]int,
	// Which entity TYPES are seats' bodies (session_set_avatar_type, from the
	// `entity=Runner:2,avatar` tag via kboot): the one fact a host takeover
	// needs to tell a PLAYER's parked body from the dead host's NPCs — see the
	// RE-OWN THE ORPHANS sweep in backup.odin.
	avatar_types:      map[Entity_Type]bool,

	// The write guard's extra exemption (session_set_guard_exempt): "this
	// entity's delta-lane divergence is legal right now". kboot.boot_lane
	// installs one that knows about the sim lane's in-flight verbs.
	guard_exempt:      knet.Guard_Exempt_Proc,
	guard_exempt_user: rawptr,

	// pre-start wiring: the game's blob writer rides every backup
	backup_blob_user:  rawptr,
	backup_blob:       Backup_Blob_Proc,

	// app-message routes (kit/comms and friends)
	app:               [MAX_APP_TAGS]App_Route,
	app_w:             knet.Writer, // scratch for session_app_begin/flush (reused per message)

	// interest management (interest.odin) — off until session_set_interest
	interest_r:        f32,
	interest_hys:      f32,
	interest_user:     rawptr,
	locator:           Locator_Proc,

	// The profile table's WIRING half (profile.odin): the installed row size.
	// The rows themselves are run state — session_init re-seeds prof.size
	// from this after the wipe.
	prof_size:         int,
	// MY row as written BEFORE I held a seat (session_profile_mine while
	// unseated — a lobby pick before hosting/joining): parked here, outside
	// the run, and moved under my seat id at host_start / welcome (prof_seat).
	prof_pending:      []u8,

	// our reconnect secret (the game persists it across runs; every *_start
	// reassigns it, and a resumed host relies on it surviving the re-init)
	token:             u64,
}

// Everything one RUN creates. Reset is wholesale — run_destroy frees the owned
// containers, then `s.run = {}` zeroes every field at once, so a new field
// can never leak stale state across a rehost by being missed in a list.
Session_Run :: struct {
	is_host:         bool,
	dedicated:       bool, // this authority is a DEDICATED SERVER: its seat is
	// infrastructure (see Player.dedicated) and succession never arms — a
	// dead server restarts, it does not migrate (the token/backup machinery
	// belongs to the friends-host-for-friends peer model).
	me:              knet.Player_Id,
	players:         map[knet.Player_Id]Player,
	events:          [dynamic]Event,

	// resolved from cfg at *_start (read these, not cfg, mid-run)
	tick_hz:         int,
	pending_max_age: u64, // ticks
	join_timeout:    int, // ticks
	interp_delay:    f64,
	interp_adapt:    bool, // resolved: is the adaptive slew on?
	adapt:           Interp_Adapt, // adaptive interp-delay controller (interp.odin) — inert when interp_adapt is false
	backup_every:    u64, // net ticks between backup refreshes (default 100 = 5s)

	// the replicated world (kit/net): the session drives the per-tick walks
	reg:             knet.Registry,
	ctx:             knet.Command_Ctx,
	ticker:          knet.Ticker,
	clocks:          map[Peer_Id]knet.Clock_Sync, // per transport peer, fed by ping/pong
	pongs:           int, // pong samples applied (games gate "clock is warm" on this)
	malformed:       u64, // session packets dropped mid-parse (truncation, corruption, a foreign build past the fingerprint) — counted, never silent; netgraph's `drop` reads it
	// The write guard's RELEASE voice (see session_tick): where -disable-assert
	// strips the teaching assert, rogue client writes count here and log ONCE
	// instead of going dark. Stays zero in dev builds — the assert fires first.
	guard_hits:      u64,
	guard_logged:    bool,
	traffic:         map[knet.Player_Id]Traffic_Seat,
	traffic_dropped: u64,
	authority_action_seen: map[Authority_Action_Key]knet.Dedup_Window,
	authority_ingress:     Authority_Ingress_Stats,
	log_window:            f64,
	log_emitted:           int,
	log_dropped:           u64,
	log_ready:             bool,
	now:             f64, // the game's monotonic seconds, updated each session_tick
	replicating:     bool, // host: the world is LIVE (deltas flow; joiners get SES_WORLD)
	later:           knet.Later, // session_present's queue — drained every session_tick

	// entity types
	types:           map[knet.Net_Id]Entity_Type, // host: for (re-)announcing spawns
	unsent:          map[knet.Net_Id]u64, // host: spawn_make'd, spawn_send still owed (tick-stamped)

	// The per-player PROFILE table (profile.odin): one POD row per seat,
	// owner-authored, host-relayed. Run state — a rehost must not relay a
	// dead run's rows under recycled Player_Ids, and a surviving declare
	// shadow would keep an unchanged client's row invisible to a NEW host.
	// The ONE keeper is session_host_resume (keep_profiles): the heir's
	// table IS the resumed lobby.
	prof:            Profile_Table,

	// the stat registry (host accumulates; everyone reads)
	stat_names:      [dynamic]string, // owned; index = column
	stats:           map[knet.Player_Id][MAX_STAT_COLS]i64,
	stats_dirty:     bool, // host: snapshot goes out on the next low-rate tick

	// backup hosting (migration-readiness): the host periodically ships a
	// complete re-hostable snapshot to the ELDEST connected client
	backup_tick:     u64, // host: when the last one shipped
	backup_target:   knet.Player_Id, // host: who holds it
	backup:          []u8, // client: the latest payload (opaque; owned; split via session_backup_parts)
	backup_at:       f64, // client: when it arrived (session now)

	// SUCCESSION (live migration): the host names the backup holder and how
	// to reach them BEFORE dying; every peer holds the answer when the
	// lights go out.
	succ_info:       []u8, // host: the game's transport rendezvous blob (owned)
	successor:       knet.Player_Id, // client: who carries the torch
	successor_info:  []u8, // client: how to find them (owned; see session_successor)

	// host bookkeeping
	next_player:     knet.Player_Id,
	tokens:          map[u64]knet.Player_Id, // reconnect identity, forever
	by_peer:         map[Peer_Id]knet.Player_Id,
	denied:          map[u64]knet.Player_Id, // banned token hashes -> who they were (run-scoped)
	locked:          bool, // host: new joins refused (rejoins still reclaim their seat)

	// client bookkeeping
	spectate:        bool, // client: this seat joins to WATCH (session_client_start's flag; rides SES_JOIN)
	name:            string, // owned; the name we asked for
	joined:          bool, // WELCOME received
	join_waited:     int, // ticks since client_start without a WELCOME (-1 = not waiting; session_init disarms)

	// interest run state (interest.odin)
	focus:           map[knet.Player_Id][3]f32, // host: each peer's eyes (z = 0 for 2D games)
	interest:        map[Interest_Key]bool, // host: (player, entity) pairs currently near
	// bandwidth budget (interest.odin): the tick each (peer, entity) last had a
	// stream update sent, and its distance² from that peer's focus — the two
	// inputs the per-peer stream budget prioritizes by (staleness, then near).
	stream_sent:     map[Interest_Key]u64,
	interest_d2:     map[Interest_Key]f32,
	aoi_client:      bool, // client: the host declared AOI filtering (all client
	// streams route through the host authority gateway)
}

Session :: struct {
	using wiring: Session_Wiring,
	using run:    Session_Run,
	ran:          bool, // session_init completed at least once — gates the re-entrant teardown
	// REPLAY recording (session_record_start): every packet this session HANDLES,
	// framed with its arrival time and peer, appended here. A direct Session field
	// (not run-scoped) because the game drives it explicitly across a run's life —
	// run_destroy must not wipe a capture the game is still taking. Lazily made.
	record:       knet.Writer,
	recording:    bool,
}

// The session's stored allocator, or the caller's ambient when it is not yet
// resolved (a root reached before the first *_start — session_present's
// pre-start lobby flourish). Every allocating/freeing ROOT opens with
// `context.allocator = ses_allocator(s)` so a container filled from one entry
// point (a packet handler, a tick) and freed from another (run_destroy) can
// never ride two allocators — the stored-and-rebound tier kit/sim's Lane
// proved. Installing context.allocator is frame-local, so this CANNOT be a
// proc that sets it for the caller; it returns the value each root installs.
@(private)
ses_allocator :: proc(s: ^Session) -> mem.Allocator {
	return s.allocator.procedure != nil ? s.allocator : context.allocator
}

// Free every owned container one run creates — the ONE list a new run-scoped
// container field must join (a missed line leaks memory; it can never leak
// stale STATE — `s.run = {}` wipes every field wholesale, listed or not).
// Shared by session_init's re-entrant teardown and session_destroy.
@(private = "file")
run_destroy :: proc(run: ^Session_Run) {
	knet.registry_destroy(&run.reg)
	knet.command_ctx_destroy(&run.ctx)
	for _, p in run.players {
		delete(p.name)
	}
	delete(run.players)
	delete(run.events)
	delete(run.tokens)
	delete(run.by_peer)
	delete(run.traffic)
	delete(run.authority_action_seen)
	delete(run.denied)
	delete(run.clocks)
	delete(run.types)
	delete(run.unsent)
	for n in run.stat_names {
		delete(n)
	}
	delete(run.stat_names)
	delete(run.stats)
	delete(run.focus)
	delete(run.interest)
	delete(run.stream_sent)
	delete(run.interest_d2)
	delete(run.backup)
	delete(run.succ_info)
	delete(run.successor_info)
	delete(run.name)
	prof_destroy(&run.prof)
	knet.later_destroy(&run.later)
}

@(private) // backup.odin's session_host_resume re-inits through here too
session_init :: proc(s: ^Session, keep_profiles := false) {
	// RE-ENTRANT: host_start / client_start / host_resume may run on a
	// session that already ran (back to lobby -> rehost, host after a failed
	// join). The previous RUN dies wholesale — run_destroy frees, `s.run = {}`
	// zeroes — while everything a game wires BEFORE start (Session_Wiring:
	// transport, factory, hooks, app routes, tuning) is untouchable by
	// construction. Pending presentations are dropped even on a FIRST start:
	// session_present can legally run before any *_start (a lobby flourish),
	// and those queued against a zero clock must not fire into the new run.
	//
	// Tier C→B: resolve and install the session's allocator FIRST, so the
	// re-entrant teardown below frees the dead run under the allocator that
	// built it, and every container this init creates (registry, ctx,
	// stat_names, the app writer) rides it too. Zero adopts the caller's
	// ambient ONCE, at the first *_start; a rehost keeps the resolved value
	// (Session_Wiring survives the wipe). See Session_Wiring.allocator.
	if s.allocator.procedure == nil {
		s.allocator = context.allocator
	}
	assert(
		traffic_config_valid(s.cfg.traffic),
		"Session_Config.traffic packet rates, byte rates, and burst_seconds cannot be negative",
	)
	context.allocator = s.allocator
	knet.later_clear(&s.later)
	// `ran` (not a side effect like stat_names) gates the teardown: a FAILED
	// host_resume leaves stat_names empty but the roster/tokens/registry
	// partially populated — judging by a side effect would skip the teardown
	// exactly then, leaking the dead run's players into the next one.
	if s.ran {
		// keep_profiles is session_host_resume's flag: the heir's table IS
		// the resumed lobby (every peer holds the whole table — that's what
		// makes succession free). Lift it out of the wipe, put it back
		// dirty, so it re-relays at the next stats cadence instead of
		// waiting on re-declares that would never come.
		kept: Profile_Table
		if keep_profiles {
			kept = s.prof
			s.prof = {}
		}
		run_destroy(&s.run)
		s.run = {}
		if keep_profiles {
			s.prof = kept
			s.prof.dirty = true
		}
	}
	// Non-zero ground state the wholesale wipe can't express:
	s.join_waited = -1 // the join-timeout clock is DISARMED (0 would be armed-at-tick-0)
	s.prof.size = s.prof_size // re-seed the wiring half of the profile table
	// Resolve the config (zero fields = defaults). Durations are configured in
	// seconds and baked to tick counts HERE, against the configured rate.
	s.tick_hz = s.cfg.tick_hz > 0 ? s.cfg.tick_hz : knet.DEFAULT_TICK_HZ
	hz := f64(s.tick_hz)
	s.interp_delay = s.cfg.interp_delay > 0 ? s.cfg.interp_delay : DEFAULT_INTERP_TICKS / hz
	// Adaptive interp delay (opt-in): the resolved interp_delay above is the FLOOR
	// (and the starting value); the ceiling defaults generously. When off, the
	// controller is never stepped and interp_delay stays exactly this constant.
	s.interp_adapt = s.cfg.interp_adapt
	if s.interp_adapt {
		ceiling :=
			s.cfg.interp_delay_max > 0 ? s.cfg.interp_delay_max : DEFAULT_INTERP_MAX_TICKS / hz
		interp_adapt_reset(&s.adapt, s.interp_delay, ceiling)
	}
	s.pending_max_age = u64(
		(s.cfg.command_timeout > 0 ? s.cfg.command_timeout : DEFAULT_COMMAND_TIMEOUT) * hz,
	)
	s.join_timeout = int((s.cfg.join_timeout > 0 ? s.cfg.join_timeout : DEFAULT_JOIN_TIMEOUT) * hz)
	s.backup_every = u64(
		(s.cfg.backup_interval > 0 ? s.cfg.backup_interval : DEFAULT_BACKUP_INTERVAL) * hz,
	)

	s.reg = knet.registry_make()
	s.ctx = knet.command_ctx_make()
	s.ticker = knet.ticker_make(s.tick_hz)
	s.traffic = make(map[knet.Player_Id]Traffic_Seat)
	s.authority_action_seen = make(map[Authority_Action_Key]knet.Dedup_Window)
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

// End the current run while retaining the pre-start wiring: transport/factory
// hooks, action routes, profiles, configuration, and the resolved allocator.
// This is the back-to-menu reset used by the generated game-network facade.
// The next host/client start rebuilds a fresh run and registry from that wiring.
// Idempotent; unlike session_destroy, this Session remains reusable.
session_reset :: proc(s: ^Session) {
	context.allocator = ses_allocator(s)
	run_destroy(&s.run)
	s.run = {}
	s.join_waited = -1
	s.prof.size = s.prof_size
	s.ran = false
}

session_destroy :: proc(s: ^Session) {
	context.allocator = ses_allocator(s) // free every run + wiring container under what built it
	session_reset(s)
	// The wiring's own two containers (everything else there is procs,
	// pointers, and plain values):
	delete(s.type_hooks)
	delete(s.type_stream_hz)
	delete(s.avatar_types)
	delete(s.prof_pending)
	knet.writer_destroy(&s.app_w)
	knet.writer_destroy(&s.record) // the replay capture (nil-safe if never recorded)
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

// Where adaptive interp delay is HEADED — the last-computed target the slew is
// converging on (Session_Config.interp_adapt). Equals session_interp_delay when
// not adapting (or once converged); a persistent gap between the two is the
// controller mid-slew (worth a netgraph row — a target riding the ceiling means
// the link outgrew the cap). Zero before *_start.
session_interp_target :: proc(s: ^Session) -> f64 {
	return s.interp_adapt ? s.adapt.target : s.interp_delay
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
session_present :: proc(
	s: ^Session,
	mine: bool,
	user: rawptr,
	cb: knet.Later_Proc,
	id := knet.NET_ID_INVALID,
	a := u64(0),
	extra := 0.0,
) {
	context.allocator = ses_allocator(s) // the later queue is the session's (guarded: a pre-start present rides ambient, dropped at init)
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

// Install the transport half of an automatic traffic-policy kick. netgd uses
// a deferred close so the target receives SES_KICKED before its socket dies.
// A custom transport may omit this: the seat is still revoked immediately.
session_set_peer_drop :: proc(s: ^Session, user: rawptr, drop: Drop_Peer_Proc) {
	s.drop_peer = drop
	s.drop_peer_user = user
}

// Install a production-safe structured log sink. Records contain only fixed
// enums, ids, sizes, and counters; the kit emits at most 16 per second per
// session and counts the rest instead of allocating or forwarding remote text.
session_set_production_log_hook :: proc(
	s: ^Session,
	user: rawptr,
	hook: Production_Log_Hook,
) {
	s.log_hook_user = user
	s.log_hook = hook
}

session_production_log_dropped :: proc(s: ^Session) -> u64 {
	return s.log_dropped
}

@(private)
session_production_log :: proc(s: ^Session, record: Production_Log_Record) {
	if s.log_hook == nil {
		return
	}
	if !s.log_ready || s.now < s.log_window || s.now - s.log_window >= 1.0 {
		s.log_window = s.now
		s.log_emitted = 0
		s.log_ready = true
	}
	if s.log_emitted >= PRODUCTION_LOG_EVENTS_PER_SECOND {
		s.log_dropped += 1
		return
	}
	s.log_emitted += 1
	s.log_hook(s.log_hook_user, record)
}

// Install the write guard's extra exemption (see registry_write_guard) —
// pre-start wiring like the transport/factory installers. kboot.boot_lane
// installs the sim lane's ("a tick-scheduled verb is in flight on this
// entity"); games without a lane never need one.
session_set_guard_exempt :: proc(s: ^Session, user: rawptr, exempt: knet.Guard_Exempt_Proc) {
	s.guard_exempt = exempt
	s.guard_exempt_user = user
}

// Install the client-side entity factory (do it before joining). The factory's
// `user` doubles as THE game pointer — what every `<verb>_then` consequence
// proc receives as its game param — unless session_set_game named a different
// one (kboot's boot_entities does: its factory user is the Boot, so it names
// the game explicitly). Survives starts via session_init's re-install.
session_set_factory :: proc(
	s: ^Session,
	user: rawptr,
	make_entity: Make_Entity_Proc,
	free_entity: Free_Entity_Proc,
) {
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

// Install the authority's born hook (see Born_Proc; pre-start wiring, survives
// starts). With it installed, session_spawn / session_spawn_send deliver the
// host's own Ev_Spawned to `born` synchronously and queue NOTHING for that
// spawn — a poll loop never sees it. nil restores the queue.
session_set_born :: proc(s: ^Session, user: rawptr, born: Born_Proc) {
	s.born_user = user
	s.born = born
}

// The authority's spawn is BORN: fields set, announced — hand it to the born
// hook this instant, or queue it for the poll like every other peer's.
@(private = "file")
born_or_queued :: proc(s: ^Session, ev: Ev_Spawned) {
	if s.born != nil {
		s.born(s.born_user, ev)
		return
	}
	append(&s.events, ev)
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
	// The zero-map class the tracking pin caught three times over (focus,
	// stats, interest): a map SELF-CARRIES its creation allocator, so the FIRST
	// insert silently decides where the whole table lives — and this table is
	// WIRING, freed by session_destroy under the session's allocator. Created on
	// a caller's ambient and freed on the session's own is the cross-allocator
	// pairing tier B exists to prevent. Pre-start this is a no-op (ses_allocator
	// falls back to ambient until session_init resolves one), which is exactly
	// why it costs nothing to be right.
	context.allocator = ses_allocator(s)
	s.type_hooks[type] = Type_Hook_Entry {
		user = user,
		hook = hook,
	}
	s.ctx.hook = ctx_hook_dispatch
	s.ctx.hook_user = s
}

// The one place every executed command's hook fires — the host's own local
// issues (via ctx) and the clients' (the SES_CMD handler) both land here.
@(private = "file")
session_dispatch_hook :: proc(
	s: ^Session,
	player: knet.Player_Id,
	entity: knet.Net_Id,
	cmd: u16,
	ok: bool,
) {
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
ctx_hook_dispatch :: proc(
	user: rawptr,
	player: knet.Player_Id,
	entity: knet.Net_Id,
	cmd: u16,
	ok: bool,
) {
	session_dispatch_hook(cast(^Session)user, player, entity, cmd, ok)
}

// One game-facing result vocabulary for immediate and scheduled actions.
// kit/sim calls these after its frame-safe settle; the immediate session loop
// calls them after truth/revert application. Games consume the ordinary
// generated `_command_confirmed` / `_command_rejected` halves and never need to
// know which packet lane carried the action.
session_action_executed :: proc(
	s: ^Session,
	model: knet.Action_Model,
	seq: u32,
	player: knet.Player_Id,
	entity: knet.Net_Id,
	cmd: u16,
	reason: knet.Action_Reject_Reason,
) {
	append(
		&s.events,
		Ev_Command_Executed {
			ok = reason == .None,
			reason = reason,
			model = model,
			seq = knet.Intent_Seq(seq),
			player = player,
			entity = entity,
			cmd = cmd,
		},
	)
}

session_action_resolved :: proc(
	s: ^Session,
	model: knet.Action_Model,
	seq: u32,
	entity: knet.Net_Id,
	cmd: u16,
	reason: knet.Action_Reject_Reason,
) {
	if reason == .None {
		append(
			&s.events,
			Ev_Command_Confirmed {
				seq = knet.Intent_Seq(seq),
				entity = entity,
				cmd = cmd,
				model = model,
			},
		)
		return
	}
	append(
		&s.events,
		Ev_Command_Rejected {
			seq = knet.Intent_Seq(seq),
			entity = entity,
			cmd = cmd,
			model = model,
			reason = reason,
		},
	)
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
	session_send_packet(s, HOST_PEER, knet.writer_bytes(&w), .Reliable)
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
session_spawn :: proc(
	s: ^Session,
	type: Entity_Type,
	entity: rawptr,
	set: ^knet.Command_Set,
	owner := knet.PLAYER_ID_INVALID,
) -> knet.Net_Id {
	assert(s.is_host, "only the authority spawns; clients create via the factory")
	context.allocator = ses_allocator(s) // the registry's per-entity shadows free in run_destroy — allocate them there too (a spawn from a lane tick runs under l.allocator otherwise)
	id := knet.registry_spawn(&s.reg, entity, set, owner)
	s.types[id] = type
	apply_type_stream_hz(s, id, type)
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_SPAWN)
		write_spawn_tuple(s, &w, id)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
	born_or_queued(s, Ev_Spawned{id = id, type = type, owner = owner}) // pre-filled entity: born now
	return id
}

// Host: spawn THROUGH THE FACTORY — the same Make_Entity_Proc clients run,
// so every entity type's creation is written exactly once. Two-phase because
// the spawn announcement carries a field snapshot: make, set your per-spawn
// fields on the returned entity, then session_spawn_send — which is where
// Ev_Spawned fires (the entity is BORN once its fields are set; an event at
// make time would hand the game an empty shell). Fires INTO the born hook
// when one is installed (session_set_born), queued otherwise.
session_spawn_make :: proc(
	s: ^Session,
	type: Entity_Type,
	owner := knet.PLAYER_ID_INVALID,
) -> (
	entity: rawptr,
	id: knet.Net_Id,
) {
	assert(s.is_host, "only the authority spawns; clients create via the factory")
	assert(s.factory_make != nil, "session_spawn_make needs session_set_factory")
	context.allocator = ses_allocator(s) // registry_insert's shadow/edge_shadow ride the stored allocator (see session_spawn)
	id = knet.registry_alloc_id(&s.reg)
	set: ^knet.Command_Set
	entity, set = s.factory_make(s.factory_user, type, id, owner)
	assert(entity != nil, "the factory returned nil for a host-side spawn")
	knet.registry_insert(&s.reg, id, entity, set, owner)
	s.types[id] = type
	apply_type_stream_hz(s, id, type)
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
	context.allocator = ses_allocator(s) // the spawn pair's second half rebinds like the first
	delete_key(&s.unsent, id) // the owed send arrived
	if s.replicating {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_SPAWN)
		write_spawn_tuple(s, &w, id)
		broadcast(s, knet.writer_bytes(&w), .Reliable)
	}
	if e, ok := knet.registry_get(&s.reg, id); ok {
		// BORN — here, not at make: the fields are set and on the wire. With a
		// born hook installed this fires the game's dress before this call
		// returns (no engine callback can see the authority's node undressed);
		// without one it queues for the poll like any peer's.
		born_or_queued(s, Ev_Spawned{id = id, type = s.types[id], owner = e.owner})
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
// not replicated — a per-id ONE-OFF: it must be re-applied after a host
// migration, like interest. A kind's standing rate is DECLARED instead
// (session_set_type_stream_hz below / the `entity=Mob:3,stream_hz=30` tag),
// which every insert on every peer honors, takeovers included.
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

// The DECLARED form of session_set_stream_hz: every entity of `type` streams
// at `hz` from the moment it is inserted — the host's own spawn, a client's
// wire spawn, the heir's resume rebuild. Pre-start wiring (survives re-init
// like the factory); kboot.boot_entities installs it from the generated kind
// table (`gd:"entity=Mob:3,stream_hz=30"`), so a game never re-applies the
// hint by hand and a takeover can't silently drop it. The per-id call above
// still works for a one-off (a boss, a carried object) and wins by being
// later. 0 = full rate (clears a previous declaration).
session_set_type_stream_hz :: proc(s: ^Session, type: Entity_Type, hz: int) {
	context.allocator = ses_allocator(s) // wiring map: created and freed under the session's own (the zero-map rule, session_set_type_hook)
	if hz <= 0 {
		delete_key(&s.type_stream_hz, type)
		return
	}
	s.type_stream_hz[type] = hz
}

// Declare `type` a SEAT'S BODY (an avatar) — or not. Pre-start wiring, from
// the `entity=Runner:2,avatar` tag through kboot.boot_entities. The session
// reads it in exactly one place: a host takeover's orphan sweep (backup.odin)
// PARKS avatar entities with their departed seat — owner unchanged, so the
// token holder who dials back in reseats AND re-embodies the body it left
// standing — and adopts everything else the dead host owned (its NPCs, its
// world) to the heir so they keep living. Without the declaration every
// orphan is adopted, avatars included, and a returning former host finds its
// body owned by the heir (the regression scrapyard's succ_fixups used to
// patch game-side, keyed on a spawn-time owner map the census no longer keeps).
session_set_avatar_type :: proc(s: ^Session, type: Entity_Type, avatar: bool) {
	context.allocator = ses_allocator(s) // wiring map (the zero-map rule, session_set_type_hook)
	if avatar {
		s.avatar_types[type] = true
	} else {
		delete_key(&s.avatar_types, type)
	}
}

// Is `type` a declared avatar kind?
session_is_avatar_type :: proc(s: ^Session, type: Entity_Type) -> bool {
	return s.avatar_types[type]
}

@(private = "file")
apply_type_stream_hz :: proc(s: ^Session, id: knet.Net_Id, type: Entity_Type) {
	if hz, declared := s.type_stream_hz[type]; declared {
		session_set_stream_hz(s, id, hz)
	}
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
	context.allocator = ses_allocator(s) // registry_set_owner reseeds the stream ring under the stored allocator
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

// PREDICTED OWNERSHIP TRANSFER — the client half of carrying/striking/possessing
// a shared object. Owner-streamed fields are the current owner's to write, so a
// non-owner's write to them is stomped by stream sampling every frame until the
// host transfers ownership — a full round trip during which the pickup shows
// nothing. Call this the moment you REQUEST the transfer (issue your predicted
// command) and write the fields you want (the ball's velocity, the prop's pose):
// they hold locally at once, so the action shows now. When the host confirms and
// the transfer lands on you, those fields become the streamed truth (no re-apply
// — the scratch-and-re-raise dance every pass-the-object game hand-rolled is
// gone). If the request is DENIED, clear it (predicting=false): the entity
// resumes sampling and snaps back to the true owner. Host-authoritative deltas
// are unaffected — this is only the owner-stream lane.
session_predict_owner :: proc(s: ^Session, id: knet.Net_Id, predicting := true) {
	knet.registry_predict_owner(&s.reg, id, predicting)
}

// Whether this peer is currently predicting ownership of `id` (see
// session_predict_owner). Cleared automatically when the real transfer lands.
session_predicting_owner :: proc(s: ^Session, id: knet.Net_Id) -> bool {
	if e, ok := knet.registry_get(&s.reg, id); ok {
		return e.predict_owner
	}
	return false
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
	assert(
		len(data) <= knet.ENTITY_BLOB_MAX_BYTES,
		"entity blob exceeds ENTITY_BLOB_MAX_BYTES — use kit/xfer for bulk payloads",
	)
	context.allocator = ses_allocator(s) // the blob copy frees in registry_remove/destroy under the stored allocator — make it there
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
	context.allocator = ses_allocator(s) // registry_remove frees the entry's shadow/blob/edge/ring — under the allocator that made them (see session_spawn)
	entity: rawptr
	if e, ok := knet.registry_get(&s.reg, id); ok {
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
	context.allocator = ses_allocator(s) // commit_shadows may allocate a missing entity's shadow — on the stored allocator
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
	assert(n <= knet.MAX_REPLICATED_ENTITY_BYTES)
	knet.write_u16(w, u16(n))
	knet.write_full(w, e.entity, e.set.entity_desc)
	knet.write_u32(w, e.blob_ver)
	assert(len(e.blob) <= knet.ENTITY_BLOB_MAX_BYTES)
	knet.write_u32(w, u32(len(e.blob)))
	append(&w.buf, ..e.blob)
}

@(private = "file")
send_world :: proc(s: ^Session, peer: Peer_Id) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_WORLD)
	assert(knet.registry_count(&s.reg) <= int(max(u16)))
	assert(knet.registry_count(&s.reg) <= knet.MAX_CONTAINER_ITEMS)
	knet.write_u16(&w, u16(knet.registry_count(&s.reg)))
	for id in s.types {
		write_spawn_tuple(s, &w, id)
	}
	session_send_packet(s, peer, knet.writer_bytes(&w), .Reliable)
}

@(private)
spawn_tuple_probe :: proc(r: ^knet.Reader) -> bool {
	_ = knet.read_u16(r) // type
	_ = knet.read_net_id(r)
	_ = knet.read_player_id(r)
	n := int(knet.read_u16(r))
	if r.err || n > knet.MAX_REPLICATED_ENTITY_BYTES {
		r.err = true
		return false
	}
	_ = knet.reader_view(r, n)
	_ = knet.read_u32(r) // blob version
	blob_n := int(knet.read_u32(r))
	if r.err || blob_n < 0 || blob_n > knet.ENTITY_BLOB_MAX_BYTES {
		r.err = true
		return false
	}
	_ = knet.reader_view(r, blob_n)
	return !r.err
}

// Client: one incoming spawn tuple — factory-create (or reconcile onto an
// entity we already have: a same-session rejoin re-receives the world), apply
// the snapshot, event. Unknown types skip by length.
@(private) // backup.odin's session_host_resume replays these too
apply_spawn_tuple :: proc(s: ^Session, r: ^knet.Reader) {
	type := Entity_Type(knet.read_u16(r))
	id := knet.read_net_id(r)
	owner := knet.read_player_id(r)
	n := int(knet.read_u16(r))
	if r.err || n > knet.MAX_REPLICATED_ENTITY_BYTES {
		r.err = true
		return
	}
	body_bytes := knet.reader_view(r, n)
	body := knet.reader_make(body_bytes)

	// The blob section is consumed up front — every early-out below (already
	// known, no factory, unknown type) must leave the reader past this tuple.
	blob_ver := knet.read_u32(r)
	blob_n := int(knet.read_u32(r))
	if r.err || blob_n < 0 || blob_n > knet.ENTITY_BLOB_MAX_BYTES { 	// <0: 32-bit wrap on hostile lengths
		r.err = true
		return
	}
	blob := knet.reader_view(r, blob_n)

	if e, exists := knet.registry_get(&s.reg, id); exists {
		if n != knet.desc_wire_size(e.set.entity_desc) {
			r.err = true
			return
		}
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
	if n != knet.desc_wire_size(set.entity_desc) {
		if s.factory_free != nil {
			s.factory_free(s.factory_user, id, entity)
		}
		r.err = true
		return
	}
	knet.registry_insert(&s.reg, id, entity, set, owner)
	s.types[id] = type
	apply_type_stream_hz(s, id, type)
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
	context.allocator = ses_allocator(s) // net_tick, prof/stats/backup, the registry walks, later_drain, edges — all one allocator
	s.now = now
	ticks = knet.ticker_advance(&s.ticker, dt)
	for _ in 0 ..< ticks {
		net_tick(s)
	}
	// Adaptive interp delay (opt-in, interp.odin): slew interp_delay toward the
	// worst active link's need BEFORE this frame samples the streams against it.
	// The need reads the SAME per-peer ClockSync rtt/jitter the ping stat and the
	// sim-lane cold-start lead already use — no second estimator. Off = the field
	// is untouched and stays the resolved constant.
	if s.interp_adapt {
		want := 0.0
		for _, c in s.clocks {
			if !c.initialized {
				continue
			}
			if need := c.rtt * 0.5 + c.jitter * 2.0; need > want {
				want = need
			}
		}
		s.interp_delay = interp_adapt_update(&s.adapt, want, dt)
	}
	sampled = knet.registry_sample_streams(&s.reg, now - s.interp_delay, s.me)
	// The delta-lane WRITE GUARD (kit/net registry.odin): on a client, a
	// host-lane field that moved outside the framework since its last bless
	// is a local rogue write — the canonical silent-divergence bug, named
	// within one net tick instead of never. Costs the host's own diff walk.
	// Dev builds HALT on it (the teaching assert); a `-disable-assert` build
	// keeps the walk and the name but not the halt — it counts (guard_hits,
	// session_guard_hits) and says the first one ONCE, because a shipped
	// build re-opening the exact divergence class this guard was built to
	// kill is worse than the walk it saves.
	if ticks > 0 && !s.is_host {
		if cls, field, id, found := knet.registry_write_guard(
			&s.reg,
			&s.ctx,
			s.guard_exempt,
			s.guard_exempt_user,
		); found {
			when !ODIN_DISABLE_ASSERT {
				assert(
					false,
					fmt.tprintf(
						"WRITE GUARD: %s.%s (net id %d) changed on a CLIENT outside the framework — " +
						"host-lane replicated fields are the authority's to write; a client's local write never replicates (it silently diverges). " +
						"Route the change through a verb (`<verb>_cmd`) or compute it on the authority (`_then` / an authority step); " +
						"presentation belongs in halves, not in replicated fields.",
						cls,
						field,
						u32(id),
					),
				)
			} else {
				s.guard_hits += 1
				if !s.guard_logged {
					s.guard_logged = true
					// Native only: the wasm fmt has no stdio — the counter
					// still counts there, the once-line just stays quiet.
					when ODIN_OS != .Freestanding {
						fmt.printfln(
							"kit/session WRITE GUARD: %s.%s (net id %d) changed on a client outside the framework — logged once; session_guard_hits counts from here",
							cls,
							field,
							u32(id),
						)
					}
				}
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
	context.allocator = ses_allocator(s) // a standalone edge pass rebinds like session_tick (the halves are game code on the session's stack)
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
				fmt.tprintf(
					"entity %d (type %d) was session_spawn_make'd but never session_spawn_send'd — the pair is make, set fields, send (same frame)",
					u32(id),
					u16(s.types[id]),
				),
			)
		}
	}

	if !s.is_host && !s.joined && s.join_waited >= 0 {
		s.join_waited += 1
		if s.join_waited > s.join_timeout {
			s.join_waited = -1
			append(&s.events, Ev_Join_Failed{reason = .Timeout})
			session_production_log(s, Production_Log_Record {
				kind = .Disconnected, disconnect = .Timeout, peer = HOST_PEER,
			})
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
	// (a drop is superseded by the next tick's snapshot). Every client sends to
	// the HOST first: only it can resolve transport peer → player → authoritative
	// ownership, so it is the one enforceable admission point. The physical ENet
	// topology already relays through that machine; this merely makes the relay
	// explicit. The host fans out whole batches normally and AOI-splits them
	// when interest is enabled.
	{
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_STREAM)
		// The authority keeps its OWN streams' history too (keep_history): that
		// is what lets session_rewound wind a host-owned body back to what a
		// client's screen was drawing — the hole coop lag comp used to leave.
		if knet.registry_write_streams(&w, &s.reg, s.me, s.now, t, keep_history = s.is_host) > 0 {
			if interest_on(s) {
				interest_route_streams(s, knet.writer_bytes(&w)[1:], 0, t)
			} else if !s.is_host {
				session_send_packet(s, HOST_PEER, knet.writer_bytes(&w), .Stream)
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
					session_send_packet(s, p.peer, knet.writer_bytes(&w), .Reliable)
				}
			}
		} else {
			session_send_packet(s, HOST_PEER, knet.writer_bytes(&w), .Reliable)
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
		// The profile relay (profile.odin): a landed declare goes out at the
		// same lobby-alive cadence stats do.
		if s.prof.dirty {
			s.prof.dirty = false
			prof_send(s)
		}
		// Backup hosting (backup.odin): target election + snapshot refresh.
		backup_slot(s, t)
	}

	// The profile auto-declare (profile.odin), every role: my row's changes
	// ship themselves — there is no "remember to declare" call to forget.
	prof_tick(s)

	// Loud auto-revert: a silent host must read as "no" — and the rejection
	// carries the REAL seq/entity so UI keyed on either matches the timeout
	// path just like the explicit-reject path.
	expired := make([dynamic]knet.Expired_Command, context.temp_allocator)
	if knet.registry_expire_pending(&s.reg, &s.ctx, s.pending_max_age, s.me, &expired) > 0 {
		for x in expired {
			session_action_resolved(s, .Immediate, u32(x.seq), x.entity, x.cmd, .Timeout)
		}
	}
}

// Transport-level "everyone but me". World traffic uses this — only the HOST
// knows other players' transport peers, but any peer may own streamed
// entities. Roster messages stay host-targeted (they need per-peer exclusion).
//
// DELIBERATELY NOT 0: zero is NO_PEER, a disconnected seat's peer — and for
// years the two aliased, so a departed player's peer accidentally handed to
// send() became a broadcast instead of a bug. The transport translates: netgd
// maps this sentinel to the engine's broadcast id (0) at the boundary and
// DROPS a NO_PEER send as the upstream mistake it is.
BROADCAST_PEER :: Peer_Id(-1)

// The one transport egress door. A producer that exceeds the same ceiling the
// receiver enforces fails locally before committing a shadow or announcing a
// state transition that no peer could accept.
@(private)
session_send_packet :: proc(s: ^Session, to_peer: Peer_Id, bytes: []u8, channel: Channel) {
	assert(
		len(bytes) <= knet.MAX_PACKET_BYTES,
		"session packet exceeds MAX_PACKET_BYTES — split/chunk the payload",
	)
	s.send(s.send_user, to_peer, bytes, channel)
}

@(private) // interest.odin composes per-peer sends beside this
broadcast :: proc(s: ^Session, bytes: []u8, channel: Channel) {
	session_send_packet(s, BROADCAST_PEER, bytes, channel)
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

// Does this seat FIELD AN AVATAR — a connected person to deal a body to?
// The one predicate every spawn loop needs and half of them got wrong by
// omission: a dedicated server holds an infrastructure seat (no avatar) and a
// spectator watches (boot_spectate's doc said the `!p.spectator` skip was the
// game's half — which is exactly how it got skipped).
player_fields_avatar :: proc "contextless" (p: Player) -> bool {
	return p.connected && !p.dedicated && !p.spectator
}

// The seats that field avatars, in roster order — the spawn loop's list:
//
//	for p in ksess.session_players_fielding(&self.ses) {
//	    host_spawn_runner(self, p.id)
//	}
session_players_fielding :: proc(s: ^Session, allocator := context.temp_allocator) -> []Player {
	out := make([dynamic]Player, 0, len(s.players), allocator)
	for p in session_roster(s, allocator) {
		if player_fields_avatar(p) {
			append(&out, p)
		}
	}
	return out[:]
}

// Is the seat that OWNS `id` still present (connected)? The "ghost body"
// predicate every co-op game with persistent avatars re-spelled three ways
// (a standing body whose player left must not hold a wipe open, block a
// mend, or count as a defender). False for an unowned entity (nobody's), a
// departed seat, or an unknown owner.
session_owner_present :: proc(s: ^Session, id: knet.Net_Id) -> bool {
	owner := session_owner_of(s, id)
	if owner == knet.PLAYER_ID_INVALID {
		return false
	}
	p, ok := s.players[owner]
	return ok && p.connected
}

// ---- muster: the staging-room paradigm decision (who's ready, may we start) --
//
// A ready-up lobby is the last meta-game paradigm every game re-derived: rows of
// players, a ready bit each, a START the host may press only when the room is
// set. The BIT lives wherever the game keeps it — a profile row's `ready: bool`,
// a stat column — so muster_* takes a PREDICATE for it, not a type: the kit owns
// the DECISION (the count, the gate) and kit/ui's muster widget owns the pixels.
Muster_Tally :: struct {
	ready:   int, // present players whose ready bit is set
	present: int, // present PLAYERS: connected, not a spectator, not the server seat
}

Ready_Proc :: proc(s: ^Session, pid: knet.Player_Id) -> bool

// How many present players are ready, out of how many present. A watcher and a
// dedicated-server seat are in the room but not the game — never counted.
muster_tally :: proc(s: ^Session, ready: Ready_Proc) -> Muster_Tally {
	t: Muster_Tally
	for p in session_roster(s) {
		if p.dedicated || p.spectator || !p.connected {
			continue
		}
		t.present += 1
		if ready(s, p.id) {
			t.ready += 1
		}
	}
	return t
}

// May the host START? Host-only (starting is the authority's to do — a client
// always gets false), at least `min` present players, every one of them ready.
muster_can_start :: proc(s: ^Session, min: int, ready: Ready_Proc) -> bool {
	if !s.is_host {
		return false
	}
	t := muster_tally(s, ready)
	return t.present >= max(min, 1) && t.ready == t.present
}

// Which player owns an entity (PLAYER_ID_INVALID = the host/world) — saves
// games keeping their own reverse maps.
session_owner_of :: proc(s: ^Session, id: knet.Net_Id) -> knet.Player_Id {
	if e, ok := knet.registry_get(&s.reg, id); ok {
		return e.owner
	}
	return knet.PLAYER_ID_INVALID
}

// Local feedback for generated action wrappers. A fully-started session can
// distinguish a stale target from denied access before encoding or sending.
// A transport-only Session shell retains the low-level escape hatch used by
// embedders: it has no registry/roster to consult, so only the policy/known
// owner check applies. This is an ergonomic fast-fail, never the trust root.
session_action_rejection :: proc(
	s: ^Session,
	id: knet.Net_Id,
	policy: knet.Action_Policy,
) -> knet.Action_Reject_Reason {
	if !s.ran {
		if s.is_host || knet.action_access_allows(policy, s.me, session_owner_of(s, id), false) {
			return .None
		}
		return .Access
	}
	if !s.joined {
		return .Access
	}
	e, found := knet.registry_get(&s.reg, id)
	if !found {
		return .Stale
	}
	if s.is_host || knet.action_access_allows(policy, s.me, e.owner, false) {
		return .None
	}
	return .Access
}

session_action_allowed :: proc(s: ^Session, id: knet.Net_Id, policy: knet.Action_Policy) -> bool {
	return session_action_rejection(s, id, policy) == .None
}

// A single number over the whole replicated world — two peers that agree on it
// agree on their authoritative state, and a mismatch is the cheapest desync
// forensic there is. Print it each act and `expect_same` across the peer logs,
// or compare it in a unit test after two lanes converge. Covers the DELTA lane
// only (host-authoritative, byte-identical everywhere) — prediction and
// interpolation are excluded by construction, so a healthy session never reads
// as diverged. See knet.registry_state_hash for the walk. Games hand-mint their
// own procedural checksums (a terrain grown from the seed, an arena scattered
// from dice); this is the complementary probe for the LIVE entity state they
// never hashed — and the seed a replay needs to prove it reproduced the run.
session_state_hash :: proc(s: ^Session) -> u64 {
	return knet.registry_state_hash(&s.reg)
}

// ---- replay: record the received packet stream, feed it back later ----------
//
// A replay is a WIRE-TAP: session_record_start makes this session keep every
// packet it handles (framed with its arrival time and peer); session_recording
// hands back those bytes to store (wrap them in a ksave file, or ksave.record).
// session_replay feeds a recording back through session_handle_packet on a fresh
// session, which reconstructs exactly the world the recorded peer saw — the same
// welcome, spawns, deltas and streams, in order. Pair it with session_state_hash
// to PROVE the reproduction (the recorded run and the replay hash identically),
// which is also the cheapest desync-forensics answer both games hand-rolled
// checksums for. Record from RIGHT AFTER *_start so the welcome that seeds the
// world is in the capture.
session_record_start :: proc(s: ^Session) {
	if s.record.buf == nil {
		s.record = knet.writer_make(allocator = ses_allocator(s))
	} else {
		knet.writer_reset(&s.record)
	}
	s.recording = true
}

// Stop capturing (the recording is kept until the next record_start or destroy).
session_record_stop :: proc(s: ^Session) {
	s.recording = false
}

// The captured bytes so far — a slice into the session's buffer (copy it if it
// must outlive the next record_start). Empty if nothing was recorded.
session_recording :: proc(s: ^Session) -> []u8 {
	return knet.writer_bytes(&s.record)
}

// Feed a recording back through the packet path: this session receives every
// captured packet, in order, exactly as the transport delivered them the first
// time. `s` should be a fresh CLIENT (session_client_start, factory installed,
// NOT joined — the recorded welcome does the seating). Returns how many packets
// replayed. Arrival times are carried in the stream for a paced playback; this
// feeds them as fast as possible (a deterministic rebuild, not a live watch).
session_replay :: proc(s: ^Session, recording: []u8) -> int {
	r := knet.reader_make(recording)
	n := 0
	for r.off < len(r.data) {
		_ = knet.read_f64(&r) // arrival time — carried for paced playback, unused here
		from := Peer_Id(knet.read_i64(&r))
		size := int(knet.read_u32(&r))
		if r.err || size < 0 || size > knet.MAX_PACKET_BYTES {
			break // truncated recording — stop at the last whole packet
		}
		packet := knet.reader_view(&r, size)
		if r.err {
			break
		}
		pr := knet.reader_make(packet)
		session_handle_packet(s, from, &pr)
		n += 1
	}
	return n
}

// Host-side lag compensation for the COOP lane — judge `query` against the world
// as `shooter` saw it when they fired. Every streamed body except the shooter's
// own winds back to the pose their screen was drawing; the live world returns
// after the query. Covers BOTH timelines a coop host judges: other clients'
// bodies (their inbound streams are the history) and the authority's OWN
// streamed bodies — its mobs, its avatar — whose history the host keeps of
// what it shipped (registry_write_streams keep_history). Host-authoritative
// deltas (owner = nobody) have no stream history and are judged live; the
// host judges its own shots live. This is ksim.lane_rewound for games that
// never promoted to the sim lane: a coop shooter's hitscan lands on the
// target where the SHOOTER aimed, not where the host's copy has since moved it.
//
// THE REWIND TIME, derived once so nobody ships it half-off again: a sample the
// host held at T (received from its owner, or authored and sent) reaches the
// shooter one transit later and is drawn interp_delay after that; the shot the
// shooter fires at that sight takes one more transit back up. So the sight the
// shot was aimed at is the host's sample from now − (RTT + interp_delay) — the
// FULL round trip, not half of it: the stream's trip down and the shot's trip
// up both count. There is no per-tick ack to derive it from the way the sim
// lane does, so it trusts the shooter's smoothed RTT (the session's own ping
// clock; until its first pong lands the rewind is interp only — conservative,
// behind the truth, never ahead) and the known interp delay. Games that judge
// by hand read the same number from session_rewind_secs.
session_rewound :: proc(
	s: ^Session,
	shooter: knet.Player_Id,
	user: rawptr,
	query: knet.Rewound_Query,
) {
	assert(s.is_host, "lag compensation is the authority's job")
	if shooter == s.me {
		query(user) // the host's own screen IS the live world
		return
	}
	knet.registry_rewound(&s.reg, s.now - session_rewind_secs(s, shooter), shooter, user, query)
}

// How far in the past `shooter`'s screen was, in seconds, by the rule above
// (RTT + interp_delay; 0 for the host's own shots): the rewind session_rewound
// applies, exposed for a game that sweeps its own ledger or prints a receipt.
session_rewind_secs :: proc(s: ^Session, shooter: knet.Player_Id) -> f64 {
	if shooter == s.me {
		return 0
	}
	lag := s.interp_delay
	if p, ok := s.players[shooter]; ok {
		if c := s.clocks[p.peer]; c.initialized {
			lag += c.rtt // the stream's trip down to them AND the shot's trip back up
		}
	}
	return lag
}

// The bare call counts PRESENT PEOPLE — connected, non-dedicated — because
// that is what every gate that says "players" means (min-players, ready
// checks, max_players). The old bare call counted ghosts: departed seats
// (kept for reconnect) and the server's own infrastructure seat, and every
// real caller was overriding both flags to say otherwise. Opt DOWN for the
// other censuses: connected_only=false includes departed rows (roster size —
// what a save/resume receipt reports), players_only=false counts a dedicated
// seat (the wire's view).
session_count :: proc(s: ^Session, connected_only := true, players_only := true) -> int {
	if !connected_only && !players_only {
		return len(s.players)
	}
	n := 0
	for _, p in s.players {
		if connected_only && !p.connected {continue}
		if players_only && (p.dedicated || p.spectator) {continue}
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
	assert(len(name) <= PLAYER_NAME_MAX_BYTES, "player name exceeds PLAYER_NAME_MAX_BYTES")
	session_init(s) // resolves + stores s.allocator (first start adopts the ambient)
	context.allocator = ses_allocator(s) // the host's own roster name clone rides it too
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
	prof_seat(s) // a row written before the seat existed lands under it now
	append(&s.events, Ev_Seated{me = s.me}) // the host is seated too — the same half a client gets
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
session_kick :: proc(
	s: ^Session,
	player: knet.Player_Id,
	ban := false,
	reason := Disconnect_Reason.Kicked,
) -> (
	was: Peer_Id,
	ok: bool,
) {
	assert(s.is_host, "the authority moderates")
	assert(
		disconnect_reason_valid(reason) && reason != .Unknown &&
		(reason == .Kicked || reason == .Banned || reason == .Traffic_Policy),
		"session_kick reason must describe a deliberate removal",
	)
	context.allocator = ses_allocator(s) // two writers and the ban table's inserts — all the session's
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
	disconnect_reason := reason
	if ban && reason == .Kicked {
		disconnect_reason = .Banned
	}
	knet.write_u8(&w, u8(disconnect_reason))
	session_send_packet(s, p.peer, knet.writer_bytes(&w), .Reliable)

	was = p.peer
	delete_key(&s.by_peer, p.peer)
	mark_left(s, player, disconnect_reason)
	left := knet.writer_make()
	defer knet.writer_destroy(&left)
	knet.write_u8(&left, SES_LEFT)
	knet.write_player_id(&left, player)
	knet.write_u8(&left, u8(disconnect_reason))
	host_broadcast(s, knet.writer_bytes(&left), except = player)
	return was, true
}

// The transport told us a peer vanished. A peer that never joined is nobody;
// a player's departure is broadcast and the roster keeps them (disconnected)
// so the same token can reclaim the identity later.
session_peer_disconnected :: proc(
	s: ^Session,
	peer: Peer_Id,
	reason := Disconnect_Reason.Transport_Lost,
) {
	context.allocator = ses_allocator(s) // the SES_LEFT writer; this root is called from transport callbacks, whose ambient is nobody's guess
	assert(disconnect_reason_valid(reason) && reason != .Unknown)
	if !s.is_host {
		if peer == HOST_PEER {
			append(&s.events, Ev_Host_Left{reason = reason})
			session_production_log(s, Production_Log_Record {
				kind = .Disconnected, disconnect = reason, peer = peer,
			})
			if s.successor != knet.PLAYER_ID_INVALID {
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
	mark_left(s, id, reason)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_LEFT)
	knet.write_player_id(&w, id)
	knet.write_u8(&w, u8(reason))
	host_broadcast(s, knet.writer_bytes(&w), except = id)
}

@(private = "file")
mark_left :: proc(s: ^Session, id: knet.Player_Id, reason: Disconnect_Reason) {
	p := s.players[id]
	was_peer := p.peer
	p.connected = false
	p.peer = NO_PEER
	s.players[id] = p
	// Their exactly-once window goes with them: a returning player gets a
	// fresh Command_Ctx client-side anyway (new process or re-init), so the
	// old window only mis-drops their first post-rejoin commands as "stale"
	// — and an unpruned map otherwise grows with every seat ever used.
	delete_key(&s.ctx.dedup, u64(id))
	// Their interest footprint too — the focus row and every (player, entity)
	// near-pair. A rejoin re-declares focus and re-earns its pairs on the next
	// interest tick (the welcome world already re-seeds everything visible);
	// left in place they only keep the locator scanning for absent eyes.
	interest_forget_player(s, id)
	append(&s.events, Ev_Player_Left{id = id, reason = reason})
	session_production_log(s, Production_Log_Record {
		kind = .Disconnected, disconnect = reason, player = id, peer = was_peer,
	})
}

@(private = "file")
host_broadcast :: proc(
	s: ^Session,
	bytes: []u8,
	except := knet.PLAYER_ID_INVALID,
	channel := Channel.Reliable,
) {
	for _, p in s.players {
		if !p.connected || p.id == s.me || p.id == except {
			continue
		}
		session_send_packet(s, p.peer, bytes, channel)
	}
}

@(private = "file")
deny_join :: proc(s: ^Session, peer: Peer_Id, reason: Deny_Reason) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_DENIED)
	knet.write_u8(&w, u8(reason))
	session_send_packet(s, peer, knet.writer_bytes(&w), .Reliable)
}

@(private = "file")
host_handle_join :: proc(s: ^Session, peer: Peer_Id, r: ^knet.Reader) {
	token := knet.read_u64(r)
	name := knet.read_string_limited(r, PLAYER_NAME_MAX_BYTES)
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
	spectate := knet.read_bool(r)
	if r.err {
		spectate = false // a pre-spectator build's JOIN ends at the fingerprint
		r.err = false
	}
	// The joiner's pre-seat profile row (trailing; a pre-row build's JOIN ends
	// at the spectate flag): kept only if it is exactly one row of the
	// installed type — the fingerprint below already refuses a foreign shape.
	hello_row: []u8
	if n := int(knet.read_u16(r));
	   !r.err && n > 0 && n == s.prof.size && r.off + n <= len(r.data) {
		hello_row = r.data[r.off:r.off + n]
		r.off += n
	}
	r.err = false

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
		if len(s.players) >= knet.MAX_CONTAINER_ITEMS {
			deny_join(s, peer, .Full) // protocol table ceiling, including spectators
			return
		}
		// max_players caps PEOPLE — a dedicated server's own seat never eats
		// one, and a SPECTATOR bypasses the cap outright (a full room can be
		// watched; the seat plays nobody). Zero config = DEFAULT_MAX_PLAYERS;
		// going unbounded is spelled max_players = -1, a declaration, not a
		// forgotten field.
		limit := s.cfg.max_players == 0 ? DEFAULT_MAX_PLAYERS : s.cfg.max_players
		if !spectate &&
		   limit > 0 &&
		   session_count(s, connected_only = true, players_only = true) >= limit {
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
		p.spectator = spectate // the seat re-declares its intent each join
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
			spectator = spectate,
		}
	}
	s.by_peer[peer] = id
	// The row that rode the hello is the seat's word from this instant: file it
	// before the welcome's table ships and before Ev_Player_Joined fires, so
	// the joiner's first sight of itself and the host's join half both read
	// it. (It is the joiner's LATEST word — it replaces a rejoiner's old row.)
	if hello_row != nil {
		prof_adopt(s, id, hello_row)
	}

	// WELCOME the joiner with the full roster (their own entry included —
	// clients learn `me` from your_id).
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_WELCOME)
	knet.write_player_id(&w, id)
	assert(len(s.players) <= int(max(u16)))
	assert(len(s.players) <= knet.MAX_CONTAINER_ITEMS)
	knet.write_u16(&w, u16(len(s.players)))
	for _, p in s.players {
		knet.write_player_id(&w, p.id)
		knet.write_string(&w, p.name)
		knet.write_bool(&w, p.connected)
		knet.write_bool(&w, p.dedicated) // the server seat announces itself
		knet.write_bool(&w, p.spectator) // ...and the watching seats do too
	}
	knet.write_bool(&w, s.interest_r > 0 && s.locator != nil) // stream routing (interest.odin)
	session_send_packet(s, peer, knet.writer_bytes(&w), .Reliable)

	// Everyone else learns about (or re-learns) the joiner.
	up := knet.writer_make()
	defer knet.writer_destroy(&up)
	knet.write_u8(&up, SES_UPSERT)
	knet.write_player_id(&up, id)
	knet.write_string(&up, name)
	knet.write_bool(&up, true)
	knet.write_bool(&up, rejoin)
	knet.write_bool(&up, spectate)
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
	prof_send(s, peer) // the profile table rides behind the welcome too
	send_successor(s, peer)

	append(&s.events, Ev_Player_Joined{id = id, rejoin = rejoin})
}

// ---- client ------------------------------------------------------------------

// Remember who we are; the JOIN goes out when the game confirms the transport
// is up (session_client_join). `token` is the persistent reconnect secret.
// `spectate` joins to WATCH: the seat sees everything and is nobody — no
// avatar to field, no vote in player gates, no torch, and the host refuses
// its commands and streams. It bypasses max_players (a full room can be
// watched). Promotion to a playing seat is deliberately NOT a flag flip —
// leave and rejoin as a player.
session_client_start :: proc(s: ^Session, token: u64, name: string, spectate := false) {
	assert(len(name) <= PLAYER_NAME_MAX_BYTES, "player name exceeds PLAYER_NAME_MAX_BYTES")
	session_init(s) // resolves + stores s.allocator (first start adopts the ambient)
	context.allocator = ses_allocator(s) // the requested-name clone below rides it
	s.is_host = false
	s.token = token
	s.spectate = spectate
	s.name = strings.clone(name)
	s.join_waited = 0 // the join-timeout clock arms; Ev_Join_Failed if no WELCOME
}

// Transport is connected: ask the host to seat us.
session_client_join :: proc(s: ^Session) {
	context.allocator = ses_allocator(s) // the shadow being dropped was made under the stored allocator (prof_tick)
	// This host has never seen my row (a fresh host, or a rejoin to a new
	// one): drop the declare shadow so the first prof_tick after seating
	// re-ships it. The row itself stays — it is my echo, not run state here.
	delete(s.prof.shadow)
	s.prof.shadow = nil
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_JOIN)
	knet.write_u64(&w, s.token)
	knet.write_string(&w, s.name)
	knet.write_u64(&w, wire_fingerprint(s.cfg.fingerprint))
	knet.write_bool(&w, s.spectate) // trailing like the fingerprint: older joins just end sooner
	// MY PROFILE ROW RIDES THE HELLO (trailing too): the row I wrote before I
	// had a seat (a lobby pick — prof_pending) reaches the host WITH the join,
	// so the host holds my word the instant it seats me — a game that spawns
	// at the seat reads my loadout, not a zero row that my declare overwrites
	// a tick later (the spawn/declare race every drop-in lobby had to gate by
	// hand). [size u16][row bytes]; size 0 = nothing to say yet.
	if s.prof_pending != nil && s.prof.size == len(s.prof_pending) {
		knet.write_u16(&w, u16(s.prof.size))
		append(&w.buf, ..s.prof_pending)
	} else {
		knet.write_u16(&w, 0)
	}
	session_send_packet(s, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

// The SESSION's own wire revision — this package's messages and codecs ONLY.
// Every wire-bearing package now owns its rev beside the wire it describes
// (knet.WIRE_REV, ksim's, netgd's) and all of them fold into the fingerprint
// below, so a wire change and its rev bump land in the SAME package, the
// same commit. (This log used to register the whole kit's changes: its rev 3
// and 8 were netgd's, rev 4 was kit/sim's — a convention that held only by
// engineers remembering a constant in a package they weren't editing.)
PROTOCOL_REV :: u64(13) // 13: leave/bye/kick carry structured disconnect reasons

// Wire revisions of the packages ABOVE the session (kit/sim's lane wire,
// netgd's frame) — the session cannot import upward, so they register at
// load via @(init), the same inversion the generated fingerprint rides
// (default_net_fingerprint). Shift allocation: session bits 0..7, knet 8..15
// (read directly — it's below), kit/sim 16..23, netgd 24..31. Pre-main, so
// no runtime mutation of package globals is ever involved.
@(private = "file")
registered_wire_revs: u64

session_register_wire_rev :: proc "contextless" (rev: u64, shift: uint) {
	registered_wire_revs |= rev << shift
}

// The route registered on `tag` (session_app_route) — for a subsystem that
// wants to reach ITS OWN receive queue on the machine that is also the
// sender (kcombat's fire loopback: the host announces and its own screen
// hears it through the same drain every client uses). The caller compares
// `handler` against its own to know the user pointer's type.
session_app_route_of :: proc(s: ^Session, tag: u8) -> (user: rawptr, handler: App_Handler) {
	if int(tag) >= MAX_APP_TAGS {
		return nil, nil
	}
	route := s.app[tag]
	return route.user, route.handler
}

@(private = "file")
fp_salt :: proc() -> u64 {
	// The golden-ratio constant, rev-shifted. (Added, not multiplied: a typed
	// compile-time u64 multiply that overflows trips an LLVM-backend assert
	// in current Odin — a compiler crash, not an error.)
	return u64(0x9E3779B97F4A7C15) + PROTOCOL_REV + (knet.WIRE_REV << 8) + registered_wire_revs
}

@(private = "file")
wire_fingerprint :: proc(cfg_fp: u64) -> u64 {
	fp := cfg_fp
	if fp == 0 {
		fp = default_net_fingerprint // the generated guard file's @(init) value
	}
	if fp == 0 || fp == FINGERPRINT_NONE {
		return 0 // unchecked stays unchecked — never salted into a phantom value
	}
	return fp ~ fp_salt()
}

// Graceful goodbye (the host also handles the plain transport disconnect —
// this just makes the departure immediate instead of timeout-shaped).
session_client_leave :: proc(s: ^Session) {
	context.allocator = ses_allocator(s) // the goodbye writer rides the session like every other send path
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, SES_BYE)
	knet.write_u8(&w, u8(Disconnect_Reason.Graceful))
	session_send_packet(s, HOST_PEER, knet.writer_bytes(&w), .Reliable)
}

@(private = "file")
roster_upsert :: proc(
	s: ^Session,
	id: knet.Player_Id,
	name: string,
	connected: bool,
	peer := NO_PEER,
	dedicated := false,
	spectator := false,
) {
	if old, had := s.players[id]; had {
		delete(old.name)
	}
	s.players[id] = Player {
		id        = id,
		name      = strings.clone(name),
		peer      = peer,
		connected = connected,
		dedicated = dedicated,
		spectator = spectator,
	}
}

@(private = "file")
client_handle_welcome :: proc(s: ^Session, r: ^knet.Reader) {
	me := knet.read_player_id(r)
	count := int(knet.read_u16(r))
	if !knet.reader_admit_count(r, count, 13) {
		return
	}
	probe := r^
	for _ in 0 ..< count {
		_ = knet.read_player_id(&probe)
		_ = knet.read_string_limited(&probe, PLAYER_NAME_MAX_BYTES)
		_ = knet.read_bool(&probe)
		_ = knet.read_bool(&probe)
		_ = knet.read_bool(&probe)
	}
	// AOI is the one backwards-compatible optional trailing byte.
	if probe.err || len(knet.reader_remaining(&probe)) > 1 {
		r.err = true
		return
	}
	for _ in 0 ..< count {
		id := knet.read_player_id(r)
		name := knet.read_string_limited(r, PLAYER_NAME_MAX_BYTES)
		connected := knet.read_bool(r)
		dedicated := knet.read_bool(r)
		spectator := knet.read_bool(r)
		if r.err {
			return // preflight above makes this unreachable
		}
		roster_upsert(s, id, name, connected, dedicated = dedicated, spectator = spectator)
	}
	s.me = me
	s.ctx.me = me
	// Interest routing (older hosts simply end the payload here: read_bool
	// on an exhausted reader yields false — broadcast, the old behavior).
	s.aoi_client = false
	if len(knet.reader_remaining(r)) == 1 {
		s.aoi_client = knet.read_bool(r)
	}
	s.joined = true
	s.join_waited = -1 // the join-timeout clock disarms
	prof_seat(s) // a row written before the seat existed lands under it now (and wins over the table's old copy of me)
	append(&s.events, Ev_Seated{me = me})
	append(&s.events, Ev_Welcomed{me = me})
}

// ---- shared receive path -----------------------------------------------------

// The game routes its session kind byte here with the rest of the packet.
// `from_peer` is the transport sender (hosts route by it; clients only ever
// hear from the host — except streams, which any owning peer may broadcast).
session_handle_packet :: proc(
	s: ^Session,
	from_peer: Peer_Id,
	r: ^knet.Reader,
	channel := Channel.Reliable,
) {
	context.allocator = ses_allocator(s) // every receive-path clone/make/free (names, rows, stat names, backup blobs, registry slices) rides the stored allocator
	if !knet.reader_admit_packet(r) {
		s.malformed += 1
		session_production_log(s, Production_Log_Record {
			kind = .Malformed_Packet, peer = from_peer,
			bytes = u32(len(r.data)), count = s.malformed,
		})
		return
	}
	if s.recording {
		// Tap the raw packet BEFORE it is parsed: arrival time, peer, and the whole
		// byte string (r.off is 0 at entry — this is the transport's delivery). The
		// replay feeds these back through this same proc, in order.
		frame_bytes := 8 + 8 + 4 + len(r.data)
		if frame_bytes <= RECORDING_MAX_BYTES - len(s.record.buf) {
			knet.write_f64(&s.record, s.now)
			knet.write_i64(&s.record, i64(from_peer))
			knet.write_u32(&s.record, u32(len(r.data)))
			append(&s.record.buf, ..r.data)
		} else {
			s.recording = false // a diagnostic tap must never become an unbounded remote allocation
		}
	}
	// One shared channel gate before any routed decoder or application handler
	// runs. Pre-seat traffic has no stable player yet and stays under the join
	// door's own bounds; every seated peer, spectators included, is accountable.
	if s.is_host {
		if player, seated := s.by_peer[from_peer]; seated {
			class := channel == .Stream ? Traffic_Class.Stream : Traffic_Class.Reliable
			if !session_admit_traffic(s, player, from_peer, class, len(r.data)) {
				return
			}
		}
	}
	handle_packet_inner(s, from_peer, r)
	if r.err {
		// A packet died mid-parse — every inner bail leaves r.err set, so the
		// drop is COUNTED here no matter which of the ~30 read sites refused
		// it. (Role-gate returns leave r.err clear: discipline, not damage.)
		s.malformed += 1
		session_production_log(s, Production_Log_Record {
			kind = .Malformed_Packet, peer = from_peer,
			bytes = u32(len(r.data)), count = s.malformed,
		})
	}
}

// How many session packets this peer dropped mid-parse. A moving count on a
// live link means truncation, corruption, or a mismatched build the
// fingerprint door didn't get to refuse — surface it (netgraph does).
// Rogue client writes the guard found in a RELEASE build (dev builds assert
// instead, so this stays zero there). Nonzero in the field means some client
// code writes host-lane replicated state locally — silent divergence until
// the next authoritative delta stomps it; surface it beside malformed drops.
session_guard_hits :: proc(s: ^Session) -> u64 {
	return s.guard_hits
}

session_malformed :: proc(s: ^Session) -> u64 {
	return s.malformed
}

@(private = "file")
handle_packet_inner :: proc(s: ^Session, from_peer: Peer_Id, r: ^knet.Reader) {
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
			reason := Disconnect_Reason(knet.read_u8(r))
			if r.err || !disconnect_reason_valid(reason) || reason != .Graceful {
				r.err = true
				return
			}
			session_peer_disconnected(s, from_peer, reason)
		}
	case SES_AOI:
		// Host-side stream FILTERING flipped mid-run (all client streams route
		// through the host regardless; this records whether it AOI-splits them).
		if s.is_host || !s.joined {
			return
		}
		s.aoi_client = knet.read_bool(r)
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
		reason := Disconnect_Reason(knet.read_u8(r))
		if r.err || !disconnect_reason_valid(reason) ||
		   (reason != .Kicked && reason != .Banned && reason != .Traffic_Policy) {
			r.err = true
			return
		}
		s.joined = false
		append(&s.events, Ev_Kicked{reason = reason})
		session_production_log(s, Production_Log_Record {
			kind = .Disconnected, disconnect = reason, player = s.me, peer = HOST_PEER,
		})
	case SES_UPSERT:
		if s.is_host {
			return
		}
		id := knet.read_player_id(r)
		name := knet.read_string_limited(r, PLAYER_NAME_MAX_BYTES)
		connected := knet.read_bool(r)
		rejoin := knet.read_bool(r)
		spectator := knet.read_bool(r)
		if r.err {
			return
		}
		roster_upsert(s, id, name, connected, spectator = spectator)
		append(&s.events, Ev_Player_Joined{id = id, rejoin = rejoin})
	case SES_LEFT:
		if s.is_host {
			return
		}
		id := knet.read_player_id(r)
		reason := Disconnect_Reason(knet.read_u8(r))
		if r.err || !disconnect_reason_valid(reason) {
			r.err = true
			return
		}
		if p, had := s.players[id]; had {
			p.connected = false
			p.peer = NO_PEER
			s.players[id] = p
			append(&s.events, Ev_Player_Left{id = id, reason = reason})
			session_production_log(s, Production_Log_Record {
				kind = .Disconnected, disconnect = reason, player = id,
			})
		}

	// ---- the replicated world (clients ignore it all until SEATED: a spawn
	// arriving before our WELCOME would collide with the SES_WORLD that
	// follows it — everything pre-seat is superseded by that snapshot) ----
	case SES_WORLD:
		if s.is_host || !s.joined {
			return
		}
		count := int(knet.read_u16(r))
		if !knet.reader_admit_count(r, count, 24) {
			return
		}
		probe := r^
		for _ in 0 ..< count {
			if !spawn_tuple_probe(&probe) {
				r.err = true
				return
			}
		}
		if len(knet.reader_remaining(&probe)) != 0 {
			r.err = true
			return
		}
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
		probe := r^
		if !spawn_tuple_probe(&probe) || len(knet.reader_remaining(&probe)) != 0 {
			r.err = true
			return
		}
		apply_spawn_tuple(s, r)
	case SES_SUCCESSOR:
		if s.is_host || !s.joined {
			return
		}
		successor_recv(s, r)
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
		// If WE predicted this ownership (wrote the entity's owner-streamed fields
		// before the host confirmed) and it landed on us, keep those fields — the
		// prediction IS the truth now; the normal handoff flush would stomp it.
		keep := owner == s.me && session_predicting_owner(s, id)
		if knet.registry_set_owner(&s.reg, id, owner, s.now, keep_fields = keep) {
			append(&s.events, Ev_Owner_Changed{id = id, owner = owner, prev = prev})
		}
	case SES_BLOB:
		if s.is_host || !s.joined {
			return
		}
		id := knet.read_net_id(r)
		ver := knet.read_u32(r)
		n := int(knet.read_u32(r))
		if r.err || n < 0 || n > knet.ENTITY_BLOB_MAX_BYTES { 	// <0: 32-bit wrap on hostile lengths
			r.err = true
			return
		}
		blob := knet.reader_view(r, n)
		if r.err || len(knet.reader_remaining(r)) != 0 {
			r.err = true
			return
		}
		if knet.registry_apply_blob(&s.reg, id, ver, blob) {
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
		backup_recv(s, r)
	case SES_DECLARE:
		// A player's profile row (profile.odin) — host only, seated only
		// (the same trust gate as commands: a peer that never JOINed is nobody).
		if !s.is_host {
			return
		}
		from, seated := s.by_peer[from_peer]
		if !seated {
			return
		}
		prof_handle_declare(s, from, r)
	case SES_PROFILES:
		if s.is_host || !s.joined {
			return
		}
		prof_handle_table(s, r)
	case SES_STATS:
		if s.is_host || !s.joined {
			return
		}
		stats_recv(s, r)
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
		h := knet.command_read_header(r)
		e, target_exists := knet.registry_get(&s.reg, h.entity)
		cmd: ^knet.Command_Desc
		owner := knet.PLAYER_ID_INVALID
		if target_exists {
			owner = e.owner
			cmd = knet.command_find(e.set, h.cmd)
		}
		args_bytes := len(knet.reader_remaining(r))
		policy := knet.Action_Policy{}
		if cmd != nil {
			policy = cmd.policy
		}
		decision := session_authority_action_admit(
			s,
			Authority_Action_Request {
				model = .Immediate,
				player = pid,
				peer = from_peer,
				seq = u32(h.seq),
				entity = h.entity,
				action = h.cmd,
				packet_bytes = len(r.data),
				payload_valid = !r.err,
				target_exists = target_exists,
				action_exists = cmd != nil,
				owner = owner,
				policy = policy,
				args_bytes = args_bytes,
				args_valid = cmd != nil && knet.action_args_allowed(policy, args_bytes),
			},
		)
		if !decision.respond {
			if h.seq != 0 {
				session_action_executed(s, .Immediate, u32(h.seq), pid, h.entity, h.cmd, decision.reason)
			}
			return
		}
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, SES_RESULT)
		result := knet.registry_host_command_checked(
			&s.reg,
			&s.ctx,
			pid,
			r,
			&w,
			decision.reason,
			&h,
			false,
		)
		if result.header.seq != 0 {
			session_action_executed(
				s,
				.Immediate,
				u32(result.header.seq),
				pid,
				result.header.entity,
				result.header.cmd,
				result.reason,
			)
		}
		if !result.responded {
			return
		}
		session_send_packet(s, from_peer, knet.writer_bytes(&w), .Reliable)
		// The hook runs BEFORE the result ships onward in game terms: scratch
		// state the proc left on the entity is still exactly this command's.
		if result.reason != .Stale {
			session_dispatch_hook(
				s,
				pid,
				result.header.entity,
				result.header.cmd,
				result.reason == .None,
			)
		}
	case SES_RESULT:
		if s.is_host {
			return
		}
		res := knet.registry_client_result(&s.reg, &s.ctx, r, s.me)
		if res.seq == 0 {
			return // truncated header: not a result at all (seqs start at 1)
		}
		// A truncated truth snapshot already fell back to the local revert
		// inside command_reject — the typed rejection callback holds either way.
		session_action_resolved(s, .Immediate, u32(res.seq), res.entity, res.cmd, res.reason)
	case SES_STREAM:
		if !s.joined {
			return
		}
		sender := knet.PLAYER_ID_INVALID
		if s.is_host {
			// Resolve the transport identity before parsing attacker-controlled
			// rows. Unseated, disconnected, and watching peers own no stream lane.
			pid, seated := s.by_peer[from_peer]
			if !seated {
				return
			}
			p, has := s.players[pid]
			if !has || !p.connected || p.spectator {
				return
			}
			sender = pid
		} else if from_peer != HOST_PEER {
			// Clients accept owner state only after the authority gateway relays
			// it. A direct peer packet cannot prove which player owned its rows.
			return
		}
		raw := r.data[r.off:] // the batch, pre-parse (the host may forward it)
		_ = knet.registry_stream_time(r) // sender stamp (clock-mapped timelines later)
		_ = knet.registry_apply_streams(r, &s.reg, s.me, s.now, sender)
		if r.err {
			return // transactional parse/ownership refusal: apply and forward nothing
		}
		if s.is_host {
			if interest_on(s) {
				interest_route_streams(s, raw, from_peer, s.ticker.tick)
			} else {
				w := knet.writer_make(len(raw) + 1, context.temp_allocator)
				knet.write_u8(&w, SES_STREAM)
				append(&w.buf, ..raw)
				host_broadcast(s, knet.writer_bytes(&w), except = sender, channel = .Stream)
			}
		}
	case SES_APP:
		tag := knet.read_u8(r)
		if r.err || int(tag) >= MAX_APP_TAGS {
			return
		}
		if len(knet.reader_remaining(r)) > APP_MESSAGE_MAX_BYTES {
			r.err = true
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
			session_send_packet(s, from_peer, knet.writer_bytes(&w), .Reliable)
		}
	case SES_PONG:
		c := s.clocks[from_peer]
		if knet.pong_apply(r, &c, s.now) {
			s.clocks[from_peer] = c
			s.pongs += 1
		}
	}
}
