package replay_slice_unit_test

import "core:fmt"
import "core:testing"
import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import adapter "godot:examples/replay_box3d/shared/adapter"
import common "godot:examples/box3d_common"

Query_State :: struct {
    game: common.Game,
    hits: [2]u32,
}

query_tick :: proc(state: ^Query_State, _: u8, ctx: ^r.Step(u32)) {
    execution := ctx.execution

    if ph.step(execution) != .None {
        return
    }

    ops := adapter.operations(&execution)

    for seat in 0 ..< 2 {
        count, ok := ops.query(ops.user, state.game.bodies[seat])

        if !ok {
            r.abort(ctx)
            return
        }

        state.hits[seat] = count
    }
}

@(test)
production_query_matches_native_oracle_and_distinguishes_old_long_ray :: proc(t: ^testing.T) {
    initials := [?]u32{4, 32}
    heights := [?]f32{0, 4}

    for initial in initials {
        for height in heights {
            world, game, status := common.world(initial, 1)
            testing.expect_value(t, status, b.Status.Ok)

            // Native fixture setup only: an elevated player distinguishes the two
            // finite ray segments; production world/rules are unchanged.
            if height != 0 {
                for key in game.bodies[:2] {
                    body, body_status := b.body_resolve(world, key)
                    testing.expect_value(t, body_status, b.Status.Ok)
                    pose, pose_status := b.body_get_pose(body)
                    testing.expect_value(t, pose_status, b.Status.Ok)
                    pose.position.y = height
                    testing.expect_value(t, b.body_set_pose(body, pose), b.Status.Ok)
                }
            }

            catalog_config := b.recovery_config_default()
            catalog_config.profile = common.PROFILE
            assets := common.assets()
            catalog, catalog_status := b.recovery_catalog_create(catalog_config, assets[:])
            testing.expect_value(t, catalog_status, b.Status.Ok)

            if height == 0 {
                codec: adapter.Codec
                raw_rules := adapter.rules(initial, 1)
                testing.expect(
                    t,
                    ph.network_codec_init(&codec, &catalog, adapter.config(&catalog, initial), raw_rules) == .None,
                )
                fmt.printf(
                    "REPLAY_QUERY_RULES initial=%d seed=1 adapter=%v bound=%v\n",
                    initial,
                    raw_rules,
                    codec.value.game_rules,
                )
                testing.expect(t, ph.network_codec_destroy(&codec) == .None)
            }

            checkpoint, error := ph.checkpoint_make(
                r.Frame(Query_State){state = {game = game}},
                u32,
                world,
                adapter.config(&catalog, initial),
            )
            testing.expect_value(t, error, r.Error.None)
            timeline: r.Timeline(Query_State, u8, u32)
            testing.expect_value(t, r.init_complete(&timeline, &checkpoint, query_tick, {128, 0}), r.Error.None)
            r.complete_checkpoint_destroy(&checkpoint)
            b.recovery_catalog_destroy(&catalog)
            testing.expect_value(t, b.world_step(world, 1.0 / 60.0, 4), b.Status.Ok)
            expected, old: [2]u32

            for seat in 0 ..< 2 {
                body, resolve_status := b.body_resolve(world, game.bodies[seat])
                testing.expect_value(t, resolve_status, b.Status.Ok)
                pose, pose_status := b.body_get_pose(body)
                testing.expect_value(t, pose_status, b.Status.Ok)
                hits: [35]b.Ray_Hit
                origin := pose.position
                origin.y += 0.5
                count, query_status := b.query_ray(world, origin, {0, -2, 0}, b.QUERY_FILTER_ALL, hits[:])
                testing.expect_value(t, query_status, b.Status.Ok)
                expected[seat] = count
                old_origin := pose.position
                old_origin.y += 2
                old_count, old_status := b.query_ray(world, old_origin, {0, -5, 0}, b.QUERY_FILTER_ALL, hits[:])
                testing.expect_value(t, old_status, b.Status.Ok)
                old[seat] = old_count
            }

            testing.expect_value(t, r.advance(&timeline, u8(0)).error, r.Error.None)
            actual, found := r.current_values(&timeline)
            testing.expect(t, found)
            testing.expect_value(t, actual.state.hits, expected)

            if height != 0 {
                testing.expect(t, expected != old, "elevated fixture must distinguish the old +2/-5 ray")
            }

            fmt.printf(
                "REPLAY_QUERY_PARITY initial=%d player_y=%g expected=%v actual=%v old_ray=%v filter=ALL capacity=35\n",
                initial,
                height,
                expected,
                actual.state.hits,
                old,
            )
            r.destroy(&timeline)
            b.world_destroy(&world)
        }
    }

    engine, _ := b.engine_allocation_stats()
    wrapper, _ := b.snapshot_allocation_stats()
    testing.expect_value(t, engine.live_bytes, u64(0))
    testing.expect_value(t, wrapper.live_bytes, u64(0))
    testing.expect_value(t, ph.allocation_stats().live_bytes, u64(0))
}
