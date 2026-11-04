package replay_scrapyard

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import rgd "godot:replay/godot"
import co "godot:replay/comms"
import lb "godot:replay/lobby"
import game "../shared/game"
import flow "../shared/flow"
import inputgd "godot:replay/godot/input"

Scrap_Social :: struct {
    comms: co.Comms,
    revision: u64,
    submitted: bool,
    news_ready: bool,
    news_scope: co.Scope,
    news_tick, news_gaps: u64,
    news_state: flow.News_State,
    news: [64]co.Payload,
    news_count: int,
    pings: [32]Ping_Rig,
    ping_scope: co.Scope,
    ping_received, ping_rejected: u64,
}

social_ready :: proc(self: ^ReplayScrapyard) -> bool {
    if !co.init(&self.social[0].comms) {
        return false
    }

    inputgd.bind_key("rsy_chat", .Enter)
    inputgd.bind_mouse("rsy_ping", .Middle)
    self.ping_root = gd.new_node2d()
    scenery_name(self.ping_root, "Pings")
    gd.add_child(self.world_node, self.ping_root)
    gd.connect_to(self.chat_input, "text_submitted", self.owner, "on_chat")
    gd.rich_text_label_set_use_bbcode(self.chat_lines, false)
    return true
}

social_input :: proc(self: ^ReplayScrapyard) -> bool {
    if self.menu_input_guard {
        return true
    }

    s := &self.social[0]

    if s.submitted {
        s.submitted = false
        return true
    }

    if gd.control_has_focus(self.chat_input, false) {
        if gd.is_action_just_pressed("rsy_menu") {
            gd.control_release_focus(self.chat_input)
        }

        return true
    }

    if !self.menu_open && s.comms.enabled && gd.is_action_just_pressed("rsy_chat") {
        gd.control_grab_focus(self.chat_input, false)
        return true
    }

    return false
}

social_wants_mouse :: proc(self: ^ReplayScrapyard) -> bool {
    if !gd.canvas_item_is_visible_in_tree(self.chat_panel) {
        return false
    }

    point := gd.canvas_item_get_local_mouse_position(self.chat_panel)
    size := gd.control_get_size(self.chat_panel)
    return point.x >= 0 && point.y >= 0 && point.x <= size.x && point.y <= size.y
}

@(gd_method)
replay_scrapyard_on_chat :: proc(self: ^ReplayScrapyard, text: string) {
    s := &self.social[0]
    result := co.say(&s.comms, text)
    s.submitted = true

    if result == .None {
        gd.set_string(self.chat_input, "text", "")
        gd.control_release_focus(self.chat_input)
        gd.set_string(self.chat_notice, "text", "")
    } else {
        gd.set_string(self.chat_notice, "text", fmt.ctprintf("Chat not sent: %v", result))
    }
}

social_news_flush :: proc(s: ^Scrap_Social) {
    for s.news_count > 0 {
        line := s.news[0]

        if co.system(&s.comms, string(line.text[:line.length])) != .None {
            return
        }

        s.news_count -= 1
        copy(s.news[:], s.news[1:s.news_count + 1])
    }
}

social_news :: proc(self: ^ReplayScrapyard) {
    s := &self.social[0]

    if !self.session.authority || !s.comms.enabled {
        return
    }

    timeline := &self.session.server.timeline

    if !s.news_ready || s.news_scope != s.comms.scope {
        frame, ok := r.read(timeline, timeline.confirmed)

        if !ok {
            return
        }

        s.news_ready, s.news_scope, s.news_tick, s.news_state =
            true, s.comms.scope, frame.tick, flow.news_state(&frame.state)
        s.news_count = 0

        if self.room.ready && self.room.migrations > 0 {
            s.news[0], _ = co.text_payload("the keeper is gone — the yard has a new one", true)
            s.news_count = 1
        }
    }

    social_news_flush(s)

    // Reserve one complete tick batch before advancing its observation frontier.
    for _ in 0 ..< 32 {
        if s.news_tick >= timeline.confirmed || len(s.news) - s.news_count < flow.NEWS_BATCH {
            break
        }

        next := s.news_tick + 1
        frame, ok := r.read(timeline, next)

        if !ok {
            // Keep the owned fallback read separate: assigning a multi-result
            // full frame can lower to tens of thousands of scalar WASM locals.
            latest, available := r.read(timeline, timeline.confirmed)

            if !available {
                break
            }

            s.news[s.news_count], _ = co.text_payload("older yard updates were skipped while chat caught up", true)
            s.news_count += 1
            s.news_gaps += 1
            s.news_tick, s.news_state = latest.tick, flow.news_state(&latest.state)
            break
        }

        state := flow.news_state(&frame.state)
        lines, count := flow.news_lines(s.news_state, state)
        copy(s.news[s.news_count:], lines[:count])
        s.news_count += count
        s.news_state, s.news_tick = state, next
    }

    social_news_flush(s)
}

// Pump outside the simulation and even during fenced/reconnect frames.
social_frame :: proc(self: ^ReplayScrapyard) {
    s := &self.social[0]
    frame, ok := rgd.session_authority_state(self.session)
    names: [game.SEATS]lb.Name

    if ok {
        for p, i in frame.state.players {
            names[i] = flow.news_name(p.profile.name, i + 1)
        }
    }

    observer_name: lb.Name

    if self.session.role == .Observer {
        value := gd.line_edit_get_text(self.name_edit)
        observer_name, _ = lb.name(gd.gd_string_to_odin(value))
        gd.free_string(value)
    }

    rgd.session_comms_frame(&s.comms, self.session, ok ? names[:] : nil, observer_name)
    social_news(self)

    for {
        receipt, found := co.poll_result(&s.comms)

        if !found {
            break
        }

        if receipt.result != .None {
            gd.set_string(
                self.chat_notice,
                "text",
                fmt.ctprintf("%s not sent: %v", receipt.value.kind == .Marker ? "Ping" : "Message", receipt.result),
            )
            // Restore the failed text when the user has not begun another message.
            value := gd.line_edit_get_text(self.chat_input)
            defer gd.free_string(value)

            if receipt.value.kind == .Say && gd.string_length(&value) == 0 {
                gd.set_string(
                    self.chat_input,
                    "text",
                    fmt.ctprintf("%s", string(receipt.value.text[:receipt.value.length])),
                )
            }
        }
    }

    pings_frame(self, ok ? &frame.state : nil)
    gd.canvas_item_set_visible(self.chat_panel, s.comms.bound)
    gd.line_edit_set_editable(self.chat_input, s.comms.enabled && !self.menu_open)
    width := f32(360)

    if gd.canvas_item_is_visible_in_tree(self.lobby) {
        width = min(width, max(f32(120), gd.control_get_global_rect(self.lobby).position.x - 16))
    }

    gd.control_set_offset(self.chat_panel, .Right, gd.Float(8 + width))
    climb := ok && frame.state.stage == .Clear ? gd.control_get_size(self.shop).y + 30 : f32(0)
    gd.control_set_offset(self.chat_panel, .Top, gd.Float(-174 - climb))
    gd.control_set_offset(self.chat_panel, .Bottom, gd.Float(-30 - climb))

    if s.revision != s.comms.history_serial {
        builder: strings.Builder
        defer strings.builder_destroy(&builder)

        for entry, i in s.comms.lines[:s.comms.line_count] {
            line := entry

            if i > 0 {
                strings.write_string(&builder, "\n")
            }

            if line.value.kind == .System {
                fmt.sbprintf(&builder, "* %s", string(line.value.text[:line.value.length]))
            } else {
                name :=
                    line.name.length > 0 ? lb.text(&line.name) : line.seat == 0 ? "Observer" : fmt.tprintf("runner %d", line.seat)
                fmt.sbprintf(
                    &builder,
                    "%s%s: %s",
                    name,
                    line.seat == 0 && line.name.length > 0 ? " (observer)" : "",
                    string(line.value.text[:line.value.length]),
                )
            }
        }

        gd.set_string(self.chat_lines, "text", fmt.ctprintf("%s", strings.to_string(builder)))
        s.revision = s.comms.history_serial
    }
}

@(gd_method)
replay_scrapyard_chat_probe :: proc(self: ^ReplayScrapyard, key: string) -> gd.Int {
    s := &self.social[0]

    switch key {
    case "ready":
        return gd.Int(s.comms.enabled)
    case "named_observer":
        return gd.Int(s.comms.local.spectator && s.comms.local.observer_name_allowed)
    case "lines":
        return gd.Int(s.comms.line_count)
    case "pending":
        return gd.Int(s.comms.pending_count)
    case "rejected":
        return gd.Int(s.comms.rejected)
    case "sequence":
        return gd.Int(s.comms.last_id.sequence)
    case "history_serial":
        return gd.Int(s.comms.history_serial)
    case "display_revision":
        return gd.Int(s.revision)
    case "scope_drops":
        return gd.Int(s.comms.scope_drops)
    case "duplicates":
        return gd.Int(s.comms.duplicates)
    case "result":
        return gd.Int(s.comms.last_result)
    case "outbox":
        count := 0

        for peer in s.comms.peers {
            count += peer.count
        }

        return gd.Int(count)
    case "news_gaps":
        return gd.Int(s.news_gaps)
    case "typing":
        return gd.Int(gd.control_has_focus(self.chat_input, false))
    case "pings":
        return gd.Int(s.ping_received)
    case "ping_rejected":
        return gd.Int(s.ping_rejected)
    case "active_pings":
        count := 0

        for rig in s.pings {
            if rig.node != nil {
                count += 1
            }
        }

        return gd.Int(count)
    }

    return -1
}
