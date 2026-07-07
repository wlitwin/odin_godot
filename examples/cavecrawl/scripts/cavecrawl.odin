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
import kboot "godot:kit/boot"
import kcombat "godot:kit/combat"
import kcomms "godot:kit/comms"
import kfx "godot:kit/fx"
import kitems "godot:kit/items"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import steamgd "godot:kit/steamgd"
import kui "godot:kit/ui"
import netgd "godot:kit/netgd"
import "core:fmt"

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
LEVEL_TYPE :: ksess.Entity_Type(6)
RELIC_TYPE :: ksess.Entity_Type(7)

WALK_SPEED :: f32(120) // px/s

// ---- combat (phase 4) ----

MAX_HP :: i32(100)
MAX_STAMINA :: i32(10)
ROCK_ABILITY :: kcombat.Ability_Def{name = "rock", cooldown = 20, cost = 3} // 1s at 20 Hz
HEAL_ABILITY :: kcombat.Ability_Def{name = "bandage", cooldown = 60, cost = 5} // 3s
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

// Command indices (SPELUNKER_CMD_THROW, CHEST_CMD_TAKE, ...) are GENERATED
// per class — see the *.gen.odin files; never hand-sync them.

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
	owner:     gd.Node,
	ses:       ksess.Session,
	comms:     kcomms.Comms,
	boot:      kboot.Boot, // lobby/chat/score/legend/wire/stage/world — kit-built, game-owned
	running:   bool, // hosting or joining (transport is up)

	// The authored entity scenes, assigned in cave.tscn's inspector — the
	// factory instantiates these; the entity structs only tag what
	// replicates. Bodies, particles, and layout live in the editor.
	spelunker_scene: ^gd.Resource `gd:"export,resource=PackedScene"`,
	chest_scene:     ^gd.Resource `gd:"export,resource=PackedScene"`,
	door_scene:      ^gd.Resource `gd:"export,resource=PackedScene"`,
	pickup_scene:    ^gd.Resource `gd:"export,resource=PackedScene"`,
	dweller_scene:   ^gd.Resource `gd:"export,resource=PackedScene"`,
	level_scene:     ^gd.Resource `gd:"export,resource=PackedScene"`,
	relic_scene:     ^gd.Resource `gd:"export,resource=PackedScene"`,

	// The campaign: one CaveLevelDef data asset per floor (scene + loot +
	// waves), authored in the inspector.
	floor1_def: ^gd.Resource `gd:"export,resource=CaveLevelDef"`,
	floor2_def: ^gd.Resource `gd:"export,resource=CaveLevelDef"`,

	// The current floor, as loaded on THIS peer: the scene instance under
	// `stage`, plus the host-side caches read from its def + markers.
	scenery:       gd.Node, // the loaded level_N.tscn instance (nil pre-game)
	scenery_depth: u8, // which depth `scenery` shows
	dens:          [2][3]f32, // host: den positions, from the floor's markers
	waves:         [MAX_WAVES]kai.Wave, // host: the floor's wave plan
	waves_n:       int,

	// ---- the world (phase 3) ----
	table:       kitems.Table,
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
	level:       ^Level, // the run's depth marker (nil until spawned)
	seen_depth:  u8, // owner-side descent edge: teleport to the new floor's mouth
	seen_won:    bool, // match-over edge: end screen up on won=1, down on won=0
	floors_n:    int, // how deep the cave goes (CAVE_FLOORS env shrinks it for tests)
	kicked_out:  bool, // we were removed on purpose — mutes the host-left line that follows
	steam_on:    bool, // GodotSteam present + initialized (kit/steamgd)
	relic:       ^Relic, // the carryable (ownership-transfer demo); nil pre-world
	relic_id:    knet.Net_Id,
	steam_lobby: u64, // the Steam lobby we host or sit in (invite target)
	deny_reason: int, // last Ev_Join_Denied reason (-1 = none); drivers read it
	started:     bool, // the world is live
	walking:     bool, // headless drivers steer via walk_to
	walk_target: gd.Vector2,
	target_id:   knet.Net_Id, // what the prompt points at right now
	target_kind: int, // 0 none, 1 chest, 2 door, 3 pickup

	// ---- combat (phase 4) ----
	cols:       kcombat.Combat_Cols, // host: the auto-published ledger columns
	flying:     [dynamic]Cave_Rock, // host: the authoritative rock sim
	tracers:    kfx.Tracers, // every peer: the rocks on THIS screen (px/tick -> px/s, see rocks.odin)
	fires:      kcombat.Fire_Route, // the announcement listener's registration
	fx:         kfx.Bursts, // every peer: live particle bursts (fx.odin narrates, kit/fx reaps)
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
	chat_sent:  bool, // the Enter that submitted a line must not also re-open chat
	was_dead:   bool, // owner-side respawn edge detector
	host_gone:  bool, // Ev_Host_Left seen — the takeover/rejoin window is open
	succ_seen:  int, // Ev_Succession count (latched; drivers poll it — host_gone flips back within a frame)
	rejoin_tries: int, // auto-rejoin attempts chasing the successor (capped)
	issue_at:   f64, // when my last command left (confirm latency proof)

}

now_s :: knet.now_s // the toolkit's monotonic clock, under the game's short name

refresh_hud :: proc(self: ^CaveLobby) {
	if self.me_spel == nil {return}
	kui.hp_refresh(&self.hud_hp, hp_view(self.me_spel), MAX_HP)
	defs := [?]kcombat.Ability_Def{ROCK_ABILITY, HEAL_ABILITY}
	kui.abilities_refresh(&self.hud_ab, defs[:], self.me_spel.cds[:], self.me_spel.stamina, ksess.session_tick_hz(&self.ses))
	// The bag too: hosts get no state events, and a verb-only repaint left
	// the host's grid showing loot its death had long since spilled.
	kui.inv_refresh(&self.inv, self.me_spel.bag[:], &self.table)
}

cave_lobby_ready :: proc(self: ^CaveLobby) {
	// The cave (phase 3): item defs are code — every peer declares the same
	// table. World hookups install now; entities exist only after Start.
	kitems.items_register(&self.table, GEM, "gem", 99)
	kitems.items_register(&self.table, TORCH, "torch", 5)
	ksess.session_set_factory(&self.ses, self, cave_make_entity, cave_free_entity)
	ksess.session_set_backup_blob(&self.ses, self, cave_backup_blob)
	ksess.session_set_command_hook(&self.ses, self, cave_command_hook)
	kcombat.fire_listen(&self.fires, &self.ses, TAG_FIRE, self, cave_on_fire)

	// The stock stack — lobby, chat+comms, scoreboard, stage/world, wire,
	// legend — is kit/boot's. Everything below is what makes this CAVECRAWL.
	kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, kboot.Options{
		title = "C A V E C R A W L",
		status = "Host a cave, or join one at localhost",
		legend = "WASD walk · E use · click throw · Q drop · G set down · R heal · Tab scores · Enter chat",
		msg_kind = MSG_SESSION,
		latency_env = "CAVE_LATENCY",
		methods = {"on_host", "on_join", "on_start", "on_chat", "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})

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
		if self.relic != nil && self.me_spel != nil &&
		   ksess.session_owner_of(&self.ses, self.relic_id) == self.ses.me {
			self.relic.x = self.me_spel.x + 10
			self.relic.y = self.me_spel.y - 12
		}
		kfx.frame(&self.fx, delta) // reap spent particle bursts
		if self.ses.is_host {
			for _ in 0 ..< ticks {
				cave_host_tick(self)
			}
		}
	}

	for ev in events {
		#partial switch e in ev {
		case ksess.Ev_Welcomed:
			// Seated = the host exists, BY DEFINITION — clear the loss latch
			// here, not just at rejoin start: the OLD socket's death signals
			// can land mid-rejoin (after cave_rejoin_to cleared the flag,
			// before this WELCOME) and re-latch it against the LIVE host,
			// blocking every "are we back?" gate forever.
			self.host_gone = false
			self.rejoin_tries = 0 // seated: the chase (if any) is over
			gd.print_str(fmt.tprintf("CAVE_SEATED me=%d", u64(e.me)))
		case ksess.Ev_Player_Joined:
			gd.print_str(fmt.tprintf("CAVE_PLAYERS n=%d", ksess.session_count(&self.ses, connected_only = true)))
			// The host words the flavor lines; comms ships them. Catchup goes
			// FIRST so a fresh joiner's replayed history doesn't duplicate the
			// join line it is about to receive from the broadcast.
			if self.ses.is_host {
				if p, ok := ksess.session_player(&self.ses, e.id); ok {
					verb := e.rejoin ? "returned to" : "joined"
					kcomms.comms_welcome(&self.comms, e.id, e.rejoin, fmt.tprintf("%s %s the cave", p.name, verb))
				}
			}
		case ksess.Ev_Player_Left:
			gd.print_str(fmt.tprintf("CAVE_PLAYERS n=%d", ksess.session_count(&self.ses, connected_only = true)))
			if self.ses.is_host {
				if p, ok := ksess.session_player(&self.ses, e.id); ok {
					kcomms.comms_system(&self.comms, fmt.tprintf("%s wandered off", p.name))
				}
			}
		case ksess.Ev_Host_Left:
			self.host_gone = true
			if !self.kicked_out { // the kick already explained this teardown
				// The designated backup holder can carry the torch; everyone
				// else rejoins whoever does (see on_takeover / on_rejoin).
				_, _, held := ksess.session_backup_parts(&self.ses)
				kui.lobby_set_status(&self.boot.ui, held ? "The host left — you hold the backup. Resume?" : "The host left — this run is over")
				gd.print_str("CAVE_HOST_LEFT")
			}
		case ksess.Ev_Backup_Target:
			// LIVE MIGRATION, the host's half: the session named WHO carries
			// the torch; the transport knows WHERE they are. Convention: the
			// successor re-binds the same port everyone already uses.
			if p, ok := ksess.session_player(&self.ses, e.player); ok {
				addr, aok := netgd.peer_address(self.owner, p.peer)
				if !aok {
					addr = "127.0.0.1"
				}
				w := knet.writer_make()
				defer knet.writer_destroy(&w)
				knet.write_string(&w, addr)
				knet.write_u16(&w, u16(port()))
				ksess.session_set_successor_info(&self.ses, knet.writer_bytes(&w))
				gd.print_str(fmt.tprintf("CAVE_TORCH_NAMED player=%d addr=%s", u64(e.player), addr))
			}
		case ksess.Ev_Succession:
			// LIVE MIGRATION, everyone else's half: hands-free. The torch
			// bearer takes over; the rest chase them (this event re-fires on
			// every failed reconnect — the natural retry pulse).
			self.succ_seen += 1
			if !self.kicked_out && !self.ses.is_host {
				if e.successor == self.ses.me {
					gd.print_str("CAVE_TORCH_MINE")
					cave_lobby_on_takeover(self)
				} else if self.rejoin_tries < 12 {
					self.rejoin_tries += 1
					_, info := ksess.session_successor(&self.ses)
					ir := knet.reader_make(info)
					addr := knet.read_string(&ir)
					sport := int(knet.read_u16(&ir))
					if !ir.err {
						gd.print_str(fmt.tprintf("CAVE_CHASE_TORCH try=%d", self.rejoin_tries))
						cave_rejoin_to(self, addr, sport)
					}
				} else {
					kui.lobby_set_status(&self.boot.ui, "The torch went out — this run is over")
				}
			}
		case ksess.Ev_Backup_Received:
			// We are the designated backup host from this moment on.
			gd.print_str(fmt.tprintf("CAVE_BACKUP size=%d", e.size))
		case ksess.Ev_Kicked:
			self.kicked_out = true
			kui.lobby_set_status(&self.boot.ui, "You were shown the door")
			gd.print_str("CAVE_KICKED_ME")
		case ksess.Ev_Join_Denied:
			line: string
			switch e.reason {
			case .Full:
				line = "The cave is full"
			case .Locked:
				line = "The cave is sealed"
			case .Banned:
				line = "You are not welcome here"
			}
			kui.lobby_set_status(&self.boot.ui, line)
			self.deny_reason = int(e.reason)
			gd.print_str(fmt.tprintf("CAVE_DENIED reason=%v", e.reason))
		case ksess.Ev_Join_Failed:
			gd.print_str("CAVE_JOIN_FAILED")
		case ksess.Ev_Spawned:
			// The world reached this client (factory already made the node).
			if !self.started {
				enter_the_cave(self)
			}
			gd.print_str(fmt.tprintf("CAVE_SPAWN id=%d mine=%v", u32(e.id), e.owner == self.ses.me))
		case ksess.Ev_Owner_Changed:
			// The relic changed hands — every peer hears; the new carrier's
			// process glue starts moving it (no role branch, no carrier map:
			// ownership IS the carrier record).
			if e.id == self.relic_id {
				gd.print_str(fmt.tprintf("CAVE_RELIC owner=%d", u64(e.owner)))
				if self.ses.is_host {
					line := "the relic rests"
					if p, ok := ksess.session_player(&self.ses, e.owner); ok {
						line = fmt.tprintf("%s carries the relic", p.name)
					}
					kcomms.comms_system(&self.comms, line)
				}
			}
		case ksess.Ev_Blob_Changed:
			// The floor's inscription (or any future blob) — variable-length
			// state that arrived with the change, the join snapshot, or a
			// resumed backup; one read, every path.
			if self.level != nil && e.id == self.level.net_id {
				gd.print_str(fmt.tprintf("CAVE_INSCRIPTION %s", string(ksess.session_blob(&self.ses, e.id))))
			}
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
	for m in marks {
		// No world yet to draw it in — phase 3 gives markers a cave wall.
		gd.print_str(fmt.tprintf("CAVE_MARK player=%d kind=%d x=%.1f", u64(m.player), m.kind, m.pos.x))
	}

	if self.started {
		poll_controls(self)
	}
	// Owner-side descent: the replicated depth ticking over is the signal
	// to load the floor's SCENE locally (static presentation never rides
	// the wire) and step to its mouth — position is owner-streamed, only
	// I can move me (the respawn pattern, reused). First sight of a depth
	// (fresh start, resumed save, drop-in join) loads scenery but is not
	// a teleport.
	if self.level != nil && self.level.depth != self.seen_depth {
		cave_load_scenery(self, int(self.level.depth))
		if self.seen_depth != 0 && self.me_spel != nil {
			self.me_spel.x = SPAWN_X + f32(u64(self.ses.me) % 4) * 40
			self.me_spel.y = SPAWN_Y
			self.walking = false
			// A jump, not a walk: remote screens snap instead of sliding
			// my avatar across the whole map.
			ksess.session_teleport(&self.ses, self.me_spel.net_id)
			gd.print_str(fmt.tprintf("CAVE_FLOOR depth=%d", self.level.depth))
		}
		self.seen_depth = self.level.depth
	}
	// MATCH FLOW, both directions of one replicated byte: won going 1 is the
	// end screen (scoreboard + lobby status; the host's Start button reads
	// as "again"), won going 0 is the next run starting — every peer clears
	// its screen off the same delta that rebuilt the floor.
	if self.level != nil {
		if self.level.won != 0 && !self.seen_won {
			self.seen_won = true
			kui.score_show(&self.boot.score, true)
			gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", true)
			kui.lobby_set_status(&self.boot.ui, "The cave is conquered!")
			kui.lobby_show_menu(&self.boot.ui, false, self.ses.is_host)
			gd.print_str(fmt.tprintf("CAVE_WON depth=%d", self.level.depth))
		} else if self.level.won == 0 && self.seen_won {
			self.seen_won = false
			kui.score_show(&self.boot.score, false)
			gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
			gd.print_str("CAVE_RESTARTED")
		}
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
			if self.me_spel.hp >= MAX_HP {
				// BLED OUT and back: a fresh body at the spawn point.
				self.me_spel.x = SPAWN_X
				self.me_spel.y = SPAWN_Y
				ksess.session_teleport(&self.ses, self.me_spel.net_id) // out of the grave in one step, on every screen
				gd.print_str("CAVE_RESPAWNED")
			} else {
				// REVIVED where I fell — a friend got there before the clock.
				gd.print_str("CAVE_REVIVED")
			}
		}
		if self.me_spel.hp > 0 {
			drive_spelunker(self, delta)
		}
		update_prompt(self)
		refresh_hud(self) // live bar + cooldown text (hosts get no state events)
	}
}
