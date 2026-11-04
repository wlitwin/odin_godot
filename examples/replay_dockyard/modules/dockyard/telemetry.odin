package dockyard_duo

import "core:encoding/json"
import "core:fmt"
import "core:strings"
import b "godot:box3d"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"

Status_Cache :: struct {
    native_observed,
    meter_observed:                                                                                                    bool,
    native_sampled_frame,
    meter_sampled_frame:                                                                                          u64,
    native_live_bytes,
    wrapper_live_bytes,
    host_live_bytes,
    reserved_bytes,
    admitted_bytes,
    limit_bytes,
    owner_count,
    meter_live_bytes: u64,
}

Validated_Scope :: struct {
    epoch, generation, serial, baseline: u64,
}

Optional_Number :: struct {
    name:      string,
    value:     u64,
    available: bool,
}

observe_memory :: proc(self: ^DockyardDuo) {
    contract, cs := b.domain_contract_get()
    self.status_cache.native_observed = false

    if cs == .Ok {
        ledger, ls := b.host_ledger_get(contract.cookie)

        if ls == .Ok {
            self.status_cache.native_observed = true
            self.status_cache.native_sampled_frame = self.frames
            self.status_cache.native_live_bytes = ledger.engine_live_bytes
            self.status_cache.wrapper_live_bytes = ledger.snapshot_live_bytes
            self.status_cache.host_live_bytes = ledger.host_live_bytes
            self.status_cache.reserved_bytes = ledger.host_reserved_bytes
            self.status_cache.admitted_bytes = ledger.admitted_bytes
            self.status_cache.limit_bytes = ledger.limit_bytes
            self.status_cache.owner_count = u64(ledger.owner_count)
        }
    }

    provider, ps := meter.category_stats(bg.CATEGORY_REPLAY_PROVIDER)
    core, ks := meter.category_stats(bg.CATEGORY_REPLAY_CORE)
    self.status_cache.meter_observed = ps == bg.OK && ks == bg.OK

    if self.status_cache.meter_observed {
        self.status_cache.meter_sampled_frame = self.frames
        self.status_cache.meter_live_bytes = provider.live_bytes + core.live_bytes
    }
}

// A complete-mode Running client has installed a validated complete Welcome.
// Serial/generation/baseline below are the public committed scope, not a head
// delta, request counter or manufactured Resync notice. This is observational
// Node state only, never part of canonical Game or a recovery implementation.
observe_recovery_scope :: proc(self: ^DockyardDuo) {
    if self.hosting || self.state == nil {
        return
    }

    c := self.state.session.client

    if !c.initialized || !c.has_world || c.phase != .Running || c.generation == 0 || c.serial == 0 {
        return
    }

    scope := Validated_Scope{c.cfg.epoch, c.generation, c.serial, c.baseline}

    if self.recovery_scope_seen && scope != self.validated_scope {
        self.recoveries += 1
    }

    self.validated_scope = scope
    self.recovery_scope_seen = true
}

recovery_available :: proc(self: ^DockyardDuo) -> bool {
    if self.hosting || self.state == nil || !self.recovery_scope_seen {
        return false
    }

    c := self.state.session.client
    return(
        c.initialized &&
        c.has_world &&
        c.phase == .Running &&
        c.generation != 0 &&
        c.serial != 0 &&
        self.validated_scope == (Validated_Scope{c.cfg.epoch, c.generation, c.serial, c.baseline}) \
    )
}

public_status_json :: proc(self: ^DockyardDuo) -> string {
    phase := "closed"
    head, confirmed, epoch: u64
    frontiers := false
    member, incarnation: u64

    if self.state != nil && self.state.online.enabled && self.state.room.registered {
        member = self.state.room.options.identity.member
        incarnation = self.state.room.options.identity.incarnation
    }

    pending_actions: u64

    if self.state != nil && !self.hosting && self.state.session.client.initialized {
        pending_actions = u64(self.state.session.client.action_count)
    }

    if self.state != nil {
        s := self.state.session
        phase = !s.ready ? "Menu" : self.hosting ? "Host" : fmt.tprintf("%v", s.client.phase)

        if self.hosting && s.server.initialized {
            head = s.server.timeline.head
            confirmed = head
            epoch = s.server.cfg.epoch
            frontiers = true
        }

        if !self.hosting && s.client.initialized && s.client.has_world {
            head = s.client.timeline.head
            confirmed = s.client.timeline.confirmed
            epoch = s.client.cfg.epoch
            frontiers = true
        }
    }

    native := self.state != nil && self.status_cache.native_observed
    meter_observed := self.state != nil && self.status_cache.meter_observed
    recovery := recovery_available(self)
    error := string(self.error_text[:self.error_count])

    if len(error) == 0 && self.reset_requested {
        error = "Unsupported"
    }

    game := current_game(self)
    base := struct {
        version:                                             u32,
        framework, role, phase:                              string,
        go:                                                  bool,
        frames:                                              u64,
        error:                                               string,
        reset_supported:                                     bool,
        content_sha256:                                      string,
        queries:                                             u32,
        sensor_events, pulses, accepted_rows:                u64,
        accepted_history_unavailable:                        bool,
        origin_coverage_complete:                            bool,
        origin_observed, origin_unavailable:                 u64,
        controls_by_seat, nonzero_by_seat:                   [2]u64,
        native_observed, meter_observed, recovery_available: bool,
        issued_sequence, pending_actions:                    u64,
        action_outcomes, action_applied:                     [2]u64,
        member, incarnation:                                 string,
    } {
        1,
        "Replay",
        self.role,
        phase,
        self.go,
        self.frames,
        error,
        false,
        hash_hex(self.content),
        game.queries,
        game.sensor_events,
        game.pulses,
        self.accepted_rows,
        self.accepted_gap,
        self.origin_unavailable == 0,
        self.origin_observed,
        self.origin_unavailable,
        self.controls_by_seat,
        self.nonzero_by_seat,
        native,
        meter_observed,
        recovery,
        self.scripted_boost_sequence,
        pending_actions,
        self.action_outcomes,
        self.action_applied,
        fmt.tprintf("%016x", member),
        fmt.tprintf("%016x", incarnation),
    }
    encoded, je := json.marshal(base)

    if je != nil {
        return "{\"version\":1,\"error\":\"status.JSON\"}"
    }

    defer delete(encoded)
    // Core JSON pointer/any reflection is not used: null means unavailable, not0.
    buffer: [4096]u8
    at := copy(buffer[:], encoded[:len(encoded) - 1])
    values := [18]Optional_Number {
        {"head", head, frontiers},
        {"confirmed", confirmed, frontiers},
        {"epoch", epoch, frontiers},
        {"native_live_bytes", self.status_cache.native_live_bytes, native},
        {"wrapper_live_bytes", self.status_cache.wrapper_live_bytes, native},
        {"host_live_bytes", self.status_cache.host_live_bytes, native},
        {"reserved_bytes", self.status_cache.reserved_bytes, native},
        {"admitted_bytes", self.status_cache.admitted_bytes, native},
        {"limit_bytes", self.status_cache.limit_bytes, native},
        {"owner_count", self.status_cache.owner_count, native},
        {"meter_live_bytes", self.status_cache.meter_live_bytes, meter_observed},
        {"native_sampled_frame", self.status_cache.native_sampled_frame, native},
        {"meter_sampled_frame", self.status_cache.meter_sampled_frame, meter_observed},
        {"recoveries", self.recoveries, recovery},
        {"recovery_serial", self.validated_scope.serial, recovery},
        {"baseline", self.validated_scope.baseline, recovery},
        {"recovery_generation", self.validated_scope.generation, recovery},
        {"recovery_epoch", self.validated_scope.epoch, recovery},
    }

    for value in values {
        token :=
            value.available ? fmt.tprintf(",\"%s\":%d", value.name, value.value) : fmt.tprintf(",\"%s\":null", value.name)

        if at + len(token) + 1 > len(buffer) {
            return "{\"version\":1,\"error\":\"status.capacity\"}"
        }

        at += copy(buffer[at:], transmute([]u8)token)
    }

    buffer[at] = '}'
    at += 1
    return strings.clone(string(buffer[:at]), context.temp_allocator)
}
