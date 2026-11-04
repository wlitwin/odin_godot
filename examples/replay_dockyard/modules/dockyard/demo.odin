//gd:extends Node3D
//gd:class DockyardDuo
package dockyard_duo

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
import r "godot:replay"
import net "godot:replay/net"
import view "godot:replay/view"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"

Observer_Tail :: struct {
    peer:         tr.Peer_Id,
    generation:   u64,
    acknowledged: bool,
}

Presentation_Cue :: struct {
    sequence: u64,
    kind:     u8,
    index:    u32,
}

Runtime :: struct {
    room:                                    rgd.Room(Game, Control, Action, Event, 2),
    session:                                 ^rgd.Session(Game, Control, Action, Event, 2), // borrowed alias to the single room.session storage
    initial:                                 r.Complete_Checkpoint(Game, net.Net_Event(Event)),
    online:                                  Online,
    codec:                                   Codec,
    catalog:                                 b.Recovery_Catalog,
    baked:                                   a.Baked_Scene,
    built:                                   a.Built_Scene,
    image_owner, codec_owner, session_owner: ph.Owner_Context,
    output:                                  string,
    address:                                 cstring,
    delivery_route:                          view.Cue_Route(net.Net_Event(Event), u32),
    delivery_route_ready:                    bool,
    boost_route:                             view.Cue_Route(net.Net_Event(Event), u32),
    boost_route_ready:                       bool,
    driver_token_hash:                       [32]u8,
    ready_generation:                        u64,
    observer_tails:                          [net.MAX_PEERS]Observer_Tail,
    cues:                                    [16]Presentation_Cue,
    cue_sequence:                            u64,
    qualification:                           Qualification,
}

DockyardDuo :: struct {
    owner:                                                                                                                       gd.Node3d,
    scope:                                                                                                                       ^meter.Context,
    state:                                                                                                                       ^Runtime,
    hosting,
    observing,
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
    visuals_prepared:                                                                                                            bool,
    role:                                                                                                                        string,
    target,
    head,
    confirmed,
    frames,
    tail_frames,
    fx,
    accepted_rows:                                                             u64,
    frame_budget:                                                                                                                u64,
    status_elapsed:                                                                                                              f64,
    status_cache:                                                                                                                Status_Cache,
    validated_scope:                                                                                                             Validated_Scope,
    recovery_scope_seen,
    room_announced:                                                                                         bool,
    recoveries:                                                                                                                  u64,
    first_accepted,
    last_accepted,
    sample_rows,
    held_rows,
    local_rows,
    neutral_rows,
    nonzero_rows:                               u64,
    origin_observed,
    origin_unavailable:                                                                                         u64,
    controls_by_seat,
    nonzero_by_seat:                                                                                           [2]u64,
    accepted_started:                                                                                                            bool,
    accepted_scope_epoch,
    accepted_scope_generation,
    accepted_scope_serial,
    accepted_scope_baseline:                             u64,
    accepted_snapshot_catchups:                                                                                                  u64,
    accepted_gap:                                                                                                                bool,
    owners_before:                                                                                                               u64,
    owners_before_observed:                                                                                                      bool,
    content:                                                                                                                     [32]u8,
    presentation_value:                                                                                                          bp.Frame,
    have_presentation:                                                                                                           bool,
    final_signature:                                                                                                             bd.Signature,
    terminal_peer:                                                                                                               tr.Peer_Id,
    terminal_epoch,
    terminal_generation:                                                                                         u64,
    pending:                                                                                                                     Control,
    pulse_down:                                                                                                                  bool,
    scripted_boost_sequence,
    boost_fx:                                                                                           u64,
    resumed_prior_actions:                                                                                                       bool,
    carry_round:                                                                                                                 u32,
    carry_cargo:                                                                                                                 i32,
    carry_stage,
    carry_nav:                                                                                                      u8,
    action_outcomes,
    action_applied:                                                                                             [2]u64,
    controls_consumed,
    frontier_samples,
    max_prediction_ahead:                                                                   u64,
    accepted_actions:                                                                                                            [2]u64,
    reset_requested:                                                                                                             bool,
    error_text:                                                                                                                  [256]u8,
    error_count:                                                                                                                 int,
}

@(gd_method)
dockyard_duo_visuals_ready :: proc(self: ^DockyardDuo) {
    self.visuals_prepared = true
}

@(gd_method)
dockyard_duo_control :: proc(self: ^DockyardDuo, x, z, aim_x, aim_y, aim_z: i32, grab, pulse: bool) {
    self.pending.x = i16(clamp(x, -100, 100))
    self.pending.z = i16(clamp(z, -100, 100))
    self.pending.aim_x = i16(clamp(aim_x, -1400, 1400))
    self.pending.aim_y = i16(clamp(aim_y, -1000, 1000))
    self.pending.aim_z = i16(clamp(aim_z, -1400, 1400))
    self.pending.grab = grab

    if pulse && !self.pulse_down {
        self.pending.pulse = true
    }

    self.pulse_down = pulse
}

@(gd_method)
dockyard_duo_request_reset :: proc(self: ^DockyardDuo) -> bool {
    // Replay's public Session has no manual Resync facade. Automatic complete
    // recovery remains owned by Replay; this sample does not call private APIs.
    self.reset_requested = true
    return false
}

@(gd_method)
dockyard_duo_retry :: proc(self: ^DockyardDuo, next_job: bool) -> bool {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)

    if self.state == nil || !self.hosting || !self.go || current_game(self).phase != .Results {
        return false
    }

    _, error := rgd.session_issue(self.state.session, Action{kind = next_job ? .Next_Job : .Retry})
    return error == .None
}

@(gd_method)
dockyard_duo_close :: proc(self: ^DockyardDuo) -> bool {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    return close_runtime(self)
}

dockyard_duo_exit_tree :: proc(self: ^DockyardDuo) {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)

    if self.state != nil {
        if !close_runtime(self) {
            gd.print_str("SAMPLE_CLOSE_ERROR Replay owner remains retained")
        }
    }
}

close_runtime :: proc(self: ^DockyardDuo) -> bool {
    if self.state != nil {
        state := self.state
        allocator := meter.allocator(self.scope)
        qualification_end(self)

        if !state.qualification.buffered {
            qualification_flush(self)
        }

        if state.online.enabled {
            if rgd.room_try_close(&state.room) != .None {
                return false
            }
        } else if rgd.session_close(state.session) != .None {
            return false
        }

        if state.qualification.buffered {
            qualification_flush(self)
        }

        if !online_close(self) {
            return false
        }

        if r.complete_checkpoint_destroy(&state.initial) != .None {
            return false
        }

        if state.delivery_route_ready {
            view.cue_route_destroy(&state.delivery_route)
            state.delivery_route_ready = false
        }

        if state.boost_route_ready {
            view.cue_route_destroy(&state.boost_route)
            state.boost_route_ready = false
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

        if state.address != nil {
            delete(state.address, allocator)
        }

        if state.qualification.buffered_rows != nil {
            delete(state.qualification.buffered_rows, allocator)
            state.qualification.buffered_rows = nil
        }

        if state.qualification.counter_rows != nil {
            delete(state.qualification.counter_rows, allocator)
            state.qualification.counter_rows = nil
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
