package replay_scrapyard_test
import "core:testing"
import "core:reflect"
import game "../../examples/replay_scrapyard/shared/game"
import r "godot:replay"
import h "godot:replay/history"
import net "godot:replay/net"
import sc "godot:replay/schema"

@(test)
rewind_history_is_private_to_authority_snapshots_and_complete_in_archives :: proc(t: ^testing.T) {
    w := yard()
    w.clock = 1
    h.record(&w.hit_history, 1, game.proxies(&w))
    full, public: sc.Schema
    opts := sc.DEFAULT_OPTIONS
    opts.projection = .Public
    testing.expect_value(t, sc.init(&full, game.World).error, sc.Error.None)
    defer sc.destroy(&full)
    testing.expect_value(t, sc.init(&public, game.World, opts).error, sc.Error.None)
    defer sc.destroy(&public)
    testing.expect(t, public.wire_size < full.wire_size && public.excluded_fields > 0)
    a := make([]u8, full.wire_size)
    defer delete(a)
    b := make([]u8, public.wire_size)
    defer delete(b)
    testing.expect_value(t, sc.encode(&full, w, a).error, sc.Error.None)
    testing.expect_value(t, sc.encode(&public, w, b).error, sc.Error.None)
    restored, replica: game.World
    testing.expect_value(t, sc.decode(&full, &restored, a).error, sc.Error.None)
    testing.expect_value(t, sc.decode(&public, &replica, b).error, sc.Error.None)
    testing.expect(t, reflect.equal(restored, w) && game.state_valid(replica))
    expected := w
    expected.hit_history = {}
    testing.expect(t, reflect.equal(replica, expected))
    changed := w
    changed.hit_history.entries[1].value[0].position[0] += 1
    c := make([]u8, public.wire_size)
    defer delete(c)
    testing.expect_value(t, sc.encode(&public, changed, c).error, sc.Error.None)
    testing.expect_value(t, sc.digest(c), sc.digest(b))
    before := sc.digest(a)
    testing.expect_value(t, sc.encode(&full, changed, a).error, sc.Error.None)
    testing.expect(t, sc.digest(a) != before)
}

@(test)
private_rewind_history_preserves_authority_hits_and_client_beam_preview :: proc(t: ^testing.T) {
    w := yard()
    w.clock = 1
    w.players[0].position = {540, 1040}
    game.spawn_mob(&w, 0, {580, 1040})
    h.record(&w.hit_history, 1, game.proxies(&w))
    replica := w
    replica.hit_history = {}
    shot := game.Shot {
        seat       = 1,
        generation = 1,
        serial     = 1,
        position   = {540, 1040},
        velocity   = {100, 0},
        ttl        = 3,
        damage     = 1,
    }
    events: [128]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 2,
        epoch  = 1,
        events = events[:],
    }
    feedback: game.Notices
    game.rail_land(&replica, shot, false, net.View_Time{1, 1, 0, .Historical}, &feedback, &ctx)
    testing.expect_value(t, replica.mobs.values[0].hp, w.mobs.values[0].hp)
    testing.expect(t, replica.flashes.count > 0 && replica.players[0].rejected_queries == 1)
    feedback = {}
    ctx.count = 0
    game.rail_land(&w, shot, false, net.View_Time{1, 1, 0, .Historical}, &feedback, &ctx)
    testing.expect_value(t, w.mobs.values[0].hp, u16(2))
    testing.expect_value(t, w.players[0].historical_queries, u32(1))
}
