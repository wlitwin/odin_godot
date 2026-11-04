package replay_quickdraw_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import game "../../examples/replay_quickdraw/shared/duel"

@(test)
archive_resumes_projectiles_respawn_history_and_queued_purchase :: proc(t: ^testing.T) {
    w := joined()
    w.players[1].hp, w.players[1].respawn_at = 0, 60
    w.players[1].fire_cd = 7
    s, restored: net.Server(game.World, game.Controls, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&s)
    defer net.server_destroy(&restored)
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(game.World){state = w}, game.model(), {}, local_seat = 1),
        net.Error.None,
    )
    net.server_set_local_token(&s, net.Token{0 = 55})

    for tick in 1 ..= 20 {
        net.server_local(&s, game.Controls{drone = {1, 0}, buttons = tick == 1 ? game.LOB : 0})
        testing.expect_value(t, net.server_step(&s), net.Error.None)
    }

    net.server_issue(&s, game.Action{item = 1})
    cp, decoded: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&s, &cp), net.Error.None)
    testing.expect_value(t, cp.frame.state.bullets.count, u32(1))
    testing.expect_value(t, cp.frame.state.players[1].fire_cd, u16(7))
    bytes, err := net.checkpoint_encode(&cp, game.model())
    defer delete(bytes)
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, game.model(), 1), net.Error.None)
    testing.expect_value(
        t,
        net.server_restore(
            &restored,
            &decoded,
            game.model(),
            {},
            {epoch = 2, local_seat = 1, preserve_pending = true, retain_membership = true},
        ),
        net.Error.None,
    )

    for tick in 21 ..= 150 {
        control := game.Controls {
            move    = {1, 0},
            drone   = {-1, 0},
            buttons = tick % 60 == 0 ? game.LOB : 0,
        }
        net.server_local(&s, control)
        net.server_local(&restored, control)
        testing.expect_value(t, net.server_step(&s), net.Error.None)
        testing.expect_value(t, net.server_step(&restored), net.Error.None)
        a, _ := r.current(&s.timeline)
        b, _ := r.current(&restored.timeline)
        testing.expect(t, reflect.equal(a, b)) // every proxy, pool generation, timer and score
    }

    final, _ := r.current(&restored.timeline)
    testing.expect_value(t, final.state.buys, u32(1))
    testing.expect(t, final.state.players[0].boots && final.state.players[0].gold == 0)
    testing.expect_value(t, final.state.players[1].life, w.players[1].life + 1)
    testing.expect(t, final.state.lands > 0)
}

@(test)
waiting_names_and_pending_start_survive_checkpoint :: proc(t: ^testing.T) {
    w := game.initial(manual_start = true)
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 0,
        epoch  = 1,
        events = storage[:],
    }
    game.reset_player(&w, 1, &ctx)
    w.names[0].bytes[0] = 'M' // Valid alternate display name, not a default rebuilt at restore.
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    a, b: net.Server(game.World, game.Controls, game.Action, game.Event, game.SEATS)
    defer net.server_destroy(&a)
    defer net.server_destroy(&b)
    testing.expect_value(
        t,
        net.server_init(&a, r.Frame(game.World){state = w}, game.model(), {}, cfg = cfg, local_seat = 1),
        net.Error.None,
    )
    net.server_set_local_token(&a, net.Token{0 = 88})
    // Complete fresh-seat admission before declaring the profile. Reset-player
    // intentionally discards pre-admission seat data.
    testing.expect_value(t, net.server_step(&a), net.Error.None)
    _, named := net.server_issue(&a, game.Action{name = w.names[0]})
    testing.expect_value(t, named, net.Error.None)

    for _ in 0 ..< 8 {
        testing.expect_value(t, net.server_step(&a), net.Error.None)
    }

    named_frame, _ := r.current(&a.timeline)
    testing.expect_value(t, named_frame.state.names[0], w.names[0])
    _, submitted := net.server_issue(&a, game.Action{start = true})
    testing.expect_value(t, submitted, net.Error.None)
    cp, decoded: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&a, &cp), net.Error.None)
    testing.expect(t, !cp.frame.state.started)
    bytes, encoded := net.checkpoint_encode(&cp, game.model())
    defer delete(bytes)
    testing.expect_value(t, encoded, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, game.model(), game.CONTENT), net.Error.None)
    testing.expect_value(
        t,
        net.server_restore(
            &b,
            &decoded,
            game.model(),
            {},
            {epoch = 2, local_seat = 1, preserve_pending = true, retain_membership = true},
        ),
        net.Error.None,
    )

    for _ in 0 ..< 12 {
        testing.expect_value(t, net.server_step(&a), net.Error.None)
        testing.expect_value(t, net.server_step(&b), net.Error.None)
        fa, _ := r.current(&a.timeline)
        fb, _ := r.current(&b.timeline)
        testing.expect(t, reflect.equal(fa, fb))
    }

    final, _ := r.current(&b.timeline)
    testing.expect(t, final.state.started)
    testing.expect_value(t, final.state.names[0], w.names[0])
}
