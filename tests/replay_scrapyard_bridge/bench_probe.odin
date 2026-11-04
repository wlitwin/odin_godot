package replay_scrapyard
import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import rgd "godot:replay/godot"
import game "../shared/game"

// Test-only render workload: populate a detached frame, never the live timeline.
// Both versions receive the same catalog, entities and render deltas.
@(gd_method)
replay_scrapyard_bridge_benchmark :: proc(self: ^ReplayScrapyard, wanted: gd.Int) -> bool {
    if wanted < 0 || wanted > game.MAX_MOBS {
        return false
    }

    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return false
    }

    original := frame
    frame.state.mobs = {}
    frame.state.drops = {}
    frame.state.shots = {}
    frame.state.flashes = {}
    frame.state.lobs = {}
    frame.state.zones = {}
    frame.state.clock = 1000
    frame.tick = 1000

    for i in 0 ..< int(wanted) {
        position := [2]f32{f32(220 + i % 8 * 40), f32(180 + i / 8 * 40)}
        _, alive := r.pool_insert(
            &frame.state.mobs,
            game.Mob{kind = u8(i % 5), hp = 20, max_hp = 20, position = position},
        )
        assert(alive)
        _, dropped := r.pool_insert(&frame.state.drops, game.Drop{position = position + [2]f32{8, 8}, amount = 3})
        assert(dropped)
    }

    for batch in 0 ..< 6 {
        began := gd.time_get_ticks_usec(gd.singleton_time())

        for _ in 0 ..< 120 {
            paint(self, frame, frame, 1.0 / 60)
        }

        elapsed := gd.time_get_ticks_usec(gd.singleton_time()) - began

        if batch > 0 {
            gd.print_str(fmt.tprintf("SCRAP_BRIDGE_RENDER count=%d batch=%d frames=120 us=%d", wanted, batch, elapsed))
        }
    }

    // Presentation must leave the authoritative simulation untouched.
    current, _ := rgd.session_authority_state(self.session)
    same := game.state_valid(current.state) && reflect.equal(current, original)
    gd.print_str(
        fmt.tprintf("SCRAP_BRIDGE_RENDER_OK count=%d unchanged=%t world_bytes=%d", wanted, same, size_of(game.World)),
    )
    return same
}
