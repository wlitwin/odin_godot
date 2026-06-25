//gd:extends Node2D
//gd:class CoopGame
package coop_scripts

// ----------------------------------------------------------------------------
// CoopGame — the root orchestrator of the 2-player co-op survivors example. The SAME script
// runs on both peers (server + client); it hosts/joins an ENet session, replicates players and
// (server-authoritative) enemies, and proves the networked loop end-to-end.
//
// REPLICATION APPROACH: explicit `@(gd_rpc)` sync (NOT MultiplayerSpawner/Synchronizer). The
// high-level replication nodes have never been exercised with Odin scripts and proved unusable
// for a RELIABLE headless test (see examples/coop_survivors/README.md); explicit RPC mirrors
// the proven tests/rpc_net path and gives the same six guarantees deterministically. Players
// and enemies are plain Node2D + Polygon2D visuals the orchestrator moves directly (so there
// is no per-node script and no monitoring-Area2D-during-physics-flush hazard).
//
// AUTHORITY MODEL (server-authoritative):
//   * The SERVER owns enemies + shared score. It spawns enemies, simulates them, applies damage,
//     and broadcasts spawn/despawn/score to the client (authority,call_local RPCs).
//   * Each PLAYER is driven by its owning peer; that peer broadcasts its position (any_peer RPC)
//     and the other peer mirrors it. Both players exist on both peers.
//   * A client's hit is a request_damage RPC to the server (any_peer); the server applies it to
//     the authoritative enemy and replicates the death.
//
// MODES:
//   * Headless test  — COOP_ROLE=server|client (+ COOP_PORT/COOP_ADDR) in the environment drives
//     a deterministic scripted session that prints the sentinels examples/coop_survivors/run.sh
//     asserts across both processes.
//   * Windowed       — no COOP_ROLE: a minimal Host/Join start screen; pressing a button starts
//     free play (input-driven movement, server auto-spawns a swarm, players auto-fire).
// ----------------------------------------------------------------------------

import gd "godot:godot"
import gdext "godot:gdext"
import "core:fmt"
import "core:strconv"
import "core:math"
import "core:math/rand"

ARENA_W :: f32(640)
ARENA_H :: f32(360)
DEFAULT_PORT :: 7777

PLAYER_START_X :: f32(320)
PLAYER_START_Y :: f32(180)

// Scripted-test constants.
SCRIPT_ENEMY_ID :: 9001
SCRIPT_ENEMY_HP :: 30
ENEMY_POINTS :: 10
MOVE_STEP :: f32(5) // px/frame the scripted client slides its own player right
MOVE_THRESHOLD :: f32(20) // server flags a remote move once the client's x advances this far
CONNECT_TIMEOUT :: f64(15) // s to establish the peer connection
GLOBAL_TIMEOUT :: f64(30) // s hard cap on the whole scripted session

// Free-play constants.
FREE_ENEMY_HP :: 20
FREE_SPAWN_INTERVAL :: f32(1.2)
FREE_FIRE_INTERVAL :: f32(0.4)
FREE_FIRE_RANGE :: f32(140)
FREE_MOVE_SPEED :: f32(180)
ENEMY_SPEED :: f32(55)

Role :: enum {
	None,
	Server,
	Client,
}

Mode :: enum {
	Boot, // waiting to host/join (windowed: until a button is pressed)
	Connecting, // peer assigned; waiting for the other peer
	Play, // connected; scripted test or free play
}

CoopGame :: struct {
	owner:        gd.Node2d,
	players:      gd.Node `gd:"onready=Players"`,
	enemies:      gd.Node `gd:"onready=Enemies"`,
	start_screen: gd.Node `gd:"onready=StartScreen"`,
	addr_edit:    gd.Node `gd:"onready=StartScreen/AddrEdit"`,
	port_edit:    gd.Node `gd:"onready=StartScreen/PortEdit"`,
	status:       gd.Node `gd:"onready=StartScreen/Status"`,
	hud_score:    gd.Node `gd:"onready=Hud/Score"`,

	// ---- session ----
	role:         Role,
	mode:         Mode,
	headless:     bool,
	port:         int,
	addr:         string,
	client_id:    int, // server: connected client's id
	score:        int,
	enemy_hp:     map[int]int, // server-only: live enemy id -> hp
	next_enemy_id: int,

	// ---- timers ----
	alive_t:      f64,
	settle:       f64,
	dmg_accum:    f64,
	spawn_accum:  f32,
	fire_accum:   f32,

	// ---- scripted-test bookkeeping ----
	players_ok:     bool,
	enemy_spawned:  bool,
	enemy_dead:     bool, // server: the scripted enemy was killed
	saw_move:       bool, // server: observed the client's player move
	sees_enemy:     bool, // client: the scripted enemy appeared
	enemy_gone:     bool, // client: the scripted enemy despawned
	score_received: bool, // client: got the server's score broadcast
	moved_logged:   bool,
	move_frames:    int,
	done:           bool,
}

// ---- small helpers ---------------------------------------------------------

@(private = "file")
log :: proc(s: string) {gd.print_str(s)}

@(private = "file")
vi :: proc "contextless" (x: int) -> gd.Variant {v := i64(x); return gd.variant_from(&v)}
@(private = "file")
vf :: proc "contextless" (x: f32) -> gd.Variant {v := f64(x); return gd.variant_from(&v)}

// read_env reads an environment variable via Godot's OS singleton (platform-independent in the
// binding, so it compiles on wasm too). Returns "" when unset.
@(private = "file")
read_env :: proc(key: cstring) -> string {
	os := gd.singleton_os()
	k := gd.new_string_cstring(key)
	if !bool(gd.os_has_environment(os, k)) {return ""}
	s := gd.os_get_environment(os, k)
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, nil, 0)
	if n <= 0 {return ""}
	buf := make([]u8, n, context.temp_allocator)
	gdext.string_to_utf8_chars(cast(gdext.StringPtr)&s, cast(cstring)raw_data(buf), n)
	return string(buf)
}

// poly builds a Polygon2D child with the given points + color and returns it.
@(private = "file")
make_poly :: proc(points: []gd.Vector2, color: gd.Color) -> gd.Polygon2d {
	body := gd.new_polygon2d()
	arr := gd.new_packed_vector2_array()
	for p in points {
		pp := p
		gd.packed_vector2_array_push_back(&arr, pp)
	}
	gd.polygon2d_set_polygon(body, arr)
	gd.polygon2d_set_color(body, color)
	return body
}

@(private = "file")
make_player :: proc(peer_id: int) -> gd.Node2d {
	n := gd.new_node2d()
	name := gd.new_string_name_cstring(fmt.ctprintf("P%d", peer_id), false)
	gd.node_set_name(n, name)
	color := gd.Color{0.35, 0.65, 1, 1} // host / peer 1 = blue
	if peer_id != 1 {color = gd.Color{1, 0.62, 0.2, 1}} // client = orange
	pts := []gd.Vector2{{0, -14}, {13, 11}, {-13, 11}}
	gd.add_child(n, make_poly(pts, color))
	gd.node2d_set_position(n, gd.Vector2{PLAYER_START_X, PLAYER_START_Y})
	return n
}

@(private = "file")
make_enemy :: proc(id: int) -> gd.Node2d {
	n := gd.new_node2d()
	name := gd.new_string_name_cstring(fmt.ctprintf("E%d", id), false)
	gd.node_set_name(n, name)
	pts := []gd.Vector2{{0, -13}, {12, -4}, {8, 12}, {-8, 12}, {-12, -4}}
	gd.add_child(n, make_poly(pts, gd.Color{0.9, 0.22, 0.22, 1}))
	return n
}

@(private = "file")
player_node :: proc(self: ^CoopGame, peer_id: int) -> gd.Node {
	if self.players == nil {return nil}
	return gd.node_get_node_or_null(self.players, gd.new_node_path_cstring(fmt.ctprintf("P%d", peer_id)))
}

@(private = "file")
enemy_node :: proc(self: ^CoopGame, id: int) -> gd.Node {
	if self.enemies == nil {return nil}
	return gd.node_get_node_or_null(self.enemies, gd.new_node_path_cstring(fmt.ctprintf("E%d", id)))
}

@(private = "file")
player_count :: proc(self: ^CoopGame) -> int {
	if self.players == nil {return 0}
	return int(gd.node_get_child_count(self.players, false))
}

@(private = "file")
maybe_players_ok :: proc(self: ^CoopGame) {
	if self.players_ok {return}
	if player_count(self) >= 2 {
		self.players_ok = true
		log(fmt.tprintf("PLAYERS_OK on=%d count=%d", gd.my_peer_id(self.owner), player_count(self)))
	}
}

@(private = "file")
update_hud :: proc(self: ^CoopGame) {
	if self.hud_score == nil {return}
	gd.set_string(self.hud_score, "text", fmt.ctprintf("Score: %d", self.score))
}

// ---- lifecycle -------------------------------------------------------------

coop_game_ready :: proc(self: ^CoopGame) {
	self.enemy_hp = make(map[int]int)
	self.next_enemy_id = 1
	self.addr = "127.0.0.1"
	self.port = DEFAULT_PORT
	self.mode = .Boot

	role := read_env("COOP_ROLE")
	if role == "server" || role == "client" {
		self.headless = true
		self.role = role == "server" ? .Server : .Client
		if p := read_env("COOP_PORT"); p != "" {
			if v, ok := strconv.parse_int(p); ok {self.port = v}
		}
		if a := read_env("COOP_ADDR"); a != "" {self.addr = a}
		if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
		log(fmt.tprintf("COOP_BOOT role=%v port=%d", self.role, self.port))
	} else {
		// Windowed: show the start screen and wire the Host/Join buttons.
		self.headless = false
		if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", true)}
		host_btn := gd.get_node(self.start_screen, "HostButton")
		join_btn := gd.get_node(self.start_screen, "JoinButton")
		if host_btn != nil {gd.connect_to(host_btn, "pressed", self.owner, "on_host")}
		if join_btn != nil {gd.connect_to(join_btn, "pressed", self.owner, "on_join")}
	}
	update_hud(self)
}

coop_game_process :: proc(self: ^CoopGame, delta: f64) {
	self.alive_t += delta

	switch self.mode {
	case .Boot:
		if self.role == .None {return} // windowed: waiting on a button
		start_session(self)
		self.mode = .Connecting
		self.alive_t = 0

	case .Connecting:
		my := gd.my_peer_id(self.owner)
		peers := gd.connected_peers(self.owner)
		if my != 0 && len(peers) >= 1 {
			if self.role == .Server {
				self.client_id = peers[0]
				log(fmt.tprintf("SERVER_SEES_CLIENT id=%d", self.client_id))
				// Spawn BOTH players on BOTH peers (authority,call_local broadcast).
				gd.rpc(self.owner, "spawn_player", vi(1))
				gd.rpc(self.owner, "spawn_player", vi(self.client_id))
			} else {
				log(fmt.tprintf("CLIENT_SEES_SERVER REPORT my_id=%d", my))
			}
			self.mode = .Play
			self.settle = 0
		} else if self.alive_t > CONNECT_TIMEOUT {
			log(fmt.tprintf("%v_TIMEOUT: no peer", self.role))
			quit_now(self, 1)
		}

	case .Play:
		maybe_players_ok(self)
		if self.headless {
			if self.role == .Server {
				server_scripted_tick(self, delta)
			} else {
				client_scripted_tick(self, delta)
			}
			if self.alive_t > GLOBAL_TIMEOUT && !self.done {
				log(fmt.tprintf("%v_TIMEOUT: scripted loop did not complete", self.role))
				quit_now(self, 1)
			}
		} else {
			free_play_tick(self, delta)
		}
	}
}

// start_session hosts or joins per role.
@(private = "file")
start_session :: proc(self: ^CoopGame) {
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
		caddr := fmt.ctprintf("%s", self.addr)
		if gd.join(self.owner, caddr, self.port) {
			log(fmt.tprintf("CLIENT_STARTED addr=%s port=%d", self.addr, self.port))
		} else {
			log("CLIENT_FAIL")
			quit_now(self, 1)
		}
	}
}

@(private = "file")
quit_now :: proc(self: ^CoopGame, code: int) {
	tree := gd.get_tree(self.owner)
	if tree != nil {gd.scene_tree_quit(tree, gd.Int(code))}
}

// ---- scripted (headless) ticks --------------------------------------------

@(private = "file")
server_scripted_tick :: proc(self: ^CoopGame, delta: f64) {
	// Spawn the scripted enemy a beat after both players exist.
	if self.players_ok && !self.enemy_spawned {
		self.settle += delta
		if self.settle > 0.3 {
			self.enemy_spawned = true
			self.enemy_hp[SCRIPT_ENEMY_ID] = SCRIPT_ENEMY_HP
			gd.rpc(self.owner, "spawn_enemy", vi(SCRIPT_ENEMY_ID), vf(100), vf(100))
			log(fmt.tprintf("ENEMY_SPAWN on=%d id=%d", gd.my_peer_id(self.owner), SCRIPT_ENEMY_ID))
		}
	}
	// Done once we've observed the client move AND the authoritative enemy died.
	if self.saw_move && self.enemy_dead && !self.done {
		self.done = true
		log(fmt.tprintf("SERVER_SUMMARY players=%d score=%d", player_count(self), self.score))
		log("SERVER_DONE")
		// settle a frame for the score broadcast to flush before quitting.
		quit_now(self, 0)
	}
}

@(private = "file")
client_scripted_tick :: proc(self: ^CoopGame, delta: f64) {
	if self.players_ok {
		me := gd.my_peer_id(self.owner)
		if n := player_node(self, me); n != nil {
			pos := gd.node2d_get_position(cast(gd.Node2d)n)
			pos.x += MOVE_STEP
			if pos.x > ARENA_W - 20 {pos.x = ARENA_W - 20}
			gd.node2d_set_position(cast(gd.Node2d)n, pos)
			gd.rpc(self.owner, "sync_player_pos", vi(me), vf(pos.x), vf(pos.y))
			self.move_frames += 1
			if self.move_frames == 25 && !self.moved_logged {
				self.moved_logged = true
				log(fmt.tprintf("MOVED on=%d x=%.1f", me, f64(pos.x)))
			}
		}
		// Request damage on the enemy once it has appeared (throttled; the first hit kills it).
		if self.sees_enemy && !self.enemy_gone {
			self.dmg_accum += delta
			if self.dmg_accum > 0.1 {
				self.dmg_accum = 0
				gd.rpc_id(self.owner, 1, "request_damage", vi(SCRIPT_ENEMY_ID), vi(SCRIPT_ENEMY_HP))
			}
		}
	}
	if self.enemy_gone && self.score_received && !self.done {
		self.done = true
		log(fmt.tprintf("CLIENT_SUMMARY players=%d score=%d", player_count(self), self.score))
		log("CLIENT_DONE")
		quit_now(self, 0)
	}
}

// ---- free play (windowed) --------------------------------------------------

@(private = "file")
free_play_tick :: proc(self: ^CoopGame, delta: f64) {
	// Move my own player from input and broadcast its position.
	me := gd.my_peer_id(self.owner)
	if n := player_node(self, me); n != nil {
		input := gd.singleton_input()
		dx := f32(gd.input_get_axis(input, sn("ui_left"), sn("ui_right")))
		dy := f32(gd.input_get_axis(input, sn("ui_up"), sn("ui_down")))
		pos := gd.node2d_get_position(cast(gd.Node2d)n)
		pos.x += dx * FREE_MOVE_SPEED * f32(delta)
		pos.y += dy * FREE_MOVE_SPEED * f32(delta)
		pos.x = clamp(pos.x, 8, ARENA_W - 8)
		pos.y = clamp(pos.y, 8, ARENA_H - 8)
		gd.node2d_set_position(cast(gd.Node2d)n, pos)
		gd.rpc(self.owner, "sync_player_pos", vi(me), vf(pos.x), vf(pos.y))

		// Auto-fire: ask the server to damage the nearest enemy in range.
		self.fire_accum += f32(delta)
		if self.fire_accum > FREE_FIRE_INTERVAL {
			self.fire_accum = 0
			if id, ok := nearest_enemy_id(self, pos, FREE_FIRE_RANGE); ok {
				gd.rpc_id(self.owner, 1, "request_damage", vi(id), vi(8))
			}
		}
	}

	if self.role != .Server {return}

	// Server: spawn a swarm and chase the nearest player.
	self.spawn_accum += f32(delta)
	if self.spawn_accum > FREE_SPAWN_INTERVAL {
		self.spawn_accum = 0
		id := self.next_enemy_id
		self.next_enemy_id += 1
		self.enemy_hp[id] = FREE_ENEMY_HP
		ex := rand.float32_range(20, ARENA_W - 20)
		gd.rpc(self.owner, "spawn_enemy", vi(id), vf(ex), vf(16))
	}
	// Chase + broadcast positions.
	cnt := int(gd.node_get_child_count(self.enemies, false))
	for i in 0 ..< cnt {
		e := gd.node_get_child(self.enemies, gd.Int(i), false)
		if e == nil {continue}
		epos := gd.node2d_get_position(cast(gd.Node2d)e)
		if tp, ok := nearest_player_pos(self, epos); ok {
			d := normalize2(gd.Vector2{tp.x - epos.x, tp.y - epos.y})
			epos.x += d.x * ENEMY_SPEED * f32(delta)
			epos.y += d.y * ENEMY_SPEED * f32(delta)
			gd.node2d_set_position(cast(gd.Node2d)e, epos)
		}
		nm := id_from_name(self, e)
		if nm >= 0 {gd.rpc(self.owner, "sync_enemy_pos", vi(nm), vf(epos.x), vf(epos.y))}
	}
}

@(private = "file")
sn :: proc "contextless" (s: cstring) -> gd.String_Name {return gd.new_string_name_cstring(s, true)}

@(private = "file")
normalize2 :: proc "contextless" (v: gd.Vector2) -> gd.Vector2 {
	l := math.sqrt(v.x * v.x + v.y * v.y)
	if l <= 0.0001 {return gd.Vector2{0, 0}}
	return gd.Vector2{v.x / l, v.y / l}
}

@(private = "file")
id_from_name :: proc(self: ^CoopGame, n: gd.Node) -> int {
	name := gd.get_string(n, "name")
	if len(name) < 2 || name[0] != 'E' {return -1}
	if v, ok := strconv.parse_int(name[1:]); ok {return v}
	return -1
}

@(private = "file")
nearest_player_pos :: proc(self: ^CoopGame, from: gd.Vector2) -> (gd.Vector2, bool) {
	cnt := player_count(self)
	best: gd.Vector2
	best_d := max(f32)
	found := false
	for i in 0 ..< cnt {
		p := gd.node_get_child(self.players, gd.Int(i), false)
		if p == nil {continue}
		pos := gd.node2d_get_position(cast(gd.Node2d)p)
		dx := pos.x - from.x
		dy := pos.y - from.y
		d := dx * dx + dy * dy
		if d < best_d {best_d = d; best = pos; found = true}
	}
	return best, found
}

@(private = "file")
nearest_enemy_id :: proc(self: ^CoopGame, from: gd.Vector2, range: f32) -> (int, bool) {
	cnt := int(gd.node_get_child_count(self.enemies, false))
	best_id := -1
	best_d := range * range
	for i in 0 ..< cnt {
		e := gd.node_get_child(self.enemies, gd.Int(i), false)
		if e == nil {continue}
		pos := gd.node2d_get_position(cast(gd.Node2d)e)
		dx := pos.x - from.x
		dy := pos.y - from.y
		d := dx * dx + dy * dy
		if d < best_d {
			id := id_from_name(self, e)
			if id >= 0 {best_d = d; best_id = id}
		}
	}
	return best_id, best_id >= 0
}

// ---- windowed button handlers ----------------------------------------------

@(gd_method)
coop_game_on_host :: proc(self: ^CoopGame) {
	self.role = .Server
	read_addr_port(self)
	if self.status != nil {gd.set_string(self.status, "text", "Hosting…")}
	if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
}

@(gd_method)
coop_game_on_join :: proc(self: ^CoopGame) {
	self.role = .Client
	read_addr_port(self)
	if self.status != nil {gd.set_string(self.status, "text", "Joining…")}
	if self.start_screen != nil {gd.set_bool(self.start_screen, "visible", false)}
}

@(private = "file")
read_addr_port :: proc(self: ^CoopGame) {
	if self.addr_edit != nil {
		t := gd.get_string(self.addr_edit, "text")
		if len(t) > 0 {self.addr = t}
	}
	if self.port_edit != nil {
		t := gd.get_string(self.port_edit, "text")
		if v, ok := strconv.parse_int(t); ok && v > 0 {self.port = v}
	}
}

// ---- peer signal handlers --------------------------------------------------

@(gd_method)
coop_game_on_peer_connected :: proc(self: ^CoopGame, id: gd.Int) {
	log(fmt.tprintf("PEER_CONNECTED on=%d id=%d", gd.my_peer_id(self.owner), i64(id)))
	// Windowed free play: when a client joins, the server spawns both avatars.
	if !self.headless && self.role == .Server {
		gd.rpc(self.owner, "spawn_player", vi(1))
		gd.rpc(self.owner, "spawn_player", vi(int(id)))
	}
}

@(gd_method)
coop_game_on_peer_disconnected :: proc(self: ^CoopGame, id: gd.Int) {
	log(fmt.tprintf("PEER_DISCONNECTED on=%d id=%d", gd.my_peer_id(self.owner), i64(id)))
}

// ---- replication RPCs ------------------------------------------------------

// spawn_player creates player <peer_id> on every peer (authority broadcasts it, call_local so
// the server makes it locally too).
@(gd_method, gd_rpc = "authority,reliable,call_local")
coop_game_spawn_player :: proc(self: ^CoopGame, peer_id: gd.Int) {
	pid := int(peer_id)
	if player_node(self, pid) != nil {return}
	n := make_player(pid)
	gd.add_child(self.players, n)
	gd.node_set_multiplayer_authority(n, gd.Int(pid), true)
	maybe_players_ok(self)
}

// sync_player_pos mirrors a player's position to the other peer (its owner broadcasts it).
@(gd_method, gd_rpc = "any_peer,unreliable")
coop_game_sync_player_pos :: proc(self: ^CoopGame, peer_id: gd.Int, x: f64, y: f64) {
	pid := int(peer_id)
	if pid == gd.my_peer_id(self.owner) {return} // never fight our own authority
	n := player_node(self, pid)
	if n == nil {return}
	gd.node2d_set_position(cast(gd.Node2d)n, gd.Vector2{f32(x), f32(y)})
	// Server observes the client's player moving (position replication proven).
	if self.role == .Server && pid == self.client_id && !self.saw_move {
		if f32(x) > PLAYER_START_X + MOVE_THRESHOLD {
			self.saw_move = true
			log(fmt.tprintf("SAW_REMOTE_MOVE on=%d peer=%d x=%.1f", gd.my_peer_id(self.owner), pid, x))
		}
	}
}

// spawn_enemy creates enemy <id> on every peer (server authority broadcasts, call_local).
@(gd_method, gd_rpc = "authority,reliable,call_local")
coop_game_spawn_enemy :: proc(self: ^CoopGame, id: gd.Int, x: f64, y: f64) {
	iid := int(id)
	if enemy_node(self, iid) != nil {return}
	n := make_enemy(iid)
	gd.node2d_set_position(n, gd.Vector2{f32(x), f32(y)})
	gd.add_child(self.enemies, n)
	if self.role == .Client {
		self.sees_enemy = true
		log(fmt.tprintf("ENEMY_SEEN on=%d id=%d", gd.my_peer_id(self.owner), iid))
	}
}

// sync_enemy_pos mirrors a server-owned enemy's position to the client.
@(gd_method, gd_rpc = "authority,unreliable")
coop_game_sync_enemy_pos :: proc(self: ^CoopGame, id: gd.Int, x: f64, y: f64) {
	n := enemy_node(self, int(id))
	if n == nil {return}
	gd.node2d_set_position(cast(gd.Node2d)n, gd.Vector2{f32(x), f32(y)})
}

// request_damage — a client asks the SERVER to damage an enemy (any_peer so the non-authority
// client may call it). Only the server acts: it mutates the authoritative enemy and, on death,
// banks score + replicates the despawn and the new shared score.
@(gd_method, gd_rpc = "any_peer,reliable")
coop_game_request_damage :: proc(self: ^CoopGame, id: gd.Int, amount: gd.Int) {
	if self.role != .Server {return}
	iid := int(id)
	hp, ok := self.enemy_hp[iid]
	if !ok {return}
	hp -= int(amount)
	if hp <= 0 {
		delete_key(&self.enemy_hp, iid)
		self.score += ENEMY_POINTS
		if iid == SCRIPT_ENEMY_ID {self.enemy_dead = true}
		log(fmt.tprintf("ENEMY_DEAD on=%d id=%d", gd.my_peer_id(self.owner), iid))
		gd.rpc(self.owner, "despawn_enemy", vi(iid))
		gd.rpc(self.owner, "set_score", vi(self.score))
	} else {
		self.enemy_hp[iid] = hp
	}
}

// despawn_enemy removes enemy <id> on every peer (server authority broadcasts, call_local).
@(gd_method, gd_rpc = "authority,reliable,call_local")
coop_game_despawn_enemy :: proc(self: ^CoopGame, id: gd.Int) {
	iid := int(id)
	if n := enemy_node(self, iid); n != nil {gd.node_queue_free(n)}
	log(fmt.tprintf("ENEMY_GONE on=%d id=%d", gd.my_peer_id(self.owner), iid))
	if self.role == .Client {self.enemy_gone = true}
}

// set_score replicates the server-authoritative shared score to every peer (call_local).
@(gd_method, gd_rpc = "authority,reliable,call_local")
coop_game_set_score :: proc(self: ^CoopGame, value: gd.Int) {
	self.score = int(value)
	update_hud(self)
	log(fmt.tprintf("SCORE_SET on=%d value=%d", gd.my_peer_id(self.owner), int(value)))
	if self.role == .Client {self.score_received = true}
}
