//gd:extends Node3D
//gd:class ReplayAuthoringDemo
package replay_authoring_demo

import "base:runtime"
import "core:mem"
import gd "godot:godot"
import b "godot:box3d"
import a "godot:box3d/authoring"
import bd "godot:box3d/diagnostics"
import bp "godot:box3d/presentation"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import ph "godot:replay/physics"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"

Runtime :: struct {
    session:                                 rgd.Session(Game, Control, Action, Event, 2),
    codec:                                   Codec,
    catalog:                                 b.Recovery_Catalog,
    baked:                                   a.Baked_Scene,
    built:                                   a.Built_Scene,
    image_owner, codec_owner, session_owner: ph.Owner_Context,
    output:                                  string,
}

ReplayAuthoringDemo :: struct {
    owner:                                                                                                            gd.Node3d,
    scope:                                                                                                            ^meter.Context,
    state:                                                                                                            ^Runtime,
    hosting,
    scripted,
    ready,
    go,
    failed,
    finished,
    announced,
    have_final,
    got_close,
    terminal_ready,
    terminal_final: bool,
    role:                                                                                                             string,
    target,
    head,
    confirmed,
    frames,
    tail_frames,
    fx,
    accepted_rows:                                                  u64,
    frame_budget:                                                                                                     u64,
    status_elapsed:                                                                                                   f64,
    status_cache:                                                                                                     Status_Cache,
    validated_scope:                                                                                                  Validated_Scope,
    recovery_scope_seen:                                                                                              bool,
    recoveries:                                                                                                       u64,
    first_accepted,
    last_accepted,
    sample_rows,
    held_rows,
    local_rows,
    neutral_rows,
    nonzero_rows:                    u64,
    origin_observed,
    origin_unavailable:                                                                              u64,
    controls_by_seat,
    nonzero_by_seat:                                                                                [2]u64,
    accepted_started:                                                                                                 bool,
    accepted_scope_epoch,
    accepted_scope_generation,
    accepted_scope_serial,
    accepted_scope_baseline:                  u64,
    accepted_snapshot_catchups:                                                                                       u64,
    accepted_gap:                                                                                                     bool,
    owners_before:                                                                                                    u64,
    owners_before_observed:                                                                                           bool,
    content:                                                                                                          [32]u8,
    presentation_value:                                                                                               bp.Frame,
    have_presentation:                                                                                                bool,
    final_signature:                                                                                                  bd.Signature,
    terminal_peer:                                                                                                    tr.Peer_Id,
    terminal_epoch,
    terminal_generation:                                                                              u64,
    pending:                                                                                                          Control,
    pulse_down:                                                                                                       bool,
    reset_requested:                                                                                                  bool,
    error_text:                                                                                                       [256]u8,
    error_count:                                                                                                      int,
}

@(gd_method)
replay_authoring_demo_control :: proc(self: ^ReplayAuthoringDemo, x, z: i32, pulse: bool) {
    self.pending.x = i16(clamp(x, -1, 1))
    self.pending.z = i16(clamp(z, -1, 1))

    if pulse && !self.pulse_down {
        self.pending.pulse = true
    }

    self.pulse_down = pulse
}

@(gd_method)
replay_authoring_demo_request_reset :: proc(self: ^ReplayAuthoringDemo) -> bool {
    // Replay's public Session has no manual Resync facade. Automatic complete
    // recovery remains owned by Replay; this sample does not call private APIs.
    self.reset_requested = true
    return false
}

@(gd_method)
replay_authoring_demo_close :: proc(self: ^ReplayAuthoringDemo) -> bool {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    return close_runtime(self)
}

replay_authoring_demo_exit_tree :: proc(self: ^ReplayAuthoringDemo) {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)

    if self.state != nil {
        if !close_runtime(self) {
            gd.print_str("SAMPLE_CLOSE_ERROR Replay owner remains retained")
        }
    }
}

close_runtime :: proc(self: ^ReplayAuthoringDemo) -> bool {
    if self.state != nil {
        state := self.state
        allocator := meter.allocator(self.scope)

        if rgd.session_close(&state.session) != .None {
            return false
        }

        if state.codec.ready || state.codec.catalog._handle != nil {
            if ph.network_codec_destroy(&state.codec) != .None {
                return false
            }
        }

        if a.built_destroy(&state.built) != .Ok {
            return false
        }

        a.destroy(&state.baked)

        if b.recovery_catalog_destroy(&state.catalog) != .Ok {
            return false
        }

        if ph.owner_context_destroy(&state.session_owner) != .None {
            return false
        }

        if ph.owner_context_destroy(&state.codec_owner) != .None {
            return false
        }

        if ph.owner_context_destroy(&state.image_owner) != .None {
            return false
        }

        if len(state.output) > 0 {
            delete(state.output, allocator)
        }

        mem.free(state, allocator)
        self.state = nil
    }

    if self.scope != nil {
        if meter.destroy(&self.scope) != bg.OK {
            return false
        }
    }

    self.ready = false
    return true
}
