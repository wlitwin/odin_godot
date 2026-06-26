//gd:extends Node2D
//gd:class ArenaGame
package coop_arena

// ----------------------------------------------------------------------------
// ArenaGame — the unified, PEER-AUTHORITATIVE co-op survivors orchestrator (root of arena.tscn).
// ONE gameplay codebase, THREE modes, selected at startup; the transport is chosen at COMPILE
// time by platform (native -> ENet, web -> WebRTC):
//
//   * Single — host with ZERO peers. No transport is opened; the SAME pawn/bullet/enemy scripts
//              run, the broadcasts simply reach nobody. This is the unification: single-player
//              == host-with-no-peers, not a separate codebase.
//   * Host   — authoritative for the SHARED HORDE only (enemy spawning + movement), via
//              MultiplayerSpawner + MultiplayerSynchronizer. Owns its OWN pawn like any peer.
//   * Join   — a peer that owns its OWN pawn and resolves its OWN bullets locally.
//
// AUTHORITY MODEL (the whole point — responsiveness with no host round-trip for your actions):
//   * PAWNS are OWNER-authoritative. Each pawn's multiplayer authority = its owner; the owner
//     simulates movement + auto-fire LOCALLY every frame (arena_player.odin); the synchronizer
//     replicates the owner's position/hp to others. No "send input to host, await position".
//   * PROJECTILES are OWNER-authoritative + deterministic-local. The firing peer spawns its
//     bullet LOCALLY the instant it fires (sees its own shot with no delay) and BROADCASTS
//     `fired` so peers spawn a matching ghost. The owner's bullet authoritatively resolves its
//     hit and BROADCASTS the damage/kill (`damage`, call_local) — peers TRUST it (no anti-cheat).
//   * ENEMIES are HOST-authoritative for SPAWN + MOVEMENT (one source of truth for a horde you
//     don't input), but DAMAGE/death is PEER-authoritative: whoever's bullet hit broadcasts the
//     kill and every peer agrees. The host (node owner) frees the node; the spawner replicates
//     the despawn.
//
// A headless scripted session (COOP_ROLE env on native, ?role= query on web) drives the
// deterministic proofs the test harnesses assert; with no role it shows a Single/Host/Join
// start screen for windowed play.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import gdext "godot:gdext"
import rt "godot:runtime"
import "core:fmt"
import "core:strconv"
import "core:math"

IS_WEB :: ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32

DEFAULT_PORT :: 7777
SCRIPT_ENEMY_ID :: 9001
COOP_ENEMY_HP :: 12
SINGLE_ENEMY_HP :: 8
SINGLE_TOUGH_HP :: 999
XP_PER_KILL :: 6
XP_TO_LEVEL :: 5
MOVE_STEP :: f32(5)
MOVE_THRESHOLD :: f32(20)
ENEMY_SPEED :: f32(48)
CONTACT_RADIUS :: f32(22)
CONTACT_DMG :: 25
CONTACT_COOLDOWN :: f64(0.3)
FREE_SPAWN_INTERVAL :: f32(1.1)

when IS_WEB {
	CONNECT_TIMEOUT :: f64(40)
	GLOBAL_TIMEOUT :: f64(75)
} else {
	CONNECT_TIMEOUT :: f64(15)
	GLOBAL_TIMEOUT :: f64(30)
}

// LOBBY_CONNECT_TIMEOUT bounds a WINDOWED (interactive) connect attempt. If "Connecting…/Joining…"
// runs this long with no peer/connection, the lobby treats it as a failure and RESETS to the
// connectable start screen (so a dead room code or an unreachable relay can't hang forever). The
// headless scripted sessions keep CONNECT_TIMEOUT (they quit on failure for the test harness).
LOBBY_CONNECT_TIMEOUT :: f64(18)

Role :: enum {None, Single, Server, Client}
Mode :: enum {Boot, Connecting, Play}

// Lobby_Test selects a headless self-drive of the WINDOWED lobby (web only), used by the gated
// browser harness to prove the retry-recovery + web-paste mechanics without a human: it exercises
// the SAME begin_join/begin_host/on_lobby_input code paths the real buttons + Ctrl/Cmd+V trigger.
Lobby_Test :: enum {Off, Retry, Paste}

ArenaGame :: struct {
	owner:        gd.Node2d,
	players:      gd.Node `gd:"onready=Players"`,
	enemies:      gd.Node `gd:"onready=Enemies"`,
	bullets:      gd.Node `gd:"onready=Bullets"`,
	start_screen: gd.Node `gd:"onready=StartScreen"`,
	status:       gd.Node `gd:"onready=StartScreen/Status"`,
	url_edit:     gd.Node `gd:"onready=StartScreen/UrlEdit"`,
	room_edit:    gd.Node `gd:"onready=StartScreen/RoomEdit"`,
	code_label:   gd.Node `gd:"onready=StartScreen/CodeLabel"`,
	hud_info:     gd.Node `gd:"onready=Hud/Info"`,
	spawner:      gd.Multiplayer_Spawner,

	role:        Role,
	mode:        Mode,
	headless:    bool,

	// windowed lobby recovery + web clipboard paste (Bug 1 + Bug 2)
	reset_count:   int,        // how many times the lobby recovered from a failed attempt
	lobby_test:    Lobby_Test, // headless self-drive of the windowed lobby (web harness)
	lt_phase:      int,
	lt_t:          f64,
	paste_pending: bool,       // an async navigator.clipboard.readText() is in flight (web)
	paste_target:  gd.Node,    // the LineEdit the pasted text lands in
	paste_t:       f64,

	port:        int,
	addr:        string,
	url:         string,
	room:        string,
	room_logged: bool,
	client_id:   int,
	next_id:     int,

	// local progression (per-peer)
	my_xp:    int,
	my_level: int,
	kills:    int,

	// timers
	alive_t: f64,
	settle:  f64,
	contact_cd: f64,
	spawn_accum: f32,

	// scripted bookkeeping
	players_ok:    bool,
	enemy_spawned: bool,
	enemy_dead:    bool,
	saw_move:      bool,
	sees_enemy:    bool,
	enemy_sync:    bool,
	enemy_gone:    bool,
	leveled:       bool,
	moved_logged:  bool,
	move_frames:   int,
	seen_enemy_x:  f32,
	single_phase:  int,
	player_dead:   bool,
	done:          bool,
}

// ---- small helpers ---------------------------------------------------------

@(private = "file")
log :: proc(s: string) {gd.print_str(s)}
@(private = "file")
vi :: proc "contextless" (x: int) -> gd.Variant {v := i64(x); return gd.variant_from(&v)}

@(private = "file")
read_env :: proc(key: cstring) -> string {
	os := gd.singleton_os()
	k := gd.new_string_cstring(key)
	if !bool(gd.os_has_environment(os, k)) {return ""}
	s := gd.os_get_environment(os, k)
	return str_to_odin(s)
}

@(private = "file")
str_to_odin :: proc(s: gd.String) -> string {
	s := s
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, nil, 0)
	if n <= 0 {return ""}
	buf := make([]u8, n, context.temp_allocator)
	gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, cast(cstring)raw_data(buf), n)
	return string(buf)
}

@(private = "file")
web_query :: proc(key: string) -> string {
	when IS_WEB {
		js := gd.singleton_java_script_bridge()
		code := gd.new_string_cstring("location.search || ''")
		v := gd.java_script_bridge_eval(js, code, true)
		search := gd.variant_to_string(&v)
		s := str_to_odin(search)
		if len(s) > 0 && s[0] == '?' {s = s[1:]}
		start := 0
		for i := 0; i <= len(s); i += 1 {
			if i == len(s) || s[i] == '&' {
				kv := s[start:i]
				eq := -1
				for j in 0 ..< len(kv) {if kv[j] == '=' {eq = j; break}}
				if eq > 0 && kv[:eq] == key {return uri_decode(kv[eq + 1:])}
				start = i + 1
			}
		}
		return ""
	} else {
		return ""
	}
}

@(private = "file")
uri_decode :: proc(s: string) -> string {
	out := make([]u8, len(s), context.temp_allocator)
	n := 0; i := 0
	for i < len(s) {
		if s[i] == '%' && i + 2 < len(s) {
			hi := hexval(s[i + 1]); lo := hexval(s[i + 2])
			if hi >= 0 && lo >= 0 {out[n] = u8(hi * 16 + lo); n += 1; i += 3; continue}
		}
		out[n] = s[i]; n += 1; i += 1
	}
	return string(out[:n])
}
@(private = "file")
hexval :: proc(c: u8) -> int {
	switch {
	case c >= '0' && c <= '9': return int(c - '0')
	case c >= 'a' && c <= 'f': return int(c - 'a' + 10)
	case c >= 'A' && c <= 'F': return int(c - 'A' + 10)
	}
	return -1
}
@(private = "file")
sn :: proc "contextless" (s: cstring) -> gd.String_Name {return gd.new_string_name_cstring(s, true)}

@(private = "file")
pawn_start :: proc "contextless" (peer_id: int) -> gd.Vector2 {
	if peer_id == 1 {return gd.Vector2{200, 180}}
	return gd.Vector2{400, 180}
}

@(private = "file")
pawn_node :: proc(self: ^ArenaGame, peer_id: int) -> gd.Node {
	if self.players == nil {return nil}
	return gd.node_get_node_or_null(self.players, gd.new_node_path_cstring(fmt.ctprintf("P%d", peer_id)))
}
@(private = "file")
pawn_count :: proc(self: ^ArenaGame) -> int {
	if self.players == nil {return 0}
	return int(gd.node_get_child_count(self.players, false))
}
@(private = "file")
enemy_count :: proc(self: ^ArenaGame) -> int {
	if self.enemies == nil {return 0}
	return int(gd.node_get_child_count(self.enemies, false))
}
@(private = "file")
first_enemy :: proc(self: ^ArenaGame) -> gd.Node {
	if self.enemies == nil || enemy_count(self) == 0 {return nil}
	return gd.node_get_child(self.enemies, 0, false)
}

@(private = "file")
update_hud :: proc(self: ^ArenaGame) {
	if self.hud_info != nil {
		gd.set_string(self.hud_info, "text", fmt.ctprintf("Lv %d   XP %d/%d   Kills %d", self.my_level, self.my_xp, XP_TO_LEVEL, self.kills))
	}
}

@(private = "file")
maybe_players_ok :: proc(self: ^ArenaGame) {
	if self.players_ok {return}
	need := self.role == .Single ? 1 : 2
	if pawn_count(self) >= need {
		self.players_ok = true
		log(fmt.tprintf("PLAYERS_OK on=%d count=%d", gd.my_peer_id(self.owner), pawn_count(self)))
	}
}

// ---- lifecycle -------------------------------------------------------------

arena_game_ready :: proc(self: ^ArenaGame) {
	self.next_id = 1
	self.addr = "127.0.0.1"
	self.port = DEFAULT_PORT
	self.url = "ws://127.0.0.1:9080"
	self.mode = .Boot
	self.my_level = 1
	gd.add_to_group(self.owner, GROUP_GAME)

	// Build the enemy MultiplayerSpawner on EVERY peer (the client's spawner instantiates the
	// host's res://arena_enemy.tscn spawns). spawn_path is the sibling Enemies node.
	sp := gd.new_multiplayer_spawner()
	gd.node_set_name(sp, gd.new_string_name_cstring("EnemySpawner", false))
	gd.add_child(self.owner, sp)
	gd.multiplayer_spawner_add_spawnable_scene(sp, gd.new_string_cstring("res://arena_enemy.tscn"))
	gd.multiplayer_spawner_set_spawn_path(sp, gd.new_node_path_cstring("../Enemies"))
	self.spawner = sp

	role := read_env("COOP_ROLE")
	when IS_WEB {
		if role == "" {role = web_query("role")}
	}
	if role == "server" || role == "client" || role == "single" || role == "host" || role == "join" {
		self.headless = true
		switch role {
		case "server", "host": self.role = .Server
		case "client", "join": self.role = .Client
		case "single":         self.role = .Single
		}
		if p := read_env("COOP_PORT"); p != "" {if v, ok := strconv.parse_int(p); ok {self.port = v}}
		if a := read_env("COOP_ADDR"); a != "" {self.addr = a}
		when IS_WEB {
			if u := web_query("url"); u != "" {self.url = u}
			if r := web_query("room"); r != "" {self.room = r}
		}
		if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
		log(fmt.tprintf("ARENA_BOOT role=%v web=%v", self.role, IS_WEB))
	} else {
		self.headless = false
		when IS_WEB {
			if u := web_query("url"); u != "" {self.url = u} // let a deploy pin the relay via ?url=
		}
		if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", true)}
		// Default the signaling URL field to the real value so a joiner usually only needs the room
		// code (it stays editable for other deploys).
		if self.url_edit != nil {gd.set_string(self.url_edit, "text", fmt.ctprintf("%s", self.url))}
		if self.code_label != nil {gd.set_string(self.code_label, "text", "")}
		wire_button(self, "SingleButton", "on_single")
		wire_button(self, "HostButton", "on_host")
		wire_button(self, "JoinButton", "on_join")
		when IS_WEB {
			// Web paste fix (Bug 2): the built-in LineEdit paste reads DisplayServer.clipboard_get,
			// which is empty in the web export (the browser clipboard is async + permissioned). We
			// intercept Ctrl/Cmd+V on the lobby fields and read navigator.clipboard via the JS bridge.
			wire_signal(self, "UrlEdit", "gui_input", "on_lobby_input")
			wire_signal(self, "RoomEdit", "gui_input", "on_lobby_input")
			// Headless self-drive hooks for the gated browser harness (no human needed).
			switch web_query("lobbytest") {
			case "retry": self.lobby_test = .Retry
			case "paste": self.lobby_test = .Paste
			}
		}
	}
	update_hud(self)
}

@(private = "file")
wire_button :: proc(self: ^ArenaGame, name: cstring, method: cstring) {
	if self.start_screen == nil {return}
	b := gd.get_node(self.start_screen, name)
	if b != nil {gd.connect_to(b, "pressed", self.owner, method)}
}

@(private = "file")
wire_signal :: proc(self: ^ArenaGame, name: cstring, signal: cstring, method: cstring) {
	if self.start_screen == nil {return}
	b := gd.get_node(self.start_screen, name)
	if b != nil {gd.connect_to(b, signal, self.owner, method)}
}

@(private = "file")
set_lobby_buttons_enabled :: proc(self: ^ArenaGame, enabled: bool) {
	if self.start_screen == nil {return}
	for name in ([]cstring{"SingleButton", "HostButton", "JoinButton"}) {
		if b := gd.get_node(self.start_screen, name); b != nil {gd.set_bool(b, "disabled", !enabled)}
	}
}

arena_game_process :: proc(self: ^ArenaGame, delta: f64) {
	when IS_WEB {
		gd.webrtc_poll(self.owner)
		lobby_paste_poll(self, delta)
		lobby_web_update(self)
		if self.lobby_test != .Off {lobby_test_drive(self, delta)}
	}
	self.alive_t += delta

	switch self.mode {
	case .Boot:
		if self.role == .None {return}
		start_session(self)
		self.mode = .Connecting
		self.alive_t = 0

	case .Connecting:
		if self.role == .Single {
			spawn_pawn_local(self, 1)
			self.mode = .Play
			self.alive_t = 0
			return
		}
		my := gd.my_peer_id(self.owner)
		peers := gd.connected_peers(self.owner)
		if my != 0 && len(peers) >= 1 {
			if self.role == .Server {
				self.client_id = peers[0]
				log(fmt.tprintf("SERVER_SEES_CLIENT id=%d", self.client_id))
				gd.rpc(self.owner, "spawn_pawn", vi(1))
				gd.rpc(self.owner, "spawn_pawn", vi(self.client_id))
			} else {
				log(fmt.tprintf("CLIENT_SEES_SERVER REPORT my_id=%d", my))
			}
			// Connected — drop the lobby panel for windowed play.
			if !self.headless && self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
			self.mode = .Play
			self.alive_t = 0
		} else if self.headless {
			// Scripted sessions quit on failure so the harness sees a deterministic timeout.
			if self.alive_t > CONNECT_TIMEOUT {
				log(fmt.tprintf("%v_TIMEOUT: no peer", self.role))
				quit_now(self, 1)
			}
		} else {
			// WINDOWED (Bug 1): RECOVER on ANY connect failure — a signaling error (no_room/full),
			// the peer dropping mid-connect (closed/peer_left -> Failed), or a connect timeout —
			// reset to the connectable start screen so the user can attempt again with no reload.
			failed := false
			reason := "timed out"
			when IS_WEB {
				if er := gd.webrtc_error_reason(self.owner); er != "" {
					failed = true; reason = er
				} else if gd.webrtc_session_state(self.owner) == .Failed {
					failed = true; reason = "connection failed"
				}
			}
			// The connect TIMEOUT only fires while we're still trying to reach the other side. A HOST
			// that successfully opened its room (web: got a room code; native: ENet bound) is healthily
			// WAITING for a friend and must NOT reset — only a stuck joiner / unreachable relay does.
			waiting_ok := false
			when IS_WEB {
				if self.role == .Server && self.room_logged {waiting_ok = true}
			} else {
				if self.role == .Server {waiting_ok = true}
			}
			if !failed && !waiting_ok && self.alive_t > LOBBY_CONNECT_TIMEOUT {failed = true; reason = "timed out"}
			if failed {lobby_reset(self, reason)}
		}

	case .Play:
		maybe_players_ok(self)
		update_hud(self)
		if self.headless {
			scripted_tick(self, delta)
			if self.alive_t > GLOBAL_TIMEOUT && !self.done {
				log(fmt.tprintf("%v_TIMEOUT: scripted loop did not complete", self.role))
				quit_now(self, 1)
			}
		} else {
			free_play_tick(self, delta)
		}
	}
}

@(private = "file")
start_session :: proc(self: ^ArenaGame) {
	if self.role == .Single {return}
	when IS_WEB {
		ok := self.role == .Server \
			? gd.webrtc_host(self.owner, fmt.ctprintf("%s", self.url)) \
			: gd.webrtc_join(self.owner, fmt.ctprintf("%s", self.url), fmt.ctprintf("%s", self.room))
		if ok {log(fmt.tprintf("WEBRTC_%v_STARTED url=%s room=%s", self.role, self.url, self.room))} else {log("TRANSPORT_FAIL"); quit_now(self, 1)}
	} else {
		if self.role == .Server {
			if gd.host(self.owner, self.port) {
				gd.on_peer_connected(self.owner, "on_peer_connected")
				gd.on_peer_disconnected(self.owner, "on_peer_disconnected")
				log(fmt.tprintf("HOST_OK port=%d is_server=%v", self.port, gd.is_server(self.owner)))
			} else {log("HOST_FAIL"); quit_now(self, 1)}
		} else {
			if gd.join(self.owner, fmt.ctprintf("%s", self.addr), self.port) {
				log(fmt.tprintf("CLIENT_STARTED addr=%s port=%d", self.addr, self.port))
			} else {log("CLIENT_FAIL"); quit_now(self, 1)}
		}
	}
}

// lobby_web_update (web only) — surface the room-code lobby state every frame: capture + log the
// host's assigned CODE once it arrives (so a friend / the test driver can read it), and reflect
// connecting / waiting / connected / error in the windowed start-screen status + code labels.
@(private = "file")
lobby_web_update :: proc(self: ^ArenaGame) {
	when IS_WEB {
		if self.role != .Server && self.role != .Client {return}
		if self.role == .Server && !self.room_logged {
			code := gd.webrtc_room_code(self.owner)
			if len(code) > 0 {
				self.room_logged = true
				self.room = code
				log(fmt.tprintf("ROOM_CODE %s", code)) // headless driver scrapes this
				if !self.headless && self.code_label != nil {
					gd.set_string(self.code_label, "text", fmt.ctprintf("ROOM CODE:  %s   (share with a friend)", code))
				}
			}
		}
		if self.headless {return}
		// Windowed status line.
		if self.status == nil {return}
		if reason := gd.webrtc_error_reason(self.owner); reason != "" {
			gd.set_string(self.status, "text", fmt.ctprintf("Error: %s", reason))
			return
		}
		if self.mode == .Play {
			gd.set_string(self.status, "text", "Connected!")
		} else if self.role == .Server {
			if self.room_logged {
				gd.set_string(self.status, "text", "Waiting for a friend to join...")
			} else {
				gd.set_string(self.status, "text", "Hosting — contacting signaling server...")
			}
		} else {
			gd.set_string(self.status, "text", fmt.ctprintf("Joining room %s...", self.room))
		}
	}
}

@(private = "file")
quit_now :: proc(self: ^ArenaGame, code: int) {
	tree := gd.get_tree(self.owner)
	if tree != nil {gd.scene_tree_quit(tree, gd.Int(code))}
}

// ---- pawn spawning (host-orchestrated, OWNER-authoritative) -----------------

@(private = "file")
spawn_pawn_local :: proc(self: ^ArenaGame, peer_id: int) {
	if pawn_node(self, peer_id) != nil {return}
	p := gd.instantiate(gd.load_scene("res://arena_player.tscn"))
	if p == nil {return}
	gd.node_set_name(p, gd.new_string_name_cstring(fmt.ctprintf("P%d", peer_id), false))
	gd.add_child(self.players, p)
	// OWNER authority: set recursively so the child MultiplayerSynchronizer streams FROM the
	// owner (the owner sims its own pawn; everyone else renders the synced transform).
	gd.node_set_multiplayer_authority(p, gd.Int(peer_id), true)
	gd.node2d_set_position(cast(gd.Node2d)p, pawn_start(peer_id))
	cp := rt.script_of(p, ArenaPlayer)
	if cp != nil {
		arena_player_recolor(cp, peer_id)
		// Arm auto-fire on MY OWN pawn. In the headless co-op test the host disarms its own pawn
		// so the CLIENT is the deterministic shooter; everyone is armed in free play / single.
		if peer_id == gd.my_peer_id(self.owner) || (self.role == .Single && peer_id == 1) {
			cp.armed = !(self.headless && self.role == .Server)
		}
	}
	maybe_players_ok(self)
}

// ---- fire / damage (called by pawns + bullets; same package) ---------------

// arena_player_fire — invoked by the OWNER's pawn the instant it auto-fires. It spawns the
// owner's bullet LOCALLY right now (zero round-trip — the owner sees its shot immediately) and
// BROADCASTS the shot so peers spawn a matching ghost. NOT an RPC handler — a plain local call.
arena_player_fire :: proc(game: ^ArenaGame, shooter: int, origin: gd.Vector2, dir: gd.Vector2, damage: int, color: gd.Color) {
	arena_spawn_bullet(game, shooter, origin, dir, damage, color, true) // local OWNED bullet (logs BULLET_LOCAL)
	ox := int(origin.x); oy := int(origin.y)
	dx := int(dir.x * 1000); dy := int(dir.y * 1000)
	gd.rpc(game.owner, "fired", vi(shooter), vi(ox), vi(oy), vi(dx), vi(dy))
}

// arena_broadcast_damage — invoked by the OWNER's bullet when it hits. Peer-authoritative:
// broadcast (call_local) so every peer applies the SAME damage/kill and agrees on the death.
arena_broadcast_damage :: proc(game: ^ArenaGame, eid: int, amount: int, killer: int) {
	gd.rpc(game.owner, "damage", vi(eid), vi(amount), vi(killer))
}

@(private = "file")
arena_spawn_bullet :: proc(game: ^ArenaGame, shooter: int, origin: gd.Vector2, dir: gd.Vector2, damage: int, color: gd.Color, owned: bool) {
	if game.bullets == nil {return}
	b := gd.instantiate(gd.load_scene("res://arena_bullet.tscn"))
	if b == nil {return}
	gd.add_child(game.bullets, b)
	gd.node2d_set_global_position(cast(gd.Node2d)b, origin)
	bs := rt.script_of(b, ArenaBullet)
	if bs != nil {
		bs.dir = dir; bs.damage = damage; bs.owner_peer = shooter; bs.owned = owned
		body := gd.get_node(b, "Body")
		if body != nil {gd.polygon2d_set_color(cast(gd.Polygon2d)body, color)}
	}
	if owned {
		log(fmt.tprintf("BULLET_LOCAL on=%d shooter=%d", gd.my_peer_id(game.owner), shooter))
	} else {
		log(fmt.tprintf("BULLET_REMOTE on=%d shooter=%d", gd.my_peer_id(game.owner), shooter))
	}
}

@(private = "file")
grant_xp :: proc(self: ^ArenaGame, amount: int) {
	self.my_xp += amount
	for self.my_xp >= XP_TO_LEVEL {
		self.my_xp -= XP_TO_LEVEL
		self.my_level += 1
		self.leveled = true
		// real progression: bump my own pawn's damage
		if n := pawn_node(self, self.role == .Single ? 1 : gd.my_peer_id(self.owner)); n != nil {
			if cp := rt.script_of(n, ArenaPlayer); cp != nil {cp.damage += 2}
		}
		log(fmt.tprintf("LEVELUP on=%d level=%d", gd.my_peer_id(self.owner), self.my_level))
	}
	update_hud(self)
}

// ---- host enemy simulation (host-authoritative position + contact) ---------

@(private = "file")
host_spawn_enemy :: proc(self: ^ArenaGame, id: int, pos: gd.Vector2, hp: int) {
	e := gd.instantiate(gd.load_scene("res://arena_enemy.tscn"))
	if e == nil {return}
	gd.node_set_name(e, gd.new_string_name_cstring(fmt.ctprintf("E%d", id), false))
	ce := rt.script_of(e, ArenaEnemy)
	if ce != nil {ce.id = id; ce.hp = hp}
	gd.node2d_set_position(cast(gd.Node2d)e, pos)
	gd.add_child(self.enemies, e)
}

// host_enemy_sim — host moves each enemy toward the nearest pawn (synchronizer streams it) and,
// in SINGLE/host-owned cases, applies contact damage to pawns it has authority over.
@(private = "file")
host_enemy_sim :: proc(self: ^ArenaGame, delta: f64) {
	if self.role == .Client {return}
	if self.contact_cd > 0 {self.contact_cd -= delta}
	cnt := enemy_count(self)
	for i in 0 ..< cnt {
		e := gd.node_get_child(self.enemies, gd.Int(i), false)
		if e == nil {continue}
		epos := gd.node2d_get_position(cast(gd.Node2d)e)
		tp, tnode, ok := nearest_pawn(self, epos)
		if !ok {continue}
		d := normalized(gd.Vector2{tp.x - epos.x, tp.y - epos.y})
		epos.x += d.x * ENEMY_SPEED * f32(delta)
		epos.y += d.y * ENEMY_SPEED * f32(delta)
		gd.node2d_set_position(cast(gd.Node2d)e, epos)
		// contact damage — only to pawns the host has authority over (its own / single's lone one)
		dx := tp.x - epos.x; dy := tp.y - epos.y
		if dx * dx + dy * dy <= CONTACT_RADIUS * CONTACT_RADIUS && self.contact_cd <= 0 {
			if bool(gd.node_is_multiplayer_authority(cast(gd.Node)tnode)) {
				cp := rt.script_of(cast(gd.Object)tnode, ArenaPlayer)
				if cp != nil && cp.hp > 0 {
					cp.hp -= CONTACT_DMG
					self.contact_cd = CONTACT_COOLDOWN
					if cp.hp <= 0 && !self.player_dead {
						self.player_dead = true
						log(fmt.tprintf("PLAYER_DIED on=%d", gd.my_peer_id(self.owner)))
					}
				}
			}
		}
	}
}

@(private = "file")
nearest_pawn :: proc(self: ^ArenaGame, from: gd.Vector2) -> (gd.Vector2, gd.Node, bool) {
	cnt := pawn_count(self)
	best: gd.Vector2; best_node: gd.Node = nil
	best_d := max(f32); found := false
	for i in 0 ..< cnt {
		p := gd.node_get_child(self.players, gd.Int(i), false)
		if p == nil {continue}
		pos := gd.node2d_get_position(cast(gd.Node2d)p)
		dx := pos.x - from.x; dy := pos.y - from.y
		d := dx * dx + dy * dy
		if d < best_d {best_d = d; best = pos; best_node = p; found = true}
	}
	return best, best_node, found
}

@(private = "file")
park_pawn :: proc(self: ^ArenaGame, peer_id: int, pos: gd.Vector2) {
	if n := pawn_node(self, peer_id); n != nil {gd.node2d_set_position(cast(gd.Node2d)n, pos)}
}

// ---- scripted (headless) tick ----------------------------------------------

@(private = "file")
scripted_tick :: proc(self: ^ArenaGame, delta: f64) {
	switch self.role {
	case .Single:
		single_tick(self, delta)
	case .Server:
		host_enemy_sim(self, delta)
		if self.players_ok && !self.enemy_spawned {
			self.settle += delta
			if self.settle > 0.4 {
				self.enemy_spawned = true
				// keep the host's own pawn well clear of the test enemy so the CLIENT is the
				// only shooter (its pawn is disarmed too — belt and braces).
				park_pawn(self, 1, gd.Vector2{40, 40})
				host_spawn_enemy(self, SCRIPT_ENEMY_ID, gd.Vector2{400, 110}, COOP_ENEMY_HP)
				log(fmt.tprintf("ENEMY_SPAWN on=%d id=%d", gd.my_peer_id(self.owner), SCRIPT_ENEMY_ID))
			}
		}
		// observe the client's pawn move via the synchronizer (owner-auth move replicated to host)
		if !self.saw_move && self.client_id != 0 {
			if n := pawn_node(self, self.client_id); n != nil {
				x := gd.node2d_get_position(cast(gd.Node2d)n).x
				if x > pawn_start(self.client_id).x + MOVE_THRESHOLD {
					self.saw_move = true
					log(fmt.tprintf("SAW_REMOTE_MOVE on=1 peer=%d x=%.1f", self.client_id, f64(x)))
				}
			}
		}
		if self.saw_move && self.enemy_dead && !self.done {
			self.done = true
			log(fmt.tprintf("SERVER_SUMMARY pawns=%d kills=%d", pawn_count(self), self.kills))
			log("SERVER_DONE")
			quit_now(self, 0)
		}
	case .Client:
		me := gd.my_peer_id(self.owner)
		if self.players_ok {
			// drive our OWN pawn right — we hold its authority, so we write its position LOCALLY
			// (no round-trip) and the synchronizer streams it to the host.
			if n := pawn_node(self, me); n != nil {
				pos := gd.node2d_get_position(cast(gd.Node2d)n)
				pos.x += MOVE_STEP
				if pos.x > ARENA_W - 20 {pos.x = ARENA_W - 20}
				gd.node2d_set_position(cast(gd.Node2d)n, pos)
				self.move_frames += 1
				if self.move_frames == 25 && !self.moved_logged {
					self.moved_logged = true
					log(fmt.tprintf("MOVED on=%d x=%.1f", me, f64(pos.x)))
				}
			}
			// see the host's enemy (spawner replication) + its synced motion (synchronizer)
			if !self.sees_enemy {
				if e := first_enemy(self); e != nil {
					self.seen_enemy_x = gd.node2d_get_position(cast(gd.Node2d)e).x
					self.sees_enemy = true
					log(fmt.tprintf("ENEMY_SEEN on=%d id=%d", me, SCRIPT_ENEMY_ID))
				}
			} else if !self.enemy_sync {
				if e := first_enemy(self); e != nil {
					x := gd.node2d_get_position(cast(gd.Node2d)e).x
					if math.abs(x - self.seen_enemy_x) > 4 {
						self.enemy_sync = true
						log(fmt.tprintf("ENEMY_SYNC on=%d id=%d", me, SCRIPT_ENEMY_ID))
					}
				}
			}
			// despawn (enemy was seen, host freed it -> spawner replicated the despawn)
			if self.sees_enemy && !self.enemy_gone && enemy_count(self) == 0 {
				self.enemy_gone = true
				log(fmt.tprintf("ENEMY_GONE on=%d id=%d", me, SCRIPT_ENEMY_ID))
			}
		}
		if self.enemy_gone && self.leveled && !self.done {
			self.done = true
			log(fmt.tprintf("CLIENT_SUMMARY pawns=%d level=%d", pawn_count(self), self.my_level))
			log("CLIENT_DONE")
			quit_now(self, 0)
		}
	case .None:
	}
}

// single_tick — the unified game in SINGLE mode (host with no peers): move, auto-fire kills,
// XP/level, then contact death. The SAME pawn/bullet/enemy scripts as co-op; broadcasts no-op.
@(private = "file")
single_tick :: proc(self: ^ArenaGame, delta: f64) {
	host_enemy_sim(self, delta)
	switch self.single_phase {
	case 0: // move proof
		if n := pawn_node(self, 1); n != nil {
			pos := gd.node2d_get_position(cast(gd.Node2d)n)
			pos.x = clamp(pos.x + MOVE_STEP, 8, ARENA_W - 8)
			gd.node2d_set_position(cast(gd.Node2d)n, pos)
			self.move_frames += 1
			if self.move_frames >= 20 {
				log(fmt.tprintf("MOVED on=%d", gd.my_peer_id(self.owner)))
				self.single_phase = 1
			}
		}
	case 1: // auto-fire kills enemies -> XP / level
		if enemy_count(self) == 0 && self.kills < 3 {
			id := self.next_id; self.next_id += 1
			host_spawn_enemy(self, id, gd.Vector2{320, 180}, SINGLE_ENEMY_HP)
		}
		if self.kills >= 3 && self.leveled {
			self.single_phase = 2
			self.settle = 0
		}
	case 2: // contact death: disarm the pawn, drop a tough enemy on it
		if n := pawn_node(self, 1); n != nil {
			if cp := rt.script_of(n, ArenaPlayer); cp != nil {cp.armed = false}
		}
		// clear any lingering shootable enemy, then spawn the tough one on the pawn
		if enemy_count(self) == 0 {
			ppos := gd.Vector2{320, 180}
			if n := pawn_node(self, 1); n != nil {ppos = gd.node2d_get_position(cast(gd.Node2d)n)}
			host_spawn_enemy(self, 9999, ppos, SINGLE_TOUGH_HP)
			self.single_phase = 3
		}
	case 3: // wait for the contact kill
		if self.player_dead && !self.done {
			self.done = true
			log(fmt.tprintf("SINGLE_SUMMARY kills=%d level=%d", self.kills, self.my_level))
			log("SINGLE_DONE")
			quit_now(self, 0)
		}
	}
}

// ---- free play (windowed) --------------------------------------------------

@(private = "file")
free_play_tick :: proc(self: ^ArenaGame, delta: f64) {
	// Pawns self-drive (input + auto-fire) in arena_player.odin; the host just feeds the horde.
	host_enemy_sim(self, delta)
	if self.role == .Client {return}
	self.spawn_accum += f32(delta)
	if self.spawn_accum > FREE_SPAWN_INTERVAL {
		self.spawn_accum = 0
		id := self.next_id; self.next_id += 1
		ex := f32(20) + f32((id * 73) % 600)
		host_spawn_enemy(self, id, gd.Vector2{ex, 12}, COOP_ENEMY_HP)
	}
}

// ---- windowed button handlers ----------------------------------------------

// read the (optional) editable signaling URL / room-code fields from the lobby.
@(private = "file")
read_lobby_url :: proc(self: ^ArenaGame) {
	if self.url_edit != nil {
		if t := gd.get_string(self.url_edit, "text"); len(t) > 0 {self.url = t}
	}
}

@(gd_method)
arena_game_on_single :: proc(self: ^ArenaGame) {
	self.role = .Single
	if self.status != nil {gd.set_string(self.status, "text", "Single Player")}
	if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
}
// Host: keep the lobby panel up so the assigned ROOM CODE can be DISPLAYED to share; the panel is
// dropped on connect (in the Connecting->Play transition). Status is driven by lobby_web_update.
@(gd_method)
arena_game_on_host :: proc(self: ^ArenaGame) {begin_host(self)}
// Join: read the room code the friend shared (RoomEdit) + URL, then connect. Panel drops on
// connect; errors (no_room/full) surface via lobby_web_update -> lobby_reset.
@(gd_method)
arena_game_on_join :: proc(self: ^ArenaGame) {
	if self.room_edit != nil {
		if t := gd.get_string(self.room_edit, "text"); len(t) > 0 {self.room = t}
	}
	begin_join(self, "")
}

// begin_host / begin_join — the shared "start an attempt" path used by the Host/Join BUTTONS and
// by the headless lobby self-test. Disabling the buttons here (and re-enabling them in lobby_reset)
// is the "re-enable on recover" half of the retry UX.
@(private = "file")
begin_host :: proc(self: ^ArenaGame) {
	read_lobby_url(self)
	self.role = .Server
	set_lobby_buttons_enabled(self, false)
	if self.status != nil {gd.set_string(self.status, "text", "Hosting...")}
	// Native (ENet) has no room code to show — drop the panel immediately.
	when !IS_WEB {if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}}
}
@(private = "file")
begin_join :: proc(self: ^ArenaGame, room: string) {
	read_lobby_url(self)
	if room != "" {self.room = room}
	self.role = .Client
	set_lobby_buttons_enabled(self, false)
	if self.status != nil {gd.set_string(self.status, "text", "Joining...")}
	when !IS_WEB {if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}}
}

// lobby_reset — the heart of the retry fix (Bug 1). On ANY failed/aborted connect it tears the
// half-open transport down (webrtc_close fully clears the WS + WebRTC peer + session state; the
// native ENet peer is detached too) and returns to the connectable START SCREEN: role/mode back to
// the boot state, the room/code cleared, Host/Join re-shown + re-enabled, and the failure reason
// surfaced. So attempt -> fail -> attempt again works any number of times with NO page reload.
@(private = "file")
lobby_reset :: proc(self: ^ArenaGame, reason: string) {
	when IS_WEB {gd.webrtc_close(self.owner)}
	gd.multiplayer_clear_peer(self.owner)
	self.role = .None
	self.mode = .Boot
	self.room = ""
	self.room_logged = false
	self.client_id = 0
	self.alive_t = 0
	self.settle = 0
	self.reset_count += 1
	if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", true)}
	set_lobby_buttons_enabled(self, true)
	if self.code_label != nil {gd.set_string(self.code_label, "text", "")}
	if self.status != nil {
		gd.set_string(self.status, "text", fmt.ctprintf("Connection failed (%s). Pick Host or Join to try again.", reason))
	}
	log(fmt.tprintf("LOBBY_RESET reason=%s count=%d", reason, self.reset_count))
}

// ---- web clipboard paste (Bug 2) -------------------------------------------

// arena_game_on_lobby_input — gui_input handler on the URL + room-code LineEdits (web only). It
// catches Ctrl/Cmd+V on the focused field, SWALLOWS the event (so Godot's built-in paste — which
// reads the empty web DisplayServer clipboard — does NOT run), and kicks off an async read of the
// real browser clipboard via the JS bridge. Desktop/native is untouched (built-in paste works).
@(gd_method)
arena_game_on_lobby_input :: proc(self: ^ArenaGame, event: gd.Input_Event) {
	when IS_WEB {
		if event == nil {return}
		if !bool(gd.object_is_class(cast(gd.Object)event, gd.new_string_cstring("InputEventKey"))) {return}
		key := cast(gd.Input_Event_Key)event
		if !bool(gd.input_event_is_pressed(cast(gd.Input_Event)event)) {return}
		if gd.input_event_key_get_keycode(key) != .V {return}
		ctrl := bool(gd.input_event_with_modifiers_is_ctrl_pressed(cast(gd.Input_Event_With_Modifiers)key))
		meta := bool(gd.input_event_with_modifiers_is_meta_pressed(cast(gd.Input_Event_With_Modifiers)key))
		if !ctrl && !meta {return}
		target := focused_lobby_field(self)
		if target == nil {return}
		gd.control_accept_event(cast(gd.Control)target) // suppress the built-in (empty) web paste
		start_clipboard_paste(self, target)
	}
}

@(private = "file")
focused_lobby_field :: proc(self: ^ArenaGame) -> gd.Node {
	if self.room_edit != nil && bool(gd.control_has_focus(cast(gd.Control)self.room_edit, false)) {return self.room_edit}
	if self.url_edit != nil && bool(gd.control_has_focus(cast(gd.Control)self.url_edit, false)) {return self.url_edit}
	return nil
}

// start_clipboard_paste kicks off navigator.clipboard.readText() (async, returns a Promise) and
// stashes the result on a JS global; lobby_paste_poll picks it up on a later frame and inserts it.
@(private = "file")
start_clipboard_paste :: proc(self: ^ArenaGame, target: gd.Node) {
	when IS_WEB {
		js := gd.singleton_java_script_bridge()
		code := gd.new_string_cstring(
			"window.__gdClip=null;window.__gdClipDone=0;" +
			"try{navigator.clipboard.readText()" +
			".then(function(t){window.__gdClip=String(t);window.__gdClipDone=1;})" +
			".catch(function(e){window.__gdClip='';window.__gdClipDone=2;});}" +
			"catch(e){window.__gdClip='';window.__gdClipDone=2;}''")
		gd.java_script_bridge_eval(js, code, true)
		self.paste_pending = true
		self.paste_target = target
		self.paste_t = 0
	}
}

// lobby_paste_poll services an in-flight clipboard read each frame: once the Promise resolves
// (__gdClipDone==1) it inserts the text at the caret (replacing any selection) like a normal paste;
// on rejection (no permission / not a secure context) or after a short timeout it gives up cleanly.
@(private = "file")
lobby_paste_poll :: proc(self: ^ArenaGame, delta: f64) {
	when IS_WEB {
		if !self.paste_pending {return}
		self.paste_t += delta
		js := gd.singleton_java_script_bridge()
		dv := gd.java_script_bridge_eval(js, gd.new_string_cstring("String(window.__gdClipDone||0)"), true)
		done := str_to_odin(gd.variant_to_string(&dv))
		if done == "1" {
			tv := gd.java_script_bridge_eval(js, gd.new_string_cstring("(window.__gdClip==null?'':String(window.__gdClip))"), true)
			text := str_to_odin(gd.variant_to_string(&tv))
			apply_paste(self, sanitize_line(text))
			self.paste_pending = false
		} else if done == "2" || self.paste_t > 3.0 {
			log("LOBBY_PASTE_FAIL: clipboard read unavailable (permission / non-secure context?)")
			self.paste_pending = false
		}
	}
}

@(private = "file")
apply_paste :: proc(self: ^ArenaGame, text: string) {
	if self.paste_target == nil {return}
	gd.line_edit_insert_text_at_caret(cast(gd.Line_Edit)self.paste_target, gd.new_string_odin(text))
	field := self.paste_target == self.room_edit ? "room" : "url"
	log(fmt.tprintf("LOBBY_PASTE_APPLIED field=%s text=%s", field, text))
}

// sanitize_line trims at the first newline — room codes / URLs are single-line, and a trailing
// newline in the clipboard would otherwise leak into the field.
@(private = "file")
sanitize_line :: proc(s: string) -> string {
	for i in 0 ..< len(s) {if s[i] == '\n' || s[i] == '\r' {return s[:i]}}
	return s
}

// lobby_test_drive (web harness only) — headlessly exercises the REAL retry + paste code paths so
// the gated browser test can assert the mechanics. Retry: drive a Join to a NONEXISTENT room (real
// signaling no_room -> Failed -> lobby_reset), confirm recovery, then a SECOND attempt (Host) that
// reaches a room code — all with no reload. Paste: focus the room field, put text on the page
// clipboard, synthesize Ctrl+V into on_lobby_input, and assert the field receives it.
@(private = "file")
lobby_test_drive :: proc(self: ^ArenaGame, delta: f64) {
	when IS_WEB {
		self.lt_t += delta
		switch self.lobby_test {
		case .Off:
		case .Retry:
			switch self.lt_phase {
			case 0:
				begin_join(self, "ZZZZ") // a code no host ever created -> server replies no_room
				log("LOBBY_TEST_JOIN_BOGUS")
				self.lt_phase = 1; self.lt_t = 0
			case 1:
				if self.reset_count >= 1 {
					log("LOBBY_RETRY_RESET_OK")
					self.lt_phase = 2; self.lt_t = 0
				} else if self.lt_t > 30 {
					log("LOBBY_RETRY_FAIL: no reset after a failed join"); quit_now(self, 1)
				}
			case 2:
				begin_host(self) // second attempt, no page reload
				log("LOBBY_TEST_REHOST")
				self.lt_phase = 3; self.lt_t = 0
			case 3:
				if self.room_logged {
					log("LOBBY_RETRY_OK")
					quit_now(self, 0)
				} else if self.lt_t > 30 {
					log("LOBBY_RETRY_FAIL: re-host produced no room code"); quit_now(self, 1)
				}
			}
		case .Paste:
			switch self.lt_phase {
			case 0:
				if self.room_edit != nil {gd.control_grab_focus(cast(gd.Control)self.room_edit, false)}
				js := gd.singleton_java_script_bridge()
				gd.java_script_bridge_eval(js, gd.new_string_cstring(
					"window.__gdWrote=0;navigator.clipboard.writeText('WXYZ')" +
					".then(function(){window.__gdWrote=1;}).catch(function(){window.__gdWrote=2;});''"), true)
				self.lt_phase = 1; self.lt_t = 0
			case 1:
				js := gd.singleton_java_script_bridge()
				wv := gd.java_script_bridge_eval(js, gd.new_string_cstring("String(window.__gdWrote||0)"), true)
				w := str_to_odin(gd.variant_to_string(&wv))
				if w == "1" {
					ev := gd.new_input_event_key()
					gd.input_event_key_set_keycode(ev, gd.Key.V)
					gd.input_event_with_modifiers_set_ctrl_pressed(cast(gd.Input_Event_With_Modifiers)ev, true)
					gd.input_event_key_set_pressed(ev, true)
					arena_game_on_lobby_input(self, cast(gd.Input_Event)ev)
					log("LOBBY_TEST_PASTE_KEY")
					self.lt_phase = 2; self.lt_t = 0
				} else if w == "2" || self.lt_t > 10 {
					log("LOBBY_PASTE_FAIL: clipboard write blocked"); quit_now(self, 1)
				}
			case 2:
				if self.room_edit != nil {
					if t := gd.get_string(self.room_edit, "text"); t == "WXYZ" {
						log(fmt.tprintf("LOBBY_PASTE_OK field=room text=%s", t))
						quit_now(self, 0)
					} else if self.lt_t > 10 {
						log(fmt.tprintf("LOBBY_PASTE_FAIL: field text=%q", t)); quit_now(self, 1)
					}
				}
			}
		}
	}
}

// ---- peer signal handlers --------------------------------------------------

@(gd_method)
arena_game_on_peer_connected :: proc(self: ^ArenaGame, id: gd.Int) {
	log(fmt.tprintf("PEER_CONNECTED on=%d id=%d", gd.my_peer_id(self.owner), i64(id)))
	if !self.headless && self.role == .Server {
		gd.rpc(self.owner, "spawn_pawn", vi(1))
		gd.rpc(self.owner, "spawn_pawn", vi(int(id)))
	}
}
@(gd_method)
arena_game_on_peer_disconnected :: proc(self: ^ArenaGame, id: gd.Int) {
	log(fmt.tprintf("PEER_DISCONNECTED on=%d id=%d", gd.my_peer_id(self.owner), i64(id)))
}

// ---- RPCs ------------------------------------------------------------------

// spawn_pawn — host orchestrates pawn creation on every peer; authority is set per-pawn to the
// owner inside spawn_pawn_local, so each pawn is OWNER-authoritative.
@(gd_method, gd_rpc = "authority,reliable,call_local")
arena_game_spawn_pawn :: proc(self: ^ArenaGame, peer_id: gd.Int) {
	spawn_pawn_local(self, int(peer_id))
}

// fired — a peer broadcasts that it fired (the owner already spawned its own bullet locally).
// Every OTHER peer spawns a matching GHOST bullet (visual only). NOT call_local — the firer
// already has its owned bullet.
@(gd_method, gd_rpc = "any_peer,reliable")
arena_game_fired :: proc(self: ^ArenaGame, shooter: gd.Int, ox: gd.Int, oy: gd.Int, dx: gd.Int, dy: gd.Int) {
	origin := gd.Vector2{f32(ox), f32(oy)}
	dir := gd.Vector2{f32(dx) / 1000, f32(dy) / 1000}
	arena_spawn_bullet(self, int(shooter), origin, dir, 0, peer_color(int(shooter)), false)
}

// damage — PEER-authoritative shared damage. The firing peer broadcasts (call_local) the hit it
// resolved; every peer applies the SAME damage and agrees on the kill. The host (node owner)
// frees the enemy; the spawner replicates the despawn (no explicit despawn RPC -> no double-free).
@(gd_method, gd_rpc = "any_peer,reliable,call_local")
arena_game_damage :: proc(self: ^ArenaGame, eid: gd.Int, amount: gd.Int, killer: gd.Int) {
	node, e := enemy_by_id(self.owner, int(eid))
	if e == nil || e.dead {return}
	e.hp -= int(amount)
	if e.hp > 0 {return}
	e.dead = true
	me := gd.my_peer_id(self.owner)
	self.kills += 1
	log(fmt.tprintf("ENEMY_KILLED on=%d id=%d killer=%d", me, int(eid), int(killer)))
	if int(eid) == SCRIPT_ENEMY_ID {self.enemy_dead = true}
	// XP to the FIRER only.
	if self.role == .Single || int(killer) == me {grant_xp(self, XP_PER_KILL)}
	// The host owns the spawner-instantiated node -> it frees it; the spawner despawns it on peers.
	if bool(gd.is_server(self.owner)) {gd.node_queue_free(node)}
}
