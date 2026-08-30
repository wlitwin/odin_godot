//gd:extends Node
//gd:class CaveLobby
package cavecrawl_scripts

// ----------------------------------------------------------------------------
// CAVECRAWL — the friendslop toolkit's example game, grown one phase at a
// time: a working lobby (phase 1), chat (2), a lootable world (3), predicted
// combat under real latency (4), hostile dwellers (5), and quit-and-resume
// saves (6).
//
// This file is the game's CORE: the vocabulary (constants + types), the
// CaveLobby state, and the two lifecycle hooks (ready wires everything up,
// process pumps it). The rest of the class lives in sibling files — one
// class, many files, split the way a real game is:
//   * net.odin     — transport packets, identity, the Host/Join buttons.
//   * world.odin   — entity nodes, the spawn factory, the interact prompt.
//   * input.odin   — keys/mouse and the player verbs they drive.
//   * rocks.odin   — peer-owned projectile visuals (the zero-felt-lag story).
//   * host.odin    — the authority: command hook, game tick, dweller brains.
//   * save.odin    — the run on disk (session snapshot + game blob).
//   * queries.odin — read-only windows for HUDs and test drivers.
//   * The ENTITIES: spelunker.odin / chest.odin / door.odin / pickup.odin /
//     dweller.odin — a file each, fields tagged gd:"replicate", commands as
//     plain procs. That is the entire multiplayer author surface.
// ----------------------------------------------------------------------------

import "core:fmt"
import gd "godot:godot"
import kai "godot:kit/ai"
import kboot "godot:kit/boot"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import kfx "godot:kit/fx"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import ksess "godot:kit/session"
import steamgd "godot:kit/steamgd"
import kui "godot:kit/ui"

DEFAULT_PORT :: 4242
MSG_SESSION :: u8(0) // all kit/session traffic under one game byte

// ---- the cave's vocabulary (shared by every script in this package) ----

REACH :: f32(40) // interaction reach in pixels — prompt AND host gate use it

GEM :: kitems.Item_Id(1)
TORCH :: kitems.Item_Id(2)

// (The SPELUNKER_TYPE..RELIC_TYPE wire-id consts are GENERATED now — each
// scene field below declares its entity and stable id in its tag, and
// scriptgen emits the consts + the factory table. See world.odin's hooks.)

WALK_SPEED :: f32(120) // px/s

// ---- combat (phase 4) ----

MAX_HP :: i32(100)
MAX_STAMINA :: i32(10)
ROCK_ABILITY :: kcombat.Ability_Def {
	name     = "rock",
	cooldown = 20,
	cost     = 3,
} // 1s at 20 Hz
HEAL_ABILITY :: kcombat.Ability_Def {
	name     = "bandage",
	cooldown = 60,
	cost     = 5,
} // 3s
HEAL_AMOUNT :: i32(25)
ROCK_DMG :: i32(35)
ROCK_SPEED :: f32(12) // px per net tick
ROCK_TTL :: u16(24) // ~288 px of flight
CAST_LEASH :: f32(64) // how far a claimed cast origin may differ from the host's lagged copy
BODY_RADIUS :: f32(14)
RESPAWN_TICKS :: 60 // 3s in the grave
CHILL :: u8(1) // rocks chill what they don't kill
REVIVE_HP :: i32(30) // where a revive leaves you: alive, not well
SPAWN_X :: f32(80)
SPAWN_Y :: f32(120)

// Command wire ids (SPELUNKER_CMD_THROW, CHEST_CMD_TAKE, ...) are GENERATED
// per class — stable name hashes, not positions; see the *.gen.odin files.

// kit/comms rides SES_APP tag 0; fire announcements ride tag 1.
TAG_FIRE :: u8(1)
FIRE_ROCK :: u8(1)

// ---- cave dwellers (phase 5) ----

DWELLER_HP :: i32(70) // two rocks
DWELLER_SPEED :: f32(4) // px per tick (players outrun them)
DWELLER_AGGRO :: f32(100) // sight radius (open cave: no LoS blocker)
BITE_RANGE :: f32(24)
BITE_DMG :: i32(10)
BITE_CD :: u16(30) // 1.5s between bites
FLEE_BELOW :: i32(35) // one rock in: it runs

// ---- the floors (level migration) ----
//
// A LEVEL is a data asset: a CaveLevelDef .tres names the floor's SCENE
// (backdrop + spawn markers, loaded LOCALLY by every peer — static
// presentation never touches the wire) plus the chest stock and the wave
// plan. Descending = despawn the old floor's entities, bump the replicated
// depth byte, furnish the next def — the same replication that built floor
// 1 delivers floor 2 to every peer. Depths beyond the table replay the
// deepest floor (the cave goes on).
MAX_WAVES :: 8


// The host-side half of a dweller's mind (never on the wire).
Dweller_Brain :: struct {
	home:    [3]f32,
	bite_cd: u16,
}

// One rock in the HOST's authoritative sim — the only rocks that hurt.
Cave_Rock :: struct {
	p:       kcombat.Projectile,
	shooter: knet.Player_Id,
}

CaveLobby :: struct {
	owner:           gd.Node,
	ses:             ksess.Session,
	comms:           kcomms.Comms,
	boot:            kboot.Boot, // lobby/chat/score/legend/wire/stage/world — kit-built, game-owned
	running:         bool, // hosting or joining (transport is up)

	// The authored entity scenes, assigned in cave.tscn's inspector. Each
	// tag's `entity=Name:id` IS the factory declaration: the struct this
	// scene bodies and its stable wire id — scriptgen generates the TYPE
	// consts, the kind table, and the typed hooks' dispatch from these;
	// kboot.boot_entities (ready(), below) drives it. Bodies, particles,
	// and layout stay in the editor.
	spelunker_scene: ^gd.Resource `gd:"entity=Spelunker:1"`,
	chest_scene:     ^gd.Resource `gd:"entity=Chest:2"`,
	door_scene:      ^gd.Resource `gd:"entity=Door:3"`,
	pickup_scene:    ^gd.Resource `gd:"entity=Pickup:4"`,
	dweller_scene:   ^gd.Resource `gd:"entity=Dweller:5"`,
	level_scene:     ^gd.Resource `gd:"entity=Level:6"`,
	relic_scene:     ^gd.Resource `gd:"entity=Relic:7"`,

	// The campaign: one CaveLevelDef data asset per floor (scene + loot +
	// waves), authored in the inspector.
	floor1_def:      ^gd.Resource `gd:"export,resource=CaveLevelDef"`,
	floor2_def:      ^gd.Resource `gd:"export,resource=CaveLevelDef"`,

	// The current floor, as loaded on THIS peer: the scene instance under
	// `stage`, plus the host-side caches read from its def + markers.
	scenery:         gd.Node, // the loaded level_N.tscn instance (nil pre-game)
	scenery_depth:   u8, // which depth `scenery` shows
	dens:            [2][3]f32, // host: den positions, from the floor's markers
	waves:           [MAX_WAVES]kai.Wave, // host: the floor's wave plan
	waves_n:         int,

	// ---- the world (phase 3) ----
	table:           kitems.Table,
	prompt:          kui.Prompt,
	inv:             kui.Inv,
	spelunkers:      map[knet.Net_Id]^Spelunker,
	chests:          map[knet.Net_Id]^Chest,
	doors:           map[knet.Net_Id]^Door,
	pickups:         map[knet.Net_Id]^Pickup,
	dwellers:        map[knet.Net_Id]^Dweller,
	avatar_of:       map[knet.Player_Id]knet.Net_Id,
	me_spel:         ^Spelunker, // my avatar (nil until spawned)
	level:           ^Level, // the run's depth marker (nil until spawned)
	floors_n:        int, // how deep the cave goes (CAVE_FLOORS env shrinks it for tests)
	kicked_out:      bool, // we were removed on purpose — mutes the host-left line that follows
	steam_on:        bool, // GodotSteam present + initialized (kit/steamgd)
	relic:           ^Relic, // the carryable (ownership-transfer demo); nil pre-world
	relic_id:        knet.Net_Id,
	steam_lobby:     u64, // the Steam lobby we host or sit in (invite target)
	deny_reason:     int, // last Ev_Join_Denied reason (-1 = none); drivers read it
	started:         bool, // the world is live
	walking:         bool, // headless drivers steer via walk_to
	walk_target:     gd.Vector2,
	target_id:       knet.Net_Id, // what the prompt points at right now
	target_kind:     int, // 0 none, 1 chest, 2 door, 3 pickup

	// ---- combat (phase 4) ----
	cols:            kcombat.Combat_Cols, // host: the auto-published ledger columns
	flying:          [dynamic]Cave_Rock, // host: the authoritative rock sim
	tracers:         kfx.Tracers, // every peer: the rocks on THIS screen (px/tick -> px/s, see rocks.odin)
	fires:           kcombat.Fire_Route, // the announcement listener's registration
	fx:              kfx.Bursts, // every peer: live particle bursts (fx.odin narrates, kit/fx reaps)
	respawn_at:      map[knet.Net_Id]int `gd:"backup"`, // host: resurrection clocks

	// ---- dwellers (phase 5, host-side) ----
	// The host-local campaign state a takeover (and a save) must carry — TAGGED,
	// not hand-serialized: scriptgen emits the versioned cave_lobby_backup_write/
	// _read pair over exactly these fields (see save.odin). Maps ride whole.
	brains:          map[knet.Net_Id]Dweller_Brain `gd:"backup"`,
	director:        kai.Director `gd:"backup"`,
	slain_col:       ksess.Stat_Col, // the game's own scoreboard column
	// UNTAGGED on purpose: a print latch, not campaign state. A successor host
	// re-earns it on its first bent path (host.odin's CAVE_NAV_BENT receipt) —
	// backing it up would only teach the new host to stay quiet.
	nav_bent:        bool,
	dens_used:       int `gd:"backup"`, // round-robin den picker
	last_wave:       int `gd:"backup"`, // wave-announcement edge
	host_ticks:      int `gd:"backup"`, // host: game ticks elapsed
	hud_hp:          kui.Hp_Bar,
	hud_ab:          kui.Abilities_Bar,
	chat_sent:       bool, // the Enter that submitted a line must not also re-open chat
	host_gone:       bool, // the driver's poll mirror (the KIT holds the mechanics latch now)
	greeted:         bool, // @(gd_message) dogfood: the one-time greeting fired (not on migration re-welcomes)
	succ_seen:       int, // Ev_Succession count (latched; drivers poll it — host_gone flips back within a frame)
	issue_at:        f64, // when my last command left (confirm latency proof)
}

now_s :: knet.now_s // the toolkit's monotonic clock, under the game's short name

refresh_hud :: proc(self: ^CaveLobby) {
	if self.me_spel == nil {return}
	kui.hp_refresh(&self.hud_hp, hp_view(self.me_spel), MAX_HP)
	defs := [?]kcombat.Ability_Def{ROCK_ABILITY, HEAL_ABILITY}
	kui.abilities_refresh(
		&self.hud_ab,
		defs[:],
		self.me_spel.cds[:],
		self.me_spel.stamina,
		ksess.session_tick_hz(&self.ses),
	)
	// The bag too: hosts get no state events, and a verb-only repaint left
	// the host's grid showing loot its death had long since spilled.
	kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
}

cave_lobby_ready :: proc(self: ^CaveLobby) {
	// The cave (phase 3): item defs are code — every peer declares the same
	// table. World hookups install now; entities exist only after Start.
	kitems.items_register(&self.table, GEM, "gem", 99)
	kitems.items_register(&self.table, TORCH, "torch", 5)
	kcombat.fire_listen(&self.fires, &self.ses, TAG_FIRE)

	// The wire-contract version gate is on by default (the generated guard file
	// registers NET_FINGERPRINT as the session default at load) — but that hashes
	// the wire SHAPES, not the MEANING of our item bytes. GEM=1/TORCH=2 are game
	// constants that never ship; a build that reordered them keeps a byte-identical
	// Slot layout, passes the door, and then reads a replicated `item=1` as the
	// wrong thing. Fold the table's contract onto the shape hash so that skew is
	// refused at the door instead (see kitems.items_contract / session_mix_fingerprint).
	net_cfg := kboot.network_profile(.Friends_Coop)
	net_cfg.session.fingerprint = ksess.session_mix_fingerprint(
		0,
		kitems.items_contract(&self.table),
	)

	// The stock stack — lobby, chat+comms, scoreboard, stage/world, wire,
	// legend — is kit/boot's. Everything below is what makes this CAVECRAWL.
	cave_lobby_net_attach(
		self,
		kboot.Options {
			title       = "C A V E C R A W L",
			status      = "Host a cave, or join one at localhost",
			legend      = "WASD walk · E use · click throw · Q drop · G set down · R heal · Tab scores · Enter chat",
			msg_kind    = MSG_SESSION,
			env         = "CAVE", // the CAVE_* env family — including the shim's _JITTER/_LOSS knobs
			latency_env = "CAVE_LATENCY",
			methods     = {
				"on_host",
				"on_join",
				"on_start",
				"on_chat",
				"on_packet",
				"on_peer_left",
				"on_net_up",
				"on_net_down",
			},
		},
		net_cfg,
	)
	// The factory, written by nobody: the generated table (from the scene
	// fields' entity= tags) instantiates/frees under boot.world; the typed
	// *_spawned/*_freed hooks in world.odin keep the census. `self` is also
	// what every `<verb>_then` consequence receives as its game param.
	// The migration dance, danced by the kit: the torch, the takeover/chase
	// fork, the census-driven wipe, the caps. The game's four seams ride the
	// generated table (backup/took_over/wiped/migrating halves, save.odin +
	// net.odin) — words and bytes, never mechanics.
	// @(gd_message): register the typed app-message routes (the emote greeting
	// below). One line, like fire_listen — routes survive *_start, so once is enough.

	self.prompt = kui.prompt_make(self.owner)
	self.inv = kui.inv_make(self.owner, 6)
	kui.inv_show(&self.inv, false)
	self.hud_hp = kui.hp_make(self.owner)
	self.hud_ab = kui.abilities_make(self.owner, 2)
	// The LAYOUT is the game's call, not the kit's: status cluster stacked
	// in the top-left (kit widgets spawn at the anchor origin by default).
	gd.control_set_position(cast(gd.Control)self.hud_hp.label, {8, 4}, false)
	gd.control_set_position(self.hud_ab.root, {8, 22}, false)
	gd.control_set_position(self.inv.root, {8, 40}, false)
	// STEAM, when the GodotSteam extension is in the project (and not
	// switched off for tests): one transport swap, zero session changes.
	if steamgd.available() && gd.env_int("CAVE_STEAM", 1) != 0 {
		self.steam_on = steamgd.init(gd.env_int("CAVE_APPID", steamgd.TEST_APP_ID))
		if self.steam_on {
			steamgd.listen(self.owner, "on_lobby_created", "on_lobby_joined", "on_join_requested")
		}
	}
	gd.print_str(fmt.tprintf("CAVE_STEAM %s", self.steam_on ? "on" : "off"))
	self.floors_n = gd.env_int("CAVE_FLOORS", 2)
	self.deny_reason = -1
	install_controls()
	gd.print_str("CAVE_UI_READY")
}

// Both roles flip to game mode the same way (host at Start, client at spawn).
enter_the_cave :: proc(self: ^CaveLobby) {
	self.started = true
	gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
	gd.set_bool(cast(gd.Object)self.boot.legend, "visible", true)
	kui.inv_show(&self.inv, true)
	if self.me_spel != nil {
		kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
		refresh_hud(self)
	}
}


cave_lobby_process :: proc(self: ^CaveLobby, delta: f64) {
	if !self.running {return}

	// Preamble + boilerplate event reactions live in kit/boot; every event is
	// re-yielded below, so the game switch stays complete.
	events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())
	if self.started {
		// Visuals fly FIRST, on the frame clock (smooth on any refresh
		// rate): on the host, the impact you see is noted before the
		// authority's tick deals the damage in the same frame — the
		// overlay consumes that truth cleanly instead of double-dipping.
		cave_visual_frame(self, delta) // every peer flies its own screen's rocks
		// CARRYING: if the relic is mine, it rides my shoulder — my writes
		// stream to everyone (the same machinery that streams me).
		if self.relic != nil &&
		   self.me_spel != nil &&
		   ksess.session_owner_of(&self.ses, self.relic_id) == self.ses.me {
			self.relic.x = self.me_spel.x + 10
			self.relic.y = self.me_spel.y - 12
		}
		kfx.bursts_frame(&self.fx, delta) // reap spent particle bursts
		// Announced fires, drained on MY stack (events-not-callbacks — the
		// old on_fire callback ran mid-session-pump).
		for {
			f, has := kcombat.fire_poll(&self.fires)
			if !has {break}
			cave_on_fire(self, f)
		}
		// The authority's fixed steps + the same-frame edge pass, role-free
		// at the call site: the generated cave_lobby_step holds the host
		// gate (clients no-op) and runs session_run_edges after the loop —
		// the respawn walk-out must move the body before the next exchange.
		cave_lobby_step(self, ticks)
	}

	// The game's event reactions are the name-paired halves below — the
	// generated cave_lobby_events holds the switch AND the role gates.
	cave_lobby_events(self, events)
	for m in marks {
		// No world yet to draw it in — phase 3 gives markers a cave wall.
		gd.print_str(
			fmt.tprintf("CAVE_MARK player=%d kind=%d x=%.1f", u64(m.player), m.kind, m.pos.x),
		)
	}

	if self.started {
		poll_controls(self)
	}
	if self.started && self.me_spel != nil {
		if self.me_spel.hp > 0 {
			drive_spelunker(self, delta)
		}
		update_prompt(self)
		refresh_hud(self) // live bar + cooldown text (hosts get no state events)
	}
}

// ---- session event halves ---------------------------------------------------
// The old 150-line event-drain switch, as name-paired procs: declare the
// events you care about, skip the rest — the generated cave_lobby_events
// dispatches, and every role gate (host-only `_then` consequences, the
// client-only gate that drops a stale post-takeover re-fire) is generated.

// Seated = the host exists, BY DEFINITION — clear the loss latch here, not
// just at rejoin start: the OLD socket's death signals can land mid-rejoin
// (after cave_rejoin_to cleared the flag, before this WELCOME) and re-latch
// it against the LIVE host, blocking every "are we back?" gate forever.
@(gd_half)
cave_lobby_welcomed :: proc(self: ^CaveLobby, me: knet.Player_Id) {
	self.host_gone = false
	gd.print_str(fmt.tprintf("CAVE_SEATED me=%d", u64(me)))
	// A GUEST greets the host on arrival — a @(gd_message), the typed app-message
	// path (comms carries chat + broadcast pings; THIS is a directed POD payload
	// decoded for the handler, the sender resolved into `from`). The host greets
	// back with a SEAT-ADDRESSED reply, so this one arrival exercises both doors.
	// Once only — not on migration re-welcomes (a greeting is a first-hello, and
	// the delicate takeover window doesn't want the extra traffic).
	if !self.ses.is_host && !self.greeted {
		self.greeted = true
		cave_lobby_emote_send(&self.ses, Emote{kind = GREET, spice = 41}, ksess.HOST_PEER)
	}
}

// ---- @(gd_message): a directed greeting — the typed app-message dogfood -------
// comms already carries chat and broadcast pings; this is the POINT-TO-POINT typed
// path a game reaches for when "if you weren't there, you don't get it" is the
// right behavior. One message type; `kind` tells a greeting from its ack so the
// host's reply can't loop back into another reply.
Emote :: struct {
	spice:          u16, // an arbitrary value, echoed +1 in the ack — proves the payload decoded intact
	kind:           u8, // GREET (guest→host) or GREET_ACK (host→guest)
	_wire_reserved: u8, // explicit protocol byte; no compiler-owned tail padding
}
TAG_EMOTE :: u8(4) // a free SES_APP tag (kit holds comms 0, xfer 2, sim 3; the game's fire is 1)
GREET :: u8(7)
GREET_ACK :: u8(8)

@(gd_message = "TAG_EMOTE")
cave_lobby_emote :: proc(self: ^CaveLobby, from: knet.Player_Id, msg: Emote) {
	gd.print_str(
		fmt.tprintf("CAVE_WHISPER from=%d kind=%d spice=%d", u64(from), msg.kind, msg.spice),
	)
	// The host answers a greeting with a directed, seat-addressed reply
	// (cave_lobby_emote_send_to → the authority resolves `from`'s peer). The ack
	// carries GREET_ACK, so the guest presents it and never greets back.
	if self.ses.is_host && msg.kind == GREET {
		cave_lobby_emote_send_to(&self.ses, from, Emote{kind = GREET_ACK, spice = msg.spice + 1})
	}
}

@(gd_half)
cave_lobby_player_joined :: proc(self: ^CaveLobby, id: knet.Player_Id, rejoin: bool) {
	_ = id
	_ = rejoin
	gd.print_str(
		fmt.tprintf("CAVE_PLAYERS n=%d", ksess.session_count(&self.ses, connected_only = true)),
	)
}

// The host words the flavor lines; comms ships them. Catchup goes FIRST so a
// fresh joiner's replayed history doesn't duplicate the join line it is
// about to receive from the broadcast.
@(gd_half)
cave_lobby_player_joined_then :: proc(self: ^CaveLobby, id: knet.Player_Id, rejoin: bool) {
	if p, ok := ksess.session_player(&self.ses, id); ok {
		verb := rejoin ? "returned to" : "joined"
		kcomms.comms_welcome(&self.comms, id, rejoin, fmt.tprintf("%s %s the cave", p.name, verb))
	}
}

@(gd_half)
cave_lobby_player_left :: proc(self: ^CaveLobby, id: knet.Player_Id) {
	_ = id
	gd.print_str(
		fmt.tprintf("CAVE_PLAYERS n=%d", ksess.session_count(&self.ses, connected_only = true)),
	)
}

@(gd_half)
cave_lobby_player_left_then :: proc(self: ^CaveLobby, id: knet.Player_Id) {
	if p, ok := ksess.session_player(&self.ses, id); ok {
		kcomms.comms_system(&self.comms, fmt.tprintf("%s wandered off", p.name))
	}
}

@(gd_half)
cave_lobby_host_left :: proc(self: ^CaveLobby) {
	self.host_gone = true
	if !self.kicked_out { 	// the kick already explained this teardown
		// The designated backup holder can carry the torch; everyone else
		// rejoins whoever does (cave_lobby_succession / on_rejoin).
		_, _, held := ksess.session_backup_parts(&self.ses)
		kui.lobby_set_status(
			&self.boot.ui,
			held ? "The host left — you hold the backup. Resume?" : "The host left — this run is over",
		)
		gd.print_str("CAVE_HOST_LEFT")
	}
}

// LIVE MIGRATION, the host's half: WORDS ONLY now — the session named WHO,
// and the KIT's ceremony (boot_migration) computed WHERE and broadcast it
// before this half fired. The receipt reads the torch back.
@(gd_half)
cave_lobby_backup_target :: proc(self: ^CaveLobby, player: knet.Player_Id) {
	// The torch is the kit's STRUCTURED rendezvous, not a printable string —
	// decode it, then word it. (This line said `string(info)` for a while after
	// the record went binary, and printed raw bytes into its own receipt; the
	// blob's type refuses that now, and succession_words is what it points at.)
	_, info := ksess.session_successor(&self.ses)
	rv, _ := netgd.succession_decode(info)
	gd.print_str(
		fmt.tprintf("CAVE_TORCH_NAMED player=%d addr=%s", u64(player), netgd.succession_words(rv)),
	)
}

// LIVE MIGRATION, everyone else's half: WORDS ONLY — the kit runs the
// takeover on the bearer and the capped chase on everyone else AFTER this
// half returns (the generated events tail drains it), so these words still
// see the old world. The bearer's own word rides cave_lobby_migrating's
// .Taking_Over arm (the kit dedupes the double death-signal); the chase
// receipts live there too.
@(gd_half)
cave_lobby_succession :: proc(self: ^CaveLobby, successor: knet.Player_Id) {
	_ = successor
	self.succ_seen += 1
}

// We are the designated backup host from this moment on.
@(gd_half)
cave_lobby_backup_received :: proc(self: ^CaveLobby, size: int) {
	gd.print_str(fmt.tprintf("CAVE_BACKUP size=%d", size))
}

@(gd_half)
cave_lobby_kicked :: proc(self: ^CaveLobby) {
	self.kicked_out = true
	kui.lobby_set_status(&self.boot.ui, "You were shown the door")
	gd.print_str("CAVE_KICKED_ME")
}

@(gd_half)
cave_lobby_join_denied :: proc(self: ^CaveLobby, reason: ksess.Deny_Reason) {
	line: string
	switch reason {
	case .Full:
		line = "The cave is full"
	case .Locked:
		line = "The cave is sealed"
	case .Banned:
		line = "You are not welcome here"
	case .Version:
		line = "Your build and the host's disagree — update one of them"
	}
	kui.lobby_set_status(&self.boot.ui, line)
	self.deny_reason = int(reason)
	gd.print_str(fmt.tprintf("CAVE_DENIED reason=%v", reason))
}

@(gd_half)
cave_lobby_join_failed :: proc(self: ^CaveLobby) {
	gd.print_str("CAVE_JOIN_FAILED")
}

// The world reached this peer (factory already made the node) — and the
// level's INITIAL dress: scenery from the replicated seed, the end screen
// for a joiner landing mid-victory. HERE, not in the level_spawned census
// hook: the hook fires before the spawn tuple's fields apply (bookkeeping
// only), and the edge halves seed silently on first sight (a baseline, not
// an edge).
@(gd_half)
cave_lobby_entity_spawned :: proc(
	self: ^CaveLobby,
	id: knet.Net_Id,
	type: ksess.Entity_Type,
	owner: knet.Player_Id,
) {
	cave_place(self, id, type) // the node's FIRST placement — world.odin
	if !self.started {
		enter_the_cave(self)
	}
	if type == LEVEL_TYPE && self.level != nil {
		cave_load_scenery(self, int(self.level.depth))
		if self.level.won != 0 {
			cave_show_won(self)
		}
	}
	gd.print_str(fmt.tprintf("CAVE_SPAWN id=%d mine=%v", u32(id), owner == self.ses.me))
}

// The relic changed hands — every peer hears; the new carrier's process glue
// starts moving it (no role branch, no carrier map: ownership IS the
// carrier record).
@(gd_half)
cave_lobby_owner_changed :: proc(
	self: ^CaveLobby,
	id: knet.Net_Id,
	owner: knet.Player_Id,
	prev: knet.Player_Id,
) {
	_ = prev
	if id == self.relic_id {
		gd.print_str(fmt.tprintf("CAVE_RELIC owner=%d", u64(owner)))
	}
}

// The host words the handoff for every chat pane.
@(gd_half)
cave_lobby_owner_changed_then :: proc(
	self: ^CaveLobby,
	id: knet.Net_Id,
	owner: knet.Player_Id,
	prev: knet.Player_Id,
) {
	_ = prev
	if id == self.relic_id {
		line := "the relic rests"
		if p, ok := ksess.session_player(&self.ses, owner); ok {
			line = fmt.tprintf("%s carries the relic", p.name)
		}
		kcomms.comms_system(&self.comms, line)
	}
}

// The floor's inscription (or any future blob) — variable-length state that
// arrived with the change, the join snapshot, or a resumed backup; one
// read, every path.
@(gd_half)
cave_lobby_blob_changed :: proc(self: ^CaveLobby, id: knet.Net_Id, size: int) {
	_ = size
	if self.level != nil && id == self.level.net_id {
		gd.print_str(fmt.tprintf("CAVE_INSCRIPTION %s", string(ksess.session_blob(&self.ses, id))))
	}
}

@(gd_half)
cave_lobby_state_applied :: proc(self: ^CaveLobby, entities: int) {
	_ = entities
	if self.me_spel != nil {
		kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
		refresh_hud(self)
	}
}

@(gd_half)
cave_lobby_command_executed :: proc(
	self: ^CaveLobby,
	ok: bool,
	player: knet.Player_Id,
	entity: knet.Net_Id,
	cmd: u16,
	reason: knet.Action_Reject_Reason,
	seq: knet.Intent_Seq,
	model: knet.Action_Model,
) {
	_, _, _ = player, seq, model
	gd.print_str(
		fmt.tprintf("CAVE_EXEC ok=%v reason=%v entity=%d cmd=%d", ok, reason, u32(entity), cmd),
	)
}

@(gd_half)
cave_lobby_command_confirmed :: proc(
	self: ^CaveLobby,
	seq: knet.Intent_Seq,
	entity: knet.Net_Id,
	cmd: u16,
	model: knet.Action_Model,
) {
	_, _, _, _ = seq, entity, cmd, model
	dt_ms := self.issue_at > 0 ? int((now_s() - self.issue_at) * 1000) : 0
	gd.print_str(fmt.tprintf("CAVE_CONFIRM dt_ms=%d", dt_ms))
}

@(gd_half)
cave_lobby_command_rejected :: proc(
	self: ^CaveLobby,
	seq: knet.Intent_Seq,
	entity: knet.Net_Id,
	cmd: u16,
	reason: knet.Action_Reject_Reason,
	model: knet.Action_Model,
) {
	_, _, _ = seq, cmd, model
	gd.print_str(fmt.tprintf("CAVE_REJECT reason=%v entity=%d", reason, u32(entity)))
}

// THE FLOOR EDGE — the descent, minus the seen_depth mirror: the replicated
// depth ticking over loads the floor's SCENE locally (static presentation
// never rides the wire) and steps me to its mouth — position is owner-
// streamed, only I can move me. First sight (fresh start, resumed save,
// drop-in join) is structurally NOT an edge — the machinery seeds silently —
// so the initial scenery load rides Ev_Spawned (below), and the old
// `seen_depth != 0` guard has nothing left to guard.
@(gd_half)
level_depth_edge :: proc(g: ^CaveLobby, self: ^Level, old, new: u8) {
	cave_load_scenery(g, int(new))
	if g.me_spel != nil {
		g.me_spel.x = SPAWN_X + f32(u64(g.ses.me) % 4) * 40
		g.me_spel.y = SPAWN_Y
		g.walking = false
		// A jump, not a walk: remote screens snap instead of sliding my
		// avatar across the whole map.
		_ = spelunker_teleport(&g.boot, g.me_spel)
		gd.print_str(fmt.tprintf("CAVE_FLOOR depth=%d", new))
	}
}

// MATCH FLOW, both directions of one replicated byte: won going 1 is the end
// screen (the host's Start button reads as "again"), won going 0 is the next
// run starting — every peer clears its screen off the same delta that rebuilt
// the floor. A late joiner mid-end-screen is dressed off Ev_Spawned (spawn
// values seed silently — a baseline, not an edge).
@(gd_half)
level_won_edge :: proc(g: ^CaveLobby, self: ^Level, old, new: u8) {
	if new != 0 {
		cave_show_won(g)
		gd.print_str(fmt.tprintf("CAVE_WON depth=%d", self.depth))
	} else {
		kui.score_show(&g.boot.score, false)
		gd.set_bool(cast(gd.Object)g.boot.ui.root, "visible", false)
		gd.print_str("CAVE_RESTARTED")
	}
}

cave_show_won :: proc(g: ^CaveLobby) {
	kui.score_show(&g.boot.score, true)
	gd.set_bool(cast(gd.Object)g.boot.ui.root, "visible", true)
	kui.lobby_set_status(&g.boot.ui, "The cave is conquered!")
	kui.lobby_show_menu(&g.boot.ui, false, g.ses.is_host)
}
