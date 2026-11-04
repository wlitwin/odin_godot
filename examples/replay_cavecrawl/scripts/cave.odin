//gd:extends Node2D
//gd:class ReplayCave
package replay_cavecrawl

import "core:fmt"
import "core:math"
import gd "godot:godot"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import comms "godot:replay/comms"
import dg "godot:replay/telemetry"
import rec "godot:replay/recovery"
import auth "godot:replay/authority"
import sc "godot:replay/schema"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/cave"
import lb "godot:replay/lobby"
import debuggd "godot:replay/godot/debug"
import inputgd "godot:replay/godot/input"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

ReplayCave :: struct {
    owner:                                                 gd.Node2d,
    browser:                                               Cave_Browser,
    online:                                                Cave_Online,
    online_code:                                           gd.Line_Edit `gd:"onready=Lobby/Panel/Column/PartyCode"`,
    name_profile:                                          storagegd.Name_Profile,
    name_loaded, use_lobby, menu_launch, lobby_menu_open:  bool,
    profile_epoch, profile_retry:                          u64,
    profile_name:                                          lb.Name,
    moderation:                                            Cave_Moderation,
    lobby_panel:                                           gd.Control `gd:"onready=Lobby/Panel"`,
    lobby_name:                                            gd.Line_Edit `gd:"onready=Lobby/Panel/Column/Name"`,
    lobby_address:                                         gd.Line_Edit `gd:"onready=Lobby/Panel/Column/Address"`,
    lobby_port:                                            gd.Spin_Box `gd:"onready=Lobby/Panel/Column/Port"`,
    lobby_status:                                          gd.Label `gd:"onready=Lobby/Panel/Column/Status"`,
    lobby_roster:                                          gd.Label `gd:"onready=Lobby/Panel/Column/Roster"`,
    comms:                                                 comms.Comms,
    diagnostics:                                           dg.Diagnostics,
    chat_input:                                            gd.Line_Edit `gd:"onready=Social/Chat/Input"`,
    chat_lines:                                            gd.Rich_Text_Label `gd:"onready=Social/Chat/Lines"`,
    chat_notice:                                           gd.Label `gd:"onready=Social/Chat/Notice"`,
    score_panel:                                           gd.Control `gd:"onready=Social/Scoreboard"`,
    score_cells:                                           [4][8]gd.Label,
    chat_submitted, score_open:                            bool,
    chat_revision:                                         u64,
    marks:                                                 [16]Cave_Mark,
    mark_received:                                         u64,
    floor1_def:                                            ^gd.Resource `gd:"export,resource=ReplayCaveLevelDef"`,
    floor2_def:                                            ^gd.Resource `gd:"export,resource=ReplayCaveLevelDef"`,
    definitions:                                           [2]game.Floor,
    floor_scenes:                                          [2]gd.Packed_Scene,
    scatter_checksum:                                      u32,
    debug_enabled:                                         bool `gd:"export"`,
    debug:                                                 debuggd.Debug_Overlay,
    stage:                                                 gd.Node2d `gd:"onready=Stage"`,
    status:                                                gd.Label `gd:"onready=Status"`,
    inventory:                                             gd.Label `gd:"onready=Inventory"`,
    prompt:                                                gd.Label `gd:"onready=Prompt"`,
    session:                                               ^rgd.Session(
        game.World,
        game.Control,
        game.Action,
        game.Event,
        game.SEATS,
    ),
    standalone:                                            rgd.Session(
        game.World,
        game.Control,
        game.Action,
        game.Event,
        game.SEATS,
    ),
    room:                                                  rgd.Room(
        game.World,
        game.Control,
        game.Action,
        game.Event,
        game.SEATS,
    ),
    players, chest, door, relic, dwellers, pickups, rocks: scenegd.Nodes2,
    scenery:                                               gd.Node,
    scenery_depth:                                         u8,
    scenery_seed:                                          u32,
    ready, walking:                                        bool,
    motion:                                                Cave_Motion,
    feedback:                                              Cave_Feedback,
    rock_phase:                                            v.Tick_Phase,
    walk_target:                                           [2]f32,
    aim:                                                   [2]f32,
    accepted, rejected, effects:                           u32,
    last_verdict, verdict_epoch:                           u64,
    saved_hash, restored_hash, saved_tick, restored_tick:  u64,
    save_notice_until:                                     u64,
    recovery_notice_until, noticed_migration:              u64,
    save_ok:                                               bool,
}

replay_cave_ready :: proc(self: ^ReplayCave) {
    if self.debug_enabled || gd.launch_param("REPLAY_DEBUG", "debug", "0") == "1" {
        debuggd.debug_overlay_init(&self.debug, self.owner, true)
    }

    self.session = &self.standalone

    if !comms.init(&self.comms) {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    if !dg.init(&self.diagnostics) {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    social_ready(self)

    if !definitions_load(self) {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    install_controls()
    lobby_ready(self)
    cave_moderation_ready(self)
    browser_cave_ready(self)
    online_ready(self)
    role := cave_param("REPLAY_CAVE_ROLE", "")

    if role == "" && (cave_int("REPLAY_CAVE_COORD_PORT", 0) > 0 || cave_param("REPLAY_CAVE_COORD_URL", "") != "") {
        role = cave_int("REPLAY_CAVE_MEMBER", 1) == 1 ? "host" : "client"
    }

    self.use_lobby = role == "" || cave_int("REPLAY_CAVE_LOBBY", 0) == 1

    if role != "" {
        replay_cave_connect(self, role, false)
    }
}

replay_cave_connect :: proc(self: ^ReplayCave, role: string, resume: bool) {
    if self.ready || self.room.ready || self.session.ready {
        return
    }

    self.moderation.removed = false

    if !self.online.launch && !browser_cave_prepare(self, role, resume || cave_int("REPLAY_CAVE_RESUME", 0) == 1) {
        return
    }

    if !definitions_load(self) {
        gd.set_string(self.lobby_status, "text", "Floor definition is invalid.")
        return
    }

    opts := rgd.SESSION_OPTIONS

    if !rgd.session_comms_enable(&opts) {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    if !debuggd.session_diagnostics_enable(&opts) {
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    switch role {
    case "host":
        opts.role = .Host
    case "server":
        opts.role = .Server
    case "client":
        opts.role = .Client
    case "observer":
        opts.role = .Observer
    }

    port := self.menu_launch ? int(gd.range_get_value(self.lobby_port)) : cave_int("REPLAY_CAVE_PORT", 49422)
    latency := cave_int("REPLAY_CAVE_LATENCY", 0)

    if port < 1 || port > 65535 || latency < 0 || latency > 10000 {
        gd.print_str("REPLAY_CAVE_FAIL configuration")
        return
    }

    opts.port = u16(port)
    address := cave_param("REPLAY_CAVE_ADDRESS", "127.0.0.1")

    if self.menu_launch {
        value := gd.line_edit_get_text(self.lobby_address)
        address = gd.gd_string_to_odin(value, context.temp_allocator)
        gd.free_string(value)
    }

    opts.address = fmt.ctprintf("%s", address)
    label := cave_param("REPLAY_CAVE_TOKEN", "")

    if self.online.launch {
        opts.token = self.online.grant.token
    } else if label != "" {
        opts.token = storagegd.session_token(label)
    } else {
        when gd.IS_WEB {
            opts.token = self.browser.token
        } else {
            profile := cave_param(
                "REPLAY_CAVE_PROFILE",
                self.menu_launch ? "user://player.token" : fmt.tprintf("user://%s.token", role),
            )
            token, err := storagegd.session_profile(profile)

            if err != .None {
                gd.print_str(fmt.tprintf("REPLAY_CAVE_FAIL profile=%v", err))
                return
            }

            opts.token = token
        }
    }

    opts.latency_ms = u32(latency)
    jit := cave_int("REPLAY_CAVE_JITTER", 0)
    loss := cave_int("REPLAY_CAVE_LOSS", 0)
    duplicate := cave_int("REPLAY_CAVE_DUPLICATE", 0)

    if jit < 0 || jit > 10000 || loss < 0 || loss > 10000 || duplicate < 0 || duplicate > 10000 {
        gd.print_str("REPLAY_CAVE_FAIL faults")
        return
    }

    opts.jitter_ms, opts.loss_permyriad, opts.duplicate_permyriad = u32(jit), u32(loss), u32(duplicate)
    opts.replication.accept_checkpoints = cave_int("REPLAY_CAVE_BACKUP", 0) == 1
    opts.network.hz, opts.network.lead, opts.network.snapshot_every = game.HZ, 4, 1
    opts.network.content = game.CONTENT
    coordinator_port := cave_int("REPLAY_CAVE_COORD_PORT", 0)
    epoch := cave_int("REPLAY_CAVE_EPOCH", 1)

    if epoch < 1 {
        gd.print_str("REPLAY_CAVE_FAIL epoch")
        return
    }

    opts.network.epoch = u64(epoch)
    err: net.Error
    coordinator_url := cave_param("REPLAY_CAVE_COORD_URL", "")

    if self.online.launch {
        options, valid := rgd.party_room_options(&self.online.party, opts)

        if !valid {
            gd.set_string(self.lobby_status, "text", "The party credential does not match this game.")
            return
        }

        err = rgd.room_open(
            &self.room,
            r.Frame(game.World){state = game.initial(floors = self.definitions, staging = true)},
            game.model(),
            options,
        )
        self.session = &self.room.session
    } else if coordinator_port > 0 || (gd.IS_WEB && coordinator_url != "") {
        member := cave_int("REPLAY_CAVE_MEMBER", 1)
        incarnation := cave_int("REPLAY_CAVE_INCARNATION", 101)
        key, valid := cave_control_key(cave_param("REPLAY_CAVE_COORD_KEY", ""))

        if !valid || coordinator_port > 65535 || member < 1 || incarnation < 1 {
            gd.print_str("REPLAY_CAVE_FAIL coordinator config")
            return
        }

        options := rgd.Room_Options {
            identity     = {u64(member), u64(incarnation)},
            key          = key,
            room         = 44,
            coordinator  = "127.0.0.1",
            control_port = u16(coordinator_port),
            bootstrap    = member == 1,
            session      = opts,
        }

        if gd.env_int("REPLAY_CONTROL_WS", 0) == 1 {
            options.control_backend = .Websocket
            options.coordinator = fmt.tprintf("ws://127.0.0.1:%d/control", coordinator_port)
        }

        when gd.IS_WEB {
            options.control_backend = .Websocket
            options.coordinator = coordinator_url
            options.session.backend = .Rtc
            options.session.rtc.url = coordinator_url
        }

        if member == 1 {
            options.successor = {2, 102}
        }

        if member == 2 {
            options.successor = {1, 101}
        }

        options.session.replication.accept_checkpoints = member <= 2
        err = rgd.room_open(
            &self.room,
            r.Frame(game.World) {
                state = game.initial(
                    floors = self.definitions,
                    staging = self.use_lobby,
                    dedicated = opts.role == .Server,
                ),
            },
            game.model(),
            options,
        )
        self.session = &self.room.session
    } else if resume || cave_int("REPLAY_CAVE_RESUME", 0) == 1 {
        cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)

        defer if !gd.IS_WEB {
            net.checkpoint_destroy(&cp)
        }

        when gd.IS_WEB {
            if self.browser.save.phase != .Ready || !self.browser.save.has_checkpoint {
                gd.set_string(self.lobby_status, "text", "No readable browser save is available.")
                return
            }

            // The slot owns its archive. Borrow only for this synchronous resume.
            cp = self.browser.save.checkpoint
        } else {
            result := storagegd.checkpoint_read(
                &cp,
                game.model(),
                cave_param("REPLAY_CAVE_SAVE", "user://cave.replay"),
                opts.network.content,
            )

            if result.error != .None {
                gd.set_string(self.lobby_status, "text", fmt.ctprintf("Cannot load save: %v", result.error))
                gd.print_str(fmt.tprintf("REPLAY_CAVE_FAIL load=%v", result))
                return
            }
        }

        seat, _ := net.checkpoint_seat(&cp, opts.token)

        if opts.role == .Server {
            seat = 0
        }

        err = rgd.session_resume(
            self.session,
            &cp,
            game.model(),
            opts,
            {epoch = cp.header.epoch + 1, local_seat = seat},
        )

        if err == .None {
            self.restored_tick, self.restored_hash = cp.frame.tick, replay_cave_hash(cp.frame)
            gd.print_str(
                fmt.tprintf(
                    "REPLAY_CAVE_RESTORED tick=%d epoch=%d hash=%d",
                    self.restored_tick,
                    self.session.server.cfg.epoch,
                    self.restored_hash,
                ),
            )
        }
    } else {
        err = rgd.session_open(
            self.session,
            r.Frame(game.World) {
                state = game.initial(
                    floors = self.definitions,
                    staging = self.use_lobby,
                    dedicated = opts.role == .Server,
                ),
            },
            game.model(),
            opts,
        )
    }

    if err != .None {
        gd.set_string(self.lobby_status, "text", fmt.ctprintf("Connection failed: %v", err))
        gd.print_str(fmt.tprintf("REPLAY_CAVE_FAIL init=%v", err))
        return
    }

    self.ready =
        scenegd.nodes_load(&self.players, self.stage, "res://views/spelunker.tscn", game.SEATS) &&
        scenegd.nodes_load(&self.chest, self.stage, "res://views/chest.tscn", 1) &&
        scenegd.nodes_load(&self.door, self.stage, "res://views/door.tscn", 1) &&
        scenegd.nodes_load(&self.relic, self.stage, "res://views/relic.tscn", 1) &&
        scenegd.nodes_load(&self.dwellers, self.stage, "res://views/dweller.tscn", 16) &&
        scenegd.nodes_load(&self.pickups, self.stage, "res://views/pickup.tscn", 48) &&
        scenegd.nodes_load(&self.rocks, self.stage, "res://views/rock.tscn", 64)

    if self.ready {
        gd.print_str("REPLAY_CAVE_READY")
    }
}

install_controls :: proc() {
    if gd.has_action("rc_use") {
        return
    }

    names := [7]cstring{"rc_left", "rc_right", "rc_up", "rc_down", "rc_use", "rc_drop", "rc_heal"}
    keys := [7]i64{i64('A'), i64('D'), i64('W'), i64('S'), i64('E'), i64('Q'), i64('R')}

    for name, i in names {
        inputgd.bind_key(name, gd.Key(keys[i]))
    }

    inputgd.bind_key("rc_set_down", gd.Key('G'))
    inputgd.bind_mouse("rc_throw", .Left)
    inputgd.bind_key("rc_save", .F5)
}

replay_cave_process :: proc(self: ^ReplayCave, dt: f64) {
    defer debuggd.debug_session_frame(&self.debug, self.session)
    online_frame(self)
    browser_cave_frame(self)
    lobby_frame(self)

    if !self.ready {
        debuggd.session_diagnostics_frame(&self.diagnostics, self.session)
        return
    }

    if cave_moderation_removed(self) {
        return
    }

    if gd.is_action_just_pressed("ui_cancel") && !gd.control_has_focus(self.chat_input, false) {
        self.lobby_menu_open = !self.lobby_menu_open
    }

    typing := social_input(self) || lobby_waiting(self) || self.lobby_menu_open

    if !typing && gd.is_action_just_pressed("rc_save") {
        replay_cave_save(self)
    }

    control: game.Control

    if !typing && (gd.is_action_pressed("rc_left") || gd.is_action_pressed("ui_left")) {
        control.move[0] -= 1
    }

    if !typing && (gd.is_action_pressed("rc_right") || gd.is_action_pressed("ui_right")) {
        control.move[0] += 1
    }

    if !typing && (gd.is_action_pressed("rc_up") || gd.is_action_pressed("ui_up")) {
        control.move[1] -= 1
    }

    if !typing && (gd.is_action_pressed("rc_down") || gd.is_action_pressed("ui_down")) {
        control.move[1] += 1
    }

    frame, available := rgd.session_state(self.session)
    seat := rgd.session_seat(self.session)

    if available && seat != 0 && !typing {
        player := frame.state.players[seat - 1]

        when !game.OWNER_MOTION {
            if self.walking {
                difference := self.walk_target - player.position

                if p.in_reach(self.walk_target, player.position, 7) {
                    self.walking = false
                } else {
                    control.move = {
                        abs(difference[0]) > 4 ? (difference[0] > 0 ? i8(1) : i8(-1)) : 0,
                        abs(difference[1]) > 4 ? (difference[1] > 0 ? i8(1) : i8(-1)) : 0,
                    }
                }
            }
        }

        mouse := gd.canvas_item_get_local_mouse_position(self.stage)
        self.aim = mouse - player.position

        if gd.is_action_just_pressed("rc_use") {
            replay_cave_use(self)
        }

        if gd.is_action_just_pressed("ui_accept") || gd.is_action_just_pressed("rc_throw") {
            replay_cave_throw(self, f64(self.aim[0]), f64(self.aim[1]))
        }

        if gd.is_action_just_pressed("rc_drop") {
            replay_cave_drop(self, 0)
        }

        if gd.is_action_just_pressed("rc_heal") {
            replay_cave_issue(self, game.Action{verb = .Heal})
        }

        if gd.is_action_just_pressed("rc_set_down") {
            replay_cave_issue(self, game.Action{verb = .Set_Down})
        }
    }

    cave_motion_control(self, dt, &control)
    cave_motion_flush(self)
    err := self.room.ready ? rgd.room_frame(&self.room, dt, control) : rgd.session_frame(self.session, dt, control)
    debuggd.session_diagnostics_frame(&self.diagnostics, self.session)

    if cave_moderation_removed(self) {
        return
    }

    if err != .None {
        gd.print_str(fmt.tprintf("REPLAY_CAVE_FAIL frame=%v", err))
        return
    }

    if self.room.ready && self.room.recovery.ready && self.room.migrations > self.noticed_migration {
        self.noticed_migration = self.room.migrations
        self.recovery_notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 4000
    }

    if !scenegd.session_tick_phase(self.session, &self.rock_phase, dt) {
        self.rock_phase.fraction = 0
    }

    cave_feedback_prepare(self, dt)
    changes: [320]v.Change(net.Net_Event(game.Event))
    n := rgd.session_changes(self.session, changes[:])

    for change in changes[:n] {
        cave_feedback_change(self, change)
        event := change.occurrence.value

        if event.kind == .Gameplay && change.kind == .Begin {
            self.effects += 1
        }

        if event.kind == .Action_Result &&
           event.seat == seat &&
           (change.kind == .Confirm || (change.kind == .Begin && change.confirmed)) {
            if change.occurrence.id.epoch < self.verdict_epoch {
                continue
            }

            if change.occurrence.id.epoch > self.verdict_epoch {
                self.verdict_epoch, self.last_verdict = change.occurrence.id.epoch, 0
            }

            if event.sequence <= self.last_verdict {
                continue
            }

            self.last_verdict = event.sequence

            if event.applied {
                self.accepted += 1
            } else {
                self.rejected += 1
            }
        }
    }

    lobby_frame(self)
    observed, has_observed := rgd.session_authority_state(self.session)
    rgd.session_comms_frame(&self.comms, self.session, has_observed ? observed.state.lobby.names[:] : nil)
    replay_cave_paint(self)
    cave_feedback_paint(self)
    social_paint(self)
    cave_moderation_frame(self)
}

replay_cave_issue :: proc(self: ^ReplayCave, action: game.Action) {
    action := action

    if !cave_motion_action(self, &action) {
        return
    }

    err: net.Error

    if self.room.ready {
        _, err = rgd.room_issue(&self.room, action)
    } else {
        _, err = rgd.session_issue(self.session, action)
    }

    if err != .None {
        gd.print_str(fmt.tprintf("REPLAY_CAVE_ACTION %v", err))
    }
}

replay_cave_paint :: proc(self: ^ReplayCave) {
    frame, ok := rgd.session_state(self.session)

    if !ok {
        gd.set_text(cast(gd.Object)self.status, "Joining the cave…")
        return
    }

    w := frame.state
    cave_motion_present(self, &w)

    if w.lobby.phase == .Waiting {
        gd.set_string(self.status, "text", "Waiting for the party")
        return
    }

    def := game.world_floor(&w)

    if self.scenery_depth != w.depth || self.scenery_seed != w.seed {
        if self.scenery != nil {
            gd.node_queue_free(self.scenery)
        }

        self.scenery = gd.instantiate(self.floor_scenes[w.depth - 1])
        gd.add_child(self.stage, self.scenery)
        decoration := game.scatter(w.seed, w.depth)
        self.scatter_checksum = decoration.checksum

        for item in decoration.items[:decoration.count] {
            label := gd.new_label()
            gd.add_child(self.scenery, label)
            gd.set_string(label, "text", item.kind == 0 ? "🪨" : "🍄")
            gd.control_set_position(label, {f32(item.x), f32(item.y)}, false)
        }

        gd.print_str(fmt.tprintf("REPLAY_CAVE_SCATTER depth=%d sum=%d", w.depth, decoration.checksum))
        self.scenery_depth, self.scenery_seed = w.depth, w.seed
    }

    instances: [64]scenegd.Instance2
    n := 0

    for player, i in w.players {
        if !player.connected {
            continue
        }

        instances[n] = instance(u64(i + 1), player.position, {1, 1, 1, 1})
        n += 1
    }

    scenegd.nodes_present(&self.players, instances[:n])

    for player, i in w.players {
        if node, found := scenegd.nodes_get(&self.players, u64(i + 1)); found {
            gd.set_text(cast(gd.Object)gd.get_node(node, "Glyph"), player.hp > 0 ? "⛏" : "💀")
        }
    }

    instances[0] = instance(1, def.chest, {1, 1, 1, 1})
    scenegd.nodes_present(&self.chest, instances[:1])
    instances[0] = instance(1, def.door, {1, 1, 1, 1})
    scenegd.nodes_present(&self.door, instances[:1])

    if node, found := scenegd.nodes_get(&self.door, 1); found {
        gd.set_text(cast(gd.Object)gd.get_node(node, "Glyph"), w.door_open ? "🕳" : "🚪")
    }

    instances[0] = instance(1, w.relic.position, {1, 1, 1, 1})
    scenegd.nodes_present(&self.relic, instances[:1])
    n = 0

    for entity, i in w.dwellers.values {
        if !w.dwellers.alive[i] {
            continue
        }

        instances[n] = instance(u64(w.dwellers.generations[i]) << 32 | u64(i + 1), entity.position, {1, 1, 1, 1})
        n += 1
    }

    scenegd.nodes_present(&self.dwellers, instances[:n])

    for entity, i in w.dwellers.values {
        if !w.dwellers.alive[i] {
            continue
        }

        if node, found := scenegd.nodes_get(&self.dwellers, u64(w.dwellers.generations[i]) << 32 | u64(i + 1)); found {
            gd.set_text(
                cast(gd.Object)gd.get_node(node, "Glyph"),
                entity.mood == 1 ? "😈" : entity.mood == 2 ? "💨" : "🦇",
            )
        }
    }

    n = 0

    for entity, i in w.pickups.values {
        if !w.pickups.alive[i] {
            continue
        }

        instances[n] = instance(u64(w.pickups.generations[i]) << 32 | u64(i + 1), entity.position, {1, 1, 1, 1})
        n += 1
    }

    scenegd.nodes_present(&self.pickups, instances[:n])

    for entity, i in w.pickups.values {
        if !w.pickups.alive[i] {
            continue
        }

        if node, found := scenegd.nodes_get(&self.pickups, u64(w.pickups.generations[i]) << 32 | u64(i + 1)); found {
            gd.set_text(cast(gd.Object)gd.get_node(node, "Glyph"), entity.stack.item == game.GEM ? "💎" : "🔦")
        }
    }

    n = 0

    for entity, i in w.rocks.values {
        if !w.rocks.alive[i] {
            continue
        }

        position := cave_rock_position(&w, i, self.rock_phase.fraction)
        instances[n] = instance(u64(w.rocks.generations[i]) << 32 | u64(i + 1), position, {1, 1, 1, 1})
        n += 1
    }

    scenegd.nodes_present(&self.rocks, instances[:n])

    for inst in instances[:n] {
        if node, exists := scenegd.nodes_get(&self.rocks, inst.key); exists {
            glyph := cast(gd.Control)gd.get_node(node, "Glyph")
            gd.control_set_position(glyph, -gd.control_get_combined_minimum_size(glyph) * .5, false)
        }
    }

    seat := rgd.session_seat(self.session)
    gd.set_string(
        cast(gd.Object)self.status,
        "text",
        fmt.ctprintf(
            "Floor %d / 2    Wave %d    Dwellers %d    %s",
            w.depth,
            w.director.wave,
            w.dwellers.count,
            w.won ? "ESCAPED" : w.director.done ? "Floor cleared — gather at the open door" : "Explore and survive",
        ),
    )

    if self.room.ready {
        if self.room.phase == .Freezing ||
           self.room.phase == .Releasing ||
           self.room.phase == .Claiming ||
           self.room.phase == .Recovering {
            gd.set_text(cast(gd.Object)self.status, "Changing host…")
        } else if self.session.fenced || (!self.session.authority && self.session.client.phase != .Running) {
            gd.set_text(cast(gd.Object)self.status, "Reconnecting to the cave…")
        } else if gd.time_get_ticks_msec(gd.singleton_time()) < self.recovery_notice_until {
            gd.set_text(
                cast(gd.Object)self.status,
                self.room.recovery.known_lost_ticks > 0 ? "Reconnected. Some recent progress was rolled back." : "Host changed. Back in the cave.",
            )
        }
    }

    if seat != 0 {
        player := w.players[seat - 1]
        gd.set_string(
            cast(gd.Object)self.inventory,
            "text",
            fmt.ctprintf(
                "SEAT %d\nHP %d / 100\nStamina %d / 10\n\n💎 %d\n🔦 %d\n\nSlain %d\nDeaths %d",
                seat,
                player.hp,
                player.stamina,
                p.inventory_count(player.bag[:], game.GEM),
                p.inventory_count(player.bag[:], game.TORCH),
                player.slain,
                player.deaths,
            ),
        )
        message: cstring = "Explore the cave and clear the waves."

        if p.in_reach(player.position, def.chest, game.REACH) {
            message = "E: take chest loot"
        }

        if p.in_reach(player.position, def.door, game.REACH) {
            message = "E: open / close the door"
        }

        if w.relic.carrier == 0 && p.in_reach(player.position, w.relic.position, game.REACH) {
            message = "E: carry the relic"
        }

        if w.relic.carrier == seat {
            message = "G: set down the relic"
        }

        if player.hp == 0 {
            message = "Downed — a nearby friend can revive you."
        }

        if gd.time_get_ticks_msec(gd.singleton_time()) < self.save_notice_until {
            message = self.save_ok ? "Game saved." : "Couldn't save the game."
        }

        when gd.IS_WEB {
            if self.browser.save.phase == .Writing {
                message = "Saving…"
            }
        }

        gd.set_text(cast(gd.Object)self.prompt, message)
    }
}

instance :: proc(key: u64, position: [2]f32, color: gd.Color) -> scenegd.Instance2 {
    return {key = key, pose = {position = position}, scale = {1, 1}, color = color}
}

replay_cave_exit_tree :: proc(self: ^ReplayCave) {
    cave_feedback_destroy(self)
    browser_cave_close(self)
    storagegd.name_profile_close(&self.name_profile)
    comms.destroy(&self.comms)
    dg.destroy(&self.diagnostics)
    definitions_close(self)
    debuggd.debug_overlay_destroy(&self.debug)

    if self.room.ready {
        rgd.room_close(&self.room)
    } else if self.session != nil {
        rgd.session_close(self.session)
    }

    online_close(self)
    scenegd.nodes_destroy(&self.players)
    scenegd.nodes_destroy(&self.chest)
    scenegd.nodes_destroy(&self.door)
    scenegd.nodes_destroy(&self.relic)
    scenegd.nodes_destroy(&self.dwellers)
    scenegd.nodes_destroy(&self.pickups)
    scenegd.nodes_destroy(&self.rocks)
}

@(gd_method)
replay_cave_walk_to :: proc(self: ^ReplayCave, x, y: f64) {
    self.walk_target = {f32(x), f32(y)}
    self.walking = true
}

@(gd_method)
replay_cave_loot :: proc(self: ^ReplayCave, slot: gd.Int) {
    if slot >= 0 && slot < 8 {
        replay_cave_issue(self, game.Action{verb = .Take, index = u16(slot)})
    }
}

@(gd_method)
replay_cave_door :: proc(self: ^ReplayCave) {
    replay_cave_issue(self, game.Action{verb = .Door})
}

@(gd_method)
replay_cave_drop :: proc(self: ^ReplayCave, slot: gd.Int) {
    if slot >= 0 && slot < 6 {
        replay_cave_issue(self, game.Action{verb = .Drop, index = u16(slot)})
    }
}

@(gd_method)
replay_cave_throw :: proc(self: ^ReplayCave, x, y: f64) {
    length := math.sqrt(x * x + y * y)

    if length > 0 {
        replay_cave_issue(self, game.Action{verb = .Throw, aim = {f32(x / length), f32(y / length)}})
    }
}

@(gd_method)
replay_cave_use :: proc(self: ^ReplayCave) {
    frame, ok := rgd.session_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 {
        return
    }

    w := frame.state
    cave_motion_present(self, &w)
    position := w.players[seat - 1].position
    def := game.world_floor(&w)

    for pickup, i in w.pickups.values {
        if w.pickups.alive[i] && p.in_reach(position, pickup.position, game.REACH) {
            replay_cave_issue(self, game.Action{verb = .Grab, index = u16(i), generation = w.pickups.generations[i]})
            return
        }
    }

    for player, i in w.players {
        if player.connected && player.hp == 0 && p.in_reach(position, player.position, game.REACH) {
            replay_cave_issue(self, game.Action{verb = .Revive, index = u16(i)})
            return
        }
    }

    if p.in_reach(position, def.chest, game.REACH) {
        for stack, i in w.chest {
            if stack.count > 0 {
                replay_cave_loot(self, gd.Int(i))
                return
            }
        }
    }

    if p.in_reach(position, def.door, game.REACH) {
        replay_cave_door(self)
        return
    }

    if p.in_reach(position, w.relic.position, game.REACH) {
        replay_cave_issue(self, game.Action{verb = .Carry})
    }
}

@(gd_method)
replay_cave_probe_ready :: proc(self: ^ReplayCave) -> bool {
    if self.session == nil {
        return false
    }

    _, ok := rgd.session_state(self.session)
    return ok
}

@(gd_method)
replay_cave_probe_x :: proc(self: ^ReplayCave) -> f64 {
    frame, ok := rgd.session_state(self.session)
    seat := rgd.session_seat(self.session)
    return ok && seat != 0 ? f64(frame.state.players[seat - 1].position[0]) : 0
}

@(gd_method)
replay_cave_probe_gems :: proc(self: ^ReplayCave) -> gd.Int {
    frame, _ := rgd.session_state(self.session)
    return gd.Int(game.world_items(&frame.state, game.GEM))
}

@(gd_method)
replay_cave_probe_bag :: proc(self: ^ReplayCave) -> gd.Int {
    frame, _ := rgd.session_state(self.session)
    seat := rgd.session_seat(self.session)
    return seat != 0 ? gd.Int(p.inventory_count(frame.state.players[seat - 1].bag[:], game.GEM)) : 0
}

@(gd_method)
replay_cave_probe_door :: proc(self: ^ReplayCave) -> bool {
    frame, _ := rgd.session_state(self.session)
    return frame.state.door_open
}

@(gd_method)
replay_cave_probe_accepted :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.accepted)
}

@(gd_method)
replay_cave_probe_chest :: proc(self: ^ReplayCave, index: gd.Int) -> gd.Int {
    if index < 0 || index >= 8 {
        return -1
    }

    frame, _ := rgd.session_state(self.session)
    return gd.Int(frame.state.chest[index].count)
}

@(gd_method)
replay_cave_probe_players :: proc(self: ^ReplayCave) -> gd.Int {
    frame, _ := rgd.session_state(self.session)
    count := 0

    for player in frame.state.players {
        if player.connected {
            count += 1
        }
    }

    return gd.Int(count)
}

@(gd_method)
replay_cave_save :: proc(self: ^ReplayCave) -> bool {
    frame, ok := rgd.session_state(self.session)

    if !ok || !self.session.authority {
        return false
    }

    if self.room.ready {
        return self.online.enabled && rgd.room_save(&self.room) == .None
    }

    when gd.IS_WEB {
        if self.browser.save.phase == .Writing {
            return false
        }

        self.save_ok = false

        if !rgd.browser_checkpoint_save(&self.browser.save, self.session) {
            self.save_notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 4000
            return false
        }

        return true
    }

    result := rgd.session_save(self.session, cave_param("REPLAY_CAVE_SAVE", "user://cave.replay"))
    self.save_ok = result.error == .None
    self.save_notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 3000

    if result.error != .None {
        gd.print_str(fmt.tprintf("REPLAY_CAVE_SAVE_ERROR %v", result))
        return false
    }

    self.saved_tick, self.saved_hash = frame.tick, replay_cave_hash(frame)
    gd.print_str(fmt.tprintf("REPLAY_CAVE_SAVED tick=%d hash=%d", self.saved_tick, self.saved_hash))
    return true
}

replay_cave_hash :: proc(frame: r.Frame(game.World)) -> u64 {
    schema: sc.Schema
    defer sc.destroy(&schema)

    if sc.init(&schema, r.Frame(game.World)).error != .None {
        return 0
    }

    bytes := make([]u8, schema.wire_size)
    defer delete(bytes)

    if sc.encode(&schema, frame, bytes).error != .None {
        return 0
    }

    return sc.digest(bytes)
}

@(gd_method)
replay_cave_probe_saved_hash :: proc(self: ^ReplayCave) -> gd.Int {
    return transmute(i64)self.saved_hash
}

@(gd_method)
replay_cave_probe_restored_hash :: proc(self: ^ReplayCave) -> gd.Int {
    return transmute(i64)self.restored_hash
}

@(gd_method)
replay_cave_probe_saved_tick :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.saved_tick)
}

@(gd_method)
replay_cave_probe_restored_tick :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.restored_tick)
}

@(gd_method)
replay_cave_probe_epoch :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch)
}

@(gd_method)
replay_cave_backup_to :: proc(self: ^ReplayCave, seat: gd.Int) -> bool {
    if seat < 1 || seat > game.SEATS {
        return false
    }

    return rgd.session_backup_seat(self.session, u16(seat), game.HZ / 2) == .None
}

@(gd_method)
replay_cave_probe_backup_tick :: proc(self: ^ReplayCave) -> gd.Int {
    receipt, ok := rgd.session_backup_receipt(self.session)
    return ok ? gd.Int(receipt.archive.tick) : 0
}

@(gd_method)
replay_cave_probe_backup_sequence :: proc(self: ^ReplayCave) -> gd.Int {
    receipt, ok := rgd.session_backup_receipt(self.session)
    return ok ? gd.Int(receipt.archive.sequence) : 0
}

@(gd_method)
replay_cave_probe_backup_play :: proc(self: ^ReplayCave) -> bool {
    receipt, ok := rgd.session_backup_receipt(self.session)

    if !ok {
        return false
    }

    frame: r.Frame(game.World)

    if self.session.authority {
        frame, ok = r.read(&self.session.server.timeline, receipt.archive.tick)
    } else {
        cp, found := rec.receiver_checkpoint(&self.session.link.incoming, receipt.archive)

        if !found {
            return false
        }

        frame = cp.frame
    }

    return(
        ok &&
        frame.state.door_open &&
        p.inventory_count(frame.state.players[1].bag[:], game.GEM) == 3 &&
        self.session.link.error == .None &&
        self.session.link.model_error == .None \
    )
}

@(gd_method)
replay_cave_probe_protocol_rejections :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(
        self.session.authority ? self.session.server.stats.rejected_packets : self.session.client.stats.rejected_packets,
    )
}

cave_control_key :: proc(value: string) -> (auth.Key, bool) {
    key: auth.Key

    if len(value) != 64 {
        return key, false
    }

    for i in 0 ..< 64 {
        c := value[i]
        digit := c >= '0' && c <= '9' ? int(c - '0') : c >= 'a' && c <= 'f' ? int(c - 'a') + 10 : -1

        if digit < 0 {
            return key, false
        }

        key[i / 2] = key[i / 2] << 4 | u8(digit)
    }

    return key, true
}

@(gd_method)
replay_cave_handoff :: proc(self: ^ReplayCave) -> bool {
    return rgd.room_handoff(&self.room) == .None
}

@(gd_method)
replay_cave_probe_migrations :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.room.migrations)
}

@(gd_method)
replay_cave_probe_room_phase :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.room.phase)
}

@(gd_method)
replay_cave_probe_steady :: proc(self: ^ReplayCave) -> bool {
    return(
        self.session.ready &&
        !self.session.fenced &&
        (self.session.authority || self.session.client.phase == .Running) \
    )
}

@(gd_method)
replay_cave_probe_recovery_tick :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.room.recovery.checkpoint_tick)
}

@(gd_method)
replay_cave_probe_prepared_tick :: proc(self: ^ReplayCave) -> gd.Int {
    return self.room.rpc.reply.prepared ? gd.Int(self.room.rpc.reply.point.archive.tick) : 0
}

@(gd_method)
replay_cave_probe_lost_ticks :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.room.recovery.known_lost_ticks)
}

@(gd_method)
replay_cave_probe_interruption :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.room.recovery.interruption_ms)
}

@(gd_method)
replay_cave_probe_recovery_kind :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.room.lease.view.recovery)
}

@(gd_method)
replay_cave_probe_incarnation :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.room.options.identity.incarnation)
}

@(gd_method)
replay_cave_probe_seat :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(rgd.session_seat(self.session))
}

@(gd_method)
replay_cave_pause_control :: proc(self: ^ReplayCave, paused: bool) {
    self.room.control_paused = paused
}

@(gd_method)
replay_cave_probe_fenced :: proc(self: ^ReplayCave) -> bool {
    return self.session.fenced
}

@(gd_method)
replay_cave_probe_head :: proc(self: ^ReplayCave) -> gd.Int {
    return gd.Int(self.session.authority ? self.session.server.timeline.head : self.session.client.timeline.head)
}

// Acceptance uses authoritative arrival rather than a predicted x coordinate.
@(gd_method)
replay_cave_probe_near :: proc(self: ^ReplayCave, x, y: f64) -> bool {
    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)
    return ok && seat != 0 && p.in_reach(frame.state.players[seat - 1].position, {f32(x), f32(y)}, 20)
}

@(gd_method)
replay_cave_drop_signaling :: proc(self: ^ReplayCave) {
    transportgd.rtc_drop_signaling(&self.session.rtc)
}

@(gd_method)
replay_cave_probe_signaling :: proc(self: ^ReplayCave, field: gd.Int) -> gd.Int {
    switch field {
    case 0:
        return gd.Int(self.session.rtc.signaling_resumes)
    case 1:
        return gd.Int(self.session.rtc.connection_serial)
    case 2:
        return gd.Int(self.session.rtc.id)
    }

    return 0
}
