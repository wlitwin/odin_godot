package turret_corpus
import r "godot:replay"
import net "godot:replay/net"
import scenario "godot:replay/testing"
import game "../../../examples/replay_scrapyard/shared/game"

verify :: proc() -> (u64, bool) {
    w := game.initial(encounter_count = 0)
    w.stage = .Yard

    for &player, i in w.players[:2] {
        player.connected, player.in_yard = true, true
        player.position = {600, f32(1030 + i * 20)}
        player.profile.abilities = {7, 2}
    }

    w.catalog.abilities[7].turret.ammo = 5
    w.catalog.abilities[7].turret.cadence = 10
    h, ok := r.pool_insert(
        &w.turrets,
        game.Turret{position = {630, 1040}, aim = {1, 0}, ability = 7, ammo = 5, deployed_by = {2, 1}},
    )

    if !ok || !game.turret_mount(&w, 1, h) {
        return 0, false
    }

    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    model := game.model()
    model.reset_player = nil

    drive := proc(
        s: ^net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS),
        tick: u64,
    ) -> net.Error {
        return net.server_local(s, game.Control{aim = {1, 0}, fire = tick <= 41})
    }

    result := scenario.takeover(r.Frame(game.World){state = w}, model, cfg, 5, 60, drive)
    return result.report.hash,
        result.report.phase == .Complete &&
        result.before.state.turrets.values[0].operator.seat == 1 &&
        result.before.state.turrets.values[0].ammo == 4 &&
        result.after.state.turrets.count == 0 &&
        result.after.state.players[0].shots == 5
}
