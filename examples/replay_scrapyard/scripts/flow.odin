package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import game "../shared/game"
import rgd "godot:replay/godot"
import dg "godot:replay/telemetry"

flow_ready :: proc(self: ^ReplayScrapyard) {
	recording_ready(self)
	rgd.bind_key("rsy_menu", .Escape)
	rgd.bind_key("rsy_tally", .Tab)
	for row in 0 ..< game.SEATS {
		for column in 0 ..< 8 {
			self.tally_cells[row][column] = cast(gd.Label)gd.get_node(
				self.owner,
				fmt.ctprintf("UI/Tally/Column/Grid/Row%d_%d", row, column),
			)
		}
	}
	gd.connect_to(gd.get_node(self.owner, "UI/Menu/Scroll/Column/Resume"), "pressed", self.owner, "on_resume_menu")
	gd.connect_to(gd.get_node(self.owner, "UI/Menu/Scroll/Column/Quit"), "pressed", self.owner, "on_quit_menu")
	gd.connect_to(gd.get_node(self.owner, "UI/Menu/Scroll/Column/Save"), "pressed", self.owner, "on_save_menu")
	gd.connect_to(gd.get_node(self.owner, "UI/Menu/Scroll/Column/Spray"), "pressed", self.owner, "on_spray_pick")
}

@(gd_method)
replay_scrapyard_on_menu :: proc(self: ^ReplayScrapyard) {
	flow_menu_set(self, !self.menu_open)
}

flow_menu_set :: proc(self: ^ReplayScrapyard, open: bool) {
	self.menu_open = open
	gd.canvas_item_set_visible(self.menu_panel, open)
	gd.canvas_item_set_visible(self.menu_veil, open)
	if open {
		gd.control_grab_focus(cast(gd.Control)gd.get_node(self.owner, "UI/Menu/Scroll/Column/Resume"), false)
	} else {
		gd.viewport_gui_release_focus(gd.node_get_viewport(self.owner))
		self.menu_input_guard = true
	}
}

@(gd_method)
replay_scrapyard_on_resume_menu :: proc(self: ^ReplayScrapyard) {
	flow_menu_set(self, false)
}

@(gd_method)
replay_scrapyard_on_quit_menu :: proc(self: ^ReplayScrapyard) {
	gd.print_str("RSY_MENU_QUIT")
	path := gd.new_string_cstring("res://closed.tscn")
	defer gd.free_string(path)
	if gd.scene_tree_change_scene_to_file(gd.node_get_tree(self.owner), path) != gd.Error(0) {
		flow_note(self, "Could not leave the yard.")
	}
}

@(gd_method)
replay_scrapyard_on_save_menu :: proc(self: ^ReplayScrapyard) {
	replay_scrapyard_save_run(self)
}

flow_input :: proc(self: ^ReplayScrapyard, typing: bool) {
	// Release still reaches the tally when chat owns keyboard focus.
	if gd.is_action_just_released("rsy_tally") {
		self.tally_open = false
	}
	if typing {
		return
	}
	if gd.is_action_just_pressed("rsy_menu") {
		replay_scrapyard_on_menu(self)
	}
	if gd.is_action_just_pressed("rsy_tally") {
		self.tally_open = true
		if !self.menu_open {
			gd.viewport_gui_release_focus(gd.node_get_viewport(self.owner))
		}
	}
}

flow_note :: proc(self: ^ReplayScrapyard, text: cstring) {
	gd.set_string(self.notice_label, "text", text)
	self.notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 4000
	gd.canvas_item_set_visible(self.notice_label, true)
}

flow_paint :: proc(self: ^ReplayScrapyard, w: ^game.World) {
	gd.canvas_item_set_visible(self.menu_panel, self.menu_open)
	gd.canvas_item_set_visible(self.menu_veil, self.menu_open)
	gd.canvas_item_set_visible(self.tally_panel, self.tally_open)
	gd.canvas_item_set_visible(self.notice_label, gd.time_get_ticks_msec(gd.singleton_time()) < self.notice_until)
	if self.tally_open {
		for player, row in w.players {
			for label in self.tally_cells[row] {
				gd.canvas_item_set_visible(label, player.connected)
			}
			if !player.connected {
				continue
			}
			p := player
			gd.set_string(self.tally_cells[row][0], "text", fmt.ctprintf("%s", game.name_string(&p.profile.name)))
			values := [5]u32{p.kills, p.damage, p.healed, p.scrap, p.cores}
			for value, column in values {
				gd.set_string(self.tally_cells[row][column + 1], "text", fmt.ctprintf("%d", value))
			}
			// The original registers deaths but never credits player downs as deaths.
			gd.set_string(self.tally_cells[row][6], "text", "0")
			ping := dg.read(&self.diagnostics[0], u16(row + 1))
			gd.set_string(self.tally_cells[row][7], "text", ping.known ? fmt.ctprintf("%d", ping.round_trip_ms) : "--")
		}
	}
	if self.menu_open {
		seat := rgd.session_seat(self.session)
		gd.texture_rect_set_texture(self.spray_preview, seat > 0 ? self.spray_rigs[seat - 1].texture : nil)
		button := cast(gd.Base_Button)gd.get_node(self.owner, "UI/Menu/Scroll/Column/Save")
		gd.base_button_set_disabled(
			button,
			!self.session.ready ||
			!self.session.authority ||
			(self.room.ready &&
					(!self.online.enabled ||
							self.room.save.phase == .Checking ||
							self.room.save.phase == .Uploading)) ||
			self.saved_run[0].phase != .Idle,
		)
	}
}
