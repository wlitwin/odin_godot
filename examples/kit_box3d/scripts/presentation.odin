package kit_box3d

import "core:fmt"
import "core:math"
import gd "godot:godot"
import b "godot:box3d"
import bp "godot:box3d/presentation"
import p "godot:kit/physics"
import k "godot:kit/sim"
import common "godot:examples/box3d_common"

Consumer_View :: struct {
    pool:                              bp.View,
    previous, current:                 bp.Frame,
    tokens:                            [common.MAX_DYNAMIC]bp.Token,
    current_valid, previous_valid:     bool,
    generation:                        u32,
    revision, epoch, client_confirmed: u64,
    resim_ticks:                       int,
    error:                             bp.Error,
    capture_error:                     k.World_Error,
}

consumer_settled_effect :: proc(rt: ^Runtime, stamp: Stamped_Event, key: u64) {
    if stamp.value.serial == 0 || stamp.value.lifetime == 0 {
        return
    }

    entity := stamp.value.lifetime

    if entity > u64(rt.initial) {
        entity = u64(rt.initial) + 1
    }

    observation, ok := p.presentation_effect(stamp.epoch, stamp.tick, 1, key, {entity, stamp.value.lifetime})

    if ok {
        rt.presentation_effect_count += 1
        rt.presentation_effect = observation
    }
}

consumer_frame :: proc(rt: ^Runtime, cp: ^k.World_Checkpoint, epoch, revision: u64) -> (bp.Frame, bp.Error) {
    side, se := p.checkpoint_side(cp, Side)

    if se != .Ok {
        return {}, .Invalid
    }

    states: [bp.MAX_BODIES]b.Body_State
    count, ce := p.checkpoint_body_states(cp, states[:], Side)

    if ce != .Ok {
        return {}, .Invalid
    }

    telemetry_frame(rt, cp, states[:count]) // exact same public cache, never derived rows
    bindings: [bp.MAX_BODIES]bp.Binding
    n := 0

    for alive, i in side.game.alive {
        if !alive {
            continue
        }

        asset := common.CRATE_ASSET

        if i < 2 {
            asset = common.PLAYER_ASSET
        }

        if i == int(side.game.initial) {
            asset = common.SPAWN_ASSET
        }

        bindings[n] = {
            id    = {u64(i + 1), side.game.lifetimes[i]},
            body  = bp.Body_Key(side.game.bodies[i]),
            asset = asset,
            seat  = i < 2 ? u16(i + 1) : 0,
            alive = true,
        }
        n += 1
    }

    samples: [bp.MAX_BODIES]bp.Body_Sample

    for state, i in states[:count] {
        samples[i] = {
            body  = bp.Body_Key(state.key),
            pose  = {
                {state.pose.position.x, state.pose.position.y, state.pose.position.z},
                {state.pose.rotation.x, state.pose.rotation.y, state.pose.rotation.z, state.pose.rotation.w},
            },
            awake = state.is_awake != 0,
        }
    }

    source: bp.Source = .Predicted

    if rt.ses.is_host {
        source = .Confirmed
    } else if rt.seat == 0 {
        source = .Observed
    }

    return bp.frame_make(epoch, cp.tick, revision, source, bindings[:n], samples[:count])
}

consumer_paint :: proc(self: ^KitSlice, rt: ^Runtime) {
    view := &self.presentation
    epoch := k.lane_world_epoch(&rt.lane)
    network := k.lane_world_network_status(&rt.lane)
    work := k.lane_world_work_stats(&rt.lane)

    if network.ready {
        // This epoch belongs to this one owned capture; copied Frames retain it.
        cp, ce := k.lane_world_checkpoint(&rt.lane, rt.lane.ticker.tick)
        view.capture_error = ce

        if ce == .Ok {
            confirmed := rt.ses.is_host ? u64(0) : k.lane_world_confirmed(&rt.lane)
            resims := k.lane_net_stats(&rt.lane).resim_ticks
            cut :=
                view.current_valid &&
                (view.generation != rt.generation ||
                        view.epoch != epoch ||
                        view.client_confirmed != confirmed ||
                        view.resim_ticks != resims ||
                        cp.tick < view.current.tick)

            if cut && view.revision == max(u64) {
                view.error = .Generation_Exhausted
            } else {
                revision := view.revision

                if cut {
                    revision += 1
                }

                frame, error := consumer_frame(rt, &cp, epoch, revision)

                if error == .None {
                    if !view.current_valid || cut || view.current.tick + 1 != frame.tick {
                        if !view.current_valid || view.current.tick != frame.tick || cut {
                            view.previous_valid = false
                        }
                    }

                    if view.current_valid && !cut && view.current.tick + 1 == frame.tick {
                        view.previous = view.current
                        view.previous_valid = true
                    }

                    view.current = frame
                    view.current_valid = true
                    view.revision = revision
                    view.generation = rt.generation
                    view.epoch = epoch
                    view.client_confirmed = confirmed
                    view.resim_ticks = resims
                }

                view.error = error
            }

            _ = k.world_checkpoint_destroy(&cp)
        }

        dt := rt.lane.ticker.dt
        acc := rt.lane.ticker.acc

        if view.current_valid &&
           view.error == .None &&
           dt > 0 &&
           !math.is_nan(dt) &&
           !math.is_inf(dt) &&
           !math.is_nan(acc) &&
           !math.is_inf(acc) {
            changes: [bp.MAX_CHANGES]bp.Change
            previous: ^bp.Frame

            if view.previous_valid {
                previous = &view.previous
            }

            needed, error := bp.present(&view.pool, previous, &view.current, f32(clamp(acc / dt, 0, 1)), changes[:])
            view.error = error

            if error == .None {
                for change in changes[:needed] {
                    index := int(change.token.slot)

                    if index >= len(self.meshes) {
                        view.error = .Capacity
                        break
                    }

                    if change.kind == .Remove {
                        if view.tokens[index] == change.token {
                            gd.node3d_set_visible(self.meshes[index], false)
                            view.tokens[index] = {}
                        }

                        continue
                    }

                    if change.kind == .Update && view.tokens[index] != change.token {
                        view.error = .Stale
                        break
                    }

                    view.tokens[index] = change.token
                    row := change.row
                    gd.node3d_set_visible(self.meshes[index], true)
                    gd.node3d_set_visible(self.spheres[index], row.asset == common.PLAYER_ASSET)
                    gd.node3d_set_visible(self.crates[index], row.asset == common.CRATE_ASSET)
                    gd.node3d_set_visible(self.capsules[index], row.asset == common.SPAWN_ASSET)
                    gd.node3d_set_position(
                        self.meshes[index],
                        {row.pose.position[0], row.pose.position[1], row.pose.position[2]},
                    )
                    gd.node3d_set_quaternion(
                        self.meshes[index],
                        quaternion(
                            x = row.pose.rotation[0],
                            y = row.pose.rotation[1],
                            z = row.pose.rotation[2],
                            w = row.pose.rotation[3],
                        ),
                    )
                }
            }
        }
    }

    status := p.presentation_status(epoch, rt.lane.ticker.tick, k.lane_world_confirmed(&rt.lane), network, work)
    world_error := k.lane_world_status(&rt.lane)

    if world_error != .Ok {
        status.error_code = i32(world_error)
    }

    // Presentation-only failure label: retain copied poses, never change Lane
    // readiness, resync, clocks, or admission in order to paint the HUD.
    if view.capture_error != .Ok {
        status.ready = false
        status.hold = true
        status.error_code = i32(view.capture_error)
    }

    status.profile = rt.network.identity.profile
    status.profile_available = status.profile != 0
    status.latest_timing_available = work.normal_latest_ns != 0 || work.correction_latest_ns != 0
    status.timing_available =
        status.latest_timing_available || work.normal_peak_ns != 0 || work.correction_peak_ns != 0
    contract, ds := b.domain_contract_get()

    if ds == .Ok {
        ledger, ls := b.host_ledger_get(contract.cookie)

        if ls == .Ok {
            status.resources_available = true
            status.native_live_bytes = ledger.engine_live_bytes
            status.wrapper_live_bytes = ledger.snapshot_live_bytes
            status.host_live_bytes = ledger.host_live_bytes
            status.reserved_bytes = ledger.host_reserved_bytes
            status.tracked_peak_bytes = ledger.committed_peak_bytes
        }
    }

    text: [2049]u8
    size, error := bp.status_text(status, text[:2048])

    if error == .None {
        text[size] = 0
        gd.set_text(
            self.label,
            fmt.ctprintf(
                "%sKIT %s / seat %d / visual rows %d / cuts %d / settled FX %d / view %v / capture %v\n%s",
                cast(cstring)&text[0],
                role_name(rt.role),
                rt.seat,
                view.current.count,
                view.pool.cuts,
                rt.presentation_effect_count,
                view.error,
                view.capture_error,
                scene_impairment_text(rt.impairment),
            ),
        )
    }
}
