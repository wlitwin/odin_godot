package dockyard_duo

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"

Qualification_State :: struct {
    ready, authority, fenced, lease_poisoned, clock_poisoned, rpc_pending:                                      bool,
    head, confirmed, generation, serial, repairs, lease_now, deadline, last_wall, last_monotonic, last_control: u64,
}

Qualification_Row :: struct {
    sequence, frame, elapsed_us:   u64,
    operation, category:           string,
    error:                         net.Error,
    before, after:                 Qualification_State,
    planned_depth, executed_steps: u64,
    dt_seconds:                    f64,
    clock_valid:                   bool,
}

Qualification_Counters :: struct {
    observed:                                                         bool,
    epoch, head, next_id, tx_packets, tx_bytes, rx_packets, rx_bytes: u64,
    peers, generation, serial, facts_sent, snapshot_sent:             u64,
    transfer_id, transfer_tick, stored_bytes, parts_progress:         u64,
    waiting_ack, snapshot, welcome:                                   bool,
}

Qualification_Counter_Row :: struct {
    sequence:      u64,
    before, after: Qualification_Counters,
}

Qualification :: struct {
    enabled, overflow, buffered, transfer_emitted, end_reported, phase_detail, counter_detail: bool,
    sequence, maximum_complete_wire_bytes, maximum_attachment_bytes:                           u64,
    count, emitted:                                                                            int,
    rows:                                                                                      [128]Qualification_Row,
    buffered_rows:                                                                             []Qualification_Row,
    counter_rows:                                                                              []Qualification_Counter_Row,
}

Qualification_Phases :: struct {
    ready, authority:                                       bool,
    epoch, head:                                            u64,
    external_enabled, external_clock, external_godot_clock: bool,
    external_work_ns, external_total_ns:                    u64,
    external_open, external_model, external_capture:        r.External_Phase_Timing,
    total_us, samples, errors:                              [net.Profile_Metric]u64,
}

Qualification_Phase_Delta :: struct {
    name:                      string,
    total_us, samples, errors: u64,
}

Qualification_Action_Sample :: struct {
    copied:                                 bool,
    error:                                  r.Error,
    actions, applied, predicate_rejections: [2]u64,
    invalid_seats:                          u64,
}

qualification_profile_clock :: proc(_: rawptr) -> (u64, bool) {
    return gd.time_get_ticks_usec(gd.singleton_time()), true
}

qualification_external_clock :: proc() -> u64 {
    return gd.time_get_ticks_usec(gd.singleton_time()) * 1000
}

qualification_phases :: proc(self: ^DockyardDuo) -> Qualification_Phases {
    s := self.state.session
    out := Qualification_Phases {
        ready     = s.ready,
        authority = s.authority,
    }

    if !s.ready {
        return out
    }

    out.epoch = s.authority ? s.server.cfg.epoch : s.client.cfg.epoch
    timeline := s.authority ? &s.server.timeline : &s.client.timeline
    out.head = timeline.head
    out.external_enabled = timeline.external.identity != 0
    out.external_clock = timeline.external.clock != nil
    out.external_godot_clock = timeline.external.clock == qualification_external_clock
    out.external_work_ns = timeline.external_profile.last_work_ns
    out.external_total_ns = timeline.external_profile.last_total_ns
    out.external_open = timeline.external_profile.open
    out.external_model = timeline.external_profile.model
    out.external_capture = timeline.external_profile.capture
    metrics := s.authority ? &s.server.profile_metrics : &s.client.profile_metrics

    for timing, metric in metrics^ {
        out.total_us[metric] = timing.total_us
        out.samples[metric] = timing.samples
        out.errors[metric] = timing.errors
    }

    return out
}

qualification_action_sample :: proc(self: ^DockyardDuo) -> Qualification_Action_Sample {
    result := Qualification_Action_Sample {
        error = .Not_Initialized,
    }
    s := self.state.session

    if !s.ready {
        return result
    }

    timeline := s.authority ? &s.server.timeline : &s.client.timeline
    events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))
    count, error := r.copy_events(timeline, timeline.head, events[:])
    result.error = error

    if error != .None {
        return result
    }

    result.copied = true

    for event in events[:count] {
        if event.value.kind != .Action_Result {
            continue
        }

        seat := int(event.value.seat) - 1

        if seat < 0 || seat >= len(result.actions) {
            result.invalid_seats += 1
            continue
        }

        result.actions[seat] += 1

        if event.value.applied {
            result.applied[seat] += 1
        }

        if event.value.reason == .Predicate {
            result.predicate_rejections[seat] += 1
        }
    }

    return result
}

qualification_phase_report :: proc(self: ^DockyardDuo, before: Qualification_Phases, row: Qualification_Row) {
    after := qualification_phases(self)
    valid := before.ready && after.ready && before.authority == after.authority && before.epoch == after.epoch

    for value, metric in after.total_us {
        if value < before.total_us[metric] ||
           after.samples[metric] < before.samples[metric] ||
           after.errors[metric] != before.errors[metric] {
            valid = false
        }
    }

    deltas: [net.Profile_Metric]Qualification_Phase_Delta

    for _, metric in deltas {
        deltas[metric].name = fmt.tprintf("%v", metric)

        if valid {
            deltas[metric].total_us = after.total_us[metric] - before.total_us[metric]
            deltas[metric].samples = after.samples[metric] - before.samples[metric]
        }

        if after.errors[metric] >= before.errors[metric] {
            deltas[metric].errors = after.errors[metric] - before.errors[metric]
        }
    }

    log_json("SAMPLE_OPERATION_PHASES", struct {
        sequence, whole_elapsed_us:                             u64,
        valid:                                                  bool,
        before_epoch, after_epoch:                              u64,
        scope:                                                  string,
        external_enabled, external_clock, external_godot_clock: bool,
        external_head, external_work_ns, external_total_ns:     u64,
        external_open, external_model, external_capture:        r.External_Phase_Timing,
        actions:                                                Qualification_Action_Sample,
        metrics:                                                [net.Profile_Metric]Qualification_Phase_Delta,
    } {
        sequence = row.sequence,
        whole_elapsed_us = row.elapsed_us,
        valid = valid,
        before_epoch = before.epoch,
        after_epoch = after.epoch,
        scope = "existing nested/partial last-transaction observations; no subtraction",
        external_enabled = after.external_enabled,
        external_clock = after.external_clock,
        external_godot_clock = after.external_godot_clock,
        external_head = after.head,
        external_work_ns = after.external_work_ns,
        external_total_ns = after.external_total_ns,
        external_open = after.external_open,
        external_model = after.external_model,
        external_capture = after.external_capture,
        actions = qualification_action_sample(self),
        metrics = deltas,
    })
}

qualification_state :: proc(self: ^DockyardDuo) -> Qualification_State {
    s := self.state.session
    out := Qualification_State {
        ready     = s.ready,
        authority = s.authority,
    }
    out.fenced = s.fenced

    if self.state.online.enabled {
        room := &self.state.room
        out.lease_now = room.lease.now
        out.deadline = room.lease.deadline
        out.lease_poisoned = room.lease.poisoned
        out.clock_poisoned = room.browser_clock.paired.poisoned
        out.last_wall = room.browser_clock.paired.last_wall
        out.last_monotonic = room.browser_clock.paired.last_monotonic
        out.last_control = room.last_control
        out.rpc_pending = room.rpc.pending
    }

    if !s.ready {
        return out
    }

    if s.authority {
        out.head = s.server.timeline.head
        out.confirmed = s.server.timeline.confirmed
    } else {
        out.head = s.client.timeline.head
        out.confirmed = s.client.timeline.confirmed
        out.generation = s.client.generation
        out.serial = s.client.serial

        if s.client.physics != nil {
            out.repairs = s.client.physics.repairs
        }
    }

    return out
}

qualification_counters :: proc(self: ^DockyardDuo) -> Qualification_Counters {
    s := self.state.session
    out: Qualification_Counters

    if !s.ready || !s.authority || s.server.physics == nil {
        return out
    }

    server := &s.server
    out.observed = true
    out.epoch = server.cfg.epoch
    out.head = server.timeline.head
    out.next_id = server.physics.next_id
    out.tx_packets = server.stats.tx_packets
    out.tx_bytes = server.stats.tx_bytes
    out.rx_packets = server.stats.rx_packets
    out.rx_bytes = server.stats.rx_bytes

    for peer, index in server.peers {
        if peer.local || (peer.phase != .Running && peer.phase != .Pending) {
            continue
        }

        out.peers += 1

        if out.peers != 1 {
            continue
        } // Exact slot details are valid only for one remote peer.

        out.generation = peer.generation
        out.serial = peer.serial
        out.facts_sent = peer.facts_sent
        out.snapshot_sent = peer.snapshot_sent
        tx := &server.physics.tx[index]
        out.transfer_id = tx.id
        out.transfer_tick = tx.tick
        out.stored_bytes = u64(len(tx.data.bytes))
        out.parts_progress = u64(tx.part)
        out.waiting_ack = tx.waiting_ack
        out.snapshot = len(tx.data.bytes) > 0 && tx.purpose == .Snapshot
        out.welcome = len(tx.data.bytes) > 0 && tx.purpose == .Welcome
    }

    return out
}

qualification_flush :: proc(self: ^DockyardDuo) {
    if self.state == nil {
        return
    }

    q := &self.state.qualification

    if q.enabled && q.buffered {
        for q.emitted < q.count {
            end := min(q.emitted + len(q.rows), q.count)
            batch := q.buffered_rows[q.emitted:end]
            log_json("SAMPLE_OPERATION", struct {
                role: string,
                rows: []Qualification_Row,
            }{self.role, batch})

            for row in batch {
                if !row.clock_valid ||
                   row.elapsed_us >= 10000 ||
                   row.error != .None ||
                   (!row.before.fenced && row.after.fenced) {
                    log_json("SAMPLE_OPERATION_SLOW", row)
                }
            }

            q.emitted = end
        }

        if !q.transfer_emitted && q.maximum_complete_wire_bytes > 0 {
            log_json("SAMPLE_QUALIFICATION_TRANSFER", struct {
                role:                                                  string,
                complete_wire_bytes, native_payload_upper_bound_bytes: u64,
            }{self.role, q.maximum_complete_wire_bytes, q.maximum_attachment_bytes})
            q.transfer_emitted = true
        }

        return
    }

    if q.enabled && q.count > 0 {
        log_json("SAMPLE_OPERATION", struct {
            role: string,
            rows: []Qualification_Row,
        }{self.role, q.rows[:q.count]})

        if q.counter_detail {
            log_json("SAMPLE_OPERATION_COUNTERS", struct {
                role: string,
                rows: []Qualification_Counter_Row,
            }{self.role, q.counter_rows[:q.count]})
        }

        q.count = 0
    }
}

qualification_end :: proc(self: ^DockyardDuo) {
    q := &self.state.qualification

    if q.enabled && !q.end_reported {
        log_json("SAMPLE_OPERATION_END", struct {
            role:                  string,
            buffered:              bool,
            rows, head, confirmed: u64,
        }{self.role, q.buffered, q.sequence, self.head, self.confirmed})

        if q.phase_detail {
            log_json("SAMPLE_PHASE_TOTALS", qualification_phases(self))
        }

        q.end_reported = true
    }
}

qualification_frame :: proc(self: ^DockyardDuo, dt: f64, control: Control) -> net.Error {
    state := self.state
    q := &state.qualification

    if !q.enabled {
        return(
            state.online.enabled ? rgd.room_frame(&state.room, dt, control) : rgd.session_frame(state.session, dt, control) \
        )
    }

    before := qualification_state(self)
    counter_before, counter_after: Qualification_Counters

    if q.counter_detail {
        counter_before = qualification_counters(self)
    }

    phase_before: Qualification_Phases

    if q.phase_detail {
        if state.session.ready && state.session.authority {
            state.session.server.profile_clock = {
                read = qualification_profile_clock,
            }
        }

        if state.session.ready {
            timeline := state.session.authority ? &state.session.server.timeline : &state.session.client.timeline

            if timeline.external.identity != 0 {
                timeline.external.clock = qualification_external_clock
            }
        }

        phase_before = qualification_phases(self)
    }

    start := gd.time_get_ticks_usec(gd.singleton_time())
    error :=
        state.online.enabled ? rgd.room_frame(&state.room, dt, control) : rgd.session_frame(state.session, dt, control)
    end := gd.time_get_ticks_usec(gd.singleton_time())

    if q.counter_detail {
        counter_after = qualification_counters(self)
    }

    after := qualification_state(self)
    planned, executed: u64

    if !state.session.authority && state.session.client.physics != nil {
        planned = state.session.client.physics.last_planned_depth
        executed = state.session.client.physics.last_executed_steps
    }

    category := "pump"

    if error != .None {
        category = "error"
    } else if !before.ready {
        category = "bootstrap"
    } else if before.generation != after.generation || before.serial != after.serial || after.head < before.head {
        category = "replacement"
    } else if after.repairs > before.repairs {
        category = "repair"
    } else if after.head > before.head {
        category = after.head - before.head == 1 ? "advance1" : "advance_many"
    }

    if q.sequence >= 65536 {
        q.overflow = true
        error_set(self, "qualification.operation capacity reached")
        return error
    }

    q.sequence += 1
    row := Qualification_Row {
        sequence       = q.sequence,
        frame          = self.frames,
        elapsed_us     = end >= start ? end - start : 0,
        operation      = state.online.enabled ? "Room.frame" : "Session.frame",
        category       = category,
        error          = error,
        before         = before,
        after          = after,
        planned_depth  = planned,
        executed_steps = executed,
        dt_seconds     = dt,
        clock_valid    = end >= start,
    }

    if q.counter_detail {
        q.counter_rows[q.count] = {row.sequence, counter_before, counter_after}
    }

    if q.buffered {
        q.buffered_rows[q.count] = row
        q.count += 1
    } else {
        q.rows[q.count] = row

        if !row.clock_valid || row.elapsed_us >= 10000 || error != .None || (!before.fenced && after.fenced) {
            log_json("SAMPLE_OPERATION_SLOW", row)

            if q.phase_detail {
                qualification_phase_report(self, phase_before, row)
            }
        }

        q.count += 1

        if q.count == len(q.rows) {
            qualification_flush(self)
        }
    }

    // Observe actual producer transfer storage, outside the measured operation.
    // The entire attachment is a conservative upper bound on its Native payload.
    if state.session.authority && state.session.server.physics != nil {
        for tx in state.session.server.physics.tx {
            if u64(len(tx.data.bytes)) > q.maximum_complete_wire_bytes {
                image, inspect_error := net.complete_inspect(
                    tx.data.bytes,
                    state.codec.value.identity,
                    state.session.server.cfg.epoch,
                )

                if inspect_error != .None {
                    error_set(self, "qualification.producer transfer inspection")
                    return error
                }

                q.maximum_complete_wire_bytes = u64(len(tx.data.bytes))
                q.maximum_attachment_bytes = max(q.maximum_attachment_bytes, u64(len(image.attachment)))

                if !q.buffered {
                    log_json("SAMPLE_QUALIFICATION_TRANSFER", struct {
                        role:                                                  string,
                        complete_wire_bytes, native_payload_upper_bound_bytes: u64,
                    }{self.role, q.maximum_complete_wire_bytes, q.maximum_attachment_bytes})
                }
            }
        }
    }

    return error
}
