package replay_scrapyard

import "core:fmt"
import "core:math"
import gd "godot:godot"
import rgd "godot:replay/godot"
import co "godot:replay/comms"
import lb "godot:replay/lobby"
import game "../shared/game"
import flow "../shared/flow"
import scenegd "godot:replay/godot/scene"

Ping_Rig :: struct {
	node: gd.Node2d,
	diamond: gd.Mesh_Instance2d,
	label: gd.Label,
	born: u64,
	run: u32,
	floor: u8,
}

PING_MS :: u64(2600)

@(gd_method)
replay_scrapyard_ping :: proc(self: ^ReplayScrapyard, x, y: gd.Float) -> bool {
	if self.menu_open || gd.control_has_focus(self.chat_input, false) {
		return false
	}
	frame, ok := rgd.session_authority_state(self.session)
	seat := rgd.session_seat(self.session)
	if !ok || seat == 0 || !frame.state.players[seat - 1].in_yard {
		return false
	}
	payload := flow.ping_payload(&frame.state, {f32(x), f32(y)})
	if !flow.ping_valid(&frame.state, payload) {
		return false
	}
	result := co.mark(&self.social[0].comms, payload.tag, payload.position)
	if result != .None {
		gd.set_string(self.chat_notice, "text", fmt.ctprintf("Ping not sent: %v", result))
	}
	return result == .None
}

ping_remove :: proc(rig: ^Ping_Rig) {
	if rig.node != nil {
		gd.node_remove_child(gd.node_get_parent(rig.node), rig.node)
		gd.node_queue_free(rig.node)
	}
	rig^ = {}
}

pings_frame :: proc(self: ^ReplayScrapyard, world: ^game.World) {
	s := &self.social[0]
	now := gd.time_get_ticks_msec(gd.singleton_time())
	changed := s.ping_scope != s.comms.scope
	s.ping_scope = s.comms.scope
	for &rig in s.pings {
		if rig.node == nil {
			continue
		}
		if changed || world == nil || rig.run != world.run || rig.floor != world.floor || now - rig.born >= PING_MS {
			ping_remove(&rig)
			continue
		}
		age := f32(now - rig.born) / 1000
		scale := 1 + math.sin(age * 7) * 0.3
		gd.node2d_set_scale(rig.diamond, {scale, scale})
		gd.canvas_item_set_modulate(rig.diamond, {1, 1, 1, 1 - age / 2.6 * 0.7})
		gd.canvas_item_set_visible(rig.label, age < 0.9)
		gd.control_set_position(rig.label, {-12, -22 - age * 46}, false)
		gd.canvas_item_set_modulate(rig.label, {1, 1, 1, clamp((0.9 - age) / 0.54, 0, 1)})
	}
	for {
		entry, found := co.poll_marker(&s.comms)
		if !found {
			break
		}
		if world == nil || entry.seat == 0 || !flow.ping_valid(world, entry.value) {
			s.ping_rejected += 1
			continue
		}
		slot := -1
		for rig, i in s.pings {
			if rig.node == nil {
				slot = i
				break
			}
		}
		if slot < 0 {
			s.ping_rejected += 1
			continue
		}
		rig := &s.pings[slot]
		rig.node = gd.new_node2d()
		scenery_name(rig.node, fmt.tprintf("Ping%d", slot))
		gd.add_child(self.ping_root, rig.node)
		position := [2]f32{entry.value.position[0], entry.value.position[1]}
		gd.node2d_set_position(rig.node, position)
		gd.canvas_item_set_z_index(rig.node, 28)
		rig.diamond = gd.new_mesh_instance2d()
		gd.add_child(rig.node, rig.diamond)
		points := gd.new_packed_vector2_array()
		for p in ([4]gd.Vector2{{0, -9}, {7, 0}, {0, 9}, {-7, 0}}) {
			gd.packed_vector2_array_append(&points, p)
		}
		scenegd.mesh2_polygon(rig.diamond, points)
		gd.free_packed_vector2_array(points)
		gd.canvas_item_set_self_modulate(rig.diamond, {1, 0.85, 0.25, 0.95})
		rig.label = gd.new_label()
		scenery_name(rig.label, "Name")
		gd.add_child(rig.node, rig.label)
		name := entry.name
		gd.set_string(rig.label, "text", fmt.ctprintf("%s", lb.text(&name)))
		gd.control_set_position(rig.label, {-12, -22}, false)
		gd.control_set_mouse_filter(rig.label, .Mouse_Filter_Ignore)
		gd.canvas_item_set_modulate(rig.label, {1, 0.9, 0.5, 1})
		rig.born, rig.run, rig.floor = now, world.run, world.floor
		s.ping_received += 1
		audio_direct(self, {kind = .Ping, position = position, spatial = true})
	}
}
