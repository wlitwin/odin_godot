//gd:extends Node2D
//gd:class NetGame
package survivors_scripts

// ----------------------------------------------------------------------------
// NetGame — the unified THREE-MODE co-op survivors orchestrator (root of coop.tscn). ONE
// codebase, three modes selected at startup:
//
//   * Single — host with ZERO peers. No transport is opened; the authoritative simulation runs
//              exactly as in co-op-host, just with no client. This is the KEY UNIFICATION:
//              single-player == host-with-no-net, so the same enemy spawning / wave / death code
//              path drives both.
//   * Host   — authoritative host + a network transport (NATIVE: ENet via gd.host; WEB: WebRTC
//              via gd.webrtc_host). Owns the shared world: enemies, spawning, enemy deaths, score.
//   * Join   — a client (NATIVE ENet gd.join; WEB WebRTC gd.webrtc_join). Renders the host's
//              world; requests damage on the host; owns only its own player.
//
// REPLICATION (uses Godot's high-level replication nodes for real — proven to work with Odin
// scripts, see tests/repl_spike):
//   * MultiplayerSpawner (child "EnemySpawner", spawn_path -> Enemies) auto-instantiates each
//     host-spawned coop_enemy.tscn on every client.
//   * MultiplayerSynchronizer (in coop_player.tscn / coop_enemy.tscn, configured in the .tscn)
//     streams continuous state: each player's position+hp from its OWNING peer, each enemy's
//     position+hp+id from the host. So "both players synced" + "enemy positions synced" hold
//     via the synchronizer over BOTH ENet and WebRTC.
//   * @(gd_rpc) carries DISCRETE events: spawn_player (peer->authority mapping), the client's
//     request_damage, grant_xp / level-up, and the shared score.
//
// Transport is auto-selected by platform (compile-time IS_WEB). A headless scripted session
// (COOP_ROLE env native, or ?role= query on web) drives the deterministic test the harnesses
// assert; with no role it shows a Single/Host/Join start screen for windowed play.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import gdext "godot:gdext"
import rt "godot:runtime"
import "core:fmt"
import "core:strconv"
import "core:math"

IS_WEB :: ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32

// ARENA_W / ARENA_H are shared package constants from spawner.odin (640 x 360).
DEFAULT_PORT :: 7777
PLAYER_START_X :: f32(320)
PLAYER_START_Y :: f32(180)

SCRIPT_ENEMY_ID :: 9001
SCRIPT_ENEMY_HP :: 30
ENEMY_POINTS :: 10
XP_PER_KILL :: 6        // a single scripted kill funds a level (threshold 5)
XP_TO_LEVEL :: 5
MOVE_STEP :: f32(5)
MOVE_THRESHOLD :: f32(20)
ENEMY_SPEED :: f32(55)
// WebRTC handshakes are async + slower than localhost ENet — be generous on web.
when IS_WEB {
	CONNECT_TIMEOUT :: f64(40)
	GLOBAL_TIMEOUT :: f64(75)
} else {
	CONNECT_TIMEOUT :: f64(15)
	GLOBAL_TIMEOUT :: f64(30)
}

// free-play (windowed) tuning
FREE_SPAWN_INTERVAL :: f32(1.2)
FREE_MOVE_SPEED :: f32(180)
FREE_ENEMY_HP :: 20

Role :: enum {None, Single, Server, Client}
Mode :: enum {Boot, Connecting, Play}

NetGame :: struct {
	owner:         gd.Node2d,
	players:       gd.Node `gd:"onready=Players"`,
	enemies:       gd.Node `gd:"onready=Enemies"`,
	start_screen:  gd.Node `gd:"onready=StartScreen"`,
	status:        gd.Node `gd:"onready=StartScreen/Status"`,
	hud_score:     gd.Node `gd:"onready=Hud/Score"`,
	hud_info:      gd.Node `gd:"onready=Hud/Info"`,
	spawner:       gd.Multiplayer_Spawner,

	role:          Role,
	mode:          Mode,
	headless:      bool,
	port:          int,
	addr:          string,
	url:           string,
	room:          string,
	room_logged:   bool,
	client_id:     int,
	score:         int,
	enemy_hp:      map[int]int,
	enemy_nodes:   map[int]gd.Node,
	next_enemy_id: int,

	// per-(local-)player progression
	my_xp:         int,
	my_level:      int,
	my_damage:     f32,

	// timers
	alive_t:       f64,
	settle:        f64,
	dmg_accum:     f64,
	spawn_accum:   f32,

	// scripted bookkeeping
	players_ok:    bool,
	enemy_spawned: bool,
	enemy_dead:    bool,
	saw_move:      bool,
	sees_enemy:    bool,
	enemy_sync:    bool,
	enemy_gone:    bool,
	score_recv:    bool,
	leveled:       bool,
	moved_logged:  bool,
	move_frames:   int,
	seen_enemy_id: int,
	seen_enemy_x:  f32,
	done:          bool,
}

// ---- small helpers ---------------------------------------------------------

@(private = "file")
log :: proc(s: string) {gd.print_str(s)}
@(private = "file")
vi :: proc "contextless" (x: int) -> gd.Variant {v := i64(x); return gd.variant_from(&v)}
@(private = "file")
vf :: proc "contextless" (x: f32) -> gd.Variant {v := f64(x); return gd.variant_from(&v)}

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

// web_query reads a value from the page URL's query string (web only); "" otherwise.
@(private = "file")
web_query :: proc(key: string) -> string {
	when IS_WEB {
		js := gd.singleton_java_script_bridge()
		code := gd.new_string_cstring("location.search || ''")
		v := gd.java_script_bridge_eval(js, code, true)
		search := gd.variant_to_string(&v)
		s := str_to_odin(search)
		if len(s) > 0 && s[0] == '?' {s = s[1:]}
		// split on '&', find key=
		start := 0
		for i := 0; i <= len(s); i += 1 {
			if i == len(s) || s[i] == '&' {
				kv := s[start:i]
				eq := -1
				for j in 0 ..< len(kv) {
					if kv[j] == '=' {eq = j; break}
				}
				if eq > 0 && kv[:eq] == key {
					return uri_decode(kv[eq + 1:])
				}
				start = i + 1
			}
		}
		return ""
	} else {
		return ""
	}
}

// uri_decode does a minimal percent-decode (enough for ws:// signaling urls).
@(private = "file")
uri_decode :: proc(s: string) -> string {
	out := make([]u8, len(s), context.temp_allocator)
	n := 0
	i := 0
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
player_node :: proc(self: ^NetGame, peer_id: int) -> gd.Node {
	if self.players == nil {return nil}
	return gd.node_get_node_or_null(self.players, gd.new_node_path_cstring(fmt.ctprintf("P%d", peer_id)))
}
@(private = "file")
player_count :: proc(self: ^NetGame) -> int {
	if self.players == nil {return 0}
	return int(gd.node_get_child_count(self.players, false))
}
@(private = "file")
enemy_count :: proc(self: ^NetGame) -> int {
	if self.enemies == nil {return 0}
	return int(gd.node_get_child_count(self.enemies, false))
}
@(private = "file")
first_enemy :: proc(self: ^NetGame) -> gd.Node {
	if self.enemies == nil || enemy_count(self) == 0 {return nil}
	return gd.node_get_child(self.enemies, 0, false)
}

@(private = "file")
update_hud :: proc(self: ^NetGame) {
	if self.hud_score != nil {gd.set_string(self.hud_score, "text", fmt.ctprintf("Score: %d", self.score))}
	if self.hud_info != nil {
		gd.set_string(self.hud_info, "text", fmt.ctprintf("Lv %d   XP %d/%d   Dmg %.1f", self.my_level, self.my_xp, XP_TO_LEVEL, f64(self.my_damage)))
	}
}

@(private = "file")
maybe_players_ok :: proc(self: ^NetGame) {
	if self.players_ok {return}
	need := self.role == .Single ? 1 : 2
	if player_count(self) >= need {
		self.players_ok = true
		log(fmt.tprintf("PLAYERS_OK on=%d count=%d", gd.my_peer_id(self.owner), player_count(self)))
	}
}

// ---- lifecycle -------------------------------------------------------------

net_game_ready :: proc(self: ^NetGame) {
	self.enemy_hp = make(map[int]int)
	self.enemy_nodes = make(map[int]gd.Node)
	self.next_enemy_id = 1
	self.addr = "127.0.0.1"
	self.port = DEFAULT_PORT
	self.url = "ws://127.0.0.1:9080"
	self.mode = .Boot
	self.my_level = 1
	self.my_damage = 1

	// Build the enemy MultiplayerSpawner on every peer (the client's spawner instantiates the
	// host's coop_enemy.tscn spawns). spawn_path is the sibling Enemies node.
	sp := gd.new_multiplayer_spawner()
	gd.node_set_name(sp, gd.new_string_name_cstring("EnemySpawner", false))
	gd.add_child(self.owner, sp)
	gd.multiplayer_spawner_add_spawnable_scene(sp, gd.new_string_cstring("res://coop_enemy.tscn"))
	gd.multiplayer_spawner_set_spawn_path(sp, gd.new_node_path_cstring("../Enemies"))
	self.spawner = sp

	// Resolve the launch mode: env (native headless) or ?role= (web headless), else windowed.
	role := read_env("COOP_ROLE")
	when IS_WEB {
		if role == "" {role = web_query("role")}
	}
	// accept both the native (server/client) and web URL (host/join) naming.
	if role == "server" || role == "client" || role == "single" || role == "host" || role == "join" {
		self.headless = true
		switch role {
		case "server", "host": self.role = .Server
		case "client", "join": self.role = .Client
		case "single": self.role = .Single
		}
		if p := read_env("COOP_PORT"); p != "" {
			if v, ok := strconv.parse_int(p); ok {self.port = v}
		}
		if a := read_env("COOP_ADDR"); a != "" {self.addr = a}
		when IS_WEB {
			if u := web_query("url"); u != "" {self.url = u}
			if r := web_query("room"); r != "" {self.room = r}
		}
		if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
		log(fmt.tprintf("COOP_BOOT role=%v web=%v", self.role, IS_WEB))
	} else {
		self.headless = false
		if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", true)}
		wire_button(self, "SingleButton", "on_single")
		wire_button(self, "HostButton", "on_host")
		wire_button(self, "JoinButton", "on_join")
	}
	update_hud(self)
}

@(private = "file")
wire_button :: proc(self: ^NetGame, name: cstring, method: cstring) {
	if self.start_screen == nil {return}
	b := gd.get_node(self.start_screen, name)
	if b != nil {gd.connect_to(b, "pressed", self.owner, method)}
}

net_game_process :: proc(self: ^NetGame, delta: f64) {
	when IS_WEB {
		gd.webrtc_poll(self.owner)
		// Surface the host's assigned room CODE once (the headless driver scrapes ROOM_CODE).
		if self.role == .Server && !self.room_logged {
			if code := gd.webrtc_room_code(self.owner); len(code) > 0 {
				self.room_logged = true
				self.room = code
				log(fmt.tprintf("ROOM_CODE %s", code))
			}
		}
	}
	self.alive_t += delta

	switch self.mode {
	case .Boot:
		if self.role == .None {return}
		start_session(self)
		self.mode = .Connecting
		self.alive_t = 0

	case .Connecting:
		// Single player: no peer to wait for — go straight to play + spawn our lone avatar.
		if self.role == .Single {
			spawn_player_local(self, 1)
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
				gd.rpc(self.owner, "spawn_player", vi(1))
				gd.rpc(self.owner, "spawn_player", vi(self.client_id))
			} else {
				log(fmt.tprintf("CLIENT_SEES_SERVER REPORT my_id=%d", my))
			}
			self.mode = .Play
			self.alive_t = 0
		} else if self.alive_t > CONNECT_TIMEOUT {
			log(fmt.tprintf("%v_TIMEOUT: no peer", self.role))
			quit_now(self, 1)
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
start_session :: proc(self: ^NetGame) {
	if self.role == .Single {return} // host-with-no-net: no transport
	when IS_WEB {
		ok := self.role == .Server \
			? gd.webrtc_host(self.owner, fmt.ctprintf("%s", self.url)) \
			: gd.webrtc_join(self.owner, fmt.ctprintf("%s", self.url), fmt.ctprintf("%s", self.room))
		if ok {
			log(fmt.tprintf("WEBRTC_%v_STARTED url=%s room=%s", self.role, self.url, self.room))
		} else {
			log("TRANSPORT_FAIL")
			quit_now(self, 1)
		}
	} else {
		if self.role == .Server {
			if gd.host(self.owner, self.port) {
				gd.on_peer_connected(self.owner, "on_peer_connected")
				gd.on_peer_disconnected(self.owner, "on_peer_disconnected")
				log(fmt.tprintf("HOST_OK port=%d is_server=%v", self.port, gd.is_server(self.owner)))
			} else {
				log("HOST_FAIL")
				quit_now(self, 1)
			}
		} else {
			if gd.join(self.owner, fmt.ctprintf("%s", self.addr), self.port) {
				log(fmt.tprintf("CLIENT_STARTED addr=%s port=%d", self.addr, self.port))
			} else {
				log("CLIENT_FAIL")
				quit_now(self, 1)
			}
		}
	}
}

@(private = "file")
quit_now :: proc(self: ^NetGame, code: int) {
	tree := gd.get_tree(self.owner)
	if tree != nil {gd.scene_tree_quit(tree, gd.Int(code))}
}

// ---- scripted (headless) tick ----------------------------------------------

@(private = "file")
scripted_tick :: proc(self: ^NetGame, delta: f64) {
	switch self.role {
	case .Single:
		// Single-player smoke: spawn a few enemies, verify the loop boots + runs clean, exit.
		host_enemy_sim(self, delta)
		if self.players_ok && !self.enemy_spawned {
			self.settle += delta
			if self.settle > 0.3 {
				self.enemy_spawned = true
				host_spawn_enemy(self, SCRIPT_ENEMY_ID, gd.Vector2{100, 100})
				log("SINGLE_ENEMY_SPAWN")
			}
		}
		if self.enemy_spawned && self.alive_t > 1.5 && !self.done {
			self.done = true
			log(fmt.tprintf("SINGLE_SUMMARY players=%d enemies=%d", player_count(self), enemy_count(self)))
			log("SINGLE_DONE")
			quit_now(self, 0)
		}
	case .Server:
		host_enemy_sim(self, delta)
		if self.players_ok && !self.enemy_spawned {
			self.settle += delta
			if self.settle > 0.3 {
				self.enemy_spawned = true
				host_spawn_enemy(self, SCRIPT_ENEMY_ID, gd.Vector2{100, 100})
				log(fmt.tprintf("ENEMY_SPAWN on=%d id=%d", gd.my_peer_id(self.owner), SCRIPT_ENEMY_ID))
			}
		}
		// Observe the client's player move via the SYNCHRONIZER (read its replicated position).
		if !self.saw_move && self.client_id != 0 {
			if n := player_node(self, self.client_id); n != nil {
				x := gd.node2d_get_position(cast(gd.Node2d)n).x
				if x > PLAYER_START_X + MOVE_THRESHOLD {
					self.saw_move = true
					log(fmt.tprintf("SAW_REMOTE_MOVE on=%d peer=%d x=%.1f", gd.my_peer_id(self.owner), self.client_id, f64(x)))
				}
			}
		}
		if self.saw_move && self.enemy_dead && !self.done {
			self.done = true
			log(fmt.tprintf("SERVER_SUMMARY players=%d score=%d", player_count(self), self.score))
			log("SERVER_DONE")
			quit_now(self, 0)
		}
	case .Client:
		me := gd.my_peer_id(self.owner)
		if self.players_ok {
			// Drive our own avatar right (we hold its authority) — the synchronizer streams it.
			if n := player_node(self, me); n != nil {
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
			// See the host's enemy (spawner replication) + its synced motion (synchronizer).
			if !self.sees_enemy {
				if e := first_enemy(self); e != nil {
					ce := rt_script_enemy(e)
					self.seen_enemy_id = ce != nil ? ce.id : SCRIPT_ENEMY_ID
					self.seen_enemy_x = gd.node2d_get_position(cast(gd.Node2d)e).x
					self.sees_enemy = true
					log(fmt.tprintf("ENEMY_SEEN on=%d id=%d", me, self.seen_enemy_id))
				}
			} else if !self.enemy_sync {
				if e := first_enemy(self); e != nil {
					x := gd.node2d_get_position(cast(gd.Node2d)e).x
					if math.abs(x - self.seen_enemy_x) > 5 {
						self.enemy_sync = true
						log(fmt.tprintf("ENEMY_SYNC on=%d id=%d", me, self.seen_enemy_id))
					}
				}
			}
			// Request the host damage the enemy until it dies — but only AFTER we've observed
			// its synced motion, so the position-sync guarantee is seen before the kill.
			if self.enemy_sync && !self.enemy_gone {
				self.dmg_accum += delta
				if self.dmg_accum > 0.1 {
					self.dmg_accum = 0
					gd.rpc_id(self.owner, 1, "request_damage", vi(self.seen_enemy_id), vi(SCRIPT_ENEMY_HP))
				}
			}
			// Detect despawn (enemy was seen, now gone).
			if self.sees_enemy && !self.enemy_gone && enemy_count(self) == 0 {
				self.enemy_gone = true
				log(fmt.tprintf("ENEMY_GONE on=%d id=%d", me, self.seen_enemy_id))
			}
		}
		if self.enemy_gone && self.score_recv && self.leveled && !self.done {
			self.done = true
			log(fmt.tprintf("CLIENT_SUMMARY players=%d score=%d level=%d", player_count(self), self.score, self.my_level))
			log("CLIENT_DONE")
			quit_now(self, 0)
		}
	case .None:
	}
}

@(private = "file")
rt_script_enemy :: proc(n: gd.Node) -> ^CoopEnemy {
	return rt.script_of(cast(gd.Object)n, CoopEnemy)
}
@(private = "file")
rt_script_player :: proc(n: gd.Node) -> ^CoopPlayer {
	return rt.script_of(cast(gd.Object)n, CoopPlayer)
}

// ---- host enemy simulation -------------------------------------------------

@(private = "file")
host_spawn_enemy :: proc(self: ^NetGame, id: int, pos: gd.Vector2) {
	e := gd.instantiate(gd.load_scene("res://coop_enemy.tscn"))
	if e == nil {return}
	gd.node_set_name(e, gd.new_string_name_cstring(fmt.ctprintf("E%d", id), false))
	ce := rt_script_enemy(e)
	if ce != nil {ce.id = id; ce.hp = SCRIPT_ENEMY_HP}
	gd.node2d_set_position(cast(gd.Node2d)e, pos)
	gd.add_child(self.enemies, e)
	self.enemy_hp[id] = SCRIPT_ENEMY_HP
	self.enemy_nodes[id] = e
}

// host_enemy_sim chases each enemy toward the nearest player so its position visibly changes
// (the synchronizer streams it to clients). Server + Single only.
@(private = "file")
host_enemy_sim :: proc(self: ^NetGame, delta: f64) {
	if self.role == .Client {return}
	cnt := enemy_count(self)
	for i in 0 ..< cnt {
		e := gd.node_get_child(self.enemies, gd.Int(i), false)
		if e == nil {continue}
		epos := gd.node2d_get_position(cast(gd.Node2d)e)
		if tp, ok := nearest_player_pos(self, epos); ok {
			d := norm2(gd.Vector2{tp.x - epos.x, tp.y - epos.y})
			epos.x += d.x * ENEMY_SPEED * f32(delta)
			epos.y += d.y * ENEMY_SPEED * f32(delta)
			gd.node2d_set_position(cast(gd.Node2d)e, epos)
		}
	}
}

@(private = "file")
nearest_player_pos :: proc(self: ^NetGame, from: gd.Vector2) -> (gd.Vector2, bool) {
	cnt := player_count(self)
	best: gd.Vector2
	best_d := max(f32)
	found := false
	for i in 0 ..< cnt {
		p := gd.node_get_child(self.players, gd.Int(i), false)
		if p == nil {continue}
		pos := gd.node2d_get_position(cast(gd.Node2d)p)
		dx := pos.x - from.x; dy := pos.y - from.y
		d := dx * dx + dy * dy
		if d < best_d {best_d = d; best = pos; found = true}
	}
	return best, found
}

@(private = "file")
norm2 :: proc "contextless" (v: gd.Vector2) -> gd.Vector2 {
	l := math.sqrt(v.x * v.x + v.y * v.y)
	if l <= 0.0001 {return gd.Vector2{0, 0}}
	return gd.Vector2{v.x / l, v.y / l}
}

// ---- player spawning -------------------------------------------------------

@(private = "file")
spawn_player_local :: proc(self: ^NetGame, peer_id: int) {
	if player_node(self, peer_id) != nil {return}
	p := gd.instantiate(gd.load_scene("res://coop_player.tscn"))
	if p == nil {return}
	gd.node_set_name(p, gd.new_string_name_cstring(fmt.ctprintf("P%d", peer_id), false))
	gd.add_child(self.players, p)
	gd.node_set_multiplayer_authority(p, gd.Int(peer_id), true)
	gd.node2d_set_position(cast(gd.Node2d)p, gd.Vector2{PLAYER_START_X, PLAYER_START_Y})
	cp := rt_script_player(p)
	if cp != nil {cp.peer_id = peer_id; coop_player_recolor(cp, peer_id == 1)}
	maybe_players_ok(self)
}

// ---- free play (windowed) --------------------------------------------------

@(private = "file")
free_play_tick :: proc(self: ^NetGame, delta: f64) {
	me := gd.my_peer_id(self.owner)
	if self.role == .Single {me = 1}
	if n := player_node(self, me); n != nil {
		input := gd.singleton_input()
		dx := f32(gd.input_get_axis(input, sn("ui_left"), sn("ui_right")))
		dy := f32(gd.input_get_axis(input, sn("ui_up"), sn("ui_down")))
		pos := gd.node2d_get_position(cast(gd.Node2d)n)
		pos.x = clamp(pos.x + dx * FREE_MOVE_SPEED * f32(delta), 8, ARENA_W - 8)
		pos.y = clamp(pos.y + dy * FREE_MOVE_SPEED * f32(delta), 8, ARENA_H - 8)
		gd.node2d_set_position(cast(gd.Node2d)n, pos)
	}
	host_enemy_sim(self, delta)
	if self.role == .Client {return}
	self.spawn_accum += f32(delta)
	if self.spawn_accum > FREE_SPAWN_INTERVAL {
		self.spawn_accum = 0
		id := self.next_enemy_id; self.next_enemy_id += 1
		ex := f32(20) + f32((id * 53) % 600)
		host_spawn_enemy_hp(self, id, gd.Vector2{ex, 16}, FREE_ENEMY_HP)
	}
}

@(private = "file")
host_spawn_enemy_hp :: proc(self: ^NetGame, id: int, pos: gd.Vector2, hp: int) {
	e := gd.instantiate(gd.load_scene("res://coop_enemy.tscn"))
	if e == nil {return}
	gd.node_set_name(e, gd.new_string_name_cstring(fmt.ctprintf("E%d", id), false))
	ce := rt_script_enemy(e)
	if ce != nil {ce.id = id; ce.hp = hp}
	gd.node2d_set_position(cast(gd.Node2d)e, pos)
	gd.add_child(self.enemies, e)
	self.enemy_hp[id] = hp
	self.enemy_nodes[id] = e
}

@(private = "file")
sn :: proc "contextless" (s: cstring) -> gd.String_Name {return gd.new_string_name_cstring(s, true)}

// ---- windowed button handlers ----------------------------------------------

@(gd_method)
net_game_on_single :: proc(self: ^NetGame) {
	self.role = .Single
	if self.status != nil {gd.set_string(self.status, "text", "Single Player")}
	if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
}
@(gd_method)
net_game_on_host :: proc(self: ^NetGame) {
	self.role = .Server
	if self.status != nil {gd.set_string(self.status, "text", "Hosting...")}
	if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
}
@(gd_method)
net_game_on_join :: proc(self: ^NetGame) {
	self.role = .Client
	if self.status != nil {gd.set_string(self.status, "text", "Joining...")}
	if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
}

// ---- peer signal handlers --------------------------------------------------

@(gd_method)
net_game_on_peer_connected :: proc(self: ^NetGame, id: gd.Int) {
	log(fmt.tprintf("PEER_CONNECTED on=%d id=%d", gd.my_peer_id(self.owner), i64(id)))
	if !self.headless && self.role == .Server {
		gd.rpc(self.owner, "spawn_player", vi(1))
		gd.rpc(self.owner, "spawn_player", vi(int(id)))
	}
}
@(gd_method)
net_game_on_peer_disconnected :: proc(self: ^NetGame, id: gd.Int) {
	log(fmt.tprintf("PEER_DISCONNECTED on=%d id=%d", gd.my_peer_id(self.owner), i64(id)))
}

// ---- replication RPCs (DISCRETE events) ------------------------------------

@(gd_method, gd_rpc = "authority,reliable,call_local")
net_game_spawn_player :: proc(self: ^NetGame, peer_id: gd.Int) {
	spawn_player_local(self, int(peer_id))
}

// request_damage — a client asks the host to damage the authoritative enemy. Host-only acts.
@(gd_method, gd_rpc = "any_peer,reliable")
net_game_request_damage :: proc(self: ^NetGame, id: gd.Int, amount: gd.Int) {
	if self.role == .Client {return}
	iid := int(id)
	hp, ok := self.enemy_hp[iid]
	if !ok {return}
	hp -= int(amount)
	sender := gd.rpc_sender_id(self.owner)
	if hp <= 0 {
		delete_key(&self.enemy_hp, iid)
		if n, ok2 := self.enemy_nodes[iid]; ok2 {
			gd.node_queue_free(n)
			delete_key(&self.enemy_nodes, iid)
		}
		self.score += ENEMY_POINTS
		if iid == SCRIPT_ENEMY_ID {self.enemy_dead = true}
		log(fmt.tprintf("ENEMY_DEAD on=%d id=%d", gd.my_peer_id(self.owner), iid))
		// The MultiplayerSpawner replicates the despawn to clients when we free the node above —
		// no explicit despawn RPC (that would double-free: ERR_UNAUTHORIZED on_despawn_receive).
		gd.rpc(self.owner, "set_score", vi(self.score))
		// grant XP to the killer (the requesting peer; 0/self in single-player).
		killer := sender == 0 ? 1 : sender
		gd.rpc_id(self.owner, killer, "grant_xp", vi(XP_PER_KILL))
		grant_xp_local(self, XP_PER_KILL, killer) // host-side apply for its own kills/single
	} else {
		self.enemy_hp[iid] = hp
	}
}

@(gd_method, gd_rpc = "authority,reliable,call_local")
net_game_set_score :: proc(self: ^NetGame, value: gd.Int) {
	self.score = int(value)
	update_hud(self)
	log(fmt.tprintf("SCORE_SET on=%d value=%d", gd.my_peer_id(self.owner), int(value)))
	if self.role == .Client {self.score_recv = true}
}

// grant_xp — the host awards XP to the killer peer (targeted). The receiver banks it locally and
// levels up + applies an upgrade (a damage bump) — a working per-player progression.
@(gd_method, gd_rpc = "authority,reliable")
net_game_grant_xp :: proc(self: ^NetGame, amount: gd.Int) {
	grant_xp_local(self, int(amount), gd.my_peer_id(self.owner))
}

@(private = "file")
grant_xp_local :: proc(self: ^NetGame, amount: int, _who: int) {
	self.my_xp += amount
	for self.my_xp >= XP_TO_LEVEL {
		self.my_xp -= XP_TO_LEVEL
		self.my_level += 1
		self.my_damage += 0.5 // the "upgrade" applied on level-up (observable progression)
		self.leveled = true
		log(fmt.tprintf("LEVELUP on=%d level=%d dmg=%.1f", gd.my_peer_id(self.owner), self.my_level, f64(self.my_damage)))
	}
	update_hud(self)
}
