package replay_claimball

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import lb "godot:replay/lobby"
import net "godot:replay/net"
import game "../shared/pitch"
import debuggd "godot:replay/godot/debug"
import inputgd "godot:replay/godot/input"
import scenegd "godot:replay/godot/scene"

Claimball_UI :: struct {
    lobby, score_panel:                       gd.Control,
    name, address, chat_input, save_path:     gd.Line_Edit,
    port:                                     gd.Spin_Box,
    notice, roster, chat_notice, save_notice: gd.Label,
    chat_lines:                               gd.Rich_Text_Label,
    start, leave, again, save:                gd.Button,
    doors:                                    [4]gd.Button,
    resume:                                   [2]gd.Button,
    cells:                                    [game.SEATS][3]gd.Label,
    revision:                                 u64,
    round_seen:                               u32,
    submitted, was_playing, announce_host:    bool,
}

ui_notice :: proc(self: ^ReplayClaimball, text: string) {
    gd.set_string(self.ui[0].notice, "text", fmt.ctprintf("%s", text))
}

ui_ready :: proc(self: ^ReplayClaimball) {
    u := &self.ui[0]
    u.lobby = cast(gd.Control)gd.get_node(self.owner, "UI/Lobby")
    u.save_path = cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Lobby/Column/Saved/Path")
    u.save_notice = cast(gd.Label)gd.get_node(self.owner, "UI/SaveNotice")
    u.save = cast(gd.Button)gd.get_node(self.owner, "UI/Save")
    gd.connect_to(u.save, "pressed", self.owner, "on_save")

    for label, i in ([2]cstring{"Solo", "Host"}) {
        u.resume[i] = cast(gd.Button)gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Column/Resume/%s", label))
    }

    gd.connect_to(u.resume[0], "pressed", self.owner, "on_resume_solo")
    gd.connect_to(u.resume[1], "pressed", self.owner, "on_resume_host")
    gd.set_string(
        u.save_path,
        "text",
        fmt.ctprintf(
            "%s",
            gd.IS_WEB ? claimball_param("RCB_SAVE_SLOT", "pitch") : claimball_param("RCB_SAVE", "user://claimball.replay"),
        ),
    )
    inputgd.bind_key("rcb_save", .F5)
    u.name = cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Lobby/Column/Name/Value")
    u.address = cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Lobby/Column/Address/Value")
    u.port = cast(gd.Spin_Box)gd.get_node(self.owner, "UI/Lobby/Column/Address/Port")
    u.notice = cast(gd.Label)gd.get_node(self.owner, "UI/Lobby/Column/Notice")
    u.roster = cast(gd.Label)gd.get_node(self.owner, "UI/Lobby/Column/Roster")
    u.start = cast(gd.Button)gd.get_node(self.owner, "UI/Lobby/Column/Start")
    u.leave = cast(gd.Button)gd.get_node(self.owner, "UI/Leave")
    u.again = cast(gd.Button)gd.get_node(self.owner, "UI/Again")
    gd.connect_to(u.again, "pressed", self.owner, "on_again")
    gd.connect_to(gd.get_node(self.owner, "UI/Handoff"), "pressed", self.owner, "handoff")
    u.chat_input = cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Chat/Column/Input")
    u.chat_lines = cast(gd.Rich_Text_Label)gd.get_node(self.owner, "UI/Chat/Column/Lines")
    u.chat_notice = cast(gd.Label)gd.get_node(self.owner, "UI/Chat/Column/Notice")
    u.score_panel = cast(gd.Control)gd.get_node(self.owner, "UI/Scoreboard")
    grid := gd.get_node(self.owner, "UI/Scoreboard/Column/Grid")

    for title in ([3]cstring{"PLAYER", "TEAM", "PING"}) {
        label := gd.new_label()
        gd.add_child(grid, label)
        gd.set_string(label, "text", title)
    }

    for row in 0 ..< game.SEATS {
        for column in 0 ..< 3 {
            label := gd.new_label()
            gd.add_child(grid, label)
            u.cells[row][column] = label
            gd.control_set_custom_minimum_size(label, {column == 0 ? 160 : 70, 0})
            gd.label_set_clip_text(label, true)
        }
    }

    for label, i in ([4]cstring{"Solo", "Host", "Join", "Watch"}) {
        u.doors[i] = cast(gd.Button)gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Column/Buttons/%s", label))
    }

    for method, i in ([4]cstring{"on_solo", "on_host", "on_join", "on_watch"}) {
        gd.connect_to(u.doors[i], "pressed", self.owner, method)
    }

    gd.connect_to(u.start, "pressed", self.owner, "on_start")
    gd.connect_to(u.leave, "pressed", self.owner, "on_leave")
    gd.connect_to(u.chat_input, "text_submitted", self.owner, "on_chat")
    inputgd.bind_key("rcb_chat", .Enter)
    inputgd.bind_key("rcb_scores", .Tab)
    profile_ready(self)
    gd.set_string(u.address, "text", fmt.ctprintf("%s", claimball_param("RCB_ADDRESS", "127.0.0.1")))
    gd.range_set_value(u.port, f64(claimball_int("RCB_PORT", 49490)))
    gd.rich_text_label_set_use_bbcode(u.chat_lines, false)
    ui_frame(self)
}

@(gd_method)
replay_claimball_on_solo :: proc(self: ^ReplayClaimball) {
    connect_pitch(self, "solo", false)
}

@(gd_method)
replay_claimball_on_host :: proc(self: ^ReplayClaimball) {
    if self.online.enabled {
        online_begin(self, .Create)
    } else {
        connect_pitch(self, "host", true)
    }
}

@(gd_method)
replay_claimball_on_join :: proc(self: ^ReplayClaimball) {
    if self.online.enabled {
        online_begin(self, .Join)
    } else {
        connect_pitch(self, "client", true)
    }
}

@(gd_method)
replay_claimball_on_watch :: proc(self: ^ReplayClaimball) {
    if self.online.enabled {
        online_begin(self, .Join, true)
    } else {
        connect_pitch(self, "observer", true)
    }
}

@(gd_method)
replay_claimball_on_start :: proc(self: ^ReplayClaimball) {
    if !self.ready {
        return
    }

    _, err := issue(self, game.Action{start = true})

    if err != .None {
        ui_notice(self, fmt.tprintf("Could not start: %v", err))
    }
}

@(gd_method)
replay_claimball_on_again :: proc(self: ^ReplayClaimball) {
    frame, ok := rgd.session_authority_state(self.session)

    if !self.ready || !ok {
        return
    }

    _, err := issue(self, game.Action{restart_round = frame.state.round})

    if err != .None {
        gd.set_string(self.ui[0].chat_notice, "text", fmt.ctprintf("Could not restart: %v", err))
    }
}

@(gd_method)
replay_claimball_on_leave :: proc(self: ^ReplayClaimball) {
    if !self.ready {
        return
    }

    when gd.IS_WEB {
        if !self.room.ready && self.browser_save[0].slot.phase == .Writing {
            gd.set_string(self.ui[0].save_notice, "text", "Saving… wait before leaving.")
            return
        }
    }

    close_session(self)
    co.destroy(&self.comms)
    dg.destroy(&self.diagnostics)
    co.init(&self.comms)
    dg.init(&self.diagnostics)
    self.ready, self.done, self.spiked, self.spike_visible, self.own_spike_seen, self.spike_node_start =
        false, false, false, false, false, false
    self.name_submitted = false
    self.name_sequence, self.last_verdict, self.reset_seen, self.correction_seen = 0, 0, 0, 0
    self.saved_tick, self.saved_hash, self.restored_tick, self.restored_hash = 0, 0, 0, 0
    self.restored_exact = false
    gd.set_string(self.ui[0].save_notice, "text", "")
    self.view_round, self.paint_round, self.ui[0].round_seen = 0, 0, 0
    self.goal_seen, self.ball_reset = 0, 0
    self.smoothing = {}
    self.claim = {}
    self.flash_left = 0
    self.flash_id = {}
    self.started_ms, self.done_ms, self.spike_at_ms, self.spike_at_tick, self.spike_first_sequence = 0, 0, 0, 0, 0
    self.spike_from = {}
    self.local_kicks, self.remote_kicks, self.speculative_kicks, self.spike_applied, self.spike_rejected =
        0, 0, 0, 0, 0
    self.local_canceled, self.remote_canceled = 0, 0
    self.correction_count = 0
    self.correction_sum, self.correction_max = 0, 0
    self.claim_max, self.watched_error_max, self.predicted_error_max = 0, 0, 0
    self.fast_far_samples, self.watched_samples, self.predicted_samples = 0, 0, 0
    self.predicted_members, self.remote_kicks_while_claimed = 0, 0
    self.resync_seen = 0
    self.stall_injected = false
    self.ui[0].revision = 0
    self.ui[0].submitted = false
    self.ui[0].was_playing = false
    self.ui[0].announce_host = false
    scenegd.nodes_clear(&self.players)
    scenegd.nodes_clear(&self.ball)
    gd.set_string(self.ui[0].chat_lines, "text", "")
    gd.set_string(self.ui[0].chat_notice, "text", "")
    gd.set_string(self.ui[0].chat_input, "text", "")
    gd.control_release_focus(self.ui[0].chat_input)
    gd.canvas_item_set_visible(self.ui[0].score_panel, false)
    ui_notice(self, "Host a pitch or join one.")
    ui_frame(self)
}

@(gd_method)
replay_claimball_on_chat :: proc(self: ^ReplayClaimball, text: string) {
    if self.comms.local.spectator && !self.comms.local.observer_name_allowed {
        gd.set_string(self.ui[0].chat_notice, "text", "Connecting named observer chat…")
        return
    }

    result := co.say(&self.comms, text)
    self.ui[0].submitted = true

    if result == .None {
        gd.set_string(self.ui[0].chat_input, "text", "")
        gd.control_release_focus(self.ui[0].chat_input)
        gd.set_string(self.ui[0].chat_notice, "text", "")
    } else {
        gd.set_string(self.ui[0].chat_notice, "text", fmt.ctprintf("Not sent: %v", result))
    }
}

ui_input :: proc(self: ^ReplayClaimball) -> bool {
    u := &self.ui[0]

    if gd.is_action_just_released("rcb_scores") {
        gd.canvas_item_set_visible(u.score_panel, false)
    }

    if u.submitted {
        u.submitted = false
        return true
    }

    if gd.control_has_focus(u.chat_input, false) {
        if gd.is_action_just_pressed("ui_cancel") {
            gd.control_release_focus(u.chat_input)
        }

        return true
    }

    if self.ready &&
       self.comms.enabled &&
       (!self.comms.local.spectator || self.comms.local.observer_name_allowed) &&
       gd.is_action_just_pressed("rcb_chat") {
        gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Chat"), true)
        gd.control_grab_focus(u.chat_input, false)
        return true
    }

    if self.ready && gd.is_action_just_pressed("rcb_save") {
        replay_claimball_on_save(self)
        return true
    }

    if self.ready && gd.is_action_just_pressed("rcb_scores") {
        gd.canvas_item_set_visible(u.score_panel, true)
    }

    return(
        (self.online.enabled && bool(gd.control_has_focus(self.online.code, false))) ||
        bool(gd.control_has_focus(u.save_path, false)) ||
        bool(gd.control_has_focus(u.name, false)) ||
        bool(gd.control_has_focus(u.address, false)) ||
        bool(gd.control_has_focus(gd.spin_box_get_line_edit(u.port), false)) \
    )
}

ui_frame :: proc(self: ^ReplayClaimball) {
    u := &self.ui[0]

    if u.lobby == nil {
        return
    }

    defer {
        room_ui(self)
        online_status(self)
        browser_save_status(self)
    }

    frame, ok := rgd.session_authority_state(self.session)

    if ok {
        u.was_playing = frame.state.started
    }

    playing := self.ready && (ok ? frame.state.started : self.room.ready && u.was_playing)
    gd.canvas_item_set_visible(u.lobby, !playing)

    for node in ([3]cstring{"Name", "Address", "Buttons"}) {
        gd.canvas_item_set_visible(gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Column/%s", node)), !self.ready)
    }

    gd.canvas_item_set_visible(u.leave, self.ready)

    for node in ([2]cstring{"Saved", "Resume"}) {
        gd.canvas_item_set_visible(
            gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Column/%s", node)),
            !self.ready && !gd.IS_WEB,
        )
    }

    for button in u.resume {
        gd.base_button_set_disabled(button, self.ready || !self.views_ready || claimball_int("RCB_COORD_PORT", 0) != 0)
    }

    can_save := self.ready && self.session.ready && self.session.authority && !self.room.ready && !gd.IS_WEB
    gd.canvas_item_set_visible(u.save, can_save)
    gd.base_button_set_disabled(u.save, !can_save || self.session.fenced)
    gd.canvas_item_set_visible(u.save_notice, self.ready && !self.room.ready && !gd.IS_WEB)
    gd.canvas_item_set_visible(
        gd.get_node(self.owner, "UI/Chat"),
        self.ready && (self.comms.line_count > 0 || bool(gd.control_has_focus(u.chat_input, false))),
    )

    for door in u.doors {
        gd.base_button_set_disabled(door, self.ready || !self.views_ready || !profile_available(self))
    }

    gd.line_edit_set_editable(u.name, !self.ready)
    gd.line_edit_set_editable(u.address, !self.ready)
    gd.control_set_mouse_filter(u.port, self.ready ? .Mouse_Filter_Ignore : .Mouse_Filter_Stop)
    leader := ok ? game.leader(&frame.state) : 0
    seat := rgd.session_seat(self.session)
    gd.canvas_item_set_visible(u.start, self.ready && ok && !playing && seat > 0 && seat == leader)
    count := 0

    if ok {
        for player in frame.state.players {
            if player.connected {
                count += 1
            }
        }
    }

    gd.canvas_item_set_visible(
        u.again,
        self.ready && ok && frame.state.score.winner != 0 && seat > 0 && seat == leader,
    )
    gd.base_button_set_disabled(u.again, !ok || count < int(frame.state.min_players) || self.session.fenced)
    gd.base_button_set_disabled(
        u.start,
        !ok ||
        seat == 0 ||
        count < int(frame.state.min_players) ||
        !self.name_submitted ||
        self.session.fenced ||
        (seat > 0 && frame.state.names[seat - 1] != self.display_name),
    )

    if !self.ready {
        gd.set_string(self.status, "text", "Choose Solo, Host, Join or Watch.")
        gd.set_string(u.roster, "text", "")
        return
    }

    if !self.room.ready &&
       !self.session.authority &&
       (self.session.client.phase == .Disconnected || self.session.client.phase == .Rejected) {
        ui_notice(self, "Connection ended — leave to open another pitch.")
    }

    if !ok {
        if self.room.ready && u.was_playing {
            gd.set_string(self.status, "text", "Host changing… reconnecting to the match.")
        }

        return
    }

    if seat > 0 && !self.name_submitted {
        if frame.state.names[seat - 1] == self.display_name {
            self.name_submitted = true
        } else {
            sequence, err := issue(self, game.Action{name = self.display_name})

            if err == .None {
                self.name_submitted = true
                self.name_sequence = sequence
            }
        }
    }

    builder: strings.Builder
    defer strings.builder_destroy(&builder)

    for player, i in frame.state.players {
        if player.connected {
            if strings.builder_len(builder) > 0 {
                strings.write_string(&builder, "\n")
            }

            fmt.sbprintf(&builder, "%s%s", lb.text(&frame.state.names[i]), i + 1 == int(leader) ? " (lead)" : "")
        }
    }

    gd.set_string(u.roster, "text", fmt.ctprintf("%s", strings.to_string(builder)))
}

social_frame :: proc(self: ^ReplayClaimball) {
    frame, ok := rgd.session_authority_state(self.session)
    rgd.session_comms_frame(&self.comms, self.session, ok ? frame.state.names[:] : nil, self.display_name)
    debuggd.session_diagnostics_frame(&self.diagnostics, self.session)
    u := &self.ui[0]

    if ok && self.session.authority && self.comms.enabled && u.announce_host {
        if co.system(&self.comms, "The pitch has a new host") == .None {
            u.announce_host = false
        }
    }

    if ok && self.session.authority && u.round_seen != frame.state.round {
        if u.round_seen != 0 {
            co.system(&self.comms, fmt.tprintf("Match %d starts", frame.state.round))
        }

        u.round_seen = frame.state.round
    }

    if u.revision != self.comms.history_serial {
        builder: strings.Builder
        defer strings.builder_destroy(&builder)

        for entry, i in self.comms.lines[:self.comms.line_count] {
            e := entry

            if i > 0 {
                strings.write_string(&builder, "\n")
            }

            if e.value.kind == .System {
                fmt.sbprintf(&builder, "* %s", string(e.value.text[:e.value.length]))
            } else {
                fmt.sbprintf(
                    &builder,
                    "%s%s: %s",
                    e.name.length > 0 ? lb.text(&e.name) : "Observer",
                    e.seat == 0 && e.name.length > 0 ? " (observer)" : "",
                    string(e.value.text[:e.value.length]),
                )
            }
        }

        gd.set_string(u.chat_lines, "text", fmt.ctprintf("%s", strings.to_string(builder)))
        u.revision = self.comms.history_serial
    }

    for {
        receipt, found := co.poll_result(&self.comms)

        if !found {
            break
        }

        if receipt.result != .None {
            gd.set_string(u.chat_notice, "text", fmt.ctprintf("Message not sent: %v", receipt.result))
        }
    }

    named_ready := !self.comms.local.spectator || self.comms.local.observer_name_allowed
    gd.line_edit_set_editable(u.chat_input, self.comms.enabled && named_ready)

    if !ok {
        return
    }

    score := frame.state.score
    gd.set_string(
        gd.get_node(self.owner, "UI/Scoreboard/Column/Score"),
        "text",
        fmt.ctprintf("LEFT %d — %d RIGHT", score.left, score.right),
    )

    for player, i in frame.state.players {
        for cell in u.cells[i] {
            gd.canvas_item_set_visible(cell, player.initialized)
        }

        if !player.initialized {
            continue
        }

        gd.set_string(
            u.cells[i][0],
            "text",
            fmt.ctprintf("%s%s", lb.text(&frame.state.names[i]), player.connected ? "" : " (left)"),
        )
        gd.set_string(u.cells[i][1], "text", player.team == 1 ? "LEFT" : "RIGHT")
        ping := dg.read(&self.diagnostics, u16(i + 1))
        gd.set_string(
            u.cells[i][2],
            "text",
            ping.known && player.connected ? fmt.ctprintf("%d", ping.round_trip_ms) : "—",
        )
    }
}

@(gd_method)
replay_claimball_probe :: proc(self: ^ReplayClaimball, key: string, wanted: gd.Int = 1) -> gd.Int {
    if key == "ready" {
        return gd.Int(self.ready)
    }

    if key == "chat_ready" {
        return gd.Int(self.comms.enabled)
    }

    if key == "named_observer" {
        return gd.Int(self.comms.local.spectator && self.comms.local.observer_name_allowed)
    }

    if key == "members" {
        return gd.Int(self.predicted_members)
    }

    if key == "typing" {
        return gd.Int(gd.control_has_focus(self.ui[0].chat_input, false))
    }

    frame, ok := rgd.session_authority_state(self.session)

    if key == "state_ready" {
        return gd.Int(ok)
    }

    if !ok {
        return -1
    }

    switch key {
    case "epoch":
        return gd.Int(self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch)
    case "round":
        return gd.Int(frame.state.round)
    case "claim":
        return gd.Int(self.claim.weight * 1000)
    case "tick":
        return gd.Int(frame.tick)
    case "started":
        return gd.Int(frame.state.started)
    case "seat":
        return gd.Int(rgd.session_seat(self.session))
    case "players":
        count := 0

        for player in frame.state.players {
            if player.connected {
                count += 1
            }
        }

        return gd.Int(count)
    case "kicks":
        return gd.Int(frame.state.kicks)
    case "spikes":
        return gd.Int(frame.state.spikes)
    case "left":
        return gd.Int(frame.state.score.left)
    case "right":
        return gd.Int(frame.state.score.right)
    case "winner":
        return gd.Int(frame.state.score.winner)
    }

    if key == "ball_draw_x" || key == "ball_draw_y" {
        if node, found := scenegd.nodes_get(&self.ball, 1); found {
            return gd.Int(gd.node2d_get_position(node)[key == "ball_draw_x" ? 0 : 1])
        }

        return -1
    }

    if wanted < 1 || wanted > game.SEATS {
        return -1
    }

    player := frame.state.players[wanted - 1]

    if key == "draw_x" || key == "draw_y" {
        if node, found := scenegd.nodes_get(&self.players, u64(wanted)); found {
            return gd.Int(gd.node2d_get_position(node)[key == "draw_x" ? 0 : 1])
        }

        return -1
    }

    switch key {
    case "connected":
        return gd.Int(player.connected)
    case "named":
        return gd.Int(player.named)
    case "team":
        return gd.Int(player.team)
    case "x":
        return gd.Int(player.motion.position[0])
    case "y":
        return gd.Int(player.motion.position[1])
    case "ping_known":
        return gd.Int(dg.read(&self.diagnostics, u16(wanted)).known)
    }

    return -1
}

@(gd_method)
replay_claimball_set_bot :: proc(self: ^ReplayClaimball, value: string) {
    delete(self.bot)
    self.bot = strings.clone(value)

    if value == "spiker" {
        self.spiked, self.spike_visible, self.own_spike_seen, self.spike_node_start = false, false, false, false
    }
}


observe_round :: proc(self: ^ReplayClaimball) {
    frame, ok := rgd.session_authority_state(self.session)

    if !ok || self.view_round == frame.state.round {
        return
    }

    self.view_round = frame.state.round
    self.done, self.spiked, self.spike_visible, self.spike_node_start, self.own_spike_seen =
        false, false, false, false, false
    self.goal_seen = 0
    self.spike_first_sequence = 0
    self.flash_left = 0
    self.flash_id = {}
    self.local_kicks, self.remote_kicks, self.speculative_kicks, self.local_canceled, self.remote_canceled =
        0, 0, 0, 0, 0
    self.spike_applied, self.spike_rejected = 0, 0
}
