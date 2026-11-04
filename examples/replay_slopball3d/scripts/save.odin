package replay_slopball3d

import "core:fmt"
import "core:reflect"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import own "godot:replay/owned"
import rgd "godot:replay/godot"
import game "../shared/pitch"
import storagegd "godot:replay/godot/storage"

save_path :: proc(self: ^ReplaySlopball3d) -> string {
    value := gd.line_edit_get_text(self.ui[0].save_path)
    defer gd.free_string(value)
    return strings.clone(strings.trim_space(gd.gd_string_to_odin(value)), context.temp_allocator)
}

@(gd_method)
replay_slopball3d_on_save :: proc(self: ^ReplaySlopball3d) -> bool {
    if !self.ready || !self.session.ready || !self.session.authority || self.session.fenced {
        return false
    }

    if self.room.ready {
        return self.online.enabled && rgd.room_save(&self.room) == .None
    }

    when gd.IS_WEB {
        return browser_save_submit(self)
    }

    result := rgd.session_save(self.session, save_path(self))

    if result.error != .None {
        gd.set_string(self.ui[0].save_notice, "text", "Could not save. Check the file path and write access.")
        return false
    }

    frame, _ := rgd.session_authority_state(self.session)
    self.saved_tick = frame.tick
    self.saved_hash = u64(replay_slopball3d_probe_hash(self, gd.Int(frame.tick)))
    gd.set_string(
        self.ui[0].save_notice,
        "text",
        fmt.ctprintf("Saved pitch · LEFT %d — %d RIGHT", frame.state.left, frame.state.right),
    )
    gd.print_str(fmt.tprintf("RS3_SAVED tick=%d hash=%d", self.saved_tick, self.saved_hash))
    return true
}

@(gd_method)
replay_slopball3d_on_resume_solo :: proc(self: ^ReplaySlopball3d) {
    connect_pitch(self, "solo", false, true)
}

@(gd_method)
replay_slopball3d_on_resume_host :: proc(self: ^ReplaySlopball3d) {
    connect_pitch(self, "host", false, true)
}

resume_pitch :: proc(self: ^ReplaySlopball3d, opts: rgd.Session_Options) -> net.Error {
    if self.room.ready || slopball3d_int("RS3_COORD_PORT", 0) != 0 {
        ui_notice(self, "File resume is available for direct sessions.")
        return .Wrong_Phase
    }

    if opts.role != .Solo && opts.role != .Host && opts.role != .Server {
        ui_notice(self, "Choose Resume solo or Resume host.")
        return .Wrong_Phase
    }

    when gd.IS_WEB {
        slot := &self.browser_save[0].slot
        key, valid := browser_save_key(self)

        if !valid || key != slot.key || opts.role != .Solo || slot.phase != .Ready || !slot.has_checkpoint {
            ui_notice(self, "No readable saved match is available in this slot.")
            return .Invalid_Checkpoint
        }

        return restore_pitch(self, &slot.checkpoint, opts)
    } else {
        cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&cp)
        result := storagegd.checkpoint_read(&cp, game.model(), save_path(self), game.CONTENT)

        if result.error != .None {
            ui_notice(
                self,
                result.error == .Open ? "Could not open the saved match. Check the file path." : "The saved match is damaged or from a different version.",
            )
            return result.network != .None ? result.network : net.Error.Invalid_Checkpoint
        }

        return restore_pitch(self, &cp, opts)
    }
}

restore_pitch :: proc(
    self: ^ReplaySlopball3d,
    cp: ^net.Checkpoint(game.World, game.Control, game.Action, game.SEATS),
    opts: rgd.Session_Options,
) -> net.Error {
    if cp.settings.require_permit || cp.header.policy_id != 0 {
        ui_notice(self, "This match requires its room recovery service.")
        return .Checkpoint_Policy
    }

    if cp.header.epoch == max(u64) {
        ui_notice(self, "The saved match cannot begin another session.")
        return .Invalid_Checkpoint
    }

    seat, found := net.checkpoint_seat(cp, opts.token)

    if opts.role == .Server {
        if cp.header.local_seat != 0 {
            ui_notice(self, "This match was saved by a player host.")
            return .Invalid_Input
        }

        seat = 0
    } else if !found || seat != cp.header.local_seat {
        ui_notice(self, "Use the host profile that saved this match.")
        return .Invalid_Input
    }

    // Direct file resume retires pending commands and schedules disconnected peers.
    // Coordinated migration has its own authorization/pending-command policy.
    self.session = &self.standalone
    err := rgd.session_resume(self.session, cp, game.model(), opts, {epoch = cp.header.epoch + 1, local_seat = seat})

    if err != .None {
        ui_notice(self, "Could not start the saved match. Check the host port.")
        return err
    }

    frame, ok := r.current(&self.session.server.timeline)
    self.restored_exact = ok && reflect.equal(frame, cp.frame)
    self.restored_tick = cp.frame.tick
    self.restored_hash = u64(replay_slopball3d_probe_hash(self, gd.Int(cp.frame.tick)))
    self.ui[0].was_playing = cp.frame.state.started
    self.restored_ball = cp.frame.state.ball.value
    self.save_seeded, self.save_seed_checked = false, false
    gd.set_string(
        self.ui[0].save_notice,
        "text",
        opts.role == .Solo ? "Saved pitch restored for solo play." : "Saved pitch restored — players can rejoin.",
    )
    gd.print_str(
        fmt.tprintf(
            "RS3_RESTORED tick=%d hash=%d exact=%v epoch=%d",
            self.restored_tick,
            self.restored_hash,
            self.restored_exact,
            self.session.server.cfg.epoch,
        ),
    )
    return .None
}

@(gd_method)
replay_slopball3d_save_probe :: proc(self: ^ReplaySlopball3d, key: string) -> gd.Int {
    switch key {
    case "saved_tick":
        return gd.Int(self.saved_tick)
    case "saved_hash":
        return gd.Int(self.saved_hash)
    case "restored_tick":
        return gd.Int(self.restored_tick)
    case "restored_hash":
        return gd.Int(self.restored_hash)
    case "exact":
        return gd.Int(self.restored_exact)
    }

    if key == "seeded" {
        return gd.Int(self.save_seeded)
    }

    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return -1
    }

    w := frame.state

    if key == "moving" {
        pose := w.ball.value
        spin :=
            pose.angular[0] * pose.angular[0] + pose.angular[1] * pose.angular[1] + pose.angular[2] * pose.angular[2]
        tilted := abs(pose.rotation[0]) + abs(pose.rotation[1]) + abs(pose.rotation[2]) > 0.05
        return gd.Int(
            moving(w) &&
            w.tick >= w.kickoff_until &&
            w.left + w.right > 0 &&
            pose.position[0] > 1 &&
            pose.position[0] < 15 &&
            spin > 0.25 &&
            tilted,
        )
    }

    return -1
}

observe_save_seed :: proc(self: ^ReplaySlopball3d, state: own.State(own.Pose3), actual: own.Pose3) {
    if !self.restored_exact || self.save_seed_checked || self.room.ready || state.epoch < 2 {
        return
    }

    self.save_seed_checked = true
    self.save_seed = actual
    position_error :=
        abs(actual.position[0] - self.restored_ball.position[0]) +
        abs(actual.position[1] - self.restored_ball.position[1]) +
        abs(actual.position[2] - self.restored_ball.position[2])
    velocity_error :=
        abs(actual.linear[0] - self.restored_ball.linear[0]) +
        abs(actual.linear[1] - self.restored_ball.linear[1]) +
        abs(actual.linear[2] - self.restored_ball.linear[2]) +
        abs(actual.angular[0] - self.restored_ball.angular[0]) +
        abs(actual.angular[1] - self.restored_ball.angular[1]) +
        abs(actual.angular[2] - self.restored_ball.angular[2])
    self.save_seeded =
        position_error < 0.001 &&
        velocity_error < 0.001 &&
        abs(
            actual.rotation[0] * self.restored_ball.rotation[0] +
            actual.rotation[1] * self.restored_ball.rotation[1] +
            actual.rotation[2] * self.restored_ball.rotation[2] +
            actual.rotation[3] * self.restored_ball.rotation[3],
        ) >
            0.99999
    gd.print_str(
        fmt.tprintf(
            "RS3_FILE_SEED exact=%v epoch=%d position_error=%.9f velocity_error=%.9f",
            self.save_seeded,
            state.epoch,
            position_error,
            velocity_error,
        ),
    )
}

// Observation of the committed slot or first actual local restore seed.
@(gd_method)
replay_slopball3d_save_pose :: proc(self: ^ReplaySlopball3d, which: string) -> gd.String {
    if which != "saved" && which != "seed" && which != "restored" {
        return gd.new_string_odin("null")
    }

    pose :=
        which == "seed" ? self.save_seed : which == "saved" ? self.browser_save[0].slot.checkpoint.frame.state.ball.value : self.restored_ball
    return gd.new_string_odin(fmt.tprintf("[%v,%v,%v,%v]", pose.position, pose.rotation, pose.linear, pose.angular))
}
