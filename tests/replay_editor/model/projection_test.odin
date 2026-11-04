package editor_projection_test
import "core:testing"
import "core:reflect"
import game "../../../examples/replay_scrapyard/shared/game"
import display "../../../examples/replay_scrapyard/shared/presentation"

@(test)
runner_display_and_hud_derive_owned_values_without_changing_world :: proc(t: ^testing.T) {
    world := game.initial()
    world.clock = 80
    player := world.players[0]
    player.in_yard, player.connected = true, true
    player.hp = 5
    player.generation, player.warp = 2, 3
    player.gun.ammo, player.gun.mode = 2, .Jammed
    player.profile.name = game.name("Editor")
    world.players[0] = player
    before := world
    view := display.runner(world, player, {20, 30}, 4, 1)
    hud := display.hud(world, player, 80, 1, true)
    testing.expect(t, reflect.equal(before, world))
    testing.expect(
        t,
        view.position == ([2]f32{20, 30}) && view.epoch == 4 && view.generation == 2 && view.warp == 3 && view.alive,
    )
    testing.expect(
        t,
        hud.personal &&
        hud.hp == 5 &&
        hud.maximum == game.max_health(player.parts) &&
        hud.mode == .Jammed &&
        hud.ammo == 2,
    )
    world.catalog.guns[player.gun_id].mechanism.mag = 99
    testing.expect(t, hud.mag != 99)
    player.hp = 0
    down := display.runner(world, player, {20, 30}, 4, 1)
    testing.expect(t, !down.alive && !down.weapon.visible && !down.reloading && down.tint[3] == .45)
    testing.expect(
        t,
        size_of(display.Runner_View) < size_of(game.World) && size_of(display.Hud_View) < size_of(game.World),
    )
}

@(test)
wound_uses_selected_public_tick_and_refuses_another_lifetime :: proc(t: ^testing.T) {
    player := game.Player {
        generation = 3,
        position   = {10, 20},
    }
    event := game.Event {
        kind       = .Hurt,
        generation = 3,
        position   = {30, 20},
    }
    value, ok := display.wound(player, event)
    testing.expect(t, ok && value.directional && value.victim == ([2]f32{10, 20}) && value.marker == ([2]f32{40, 20}))
    player.generation = 4
    _, ok = display.wound(player, event)
    testing.expect(t, !ok)
}
