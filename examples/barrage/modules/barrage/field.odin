//gd:extends Node2D
//gd:class BulletField
package barrage_bullets

// ----------------------------------------------------------------------------
// BulletField — the data-oriented heart of the example, and its own script MODULE
// (res://modules/barrage -> libodinscripts_barrage): thousands of live bullets with
// ZERO nodes, zero physics bodies, zero per-bullet engine objects.
//
//   * STORAGE: a fixed-capacity Odin `#soa` pool. `bullets[i].pos` etc. reads like an
//     array of structs, but the fields are laid out as parallel arrays — the integrate
//     loop walks contiguous memory (this is Odin's #soa doing cache-friendly layout for
//     free; no handles, no allocation after _ready).
//   * SIMULATION: one tight loop in _physics_process — integrate, expire, swap-remove.
//     Collision is plain circle math against the player and registered enemies; the
//     physics engine never hears about bullets.
//   * RENDERING: one MultiMesh drawn by this node's canvas item. Each frame the live
//     SOA state is flattened into a Packed_Float32_Array (written DIRECTLY through the
//     packed array's data pointer — no per-element calls) and handed to the
//     RenderingServer with a single multimesh_set_buffer. One draw call for everything.
//   * ISOLATION: other modules (player, enemies, boss) may not import this package —
//     they find this node by group and call the @(gd_method) emitters through the
//     engine (`object_call`), and listen to its typed signal fields. That boundary is
//     the script-modules contract (docs/modules.md).
// ----------------------------------------------------------------------------

import "core:math"
import gd "godot:godot"

// Pool capacity. 16k comfortably covers the boss's densest pattern; the HUD shows the
// live count so you can watch it. Raising this costs only memory (count*sizeof(Bullet)).
MAX_BULLETS :: 16384

// 2D multimesh instance stride in floats: transform2d as two rows of 4 + RGBA color.
INSTANCE_FLOATS :: 12

Bullet :: struct {
	pos:    [2]f32,
	vel:    [2]f32,
	radius: f32,
	ttl:    f32, // seconds left; expired bullets are swap-removed
	hue:    gd.Color,
	hostile: bool, // true = hurts the player; false = player's, hurts enemies
	damage: i32,
}

BulletField :: struct {
	owner: gd.Node2d,

	// ---- typed signal fields (the cross-module OUTPUT — enemies/player listen) ----
	player_hit: gd.Signal1(int) `gd:"args=damage"`, // a hostile bullet reached the player
	// SignalN carries a struct payload: which enemy instance, how hard (docs: signals).
	enemy_hit:  gd.SignalN(struct {
		enemy_id: int,
		damage:   int,
	}), // SignalN: the FIELD NAMES are the arg names (no args= tag)

	// ---- Inspector tunables ----
	bullet_scale: f32 `gd:"export,range=2:16:1"`, // quad size in px
	bounds_pad:   f32 `gd:"export,range=0:400:10"`, // how far offscreen bullets survive

	// ---- runtime (untagged -> private) ----
	count:      int,
	bullets:    #soa[MAX_BULLETS]Bullet,
	multimesh:  gd.Rid,
	quad:       gd.Quad_Mesh, // kept referenced so its RID stays alive
	buffer:     gd.Packed_Float32_Array, // reused every frame
	player:     gd.Object, // resolved lazily from the "player" group
	player_radius: f32,
	// enemies register/unregister themselves (by engine call) for player-bullet hits
	enemy_ids:  [256]int,
	enemy_pos:  [256][2]f32,
	enemy_radius: [256]f32,
	enemy_count: int,
}

bullet_field_ready :: proc(self: ^BulletField) {
	if self.bullet_scale == 0 {self.bullet_scale = 6}
	if self.bounds_pad == 0 {self.bounds_pad = 64}

	// One quad mesh + one multimesh, allocated once for the pool's capacity; the
	// per-frame instance COUNT is set with multimesh_set_visible_instances.
	rs := gd.singleton_rendering_server()
	self.quad = gd.new_quad_mesh()
	gd.plane_mesh_set_size(cast(gd.Plane_Mesh)self.quad, gd.Vector2{1, 1}) // unit quad; per-bullet scale rides the transform
	self.multimesh = gd.rendering_server_multimesh_create(rs)
	gd.rendering_server_multimesh_set_mesh(
		rs,
		self.multimesh,
		gd.resource_get_rid(cast(gd.Resource)self.quad),
	)
	gd.rendering_server_multimesh_allocate_data(
		rs,
		self.multimesh,
		MAX_BULLETS,
		.Multimesh_Transform_2d,
		true,  // per-instance color
		false, // no custom data
		false, // no indirect
	)
	// Attach the multimesh to THIS node's canvas item — one retained draw command; the
	// buffer updates animate it from then on.
	gd.rendering_server_canvas_item_add_multimesh(
		rs,
		gd.canvas_item_get_canvas_item(cast(gd.Canvas_Item)self.owner),
		self.multimesh,
		gd.Rid{},
	)
	self.buffer = gd.new_packed_float32_array_default()
	gd.packed_float32_array_resize(&self.buffer, MAX_BULLETS * INSTANCE_FLOATS)

	// Discoverable by the other modules: they get_first_node_in_group("bullet_field").
	grp := gd.new_string_name_cstring("bullet_field", true)
	gd.node_add_to_group(cast(gd.Node)self.owner, grp, false)
}

// ---- emitters: the engine-callable API other modules drive ----------------

// spawn_one — the primitive every pattern reduces to.
@(gd_method)
bullet_field_spawn_one :: proc(self: ^BulletField, pos: gd.Vector2, vel: gd.Vector2, hostile: gd.Bool, damage: gd.Int) {
	if self.count >= MAX_BULLETS {return}
	i := self.count
	self.count += 1
	self.bullets[i] = Bullet {
		pos     = {pos.x, pos.y},
		vel     = {vel.x, vel.y},
		radius  = self.bullet_scale * 0.5,
		ttl     = 8,
		hostile = bool(hostile),
		damage  = i32(damage),
		hue     = hostile ? gd.Color{1.0, 0.35, 0.35, 1.0} : gd.Color{0.4, 0.9, 1.0, 1.0},
	}
}

// spawn_ring — `n` bullets in a circle (the boss's bread and butter).
@(gd_method)
bullet_field_spawn_ring :: proc(self: ^BulletField, pos: gd.Vector2, n: gd.Int, speed: f64, phase: f64, damage: gd.Int) {
	for k in 0 ..< int(n) {
		a := f32(phase) + f32(k) * math.TAU / f32(n)
		v := gd.Vector2{math.cos(a) * f32(speed), math.sin(a) * f32(speed)}
		bullet_field_spawn_one(self, pos, v, true, damage)
	}
}

// spawn_aimed — a spread of `n` bullets fanned around the direction to `target`.
@(gd_method)
bullet_field_spawn_aimed :: proc(self: ^BulletField, pos: gd.Vector2, target: gd.Vector2, n: gd.Int, speed: f64, spread: f64, hostile: gd.Bool, damage: gd.Int) {
	base := math.atan2(target.y - pos.y, target.x - pos.x)
	for k in 0 ..< int(n) {
		t := int(n) == 1 ? 0.5 : f32(k) / f32(int(n) - 1)
		a := base + (t - 0.5) * f32(spread)
		v := gd.Vector2{math.cos(a) * f32(speed), math.sin(a) * f32(speed)}
		bullet_field_spawn_one(self, pos, v, hostile, damage)
	}
}

@(gd_method)
bullet_field_clear_hostile :: proc(self: ^BulletField) {
	// A shield powerup wipes the screen: swap-remove every hostile bullet.
	i := 0
	for i < self.count {
		if self.bullets[i].hostile {
			self.count -= 1
			self.bullets[i] = self.bullets[self.count]
		} else {
			i += 1
		}
	}
}

@(gd_method)
bullet_field_live_count :: proc(self: ^BulletField) -> gd.Int {
	return gd.Int(self.count)
}

// ---- enemy registry: enemies opt in to player-bullet collision ------------

@(gd_method)
bullet_field_register_enemy :: proc(self: ^BulletField, id: gd.Int, pos: gd.Vector2, radius: f64) {
	// Update-or-add: enemies re-register each physics tick with their current position
	// (dumb and robust across module boundaries — no lifetime coupling).
	for k in 0 ..< self.enemy_count {
		if self.enemy_ids[k] == int(id) {
			self.enemy_pos[k] = {pos.x, pos.y}
			self.enemy_radius[k] = f32(radius)
			return
		}
	}
	if self.enemy_count >= len(self.enemy_ids) {return}
	self.enemy_ids[self.enemy_count] = int(id)
	self.enemy_pos[self.enemy_count] = {pos.x, pos.y}
	self.enemy_radius[self.enemy_count] = f32(radius)
	self.enemy_count += 1
}

@(gd_method)
bullet_field_unregister_enemy :: proc(self: ^BulletField, id: gd.Int) {
	for k in 0 ..< self.enemy_count {
		if self.enemy_ids[k] == int(id) {
			self.enemy_count -= 1
			self.enemy_ids[k] = self.enemy_ids[self.enemy_count]
			self.enemy_pos[k] = self.enemy_pos[self.enemy_count]
			self.enemy_radius[k] = self.enemy_radius[self.enemy_count]
			return
		}
	}
}

// ---- simulation ------------------------------------------------------------

bullet_field_physics_process :: proc(self: ^BulletField, delta: f64) {
	dt := f32(delta)
	// Player position/size, refreshed lazily from the "player" group (cross-module: the
	// Player class lives in the MAIN module; we only ever hold an engine Object handle).
	px, py, prad, have_player := field_player_probe(self)

	// The hot loop: integrate + expire + collide, swap-remove keeps the pool dense.
	// #soa means each field access below streams through its own contiguous array.
	i := 0
	for i < self.count {
		b := &self.bullets[i]
		b.pos += b.vel * dt
		b.ttl -= dt

		dead := b.ttl <= 0
		if !dead {
			if b.hostile {
				if have_player {
					d := b.pos - [2]f32{px, py}
					r := b.radius + prad
					if d.x * d.x + d.y * d.y < r * r {
						bullet_field_emit_player_hit(self, i64(b.damage))
						dead = true
					}
				}
			} else {
				for k in 0 ..< self.enemy_count {
					d := b.pos - self.enemy_pos[k]
					r := b.radius + self.enemy_radius[k]
					if d.x * d.x + d.y * d.y < r * r {
						bullet_field_emit_enemy_hit(self, i64(self.enemy_ids[k]), i64(b.damage))
						dead = true
						break
					}
				}
			}
		}

		if dead {
			self.count -= 1
			self.bullets[i] = self.bullets[self.count]
		} else {
			i += 1
		}
	}

	field_upload_buffer(self)
}

@(private = "file")
field_player_probe :: proc(self: ^BulletField) -> (px, py, prad: f32, ok: bool) {
	if self.player == nil {
		tree := gd.node_get_tree(cast(gd.Node)self.owner)
		if tree == nil {return}
		grp := gd.new_string_name_cstring("player", true)
		n := gd.scene_tree_get_first_node_in_group(tree, grp)
		if n == nil {return}
		self.player = cast(gd.Object)n
		self.player_radius = 10
	}
	p := gd.node2d_get_position(cast(gd.Node2d)self.player)
	return p.x, p.y, self.player_radius, true
}

// Flatten live bullets into the multimesh instance buffer. The packed array was
// resized once in _ready; `data_unsafe` writes straight into its storage — the whole
// upload is one memcpy-shaped loop plus one RenderingServer call.
@(private = "file")
field_upload_buffer :: proc(self: ^BulletField) {
	rs := gd.singleton_rendering_server()
	data := self.buffer.data_unsafe
	s := self.bullet_scale
	for i in 0 ..< self.count {
		pos := self.bullets[i].pos
		hue := self.bullets[i].hue
		o := i * INSTANCE_FLOATS
		// transform2d rows: [xx xy 0 ox] [yx yy 0 oy] — axis-aligned scaled quad.
		data[o + 0] = s
		data[o + 1] = 0
		data[o + 2] = 0
		data[o + 3] = pos.x
		data[o + 4] = 0
		data[o + 5] = s
		data[o + 6] = 0
		data[o + 7] = pos.y
		data[o + 8] = hue.r
		data[o + 9] = hue.g
		data[o + 10] = hue.b
		data[o + 11] = hue.a
	}
	gd.rendering_server_multimesh_set_buffer(rs, self.multimesh, self.buffer)
	gd.rendering_server_multimesh_set_visible_instances(rs, self.multimesh, gd.Int(self.count))
}
