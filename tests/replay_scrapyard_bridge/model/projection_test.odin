package scrap_bridge_test
import "core:testing"
import "core:reflect"
import r "godot:replay"
import game "../../../examples/replay_scrapyard/shared/game"
import display "../../../examples/replay_scrapyard/shared/presentation"

@(test)
detached_mob_and_drop_views_preserve_values_and_entity_lifetimes :: proc(t: ^testing.T) {
    world := game.initial(encounter_count = 0)
    world.clock = 12
    world.players[0].connected, world.players[0].in_yard, world.players[0].hp = true, true, 10
    world.players[0].position = {95, 100}
    handle, ok := r.pool_insert(&world.mobs, game.Mob{kind = 1, hp = 7, position = {100, 100}})
    assert(ok)
    drop, _ := r.pool_insert(&world.drops, game.Drop{position = {20, 30}, amount = 5})
    before := world
    mobs := display.mobs(world, 2)
    drops := display.drops(world)
    testing.expect(t, reflect.equal(before, world))
    testing.expect(t, mobs.count == 1 && mobs.items[0].handle == handle && mobs.items[0].source == .Observed)
    value := mobs.items[0].view.value
    testing.expect(t, value.near && value.prey_left && value.hp == 7 && value.tick == 12 && value.epoch == 2)
    testing.expect(t, value.source == u64(handle.generation) << 32 | u64(handle.index + 1))
    testing.expect(
        t,
        drops.count == 1 && drops.items[0].handle == drop && drops.items[0].view.pose.position == ([2]f32{20, 30}),
    )
    world.catalog.mobs[1].scale = 9
    world.mobs.values[handle.index].hp = 1
    testing.expect(t, mobs.items[0].view.value.hp == 7 && mobs.items[0].view.value.scale != 9)
    assert(r.pool_remove(&world.mobs, handle))
    next, _ := r.pool_insert(&world.mobs, game.Mob{kind = 5, hp = 1})
    replacement := display.mobs(world, 2)
    testing.expect(t, replacement.items[0].handle == next && next != handle && replacement.items[0].view.value.prop)
    testing.expect(t, size_of(display.Mob_Batch) < size_of(game.World))
}
