//gd:extends Node3D
package scripts

// Offline Box3D: this script owns one Box3D world and steps it itself, once per
// Godot physics frame. There is no Kit, no Replay and no network.
//
// A pyramid of boxes stands on the ground. Click (or press Space) to launch a ball
// from the camera toward the mouse; press R to rebuild the tower. Hold the right mouse
// button and drag to orbit around the stack; W/S (or Up/Down) move the camera in and out.
//
// The Godot side is ordinary nodes: each body gets a MeshInstance3D whose transform
// is copied from the body's pose after every step. The nodes never feed back into
// the simulation.

import "core:fmt"
import "core:math"
import b "godot:box3d"
import gd "godot:godot"

ROWS :: 5 // pyramid rows; the bottom row has ROWS boxes
BOX_COUNT :: ROWS * (ROWS + 1) / 2
BALL_SLOTS :: 8 // launching a ninth ball recycles the oldest one
BOX_HALF :: f32(0.4)
BOX_GAP :: f32(0.02)
BALL_RADIUS :: f32(0.3)
// Densities are kg/m³; Box3D's default is 1000 (water). Light crates and a heavy
// ball: each box is ~128 kg and the ball ~450 kg, so a hit carries through the stack.
BOX_DENSITY :: f32(250)
BALL_DENSITY :: f32(4000)
LAUNCH_SPEED :: f32(20) // meters per second
GROUND_HALF :: b.Vec3{12, 0.5, 12}
LOST_HEIGHT :: f32(-20) // balls that fall off the ground are removed here

// The camera orbits CAMERA_TARGET, the middle of the stack. Yaw and pitch are in
// radians; pitch stays above the ground and short of straight down.
CAMERA_TARGET :: gd.Vector3{0, 1.6, 0}
ORBIT_PER_PIXEL :: f32(0.008)
PITCH_MIN :: f32(0.05)
PITCH_MAX :: f32(1.4)
DISTANCE_MIN :: f32(4)
DISTANCE_MAX :: f32(25)
ZOOM_RATE :: f32(1.5) // distance changes by a factor of e^1.5 per second held

LAUNCH_ACTION :: "box_tower_launch"
RESET_ACTION :: "box_tower_reset"
ZOOM_IN_ACTION :: "box_tower_zoom_in"
ZOOM_OUT_ACTION :: "box_tower_zoom_out"

Box_Tower :: struct {
	owner:      gd.Node3d,
	camera:     gd.Camera3d `gd:"onready=Camera"`,
	status:     gd.Label `gd:"onready=HUD/Status"`,
	world:      b.World,
	boxes:      [BOX_COUNT]b.Body,
	box_start:  [BOX_COUNT]f32, // resting height, to count knocked-down boxes
	balls:      [BALL_SLOTS]b.Body,
	box_nodes:  [BOX_COUNT]gd.Mesh_Instance3d,
	ball_nodes: [BALL_SLOTS]gd.Mesh_Instance3d,
	next_ball:  int,
	launched:   int,
	fallen:     int,
	failed:     bool,
	text:       [256]u8, // HUD text; rewritten only when the numbers change
	yaw:        f32,
	pitch:      f32,
	distance:   f32,
	last_mouse: gd.Vector2,
	orbiting:   bool, // right button held since the previous frame
}

box_tower_ready :: proc(self: ^Box_Tower) {
	bind_actions()
	make_nodes(self)
	self.pitch = 0.14
	self.distance = 10
	place_camera(self)

	if build_world(self) {
		show_status(self)
	}
}

box_tower_physics_process :: proc(self: ^Box_Tower, delta: f64) {
	if self.failed {
		return
	}

	launched, fallen := self.launched, self.fallen

	if gd.is_action_just_pressed(RESET_ACTION) {
		destroy_world(self)

		if !build_world(self) {
			return
		}
	}

	if gd.is_action_just_pressed(LAUNCH_ACTION) && !launch_ball(self) {
		return
	}

	// world_step_fixed advances exactly 1/60 s (four substeps), matching the
	// 60 Hz physics rate in project.godot, so one step per physics frame is real time.
	if status := b.world_step_fixed(self.world); status != .Ok {
		fail(self, "world_step_fixed", status)
		return
	}

	if !sync_nodes(self) {
		return
	}

	if self.launched != launched || self.fallen != fallen {
		show_status(self)
	}
}

// Camera controls run every rendered frame, independent of the physics.
box_tower_process :: proc(self: ^Box_Tower, delta: f64) {
	mouse := gd.viewport_get_mouse_position(gd.node_get_viewport(self.owner))

	if gd.input_is_mouse_button_pressed(gd.singleton_input(), .Right) {
		if self.orbiting {
			moved := mouse - self.last_mouse
			self.yaw -= moved.x * ORBIT_PER_PIXEL
			self.pitch = clamp(self.pitch + moved.y * ORBIT_PER_PIXEL, PITCH_MIN, PITCH_MAX)
		}

		self.orbiting = true
	} else {
		self.orbiting = false
	}

	self.last_mouse = mouse
	zoom := f32(gd.get_axis(ZOOM_IN_ACTION, ZOOM_OUT_ACTION))

	if zoom != 0 {
		self.distance = clamp(
			self.distance * math.exp(zoom * ZOOM_RATE * f32(delta)),
			DISTANCE_MIN,
			DISTANCE_MAX,
		)
	}

	place_camera(self)
}

box_tower_exit_tree :: proc(self: ^Box_Tower) {
	destroy_world(self)
}

place_camera :: proc(self: ^Box_Tower) {
	flat := math.cos(self.pitch) * self.distance
	offset := gd.Vector3 {
		math.sin(self.yaw) * flat,
		math.sin(self.pitch) * self.distance,
		math.cos(self.yaw) * flat,
	}
	camera := cast(gd.Node3d)self.camera
	gd.node3d_set_position(camera, CAMERA_TARGET + offset)
	gd.node3d_look_at(camera, CAMERA_TARGET, {0, 1, 0}, false)
}

bind_actions :: proc() {
	if !gd.has_action(LAUNCH_ACTION) {
		gd.add_action(LAUNCH_ACTION)
		gd.action_add_mouse_button(LAUNCH_ACTION, i64(gd.Mouse_Button.Left))
		gd.action_add_key(LAUNCH_ACTION, i64(gd.Key.Space))
	}

	if !gd.has_action(RESET_ACTION) {
		gd.add_action(RESET_ACTION)
		gd.action_add_key(RESET_ACTION, i64('R'))
	}

	if !gd.has_action(ZOOM_IN_ACTION) {
		gd.add_action(ZOOM_IN_ACTION)
		gd.action_add_key(ZOOM_IN_ACTION, i64('W'))
		gd.action_add_key(ZOOM_IN_ACTION, i64(gd.Key.Up))
	}

	if !gd.has_action(ZOOM_OUT_ACTION) {
		gd.add_action(ZOOM_OUT_ACTION)
		gd.action_add_key(ZOOM_OUT_ACTION, i64('S'))
		gd.action_add_key(ZOOM_OUT_ACTION, i64(gd.Key.Down))
	}
}

// Create the ground, box and ball nodes once. A reset rebuilds only the physics.
make_nodes :: proc(self: ^Box_Tower) {
	ground_mesh := gd.new_box_mesh()
	gd.ref_counted_init_ref(ground_mesh)
	gd.box_mesh_set_size(ground_mesh, {2 * GROUND_HALF.x, 2 * GROUND_HALF.y, 2 * GROUND_HALF.z})
	ground := mesh_node(self, cast(gd.Mesh)ground_mesh, {0.18, 0.21, 0.27, 1})
	gd.release_ref(ground_mesh)
	gd.node3d_set_position(cast(gd.Node3d)ground, {0, -GROUND_HALF.y, 0})

	box_mesh := gd.new_box_mesh()
	gd.ref_counted_init_ref(box_mesh)
	gd.box_mesh_set_size(box_mesh, {2 * BOX_HALF, 2 * BOX_HALF, 2 * BOX_HALF})
	index := 0

	for row in 0 ..< ROWS {
		shade := f32(row) / f32(ROWS)

		for _ in 0 ..< ROWS - row {
			color := gd.Color{0.85 - 0.25 * shade, 0.45 + 0.3 * shade, 0.2 + 0.1 * shade, 1}
			self.box_nodes[index] = mesh_node(self, cast(gd.Mesh)box_mesh, color)
			index += 1
		}
	}

	gd.release_ref(box_mesh)

	ball_mesh := gd.new_sphere_mesh()
	gd.ref_counted_init_ref(ball_mesh)
	gd.sphere_mesh_set_radius(ball_mesh, f64(BALL_RADIUS))
	gd.sphere_mesh_set_height(ball_mesh, f64(2 * BALL_RADIUS))

	for i in 0 ..< BALL_SLOTS {
		self.ball_nodes[i] = mesh_node(self, cast(gd.Mesh)ball_mesh, {0.3, 0.75, 0.95, 1})
		gd.node3d_set_visible(cast(gd.Node3d)self.ball_nodes[i], false)
	}

	gd.release_ref(ball_mesh)
}

mesh_node :: proc(self: ^Box_Tower, mesh: gd.Mesh, color: gd.Color) -> gd.Mesh_Instance3d {
	node := gd.new_mesh_instance3d()
	gd.mesh_instance3d_set_mesh(node, mesh)
	material := gd.new_standard_material3d()
	gd.ref_counted_init_ref(material)
	gd.base_material3d_set_albedo(cast(gd.Base_Material3d)material, color)
	gd.geometry_instance3d_set_material_override(
		cast(gd.Geometry_Instance3d)node,
		cast(gd.Material)material,
	)
	gd.release_ref(material)
	gd.add_child(self.owner, node)
	return node
}

// A fresh world: static ground plus the box pyramid, all asleep until hit.
build_world :: proc(self: ^Box_Tower) -> bool {
	world, status := b.world_create(b.world_def_default())

	if status != .Ok {
		return fail(self, "world_create", status)
	}

	self.world = world
	ground_def := b.body_def_default()
	ground_def.type = .Static
	ground_def.pose.position = {0, -GROUND_HALF.y, 0}
	ground, ground_status := b.body_create(world, ground_def)

	if ground_status != .Ok {
		return fail(self, "body_create (ground)", ground_status)
	}

	if _, shape_status := b.shape_box(ground, b.shape_def_default(), GROUND_HALF);
	   shape_status != .Ok {
		return fail(self, "shape_box (ground)", shape_status)
	}

	step := 2 * BOX_HALF + BOX_GAP
	index := 0

	for row in 0 ..< ROWS {
		count := ROWS - row

		for column in 0 ..< count {
			def := b.body_def_default()
			def.type = .Dynamic
			x := (f32(column) - f32(count - 1) / 2) * step
			y := BOX_HALF + f32(row) * 2 * BOX_HALF
			def.pose.position = {x, y, 0}
			body, body_status := b.body_create(world, def)

			if body_status != .Ok {
				return fail(self, "body_create (box)", body_status)
			}

			self.boxes[index] = body
			box_shape := b.shape_def_default()
			box_shape.density = BOX_DENSITY

			if _, shape_status := b.shape_box(body, box_shape, {BOX_HALF, BOX_HALF, BOX_HALF});
			   shape_status != .Ok {
				return fail(self, "shape_box (box)", shape_status)
			}

			self.box_start[index] = y
			index += 1
		}
	}

	self.next_ball = 0
	self.launched = 0
	self.fallen = 0
	return sync_nodes(self)
}

// Destroying the world destroys every body and shape in it; clear the handles.
destroy_world :: proc(self: ^Box_Tower) {
	if self.world != 0 {
		if status := b.world_destroy(&self.world); status != .Ok {
			gd.error(fmt.ctprintf("Box3D world_destroy failed: %v", status))
		}
	}

	self.world = 0
	self.boxes = {}
	self.balls = {}

	for node in self.ball_nodes {
		gd.node3d_set_visible(cast(gd.Node3d)node, false)
	}
}

launch_ball :: proc(self: ^Box_Tower) -> bool {
	mouse := gd.viewport_get_mouse_position(gd.node_get_viewport(self.owner))
	origin := gd.camera3d_project_ray_origin(self.camera, mouse)
	direction := gd.camera3d_project_ray_normal(self.camera, mouse)
	slot := self.next_ball

	if self.balls[slot] != 0 {
		if status := b.body_destroy(&self.balls[slot]); status != .Ok {
			return fail(self, "body_destroy (ball)", status)
		}
	}

	def := b.body_def_default()
	def.type = .Dynamic
	def.is_bullet = 1 // continuous collision, so a fast ball cannot tunnel through a box
	start := origin + direction * 0.5
	velocity := direction * LAUNCH_SPEED
	def.pose.position = {start.x, start.y, start.z}
	def.linear_velocity = {velocity.x, velocity.y, velocity.z}
	body, status := b.body_create(self.world, def)

	if status != .Ok {
		return fail(self, "body_create (ball)", status)
	}

	shape_def := b.shape_def_default()
	shape_def.density = BALL_DENSITY

	if _, shape_status := b.shape_sphere(body, shape_def, BALL_RADIUS); shape_status != .Ok {
		_ = b.body_destroy(&body)
		return fail(self, "shape_sphere (ball)", shape_status)
	}

	self.balls[slot] = body
	self.next_ball = (slot + 1) % BALL_SLOTS
	self.launched += 1
	return true
}

// Copy every body's pose onto its node, drop lost balls and count fallen boxes.
sync_nodes :: proc(self: ^Box_Tower) -> bool {
	fallen := 0

	for body, i in self.boxes {
		pose, status := b.body_get_pose(body)

		if status != .Ok {
			return fail(self, "body_get_pose (box)", status)
		}

		place(self.box_nodes[i], pose)

		if pose.position.y < self.box_start[i] - BOX_HALF {
			fallen += 1
		}
	}

	for i in 0 ..< BALL_SLOTS {
		node := cast(gd.Node3d)self.ball_nodes[i]

		if self.balls[i] == 0 {
			gd.node3d_set_visible(node, false)
			continue
		}

		pose, status := b.body_get_pose(self.balls[i])

		if status != .Ok {
			return fail(self, "body_get_pose (ball)", status)
		}

		if pose.position.y < LOST_HEIGHT {
			if destroy_status := b.body_destroy(&self.balls[i]); destroy_status != .Ok {
				return fail(self, "body_destroy (lost ball)", destroy_status)
			}

			gd.node3d_set_visible(node, false)
			continue
		}

		place(self.ball_nodes[i], pose)
		gd.node3d_set_visible(node, true)
	}

	self.fallen = fallen
	return true
}

place :: proc(node: gd.Mesh_Instance3d, pose: b.Pose) {
	node3d := cast(gd.Node3d)node
	gd.node3d_set_position(node3d, transmute(gd.Vector3)pose.position)
	gd.node3d_set_quaternion(node3d, transmute(gd.Quaternion)pose.rotation)
}

show_status :: proc(self: ^Box_Tower) {
	text := fmt.bprintf(
		self.text[:len(self.text) - 1],
		"Boxes down: %d / %d    Balls launched: %d\nClick or Space: launch    Right-drag: orbit    W/S: zoom    R: reset",
		self.fallen,
		BOX_COUNT,
		self.launched,
	)
	self.text[len(text)] = 0
	gd.set_text(cast(gd.Object)self.status, cstring(raw_data(self.text[:])))
}

// Report once, show the reason on screen and stop stepping.
fail :: proc(self: ^Box_Tower, what: string, status: b.Status) -> bool {
	hint := ""

	if status == .Incompatible {
		hint = "\nThe Box3D library did not load: build with BOX3D_NATIVE_LIBRARY set (see README.md)."
	}

	message := fmt.bprintf(
		self.text[:len(self.text) - 1],
		"Box3D %s failed: %v%s",
		what,
		status,
		hint,
	)
	self.text[len(message)] = 0
	gd.error(cstring(raw_data(self.text[:])))
	gd.set_text(cast(gd.Object)self.status, cstring(raw_data(self.text[:])))
	self.failed = true
	return false
}

