package replay_claimball
import "core:fmt"
import "core:reflect"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import auth "godot:replay/authority"
import sc "godot:replay/schema"
import rgd "godot:replay/godot"
import co "godot:replay/comms"
import v "godot:replay/view"
import game "../shared/pitch"

Pitch_Recovery :: struct {
    point:                   auth.Point,
    frame:                   r.Frame(game.World),
    checked:                 u64,
    exact, moving, complete: bool,
}

open_session :: proc(self: ^ReplayClaimball, initial: game.World, opts: rgd.Session_Options) -> net.Error {
    if self.online.launch {
        options, ok := rgd.party_room_options(&self.online.party, opts)

        if !ok {
            return .Invalid_Config
        }

        options.session.discover_epoch = false

        if opts.role == .Observer {
            options.session.replication.accept_checkpoints = false
        }

        self.session = &self.room.session
        return rgd.room_open(&self.room, r.Frame(game.World){state = initial}, game.model(), options)
    }

    port := claimball_int("RCB_COORD_PORT", 0)

    if port == 0 {
        self.session = &self.standalone
        return rgd.session_open(self.session, r.Frame(game.World){state = initial}, game.model(), opts)
    }

    member := claimball_int("RCB_MEMBER", 0)
    incarnation := claimball_int("RCB_INCARNATION", 100 + member)
    key, ok := control_key(claimball_param("RCB_COORD_KEY", ""))

    if port < 1 || port > 65535 || member < 1 || member > 3 || incarnation < 1 || !ok {
        return .Invalid_Config
    }

    options := rgd.Room_Options {
        identity            = {u64(member), u64(incarnation)},
        key                 = key,
        room                = 50,
        coordinator         = "127.0.0.1",
        control_port        = u16(port),
        bootstrap           = member == 1,
        session             = opts,
        automatic_successor = true,
    }
    options.session.replication.accept_checkpoints = member <= 2
    self.session = &self.room.session
    return rgd.room_open(&self.room, r.Frame(game.World){state = initial}, game.model(), options)
}

control_key :: proc(text: string) -> (auth.Key, bool) {
    key: auth.Key

    if len(text) != 64 {
        return key, false
    }

    for c, i in text {
        digit := c >= '0' && c <= '9' ? int(c - '0') : c >= 'a' && c <= 'f' ? int(c - 'a') + 10 : -1

        if digit < 0 {
            return key, false
        }

        key[i / 2] = key[i / 2] << 4 | u8(digit)
    }

    return key, true
}

issue :: proc(self: ^ReplayClaimball, a: game.Action) -> (u64, net.Error) {
    if self.room.ready {
        return rgd.room_issue(&self.room, a)
    }

    return rgd.session_issue(self.session, a)
}

frame_session :: proc(self: ^ReplayClaimball, dt: f64, c: game.Controls) -> net.Error {
    return self.room.ready ? rgd.room_frame(&self.room, dt, c) : rgd.session_frame(self.session, dt, c)
}

close_session :: proc(self: ^ReplayClaimball) {
    if self.room.ready {
        rgd.room_close(&self.room)
    } else if self.session != nil {
        rgd.session_close(self.session)
    }

    self.session = &self.standalone
    self.view_epoch = 0
    self.recovery_probe = {}
}

room_ui :: proc(self: ^ReplayClaimball) {
    handoff := gd.get_node(self.owner, "UI/Handoff")
    notice := gd.get_node(self.owner, "UI/Recovery")
    gd.canvas_item_set_visible(handoff, self.room.ready && self.session.ready && self.session.authority)
    gd.base_button_set_disabled(
        cast(gd.Button)handoff,
        !self.room.ready || self.room.phase != .Hosting || self.room.options.successor_seat == 0,
    )
    gd.canvas_item_set_visible(notice, self.room.ready)

    if self.room.ready {
        status := rgd.room_backup_status(&self.room)
        gd.set_string(notice, "text", fmt.ctprintf("%s", rgd.room_recovery_message(&self.room, status)))
    }
}

@(gd_method)
replay_claimball_handoff :: proc(self: ^ReplayClaimball) -> bool {
    return self.room.ready && rgd.room_handoff(&self.room) == .None
}

moving_pitch :: proc(w: game.World) -> bool {
    v := w.ball.motion.velocity
    return(
        w.started &&
        w.score.winner == 0 &&
        w.ball.hold == 0 &&
        v[0] * v[0] + v[1] * v[1] > 0.25 &&
        u16(w.score.left) + u16(w.score.right) > 0 \
    )
}

observe_room :: proc(self: ^ReplayClaimball) {
    if self.session == nil || !self.session.ready {
        return
    }

    epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch

    if self.view_epoch != epoch {
        prior := self.view_epoch

        if !self.session.authority && !self.session.client.spectator {
            v.journal_set_policy(&self.session.client.journal, effect_policy)
        }

        self.name_submitted = false
        self.name_sequence = 0
        self.spike_first_sequence = 0

        if prior != 0 {
            frame, ok := rgd.session_authority_state(self.session)

            if ok {
                self.ui[0].round_seen = frame.state.round
                self.ui[0].was_playing = frame.state.started
            }

            self.ui[0].announce_host = self.session.authority
        }

        self.view_epoch = epoch
        self.smoothing = {}
        self.claim = {}
        self.flash_left = 0
        self.flash_id = {}
        self.reset_seen, self.correction_seen, self.last_verdict, self.resync_seen = 0, 0, 0, 0
        self.done, self.spiked, self.spike_visible, self.spike_node_start, self.own_spike_seen =
            false, false, false, false, false
        self.local_kicks, self.remote_kicks, self.speculative_kicks, self.local_canceled, self.remote_canceled =
            0, 0, 0, 0, 0
        self.spike_applied, self.spike_rejected = 0, 0
        self.goal_seen = 0
        self.ball_reset = 0
    }

    if !self.room.ready || claimball_int("RCB_PROBE", 0) != 1 {
        return
    }

    probe := &self.recovery_probe[0]
    prepared := &self.room.prepared

    if prepared.ready && prepared.point != probe.point {
        cp: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&cp)
        codec := &self.session.link.incoming.archive_codec

        if !codec.ready {
            codec = nil
        }

        if net.checkpoint_decode(&cp, prepared.bytes, game.model(), game.CONTENT, codec = codec) == .None {
            probe.point, probe.frame = prepared.point, cp.frame
        }
    }

    if self.room.migrations > probe.checked && self.session.authority && self.room.recovery.to_epoch == epoch {
        probe.checked = self.room.migrations
        frame, found := r.read(&self.session.server.timeline, self.room.recovery.checkpoint_tick)
        probe.exact = found && probe.point == self.room.lease.view.recovered && reflect.equal(frame, probe.frame)
        probe.moving = probe.exact && moving_pitch(frame.state)
        probe.complete =
            probe.exact && game.state_valid(frame.state) && frame.state.group_seat == 0 && !frame.state.outside.valid
        gd.print_str(
            fmt.tprintf(
                "RCB_PITCH_RESTORED exact=%v moving=%v complete=%v tick=%d left=%d right=%d vx=%.6f vy=%.6f",
                probe.exact,
                probe.moving,
                probe.complete,
                frame.tick,
                frame.state.score.left,
                frame.state.score.right,
                frame.state.ball.motion.velocity[0],
                frame.state.ball.motion.velocity[1],
            ),
        )
    }
}

@(gd_method)
replay_claimball_recovery_probe :: proc(self: ^ReplayClaimball, key: string) -> gd.Int {
    if self.session == nil {
        return -1
    }

    p := &self.recovery_probe[0]

    switch key {
    case "steady":
        return gd.Int(
            self.session.ready &&
            !self.session.fenced &&
            (self.session.authority || self.session.client.phase == .Running),
        )
    case "authority":
        return gd.Int(self.session.authority)
    case "epoch":
        return gd.Int(self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch)
    case "moving_live":
        frame, ok := rgd.session_authority_state(self.session)
        return gd.Int(
            ok &&
            moving_pitch(frame.state) &&
            frame.state.ball.motion.position[0] > 140 &&
            frame.state.ball.motion.position[0] < 500,
        )
    case "backup_committed":
        return gd.Int(self.room.rpc.reply.prepared && self.room.rpc.reply.point == p.point)
    case "chat_epoch":
        return gd.Int(self.comms.scope.epoch)
    case "moving_backup":
        return gd.Int(p.point.archive.sequence != 0 && moving_pitch(p.frame.state))
    case "backup_sequence":
        return gd.Int(
            self.session.authority ? self.session.link.outgoing.acknowledged.archive.sequence : p.point.archive.sequence,
        )
    case "backup_tick":
        return gd.Int(p.frame.tick)
    case "exact":
        return gd.Int(p.exact)
    case "moving":
        return gd.Int(p.moving)
    case "complete":
        return gd.Int(p.complete)
    case "backup_members":
        count := 0

        for player in p.frame.state.players {
            if player.connected {
                count += 1
            }
        }

        return gd.Int(count)
    case "archive_bytes":
        return gd.Int(self.room.recovery.archive_bytes)
    case "install_us":
        return gd.Int(self.room.recovery.install_us)
    case "backup_complete":
        return gd.Int(
            p.point.archive.sequence != 0 &&
            game.state_valid(p.frame.state) &&
            p.frame.state.group_seat == 0 &&
            !p.frame.state.outside.valid,
        )
    case "restored_score":
        return gd.Int(p.frame.state.score.left) + gd.Int(p.frame.state.score.right)
    case "restored_spikes":
        return gd.Int(p.frame.state.spikes)
    case "ready":
        return gd.Int(self.room.recovery.ready)
    case "tick":
        return gd.Int(self.room.recovery.checkpoint_tick)
    case "lost":
        return gd.Int(self.room.recovery.known_lost_ticks)
    case "interruption":
        return gd.Int(self.room.recovery.interruption_ms)
    case "kind":
        return gd.Int(self.room.lease.view.recovery)
    case "phase":
        return gd.Int(self.room.phase)
    }

    return -1
}
