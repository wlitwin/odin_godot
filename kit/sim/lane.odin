package kit_sim

// lane — the sim lane on a live session: the driver that turns the engine-
// free parts (input pipeline, ledgers, snapshots, reconcile) into two calls
// a game actually makes.
//
//     ksim.lane_init(&self.lane, &self.ses, size_of(Runner_Input))
//     ksim.lane_set_sim(&self.lane, self, game_sample, game_step)
//     // per spawned sim entity (from the factory / Ev_Spawned):
//     ksim.lane_track(&self.lane, id, entity, desc, owner)
//     // once per frame, beside session_tick:
//     ksim.lane_frame(&self.lane, delta)
//
// ZERO ROLE BRANCHES for the game: the same wiring runs everywhere, and the
// lane derives its role from the session. On the authority a frame pops each
// player's de-jittered input, steps the tick procs, ledgers truth, and ships
// per-client snapshot batches. On a client it samples local intent, predicts
// the same tick procs ahead of the server, ships the redundant input window,
// and reconciles arriving batches — the game's Step_Proc IS the resim proc,
// which is the whole single-player-shaped promise of this lane.
//
// It rides SES_APP like kit/comms: one tag, two message kinds inside it,
// both on the .Stream channel (tick-stamped, self-superseding — a lost one
// is worthless by the time it could be resent):
//
//     SIM_INPUT  client → host   [snap ack][render off][class count]{[class id][input window]}
//     SIM_SNAP   host → client   [snapshot batch]
//
// EVENTS, NOT CALLBACKS: handlers only file bytes into lane-owned state
// (input buffers, the pending batch); every call into game code — sample,
// step, resim — happens inside lane_frame, on the game's own stack. A batch
// arriving mid-pump can never re-enter the sim.
//
// The tick timeline is the SERVER'S. A client starts unanchored: it neither
// ticks nor sends until the first batch names the authoritative tick, then
// anchors ahead of it and lets the lead controller bend the clock from
// there — the batch header's input ack doubles as the feedback signal (how
// far the server's copy of our inputs ran ahead of its sim when the batch
// left), so the loop needs no extra wire and no clock-sync dependency.
//
// What the game's tick code may touch, the resim contract (scriptgen will
// enforce this on @(gd_tick) procs; until then it is discipline):
// predicted fields, lane_input, and per-tick derivables — never wall clocks,
// node state, or un-ledgered randomness.

import "core:fmt"
import "core:mem"
import knet "godot:kit/net"
import ksess "godot:kit/session"

_ :: fmt // native-only use (the tolerance warning) — the freestanding build compiles it out

SIM_TAG :: u8(3) // default SES_APP tag (comms holds 0, xfer holds 2)

// This package's wire revision — the lane's formats ONLY (input windows,
// snap batches, verbs, facts). Registered into the session's fingerprint
// salt at load (the session sits below and cannot import upward); a lane
// wire change bumps THIS constant, in the same commit.
WIRE_REV :: u64(2) // 1: the lane's first wire · 2: SIM_FACT carries a fact kind

@(init, private = "file")
register_wire_rev :: proc "contextless" () {
	ksess.session_register_wire_rev(WIRE_REV, 16)
}

SIM_INPUT: u8 : 0 // client → host, inside the tag
SIM_SNAP: u8 : 1 // host → client
SIM_CMD: u8 : 2 // client → host, RELIABLE: a tick-stamped verb (command.odin)
SIM_VERDICT: u8 : 3 // host → client, RELIABLE: that verb's accept/reject
// host → client, RELIABLE: an event tick's facts, watch-clock presented.
// WIRE FORMAT (the one place it is written down — the generated encoders in
// every *.gen.odin and the receive case below are matched pairs, and the
// kitsim fact tests drive the full encode→decode path so a drift fails
// loudly):  [SIM_FACT u8][tick u64][anchor Net_Id u32; 0 = anchorless]
//           [kind u16; 0 = the anchor set's tick fx, else a Fact_Desc id]
//           [args: length-prefixed bytes — the fact tuple, wire-primitive
//            encoded in DECLARATION ORDER]
SIM_FACT: u8 : 4

// Fill the LOCAL player's input for `tick` into dst (input_size bytes).
// Read the device here and nowhere else — a resim never calls this.
Sample_Proc :: proc(user: rawptr, tick: u64, dst: rawptr)

// One input TYPE the lane carries: its wire class id, its byte size, the
// sample that fills it (nil on a seat that doesn't play), and the client's
// ring of already-predicted inputs for it. A single-input game holds exactly
// one of these; a game driving two entity kinds holds one per kind, each
// riding its own window on the packet and its own de-jitter buffer per player.
Input_Class :: struct {
	id:      u16,
	size:    int,
	// The input struct's typeid, when the registrar knew it (the generated
	// <game>_lane_init always does; a hand-built lane may leave it nil). It is a
	// LOCAL resolver key only — never on the wire — so lane_input_of can name its
	// class by TYPE instead of by size, which two input kinds can collide on
	// after an innocent field add. nil = fall back to size (see class_for_type).
	type:    typeid,
	sample:  Sample_Proc,
	ring:    Input_Ring, // client only: local inputs already fed to prediction
	scratch: []u8,       // sample destination (size bytes)
}

// Echo (predict-world) keys last-known inputs by (player, class): a remote
// player driving two kinds echoes one held input per kind.
@(private = "file")
Echo_Key :: struct {
	player: knet.Player_Id,
	class:  u16,
}

// Advance the sim-lane world one tick: read inputs via lane_input, mutate
// predicted fields. Deliberately the same shape as Resim_Proc — the live
// frame and the replay run the identical proc. OPTIONAL once entities carry
// their own tick thunks (lane_track_set): entity ticks run first, in track
// order, then this world pass — the spot for cross-entity work (spawning a
// predicted projectile, resolving a contested pickup).
Step_Proc :: proc(user: rawptr, tick: u64)

// One entity's tick, generated by scriptgen from @(gd_tick) (or hand-built
// in tests): cast, decode nothing (input is already struct bytes), call the
// author's proc — then route its returned PAYLOAD (facts the tick learned:
// fired, dashed, landed) to the name-paired halves, holding the role gates
// so game code never does: `<tick>_then` on the authority, `<tick>_fx` on
// the owning peer's LIVE pass (never a resim). `input` is the owning
// player's input for the tick being stepped — nil when no input drives this
// entity here; `owner` is the driving seat, for the routing and the
// consequence's `by`.
Tick_Thunk :: proc(entity: rawptr, input: rawptr, lane: ^Lane, owner: knet.Player_Id)

// One entity TYPE's every-screen presentation half — the mine-form `_fx`
// (an `_fx` declaring `mine: bool` after `self`), generated by scriptgen:
// decode the fact tuple, call the author's proc. `mine` = this screen's own
// simulation caused it (fired inline from the live pass); false = a watcher
// presenting the authority's word, fired when the watch clock reaches the
// fact's tick so the effect lands beside the delayed avatar that caused it.
Fx_Thunk :: proc(entity: rawptr, lane: ^Lane, mine: bool, args: []u8)

// Per entity TYPE: what the sim lane needs to drive it — the descriptor
// (predict subset) plus the tick entry point. scriptgen emits one per class
// with an @(gd_tick) proc: `runner_sim_set`.
Sim_Set :: struct {
	entity_desc: ^knet.Entity_Desc,
	tick:        Tick_Thunk,
	input_size:  int, // size of the tick proc's input struct (0 = inputless)
	input_class: u16, // WHICH input the tick reads — its class id on the wire. One
	                  // per distinct @(gd_tick) input TYPE in the package (scriptgen
	                  // assigns; the primary is 0). A lane ships one window per class
	                  // a seat drives, so a player controlling two entity KINDS (a
	                  // walker + a turret) sends both their inputs each tick.
	commands:    []Sim_Cmd, // the class's @(gd_command) verbs, tick-scheduled (command.odin)
	fx:          Fx_Thunk, // the mine-form `_fx` decode thunk (nil = the class declares
	                       // none): what a watcher fires when a filed SIM_FACT comes of age
	// @(gd_tick="contested"): EVERY peer predicts this entity, owner or not —
	// the predict-the-contested-object pattern (the ball, the crown, the
	// flag). Contact with it resolves on YOUR timeline instantly; the
	// server's word reconciles the fights, and the glide hides the losses.
	// Costs resim CPU per peer and honest mispredicts whenever a REMOTE
	// player (rendered in the past) touches it first — the documented trade.
	contested:   bool,
}

Lane_Config :: struct {
	hz:          int, // sim ticks per second (0 = DEFAULT_SIM_HZ, 60)
	snap_every:  int, // ticks between snapshot batches (0 = 3 → 20 Hz at 60)
	slots:       int, // ledger/ring depth in ticks (0 = 128 — covers ~2s of lead, resim, and ack round trips)
	margin:      int, // target server-side input headroom in ticks (0 = 2)
	redundancy:  int, // inputs per packet (0 = INPUT_REDUNDANCY)
	rewind_max:  int, // lag-comp rewind bound in ticks (0 = hz/4 ≈ 250ms — the favor-the-shooter ceiling)
	watch_delay: int, // how far behind the newest batch watched entities RENDER, in ticks (0 = 2×snap_every — almost always a bracketing pair)
	smooth_halflife: f64, // reconcile-correction render error half-life, seconds (0 = 0.063 — the puppet constant)
	smooth_cut: f32, // an error component past this is a deliberate cut and SNAPS, world units (0 = never cut)
	judge_live: bool, // A/B knob: lane_rewound queries the LIVE world instead of rewinding —
	                  // feel lag comp by turning it off; never a game-code fork
	// PREDICT-WORLD (the Rocket League model): batches echo every player's
	// last-known input, and clients tick contested entities owned by REMOTE
	// players with those held inputs — one timeline for everything, no claim
	// dance, constant small glided corrections instead of delayed-but-
	// accurate remote views. Mark the avatars @(gd_tick="contested") too.
	// Costs: resim on nearly every batch (held inputs drift), a few bytes of
	// echo per player per batch. Compile-time config: every peer of a game
	// agrees by construction.
	echo_inputs: bool,
	tolerance: f32, // reconcile slack for FLOAT predicted fields, world units
	                // (0 = exact). Predict-world's anti-churn: held-input
	                // drift below this rides uncorrected until it accumulates
	                // past the line; discrete fields always compare exactly.
}

// Host-side per-player state, created on a player's first input packet.
@(private = "file")
Lane_Peer :: struct {
	bufs:  map[u16]^Input_Buffer, // one de-jitter buffer per input class this player drives
	acked: u64, // newest snap tick they fully applied — their delta baseline
	tag:   u64, // the (ack<<8|off) rider of the input just popped — one packet feeds every
	            // class, so every buffer's tag agrees; the rewind reads it here
}

@(private) // command.odin's scheduler walks the track list too
Tracked :: struct {
	id:      knet.Net_Id,
	entity:  rawptr,
	desc:    ^knet.Entity_Desc,
	owner:   knet.Player_Id, // whose inputs drive it (rewound queries spare the shooter's own)
	hist:    ^History, // truth (host) / prediction (client-owned); nil = watched
	watched: bool, // client-side remote-owned: truth applies directly, no resim
	tick:    Tick_Thunk, // nil = the game's Step_Proc moves this entity
	has_in:  bool, // the thunk wants its owner's input (Sim_Set.input_size > 0)
	in_class: u16, // which input class drives it (Sim_Set.input_class) — the ring/buffer key
	cmds:    []Sim_Cmd, // tick-scheduled verbs (nil = the class declares none)
	set:     ^Sim_Set, // the class's set (lane_track_set) — nil for hand-tracked entities
	err:     []u8, // render-error blob (predict-subset layout), alloc'd on the first correction
	contested: bool, // predicted here but NOT mine: presentation follows `claim`
	claim:     f32, // 1 = my sim drives it (present predicted), decaying to 0 (present the watched view)
	// Predicted-spawn bookkeeping (a client-fired projectile, command.odin's
	// lane_spawn_predicted). born = the spawn tick, so ticks before it are
	// gated out of the ledger/rewind/resim (Entry.born). A provisional entity is
	// unmatched until the authority's spawn arrives and rekeys it.
	born:        u64,
	provisional: bool, // spawned locally, not yet matched to an authoritative id
	spawn_seq:   u32, // the firing command's seq — the match key (FIFO breaks on a rejected burst shot)
	spawn_type:  ksess.Entity_Type, // what to match against on the authority's spawn
}

Lane :: struct {
	ses:             ^ksess.Session,
	tag:             u8,
	snap_every:      int,
	slots:           int,
	margin:          int,
	redundancy:      int,
	rewind_max:      int,
	watch_delay:     int,
	watch_clock:     f64, // watched-entity render position, in fractional ticks
	presented:       bool, // the game has called lane_present at least once — until
	                       // then ingest keeps painting watched truth directly (a
	                       // hand-driven client that never presents must never freeze)
	smooth_halflife: f64,
	smooth_cut:      f32,
	judge_live:      bool,
	tolerance:       f32,
	echo_on:         bool,
	echo:            map[Echo_Key][]u8, // last-known input per REMOTE (player, class) (predict-world)
	ticker:          Sim_Ticker,

	user:            rawptr,
	// The allocator lane_init was given. EVERY lane entry point installs it
	// as context.allocator, so a handler-side alloc and its frame-side free
	// can never ride different allocators — the param used to cover only the
	// init-time containers, a half-promise a custom-allocator lane paid for
	// in mismatched frees.
	allocator:       mem.Allocator,
	// One input class per distinct @(gd_tick) input TYPE. Single-input games
	// hold exactly one (id 0, its sample from lane_set_sim); a game driving two
	// entity kinds registers the extras with lane_add_input_class. The client
	// samples and ships a window for every class here that has a sample; the
	// host de-jitters each into the matching per-player buffer.
	inputs:          [dynamic]Input_Class,
	step:            Step_Proc, // the world pass that runs EVERYWHERE (live + resim): pure-sim contact
	step_auth:       Step_Proc, // the host-only world pass: adjudication, respawns (the authority never resims)

	tracked:         [dynamic]Tracked,
	entries:         [dynamic]Entry, // ledgered subset of tracked (host: all; client: mine)

	// client
	rx:              Snap_Rx,
	pending:         [dynamic]u8, // newest unprocessed batch (copied out of the handler)
	pending_tick:    u64,
	input_ack:       u64, // newest input tick the server confirmed (batch header)
	anchored:        bool,

	// host
	peers:           map[knet.Player_Id]^Lane_Peer,

	step_tick:       u64, // the tick being stepped/resimmed — lane_input reads it
	// True while a reconcile replay is re-running ticks. Gate PRESENTATION
	// side effects on it (muzzle flashes, sounds, screen shake fire once, on
	// the live pass) — sim mutations must NEVER branch on it, or prediction
	// and replay diverge by construction.
	resimming:       bool,

	// running tallies, game-readable (a resim burst is a netgraph datum)
	stat_resims:     int,
	stat_reconciles: int,
	stat_facts_dropped: int, // world facts refused by a full queue — a moving count means the game presents too rarely (or FACT_QUEUE_CAP is honestly too small)
	stat_render_sat:    int, // render_off8 hit the wire's 31.5-tick ceiling — the authority now rewinds LESS than this screen's true delay (lag comp judges shallow)
	stat_input_drops:   int, // host: input windows dropped for an unknown class id — zero in a same-build session; a moving count is version skew or garbage on the port
	stat_cmd_capped:    int, // host: verbs refused by the per-player CMD_HOST_CAP — an honest client never queues this deep; a moving count names the peer flooding you
	// host: rewound queries whose reconstructed view fell PAST rewind_max and got
	// clamped to the floor (lane_rewind_view). The counter exists because the
	// clamp was the one failure in this file with no voice at all: the deep-lead
	// surplus bug killed lag comp by pushing every query past this ceiling, the
	// authority judged a half-second-old world, hit nothing, and NOTHING recorded
	// it — the pathology was found in a sibling port's engine acid, not here.
	// Counts QUERIES, not shots: a game that also calls lane_rewind_tick for
	// diagnostics on the same trigger tallies both. A moving count means this
	// shooter's view is older than the window can honor — either their lead is
	// mispaced (the controller's job) or rewind_max is genuinely too small for
	// the link you are serving.
	stat_rewind_clamped: int,

	// active inline rewind (lane_rewound_begin/end) — live captures to restore
	wound:           [dynamic]Wound,
	rewound:         bool,

	// tick-scheduled verbs (command.odin): the client's issued ledger and
	// the host's arrival queue
	cmd_seq:         Cmd_Seq, // the client's issued-command counter (command.odin)
	cmd_out:         [dynamic]Cmd_Out,
	cmd_in:          [dynamic]Cmd_In,
	cmd_exec_seq:    u32, // the command whose exec is running RIGHT NOW (0 = none) —
	                      // lane_spawn_predicted tags its projectile with it, so a
	                      // rejected fire despawns exactly the projectile it spawned

	// every-screen tick facts (mine-form _fx): the authority broadcasts one
	// SIM_FACT per event tick; a client files them here and fires the set's
	// fx thunk when the watch clock reaches the fact's tick (lane_present).
	facts:           [dynamic]Fact_In,

	// declared world-pass facts (@(gd_fact)): the package's fact table, id →
	// decode thunk, installed by the generated <snake>_lane_init. Kind 0 is
	// reserved for entity-tick facts (routed through the anchor's Sim_Set.fx).
	fact_set:        []Fact_Desc,

	// True while an AUTHORITY-ONLY context is running: the step_auth pass
	// (run_tick sets it) and every generated `_then` half (the tick and verb
	// thunks set it around the authority-gated call). lane_fact reads it for
	// the broadcast's owner skip: an everywhere-pass fact skips the anchor's
	// owner (their own live pass just presented it), but an authority-only
	// context's fact must INCLUDE them — their screen never ran the code that
	// announced it, and skipping them would orphan the fact on exactly the
	// screen it is most about.
	in_auth:         bool,

	// predicted spawns (spawn.odin): a client's own fired projectiles, tracked
	// under provisional ids until the authority's spawn arrives and rekeys them
	spawn_next:      u32, // provisional id counter (client-local, high-bit tagged)
	spawn_free:      Spawn_Free_Proc, // engine layer frees the node on despawn (nil on the core)
	spawn_free_user: rawptr,

	// A watched entity becomes PRESENTABLE the tick the delayed watch clock
	// reaches its first ledgered pose — the moment a remote muzzle's projectile
	// should actually appear (in step with the delayed barrel that fired it),
	// not the earlier moment its spawn packet merely landed. The engine layer
	// hides the node until then, so a fresh watched spawn is revealed on cue
	// instead of sitting frozen at the muzzle through the render delay.
	present_ready:      Present_Ready_Proc, // nil on the core
	present_ready_user: rawptr,
}

// Fired once per watched entity, the tick it first becomes presentable (the
// watch clock reaches its earliest ledgered tick). The engine layer reveals
// the node it created hidden.
Present_Ready_Proc :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr)

// A filed SIM_FACT: an event tick's fact tuple, waiting for the watch clock.
@(private = "file")
Fact_In :: struct {
	tick: u64,
	id:   knet.Net_Id, // the anchor (NET_ID_INVALID = an anchorless world fact)
	kind: u16, // 0 = entity-tick fact (the anchor set's fx); else a Fact_Desc id
	args: []u8, // owned — the fact tuple, wire-encoded
}

// One declared world-pass fact (@(gd_fact)): its stable wire id (an FNV-1a
// hash of the event name — the command-id law: reordering declarations never
// renumbers the wire) and its decode thunk. scriptgen emits the package's
// table; the generated lane_init installs it.
Fact_Desc :: struct {
	id: u16,       // never 0 — kind 0 on the wire means "the anchor set's tick fx"
	fx: Fx_Thunk,  // entity = the anchor (nil for an anchorless world fact)
}

// Install the package's declared-fact table — generated wiring, alongside
// lane_set_sim. Hand-built lanes (tests) may pass their own.
lane_set_facts :: proc(l: ^Lane, table: []Fact_Desc) {
	l.fact_set = table
}

@(private = "file")
fact_fx :: proc(l: ^Lane, kind: u16) -> Fx_Thunk {
	for d in l.fact_set {
		if d.id == kind {
			return d.fx
		}
	}
	return nil
}

// The tracked owner of an entity — the seat driving it (PLAYER_ID_INVALID for
// contested/world entities and anything untracked). The generated fact doors
// derive `mine` from it; games may read it wherever the census hook's stamp
// isn't at hand.
lane_owner_of :: proc(l: ^Lane, entity: rawptr) -> knet.Player_Id {
	for &tr in l.tracked {
		if tr.entity == entity {
			return tr.owner
		}
	}
	return knet.PLAYER_ID_INVALID
}

// Does the lane still track `entity` — a body it knows (tracked, not yet
// untracked)? The pointer-keyed twin of spawn.odin's lane_tracks(id), for the
// call sites that hold the entity, not its id. lane_owner_of can't answer it:
// PLAYER_ID_INVALID is also what a tracked world/contested entity owns. The
// generated anchored fact doors
// gate on this FIRST, so a fact announced on a corpse (an entity the game
// already untracked/despawned) shows NOWHERE: lane_fact already skips the
// wire (nobody to tell), fire_facts already drops a filed fact whose anchor
// died, and without this gate the authority's own screen was the one place
// it still fired (mine=false through the door's authority clause) — a
// presentation nobody else gets, on exactly the screen the author watches,
// masking the real bug (a fact meant to be seen is announced BEFORE the
// despawn). Games may read it too, wherever a handle might outlive its body.
lane_tracks_entity :: proc(l: ^Lane, entity: rawptr) -> bool {
	for &tr in l.tracked {
		if tr.entity == entity {
			return true
		}
	}
	return false
}

// The most unfired facts a client holds — an untrusted-input bound far above
// any honest burst (the watch clock drains the queue within a watch_delay).
@(private = "file")
FACT_QUEUE_CAP :: 256

// Bind to a session (host or client, before or after it starts). The app
// ROUTE survives session re-init like every pre-start hookup — but lane
// STATE does not reset with the session: a lane that must follow a fresh
// authority (new ticks, new anchor) takes lane_destroy → lane_init, the
// reset story. `input_size` is the game's input struct size, identical on
// every peer by construction (the same compiled struct).
lane_init :: proc(l: ^Lane, ses: ^ksess.Session, input_size: int, tag := SIM_TAG, cfg := Lane_Config{}, allocator := context.allocator) {
	assert(l.ses == nil, "lane_init on a live lane — lane_destroy first (re-init without teardown leaks every container and keeps a stale anchor)")
	l.allocator = allocator
	l.ses = ses
	l.tag = tag
	hz := cfg.hz > 0 ? cfg.hz : DEFAULT_SIM_HZ
	l.snap_every = cfg.snap_every > 0 ? cfg.snap_every : 3
	l.slots = cfg.slots > 0 ? cfg.slots : 128
	l.margin = cfg.margin > 0 ? cfg.margin : 2
	l.redundancy = cfg.redundancy > 0 ? cfg.redundancy : INPUT_REDUNDANCY
	l.rewind_max = cfg.rewind_max > 0 ? cfg.rewind_max : max(hz / 4, 1)
	l.watch_delay = cfg.watch_delay > 0 ? cfg.watch_delay : 2 * l.snap_every
	// The render offset rides the wire in EIGHTHS of a tick in one byte
	// (render_off8): 31 ticks is the most a screen can DECLARE. A config past
	// it would make every rewind judge shallow — refuse while a dev is
	// looking, clamp where asserts are stripped (stat_render_sat still counts
	// the saturation there).
	assert(l.watch_delay <= 31, "Lane_Config.watch_delay exceeds the 31-tick render-offset wire ceiling (render_off8)")
	l.watch_delay = min(l.watch_delay, 31)
	l.smooth_halflife = cfg.smooth_halflife > 0 ? cfg.smooth_halflife : 0.063
	l.smooth_cut = cfg.smooth_cut
	l.judge_live = cfg.judge_live
	l.echo_on = cfg.echo_inputs
	l.echo = make(map[Echo_Key][]u8, allocator)
	l.tolerance = cfg.tolerance
	if l.echo_on && l.tolerance == 0 {
		// Predict-world without slack: every held-input drift mismatches the
		// exact compare and buys a full resim — nearly every batch. Legal but
		// never what anyone means; one line at init beats a silent CPU tax.
		// (Native only: the wasm fmt has no stdio — println doesn't exist
		// there, and this line broke the whole web build once.)
		when ODIN_OS != .Freestanding {
			fmt.println("kit/sim: echo_inputs with tolerance=0 resims on nearly every batch — set Lane_Config.tolerance (world units of acceptable held-input drift)")
		}
	}
	l.ticker = sim_ticker_make(hz)
	l.tracked = make([dynamic]Tracked, allocator)
	l.entries = make([dynamic]Entry, allocator)
	l.inputs = make([dynamic]Input_Class, allocator)
	if input_size > 0 {
		// The primary input class (id 0). lane_set_sim attaches its sample;
		// extra classes ride lane_add_input_class; its TYPE (for lane_input_of)
		// is stamped by lane_class_set_type — the generated lane_init does so.
		lane_class_add(l, 0, input_size, nil, allocator)
	}
	l.rx = snap_rx_make(l.slots, allocator)
	l.pending = make([dynamic]u8, allocator)
	l.peers = make(map[knet.Player_Id]^Lane_Peer, allocator)
	l.wound = make([dynamic]Wound, allocator)
	l.cmd_out = make([dynamic]Cmd_Out, allocator)
	l.cmd_in = make([dynamic]Cmd_In, allocator)
	l.facts = make([dynamic]Fact_In, allocator)
	ksess.session_app_route(ses, tag, l, lane_handle)
}

// Register an ADDITIONAL input class beyond lane_init's primary (id 0) — a
// second entity kind the same player drives, with its own input struct. The
// generated <class>_lane_init emits one per extra @(gd_tick) input type; a
// hand-built lane calls it right after lane_init. `id` must be unique and
// agree with the Sim_Set.input_class the tracked entities of that kind carry.
lane_add_input_class :: proc(l: ^Lane, id: u16, size: int, sample: Sample_Proc, allocator := mem.Allocator{}) {
	assert(id != 0, "class 0 is lane_init's primary input — pass its size to lane_init")
	assert(size > 0, "an input class needs a non-zero size (inputless entities take no class)")
	lane_class_add(l, id, size, sample, allocator)
}

// Record a registered class's input STRUCT TYPE, so lane_input_of can name its
// class by type instead of by size (two kinds can share a size after a field
// add). The generated <game>_lane_init stamps every class right after it
// registers; a hand-built lane may stamp its own or leave them size-resolved.
// A `typeid` parameter can't carry a nil default in this Odin, which is why this
// is a separate stamp rather than an argument on lane_init/lane_add_input_class
// — and keeping it separate leaves the teaching signatures of those two clean.
lane_class_set_type :: proc(l: ^Lane, id: u16, type: typeid) {
	ic := lane_class(l, id)
	assert(ic != nil, "lane_class_set_type: no input class with this id — register it first")
	// Two classes claiming one type is no better a key than the size it replaced
	// (distinct types of the same SIZE are exactly what this resolves).
	other := class_for_type_exact(l, type)
	assert(other == nil || other == ic, "two input classes share an input struct type — each kind needs its own")
	ic.type = type
}

@(private = "file")
lane_class_add :: proc(l: ^Lane, id: u16, size: int, sample: Sample_Proc, allocator := mem.Allocator{}) {
	// Zero allocator (the default at every layer) = the LANE'S — these
	// containers free in lane_destroy under l.allocator, and an ambient
	// default here silently mismatched them for custom-allocator lanes.
	allocator := allocator.procedure != nil ? allocator : l.allocator
	assert(lane_class(l, id) == nil, "input class id registered twice")
	ic := Input_Class{id = id, size = size, sample = sample}
	if size > 0 {
		ic.ring = input_ring_make(size, l.slots, allocator)
		ic.scratch = make([]u8, size, allocator)
	}
	append(&l.inputs, ic)
}

@(private = "file")
lane_class :: proc(l: ^Lane, id: u16) -> ^Input_Class {
	for &ic in l.inputs {
		if ic.id == id {
			return &ic
		}
	}
	return nil
}

// The class that registered exactly `type`, or nil — the exact-match half of
// class_for_type, split out so lane_class_add can assert uniqueness with it.
@(private = "file")
class_for_type_exact :: proc(l: ^Lane, type: typeid) -> ^Input_Class {
	for &ic in l.inputs {
		if ic.type != nil && ic.type == type {
			return &ic
		}
	}
	return nil
}

// The class lane_input_of means when handed a typed T. Resolves by TYPE first —
// scriptgen records every class's input typeid, so the common case is exact and
// unambiguous even when two kinds share a size (the footgun this replaced: add a
// field to one input struct until it matches another's size, and the old
// size-keyed resolver asserted or, worse, silently picked the wrong class). A
// hand-built lane that registered no type falls back to size, which is
// unambiguous only if no two classes share it — the old behaviour, kept for
// consumers who never gave a type to resolve by.
@(private = "file")
class_for_type :: proc(l: ^Lane, type: typeid, size: int) -> u16 {
	if ic := class_for_type_exact(l, type); ic != nil {
		return ic.id
	}
	id: u16
	n := 0
	for &ic in l.inputs {
		if ic.size == size {
			id = ic.id
			n += 1
		}
	}
	assert(n == 1, "lane_input_of: input size ambiguous across classes and no type recorded — use lane_input with an explicit class id, or register the class with its type (the generated lane_init does)")
	return id
}

lane_destroy :: proc(l: ^Lane) {
	if l.allocator.procedure != nil {
		context.allocator = l.allocator // free under what allocated (a zero lane keeps ambient)
	}
	if l.ses != nil {
		ksess.session_app_route(l.ses, l.tag, nil, nil)
	}
	for &tr in l.tracked {
		if tr.hist != nil {
			history_destroy(tr.hist)
			free(tr.hist)
		}
		delete(tr.err)
	}
	delete(l.tracked)
	delete(l.entries)
	for &ic in l.inputs {
		if ic.size > 0 {
			input_ring_destroy(&ic.ring)
			delete(ic.scratch)
		}
	}
	delete(l.inputs)
	snap_rx_destroy(&l.rx)
	delete(l.pending)
	for _, p in l.peers {
		for _, buf in p.bufs {
			input_buffer_destroy(buf)
			free(buf)
		}
		delete(p.bufs)
		free(p)
	}
	delete(l.peers)
	for _, blob in l.echo {
		delete(blob)
	}
	delete(l.echo)
	delete(l.wound)
	for &c in l.cmd_out {
		cmd_out_free(&c)
	}
	delete(l.cmd_out)
	for c in l.cmd_in {
		delete(c.args)
	}
	delete(l.cmd_in)
	for f in l.facts {
		delete(f.args)
	}
	delete(l.facts)
	// A destroyed lane is a ZERO lane: destroy → lane_init is the reset
	// story (a re-keyed authority, back-to-lobby). Without the wipe, stale
	// anchor/rx state would drop every batch from a fresh-tick authority
	// forever, and a double init would silently leak the first containers.
	l^ = {}
}

// The game procs. `sample` may be nil on a seat that plays nobody (a
// dedicated server). Up to TWO world passes, either nil, both run after the
// entity thunks:
//
//   `step`      runs EVERYWHERE, live and resim alike — the PURE-SIM pass
//               (contact for pairs this peer has inputs for). With
//               lane_track_set entities it's often nil: entity thunks carry
//               the per-entity simulation, the step keeps only cross-entity work.
//   `step_auth` runs on the AUTHORITY alone — the role gate an authority-work
//               pass (respawn queues, adjudication sweeps, a match clock) used
//               to open with by hand. The host never resims, so it fires once
//               per real tick. A game needing both keeps them separate instead
//               of folding `if lane_is_authority()` into one pass.
lane_set_sim :: proc(l: ^Lane, user: rawptr, sample: Sample_Proc, step: Step_Proc = nil, step_auth: Step_Proc = nil) {
	l.user = user
	l.step = step
	l.step_auth = step_auth
	if sample != nil {
		// The sample fills the primary class (id 0). A game with extra input
		// kinds passes their samples through lane_add_input_class.
		if ic := lane_class(l, 0); ic != nil {
			ic.sample = sample
		} else {
			assert(false, "lane_set_sim: a sample needs an input class — pass input_size > 0 to lane_init")
		}
	}
}

// Put an entity on the sim lane — call where the entity is born on this peer
// (the factory / Ev_Spawned handler), with the owner from the spawn. The one
// role decision the lane makes lives here: the authority ledgers truth for
// everyone; a client ledgers predictions for its OWN entities and merely
// watches the rest (their truth lands from batches; lane_present draws them
// on the delayed watch clock, blending bracketing batches per field).
lane_track :: proc(l: ^Lane, id: knet.Net_Id, entity: rawptr, desc: ^knet.Entity_Desc, owner: knet.Player_Id, allocator := mem.Allocator{}) {
	allocator := allocator.procedure != nil ? allocator : l.allocator // zero = the lane's (see lane_class_add)
	assert(!l.rewound, "lane_track inside a rewound block — the restore holds pointers into the track list; lane_rewound_end first")
	assert(predict_size(desc) > 0, "lane_track: entity predicts nothing — tag fields gd:\"predict\"")
	if l.ses.is_host {
		hist := new(History, allocator)
		hist^ = history_make(desc, l.slots, allocator)
		append(&l.tracked, Tracked{id = id, entity = entity, desc = desc, owner = owner, hist = hist})
		append(&l.entries, Entry{id = id, entity = entity, hist = hist})
		return
	}
	snap_rx_add(&l.rx, id, desc, allocator)
	if owner == l.ses.me {
		hist := new(History, allocator)
		hist^ = history_make(desc, l.slots, allocator)
		append(&l.tracked, Tracked{id = id, entity = entity, desc = desc, owner = owner, hist = hist})
		append(&l.entries, Entry{id = id, entity = entity, hist = hist})
	} else {
		append(&l.tracked, Tracked{id = id, entity = entity, desc = desc, owner = owner, watched = true})
	}
}

// lane_track with the generated Sim_Set: the entity now DRIVES ITSELF — its
// tick thunk runs every simulated tick (live and resim alike) with its
// owner's input, in track order, before the game's world pass. This is the
// call the scriptgen surface reduces the game to:
//
//     ksim.lane_track_set(&self.lane, id, runner, &runner_sim_set, owner)
//
// Each input-driven set names its input CLASS (Sim_Set.input_class) — the id
// its window rides on the wire. That class must be registered (lane_init's
// primary or a lane_add_input_class extra) and agree on size; a player driving
// two entity KINDS ships one window per class each tick.
lane_track_set :: proc(l: ^Lane, id: knet.Net_Id, entity: rawptr, set: ^Sim_Set, owner: knet.Player_Id, allocator := mem.Allocator{}) {
	allocator := allocator.procedure != nil ? allocator : l.allocator // zero = the lane's (see lane_class_add)
	assert(set.tick != nil, "lane_track_set: a Sim_Set carries the tick entry point")
	if set.input_size > 0 {
		ic := lane_class(l, set.input_class)
		assert(ic != nil && ic.size == set.input_size,
			"lane_track_set: this set's input class is unregistered or its size disagrees — register it with lane_init/lane_add_input_class")
	}
	lane_track(l, id, entity, set.entity_desc, owner, allocator)
	tr := &l.tracked[len(l.tracked) - 1]
	tr.tick = set.tick
	tr.has_in = set.input_size > 0
	tr.in_class = set.input_class
	tr.cmds = set.commands
	tr.set = set
	if set.contested && tr.watched {
		// Contested: this client predicts it like its own — ledger, entries,
		// reconcile — instead of watching it from the past. PRESENTATION
		// stays claim-weighted (lane_present): the predicted timeline while
		// MY sim drives it, the watched view otherwise — so a remote touch
		// lands beside the remote avatar that made it, not a lead early.
		tr.watched = false
		tr.contested = true
		tr.hist = new(History, allocator)
		tr.hist^ = history_make(tr.desc, l.slots, allocator)
		append(&l.entries, Entry{id = id, entity = entity, hist = tr.hist})
	}
}

// MY simulation is influencing this contested entity right now — touching
// it, inside reach of it, just kicked it. Call it every tick the influence
// holds (the world pass's contact block is the natural spot): the claim
// rises INSTANTLY, so your first touch presents from your predicted
// timeline with zero delay, and decays over ~a quarter second once the
// influence stops, easing the entity back onto the watched view. This is
// net.md's "did MY simulation cause this?" boolean — the one fact the lane
// cannot derive — asked continuously.
lane_claim :: proc(l: ^Lane, id: knet.Net_Id) {
	for &tr in l.tracked {
		if tr.id == id {
			tr.claim = 1
			return
		}
	}
}

// How strongly `id` presents from MY predicted timeline right now: 1 while my sim
// is claiming it (lane_claim this tick), decaying to 0 over ~a quarter second
// after the influence stops (then it draws the watched view). A read of the same
// weight lane_present blends by — for a claim-mode game's own telemetry (a
// netgraph tint, a debug overlay) or an acid proving the claim rose on a touch.
lane_claimed :: proc(l: ^Lane, id: knet.Net_Id) -> f32 {
	for &tr in l.tracked {
		if tr.id == id {
			return tr.claim
		}
	}
	return 0
}

// Broadcast a fact to every screen that didn't simulate it live — the
// generated thunks (an entity tick's mine-form `_fx`, a declared @(gd_fact)
// door) call this on the authority. Reliable (facts are one-shots, like
// verdicts). Receivers file it and fire the matching fx thunk when their
// watch clock reaches `l.step_tick` — beside the delayed avatar that caused
// it. `kind` 0 = an entity-tick fact (routed to the anchor set's fx); a
// declared fact ships its Fact_Desc id. `entity` nil = an anchorless world
// fact (kind facts only) — no owner, everyone watches.
//
// The owner skip is PROVENANCE-AWARE: a fact from the everywhere pass skips
// the anchor's owner (their own live pass just presented it, mine=true, and
// the echo would double the flash) — but a fact minted in the AUTHORITY pass
// (l.in_auth) includes them, because their everywhere pass never ran the
// code that announced it.
//
// THE TRADE the everywhere-pass skip makes, named so it is not rediscovered as
// a bug: it ASSUMES the owner's own everywhere pass fired the same fact from the
// same input. True in the common case — the owner's input reached the host and
// both passes ran it — but it BREAKS under input loss on the firing tick: the
// host, missing that packet, HELD the owner's last input and its everywhere pass
// fired the fact from the extrapolation, while the owner's client ran its own
// FRESH input and may not have fired it. Skipped, the owner then never sees that
// one-shot. It stays a skip, not a detect, on purpose: including the owner
// whenever their input was held would DOUBLE-flash the (far more common) case
// where the held input fired the same fact on both sides — a rare miss traded
// for a rare double, no clear win, and facts are cosmetic one-shots the
// "friends, not forensics" stance already lets loss drop. The guarantee, when a
// game needs it (a fact the owner MUST see regardless of loss): fire it from the
// AUTHORITY pass instead of the everywhere pass — l.in_auth includes them by the
// rule above. That is the knob, not a flag on this call.
lane_fact :: proc(l: ^Lane, entity: rawptr, args: []u8, kind: u16 = 0) {
	assert(l.ses.is_host, "facts broadcast from the authority — the generated thunk holds this gate")
	id := knet.NET_ID_INVALID
	owner := knet.PLAYER_ID_INVALID
	if entity != nil {
		for &tr in l.tracked {
			if tr.entity == entity {
				id = tr.id
				owner = tr.owner
				break
			}
		}
		if id == knet.NET_ID_INVALID {
			// Untracked (mid-despawn): nobody left to tell. The generated doors
			// gate on lane_tracks_entity before reaching here, so their local
			// showing is skipped too; this is the belt for a hand-written caller.
			return
		}
	} else {
		assert(kind != 0, "an entity-tick fact always has its entity — nil anchors belong to declared @(gd_fact) doors")
	}
	skip := l.in_auth ? knet.PLAYER_ID_INVALID : owner
	for p in ksess.session_roster(l.ses) {
		if !p.connected || p.id == l.ses.me || (skip != knet.PLAYER_ID_INVALID && p.id == skip) {
			continue
		}
		w := ksess.session_app_begin(l.ses, l.tag)
		knet.write_u8(w, SIM_FACT)
		knet.write_u64(w, l.step_tick)
		knet.write_net_id(w, id)
		knet.write_u16(w, kind)
		knet.write_bytes(w, args)
		ksess.session_app_flush(l.ses, p.peer) // reliable: facts are one-shots
	}
}

lane_untrack :: proc(l: ^Lane, id: knet.Net_Id) -> bool {
	assert(!l.rewound, "lane_untrack inside a rewound block — the restore holds pointers into the track list; lane_rewound_end first")
	if !l.ses.is_host {
		snap_rx_remove(&l.rx, id)
	}
	for &e, i in l.entries {
		if e.id == id {
			ordered_remove(&l.entries, i)
			break
		}
	}
	for &tr, i in l.tracked {
		if tr.id == id {
			if tr.hist != nil {
				history_destroy(tr.hist)
				free(tr.hist)
			}
			delete(tr.err)
			ordered_remove(&l.tracked, i)
			return true
		}
	}
	return false
}

// Sim-lane ownership transfer — possession, the carry, the ball changing
// hands. LOCAL state transition only: the session already broadcasts the
// authoritative Ev_Owner_Changed on the reliable lane; every peer forwards
// it here (the host too — its call is what flips whose input buffer drives
// the entity and whom rewound queries spare). On a client the entity swaps
// prediction modes: gaining it starts a fresh ledger seeded from the newest
// received truth (predictions begin next tick — a one-lead-deep resim later
// corrects the seam); losing it drops the ledger and the entity becomes
// watched, presented from batches like everyone else's.
lane_set_owner :: proc(l: ^Lane, id: knet.Net_Id, owner: knet.Player_Id, allocator := mem.Allocator{}) -> bool {
	allocator := allocator.procedure != nil ? allocator : l.allocator // zero = the lane's (see lane_class_add)
	for &tr, i in l.tracked {
		if tr.id != id {
			continue
		}
		if tr.owner == owner {
			return true
		}
		tr.owner = owner
		if l.ses.is_host {
			return true // truth ledgers don't care who steers
		}
		gaining := owner == l.ses.me
		if gaining {
			tr.contested = false // mine now: the predicted timeline, no claim dance
		}
		if gaining && tr.watched {
			tr.watched = false
			// Mine now: a predicted entity is shown at once. If the reveal-gate
			// still had it hidden (a possession handed over during its first
			// render-delay of life, before the watched present loop uncovered
			// it), uncover it here — that loop no longer runs for it.
			if l.present_ready != nil {
				l.present_ready(l.present_ready_user, id, tr.entity)
			}
			tr.hist = new(History, allocator)
			tr.hist^ = history_make(tr.desc, l.slots, allocator)
			if e := find_rx(&l.rx, id); e != nil {
				if blob, ok := history_read(&e.hist, l.rx.newest); ok {
					predict_restore(tr.entity, tr.desc, blob)
					history_note_bytes(tr.hist, l.ticker.tick, blob) // the seam's baseline
				}
			}
			append(&l.entries, Entry{id = id, entity = tr.entity, hist = tr.hist})
		} else if !gaining && !tr.watched {
			for &e, j in l.entries {
				if e.id == id {
					ordered_remove(&l.entries, j)
					break
				}
			}
			history_destroy(tr.hist)
			free(tr.hist)
			tr.hist = nil
			delete(tr.err)
			tr.err = nil
			tr.watched = true
		}
		_ = i
		return true
	}
	return false
}

// A departed player's input state. kboot's event drain forwards
// Ev_Player_Left here (the same no-game-ever-forgets rule as ownership
// moves); hand-driven sessions call it from their own handler — skipping it
// leaks a few KB per departed seat and keeps popping their buffers per tick.
lane_drop_player :: proc(l: ^Lane, player: knet.Player_Id) {
	if p, ok := l.peers[player]; ok {
		for _, buf in p.bufs {
			input_buffer_destroy(buf)
			free(buf)
		}
		delete(p.bufs)
		free(p)
		delete_key(&l.peers, player)
	}
}

// The input driving `player`'s entities of `class` for the tick being stepped
// — valid ONLY inside your Step_Proc (live or resim, same answer). ok=false
// means no input exists here for that player+class this tick: a client asking
// about remote players (predict-self — coast them, their truth is on the way),
// a held gap on the host (the returned bytes then repeat their last real
// input). `class` defaults to 0, the single-input lane's only class.
lane_input :: proc(l: ^Lane, player: knet.Player_Id, class: u16 = 0) -> (input: []u8, ok: bool) {
	if player == l.ses.me {
		if ic := lane_class(l, class); ic != nil && ic.size > 0 {
			return input_read(&ic.ring, l.step_tick)
		}
		return nil, false
	}
	if l.ses.is_host {
		if p, found := l.peers[player]; found {
			if buf, has := p.bufs[class]; has {
				return buf.held, buf.fresh
			}
		}
		return nil, false
	}
	if l.echo_on {
		// Predict-world: a remote player's LAST-KNOWN input for this class (the
		// batch echo) — held, never fresh; the extrapolation every peer ticks
		// remotes with, corrected by the next batch's truth.
		if held, found := l.echo[Echo_Key{player, class}]; found {
			return held, false
		}
	}
	return nil, false
}

// The typed view of lane_input, for the world pass:
//
//	input, drives := ksim.lane_input_of(&g.lane, owner, Kicker_Input)
//	if !drives {continue} // a pair this peer doesn't simulate
//
// `drives` means an input EXISTS to drive with — held gaps repeat the last
// real one, because driving through loss is the point; the raw lane_input's
// ok is the FRESHNESS bit, for the rare caller that cares. The class is
// resolved from T's TYPE (scriptgen records it at registration), so two input
// kinds that happen to share a size no longer collide; a hand-built lane that
// registered no type falls back to size and must call lane_input with an
// explicit id if two kinds share one.
lane_input_of :: proc(l: ^Lane, player: knet.Player_Id, $T: typeid) -> (input: T, drives: bool) {
	bytes, _ := lane_input(l, player, class_for_type(l, T, size_of(T)))
	if bytes == nil {
		return {}, false
	}
	assert(len(bytes) == size_of(T), "lane_input_of: not this lane's input struct (size mismatch)")
	return (cast(^T)raw_data(bytes))^, true
}

// The tick being stepped — for tick procs that derive per-tick values
// (ksim RNG seeds, cooldown arithmetic) without touching a wall clock.
lane_now :: proc(l: ^Lane) -> u64 {
	return l.step_tick
}

// Accessors for GENERATED thunk routing (games rarely need them): the sim
// hookup's user pointer (the game — `<tick>_then`/`<tick>_fx` receive it
// typed), whether this peer is the authority, and who this peer is.
lane_game :: proc(l: ^Lane) -> rawptr {
	return l.user
}

lane_is_authority :: proc(l: ^Lane) -> bool {
	return l.ses.is_host
}

lane_me :: proc(l: ^Lane) -> knet.Player_Id {
	return l.ses.me
}

// lane_lead — the client's WORKING LEAD in ticks: how far its predicted head
// runs ahead of the server's newest input ack. The headroom the whole model
// rests on (inputs for tick T must land just before the server sims T); a
// healthy lead hovers near Lane_Config.margin, a starved one dips toward zero
// under a spike. Zero on the host (it IS the server) and before the first
// batch anchors the client. A netgraph datum — see kit/ui/netgraph.
lane_lead :: proc(l: ^Lane) -> int {
	if l.ses.is_host || l.input_ack == 0 {
		return 0
	}
	return int(l.ticker.tick) - int(l.input_ack)
}

// lane_live — is this the LIVE pass, whose side effects should fire ONCE
// (prints, sounds, particles), as opposed to a resim replay of history? The
// gate every game hand-wrote as `!lane.resimming` inside tick and step
// bodies. Entity-tick facts get it FREE through their `_fx` halves (the
// generated thunk holds this gate); inline presentation in a tick body or a
// world pass (@(gd_step)) reads it here — never the raw field.
lane_live :: proc(l: ^Lane) -> bool {
	return !l.resimming
}

// ---------------------------------------------------------------------------
// The frame drive.

// Advance the sim lane; call once per frame beside session_tick. Returns how
// many sim ticks ran. A client returns 0 until the first batch anchors it to
// the server's timeline.
lane_frame :: proc(l: ^Lane, dt: f64) -> int {
	context.allocator = l.allocator // lane work rides the lane's allocator (see the field)
	if l.ses.is_host {
		return host_frame(l, dt)
	}
	return client_frame(l, dt)
}

// One simulated tick, everywhere ticks happen — the live host loop, the live
// client loop, and the resim replay all funnel here so an entity can never
// behave differently between a prediction and its replay. Entity thunks
// first (track order — deterministic per peer because spawns ride the
// reliable ordered channel), then the game's world pass.
@(private = "file")
run_tick :: proc(l: ^Lane, t: u64) {
	l.step_tick = t
	// Index-based, re-fetching each iteration: a tick's _fx/_then may SPAWN a
	// projectile (lane_spawn_predicted / lane_track_set), which appends to
	// l.tracked and can REALLOCATE it — a `for &tr` pointer would dangle. A
	// freshly appended entity is born THIS tick, so the born gate below skips it.
	for i := 0; i < len(l.tracked); i += 1 {
		tr := &l.tracked[i]
		if tr.tick == nil || tr.watched {
			continue
		}
		if tr.born != 0 && t <= tr.born {
			// Not born yet, or the spawn tick itself (which holds the unticked
			// spawn state — a predicted spawn is created AFTER the thunk pass, in
			// run_cmds). During a resim that crosses the spawn, reseed from the
			// ledger so flight restarts from the spawn state, not the stale head
			// a failed rewind left behind.
			if l.resimming && t == tr.born && tr.hist != nil {
				history_restore(tr.hist, tr.born, tr.entity)
			}
			continue
		}
		in_ptr: rawptr
		if tr.has_in {
			if in_bytes, _ := lane_input(l, tr.owner, tr.in_class); in_bytes != nil {
				in_ptr = raw_data(in_bytes)
			}
		}
		tr.tick(tr.entity, in_ptr, l, tr.owner)
	}
	// Tick-scheduled verbs: after entity thunks, before the world pass —
	// ticks integrate, verbs mutate the settled state, the world pass
	// adjudicates (command.odin).
	run_cmds(l, t)
	// The everywhere pass first (contact settles), then the authority pass
	// reads that settled state to adjudicate. The host is never resimming, so
	// its authority pass fires exactly once per real tick. The in_auth flag
	// marks the pass for lane_fact's provenance-aware owner skip.
	if l.step != nil {
		l.step(l.user, t)
	}
	if l.step_auth != nil && l.ses.is_host {
		l.in_auth = true
		l.step_auth(l.user, t)
		l.in_auth = false
	}
}

// Sample every input class this seat plays (each with a sample proc), noting
// the result into that class's ring — the local half of prediction. Runs on
// both the host (for its own avatar) and the client. A class the seat doesn't
// actually drive still samples harmlessly (neutral bytes drive nothing), which
// keeps the wire shape identical on every peer.
@(private = "file")
sample_inputs :: proc(l: ^Lane, t: u64) {
	for &ic in l.inputs {
		if ic.sample != nil && ic.size > 0 {
			ic.sample(l.user, t, raw_data(ic.scratch))
			input_note(&ic.ring, t, raw_data(ic.scratch))
		}
	}
}

@(private = "file")
host_frame :: proc(l: ^Lane, dt: f64) -> int {
	n := sim_ticker_advance(&l.ticker, dt)
	for t := l.ticker.tick - u64(n) + 1; t <= l.ticker.tick; t += 1 {
		sample_inputs(l, t)
		for _, p in l.peers {
			// One packet feeds every class, so the riders USUALLY agree — but
			// a held gap on one class retains its stale rider while another
			// advances, and "last wins" in map order let iteration order pick
			// this seat's rewind depth. Take the newest deterministically:
			// the tag is (ack<<8)|off, so the plain max is the freshest ack.
			best := u64(0)
			for _, buf in p.bufs {
				input_buffer_pop(buf, t) // sets buf.fresh
				best = max(best, buf.tag)
			}
			if best != 0 {
				p.tag = best
			}
		}
		run_tick(l, t)
		note_all(l.entries[:], t)
		if t % u64(l.snap_every) == 0 {
			snap_broadcast(l, t)
		}
	}
	return n
}

// One batch per connected client, each against ITS acked baseline, carrying
// ITS input ack. The host player itself never gets one (no transport
// loopback, and it holds the truth already).
@(private = "file")
snap_broadcast :: proc(l: ^Lane, tick: u64) {
	for p in ksess.session_roster(l.ses) {
		if !p.connected || p.id == l.ses.me {
			continue
		}
		acked, input_ack := u64(0), u64(0)
		if lp, ok := l.peers[p.id]; ok {
			acked = lp.acked
			input_ack = peer_input_ack(lp)
		}
		w := ksess.session_app_begin(l.ses, l.tag)
		knet.write_u8(w, SIM_SNAP)
		snap_write(w, l.entries[:], tick, acked, input_ack)
		if l.echo_on {
			echo_write(l, w, tick)
		}
		ksess.session_app_flush(l.ses, p.peer, .Stream)
	}
}

// The input ack a batch ships is the MIN newest across the player's class
// buffers — the client leads enough for its most-starved input and trims every
// ring by this conservative floor. 0 until the player has sent anything.
@(private = "file")
peer_input_ack :: proc(p: ^Lane_Peer) -> u64 {
	m := max(u64)
	any := false
	for _, buf in p.bufs {
		if !any || buf.newest < m {
			m = buf.newest
			any = true
		}
	}
	return any ? m : 0
}

// The predict-world rider: every player's input AS THE SERVER SIMULATED IT
// this tick (its own from the rings, each peer's from the hold-last buffers),
// appended after the batch rows — [count u8] count × [player u64][class u16]
// [bytes]. One row per (player, class): a player driving two kinds echoes both.
// Clients tick remote contested entities from these held inputs, which is
// what puts every avatar on one predicted timeline.
@(private = "file")
echo_write :: proc(l: ^Lane, w: ^knet.Writer, tick: u64) {
	count_at := len(w.buf)
	knet.write_u8(w, 0)
	count := 0
	for &ic in l.inputs {
		if ic.sample != nil && ic.size > 0 {
			if blob, ok := input_read(&ic.ring, tick); ok {
				knet.write_player_id(w, l.ses.me)
				knet.write_u16(w, ic.id)
				append(&w.buf, ..blob)
				count += 1
			}
		}
	}
	for pid, p in l.peers {
		for cid, buf in p.bufs {
			knet.write_player_id(w, pid)
			knet.write_u16(w, cid)
			append(&w.buf, ..buf.held)
			count += 1
		}
	}
	w.buf[count_at] = u8(count)
}

@(private = "file")
client_frame :: proc(l: ^Lane, dt: f64) -> int {
	client_ingest(l)
	if !l.anchored {
		return 0
	}
	cmd_settle(l) // land verdicts/timeouts on the frame, not in a handler
	lane_spawn_sweep(l) // reap lost predicted spawns (a fire no authority spawn claimed)
	n := sim_ticker_advance(&l.ticker, dt)
	if n > 0 {
		// Fields may hold last frame's PRESENTED values (sim + decaying
		// error) — the ledger is the sim truth, so re-seed from it before
		// ticking. This one restore is what lets presentation vandalize the
		// fields freely between frames.
		head := l.ticker.tick - u64(n)
		for &e in l.entries {
			_ = history_restore(e.hist, head, e.entity)
		}
	}
	for t := l.ticker.tick - u64(n) + 1; t <= l.ticker.tick; t += 1 {
		sample_inputs(l, t)
		run_tick(l, t)
		note_all(l.entries[:], t)
	}
	plays := false
	for &ic in l.inputs {
		if ic.sample != nil && ic.size > 0 {
			plays = true
			break
		}
	}
	if n > 0 && plays {
		// Ack FIRST: the receiver tags every input in this packet with it —
		// the snap ack is the sender's world view, and binding them is what
		// lets a rewound query judge the view each input was AIMED with. The
		// render offset beside it says WHERE INSIDE that view the watch clock
		// was drawing (fractional ticks behind the ack, 1/8-tick fixed point):
		// a bounded claim — the server clamps it inside the window the ack
		// proves — that lets the rewind BLEND the same bracket the shooter's
		// screen blended, instead of quantizing to a tick.
		//
		// Then one window PER CLASS this seat plays — a class count, then each
		// class's id and its redundant input window. A single-input game writes
		// count 1; a player driving two kinds writes both. Every ring trims by
		// the same min ack (l.input_ack), the conservative floor.
		w := ksess.session_app_begin(l.ses, l.tag)
		knet.write_u8(w, SIM_INPUT)
		snap_ack_write(w, &l.rx)
		knet.write_u8(w, render_off8(l))
		count_at := len(w.buf)
		knet.write_u8(w, 0) // class count, patched below
		cnt := 0
		for &ic in l.inputs {
			if ic.sample != nil && ic.size > 0 {
				knet.write_u16(w, ic.id)
				input_write(w, &ic.ring, l.input_ack, l.redundancy)
				cnt += 1
			}
		}
		w.buf[count_at] = u8(cnt)
		ksess.session_app_flush(l.ses, ksess.HOST_PEER, .Stream)
	}
	return n
}

// How far behind the acked batch this screen is DRAWING watched entities, in
// 1/8-tick units. Falls back to the watch target when the clock hasn't run
// (a game that never presents keeps the old single-tick behavior).
@(private = "file")
render_off8 :: proc(l: ^Lane) -> u8 {
	off := f64(l.watch_delay)
	if l.watch_clock > 0 && f64(l.rx.acked) > l.watch_clock {
		off = f64(l.rx.acked) - l.watch_clock
	}
	if off > 31.5 {
		// The wire ceiling (u8 in 1/8 ticks): a screen running further behind
		// than this REPORTS the ceiling, so the authority's lag comp rewinds
		// less than the shooter's true delay and shots judge shallow. Counted
		// — a moving tally is a stall/overload symptom, not a tuning knob.
		l.stat_render_sat += 1
	}
	off = clamp(off, 0, min(f64(2 * l.watch_delay + 4), 31.5))
	return u8(off * 8)
}

// Process the newest batch the handler filed: anchor or reconcile the
// predicted set, land watched truth, and bend the clock off the ack echo.
@(private = "file")
client_ingest :: proc(l: ^Lane) {
	if len(l.pending) == 0 {
		return
	}
	truths := make([dynamic]Truth, context.temp_allocator)
	r := knet.reader_make(l.pending[:])
	tick, input_ack, _ := snap_rx_apply(&l.rx, &r, &truths)
	if tick != 0 && l.echo_on {
		// The predict-world rider follows the rows: last-known inputs for
		// every (player, class), last-value by batch (older batches dropped).
		// The class id gives the byte width — the receiver knows every class.
		ec := int(knet.read_u8(&r))
		for _ in 0 ..< ec {
			pid := knet.read_player_id(&r)
			cid := knet.read_u16(&r)
			ic := lane_class(l, cid)
			sz := ic != nil ? ic.size : 0
			if r.err || sz == 0 {
				break
			}
			blob := knet.reader_view(&r, sz)
			if r.err {
				break
			}
			if pid == l.ses.me {
				continue // my inputs live in my rings
			}
			key := Echo_Key{pid, cid}
			held, ok := l.echo[key]
			if !ok {
				held = make([]u8, sz)
				l.echo[key] = held
			}
			copy(held, blob)
		}
	}
	clear(&l.pending)
	l.pending_tick = 0
	if tick == 0 {
		return
	}
	ack_advanced := input_ack > l.input_ack // the server is still HEARING us
	l.input_ack = input_ack

	if !l.anchored {
		// First contact: adopt the truth outright and start predicting AHEAD
		// of it — the transit the input must cover (rtt/2 + jitter allowance,
		// from the session's clock sync) plus `margin` ticks of server-side
		// headroom. The old anchor used margin alone, so a distant client's
		// first seconds ran short and the controller grew the lead one nudge
		// at a time — inputs arriving late exactly while first impressions
		// form. A cold clock (no pong yet) reads rtt 0 and the margin stands;
		// the controller trims whatever the seed overshoots.
		for tr in truths {
			apply_truth(l, tr)
			if e := find_lane_entry(l, tr.id); e != nil {
				history_note_bytes(e.hist, tick, tr.blob)
			}
		}
		lead := l.margin
		if clock := ksess.session_clock(l.ses, ksess.HOST_PEER); clock.rtt > 0 {
			lead = max(lead, lead_target(&clock, l.ticker.dt, slack_ticks = l.margin))
		}
		l.ticker.tick = tick + u64(lead) + 1
		l.anchored = true
		return
	}

	// Pre-bracket (fewer than two applied batches) OR a game that has never
	// called lane_present: ingest paints watched truth directly. The latch
	// keeps the render_off8 promise honest — before it, a hand-driven client
	// that skipped lane_present froze every watched entity at the second
	// batch forever, because nobody else would ever paint them again.
	watched_fallback := l.rx.applied_count < 2 || !l.presented
	l.stat_reconciles += 1
	// What the screen last showed, per predicted entity — the continuity a
	// correction must glide from. Fields hold last present's visual (or the
	// sim state if the game never presents; either way, what was drawn).
	shown := make([][]u8, len(l.entries), context.temp_allocator)
	for &e, i in l.entries {
		shown[i] = make([]u8, e.hist.size, context.temp_allocator)
		predict_capture(shown[i], e.entity, e.hist.desc)
	}
	mism := make([dynamic]knet.Net_Id, context.temp_allocator)
	l.resimming = true
	l.stat_resims += reconcile(l.entries[:], truths[:], tick, l.ticker.tick, l, client_resim, &mism, l.tolerance)
	l.resimming = false
	cmd_retire(l, tick) // ticks at or before the truth are settled history
	for id in mism {
		for &tr, i in l.tracked {
			if tr.id != id || tr.hist == nil {
				continue
			}
			if tr.err == nil {
				tr.err = make([]u8, tr.hist.size)
			}
			// Fields now hold the corrected head state; err = shown − truth
			// (which folds any prior error in — continuity is transitive).
			truth_now := make([]u8, tr.hist.size, context.temp_allocator)
			predict_capture(truth_now, tr.entity, tr.desc)
			for &e, j in l.entries {
				if e.id == id {
					predict_error(tr.err, shown[j], truth_now, tr.desc, l.smooth_cut)
					break
				}
			}
			break
		}
	}
	// Watched fields belong to the PRESENTER once a bracket exists: between
	// ingest and lane_present they must keep holding last frame's DELAYED
	// view — that is what the player's screen shows, what their aim samples
	// mean, and what the server's rewound judgment reconstructs. Painting
	// fresh truth here would let a sample read a future nobody rendered.
	// Before two batches exist there is nothing to blend, so ingest paints.
	if watched_fallback {
		for tr in truths {
			if find_lane_entry(l, tr.id) == nil {
				apply_truth(l, tr)
			}
		}
	}

	// input_ack − tick = how far our inputs ran ahead of the server's sim
	// when this batch left: the observed lead. Small errors BEND the clock;
	// a hole too deep to bend out of inside a second — the fresh anchor
	// under real transit (the batch we anchored to was already a transit
	// old), or a long stall — JUMPS the head instead. Skipped ticks are
	// never simulated or ledgered: the server holds-last through the gap
	// and the next reconcile seeds the new timeline. Until the first input
	// ack exists there is nothing to measure, so probe forward briskly.
	// A FROZEN ack is the other story — an upstream blackout, not a lead
	// deficit — and jumping on it would run away forward; there the bend's
	// saturation is the honest response and redundancy does the healing.
	observed := f64(i64(input_ack) - i64(tick))
	err := f64(l.margin) - observed
	if input_ack == 0 {
		l.ticker.tick += 3 // nothing acked yet: probe forward briskly
		lead_control(&l.ticker, 0)
	} else if err > LEAD_DEEP_TICKS && ack_advanced {
		l.ticker.tick += u64(err) // deep DEFICIT: jump the head, the gap holds last
		lead_control(&l.ticker, 0)
	} else if err < -LEAD_DEEP_TICKS && ack_advanced {
		// Deep SURPLUS: we are needlessly far ahead and every tick of it is
		// input latency the player pays for nothing. This cannot jump — the
		// head only moves forward (tick.odin's LEAD_DEEP_TICKS says why) — so
		// it bends HARD instead, and hands back to the fine bend at the same
		// threshold its mirror does. Gated on ack_advanced for the same reason
		// the deficit rung is: a frozen ack drives `observed` down, never up,
		// so a surplus measured against a dead upstream is not a surplus.
		lead_control(&l.ticker, err, SCALE_NUDGE_DEEP)
	} else {
		lead_control(&l.ticker, err)
	}
}

@(private = "file")
client_resim :: proc(user: rawptr, tick: u64) {
	l := cast(^Lane)user
	run_tick(l, tick) // the SAME tick path as the live frame — no sampling, no sends
}

@(private = "file")
apply_truth :: proc(l: ^Lane, tr: Truth) {
	for &t in l.tracked {
		if t.id == tr.id {
			predict_restore(t.entity, t.desc, tr.blob)
			return
		}
	}
}

@(private = "file")
find_lane_entry :: proc(l: ^Lane, id: knet.Net_Id) -> ^Entry {
	for &e in l.entries {
		if e.id == id {
			return &e
		}
	}
	return nil
}

// ---------------------------------------------------------------------------
// Lag compensation: judge a shot where the SHOOTER saw the target.
//
// The rewind tick is DERIVED, never trusted: the shooter's newest snap ack is
// a fact (they provably applied that batch — it is their delta baseline), and
// what they rendered when they pressed fire is within a batch interval of it.
// Clamped to rewind_max, the favor-the-shooter ceiling: past it, a laggy
// shooter aims at the live world like everyone else.

// The view a rewound query for `shooter` reconstructs (host, inside a step):
// the bracketing lower tick and the blend fraction toward the next — the
// SAME pair-and-alpha shape their watch clock drew with. Sources, in trust
// order: the ack bound to the INPUT BEING EXECUTED (a fact — it rode the
// trigger's packet; the shooter's latest ack is a whole lead-plus-transit
// fresher and describes a world they never saw), minus the render offset
// that rode beside it (a claim, clamped inside the window the ack proves).
lane_rewind_view :: proc(l: ^Lane, shooter: knet.Player_Id) -> (lo: u64, alpha: f32) {
	assert(l.ses.is_host, "lag compensation is the authority's job")
	t := l.step_tick
	if shooter == l.ses.me {
		return t, 0 // the host's own screen IS the live world
	}
	tag := u64(0)
	if p, ok := l.peers[shooter]; ok {
		tag = p.tag
	}
	ack := tag >> 8
	if ack == 0 || ack >= t {
		return t, 0 // no confirmed view yet: judge live
	}
	off := clamp(f64(tag & 0xFF) / 8, 0, min(f64(2 * l.watch_delay + 4), 31.5))
	view := f64(ack) - off
	floor_ := t > u64(l.rewind_max) ? t - u64(l.rewind_max) : 1
	if view <= f64(floor_) {
		l.stat_rewind_clamped += 1
		return floor_, 0 // the favor-the-shooter ceiling
	}
	lo = u64(view)
	return lo, f32(view - f64(lo))
}

// The whole-tick floor of the view — kept for callers that only need the
// bound (diagnostics, damage falloff by age).
lane_rewind_tick :: proc(l: ^Lane, shooter: knet.Player_Id) -> u64 {
	lo, _ := lane_rewind_view(l, shooter)
	return lo
}

Rewound_Query :: proc(user: rawptr)

@(private = "file")
Wound :: struct {
	tr:   ^Tracked,
	live: []u8,
}

// Run `query` against the world as `shooter` rendered it: every tracked
// entity EXCEPT the shooter's own is wound back to lane_rewind_tick for the
// duration, then the live state returns — snapshots via the truth ledger,
// the exact same bytes the shooter's screen was drawn from. Entities whose
// ledger no longer holds the tick stay live (a fresh spawn the shooter
// couldn't have seen anyway). Host-only, inside your Step_Proc; returns the
// tick the world was judged at.
//
// This is exactly lane_rewound_begin + query + lane_rewound_end — take the
// inline pair when a context struct just to cross the rawptr boundary would
// outweigh the hit test itself.
lane_rewound :: proc(l: ^Lane, shooter: knet.Player_Id, user: rawptr, query: Rewound_Query) -> u64 {
	judged := lane_rewound_begin(l, shooter)
	query(user)
	lane_rewound_end(l)
	return judged
}

// The inline form: wind the world back to what `shooter`'s screen showed,
// write the hit test right here, then put the world back —
//
//	judged := ksim.lane_rewound_begin(&g.lane, by)
//	for id, gun in g.gunners { ... }  // every OTHER entity stands where the
//	                                  // shooter saw it; their own stay live
//	ksim.lane_rewound_end(&g.lane)
//
// Same contract as lane_rewound: host-only, inside your step; returns the
// judged tick. Begin and end must pair within the same frame (captures ride
// the temp allocator), never nest, and nothing may track/untrack lane
// entities in between (the restore holds pointers into the track list).
lane_rewound_begin :: proc(l: ^Lane, shooter: knet.Player_Id) -> u64 {
	assert(!l.rewound, "lane_rewound_begin: the world is already rewound — pair every begin with lane_rewound_end")
	l.rewound = true
	lo, alpha := lane_rewind_view(l, shooter)
	if l.judge_live {
		lo = l.step_tick // the A/B knob: judge the live world
	}
	if lo >= l.step_tick {
		return l.step_tick
	}
	// Wind every target back to the BLENDED pose the shooter's screen drew —
	// the same bracket pair and fraction their watch clock used, from the
	// truth ledger (single-tick rewind quantized against the interpolation
	// and cost near-tangent shots; the duel acid measured it).
	for &tr in l.tracked {
		if tr.owner == shooter || tr.hist == nil {
			continue
		}
		a, aok := history_read(tr.hist, lo)
		if !aok {
			continue // the ledger no longer holds it (fresh spawn): test live
		}
		live := make([]u8, tr.hist.size, context.temp_allocator)
		predict_capture(live, tr.entity, tr.desc)
		b, bok := history_read(tr.hist, lo + 1)
		if alpha > 0.001 && bok {
			predict_blend(tr.entity, tr.desc, a, b, alpha)
		} else {
			predict_restore(tr.entity, tr.desc, a)
		}
		append(&l.wound, Wound{tr = &tr, live = live})
	}
	return lo
}

lane_rewound_end :: proc(l: ^Lane) {
	assert(l.rewound, "lane_rewound_end without a begin")
	l.rewound = false
	for w in l.wound {
		predict_restore(w.tr.entity, w.tr.desc, w.live)
	}
	clear(&l.wound)
}

// ---------------------------------------------------------------------------
// Watched-entity presentation: the render clock for other people's avatars.
//
// Ingest lands watched truth as it arrives — correct, but stepping at the
// snap rate. lane_present renders them on a delayed tick timeline instead:
// a watch clock trails the newest applied batch by watch_delay ticks (so a
// bracketing PAIR of batches almost always exists), advances with frame
// time, and gets pulled gently toward its target — jitter becomes a slowly
// breathing delay, not a stutter. Blending honors Lerp_Kind per field
// (predict_blend); past the newest batch it clamps and HOLDS, never
// extrapolates. Call once per frame AFTER lane_frame, client-side (host and
// unanchored clients no-op). Predicted (own) entities are untouched — their
// freshness is the whole point of prediction.

lane_present :: proc(l: ^Lane, dt: f64) {
	context.allocator = l.allocator // same rule as lane_frame
	l.presented = true // the presenter owns watched fields from here (see watched_fallback)
	if l.ses.is_host || !l.anchored || l.rx.applied_count == 0 {
		return
	}
	target := f64(l.rx.applied[l.rx.applied_count - 1]) - f64(l.watch_delay)
	if l.watch_clock == 0 {
		l.watch_clock = target // first frame: start on target
	}
	l.watch_clock += dt / l.ticker.dt // advance in tick units
	drift := target - l.watch_clock
	if abs(drift) > f64(2 * l.watch_delay) {
		l.watch_clock = target // a real discontinuity (stall, rejoin): cut
	} else {
		l.watch_clock += drift * 0.1 // breathe toward the target
	}

	// The OWN avatar: sim truth plus the decaying reconcile error — authority
	// snapped at ingest, the eye glides here. Restoring from the ledger first
	// makes a double present harmless (idempotent per frame).
	if l.smooth_halflife > 0 {
		for &tr in l.tracked {
			if tr.watched || tr.hist == nil || tr.err == nil {
				continue
			}
			if !history_restore(tr.hist, l.ticker.tick, tr.entity) {
				continue
			}
			// Per-field half-life: each field decays at its own glide (or the
			// lane default). The gate above stays a lane-level fast out.
			predict_error_decay(tr.err, tr.desc, dt, l.smooth_halflife)
			predict_error_apply(tr.entity, tr.desc, tr.err)
		}
	}

	prev, next, ok := snap_rx_bracket(&l.rx, l.watch_clock)
	if !ok {
		fire_facts(l) // ingest's snap stands, but ripe facts still present
		return // fewer than two batches (or pre-window)
	}
	for &tr in l.tracked {
		if !tr.watched && !tr.contested {
			continue
		}
		if tr.contested {
			// PREDICT-WORLD (echo mode): one timeline — every contested
			// entity presents its predicted pose (glide included), because
			// every avatar that could touch it is predicted too. The claim
			// dance exists only for MIXED timelines.
			if l.echo_on {
				continue
			}
			// The claim-weighted timeline. Fully mine: the predicted pose
			// (already in the fields, glide included) stands — your dribble
			// answers your feet. Unclaimed: the watched view, so a REMOTE
			// touch moves the ball beside the remote avatar that made it
			// instead of a whole lead early (the mixed-timelines artifact).
			// Between: blend, easing ~a quarter second back to watched.
			tr.claim = max(tr.claim - f32(dt / 0.25), 0)
			if tr.claim >= 0.999 {
				continue
			}
		}
		e := find_rx(&l.rx, tr.id)
		if e == nil {
			continue
		}
		// Reveal on cue: the tick the delayed clock reaches this entity's first
		// ledgered pose is the tick it should APPEAR — a remote muzzle's shot
		// emerges as the delayed barrel fires it, not a render delay early. The
		// boot created the node hidden; this uncovers it, exactly once.
		if !e.revealed && e.first != 0 && l.watch_clock >= f64(e.first) {
			e.revealed = true
			if l.present_ready != nil {
				l.present_ready(l.present_ready_user, tr.id, tr.entity)
			}
		}
		// Clamp the bracket UP to the entity's first ledgered tick. A fresh
		// watched spawn (a projectile that just left a remote muzzle) has no
		// truth before `first`, and the delayed watch clock sits a `watch_delay`
		// behind it — so hold it AT that first pose (the muzzle) until the clock
		// arrives, then let it fly. Without this it holds the node's stale value
		// (its scene default) and pops into place a watch_delay late, off the
		// barrel that fired it. Long-lived entities have `first` far in the past,
		// so lo/hi are prev/next and this is a no-op for them.
		lo, hi := prev, next
		if lo < e.first {
			lo = e.first
		}
		if hi < e.first {
			hi = e.first
		}
		a, aok := history_read(&e.hist, lo)
		b, bok := history_read(&e.hist, hi)
		if !aok || !bok {
			continue // a skipped row at one end: hold ingest's last apply
		}
		alpha := f32(0)
		if hi > lo {
			alpha = clamp(f32((l.watch_clock - f64(lo)) / f64(hi - lo)), 0, 1)
		}
		if tr.contested && tr.claim > 0.001 {
			// Mid-fade: capture the predicted pose, paint the watched view,
			// then blend the two by the claim.
			pred := make([]u8, tr.hist.size, context.temp_allocator)
			predict_capture(pred, tr.entity, tr.desc)
			predict_blend(tr.entity, tr.desc, a, b, alpha)
			watched := make([]u8, tr.hist.size, context.temp_allocator)
			predict_capture(watched, tr.entity, tr.desc)
			predict_blend(tr.entity, tr.desc, watched, pred, tr.claim)
			continue
		}
		predict_blend(tr.entity, tr.desc, a, b, alpha)
	}
	// Facts fire AFTER the blend, so a muzzle flash reads the same delayed
	// pose the screen draws this frame — the flash lands ON the barrel.
	fire_facts(l)
}

// Land every filed fact whose tick the watch clock has reached: fire the
// matching fx thunk with mine=false — kind 0 routes to the anchor set's
// tick fx, a declared kind to the package fact table. An entity untracked
// since filing (a despawn racing the render delay) drops its facts — the
// edge-outlives-observers law is the game's to honor (dwell the despawn,
// sim.md). An ANCHORLESS fact (id 0) has nothing to outlive and always fires.
@(private = "file")
fire_facts :: proc(l: ^Lane) {
	if l.watch_clock == 0 {
		return // the render clock hasn't started: hold facts until it exists
	}
	for i := 0; i < len(l.facts); {
		f := &l.facts[i]
		if f64(f.tick) > l.watch_clock {
			i += 1
			continue
		}
		// Copy the handles out before calling game code: presentation may not
		// track/untrack, but a dangling &tr across a call is not a bet.
		fx: Fx_Thunk
		entity: rawptr
		anchored := f.id != knet.NET_ID_INVALID
		if anchored {
			for &tr in l.tracked {
				if tr.id == f.id {
					if f.kind == 0 && tr.set != nil {
						fx = tr.set.fx
					}
					entity = tr.entity
					break
				}
			}
		}
		if f.kind != 0 && (!anchored || entity != nil) {
			fx = fact_fx(l, f.kind)
		}
		args := f.args
		ordered_remove(&l.facts, i)
		if fx != nil {
			fx(entity, l, false, args)
		}
		delete(args)
	}
}


// ---------------------------------------------------------------------------
// The receive side: bytes into lane state, game code never re-entered here.

@(private = "file")
lane_handle :: proc(user: rawptr, from: knet.Player_Id, from_peer: ksess.Peer_Id, r: ^knet.Reader) {
	l := cast(^Lane)user
	context.allocator = l.allocator // handler-side allocs must free under the same allocator later
	kind := knet.read_u8(r)
	if r.err {
		return
	}
	switch kind {
	case SIM_INPUT:
		// Host only; the session already resolved the seat (unseated peers
		// never reach a handler with a valid `from`). A watching seat drives
		// nobody — its windows are refused before a buffer ever exists.
		if !l.ses.is_host || from == knet.PLAYER_ID_INVALID {
			return
		}
		if sp, seated := ksess.session_player(l.ses, from); seated && sp.spectator {
			return
		}
		p, ok := l.peers[from]
		if !ok {
			p = new(Lane_Peer)
			p.bufs = make(map[u16]^Input_Buffer)
			l.peers[from] = p
		}
		acked := snap_ack_read(r)
		off8 := knet.read_u8(r)
		// One rider per input: the ack AND the render offset that traveled
		// with it, packed (ticks fit 56 bits by ~38 million years).
		tag := (acked << 8) | u64(off8)
		// One window per class the sender drives, into the matching per-player
		// buffer (created on first sight, sized from the class the build
		// registered). An unknown class can't be length-skipped safely, so it
		// drops the packet's tail — every peer runs the same build regardless.
		ccount := int(knet.read_u8(r))
		if r.err {
			return
		}
		for _ in 0 ..< ccount {
			cid := knet.read_u16(r)
			if r.err {
				return // truncation — the session's malformed counter owns it
			}
			ic := lane_class(l, cid)
			if ic == nil || ic.size == 0 {
				l.stat_input_drops += 1 // the tail can't be length-skipped; counted, never silent
				return
			}
			buf, has := p.bufs[cid]
			if !has {
				buf = new(Input_Buffer)
				buf^ = input_buffer_make(ic.size, l.slots)
				p.bufs[cid] = buf
			}
			input_buffer_apply(buf, r, tag = tag)
		}
		if !r.err && acked > p.acked {
			p.acked = acked // regressions are stale reordering, not truth
		}
	case SIM_CMD:
		// Host only; the session already resolved the seat.
		if !l.ses.is_host || from == knet.PLAYER_ID_INVALID {
			return
		}
		cmd_handle(l, from, r)
	case SIM_VERDICT:
		// Client only, and only the authority's word counts.
		if l.ses.is_host || from_peer != ksess.HOST_PEER {
			return
		}
		cmd_handle_verdict(l, r)
	case SIM_FACT:
		// Client only, and only the authority's word counts. Handler
		// discipline: file the bytes; the firing waits for the watch clock
		// (lane_present), on the game's own stack.
		if l.ses.is_host || from_peer != ksess.HOST_PEER {
			return
		}
		tick := knet.read_u64(r)
		id := knet.read_net_id(r)
		kind := knet.read_u16(r)
		blob := knet.read_bytes(r)
		if r.err {
			return
		}
		if len(l.facts) >= FACT_QUEUE_CAP {
			l.stat_facts_dropped += 1 // counted, never silent — netgraph's sim row shows it
			return
		}
		args := make([]u8, len(blob))
		copy(args, blob)
		append(&l.facts, Fact_In{tick = tick, id = id, kind = kind, args = args})
	case SIM_SNAP:
		// Client only, and only the authority's word counts.
		if l.ses.is_host || from_peer != ksess.HOST_PEER {
			return
		}
		rest := r.data[r.off:]
		if len(rest) < 8 {
			return
		}
		peek := knet.reader_make(rest)
		tick := knet.read_u64(&peek)
		if tick <= l.pending_tick || tick <= l.rx.newest {
			return // an older batch than one already filed/applied: superseded
		}
		clear(&l.pending)
		append(&l.pending, ..rest)
		l.pending_tick = tick
	}
}
