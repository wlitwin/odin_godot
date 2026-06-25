//gd:extends Node2D
//gd:class Spike
package repl_spike_scripts

// Spike — de-risks MultiplayerSpawner + MultiplayerSynchronizer with Odin scripts over ENet.
// Host sets up a MultiplayerSpawner (spawn_path -> World, spawnable res://mob.tscn), hosts,
// and on the client connecting INSTANTIATES mob.tscn into World (auto-replicated by the
// spawner). It then moves the mob each frame. The client never spawns the mob itself; it must
// appear via the spawner, and its position + Odin hp must arrive via the synchronizer.

import gd "godot:godot"
import gdext "godot:gdext"
import rt "godot:runtime"
import "core:fmt"
import "core:strconv"

Spike :: struct {
	owner:    gd.Node2d,
	world:    gd.Node `gd:"onready=World"`,
	spawner:  gd.Multiplayer_Spawner,
	role:     string,
	port:     int,
	mode:     int, // 0 boot, 1 connecting, 2 play
	t:        f64,
	spawned:  bool,
	saw_mob:  bool,
	first_x:  f32,
	checked:  bool,
	done:     bool,
}

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

spike_ready :: proc(self: ^Spike) {
	self.role = read_env("ROLE")
	if self.role == "" {self.role = "server"}
	self.port = 7777
	if p := read_env("PORT"); p != "" {
		if v, ok := strconv.parse_int(p); ok {self.port = v}
	}
	// Build the spawner on BOTH peers (required: the client's spawner instantiates the scene).
	sp := gd.new_multiplayer_spawner()
	gd.node_set_name(sp, gd.new_string_name_cstring("Spawner", false))
	gd.add_child(self.owner, sp)
	gd.multiplayer_spawner_add_spawnable_scene(sp, gd.new_string_cstring("res://mob.tscn"))
	gd.multiplayer_spawner_set_spawn_path(sp, gd.new_node_path_cstring("../World"))
	self.spawner = sp
	gd.print_str(fmt.tprintf("SPIKE_BOOT role=%s port=%d", self.role, self.port))
}

spike_process :: proc(self: ^Spike, delta: f64) {
	self.t += delta
	switch self.mode {
	case 0:
		if self.role == "server" {
			if gd.host(self.owner, self.port) {
				gd.print_str("HOST_OK")
			} else {
				gd.print_str("HOST_FAIL")
				quit(self, 1)
			}
		} else {
			gd.join(self.owner, "127.0.0.1", self.port)
		}
		self.mode = 1
		self.t = 0
	case 1:
		my := gd.my_peer_id(self.owner)
		peers := gd.connected_peers(self.owner)
		if my != 0 && len(peers) >= 1 {
			self.mode = 2
			self.t = 0
			gd.print_str(fmt.tprintf("CONNECTED role=%s my_id=%d", self.role, my))
		} else if self.t > 15 {
			gd.print_str("TIMEOUT_CONNECT")
			quit(self, 1)
		}
	case 2:
		if self.role == "server" {
			server_tick(self)
		} else {
			client_tick(self)
		}
		if self.t > 20 && !self.done {
			gd.print_str("TIMEOUT_PLAY")
			quit(self, 1)
		}
	}
}

@(private = "file")
mob_node :: proc(self: ^Spike) -> gd.Node {
	if self.world == nil {return nil}
	if gd.node_get_child_count(self.world, false) == 0 {return nil}
	return gd.node_get_child(self.world, 0, false)
}

@(private = "file")
server_tick :: proc(self: ^Spike) {
	if !self.spawned {
		// Instantiate mob.tscn and add to World — the spawner auto-replicates this.
		mob := gd.instantiate(gd.load_scene("res://mob.tscn"))
		if mob == nil {gd.print_str("SPAWN_FAIL"); quit(self, 1); return}
		ms := rt.script_of(mob, Mob)
		if ms != nil {ms.hp = 42}
		gd.node2d_set_position(cast(gd.Node2d)mob, gd.Vector2{100, 100})
		gd.add_child(self.world, mob)
		self.spawned = true
		gd.print_str("SPIKE_HOST_SPAWNED hp=42")
	} else {
		if n := mob_node(self); n != nil {
			ms := rt.script_of(n, Mob)
			if ms != nil {mob_advance(ms, f32(120) * f32(0.016))}
		}
		if self.t > 4 && !self.done {
			self.done = true
			gd.print_str("SERVER_DONE")
			quit(self, 0)
		}
	}
}

@(private = "file")
client_tick :: proc(self: ^Spike) {
	n := mob_node(self)
	if n == nil {return}
	ms := rt.script_of(n, Mob)
	if ms == nil {return}
	if !self.saw_mob {
		self.saw_mob = true
		self.first_x = mob_x(ms)
		gd.print_str(fmt.tprintf("SPIKE_CLIENT_SAW_MOB hp=%d x=%.1f", ms.hp, f64(self.first_x)))
	}
	if self.saw_mob && !self.checked && self.t > 3 {
		self.checked = true
		x := mob_x(ms)
		moved := x > self.first_x + 5
		hp_ok := ms.hp == 42
		gd.print_str(fmt.tprintf("SPIKE_CLIENT_CHECK hp=%d x=%.1f moved=%v hp_ok=%v", ms.hp, f64(x), moved, hp_ok))
		if moved && hp_ok {gd.print_str("SPIKE_SYNC_OK")}
		self.done = true
		gd.print_str("CLIENT_DONE")
		quit(self, 0)
	}
}

@(private = "file")
quit :: proc(self: ^Spike, code: int) {
	tree := gd.get_tree(self.owner)
	if tree != nil {gd.scene_tree_quit(tree, gd.Int(code))}
}
