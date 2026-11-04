package replay_cavecrawl

import gd "godot:godot"
import rgd "godot:replay/godot"
import r "godot:replay"
import scenegd "godot:replay/godot/scene"

@(gd_method)
replay_cave_rock_probe :: proc(self: ^ReplayCave, key: string, wanted: gd.Int = 0) -> gd.Float {
    frame, ok := rgd.session_state(self.session)

    if !ok {
        return -1
    }

    w := &frame.state

    switch key {
    case "tick":
        return gd.Float(frame.tick)
    case "count":
        return gd.Float(w.rocks.count)
    case "fraction":
        return gd.Float(self.rock_phase.fraction)
    case "epoch":
        return gd.Float(self.rock_phase.epoch)
    case "key":
        for _, i in w.rocks.values {
            if w.rocks.alive[i] {
                return gd.Float(u64(w.rocks.generations[i]) << 32 | u64(i + 1))
            }
        }

        return 0
    }

    identity := u64(wanted)
    index := int(u32(identity)) - 1

    if index < 0 ||
       index >= len(w.rocks.alive) ||
       !w.rocks.alive[index] ||
       u32(identity >> 32) != w.rocks.generations[index] {
        return -1
    }

    rock := w.rocks.values[index]

    switch key {
    case "x":
        return gd.Float(rock.position[0])
    case "y":
        return gd.Float(rock.position[1])
    case "vx":
        return gd.Float(rock.velocity[0])
    case "vy":
        return gd.Float(rock.velocity[1])
    case "left":
        return gd.Float(rock.left)
    }

    node, found := scenegd.nodes_get(&self.rocks, identity)

    if !found {
        return -1
    }

    position := gd.node2d_get_position(node)

    switch key {
    case "draw_x":
        return gd.Float(position[0])
    case "draw_y":
        return gd.Float(position[1])
    case "center_x", "center_y":
        glyph := cast(gd.Control)gd.get_node(node, "Glyph")
        center := gd.control_get_position(glyph) + gd.control_get_size(glyph) * .5
        return gd.Float(key == "center_x" ? center[0] : center[1])
    }

    return -1
}

@(gd_method)
replay_cave_rock_view :: proc(self: ^ReplayCave, key: gd.Int) -> gd.Node2d {
    node, _ := scenegd.nodes_get(&self.rocks, u64(key))
    return node
}

@(gd_method)
replay_cave_rock_preview_only :: proc(self: ^ReplayCave, fraction: gd.Float) -> bool {
    frame, ok := rgd.session_state(self.session)

    if !ok {
        return false
    }

    before := replay_cave_hash(frame)
    self.rock_phase.fraction = f32(fraction)
    replay_cave_paint(self)
    after, valid := rgd.session_state(self.session)
    return valid && replay_cave_hash(after) == before
}
