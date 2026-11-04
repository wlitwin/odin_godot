package replay_view_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import v "godot:replay/view"

Projected_Actor :: struct {
    x:      f32,
    hp:     i32,
    owner:  u16,
    cut:    u64,
    hidden: bool,
}

project_actor :: proc(actor: Projected_Actor) -> (v.Entity_View(i32), bool) {
    return {
            pose = {position = {actor.x, 0}},
            scale = {1, 1},
            color = {1, 1, 1, 1},
            value = actor.hp,
            owner = actor.owner,
            cut = actor.cut,
        },
        !actor.hidden
}

@(test)
projection_copies_only_detached_values_and_rejects_bad_candidates_atomically :: proc(t: ^testing.T) {
    pool: r.Pool(Projected_Actor, 4)
    handle, _ := r.pool_insert(&pool, Projected_Actor{x = 5, hp = 7, owner = 1})
    before := pool
    projection: v.Projection(Projected_Actor, i32)
    assert(v.projection_init(&projection, 1))
    defer v.projection_destroy(&projection)
    testing.expect_value(
        t,
        v.project_pool(&projection, pool, {1, 0}, 12, .Predicted, project_actor),
        v.Projection_Error.None,
    )
    testing.expect(
        t,
        reflect.equal(pool, before) && projection.items[0].view.value == 7 && projection.items[0].handle == handle,
    )
    projection.items[0].view.value = 99
    testing.expect(t, pool.values[0].hp == 7)
    saved := projection.items[0]
    _, _ = r.pool_insert(&pool, Projected_Actor{x = 6, hp = 8})
    testing.expect_value(
        t,
        v.project_pool(&projection, pool, {1, 0}, 13, .Predicted, project_actor),
        v.Projection_Error.Capacity,
    )
    testing.expect(t, projection.count == 1 && projection.tick == 12 && projection.items[0] == saved)
    pool.values[1].hidden = true
    testing.expect_value(
        t,
        v.project_pool(&projection, pool, {1, 0}, 13, .Predicted, project_actor),
        v.Projection_Error.None,
    )
    pool.count = 0
    testing.expect_value(
        t,
        v.project_pool(&projection, pool, {1, 0}, 14, .Predicted, project_actor),
        v.Projection_Error.Invalid,
    )
    testing.expect_value(t, projection.tick, u64(13))
    bad: v.Projection(Projected_Actor, string)
    testing.expect(t, !v.projection_init(&bad, 2))
    v.projection_destroy(&bad)
}

@(test)
projection_blending_keeps_discrete_state_and_respects_lifetime_and_teleport_cuts :: proc(t: ^testing.T) {
    pool: r.Pool(Projected_Actor, 4)
    handle, _ := r.pool_insert(&pool, Projected_Actor{x = 0, hp = 7})
    a, b, out: v.Projection(Projected_Actor, i32)
    assert(v.projection_init(&a, 4))
    assert(v.projection_init(&b, 4))
    assert(v.projection_init(&out, 4))
    defer v.projection_destroy(&a)
    defer v.projection_destroy(&b)
    defer v.projection_destroy(&out)
    assert(v.project_pool(&a, pool, {1, 0}, 10, .Observed, project_actor) == .None)
    pool.values[0].x = 10
    pool.values[0].hp = 3
    assert(v.project_pool(&b, pool, {1, 0}, 11, .Observed, project_actor) == .None)
    testing.expect_value(t, v.projection_blend(&out, &a, &b, .5), v.Projection_Error.None)
    testing.expect(t, out.items[0].view.pose.position[0] == 5 && out.items[0].view.value == 7)
    pool.values[0].cut = 1
    assert(v.project_pool(&b, pool, {1, 0}, 11, .Observed, project_actor) == .None)
    assert(v.projection_blend(&out, &a, &b, .5) == .None)
    testing.expect_value(t, out.items[0].view.pose.position[0], f32(10))
    assert(r.pool_remove(&pool, handle))
    replacement, _ := r.pool_insert(&pool, Projected_Actor{x = 99, hp = 2})
    assert(v.project_pool(&b, pool, {1, 0}, 11, .Observed, project_actor) == .None)
    assert(v.projection_blend(&out, &a, &b, .5) == .None)
    testing.expect(t, out.items[0].handle == handle && out.items[0].view.pose.position[0] == 0)
    assert(v.projection_blend(&out, &a, &b, 1) == .None)
    testing.expect(t, out.items[0].handle == replacement && out.items[0].view.pose.position[0] == 99)
    b.scope = {2, 0}
    assert(v.projection_blend(&out, &a, &b, 0) == .None)
    testing.expect_value(t, out.scope.epoch, u64(2))
}

@(test)
projection_policy_keeps_explicit_source_time_and_refuses_mixed_lifetime_conflicts :: proc(t: ^testing.T) {
    pool: r.Pool(Projected_Actor, 4)
    _, _ = r.pool_insert(&pool, Projected_Actor{x = 10, hp = 7, owner = 1})
    _, _ = r.pool_insert(&pool, Projected_Actor{x = 20, hp = 8, owner = 2})
    predicted, observed, out: v.Projection(Projected_Actor, i32)
    assert(v.projection_init(&predicted, 4))
    assert(v.projection_init(&observed, 4))
    assert(v.projection_init(&out, 4))
    defer v.projection_destroy(&predicted)
    defer v.projection_destroy(&observed)
    defer v.projection_destroy(&out)
    assert(v.project_pool(&predicted, pool, {1, 0}, 20, .Predicted, project_actor) == .None)
    pool.values[0].x = 1
    pool.values[1].x = 2
    assert(v.project_pool(&observed, pool, {1, 0}, 15, .Observed, project_actor) == .None)
    testing.expect_value(
        t,
        v.projection_select(&out, &predicted, &observed, nil, .Local_Predicted_Remote_Observed, 1),
        v.Projection_Error.None,
    )
    testing.expect(
        t,
        out.source == .Mixed &&
        out.items[0].view.pose.position[0] == 10 &&
        out.items[0].source == .Predicted &&
        out.items[0].tick == 20,
    )
    testing.expect(
        t,
        out.items[1].view.pose.position[0] == 2 && out.items[1].source == .Observed && out.items[1].tick == 15,
    )
    before := [2]v.View_Item(Projected_Actor, i32){out.items[0], out.items[1]}
    testing.expect_value(
        t,
        v.projection_select(&out, &predicted, &observed, nil, .Authoritative),
        v.Projection_Error.Invalid,
    )
    observed.items[0].view.owner = 2
    observed.items[0].handle.generation += 1
    testing.expect_value(
        t,
        v.projection_select(&out, &predicted, &observed, nil, .Local_Predicted_Remote_Observed, 1),
        v.Projection_Error.Duplicate,
    )
    testing.expect(t, out.items[0] == before[0] && out.items[1] == before[1])
}
