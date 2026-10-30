package replay_scrapyard

import "core:fmt"
import "core:math"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/game"
import flow "../shared/flow"

Feedback_Burst :: struct {
	node: gd.Cpu_Particles2d,
	id: r.Event_Id,
	born: u64,
}

Feedback_Float :: struct {
	node: gd.Label,
	id: r.Event_Id,
	born: u64,
	position: [2]f32,
}

Feedback_Debris :: struct {
	node: gd.Mesh_Instance2d,
	id: r.Event_Id,
	born: u64,
	position, velocity: [2]f32,
	spin: f32,
}

Feedback_Ember :: struct {
	node: gd.Mesh_Instance2d,
	id: r.Event_Id,
	born: u64,
}

Feedback_Spark :: struct {
	node: gd.Mesh_Instance2d,
	id: r.Event_Id,
	born: u64,
	position, velocity: [2]f32,
}

Feedback_Wound :: struct {
	node: gd.Mesh_Instance2d,
	id: r.Event_Id,
	born: u64,
}

Feedback :: struct {
	ledger: v.One_Shots,
	bursts: [256]Feedback_Burst,
	floats: [128]Feedback_Float,
	debris: [256]Feedback_Debris,
	wounds: [32]Feedback_Wound,
	sparks: [192]Feedback_Spark,
	embers: [512]Feedback_Ember,
	trails: flow.Trails,
	buffs: flow.Buff_Observer,
	ready, scoped: bool,
	epoch, reset: u64,
	run: u32,
	floor: u8,
	spawned, duplicates, canceled, dropped: u64,
	wound_missing: u64,
}

feedback_init :: proc(self: ^ReplayScrapyard) -> bool {
	f := &self.feedback[0]
	f.ready = v.one_shots_init(&f.ledger, 1, history = 512, per_tick = 128)
	return f.ready
}

feedback_remove :: proc(node: gd.Node) {
	if node == nil {
		return
	}
	if parent := gd.node_get_parent(node); parent != nil {
		gd.node_remove_child(parent, node)
	}
	gd.node_queue_free(node)
}

feedback_clear :: proc(f: ^Feedback) {
	for &b in f.bursts {
		feedback_remove(b.node)
		b = {}
	}
	for &n in f.floats {
		feedback_remove(n.node)
		n = {}
	}
	for &d in f.debris {
		feedback_remove(d.node)
		d = {}
	}
	for &w in f.wounds {
		feedback_remove(w.node)
		w = {}
	}
	for &s in f.sparks {
		feedback_remove(s.node)
		s = {}
	}
	for &e in f.embers {
		feedback_remove(e.node)
		e = {}
	}
	dropped := f.trails.dropped
	f.trails = {
		dropped = dropped,
	}
	buff_dropped := f.buffs.dropped
	f.buffs = {
		dropped = buff_dropped,
	}
}

feedback_close :: proc(self: ^ReplayScrapyard) {
	f := &self.feedback[0]
	feedback_clear(f)
	v.one_shots_destroy(&f.ledger)
	f^ = {}
}

feedback_prepare :: proc(self: ^ReplayScrapyard) {
	f := &self.feedback[0]
	if !f.ready || !self.session.ready {
		return
	}
	epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	baseline := self.session.authority ? u64(0) : self.session.client.journal.baseline
	if !f.scoped || epoch != f.epoch {
		if self.session.authority {
			baseline = self.session.server.timeline.head
			for change in self.session.changes[:self.session.change_count] {
				if change.kind == .Begin && change.occurrence.id.epoch == epoch && change.occurrence.id.tick > 0 {
					baseline = min(baseline, change.occurrence.id.tick - 1)
				}
			}
		}
		feedback_clear(f)
		if epoch == f.ledger.epoch {
			v.one_shots_retire(&f.ledger, baseline)
		} else {
			v.one_shots_reset(&f.ledger, epoch, baseline)
		}
		f.epoch, f.scoped = epoch, true
	}
	if !self.session.authority && f.reset != self.session.client.view_reset {
		feedback_clear(f)
		f.reset = self.session.client.view_reset
	}
	frontier :=
		self.session.authority ? self.session.server.timeline.head : min(self.session.client.journal.confirmed, self.session.client.journal.watch_tick)
	floor := max(baseline, frontier > 256 ? frontier - 256 : 0)
	if floor > f.ledger.floor {
		v.one_shots_retire(&f.ledger, floor)
	}
}

feedback_burst :: proc(self: ^ReplayScrapyard, id: r.Event_Id, position: [2]f32, color: gd.Color) {
	f := &self.feedback[0]
	for &slot in f.bursts {
		if slot.node == nil {
			node := gd.new_cpu_particles2d()
			scenery_name(node, fmt.tprintf("Burst%d", f.spawned))
			gd.add_child(self.world_node, node)
			gd.node2d_set_position(node, position)
			gd.cpu_particles2d_set_amount(node, 12)
			gd.cpu_particles2d_set_lifetime(node, 0.4)
			gd.cpu_particles2d_set_one_shot(node, true)
			gd.cpu_particles2d_set_explosiveness_ratio(node, 1)
			gd.cpu_particles2d_set_spread(node, 180)
			gd.cpu_particles2d_set_param_min(node, .Param_Initial_Linear_Velocity, 40)
			gd.cpu_particles2d_set_param_max(node, .Param_Initial_Linear_Velocity, 90)
			gd.cpu_particles2d_set_color(node, color)
			gd.cpu_particles2d_set_emitting(node, true)
			slot = {node, id, gd.time_get_ticks_msec(gd.singleton_time())}
			f.spawned += 1
			return
		}
	}
	f.dropped += 1
}

feedback_float :: proc(self: ^ReplayScrapyard, id: r.Event_Id, position: [2]f32, text: cstring, color: gd.Color) {
	f := &self.feedback[0]
	for &slot in f.floats {
		if slot.node == nil {
			node := gd.new_label()
			gd.add_child(self.world_node, node)
			gd.control_set_mouse_filter(node, .Mouse_Filter_Ignore)
			gd.set_string(node, "text", text)
			gd.control_set_position(node, position, false)
			gd.canvas_item_set_self_modulate(node, color)
			gd.canvas_item_set_z_index(node, 30)
			slot = {node, id, gd.time_get_ticks_msec(gd.singleton_time()), position}
			f.spawned += 1
			return
		}
	}
	f.dropped += 1
}

feedback_explode :: proc(self: ^ReplayScrapyard, id: r.Event_Id, position: [2]f32) {
	feedback_burst(self, id, position, {1, 0.8, 0.4, 1})
	feedback_burst(self, id, position + [2]f32{-8, -4}, {0.7, 0.55, 0.4, 1})
	feedback_burst(self, id, position + [2]f32{8, 4}, {0.7, 0.55, 0.4, 1})
	f := &self.feedback[0]
	made := 0
	for &slot in f.debris {
		if slot.node == nil {
			angle := f32(made) * 2.399 + f32(id.tick % 100) * 0.07
			node := gd.new_mesh_instance2d()
			gd.add_child(self.world_node, node)
			points := gd.new_packed_vector2_array()
			for point in ([3]gd.Vector2{{5, 0}, {-3, -2}, {-3, 2}}) {
				gd.packed_vector2_array_append(&points, point)
			}
			rgd.mesh2_polygon(node, points)
			gd.free_packed_vector2_array(points)
			gd.canvas_item_set_self_modulate(node, {0.75, 0.6, 0.4, 1})
			gd.node2d_set_position(node, position)
			gd.canvas_item_set_z_index(node, 3)
			slot = {
				node,
				id,
				gd.time_get_ticks_msec(gd.singleton_time()),
				position,
				{math.cos(angle) * 120, math.sin(angle) * 120 - 35},
				angle,
			}
			made += 1
			f.spawned += 1
			if made == 6 {
				return
			}
		}
	}
	f.dropped += u64(6 - made)
}

feedback_cancel :: proc(f: ^Feedback, id: r.Event_Id) {
	for &b in f.bursts {
		if b.node != nil && b.id == id {
			feedback_remove(b.node)
			b = {}
			f.canceled += 1
		}
	}
	for &n in f.floats {
		if n.node != nil && n.id == id {
			feedback_remove(n.node)
			n = {}
			f.canceled += 1
		}
	}
	for &d in f.debris {
		if d.node != nil && d.id == id {
			feedback_remove(d.node)
			d = {}
			f.canceled += 1
		}
	}
	for &w in f.wounds {
		if w.node != nil && w.id == id {
			feedback_remove(w.node)
			w = {}
			f.canceled += 1
		}
	}
	for &s in f.sparks {
		if s.node != nil && s.id == id {
			feedback_remove(s.node)
			s = {}
			f.canceled += 1
		}
	}
	for &e in f.embers {
		if e.node != nil && e.id == id {
			feedback_remove(e.node)
			e = {}
			f.canceled += 1
		}
	}
}

feedback_event :: proc(self: ^ReplayScrapyard, change: v.Change(net.Net_Event(game.Event))) {
	f := &self.feedback[0]
	if !f.ready || change.occurrence.value.kind != .Gameplay {
		return
	}
	id := change.occurrence.id
	if change.kind == .Cancel {
		feedback_cancel(f, id)
		return
	}
	if change.kind != .Begin {
		return
	}
	event := change.occurrence.value.value
	if event.kind != .Dash &&
	   event.kind != .Hurt &&
	   event.kind != .Pickup &&
	   event.kind != .Blast &&
	   event.kind != .Healed &&
	   event.kind != .Wall {
		return
	}
	result := v.one_shot_note(&f.ledger, id)
	if result != .New {
		if result == .Duplicate {
			f.duplicates += 1
		}
		return
	}
	#partial switch event.kind {
	case .Dash:
		feedback_burst(self, id, event.position, {0.75, 0.9, 1, 1})
	case .Hurt:
		wound, found := presentation_wound(self, event, id)
		if !found {
			f.wound_missing += 1
			return
		}
		feedback_burst(self, id, wound.victim + [2]f32{0, -6}, {0.9, 0.25, 0.25, 1})
		if event.seat == rgd.session_seat(self.session) && wound.directional {
			feedback_wound(self, id, wound)
		}
	case .Pickup:
		feedback_burst(self, id, event.position, {0.95, 0.85, 0.4, 1})
		feedback_float(
			self,
			id,
			event.position + [2]f32{-6, -16},
			fmt.ctprintf("+%d", event.serial),
			{1, 0.9, 0.45, 1},
		)
	case .Healed:
		feedback_float(
			self,
			id,
			event.position + [2]f32{-6, -20},
			fmt.ctprintf("+%d HP", event.serial),
			{0.5, 1, 0.6, 1},
		)
	case .Blast:
		feedback_explode(self, id, event.position)
	case .Wall:
		feedback_wall(self, id, event)
	case:
	}
}

feedback_wall :: proc(self: ^ReplayScrapyard, id: r.Event_Id, event: game.Event) {
	normal := game.wall_normal(event)
	if normal == ([2]f32{}) {
		return
	}
	base := math.atan2(normal[1], normal[0])
	f := &self.feedback[0]
	made := 0
	color: gd.Color = event.detail & 4 != 0 ? gd.Color{0.45, 0.9, 0.5, 1} : gd.Color{1, 0.88, 0.55, 1}
	for &slot, i in f.sparks {
		if slot.node == nil {
			angle := base + (f32(made) - 1) * 0.55
			node := gd.new_mesh_instance2d()
			scenery_name(node, fmt.tprintf("WallSpark%d", i))
			gd.add_child(self.world_node, node)
			points := gd.new_packed_vector2_array()
			for point in ([3]gd.Vector2{{5, 0}, {-3, -2}, {-3, 2}}) {
				gd.packed_vector2_array_append(&points, point)
			}
			rgd.mesh2_polygon(node, points)
			gd.free_packed_vector2_array(points)
			gd.canvas_item_set_self_modulate(node, color)
			gd.canvas_item_set_z_index(node, 24)
			gd.node2d_set_position(node, event.position)
			gd.node2d_set_rotation(node, gd.Float(angle))
			slot = {
				node,
				id,
				gd.time_get_ticks_msec(gd.singleton_time()),
				event.position,
				{math.cos(angle) * 170, math.sin(angle) * 170},
			}
			made += 1
			f.spawned += 1
			if made == 3 {
				return
			}
		}
	}
	f.dropped += u64(3 - made)
}

feedback_ember :: proc(self: ^ReplayScrapyard, id: r.Event_Id, position: [2]f32) {
	f := &self.feedback[0]
	for &slot, i in f.embers {
		if slot.node == nil {
			node := gd.new_mesh_instance2d()
			scenery_name(node, fmt.tprintf("Ember%d", i))
			gd.add_child(self.world_node, node)
			points := gd.new_packed_vector2_array()
			for point in ([4]gd.Vector2{{2, 0}, {0, 2}, {-2, 0}, {0, -2}}) {
				gd.packed_vector2_array_append(&points, point)
			}
			rgd.mesh2_polygon(node, points)
			gd.free_packed_vector2_array(points)
			gd.canvas_item_set_self_modulate(node, {1, 0.8, 0.45, 0.9})
			gd.canvas_item_set_z_index(node, 12)
			gd.node2d_set_position(node, position)
			slot = {node, id, gd.time_get_ticks_msec(gd.singleton_time())}
			f.spawned += 1
			return
		}
	}
	f.dropped += 1
}

feedback_wound :: proc(self: ^ReplayScrapyard, id: r.Event_Id, wound: flow.Wound_View) {
	f := &self.feedback[0]
	for &slot, i in f.wounds {
		if slot.node == nil {
			node := gd.new_mesh_instance2d()
			scenery_name(node, fmt.tprintf("Wound%d", i))
			gd.add_child(self.world_node, node)
			points := gd.new_packed_vector2_array()
			for point in ([3]gd.Vector2{{16, 0}, {2, -7}, {2, 7}}) {
				gd.packed_vector2_array_append(&points, point)
			}
			rgd.mesh2_polygon(node, points)
			gd.free_packed_vector2_array(points)
			gd.canvas_item_set_self_modulate(node, {1, 0.24, 0.18, 0.95})
			gd.canvas_item_set_z_index(node, 26)
			gd.node2d_set_position(node, wound.marker)
			gd.node2d_set_rotation(node, gd.Float(math.atan2(wound.direction[1], wound.direction[0])))
			slot = {node, id, gd.time_get_ticks_msec(gd.singleton_time())}
			f.spawned += 1
			return
		}
	}
	f.dropped += 1
}

feedback_mob :: proc(self: ^ReplayScrapyard, id: r.Event_Id, mob: game.Mob, damage: u16, prop: bool) {
	f := &self.feedback[0]
	if !f.ready || v.one_shot_note(&f.ledger, id, 1) != .New {
		return
	}
	if mob.hp == 0 {
		feedback_explode(self, id, mob.position + [2]f32{0, -6})
		screen_death(self, mob.position, mob.kind == 4)
	} else {
		feedback_burst(self, id, mob.position + [2]f32{0, -4}, {1, 0.9, 0.55, 1})
	}
	if !prop {
		feedback_float(self, id, mob.position + [2]f32{-6, -24}, fmt.ctprintf("%d", damage), {1, 0.95, 0.6, 1})
	}
}

feedback_frame :: proc(self: ^ReplayScrapyard) {
	f := &self.feedback[0]
	if !f.ready {
		return
	}
	frame, ok := rgd.session_authority_state(self.session)
	if ok && (f.run != frame.state.run || f.floor != frame.state.floor) {
		feedback_clear(f)
		f.run, f.floor = frame.state.run, frame.state.floor
	}
	if ok {
		points: [game.MAX_SHOTS]flow.Trail_Point
		count := flow.trail_points(&f.trails, &frame.state, f.epoch, points[:])
		for point in points[:count] {
			feedback_ember(
				self,
				{epoch = f.epoch, tick = frame.tick, source = point.source, key = 0x200},
				point.position,
			)
		}
	}
	now := gd.time_get_ticks_msec(gd.singleton_time())
	for &e in f.embers {
		if e.node != nil {
			age := f32(now - e.born) / 1000
			if age >= 0.4 {
				feedback_remove(e.node)
				e = {}
				continue
			}
			gd.canvas_item_set_modulate(e.node, {1, 1, 1, 1 - age / 0.4})
		}
	}
	for &b in f.bursts {
		if b.node != nil && now - b.born >= 800 {
			feedback_remove(b.node)
			b = {}
		}
	}
	for &n in f.floats {
		if n.node != nil {
			age := f32(now - n.born) / 1000
			if age >= 0.9 {
				feedback_remove(n.node)
				n = {}
				continue
			}
			gd.control_set_position(n.node, n.position + [2]f32{0, -46 * age}, false)
			gd.canvas_item_set_modulate(n.node, {1, 1, 1, min((0.9 - age) / 0.54, 1)})
		}
	}
	for &d in f.debris {
		if d.node != nil {
			age := f32(now - d.born) / 1000
			if age >= 0.55 {
				feedback_remove(d.node)
				d = {}
				continue
			}
			gd.node2d_set_position(d.node, d.position + d.velocity * age + [2]f32{0, 140 * age * age})
			gd.node2d_set_rotation(d.node, gd.Float(d.spin + age * 8))
			gd.canvas_item_set_modulate(d.node, {1, 1, 1, 1 - age / 0.55})
		}
	}
	for &s in f.sparks {
		if s.node != nil {
			age := f32(now - s.born) / 1000
			if age >= 0.3 {
				feedback_remove(s.node)
				s = {}
				continue
			}
			gd.node2d_set_position(s.node, s.position + s.velocity * age)
			gd.canvas_item_set_modulate(s.node, {1, 1, 1, 1 - age / 0.3})
		}
	}
	for &w in f.wounds {
		if w.node != nil {
			age := f32(now - w.born) / 1000
			if age >= 0.55 {
				feedback_remove(w.node)
				w = {}
				continue
			}
			gd.canvas_item_set_modulate(w.node, {1, 1, 1, 1 - age / 0.55})
		}
	}
}

@(gd_method)
replay_scrapyard_feedback_probe :: proc(self: ^ReplayScrapyard, key: string) -> gd.Int {
	f := &self.feedback[0]
	count := 0
	switch key {
	case "bursts":
		for b in f.bursts {
			if b.node != nil {
				count += 1
			}
		}
	case "floats":
		for n in f.floats {
			if n.node != nil {
				count += 1
			}
		}
	case "debris":
		for d in f.debris {
			if d.node != nil {
				count += 1
			}
		}
	case "embers":
		for e in f.embers {
			if e.node != nil {
				count += 1
			}
		}
	case "trail_dropped":
		return gd.Int(f.trails.dropped)
	case "sparks":
		for s in f.sparks {
			if s.node != nil {
				count += 1
			}
		}
	case "wounds":
		for w in f.wounds {
			if w.node != nil {
				count += 1
			}
		}
	case "wound_missing":
		return gd.Int(f.wound_missing)
	case "active":
		for b in f.bursts {
			if b.node != nil {
				count += 1
			}
		}
		for n in f.floats {
			if n.node != nil {
				count += 1
			}
		}
		for d in f.debris {
			if d.node != nil {
				count += 1
			}
		}
		for w in f.wounds {
			if w.node != nil {
				count += 1
			}
		}
		for s in f.sparks {
			if s.node != nil {
				count += 1
			}
		}
		for e in f.embers {
			if e.node != nil {
				count += 1
			}
		}
	case "wrong_epoch":
		for b in f.bursts {
			if b.node != nil && b.id.epoch != f.epoch {
				count += 1
			}
		}
		for n in f.floats {
			if n.node != nil && n.id.epoch != f.epoch {
				count += 1
			}
		}
		for d in f.debris {
			if d.node != nil && d.id.epoch != f.epoch {
				count += 1
			}
		}
		for w in f.wounds {
			if w.node != nil && w.id.epoch != f.epoch {
				count += 1
			}
		}
		for s in f.sparks {
			if s.node != nil && s.id.epoch != f.epoch {
				count += 1
			}
		}
		for e in f.embers {
			if e.node != nil && e.id.epoch != f.epoch {
				count += 1
			}
		}
	case "spawned":
		return gd.Int(f.spawned)
	case "dropped":
		return gd.Int(f.dropped)
	case "duplicates":
		return gd.Int(f.duplicates)
	case "canceled":
		return gd.Int(f.canceled)
	case:
		return -1
	}
	return gd.Int(count)
}
