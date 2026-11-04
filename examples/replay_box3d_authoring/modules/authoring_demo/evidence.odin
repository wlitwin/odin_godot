package replay_authoring_demo

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:os"
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
    return os.write_entire_file(path, bytes) == nil
}

log_json :: proc(tag: string, value: $T) {
    bytes, error := json.marshal(value)

    if error != nil {
        return
    }

    defer delete(bytes)
    gd.print_str(fmt.tprintf("%s %s", tag, string(bytes)))
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

export_final :: proc(self: ^ReplayAuthoringDemo) -> bool {
    state := self.state
    checkpoint, error := rgd.session_checkpoint(&state.session, self.target)

    if error != .None {
        error_set(self, "final.complete_checkpoint unavailable")
        return false
    }

    defer r.complete_checkpoint_destroy(&checkpoint)
    schemas := self.hosting ? &state.session.server.physics.schemas : &state.session.client.physics.schemas
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

            if os.write_entire_file(fmt.tprintf("%s/%s", state.output, name), bytes) != nil {
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

        if signature_error != .None ||
           os.write_entire_file(fmt.tprintf("%s/signature.bin", state.output), bytes[:]) != nil {
            error_set(self, "final.signature.write")
            return false
        }

        manifest.signature_sha256 = hash_hex(bd.hash_bytes(bytes[:]))

        if !json_write(fmt.tprintf("%s/final-frame.json", state.output), manifest) {
            error_set(self, "final.manifest.write")
            return false
        }
    }

    self.have_final = true
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

publish_presentation :: proc(self: ^ReplayAuthoringDemo) {
    if self.state == nil || (!self.hosting && self.state.session.client.phase != .Running) {
        return
    }

    checkpoint, error := rgd.session_checkpoint(&self.state.session, self.confirmed)

    if error != .None {
        return
    }

    defer r.complete_checkpoint_destroy(&checkpoint)
    revision :=
        self.hosting ? u64(0) : self.state.session.client.view_reset + self.state.session.client.stats.corrections
    frame, projection_error, owner_error := rgd.physics_presentation_frame(&checkpoint, project, revision, .Confirmed)

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
replay_authoring_demo_presentation :: proc(self: ^ReplayAuthoringDemo) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    bodies: [4]Body_Value
    count := 0
    names := BODY_NAMES

    if self.have_presentation {
        for row in self.presentation_value.rows[:self.presentation_value.count] {
            name := ""

            for id, i in self.presentation_value.rows[:self.presentation_value.count] {
                if id.body == row.body {
                    name = names[i]
                    break
                }
            }

            bodies[count] = {name, row.pose.position, row.pose.rotation}
            count += 1
        }
    }

    return json_string(struct {
        version: u32,
        bodies:  []Body_Value,
    }{1, bodies[:count]})
}

@(gd_method = "owned_return")
replay_authoring_demo_status :: proc(self: ^ReplayAuthoringDemo) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    return gd.new_string_odin(public_status_json(self))
}

current_game :: proc(self: ^ReplayAuthoringDemo) -> Game {
    if self.state == nil {
        return {}
    }

    value, ok := rgd.session_values(&self.state.session)
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

finish :: proc(self: ^ReplayAuthoringDemo) {
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

    gd.scene_tree_quit(gd.node_get_tree(self.owner), result.ok ? 0 : 1)
}
