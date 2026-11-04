package replay_speedball
import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import lb "godot:replay/lobby"
import game "../shared/pitch"
import debuggd "godot:replay/godot/debug"
import inputgd "godot:replay/godot/input"
import scenegd "godot:replay/godot/scene"

Speedball_UI :: struct {
    lobby, score_panel:                                  gd.Control,
    name, address, chat_input, save_path:                gd.Line_Edit,
    port:                                                gd.Spin_Box,
    notice, roster, chat_notice, score:                  gd.Label,
    chat_lines:                                          gd.Rich_Text_Label,
    start, leave, again, save:                           gd.Button,
    resume:                                              [2]gd.Button,
    save_notice:                                         gd.Label,
    doors:                                               [4]gd.Button,
    cells:                                               [game.SEATS][3]gd.Label,
    revision, joined:                                    u64,
    round_seen:                                          u32,
    score_seen:                                          game.Score,
    started_seen, submitted, announce_host, was_playing: bool,
}

ui_notice :: proc(self: ^ReplaySpeedball, text: string) {
    gd.set_string(self.ui[0].notice, "text", fmt.ctprintf("%s", text))
}

ui_ready :: proc(self: ^ReplaySpeedball) {
    u := &self.ui[0]
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
            gd.IS_WEB ? speedball_param("RSB_SAVE_SLOT", "pitch") : speedball_param("RSB_SAVE", "user://speedball.replay"),
        ),
    )
    inputgd.bind_key("rsb_save", .F5)
    u.lobby = cast(gd.Control)gd.get_node(self.owner, "UI/Lobby")
    u.name = cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Lobby/Column/Name/Value")
    u.address = cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Lobby/Column/Address/Value")
    u.port = cast(gd.Spin_Box)gd.get_node(self.owner, "UI/Lobby/Column/Address/Port")
    u.notice = cast(gd.Label)gd.get_node(self.owner, "UI/Lobby/Column/Notice")
    u.roster = cast(gd.Label)gd.get_node(self.owner, "UI/Lobby/Column/Roster")
    u.start = cast(gd.Button)gd.get_node(self.owner, "UI/Lobby/Column/Start")
    u.leave = cast(gd.Button)gd.get_node(self.owner, "UI/Leave")
    u.again = cast(gd.Button)gd.get_node(self.owner, "UI/Again")
    gd.connect_to(u.again, "pressed", self.owner, "on_again")
    u.chat_input = cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Chat/Column/Input")
    u.chat_lines = cast(gd.Rich_Text_Label)gd.get_node(self.owner, "UI/Chat/Column/Lines")
    u.chat_notice = cast(gd.Label)gd.get_node(self.owner, "UI/Chat/Column/Notice")
    u.score_panel = cast(gd.Control)gd.get_node(self.owner, "UI/Scoreboard")
    u.score = cast(gd.Label)gd.get_node(self.owner, "UI/Scoreboard/Column/Score")
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
            gd.control_set_custom_minimum_size(label, {column == 0 ? 150 : 70, 0})
        }
    }

    for label, i in ([4]cstring{"Solo", "Host", "Join", "Watch"}) {
        u.doors[i] = cast(gd.Button)gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Column/Buttons/%s", label))
    }

    for method, i in ([4]cstring{"on_solo", "on_host", "on_join", "on_watch"}) {
        gd.connect_to(u.doors[i], "pressed", self.owner, method)
    }

    gd.connect_to(gd.get_node(self.owner, "UI/Handoff"), "pressed", self.owner, "handoff")
    gd.connect_to(u.start, "pressed", self.owner, "on_start")
    gd.connect_to(u.leave, "pressed", self.owner, "on_leave")
    gd.connect_to(u.chat_input, "text_submitted", self.owner, "on_chat")
    inputgd.bind_key("rsb_chat", .Enter)
    inputgd.bind_key("rsb_scores", .Tab)
    profile_ready(self)
    gd.set_string(u.address, "text", fmt.ctprintf("%s", speedball_param("RSB_ADDRESS", "127.0.0.1")))
    gd.range_set_value(u.port, f64(speedball_int("RSB_PORT", 49480)))
    gd.rich_text_label_set_use_bbcode(u.chat_lines, false)
    ui_frame(self)
}

@(gd_method)
replay_speedball_on_solo :: proc(self: ^ReplaySpeedball) {
    connect_pitch(self, "solo", false)
}

@(gd_method)
replay_speedball_on_host :: proc(self: ^ReplaySpeedball) {
    if self.online.enabled {
        online_begin(self, .Create)
    } else {
        connect_pitch(self, "host", true)
    }
}

@(gd_method)
replay_speedball_on_join :: proc(self: ^ReplaySpeedball) {
    if self.online.enabled {
        online_begin(self, .Join)
    } else {
        connect_pitch(self, "client", true)
    }
}

@(gd_method)
replay_speedball_on_watch :: proc(self: ^ReplaySpeedball) {
    if self.online.enabled {
        online_begin(self, .Join, true)
    } else {
        connect_pitch(self, "observer", true)
    }
}

@(gd_method)
replay_speedball_on_start :: proc(self: ^ReplaySpeedball) {
    if !self.ready {
        return
    }

    _, err := issue(self, game.Action{start = true})

    if err != .None {
        ui_notice(self, fmt.tprintf("Could not start: %v", err))
    }
}

@(gd_method)
replay_speedball_on_again :: proc(self: ^ReplaySpeedball) {
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
replay_speedball_on_leave :: proc(self: ^ReplaySpeedball) {
    if !self.ready {
        return
    }

    close_session(self)
    co.destroy(&self.comms)
    dg.destroy(&self.diagnostics)
    co.init(&self.comms)
    dg.init(&self.diagnostics)
    self.ready, self.done, self.spiked, self.spike_visible, self.own_spike_seen, self.spike_node_start =
        false, false, false, false, false, false
    self.save_tick, self.save_hash, self.restored_tick, self.restored_hash = 0, 0, 0, 0
    self.restored_exact = false
    gd.set_string(self.ui[0].save_notice, "text", "")
    self.view_round, self.paint_round = 0, 0
    self.ui[0].round_seen = 0
    self.name_submitted = false
    self.name_sequence, self.last_verdict, self.reset_seen, self.correction_seen = 0, 0, 0, 0
    self.goal_seen, self.ball_reset = 0, 0
    self.smoothing = {}
    self.flash_left = 0
    self.started_ms, self.done_ms, self.spike_at_ms, self.spike_at_tick, self.spike_first_sequence = 0, 0, 0, 0, 0
    self.spike_from = {}
    self.flash_id = {}
    self.local_kicks, self.remote_kicks, self.speculative_kicks, self.spike_applied, self.spike_rejected =
        0, 0, 0, 0, 0
    self.local_canceled, self.remote_canceled = 0, 0
    self.correction_count = 0
    self.correction_sum, self.correction_max = 0, 0
    self.ui[0].submitted, self.ui[0].announce_host, self.ui[0].was_playing = false, false, false
    self.ui[0].revision, self.ui[0].joined = 0, 0
    self.ui[0].started_seen = false
    self.ui[0].score_seen = {}
    scenegd.nodes_present(&self.players, nil)
    scenegd.nodes_present(&self.ball, nil)
    gd.set_string(self.ui[0].chat_lines, "text", "")
    gd.set_string(self.ui[0].chat_notice, "text", "")
    gd.set_string(self.ui[0].chat_input, "text", "")
    gd.control_release_focus(self.ui[0].chat_input)
    gd.canvas_item_set_visible(self.ui[0].score_panel, false)
    ui_notice(self, "Host a pitch or join one.")
    ui_frame(self)
}

@(gd_method)
replay_speedball_on_chat :: proc(self: ^ReplaySpeedball, text: string) {
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

ui_input :: proc(self: ^ReplaySpeedball) -> bool {
    u := &self.ui[0]

    if gd.is_action_just_released("rsb_scores") {
        gd.canvas_item_set_visible(u.score_panel, false)
    }

    if u.submitted {
        u.submitted = false
        return true
    }

    focused := bool(gd.control_has_focus(u.chat_input, false))

    if focused {
        if gd.is_action_just_pressed("ui_cancel") {
            gd.control_release_focus(u.chat_input)
        }

        return true
    }

    if self.ready && gd.is_action_just_pressed("rsb_save") {
        replay_speedball_on_save(self)
        return true
    }

    if self.ready && self.comms.enabled && gd.is_action_just_pressed("rsb_chat") {
        gd.control_grab_focus(u.chat_input, false)
        return true
    }

    if self.ready && gd.is_action_just_pressed("rsb_scores") {
        gd.canvas_item_set_visible(u.score_panel, true)
    }

    return(
        bool(gd.control_has_focus(u.name, false)) ||
        bool(gd.control_has_focus(u.address, false)) ||
        bool(gd.control_has_focus(u.save_path, false)) ||
        (self.online.enabled && bool(gd.control_has_focus(self.online.code, false))) \
    )
}

ui_frame :: proc(self: ^ReplaySpeedball) {
    u := &self.ui[0]

    if u.lobby == nil {
        return
    }

    defer {
        online_status(self)
        browser_save_status(self)
    }

    frame, ok := rgd.session_authority_state(self.session)

    if ok {
        u.was_playing = frame.state.started
    }

    playing := ok ? frame.state.started : self.room.ready && u.was_playing
    gd.canvas_item_set_visible(u.lobby, !playing)
    gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Column/Saved"), !self.ready && !gd.IS_WEB)
    gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Column/Resume"), !self.ready && !gd.IS_WEB)

    for button in u.resume {
        gd.base_button_set_disabled(button, self.ready || speedball_int("RSB_COORD_PORT", 0) != 0)
    }

    can_save := self.ready && self.session.ready && self.session.authority && !self.room.ready && !gd.IS_WEB
    gd.canvas_item_set_visible(u.save, can_save)
    gd.base_button_set_disabled(u.save, !can_save || self.session.fenced)
    gd.canvas_item_set_visible(u.save_notice, self.ready && !self.room.ready)

    for button in u.doors {
        gd.base_button_set_disabled(button, self.ready || !profile_available(self))
    }

    gd.line_edit_set_editable(u.name, !self.ready && self.profile_name_loaded)
    gd.line_edit_set_editable(u.address, !self.ready)
    gd.canvas_item_set_visible(
        u.start,
        self.ready &&
        ok &&
        frame.state.manual_start &&
        rgd.session_seat(self.session) == game.leader(frame.state) &&
        !playing,
    )
    count := 0

    if ok {
        for player in frame.state.players {
            if player.connected {
                count += 1
            }
        }
    }

    gd.base_button_set_disabled(u.start, !ok || count < int(frame.state.min_players))
    gd.canvas_item_set_visible(u.leave, self.ready)
    gd.canvas_item_set_visible(
        u.again,
        self.ready &&
        ok &&
        frame.state.score.winner != 0 &&
        rgd.session_seat(self.session) == game.leader(frame.state),
    )
    gd.base_button_set_disabled(u.again, !ok || count < int(frame.state.min_players) || self.session.fenced)
    gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Chat"), self.ready)

    if self.ready &&
       !self.room.ready &&
       !self.session.authority &&
       (self.session.client.phase == .Disconnected || self.session.client.phase == .Rejected) {
        ui_notice(self, "Connection ended — leave to open another pitch.")
    }

    room_ui(self)

    if !self.ready {
        gd.set_string(self.status, "text", "Choose Solo, Host, Join or Watch.")
    }

    if !ok {
        return
    }

    if !self.name_submitted && rgd.session_seat(self.session) > 0 {
        sequence, err := issue(self, game.Action{name = self.display_name})

        if err == .None {
            self.name_submitted = true
            self.name_sequence = sequence
        }
    }

    builder: strings.Builder
    defer strings.builder_destroy(&builder)

    for player, i in frame.state.players {
        if player.connected {
            if strings.builder_len(builder) > 0 {
                strings.write_string(&builder, "\n")
            }

            fmt.sbprintf(&builder, "%s · %s", lb.text(&frame.state.names[i]), player.team == 1 ? "LEFT" : "RIGHT")
        }
    }

    gd.set_string(u.roster, "text", fmt.ctprintf("%s", strings.to_string(builder)))
}

social_frame :: proc(self: ^ReplaySpeedball) {
    frame, ok := rgd.session_authority_state(self.session)
    rgd.session_comms_frame(&self.comms, self.session, ok ? frame.state.names[:] : nil)
    debuggd.session_diagnostics_frame(&self.diagnostics, self.session)
    u := &self.ui[0]

    if ok && self.session.authority && self.comms.enabled {
        if u.round_seen != frame.state.round {
            if u.round_seen != 0 {
                co.system(&self.comms, fmt.tprintf("Match %d starts", frame.state.round))
            }

            u.round_seen = frame.state.round
            u.score_seen = {}
        }

        if u.announce_host {
            if co.system(&self.comms, "The pitch has a new host") == .None {
                u.announce_host = false
            }
        }

        present: u64

        for player, i in frame.state.players {
            if player.connected && player.named {
                bit := u64(1) << uint(i)
                present |= bit

                if u.joined & bit == 0 {
                    co.system(&self.comms, fmt.tprintf("%s takes the pitch", lb.text(&frame.state.names[i])))
                }
            }
        }

        u.joined = present

        if frame.state.started && !u.started_seen {
            co.system(&self.comms, "The match starts")
            u.started_seen = true
        }

        score := frame.state.score

        if score != u.score_seen {
            co.system(&self.comms, fmt.tprintf("LEFT %d — %d RIGHT", score.left, score.right))

            if score.winner != 0 {
                co.system(&self.comms, score.winner == 1 ? "LEFT takes the match" : "RIGHT takes the match")
            }

            u.score_seen = score
        }
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
                    "%s: %s",
                    e.name.length > 0 ? lb.text(&e.name) : "Observer",
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

    gd.line_edit_set_editable(u.chat_input, self.comms.enabled)

    if ok {
        score := frame.state.score
        gd.set_string(u.score, "text", fmt.ctprintf("LEFT %d — %d RIGHT", score.left, score.right))

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
}

@(gd_method)
replay_speedball_probe :: proc(self: ^ReplaySpeedball, key: string, seat: gd.Int = 1) -> gd.Int {
    if key == "ready" {
        return gd.Int(self.ready)
    }

    if key == "chat_ready" {
        return gd.Int(self.comms.enabled)
    }

    if key == "chat_lines" {
        return gd.Int(self.comms.line_count)
    }

    frame, ok := rgd.session_authority_state(self.session)

    if key == "state_ready" {
        return gd.Int(ok)
    }

    if !ok {
        return -1
    }

    switch key {
    case "round":
        return gd.Int(frame.state.round)
    case "tick":
        return gd.Int(frame.tick)
    case "started":
        return gd.Int(frame.state.started)
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
    case "seat":
        return gd.Int(rgd.session_seat(self.session))
    }

    if seat < 1 || seat > game.SEATS {
        return -1
    }

    player := frame.state.players[seat - 1]

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
        return gd.Int(dg.read(&self.diagnostics, u16(seat)).known)
    }

    return -1
}
