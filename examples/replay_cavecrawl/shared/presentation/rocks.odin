package cave_presentation

import v "godot:replay/view"
import p "godot:replay/play"

// Reads either the base world or the owner profile's embedded world. Clip only
// the visual preview against currently visible bodies; never apply a hit here.
rock_position :: proc(w: ^$World, index: int, fraction, body_radius: f32) -> [2]f32 {
    if index < 0 || index >= len(w.rocks.alive) || !w.rocks.alive[index] {
        return {}
    }

    rock := w.rocks.values[index]
    stop := f32(1)
    to := rock.position + rock.velocity

    for player, i in w.players {
        if !player.connected || player.hp <= 0 || i + 1 == int(rock.shooter) {
            continue
        }

        if at, hit := p.segment_circle(rock.position, to, player.position, body_radius); hit {
            stop = min(stop, at)
        }
    }

    for dweller, i in w.dwellers.values {
        if w.dwellers.alive[i] {
            if at, hit := p.segment_circle(rock.position, to, dweller.position, body_radius); hit {
                stop = min(stop, at)
            }
        }
    }

    position, ok := v.linear_preview2(rock.position, rock.velocity, fraction, stop)
    return ok ? position : rock.position
}
