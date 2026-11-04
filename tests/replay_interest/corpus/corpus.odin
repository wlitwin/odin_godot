package interest_corpus
import r "godot:replay"
import sc "godot:replay/schema"
import net "godot:replay/net"
import game "../godot/shared/arena"

Result :: struct {
    ok:                bool,
    fingerprint, hash: u64,
    frames:            u32,
}

run :: proc() -> Result {
    codec: sc.Schema
    defer sc.destroy(&codec)
    options := sc.DEFAULT_OPTIONS
    options.projection = .Public

    if sc.init(&codec, net.Replica(game.World, game.Control, game.SEATS), options).error != .None {
        return {}
    }

    bytes := make([]u8, codec.wire_size)
    defer delete(bytes)
    w := game.initial()
    m := game.model()
    events: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = events[:],
    }
    result := Result {
        ok          = true,
        fingerprint = codec.fingerprint,
        hash        = 1,
    }

    for tick in u64(1) ..= 240 {
        controls := [game.SEATS]game.Control {
            0 = {move = tick < 120 ? 1 : -1, private_hint = u32(tick) + 0xa0b0c0},
        }
        ctx.tick, ctx.count = tick, 0
        game.step(&w, controls, tick == 1 ? 3 : 0, 0, &ctx)

        for who in ([3]net.Recipient{{1, false}, {2, false}, {0, true}}) {
            value, ok := m.replication.project({tick, w}, controls, who)

            if !ok {
                return {}
            }

            if sc.encode(&codec, value, bytes).error != .None {
                return {}
            }

            decoded: net.Replica(game.World, game.Control, game.SEATS)

            if sc.decode(&codec, &decoded, bytes).error != .None || !m.replication.valid(decoded, who) {
                return {}
            }

            result.hash = sc.digest(bytes, result.hash)
            result.frames += 1
        }
    }

    return result
}
