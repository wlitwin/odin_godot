package dockyard_duo

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:encoding/base64"
import "godot:gdext"
import gd "godot:godot"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import bp "godot:box3d/presentation"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"

hash_hex :: proc(value: [32]u8) -> string {
    bytes := make([]u8, 64, context.temp_allocator)
    digits := "0123456789abcdef"

    for byte, i in value {
        bytes[i * 2] = digits[byte >> 4]
        bytes[i * 2 + 1] = digits[byte & 15]
    }

    return string(bytes)
}

json_string :: proc(value: $T) -> gd.String {
    bytes, error := json.marshal(value)

    if error != nil {
        return gd.new_string_odin("{\"error\":\"JSON\"}")
    }

    defer delete(bytes)
    return gd.new_string_odin(string(bytes))
}

json_write :: proc(path: string, value: $T) -> bool {
    bytes, error := json.marshal(value)

    if error != nil {
        return false
    }

    defer delete(bytes)
    return write_bytes(path, bytes)
}

log_json :: proc(tag: string, value: $T) {
    bytes, error := json.marshal(value)

    if error != nil {
        return
    }

    defer delete(bytes)
    gd.print_str(fmt.tprintf("%s %s", tag, string(bytes)))
}

// Portable engine I/O keeps the native diagnostic-file contract. Web exports
// emit one exact base64 frame row instead of passing native pointers through JS.
write_bytes :: proc(path: string, bytes: []u8) -> bool {
    destination := gd.new_string_odin(path)
    defer gd.free_string(destination)
    file := gd.file_access_open(destination, .Write)

    if file == nil {
        return false
    }

    defer if gd.ref_counted_unreference(file) {
        gdext.object_destroy(file)
    }

    packet := gd.new_packed_byte_array()
    defer gd.free_packed_byte_array(packet)

    if gd.packed_byte_array_resize(&packet, gd.Int(len(bytes))) != 0 {
        gd.file_access_close(file)
        return false
    }

    copy(gd.packed_byte_array_view(&packet), bytes)
    stored := gd.file_access_store_buffer(file, packet)
    gd.file_access_flush(file)
    good := stored && gd.file_access_get_error(file) == .Ok && gd.file_access_get_length(file) == u64(len(bytes))
    gd.file_access_close(file)
    return good
}

Web_Part :: struct {
    name, sha256, base64: string,
    bytes:                u64,
}

complete_parts :: proc(frame: bd.Frame_View) -> ([5]Web_Part, bool) {
    parts: [5]Web_Part

    for part in bd.Part {
        payload := frame.parts[part]
        encoded, error := base64.encode(payload, allocator = context.temp_allocator)

        if error != nil {
            return {}, false
        }

        parts[int(part)] = {fmt.tprintf("%v", part), hash_hex(bd.hash_bytes(payload)), encoded, u64(len(payload))}
    }

    return parts, true
}

log_stopped_frame :: proc(self: ^DockyardDuo, tag: string) -> bool {
    if self.state == nil || !self.state.session.ready {
        return false
    }

    s := self.state.session
    tick := self.hosting ? s.server.timeline.confirmed : s.client.timeline.confirmed
    checkpoint, error := rgd.session_checkpoint(s, tick)

    if error != .None {
        return false
    }

    defer r.complete_checkpoint_destroy(&checkpoint)
    schemas := self.hosting ? &s.server.physics.schemas : &s.client.physics.schemas
    frame, view_error := net.complete_view(
        self.state.codec.value,
        &checkpoint,
        &schemas.state,
        &schemas.occurrence,
        meter.allocator(self.scope),
    )

    if view_error != .None {
        return false
    }

    defer net.complete_view_destroy(&frame)
    parts, ok := complete_parts(frame.frame)

    if !ok {
        return false
    }

    log_json(tag, struct {
        role:        string,
        epoch, tick: u64,
        parts:       [5]Web_Part,
    }{self.role, frame.frame.epoch, frame.frame.tick, parts})
    return true
}

File_Part :: struct {
    file, sha256: string,
}

File_Parts :: struct {
    Solver, Game, Side, Observations, Occurrences: File_Part,
}

Final_View :: struct {
    epoch, tick:      u64,
    content_sha256:   string,
    parts:            File_Parts,
    signature_file:   string,
    signature_sha256: string,
}

export_final :: proc(self: ^DockyardDuo) -> bool {
    state := self.state
    checkpoint, error := rgd.session_checkpoint(state.session, self.target)

    if error != .None {
        error_set(self, "final.complete_checkpoint unavailable")
        return false
    }

    defer r.complete_checkpoint_destroy(&checkpoint)
    schemas := self.hosting ? state.session.server.physics.schemas : state.session.client.physics.schemas
    view, ve := net.complete_view(
        state.codec.value,
        &checkpoint,
        &schemas.state,
        &schemas.occurrence,
        meter.allocator(self.scope),
    )

    if ve != .None {
        error_set(self, "final.complete_view")
        return false
    }

    defer net.complete_view_destroy(&view)
    signature, se := bd.sign(view.frame)

    if se != .None {
        error_set(self, "final.signature")
        return false
    }

    self.final_signature = signature

    when gd.IS_WEB {
        parts, parts_ok := complete_parts(view.frame)

        if !parts_ok {
            error_set(self, "final.base64")
            return false
        }

        signature_bytes: [bd.SIGNATURE_BYTES]u8
        _, signature_error := bd.signature_encode(signature, signature_bytes[:])

        if signature_error != .None {
            error_set(self, "final.signature.encode")
            return false
        }

        encoded_signature, encoding_error := base64.encode(signature_bytes[:], allocator = context.temp_allocator)

        if encoding_error != nil {
            error_set(self, "final.signature.base64")
            return false
        }

        log_json("SAMPLE_WEB_FRAME", struct {
            framework, role:  string,
            epoch, tick:      u64,
            content_sha256:   string,
            parts:            [5]Web_Part,
            signature_base64: string,
        }{"Replay", self.role, view.frame.epoch, view.frame.tick, hash_hex(self.content), parts, encoded_signature})
    }

    if len(state.output) > 0 {
        manifest := Final_View {
            epoch          = view.frame.epoch,
            tick           = view.frame.tick,
            content_sha256 = hash_hex(self.content),
            signature_file = "signature.bin",
        }

        for part in bd.Part {
            name := fmt.tprintf("%v.bin", part)
            bytes := view.frame.parts[part]

            if !write_bytes(fmt.tprintf("%s/%s", state.output, name), bytes) {
                error_set(self, "final.part.write")
                return false
            }

            entry := File_Part{name, hash_hex(bd.hash_bytes(bytes))}

            switch part {
            case .Solver:
                manifest.parts.Solver = entry
            case .Game:
                manifest.parts.Game = entry
            case .Side:
                manifest.parts.Side = entry
            case .Observations:
                manifest.parts.Observations = entry
            case .Occurrences:
                manifest.parts.Occurrences = entry
            }
        }

        bytes: [bd.SIGNATURE_BYTES]u8
        _, signature_error := bd.signature_encode(signature, bytes[:])

        if signature_error != .None || !write_bytes(fmt.tprintf("%s/signature.bin", state.output), bytes[:]) {
            error_set(self, "final.signature.write")
            return false
        }

        manifest.signature_sha256 = hash_hex(bd.hash_bytes(bytes[:]))

        if !json_write(fmt.tprintf("%s/final-frame.json", state.output), manifest) {
            error_set(self, "final.manifest.write")
            return false
        }
    }

    game := checkpoint.frame.state
    positions: [3][3]f32

    for position, i in game.previous {
        positions[i] = {position.x, position.y, position.z}
    }

    log_json("SAMPLE_GAME", struct {
        role:                   string,
        tick:                   u64,
        score:                  u8,
        delivered, inside:      [3]bool,
        dwell:                  [3]u16,
        cargo_positions:        [3][3]f32,
        eligible_delivery_cues: u64,
        game_sha256:            string,
        round:                  u32,
        layout:                 u8,
        phase:                  string,
        round_ticks, payout:    u32,
        lost:                   [3]bool,
        recovered:              [2]u16,
    } {
        self.role,
        checkpoint.frame.tick,
        game.score,
        game.delivered,
        game.inside,
        game.dwell,
        positions,
        self.fx,
        hash_hex(bd.hash_bytes(view.frame.parts[.Game])),
        game.round,
        game.layout,
        fmt.tprintf("%v", game.phase),
        game.round_ticks,
        game.payout,
        game.lost,
        game.recovered,
    })
    native_frame, frame_error, frame_owner_error := rgd.physics_presentation_frame(&checkpoint, project, 0, .Confirmed)

    if frame_error == .None && frame_owner_error == .None {
        robots: [2][3]f32

        for row in native_frame.rows[:native_frame.count] {
            for key, i in game.bodies[1:3] {
                if row.body == bp.Body_Key(key) {
                    robots[i] = row.pose.position
                    break
                }
            }
        }

        log_json("SAMPLE_CARRY", struct {
            role:            string,
            tick:            u64,
            robot_positions: [2][3]f32,
            magnet:          [2]u8,
            queries:         u32,
        }{self.role, checkpoint.frame.tick, robots, game.magnet, game.queries})
    }

    self.have_final = true
    stats := self.hosting ? state.session.server.stats : state.session.client.stats
    repair_available := !self.hosting && state.session.client.physics != nil
    repair_limit := self.hosting ? state.session.server.cfg.max_prediction : state.session.client.cfg.max_prediction
    last_planned, last_executed: u64

    if repair_available {
        last_planned = state.session.client.physics.last_planned_depth
        last_executed = state.session.client.physics.last_executed_steps
    }

    log_json("SAMPLE_NETWORK", struct {
        role:                                                      string,
        stats:                                                     net.Stats,
        action_outcomes, action_applied, accepted_actions:         [2]u64,
        boost_fx, issued_sequence, boosts:                         u64,
        repair_available:                                          bool,
        repair_profile_limit:                                      u32,
        last_planned_depth, last_executed_steps:                   u64,
        session_role:                                              string,
        seat:                                                      u16,
        controls_consumed, frontier_samples, max_prediction_ahead: u64,
        resumed_prior_actions:                                     bool,
    } {
        self.role,
        stats,
        self.action_outcomes,
        self.action_applied,
        self.accepted_actions,
        self.boost_fx,
        self.scripted_boost_sequence,
        game.pulses,
        repair_available,
        repair_limit,
        last_planned,
        last_executed,
        fmt.tprintf("%v", state.session.role),
        rgd.session_seat(state.session),
        self.controls_consumed,
        self.frontier_samples,
        self.max_prediction_ahead,
        self.resumed_prior_actions,
    })
    log_json("SAMPLE_INPUTS", struct {
        framework, role:                                          string,
        first, last, rows, sample, held, local, neutral, nonzero: u64,
        coverage_complete, origin_coverage_complete:              bool,
        origin_observed, origin_unavailable:                      u64,
        controls_by_seat, nonzero_by_seat:                        [2]u64,
    } {
        "Replay",
        self.role,
        self.first_accepted,
        self.last_accepted,
        self.accepted_rows,
        self.sample_rows,
        self.held_rows,
        self.local_rows,
        self.neutral_rows,
        self.nonzero_rows,
        !self.accepted_gap,
        self.origin_unavailable == 0,
        self.origin_observed,
        self.origin_unavailable,
        self.controls_by_seat,
        self.nonzero_by_seat,
    })
    log_json("SAMPLE_FINAL", struct {
        framework, role: string,
        epoch, tick:     u64,
        complete:        string,
    }{"Replay", self.role, signature.epoch, signature.tick, hash_hex(signature.complete)})
    return true
}

publish_presentation :: proc(self: ^DockyardDuo) {
    if self.state == nil || (!self.hosting && self.state.session.client.phase != .Running) {
        return
    }

    checkpoint, error := rgd.session_checkpoint(self.state.session, self.head)

    if error != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&checkpoint)
    revision :=
        self.hosting ? u64(0) : self.state.session.client.view_reset + self.state.session.client.stats.corrections
    frame, projection_error, owner_error := rgd.physics_presentation_frame(
        &checkpoint,
        project,
        revision,
        self.hosting ? .Confirmed : .Predicted,
    )

    if owner_error != .None || projection_error != .None {
        error_set(self, "presentation.complete_frame")
        return
    }

    self.presentation_value = frame
    self.have_presentation = true
}

Body_Value :: struct {
    key:      string,
    position: [3]f32,
    rotation: [4]f32,
}

@(gd_method = "owned_return")
dockyard_duo_presentation :: proc(self: ^DockyardDuo) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    bodies: [BODY_COUNT]Body_Value
    count := 0
    names := BODY_NAMES
    game := current_game(self)

    if self.have_presentation {
        for row in self.presentation_value.rows[:self.presentation_value.count] {
            name := ""

            for key, i in game.bodies {
                if bp.Body_Key(key) == row.body {
                    name = names[i]
                    break
                }
            }

            bodies[count] = {name, row.pose.position, row.pose.rotation}
            count += 1
        }
    }

    remaining := ROUND_TICKS - min(game.round_ticks, ROUND_TICKS)
    names_of_jobs := JOB_NAMES
    cues: [16]Presentation_Cue
    cue_count := 0
    sequence: u64

    if self.state != nil {
        sequence = self.state.cue_sequence
        cue_count = int(min(sequence, u64(len(cues))))

        for i in 0 ..< cue_count {
            serial := sequence - u64(cue_count) + u64(i) + 1
            cues[i] = self.state.cues[(serial - 1) % u64(len(cues))]
        }
    }

    return json_string(struct {
        version:                 u32,
        bodies:                  []Body_Value,
        score:                   u8,
        delivered, lost:         [3]bool,
        dwell:                   [3]u16,
        magnet:                  [2]u8,
        cooldown, recovered:     [2]u16,
        round:                   u32,
        layout:                  u8,
        job, phase:              string,
        remaining_ticks, payout: u32,
        confirmed_cue_sequence:  u64,
        confirmed_cues:          []Presentation_Cue,
    } {
        1,
        bodies[:count],
        game.score,
        game.delivered,
        game.lost,
        game.dwell,
        game.magnet,
        game.cooldown,
        game.recovered,
        game.round,
        game.layout,
        names_of_jobs[game.layout],
        fmt.tprintf("%v", game.phase),
        remaining,
        game.payout,
        sequence,
        cues[:cue_count],
    })
}

@(gd_method = "owned_return")
dockyard_duo_status :: proc(self: ^DockyardDuo) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    return gd.new_string_odin(public_status_json(self))
}

current_game :: proc(self: ^DockyardDuo) -> Game {
    if self.state == nil || !self.state.session.ready {
        return {}
    }

    value, ok := rgd.session_values(self.state.session)
    return ok ? value.state : Game{}
}

owner_count_observe :: proc() -> (u64, bool) {
    contract, cs := b.domain_contract_get()

    if cs != .Ok {
        return 0, false
    }

    ledger, ls := b.host_ledger_get(contract.cookie)
    return u64(ledger.owner_count), ls == .Ok
}

Cleanup :: struct {
    native, wrapper, meter:      u64,
    owners:                      i64,
    owners_before, owners_after: u64,
    observed:                    bool,
}

Result :: struct {
    framework, role:                     string,
    ok:                                  bool,
    target, head, confirmed, final_tick: u64,
    errors:                              []string,
    cleanup:                             Cleanup,
}

finish :: proc(self: ^DockyardDuo) {
    if self.finished {
        return
    }

    self.finished = true
    closed := close_runtime(self)

    if !closed {
        error_set(self, "cleanup.retained_owner")
    }

    native, ns := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    provider, ps := meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER)
    core, cs := meter.category_stats(bg.CATEGORY_REPLAY_CORE)
    owners_after, owners_after_observed := owner_count_observe()
    observed :=
        ns == .Ok && ws == .Ok && ps == bg.OK && cs == bg.OK && self.owners_before_observed && owners_after_observed

    if !observed {
        error_set(self, "cleanup.stats unavailable")
    }

    cleanup := Cleanup {
        native.live_bytes,
        wrapper.live_bytes,
        provider.live_bytes + core.live_bytes,
        i64(owners_after) - i64(self.owners_before),
        self.owners_before,
        owners_after,
        observed,
    }

    if cleanup.native != 0 || cleanup.wrapper != 0 || cleanup.meter != 0 || cleanup.owners != 0 {
        error_set(self, "cleanup.nonzero")
    }

    messages: [1]string
    count := 0

    if self.error_count > 0 {
        messages[0] = string(self.error_text[:self.error_count])
        count = 1
    }

    result := Result {
        "Replay",
        self.role,
        !self.failed && closed,
        self.target,
        self.head,
        self.confirmed,
        self.have_final ? self.final_signature.tick : 0,
        messages[:count],
        cleanup,
    }
    bytes, error := json.marshal(result)

    if error == nil {
        gd.print_str(fmt.tprintf("SAMPLE_RESULT %s", string(bytes)))
        delete(bytes)
    }

    exit_code := gd.Int(result.ok ? 0 : 1)
    path := gd.new_node_path_cstring("View")
    defer gd.free_node_path(path)
    presentation := gd.node_get_node_or_null(self.owner, path)
    method := gd.new_string_name_cstring("request_exit", false)
    defer gd.free_string_name(method)

    if presentation != nil && gd.object_has_method(presentation, method) {
        argument := gd.variant_from(&exit_code)
        defer gd.variant_destroy(&argument)
        deferred := gd.object_call_deferred(presentation, method, argument)
        gd.variant_destroy(&deferred)
    } else {
        // Standalone non-presentation fixtures have no audio graph to drain.
        gd.scene_tree_quit(gd.node_get_tree(self.owner), exit_code)
    }
}
