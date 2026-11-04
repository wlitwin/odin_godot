// Value-only rendering consumer of the existing Replay presentation bridge.
package replay_box3d

import "core:fmt"
import gd "godot:godot"
import b "godot:box3d"
import bp "godot:box3d/presentation"
import net "godot:replay/net"
import r "godot:replay"
import rgd "godot:replay/godot"
import scene "godot:replay/godot/scene"
import view "godot:replay/view"
import common "godot:examples/box3d_common"

Visual_Scope :: struct {
    epoch, serial, view_reset, corrections: u64,
}

Slice_Presentation :: struct {
    phase:                                            view.Tick_Phase,
    scope:                                            Visual_Scope,
    scope_ready, have_current, have_previous:         bool,
    revision:                                         u64,
    previous, current:                                bp.Frame,
    proxies:                                          bp.View,
    tokens:                                           [33]bp.Token,
    active:                                           [33]bool,
    status:                                           bp.Status,
    last_effect:                                      bp.Effect_Observation,
    last_payload:                                     common.Event,
    have_effect:                                      bool,
    captures, interpolated, spawns, rebinds, removes: u64,
}

slice_bindings :: proc(game: common.Game, out: []bp.Binding) -> (u32, bp.Error) {
    bindings: [33]bp.Binding
    count := u32(0)

    for alive, index in game.alive {
        if !alive {
            continue
        }

        asset := common.CRATE_ASSET

        if index < 2 {
            asset = common.PLAYER_ASSET
        }

        if index == int(game.initial) {
            asset = common.SPAWN_ASSET
        }

        bindings[count] = {
            id    = {u64(index) + 1, game.lifetimes[index]},
            body  = bp.Body_Key(game.bodies[index]),
            asset = asset,
            seat  = index < 2 ? u16(index + 1) : 0,
            alive = true,
        }
        count += 1
    }

    if u64(len(out)) < u64(count) {
        return count, .Capacity
    }

    copy(out, bindings[:count])
    return count, .None
}

// The declared fixture has initial lives1..initial, then one reusable extra
// entity at indexinitial. Retired sensor ends map from their payload alone.
slice_effect_identity :: proc(value: net.Net_Event(common.Event), initial: u64) -> (bp.Identity, bool) {
    if value.kind != .Gameplay || value.value.serial == 0 || value.value.lifetime == 0 {
        return {}, false
    }

    life := value.value.lifetime
    return {entity = life <= initial ? life : initial + 1, lifetime = life}, true
}

slice_effect_small :: proc(value: net.Net_Event(common.Event)) -> (bp.Identity, bool) {
    return slice_effect_identity(value, 4)
}

slice_effect_large :: proc(value: net.Net_Event(common.Event)) -> (bp.Identity, bool) {
    return slice_effect_identity(value, 32)
}

slice_presentation_effect :: proc(self: ^ReplayBox3d, change: view.Change(net.Net_Event(common.Event))) {
    project := self.initial == 32 ? slice_effect_large : slice_effect_small
    observed, ok := rgd.physics_effect_observation(change, project)

    if ok {
        self.presentation.last_effect = observed
        self.presentation.last_payload = change.occurrence.value.value
        self.presentation.have_effect = true
    }
}

slice_proxy_style :: proc(self: ^ReplayBox3d, slot: u32, row: bp.Row, mesh_changed: bool) -> bool {
    node := self.meshes[slot]

    if mesh_changed {
        mesh: gd.Mesh

        switch row.asset {
        case common.PLAYER_ASSET:
            sphere := gd.new_sphere_mesh()
            gd.ref_counted_init_ref(sphere)
            gd.sphere_mesh_set_radius(sphere, .25)
            gd.sphere_mesh_set_height(sphere, .5)
            mesh = cast(gd.Mesh)sphere
        case common.SPAWN_ASSET:
            capsule := gd.new_capsule_mesh()
            gd.ref_counted_init_ref(capsule)
            gd.capsule_mesh_set_radius(capsule, .2)
            gd.capsule_mesh_set_height(capsule, .8)
            mesh = cast(gd.Mesh)capsule
        case common.CRATE_ASSET:
            box := gd.new_box_mesh()
            gd.ref_counted_init_ref(box)
            gd.box_mesh_set_size(box, {.5, .5, .5})
            mesh = cast(gd.Mesh)box
        case:
            return false
        }

        gd.mesh_instance3d_set_mesh(node, mesh)
        gd.release_ref(mesh)
    }

    color: gd.Color = {.36, .52, .7, 1}

    if row.seat == 1 {
        color = {.1, .8, .75, 1}
    }

    if row.seat == 2 {
        color = {1, .45, .16, 1}
    }

    if row.id.entity == 4 {
        color = {.95, .8, .15, 1}
    }

    if row.asset == common.SPAWN_ASSET {
        color = {.9, .25, .65, 1}
    }

    if !row.awake {
        color.r *= .55
        color.g *= .55
        color.b *= .55
    }

    material := gd.new_standard_material3d()
    gd.ref_counted_init_ref(material)
    gd.base_material3d_set_albedo(cast(gd.Base_Material3d)material, color)
    gd.geometry_instance3d_set_material_override(cast(gd.Geometry_Instance3d)node, cast(gd.Material)material)
    gd.release_ref(material)
    return true
}

slice_proxy_paint :: proc(self: ^ReplayBox3d, changes: []bp.Change) -> bool {
    p := &self.presentation

    for change in changes {
        slot := change.token.slot

        if slot >= u32(len(self.meshes)) {
            return false
        }

        node := cast(gd.Node3d)self.meshes[slot]

        switch change.kind {
        case .Remove:
            if !p.active[slot] || p.tokens[slot] != change.token {
                return false
            }

            p.active[slot] = false
            gd.node3d_set_visible(node, false)
            p.removes += 1
            continue
        case .Spawn:
            if p.active[slot] || change.token.generation <= p.tokens[slot].generation {
                return false
            }

            p.active[slot] = true
            p.tokens[slot] = change.token
            p.spawns += 1
        case .Rebind:
            if !p.active[slot] ||
               p.tokens[slot] != change.previous_token ||
               change.token.generation <= p.tokens[slot].generation {
                return false
            }

            p.tokens[slot] = change.token
            p.rebinds += 1
        case .Update:
            if !p.active[slot] || p.tokens[slot] != change.token {
                return false
            }
        }

        mesh_changed := change.kind == .Spawn || change.kind == .Rebind

        if mesh_changed || change.row.awake != change.previous.awake {
            if !slice_proxy_style(self, slot, change.row, mesh_changed) {
                return false
            }
        }

        gd.node3d_set_visible(node, true)
        gd.node3d_set_position(node, transmute(gd.Vector3)change.row.pose.position)
        gd.node3d_set_quaternion(node, transmute(gd.Quaternion)change.row.pose.rotation)

        if change.interpolated {
            p.interpolated += 1
        }
    }

    return true
}

slice_presentation_draw :: proc(self: ^ReplayBox3d, dt: f64) {
    if self.state == nil {
        return
    }

    s := &self.state.session
    p := &self.presentation
    status, status_error := rgd.physics_presentation_status(s)

    if status_error != .None {
        slice_fail(self, "presentation status")
        return
    }

    status.profile = common.PROFILE
    status.profile_available = true
    contract, contract_status := b.domain_contract_get()

    if contract_status == .Ok {
        ledger, ledger_status := b.host_ledger_get(contract.cookie)

        if ledger_status == .Ok {
            status.resources_available = true
            status.native_live_bytes = ledger.engine_live_bytes
            status.wrapper_live_bytes = ledger.snapshot_live_bytes
            status.host_live_bytes = ledger.host_live_bytes
            status.reserved_bytes = ledger.host_reserved_bytes
            status.tracked_peak_bytes = ledger.committed_peak_bytes
        }
    }

    p.status = status

    if self.hosting || s.client.has_world {
        scope := Visual_Scope {
            epoch = status.epoch,
        }
        source := bp.Source.Confirmed

        if !self.hosting {
            scope.serial = s.client.serial
            scope.view_reset = s.client.view_reset
            scope.corrections = s.client.stats.corrections
            source = s.client.spectator ? bp.Source.Observed : bp.Source.Predicted
        }

        if p.scope_ready && scope != p.scope {
            if p.revision == max(u64) {
                slice_fail(self, "presentation revision exhausted")
                return
            }

            p.revision += 1
        }

        p.scope = scope
        p.scope_ready = true

        if !scene.session_tick_phase(s, &p.phase, dt) {
            slice_fail(self, "presentation phase")
            return
        }

        checkpoint, error := rgd.session_checkpoint(s, status.head)

        if error != .None {
            slice_fail(self, "render checkpoint")
            return
        }

        fresh, view_error, read_error := rgd.physics_presentation_frame(
            &checkpoint,
            slice_bindings,
            p.revision,
            source,
        )
        // Only detached values remain after this single owned CP/bulk-cache read.
        destroy_error := r.complete_checkpoint_destroy(&checkpoint)

        if destroy_error != .None || read_error != .None || view_error != .None {
            slice_fail(self, "presentation cache")
            return
        }

        if p.have_current {
            same_scope := p.current.epoch == fresh.epoch && p.current.revision == fresh.revision

            if same_scope && fresh.tick == p.current.tick {
                // Re-read of one tick preserves the existing consecutive interpolation pair.
            } else if same_scope && p.current.tick != max(u64) && p.current.tick + 1 == fresh.tick {
                p.previous = p.current
                p.have_previous = true
            } else {
                p.have_previous = false
            }
        }

        p.current = fresh
        p.have_current = true
        p.captures += 1
        changes: [bp.MAX_CHANGES]bp.Change
        previous: ^bp.Frame

        if p.have_previous {
            previous = &p.previous
        }

        count, present_error := bp.present(&p.proxies, previous, &p.current, p.phase.fraction, changes[:])

        if present_error != .None || !slice_proxy_paint(self, changes[:count]) {
            slice_fail(self, "presentation proxies")
            return
        }
    }

    slice_presentation_overlay(self)
}

slice_presentation_overlay :: proc(self: ^ReplayBox3d) {
    p := &self.presentation
    buffer: [2048]u8
    count, error := bp.status_text(p.status, buffer[:])

    if error != .None {
        slice_fail(self, "presentation overlay")
        return
    }

    source := p.have_current ? p.current.source : bp.Source.Observed
    effect := p.last_effect
    payload := p.last_payload
    text := gd.new_string(
        fmt.tprintf(
            "REPLAY BOX3D / %s / %v view / app GO=%v\n%sVisual revision %d | alpha %.2f | proxies %d/33 | cuts %d | journal changes %d\nLast actual FX available=%v id=%d/%d/%d/%d phase=%v confirmed=%v entity=%d life=%d payload=%v/%d\nWASD move | Space spawn | Backspace remove | M motor | J sleep K wake | Q query | Esc exit\n%s",
            self.actor,
            source,
            self.go,
            string(buffer[:count]),
            p.revision,
            p.phase.fraction,
            p.current.count,
            p.proxies.cuts,
            self.fx,
            p.have_effect,
            effect.id.epoch,
            effect.id.tick,
            effect.id.source,
            effect.id.key,
            effect.kind,
            effect.confirmed,
            effect.game.entity,
            effect.game.lifetime,
            payload.kind,
            payload.serial,
            slice_impairment_text(self),
        ),
    )
    gd.label_set_text(self.status, text)
    gd.free_string(text)
}
