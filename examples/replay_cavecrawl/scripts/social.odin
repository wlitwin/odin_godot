package replay_cavecrawl
import "core:fmt"
import "core:strings"
import gd "godot:godot"
import co "godot:replay/comms"
import rgd "godot:replay/godot"
import p "godot:replay/play"
import game "../shared/cave"
import lb "godot:replay/lobby"
import dg "godot:replay/telemetry"
import inputgd "godot:replay/godot/input"

Cave_Mark :: struct {
    node:    gd.Node2d,
    expires: u64,
    depth:   u8,
    scope:   co.Scope,
    run:     u32,
}

social_ready :: proc(self: ^ReplayCave) {
    inputgd.bind_key("rc_chat", .Enter)
    inputgd.bind_key("rc_scores", .Tab)
    inputgd.bind_key("rc_ping", .F)
    gd.connect_to(self.chat_input, "text_submitted", self.owner, "on_chat")

    for row in 0 ..< game.SEATS {
        for column in 0 ..< 8 {
            self.score_cells[row][column] = cast(gd.Label)gd.get_node(
                self.owner,
                fmt.ctprintf("Social/Scoreboard/Column/Grid/Row%d_%d", row, column),
            )
        }
    }
}

social_input :: proc(self: ^ReplayCave) -> bool {
    focused := bool(gd.control_has_focus(self.chat_input, false))

    if gd.is_action_just_released("rc_scores") {
        replay_cave_show_score(self, false)
    }

    if self.chat_submitted {
        self.chat_submitted = false
        return true
    }

    if gd.control_has_focus(self.lobby_name, false) {
        if gd.is_action_just_pressed("ui_cancel") {
            gd.control_release_focus(self.lobby_name)
        }

        return true
    }

    if focused {
        if gd.is_action_just_pressed("ui_cancel") {
            gd.control_release_focus(self.chat_input)
        }

        return true
    }

    if gd.is_action_just_pressed("rc_chat") {
        gd.control_grab_focus(self.chat_input, false)
        return true
    }

    if gd.is_action_just_pressed("rc_scores") {
        replay_cave_show_score(self, true)
    }

    if gd.is_action_just_pressed("rc_ping") {
        replay_cave_mark(self)
    }

    return false
}

@(gd_method)
replay_cave_on_chat :: proc(self: ^ReplayCave, text: string) {
    result := co.say(&self.comms, text)
    self.chat_submitted = true

    if result == .None {
        gd.set_string(self.chat_input, "text", "")
        gd.control_release_focus(self.chat_input)
        gd.set_string(self.chat_notice, "text", "")
    } else {
        gd.set_string(self.chat_notice, "text", fmt.ctprintf("Chat not sent: %v", result))
    }
}

@(gd_method)
replay_cave_show_score :: proc(self: ^ReplayCave, visible: bool) {
    self.score_open = visible
    gd.canvas_item_set_visible(self.score_panel, visible)
}

@(gd_method)
replay_cave_mark :: proc(self: ^ReplayCave) {
    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 {
        return
    }

    position := frame.state.players[seat - 1].position
    co.mark(&self.comms, u32(frame.state.depth), {position[0], position[1], 0})
}

social_paint :: proc(self: ^ReplayCave) {
    if self.chat_revision != self.comms.history_serial {
        builder: strings.Builder
        defer strings.builder_destroy(&builder)
        first := max(0, self.comms.line_count - 4)

        for entry, i in self.comms.lines[first:self.comms.line_count] {
            line := entry

            if i > 0 {
                strings.write_string(&builder, "\n")
            }

            if line.value.kind == .System {
                fmt.sbprintf(&builder, "* %s", string(line.value.text[:line.value.length]))
            } else {
                label :=
                    line.name.length > 0 ? lb.text(&line.name) : line.seat == 0 ? "Observer" : fmt.tprintf("Seat %d", line.seat)
                fmt.sbprintf(&builder, "%s: %s", label, string(line.value.text[:line.value.length]))
            }
        }

        gd.set_string(self.chat_lines, "text", fmt.ctprintf("%s", strings.to_string(builder)))
        self.chat_revision = self.comms.history_serial
    }

    for {
        receipt, found := co.poll_result(&self.comms)

        if !found {
            break
        }

        if receipt.result != .None {
            gd.set_string(
                self.chat_notice,
                "text",
                fmt.ctprintf("Message %d not sent: %v", receipt.submission, receipt.result),
            )
        }
    }

    now := gd.time_get_ticks_msec(gd.singleton_time())

    // Scope and wall-clock expiry do not depend on an available gameplay frame.
    // During migration the new scope can precede the first resumed snapshot.
    for &mark in self.marks {
        if mark.node != nil && (now >= mark.expires || mark.scope != self.comms.scope) {
            gd.node_queue_free(mark.node)
            mark = {}
        }
    }

    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return
    }

    w := frame.state

    for &mark in self.marks {
        if mark.node != nil && (mark.depth != w.depth || mark.run != w.lobby.run) {
            gd.node_queue_free(mark.node)
            mark = {}
        }
    }

    for {
        entry, found := co.poll_marker(&self.comms)

        if !found {
            break
        }

        if entry.value.tag != u32(w.depth) {
            continue
        }

        position := entry.value.position

        if position[0] < 0 || position[0] > 640 || position[1] < 0 || position[1] > 370 {
            continue
        }

        self.mark_received += 1

        for &mark in self.marks {
            if mark.node == nil {
                mark.node = gd.new_node2d()
                mark.expires = now + 2500
                mark.depth = w.depth
                mark.scope = self.comms.scope
                mark.run = w.lobby.run
                gd.add_child(self.stage, mark.node)
                gd.node2d_set_position(mark.node, {position[0], position[1]})
                triangle := gd.new_polygon2d()
                gd.add_child(mark.node, triangle)
                points := gd.new_packed_vector2_array()
                gd.packed_vector2_array_append(&points, {-6, -18})
                gd.packed_vector2_array_append(&points, {6, -18})
                gd.packed_vector2_array_append(&points, {0, -7})
                gd.polygon2d_set_polygon(triangle, points)
                gd.free_packed_vector2_array(points)
                label := gd.new_label()
                gd.add_child(mark.node, label)
                gd.set_string(label, "name", "CavePingName")
                name := entry.name.length > 0 ? lb.text(&entry.name) : fmt.tprintf("Seat %d", entry.seat)
                gd.set_string(label, "text", fmt.ctprintf("%s", name))
                gd.control_set_position(label, {8, -24}, false)
                gd.canvas_item_set_modulate(mark.node, {1, 0.85, 0.2, 1})
                gd.canvas_item_set_z_index(mark.node, 15)
                break
            }
        }
    }

    if self.score_open {
        for player, row in w.players {
            for cell in self.score_cells[row] {
                gd.canvas_item_set_visible(cell, player.connected)
            }

            if !player.connected {
                continue
            }

            gd.set_string(self.score_cells[row][0], "text", fmt.ctprintf("%s", lb.text(&w.lobby.names[row])))
            bag := player.bag
            values := [6]u32 {
                player.kills,
                player.deaths,
                player.damage,
                player.slain,
                p.inventory_count(bag[:], game.GEM),
                u32(player.hp),
            }

            for value, column in values {
                gd.set_string(self.score_cells[row][column + 1], "text", fmt.ctprintf("%d", value))
            }

            ping := dg.read(&self.diagnostics, u16(row + 1))
            gd.set_string(self.score_cells[row][7], "text", ping.known ? fmt.ctprintf("%d", ping.round_trip_ms) : "--")
        }
    }
}

@(gd_method)
replay_cave_social_probe :: proc(self: ^ReplayCave, key: string) -> gd.Int {
    switch key {
    case "ready":
        return gd.Int(self.comms.enabled)
    case "lines":
        return gd.Int(self.comms.line_count)
    case "marks":
        return gd.Int(self.mark_received)
    case "active_marks":
        count := 0

        for mark in self.marks {
            if mark.node != nil {
                count += 1
            }
        }

        return gd.Int(count)
    case "pending":
        return gd.Int(self.comms.pending_count)
    case "rejected":
        return gd.Int(self.comms.rejected)
    }

    return -1
}
