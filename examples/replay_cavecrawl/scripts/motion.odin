package replay_cavecrawl
import "core:math"
import gd "godot:godot"
import o "godot:replay/owned"
import rgd "godot:replay/godot"
import game "../shared/cave"

// Producer cursors/poses are external observations, never hidden reducer state.
// The owner variant captures them into controls; the original Replay profile
// keeps its existing scheduled movement and rendering paths.
Cave_Motion :: struct {
    avatar_driver, prop_driver: o.Driver,
    avatar, prop:               o.Pose2,
    pending:                    [16]game.Action,
    pending_count:              int,
}

cave_motion_control :: proc(self: ^ReplayCave, dt: f64, control: ^game.Control) {
    when game.OWNER_MOTION {
        frame, available := rgd.session_authority_state(self.session)
        seat := rgd.session_seat(self.session)

        if !available || seat == 0 {
            return
        }

        w := &frame.state
        body := w.avatars[seat - 1]

        if body.key.generation == 0 {
            return
        }

        epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
        live :=
            self.session.ready &&
            !self.session.fenced &&
            (self.session.authority || self.session.client.phase == .Running)
        motion := &self.motion
        drive := o.drive(&motion.avatar_driver, body, seat, epoch, frame.tick, live && w.players[seat - 1].connected)

        if drive.error != .None {
            return
        }

        if drive.reseed {
            motion.avatar = drive.baseline
        }

        if drive.role == .Owner {
            motion.avatar.linear = {}
            player := w.players[seat - 1]

            if player.hp > 0 && !w.won && w.lobby.phase != .Waiting && dt > 0 && dt < 1e6 && !math.is_nan(dt) {
                speed := game.WALK_SPEED * (player.chill > 0 ? f32(0.5) : f32(1))
                distance := speed * f32(dt)
                from := motion.avatar.position
                direction := [2]f32{f32(control.move[0]), f32(control.move[1])}

                if direction != ([2]f32{}) {
                    self.walking = false
                    direction /= math.sqrt(direction[0] * direction[0] + direction[1] * direction[1])
                    motion.avatar.position += direction * distance
                } else if self.walking && !self.lobby_menu_open && !gd.control_has_focus(self.chat_input, false) {
                    // Original scripted walk_to advances each axis independently and snaps
                    // only when both remaining components fit inside this frame's step.
                    delta := self.walk_target - motion.avatar.position

                    if abs(delta[0]) <= distance && abs(delta[1]) <= distance {
                        motion.avatar.position = self.walk_target
                        self.walking = false
                    } else {
                        for axis in 0 ..< 2 {
                            if abs(delta[axis]) > distance {
                                motion.avatar.position[axis] += delta[axis] > 0 ? distance : -distance
                            }
                        }
                    }
                }

                motion.avatar.linear = (motion.avatar.position - from) / f32(dt)
            }

            control.avatar, _ = o.capture(&motion.avatar_driver, motion.avatar)
        }

        prop_drive := o.drive(&motion.prop_driver, w.prop, seat, epoch, frame.tick, live && player_connected(w, seat))

        if prop_drive.error != .None {
            return
        }

        if prop_drive.reseed {
            motion.prop = prop_drive.baseline
        }

        if prop_drive.role == .Owner {
            motion.prop.position = motion.avatar.position + [2]f32{10, -12}
            motion.prop.linear = motion.avatar.linear
            control.prop, _ = o.capture(&motion.prop_driver, motion.prop)
        }
    }
}

player_connected :: proc(w: ^game.World, seat: u16) -> bool {
    return w.players[seat - 1].connected
}

cave_motion_present :: proc(self: ^ReplayCave, w: ^game.World) {
    when game.OWNER_MOTION {
        seat := rgd.session_seat(self.session)

        if seat != 0 && self.motion.avatar_driver.role == .Owner {
            w.players[seat - 1].position = self.motion.avatar.position
        }

        if self.motion.prop_driver.role == .Owner {
            w.relic.position = self.motion.prop.position
        }
    }
}

@(gd_method)
replay_cave_motion_probe :: proc(self: ^ReplayCave, key: string, wanted: gd.Int) -> gd.Int {
    if key == "profile" {
        return game.OWNER_MOTION ? 1 : 0
    }

    when game.OWNER_MOTION {
        frame, ok := rgd.session_authority_state(self.session)

        if !ok {
            return -1
        }

        w := &frame.state

        switch key {
        case "epoch":
            return gd.Int(w.epoch)
        case "prop_owner":
            return gd.Int(w.prop.owner)
        case "prop_revision":
            return gd.Int(w.prop.revision)
        case "prop_sequence":
            return gd.Int(w.prop.sequence)
        case "prop_x":
            return gd.Int(w.prop.value.position[0])
        case "prop_y":
            return gd.Int(w.prop.value.position[1])
        }

        if wanted < 1 || wanted > game.SEATS {
            return -1
        }

        body := w.avatars[wanted - 1]

        switch key {
        case "avatar_revision":
            return gd.Int(body.revision)
        case "avatar_sequence":
            return gd.Int(body.sequence)
        case "avatar_owner":
            return gd.Int(body.owner)
        case "avatar_x":
            return gd.Int(body.value.position[0])
        case "avatar_y":
            return gd.Int(body.value.position[1])
        }
    }

    return -1
}

// Refresh ownership independently of movement integration: a command can be
// issued before this frame's normal producer update (including just after resume).
cave_motion_ready :: proc(self: ^ReplayCave) -> bool {
    when game.OWNER_MOTION {
        frame, ok := rgd.session_authority_state(self.session)
        seat := rgd.session_seat(self.session)

        if !ok || seat == 0 || frame.state.avatars[seat - 1].key.generation == 0 {
            return false
        }

        epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
        live :=
            self.session.ready &&
            !self.session.fenced &&
            (self.session.authority || self.session.client.phase == .Running)
        choice := o.drive(
            &self.motion.avatar_driver,
            frame.state.avatars[seat - 1],
            seat,
            epoch,
            frame.tick,
            live && frame.state.players[seat - 1].connected,
        )

        if choice.error != .None {
            return false
        }

        if choice.reseed {
            self.motion.avatar = choice.baseline
        }

        return choice.role == .Owner
    } else {
        return true
    }
}

cave_motion_defer :: proc(self: ^ReplayCave, action: game.Action) {
    motion := &self.motion

    if !self.ready || !self.session.ready || rgd.session_seat(self.session) == 0 {
        gd.print_str("REPLAY_CAVE_ACTION owner context unavailable")
        return
    }

    if motion.pending_count == len(motion.pending) {
        gd.print_str("REPLAY_CAVE_ACTION pending input capacity")
        return
    }

    motion.pending[motion.pending_count] = action
    motion.pending_count += 1
}

// Commands awaiting the first authorized producer scope are local intents, not
// admitted actions. Capture their origin when they can first be submitted. Keep
// subsequent commands in FIFO order, and discard this queue on ordinary Leave.
cave_motion_flush :: proc(self: ^ReplayCave) {
    when game.OWNER_MOTION {
        if self.motion.pending_count == 0 || !cave_motion_ready(self) {
            return
        }

        count := self.motion.pending_count
        pending := self.motion.pending
        self.motion.pending_count = 0

        for action in pending[:count] {
            replay_cave_issue(self, action)
        }
    }
}

cave_motion_action :: proc(self: ^ReplayCave, action: ^game.Action) -> bool {
    when game.OWNER_MOTION {
        if self.motion.pending_count > 0 {
            cave_motion_defer(self, action^)
            return false
        }

        if !game.needs_origin(action.verb) {
            return true
        }

        if !cave_motion_ready(self) {
            cave_motion_defer(self, action^)
            return false
        }

        value, error := o.capture_context(&self.motion.avatar_driver, self.motion.avatar)

        if error != .None {
            cave_motion_defer(self, action^)
            return false
        }

        action.origin_kind, action.origin = .Owner_Pose, value
    }

    return true
}
