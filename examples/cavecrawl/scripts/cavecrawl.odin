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

import gd "godot:godot"
import kai "godot:kit/ai"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kui "godot:kit/ui"
import "core:fmt"
import "core:time"

DEFAULT_PORT :: 4242
MSG_SESSION :: u8(0) // all kit/session traffic under one game byte

// ---- the cave's vocabulary (shared by every script in this package) ----

REACH :: f32(40) // interaction reach in pixels — prompt AND host gate use it

GEM :: kitems.Item_Id(1)
TORCH :: kitems.Item_Id(2)

SPEL_TYPE :: ksess.Entity_Type(1)
CHEST_TYPE :: ksess.Entity_Type(2)
DOOR_TYPE :: ksess.Entity_Type(3)
PICKUP_TYPE :: ksess.Entity_Type(4)
DWELLER_TYPE :: ksess.Entity_Type(5)

WALK_SPEED :: f32(120) // px/s

// ---- combat (phase 4) ----

MAX_HP :: i32(100)
MAX_STAMINA :: i32(10)
ROCK_ABILITY :: kcombat.Ability_Def{name = "rock", cooldown = 20, cost = 3} // 1s at 20 Hz
ROCK_DMG :: i32(35)
ROCK_SPEED :: f32(12) // px per net tick
ROCK_TTL :: u16(24) // ~288 px of flight
BODY_RADIUS :: f32(14)
RESPAWN_TICKS :: 60 // 3s in the grave
CHILL :: u8(1) // rocks chill what they don't kill
SPAWN_X :: f32(80)
SPAWN_Y :: f32(120)

// Command indices = @(gd_command) declaration order in spelunker.odin.
SPEL_CMD_DROP :: u16(0)
SPEL_CMD_THROW :: u16(1)

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

// The waves (kit/ai director): the game only says what and where.
CAVE_WAVES := [?]kai.Wave{{count = 2, rest = 40}, {count = 3, rest = 40}}
DWELLER_DENS := [?][3]f32{{320, 40, 0}, {320, 320, 0}}

// Dwellers declare no commands, so scriptgen emits only their descriptor.
dweller_set := knet.Command_Set{entity_desc = &dweller_net_desc}

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

// One rock on THIS screen — a peer-owned visual flying the same trajectory
// the host's damage sim walks in ticks, but per-FRAME in seconds: the wire
// speaks px/tick, the screen speaks px/s, and 20 Hz steps on a 60 fps
// screen is exactly the stutter that conversion removes. The shooter's
// spawns at cast time (zero RTT: press fire, see rock); everyone else's
// spawns on the host's fire announcement.
Visual_Rock :: struct {
	pos:     [3]f32,
	vel:     [3]f32, // px/s
	left:    f32, // seconds of flight remaining
	shooter: knet.Player_Id,
	node:    gd.Label,
}

// Injected receive latency for the acid run (CAVE_LATENCY ms): packets
// buffer here before routing — the suite proves casts feel instant anyway.
Delayed_Packet :: struct {
	due:  f64,
	from: int,
	data: []u8,
}

CaveLobby :: struct {
	owner:     gd.Node,
	ses:       ksess.Session,
	comms:     kcomms.Comms,
	ui:        kui.Lobby,
	chat:      kui.Chat,
	running:   bool, // hosting or joining (transport is up)
	join_sent: bool, // client: JOIN goes out once the transport connects

	// ---- the world (phase 3) ----
	table:       kitems.Table,
	world:       gd.Node, // entity nodes live under here
	prompt:      kui.Prompt,
	inv:         kui.Inv,
	spelunkers:  map[knet.Net_Id]^Spelunker,
	chests:      map[knet.Net_Id]^Chest,
	doors:       map[knet.Net_Id]^Door,
	pickups:     map[knet.Net_Id]^Pickup,
	dwellers:    map[knet.Net_Id]^Dweller,
	nodes:       map[knet.Net_Id]gd.Node, // for freeing on despawn
	avatar_of:   map[knet.Player_Id]knet.Net_Id,
	me_spel:     ^Spelunker, // my avatar (nil until spawned)
	started:     bool, // the world is live
	walking:     bool, // headless drivers steer via walk_to
	walk_target: gd.Vector2,
	target_id:   knet.Net_Id, // what the prompt points at right now
	target_kind: int, // 0 none, 1 chest, 2 door, 3 pickup

	// ---- combat (phase 4) ----
	cols:       kcombat.Combat_Cols, // host: the auto-published ledger columns
	flying:     [dynamic]Cave_Rock, // host: the authoritative rock sim
	visuals:    [dynamic]Visual_Rock, // every peer: the rocks on THIS screen
	bursts:     [dynamic]Fx_Burst, // every peer: live particle bursts (fx.odin)
	respawn_at: map[knet.Net_Id]int, // host: resurrection clocks

	// ---- dwellers (phase 5, host-side) ----
	brains:    map[knet.Net_Id]Dweller_Brain,
	director:  kai.Director,
	slain_col: ksess.Stat_Col, // the game's own scoreboard column
	dens_used: int, // round-robin den picker
	last_wave: int, // wave-announcement edge
	host_ticks: int, // host: game ticks elapsed
	hud_hp:     kui.Health_Bar,
	hud_ab:     kui.Ability_Bar,
	score:      kui.Score,
	legend:     gd.Label, // the controls line, shown once the world is live
	chat_sent:  bool, // the Enter that submitted a line must not also re-open chat
	was_dead:   bool, // owner-side respawn edge detector
	issue_at:   f64, // when my last command left (confirm latency proof)

	// injected latency (CAVE_LATENCY ms; tests only)
	latency: f64,
	delayed: [dynamic]Delayed_Packet,
}

now_s :: proc "contextless" () -> f64 {
	return f64(time.tick_now()._nsec) / 1e9
}

refresh_hud :: proc(self: ^CaveLobby) {
	if self.me_spel == nil {return}
	kui.hp_refresh(&self.hud_hp, hp_view(self.me_spel), MAX_HP)
	defs := [?]kcombat.Ability_Def{ROCK_ABILITY}
	kui.abilities_refresh(&self.hud_ab, defs[:], self.me_spel.cds[:], self.me_spel.stamina)
}

cave_lobby_ready :: proc(self: ^CaveLobby) {
	self.ui = kui.lobby_make(self.owner, "C A V E C R A W L")
	kui.lobby_set_status(&self.ui, "Host a cave, or join one at localhost")
	gd.connect_to(cast(gd.Object)self.ui.host_btn, "pressed", self.owner, "on_host")
	gd.connect_to(cast(gd.Object)self.ui.join_btn, "pressed", self.owner, "on_join")

	gd.connect_to(cast(gd.Object)self.ui.start_btn, "pressed", self.owner, "on_start")

	// Comms bind before the session starts (routes survive host/client start);
	// the chat box stays hidden until there is a session to speak into.
	kcomms.comms_init(&self.comms, &self.ses)
	self.chat = kui.chat_make(self.owner)
	kui.chat_show(&self.chat, false)
	gd.connect_to(cast(gd.Object)self.chat.input, "text_submitted", self.owner, "on_chat")

	// The cave (phase 3): item defs are code — every peer declares the same
	// table. World hookups install now; entities exist only after Start.
	kitems.items_register(&self.table, GEM, "gem", 99)
	kitems.items_register(&self.table, TORCH, "torch", 5)
	self.world = gd.new_node()
	gd.node_set_name(self.world, gd.new_string_name_cstring("World", true))
	gd.add_child(self.owner, self.world)
	self.prompt = kui.prompt_make(self.owner)
	self.inv = kui.inv_make(self.owner, 6)
	kui.inv_show(&self.inv, false)
	self.hud_hp = kui.hp_make(self.owner)
	self.hud_ab = kui.abilities_make(self.owner, 2)
	self.score = kui.score_make(self.owner)
	self.latency = f64(env_int("CAVE_LATENCY", 0)) / 1000.0
	ksess.session_set_factory(&self.ses, self, cave_make_entity, cave_free_entity)
	ksess.session_set_command_hook(&self.ses, self, cave_command_hook)
	ksess.session_app_route(&self.ses, TAG_FIRE, self, cave_on_fire)
	install_controls()
	self.legend = gd.new_label()
	gd.node_set_name(cast(gd.Node)self.legend, gd.new_string_name_cstring("Legend", true))
	gd.add_child(self.owner, cast(gd.Node)self.legend)
	gd.control_set_anchors_preset(cast(gd.Control)self.legend, .Preset_Bottom_Left, false)
	gd.set_string(cast(gd.Object)self.legend, "text", "WASD walk · E use · click/Space throw · Q drop · Tab scores · Enter chat")
	gd.set_bool(cast(gd.Object)self.legend, "visible", false)
	gd.print_str("CAVE_UI_READY")
}

// Both roles flip to game mode the same way (host at Start, client at spawn).
enter_the_cave :: proc(self: ^CaveLobby) {
	self.started = true
	gd.set_bool(cast(gd.Object)self.ui.root, "visible", false)
	gd.set_bool(cast(gd.Object)self.legend, "visible", true)
	kui.inv_show(&self.inv, true)
	if self.me_spel != nil {
		kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
		refresh_hud(self)
	}
}

@(private = "file")
roster_changed :: proc(self: ^CaveLobby) {
	n := ksess.session_count(&self.ses, connected_only = true)
	gd.print_str(fmt.tprintf("CAVE_PLAYERS n=%d", n))
	if self.ses.is_host {
		kui.lobby_set_status(&self.ui, fmt.ctprintf("%d spelunkers ready", n))
		// Enough friends: the host may start (phase 3 gives Start a game).
		kui.lobby_show_menu(&self.ui, false, n >= 2)
	}
}

cave_lobby_process :: proc(self: ^CaveLobby, delta: f64) {
	if !self.running {return}

	// The fake wire delivers (acid runs only; self.latency == 0 otherwise).
	for len(self.delayed) > 0 && self.delayed[0].due <= now_s() {
		pkt := self.delayed[0]
		ordered_remove(&self.delayed, 0)
		r := knet.reader_make(pkt.data)
		if knet.read_u8(&r) == MSG_SESSION {
			ksess.session_handle_packet(&self.ses, pkt.from, &r)
		}
		delete(pkt.data)
	}

	// Client: seat ourselves as soon as the transport handshake completes.
	if !self.ses.is_host && !self.join_sent {
		mp := gd.node_get_multiplayer(self.owner)
		if cast(rawptr)mp != nil && gd.multiplayer_api_has_multiplayer_peer(mp) {
			peers := gd.multiplayer_api_get_peers(mp)
			if gd.packed_int32_array_size(&peers) > 0 {
				ksess.session_client_join(&self.ses)
				self.join_sent = true
			}
		}
	}

	ticks, _ := ksess.session_tick(&self.ses, delta, now_s())
	if self.started {
		// Visuals fly FIRST, on the frame clock (smooth on any refresh
		// rate): on the host, the impact you see is noted before the
		// authority's tick deals the damage in the same frame — the
		// overlay consumes that truth cleanly instead of double-dipping.
		cave_visual_frame(self, delta) // every peer flies its own screen's rocks
		fx_frame(self, delta) // reap spent particle bursts
		if self.ses.is_host {
			for _ in 0 ..< ticks {
				cave_host_tick(self)
			}
		}
	}

	refresh := false
	for {
		ev, ok := ksess.session_poll(&self.ses)
		if !ok {break}
		#partial switch e in ev {
		case ksess.Ev_Welcomed:
			kui.lobby_set_status(&self.ui, "In the cave — waiting for the host to start")
			gd.print_str(fmt.tprintf("CAVE_SEATED me=%d", u64(e.me)))
			refresh = true
		case ksess.Ev_Player_Joined:
			roster_changed(self)
			refresh = true
			// The host words the flavor lines; comms ships them. Catchup goes
			// FIRST so a fresh joiner's replayed history doesn't duplicate the
			// join line it is about to receive from the broadcast.
			if self.ses.is_host {
				if p, ok := ksess.session_player(&self.ses, e.id); ok {
					if !e.rejoin {
						kcomms.comms_catchup(&self.comms, e.id)
					}
					verb := e.rejoin ? "returned to" : "joined"
					kcomms.comms_system(&self.comms, fmt.tprintf("%s %s the cave", p.name, verb))
				}
			}
		case ksess.Ev_Player_Left:
			roster_changed(self)
			refresh = true
			if self.ses.is_host {
				if p, ok := ksess.session_player(&self.ses, e.id); ok {
					kcomms.comms_system(&self.comms, fmt.tprintf("%s wandered off", p.name))
				}
			}
		case ksess.Ev_Stats_Updated:
			refresh = true // ping column repaint
			kui.score_refresh(&self.score, &self.ses)
		case ksess.Ev_Host_Left:
			kui.lobby_set_status(&self.ui, "The host left — this run is over")
			gd.print_str("CAVE_HOST_LEFT")
		case ksess.Ev_Spawned:
			// The world reached this client (factory already made the node).
			if !self.started {
				enter_the_cave(self)
			}
			gd.print_str(fmt.tprintf("CAVE_SPAWN id=%d mine=%v", u32(e.id), e.owner == self.ses.me))
		case ksess.Ev_State_Applied:
			if self.me_spel != nil {
				kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
				refresh_hud(self)
			}
		case ksess.Ev_Command_Executed:
			gd.print_str(fmt.tprintf("CAVE_EXEC ok=%v entity=%d cmd=%d", e.ok, u32(e.entity), e.cmd))
		case ksess.Ev_Command_Confirmed:
			dt_ms := self.issue_at > 0 ? int((now_s() - self.issue_at) * 1000) : 0
			gd.print_str(fmt.tprintf("CAVE_CONFIRM dt_ms=%d", dt_ms))
		case ksess.Ev_Command_Rejected:
			gd.print_str(fmt.tprintf("CAVE_REJECT entity=%d", u32(e.entity)))
		}
	}
	if refresh {
		kui.lobby_refresh(&self.ui, &self.ses)
	}

	refresh_chat := false
	for {
		cev, cok := kcomms.comms_poll(&self.comms)
		if !cok {break}
		switch e in cev {
		case kcomms.Ev_Line:
			refresh_chat = true
		case kcomms.Ev_Marker:
			// No world yet to draw it in — phase 3 gives markers a cave wall.
			gd.print_str(fmt.tprintf("CAVE_MARK player=%d kind=%d x=%.1f", u64(e.player), e.kind, e.pos.x))
		}
	}
	if refresh_chat {
		kui.chat_refresh(&self.chat, &self.comms)
	}

	if self.started {
		poll_controls(self)
	}
	if self.started && self.me_spel != nil {
		// Owner-side respawn: hp coming back is the signal to walk out of
		// the grave — position is owner-streamed, only I can move me.
		if self.me_spel.hp <= 0 {
			if !self.was_dead {
				self.was_dead = true
				self.walking = false
				gd.print_str("CAVE_DIED")
			}
		} else if self.was_dead {
			self.was_dead = false
			self.me_spel.x = SPAWN_X
			self.me_spel.y = SPAWN_Y
			gd.print_str("CAVE_RESPAWNED")
		}
		if self.me_spel.hp > 0 {
			drive_spelunker(self, delta)
		}
		update_prompt(self)
		refresh_hud(self) // live bar + cooldown text (hosts get no state events)
	}
}
