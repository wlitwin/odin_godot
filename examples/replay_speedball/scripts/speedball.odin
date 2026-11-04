//gd:extends Node2D
//gd:class ReplaySpeedball
package replay_speedball

import "core:fmt"
import "core:math"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import p "godot:replay/play"
import net "godot:replay/net"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/pitch"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import lb "godot:replay/lobby"
import debuggd "godot:replay/godot/debug"
import inputgd "godot:replay/godot/input"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

ReplaySpeedball :: struct {
    owner:                                                                       gd.Node2d,
    comms:                                                                       co.Comms,
    diagnostics:                                                                 dg.Diagnostics,
    ui:                                                                          [1]Speedball_UI,
    views_ready, keyboard_captured:                                              bool,
    display_name:                                                                lb.Name,
    name_sequence:                                                               u64,
    name_submitted:                                                              bool,
    status:                                                                      gd.Label `gd:"onready=Status"`,
    session:                                                                     ^rgd.Session(
        game.World,
        game.Controls,
        game.Action,
        game.Event,
        game.SEATS,
    ),
    standalone:                                                                  rgd.Session(
        game.World,
        game.Controls,
        game.Action,
        game.Event,
        game.SEATS,
    ),
    room:                                                                        rgd.Room(
        game.World,
        game.Controls,
        game.Action,
        game.Event,
        game.SEATS,
    ),
    recovery_probe:                                                              [1]Pitch_Recovery,
    view_epoch:                                                                  u64,
    view_round, paint_round:                                                     u32,
    name_profile:                                                                storagegd.Name_Profile,
    profile_enabled, profile_name_loaded, profile_identity_ready:                bool,
    browser_identity:                                                            storagegd.Browser_Identity,
    browser_launch:                                                              string,
    browser_save:                                                                [1]Speedball_Browser_Save,
    online:                                                                      Speedball_Online,
    profile_token:                                                               net.Token,
    save_tick, save_hash, restored_tick, restored_hash:                          u64,
    restored_exact:                                                              bool,
    players, ball:                                                               scenegd.Nodes2,
    smoothing:                                                                   [game.SEATS + 1]v.Smoother2,
    ready, spiked, spike_visible, done:                                          bool,
    spike_node_start, own_spike_seen:                                            bool,
    bot:                                                                         string,
    started_ms, done_ms, reset_seen, correction_seen:                            u64,
    spike_at_ms, spike_at_tick, spike_first_sequence, last_verdict:              u64,
    spike_from:                                                                  [2]f32,
    local_kicks, remote_kicks, speculative_kicks, spike_applied, spike_rejected: u32,
    local_canceled, remote_canceled:                                             u32,
    correction_count:                                                            u64,
    correction_sum, correction_max:                                              f64,
    flash_left:                                                                  f64,
    flash_id:                                                                    r.Event_Id,
    goal_seen:                                                                   u16,
    ball_reset:                                                                  u32,
}

replay_speedball_ready :: proc(self: ^ReplaySpeedball) {
    self.session = &self.standalone
    install_controls()
    self.views_ready =
        scenegd.nodes_load(&self.players, self.owner, "res://views/kicker.tscn", game.SEATS) &&
        scenegd.nodes_load(&self.ball, self.owner, "res://views/ball.tscn", 1)

    if !self.views_ready || !co.init(&self.comms) || !dg.init(&self.diagnostics) {
        gd.print_str("REPLAY_SPEEDBALL_FAIL views/social")
        return
    }

    self.bot = strings.clone(speedball_param("RSB_BOT", ""))
    ui_ready(self)
    online_ready(self)
    role := speedball_param("RSB_ROLE", "")

    if role != "" {
        when gd.IS_WEB {
            self.browser_launch = strings.clone(role)
        } else {
            connect_pitch(self, role, false, speedball_int("RSB_RESUME", 0) == 1)
        }
    }

    gd.print_str("REPLAY_SPEEDBALL_UI_READY")
}

connect_pitch :: proc(self: ^ReplaySpeedball, role: string, manual: bool, resume: bool = false) {
    if self.ready || !self.views_ready || (self.online.party.active && !self.online.launch) {
        return
    }

    if !profile_available(self) {
        ui_notice(self, self.name_profile.failed ? "Could not load your player profile." : "Loading player profile…")
        return
    }

    when gd.IS_WEB {
        if !self.online.launch && role != "solo" {
            ui_notice(self, "Browser multiplayer uses a configured party service.")
            return
        }
    }

    opts := rgd.SESSION_OPTIONS

    switch role {
    case "solo":
        opts.role = .Solo
    case "host":
        opts.role = .Host
    case "server":
        opts.role = .Server
    case "client":
        opts.role = .Client
    case "observer":
        opts.role = .Observer
    case:
        return
    }

    port := int(gd.range_get_value(self.ui[0].port))

    if port < 1 || port > 65535 {
        ui_notice(self, "Use a port from 1 to 65535.")
        return
    }

    text := gd.line_edit_get_text(self.ui[0].name)
    name, valid := lb.name(gd.gd_string_to_odin(text))
    gd.free_string(text)

    if !valid {
        ui_notice(self, "Enter a display name.")
        return
    }

    self.display_name = name
    address := gd.line_edit_get_text(self.ui[0].address)
    defer gd.free_string(address)
    address_text := strings.trim_space(gd.gd_string_to_odin(address))

    if (opts.role == .Client || opts.role == .Observer) && len(address_text) == 0 {
        ui_notice(self, "Enter a host address.")
        return
    }

    opts.address = fmt.ctprintf("%s", address_text)
    opts.port = u16(port)
    token, profile_ok := profile_connect(self, name)

    if !profile_ok {
        return
    }

    opts.token = token
    self.profile_token = token
    opts.latency_ms = u32(speedball_int("RSB_LATENCY", 0))
    opts.jitter_ms = u32(speedball_int("RSB_JITTER", 0))
    opts.loss_permyriad = u32(speedball_int("RSB_LOSS", 0))
    opts.duplicate_permyriad = u32(speedball_int("RSB_DUPLICATE", 0))
    opts.discover_epoch = speedball_int("RSB_COORD_PORT", 0) == 0 && !self.online.launch
    opts.network.content = game.CONTENT
    opts.network.hz, opts.network.lead, opts.network.snapshot_every = 60, 4, 3

    if !rgd.session_comms_enable(&opts) || !debuggd.session_diagnostics_enable(&opts) {
        ui_notice(self, "Could not configure social channels.")
        return
    }

    minimum := u8(clamp(speedball_int("RSB_PLAYERS", manual || opts.role == .Solo ? 1 : 2), 1, game.SEATS))
    goals := u8(clamp(speedball_int("RSB_GOALS", 3), 1, 255))
    initial := game.initial(opts.role == .Server, minimum, goals, manual && opts.role != .Server)
    err: net.Error

    if resume {
        err = resume_pitch(self, opts)
    } else {
        err = open_session(self, initial, opts)
    }

    if err != .None {
        if !resume {
            ui_notice(self, fmt.tprintf("Connection failed: %v", err))
        }

        gd.print_str(fmt.tprintf("RSB_CONNECT_FAILED %v", err))
        return
    }

    self.ready = true
    self.started_ms = gd.time_get_ticks_msec(gd.singleton_time())

    if !self.session.authority && !self.session.client.spectator {
        v.journal_set_policy(&self.session.client.journal, effect_policy)
    }

    ui_notice(
        self,
        resume ? "Saved pitch restored." : opts.role == .Client ? "Joining the pitch…" : "Pitch open — invite players, then start.",
    )
    gd.print_str("REPLAY_SPEEDBALL_READY")
}

effect_policy :: proc(e: net.Net_Event(game.Event)) -> v.Policy {
    return e.kind == .Gameplay && e.value.kind == .Goal ? v.Policy.Confirmed : v.Policy.Speculative
}

install_controls :: proc() {
    if gd.has_action("rsb_left") {
        return
    }

    inputgd.bind_key("rsb_left", .A)
    inputgd.bind_key("rsb_right", .D)
    inputgd.bind_key("rsb_up", .W)
    inputgd.bind_key("rsb_down", .S)
    inputgd.bind_key("rsb_kick", .Space)
    inputgd.bind_key("rsb_spike", .E)
}

sample :: proc(self: ^ReplaySpeedball, w: game.World, seat: u16) -> game.Controls {
    c: game.Controls

    if !w.started || seat == 0 || self.keyboard_captured {
        return c
    }

    if self.bot == "" {
        if gd.is_action_pressed("rsb_left") {
            c.move[0] -= 1
        }

        if gd.is_action_pressed("rsb_right") {
            c.move[0] += 1
        }

        if gd.is_action_pressed("rsb_up") {
            c.move[1] -= 1
        }

        if gd.is_action_pressed("rsb_down") {
            c.move[1] += 1
        }

        if gd.is_action_pressed("rsb_kick") {
            c.buttons |= game.KICK
        }

        return c
    }

    me := w.players[seat - 1]
    b := w.ball.motion.position
    rel := b - me.motion.position
    steer: [2]f32

    if self.bot == "spiker" && !self.spiked {
        steer = p.unit2(rel)
    } else if self.bot == "striker" {
        to_goal := p.unit2([2]f32{me.team == 1 ? f32(640) : 0, 180} - b)
        aligned := rel[0] * to_goal[0] + rel[1] * to_goal[1]

        if aligned > 4 {
            steer = p.unit2(rel)

            if p.length_sq2(rel) < (game.KICK_REACH + 8) * (game.KICK_REACH + 8) {
                c.buttons |= game.KICK
            }
        } else {
            steer = p.unit2(b - to_goal * 31 - me.motion.position)

            if p.length_sq2(rel) < 29 * 29 * 4 {
                n := p.unit2(rel)
                tangent := [2]f32{-n[1], n[0]}

                if tangent[0] * steer[0] + tangent[1] * steer[1] < 0 {
                    tangent = -tangent
                }

                steer = p.unit2(tangent - n * 0.6)
            }
        }
    }

    for axis in 0 ..< 2 {
        if steer[axis] > 0.3 {
            c.move[axis] = 1
        } else if steer[axis] < -0.3 {
            c.move[axis] = -1
        }
    }

    return c
}

replay_speedball_process :: proc(self: ^ReplaySpeedball, dt: f64) {
    profile_frame(self)
    browser_save_frame(self)
    online_frame(self)
    self.keyboard_captured = ui_input(self)
    ui_frame(self)

    if !self.ready {
        return
    }

    defer social_frame(self)
    now := gd.time_get_ticks_msec(gd.singleton_time())
    f, available := rgd.session_state(self.session)
    seat := rgd.session_seat(self.session)
    control := sample(self, f.state, seat)

    if available && seat > 0 && !self.done && !self.keyboard_captured {
        want := gd.is_action_just_pressed("rsb_spike")

        // Two independent commands, close enough that both remain valid across
        // the runner's one-command-per-seat-per-tick service interval.
        if self.bot == "spiker" &&
           !self.spiked &&
           f.state.ball.hold == 0 &&
           p.length_sq2(f.state.ball.motion.position - f.state.players[seat - 1].motion.position) < 30 * 30 {
            want = true
        }

        if want {
            seq, err := issue(self, game.Action{spike = true})

            if err == .None && !self.spiked {
                self.spiked, self.spike_at_ms, self.spike_at_tick, self.spike_first_sequence = true, now, f.tick, seq
                self.spike_from = f.state.ball.motion.position

                if node, found := scenegd.nodes_get(&self.ball, 1); found {
                    self.spike_from = gd.node2d_get_position(node)
                    self.spike_node_start = true
                }

                _, second := issue(self, game.Action{spike = true})
                gd.print_str(fmt.tprintf("RSB_SPIKE_SENT tick=%d sequence=%d second=%v", f.tick, seq, second))
            }
        }
    }

    if err := frame_session(self, dt, control); err != .None {
        gd.print_str(fmt.tprintf("REPLAY_SPEEDBALL_FAIL frame=%v", err))
        return
    }

    observe_room(self)
    observe_round(self)

    if !self.session.authority && self.reset_seen != self.session.client.view_reset {
        self.reset_seen = self.session.client.view_reset
        self.smoothing = {}

        if !self.session.client.spectator {
            v.journal_set_policy(&self.session.client.journal, effect_policy)
        }

        gd.print_str(fmt.tprintf("RSB_SEATED seat=%d reset=%d", self.session.client.seat, self.reset_seen))
    }

    if !self.session.authority && self.session.client.correction.serial > self.correction_seen {
        note := self.session.client.correction
        self.correction_seen = note.serial

        for i in 0 ..< game.SEATS {
            a, b := note.before.state.players[i], note.after.state.players[i]
            v.smooth_correct(
                &self.smoothing[i],
                a.motion.position,
                b.motion.position,
                discontinuity = a.connected != b.connected,
            )
        }

        a, b := note.before.state.ball, note.after.state.ball
        v.smooth_correct(
            &self.smoothing[game.SEATS],
            a.motion.position,
            b.motion.position,
            discontinuity = a.reset != b.reset,
        )
        error := f64(math.sqrt(p.length_sq2(a.motion.position - b.motion.position)))

        if error > 0.001 {
            self.correction_count += 1
            self.correction_sum += error
            self.correction_max = max(self.correction_max, error)
        }
    }

    changes: [320]v.Change(net.Net_Event(game.Event))
    n := rgd.session_changes(self.session, changes[:])

    for change in changes[:n] {
        e := change.occurrence.value

        if e.kind == .Action_Result &&
           e.seat == seat &&
           (change.kind == .Confirm || change.confirmed) &&
           e.sequence > self.last_verdict {
            self.last_verdict = e.sequence

            if self.spiked &&
               self.spike_first_sequence != 0 &&
               e.sequence >= self.spike_first_sequence &&
               e.sequence <= self.spike_first_sequence + 1 {
                if e.applied {
                    self.spike_applied += 1
                } else {
                    self.spike_rejected += 1
                }
            }

            if e.sequence == self.name_sequence && !e.applied {
                self.name_submitted = false
            }

            gd.print_str(fmt.tprintf("RSB_ACTION sequence=%d applied=%v reason=%v", e.sequence, e.applied, e.reason))
        }

        if e.kind != .Gameplay {
            continue
        }

        if change.kind == .Cancel {
            if change.occurrence.id == self.flash_id {
                self.flash_left = 0
            }

            if e.value.kind == .Kick {
                if e.seat == seat {
                    self.local_canceled += 1
                } else {
                    self.remote_canceled += 1
                }
            }

            continue
        }

        if change.kind != .Begin {
            continue
        }

        if e.value.kind == .Kick {
            self.flash_left, self.flash_id = 0.12, change.occurrence.id

            if e.seat == seat {
                self.local_kicks += 1

                if !self.session.authority && change.occurrence.id.tick > self.session.client.authority_frame.tick {
                    self.speculative_kicks += 1
                }
            } else {
                self.remote_kicks += 1
            }

            gd.print_str(
                fmt.tprintf(
                    "RSB_KICK seat=%d tick=%d local=%v confirmed=%v",
                    e.seat,
                    change.occurrence.id.tick,
                    e.seat == seat,
                    change.confirmed,
                ),
            )
        }

        if e.value.kind == .Spike && self.session.authority {
            gd.print_str(fmt.tprintf("RSB_SPIKE seat=%d tick=%d", e.seat, change.occurrence.id.tick))
        }

        if e.value.kind == .Spike && e.seat == seat {
            self.own_spike_seen = true
        }
    }

    f, available = rgd.session_state(self.session)

    if available {
        paint(self, f, dt)

        if self.spiked && self.spike_node_start && self.own_spike_seen && !self.spike_visible {
            if node, found := scenegd.nodes_get(&self.ball, 1);
               found && p.length_sq2(gd.node2d_get_position(node) - self.spike_from) > 12 * 12 {
                self.spike_visible = true
                gd.print_str(
                    fmt.tprintf(
                        "RSB_SPIKE_LOCAL ticks=%d ms=%d acknowledged=%v",
                        f.tick - self.spike_at_tick,
                        gd.time_get_ticks_msec(gd.singleton_time()) - self.spike_at_ms,
                        self.last_verdict >= self.spike_first_sequence,
                    ),
                )
            }
        }

        truth := self.session.authority ? f : self.session.client.authority_frame
        score := truth.state.score
        count := u16(score.left) + u16(score.right)

        if count > self.goal_seen {
            self.goal_seen = count
            gd.print_str(fmt.tprintf("RSB_SCORE left=%d right=%d winner=%d", score.left, score.right, score.winner))
        }

        if score.winner == 0 {
            self.done = false
        }

        if score.winner != 0 && !self.done {
            self.done, self.done_ms = true, now
        }

        if self.done &&
           now - self.done_ms > (self.session.authority ? 4000 : 2500) &&
           speedball_int("RSB_TEST", 0) == 1 {
            stats := self.session.authority ? self.session.server.stats : self.session.client.stats
            gd.print_str(
                fmt.tprintf(
                    "RSB_RESULT authority=%v left=%d right=%d winner=%d x=%.3f y=%.3f kicks=%d spikes=%d local_kicks=%d speculative_kicks=%d remote_kicks=%d local_canceled=%d remote_canceled=%d accepted=%d rejected=%d",
                    self.session.authority,
                    score.left,
                    score.right,
                    score.winner,
                    truth.state.ball.motion.position[0],
                    truth.state.ball.motion.position[1],
                    truth.state.kicks,
                    truth.state.spikes,
                    self.local_kicks,
                    self.speculative_kicks,
                    self.remote_kicks,
                    self.local_canceled,
                    self.remote_canceled,
                    self.spike_applied,
                    self.spike_rejected,
                ),
            )
            gd.print_str(
                fmt.tprintf(
                    "RSB_METRICS corrections=%d replayed=%d ball_corrections=%d ball_error_sum=%.3f ball_error_max=%.3f rx_bytes=%d tx_bytes=%d resyncs=%d",
                    stats.corrections,
                    stats.replayed_ticks,
                    self.correction_count,
                    self.correction_sum,
                    self.correction_max,
                    stats.rx_bytes,
                    stats.tx_bytes,
                    stats.resyncs,
                ),
            )
            gd.print_str("REPLAY_SPEEDBALL_PROCESS_OK")
            gd.scene_tree_quit(gd.get_tree(self.owner), 0)
        }
    }

    self.flash_left = max(self.flash_left - dt, 0)

    if speedball_int("RSB_TEST", 0) == 1 && now - self.started_ms > 55000 {
        gd.print_str("REPLAY_SPEEDBALL_FAIL timeout")
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
    }
}

paint :: proc(self: ^ReplaySpeedball, frame: r.Frame(game.World), dt: f64) {
    w := frame.state

    if self.paint_round != w.round {
        self.paint_round = w.round
        self.smoothing = {}
        self.ball_reset = 0
    }

    if !w.started {
        gd.set_text(cast(gd.Object)self.status, "Waiting for the pitch to fill…")
        return
    }

    if !self.session.authority && self.session.client.spectator {
        a, b, alpha, ok := net.client_observed(&self.session.client)

        if ok {
            w = alpha >= 1 ? b.state : a.state

            for &player, i in w.players {
                if a.state.players[i].connected == b.state.players[i].connected {
                    player.motion.position =
                        a.state.players[i].motion.position +
                        (b.state.players[i].motion.position - a.state.players[i].motion.position) * alpha
                }
            }

            if a.state.ball.reset == b.state.ball.reset {
                w.ball.motion.position =
                    a.state.ball.motion.position +
                    (b.state.ball.motion.position - a.state.ball.motion.position) * alpha
            }
        }
    }

    instances: [game.SEATS]scenegd.Instance2
    colors := [2]gd.Color{{0.35, 0.65, 1, 1}, {1, 0.62, 0.2, 1}}
    n := 0

    for player, i in w.players {
        if player.connected {
            pose := v.smooth_present(&self.smoothing[i], {position = player.motion.position}, dt)
            instances[n] = {
                key   = u64(i + 1),
                pose  = pose,
                scale = {1, 1},
                color = colors[player.team - 1],
            }
            n += 1
        }
    }

    scenegd.nodes_present(&self.players, instances[:n])

    if self.ball_reset != w.ball.reset {
        self.ball_reset = w.ball.reset
        self.smoothing[game.SEATS] = {}
    }

    pose := v.smooth_present(&self.smoothing[game.SEATS], {position = w.ball.motion.position}, dt)
    ball := [1]scenegd.Instance2 {
        {
            key = 1,
            pose = pose,
            scale = {1, 1},
            color = self.flash_left > 0 ? gd.Color{1, 0.75, 0.2, 1} : gd.Color{1, 1, 1, 1},
        },
    }
    scenegd.nodes_present(&self.ball, ball[:])
    score := self.session.authority ? w.score : self.session.client.authority_frame.state.score
    gd.set_string(
        cast(gd.Object)self.status,
        "text",
        fmt.ctprintf(
            "LEFT %d — %d RIGHT   %s",
            score.left,
            score.right,
            score.winner == 0 ? "" : score.winner == 1 ? "LEFT WINS" : "RIGHT WINS",
        ),
    )
}

replay_speedball_exit_tree :: proc(self: ^ReplaySpeedball) {
    scenegd.nodes_destroy(&self.players)
    scenegd.nodes_destroy(&self.ball)
    co.destroy(&self.comms)
    dg.destroy(&self.diagnostics)
    close_session(self)
    online_close(self)
    browser_save_close(self)
    storagegd.browser_identity_close(&self.browser_identity)
    delete(self.browser_launch)
    storagegd.name_profile_close(&self.name_profile)
    delete(self.bot)
}
