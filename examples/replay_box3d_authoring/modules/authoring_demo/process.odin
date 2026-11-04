package replay_authoring_demo

import "base:runtime"
import "core:fmt"
import gd "godot:godot"
import net "godot:replay/net"
import view "godot:replay/view"
import rgd "godot:replay/godot"
import r "godot:replay"
import audit "accepted_audit"

replay_authoring_demo_process :: proc(self: ^ReplayAuthoringDemo, dt: f64) {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)

    if !self.ready || self.finished || self.state == nil {
        return
    }

    self.frames += 1

    if self.scripted && self.frames > self.frame_budget {
        error_set(self, "sample.timeout before final ACK")
        finish(self)
        return
    }

    s := &self.state.session
    terminal(self)

    if self.finished || self.failed {
        if self.failed {
            finish(self)
        }

        return
    }

    announce_go(self)
    bootstrap := false

    if self.hosting && !self.go {
        for peer in s.server.peers {
            if !peer.local && peer.phase == .Pending {
                bootstrap = true
            }
        }
    }

    running := self.hosting || s.client.phase == .Running
    head := self.hosting ? s.server.timeline.head : s.client.timeline.head
    control := self.pending
    seat := rgd.session_seat(s)

    if self.scripted {
        control = scripted_control(head + 1, seat)
    }

    if !self.go || !running || seat == 0 {
        control = {}
    }

    elapsed := self.go && running && (self.target == 0 || head < self.target) ? dt : f64(0)

    if bootstrap {
        elapsed = 1.0 / 60.0 + 1e-9
        control = {}
    }

    error := rgd.session_frame(s, elapsed, control)

    if s.control_consumed {
        self.pending.pulse = false
    }

    if !self.hosting && self.got_close && s.client.phase == .Disconnected {
        finish(self)
        return
    }

    if error != .None {
        error_set(self, "Replay.Session.frame")
        finish(self)
        return
    }

    changes: [320]view.Change(net.Net_Event(Event))
    count := rgd.session_changes(s, changes[:])

    for change in changes[:count] {
        if change.occurrence.value.kind == .Gameplay {
            self.fx += 1
        }
    }

    self.head = self.hosting ? s.server.timeline.head : s.client.timeline.head
    self.confirmed = self.hosting ? s.server.timeline.head : s.client.timeline.confirmed
    observe_recovery_scope(self)
    self.status_elapsed += dt

    if self.status_elapsed >= 1 {
        self.status_elapsed = 0
        observe_memory(self)

        if self.scripted {
            gd.print_str(fmt.tprintf("SAMPLE_STATUS %s", public_status_json(self)))
        }
    }

    accepted(self)

    if self.hosting || s.client.phase == .Running {
        publish_presentation(self)
    }

    if self.failed {
        finish(self)
        return
    }

    if self.target != 0 && self.confirmed >= self.target && !self.have_final {
        if !export_final(self) {
            finish(self)
            return
        }
    }

    terminal(self)

    if !self.finished {
        announce_go(self)
    }

    if self.failed {
        finish(self)
    }
}

announce_go :: proc(self: ^ReplayAuthoringDemo) {
    if self.scripted && self.go && !self.announced {
        self.announced = true
        self.status_elapsed = 0
        gd.print_str(fmt.tprintf("SAMPLE_STATUS %s", public_status_json(self)))
    }
}

accepted :: proc(self: ^ReplayAuthoringDemo) {
    s := &self.state.session

    if !self.hosting && s.client.phase != .Running {
        return
    }

    if !self.accepted_started {
        self.accepted_started = true
        self.last_accepted = self.hosting ? 0 : s.client.baseline
        self.first_accepted = self.last_accepted + 1

        if !self.hosting {
            self.accepted_snapshot_catchups = s.client.stats.snapshot_catchups
        }
    }

    if !self.hosting {
        c := &s.client
        scope := audit.Scope{c.cfg.epoch, c.generation, c.serial, c.baseline}
        committed := recovery_available(self) && c.physics != nil

        if committed {
            committed = c.physics.accepted.epoch == scope.epoch && c.physics.accepted.baseline == scope.baseline
        }

        previous := audit.Scope {
            self.accepted_scope_epoch,
            self.accepted_scope_generation,
            self.accepted_scope_serial,
            self.accepted_scope_baseline,
        }
        next, gap, error := audit.begin(previous, scope, self.last_accepted, committed)

        if error != .None {
            error_set(
                self,
                fmt.tprintf(
                    "accepted.scope %v committed=%v epoch=%d baseline=%d generation=%d serial=%d cursor=%d",
                    error,
                    committed,
                    scope.epoch,
                    scope.baseline,
                    scope.generation,
                    scope.serial,
                    self.last_accepted,
                ),
            )
            return
        }

        if gap.first != 0 {
            self.accepted_gap = true
            log_json("SAMPLE_INPUTS_UNAVAILABLE", struct {
                framework, role:                                                 string,
                available:                                                       bool,
                first, last, cursor_before, epoch, generation, serial, baseline: u64,
            } {
                "Replay",
                self.role,
                false,
                gap.first,
                gap.last,
                self.last_accepted,
                scope.epoch,
                scope.generation,
                scope.serial,
                scope.baseline,
            })
        }

        self.last_accepted = next
        self.accepted_scope_epoch = scope.epoch
        self.accepted_scope_generation = scope.generation
        self.accepted_scope_serial = scope.serial
        self.accepted_scope_baseline = scope.baseline
    }

    timeline := self.hosting ? &s.server.timeline : &s.client.timeline
    final := self.target == 0 ? timeline.confirmed : min(timeline.confirmed, self.target)

    if !self.hosting && s.client.stats.snapshot_catchups > self.accepted_snapshot_catchups {
        first, last, window_error := r.history_window(timeline)
        anchor, frame_found := r.read_values(timeline, first)
        _, has_input := r.read_input(timeline, first)
        evidence := audit.Snapshot_Evidence {
            previous_catchups = self.accepted_snapshot_catchups,
            current_catchups  = s.client.stats.snapshot_catchups,
            first             = first,
            last              = last,
            head              = timeline.head,
            confirmed         = timeline.confirmed,
            final             = final,
            frame_tick        = anchor.tick,
            window_valid      = window_error == .None,
            frame_found       = frame_found,
            has_input         = has_input,
        }
        gap, unavailable := audit.snapshot_gap(self.last_accepted, evidence)

        if unavailable {
            self.accepted_gap = true
            log_json("SAMPLE_INPUTS_UNAVAILABLE", struct {
                framework,
                role,
                reason:                                                                         string,
                available:                                                                                       bool,
                first,
                last,
                cursor_before,
                epoch,
                generation,
                serial,
                baseline:                                 u64,
                history_first,
                history_last,
                head,
                confirmed,
                snapshot_catchups_before,
                snapshot_catchups_after: u64,
                anchor_frame_found,
                anchor_input_found:                                                          bool,
            } {
                "Replay",
                self.role,
                "canonical_snapshot",
                false,
                gap.first,
                gap.last,
                self.last_accepted,
                s.client.cfg.epoch,
                s.client.generation,
                s.client.serial,
                s.client.baseline,
                first,
                last,
                timeline.head,
                timeline.confirmed,
                self.accepted_snapshot_catchups,
                s.client.stats.snapshot_catchups,
                frame_found,
                has_input,
            })
            self.last_accepted = gap.last
        }
    }

    for tick := self.last_accepted + 1; tick <= final; tick += 1 {
        // The receipt ring can move ahead of confirmed execution and evict an older
        // receipt. Audit the actual retained committed Batch, not receipt lifetime.
        batch, found := r.read_input(timeline, tick)
        next, error := audit.record(self.last_accepted, tick, found)

        if error != .None {
            scope := audit.Scope {
                self.accepted_scope_epoch,
                self.accepted_scope_generation,
                self.accepted_scope_serial,
                self.accepted_scope_baseline,
            }
            newest := self.hosting ? s.server.timeline.head : s.client.physics.accepted.newest
            first, last, window_error := r.history_window(timeline)
            _, requested_frame_found := r.read_values(timeline, tick)
            anchor, anchor_frame_found := r.read_values(timeline, first)
            _, anchor_input_found := r.read_input(timeline, first)
            catchups := self.hosting ? u64(0) : s.client.stats.snapshot_catchups
            log_json("SAMPLE_INPUT_AUDIT_MISSING", struct {
                framework,
                role,
                window_error:                                                                           string,
                tick,
                cursor,
                epoch,
                generation,
                serial,
                baseline,
                head,
                confirmed,
                final,
                receipt_newest:               u64,
                history_first,
                history_last,
                anchor_tick,
                last_audit_snapshot_catchups,
                snapshot_catchups:               u64,
                requested_frame_found,
                window_valid,
                anchor_frame_found,
                anchor_input_found,
                snapshot_catchups_observed: bool,
            } {
                "Replay",
                self.role,
                fmt.tprintf("%v", window_error),
                tick,
                self.last_accepted,
                scope.epoch,
                scope.generation,
                scope.serial,
                scope.baseline,
                timeline.head,
                timeline.confirmed,
                final,
                newest,
                first,
                last,
                anchor.tick,
                self.accepted_snapshot_catchups,
                catchups,
                requested_frame_found,
                window_error == .None,
                anchor_frame_found,
                anchor_input_found,
                !self.hosting,
            })
            error_set(
                self,
                fmt.tprintf(
                    "accepted.input_history %v tick=%d epoch=%d baseline=%d generation=%d serial=%d cursor=%d newest=%d",
                    error,
                    tick,
                    scope.epoch,
                    scope.baseline,
                    scope.generation,
                    scope.serial,
                    self.last_accepted,
                    newest,
                ),
            )
            return
        }

        value: net.Accepted_Input(Control, Action, 2)
        receipt_found: bool

        if self.hosting {
            value, receipt_found = net.server_accepted_input(&s.server, tick)
        } else {
            value, receipt_found = net.accepted_read(&s.client.physics.accepted, tick)
        }

        origins := audit.origin_matches(batch, value.batch, receipt_found)

        for control, seat in batch.controls {
            self.accepted_rows += 1
            self.controls_by_seat[seat] += 1

            if control.x != 0 || control.z != 0 || control.pulse {
                self.nonzero_rows += 1
                self.nonzero_by_seat[seat] += 1
            }

            if origins {
                self.origin_observed += 1

                switch value.decisions.origins[seat] {
                case .Sample:
                    self.sample_rows += 1
                case .Held:
                    self.held_rows += 1
                case .Local:
                    self.local_rows += 1
                case .Neutral:
                    self.neutral_rows += 1
                }
            } else {
                self.origin_unavailable += 1
            }
        }

        self.last_accepted = next
    }

    if !self.hosting {
        self.accepted_snapshot_catchups = s.client.stats.snapshot_catchups
    }
}
