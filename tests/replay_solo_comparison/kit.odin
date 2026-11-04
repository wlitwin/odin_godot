package scrapyard_scripts
import gd "godot:godot"
import ks "godot:kit/session"
solo_blasts: int

@(gd_method)
scrapyard_solo_input :: proc(self: ^Scrapyard, x, y: gd.Int, fire: bool) {
    scrapyard_dev_walk(self, x, y, 0.3)
    scrapyard_dev_autofire(self, fire ? 1.5 : 0)
}

@(gd_method)
scrapyard_solo_probe :: proc(self: ^Scrapyard, key: string) -> gd.Int {
    if key == "ready" {
        return gd.Int(self.started && self.world != nil && self.built_key != 0)
    }

    if self.world == nil {
        return -1
    }

    switch key {
    case "tick":
        return gd.Int(ks.session_tick_no(&self.ses))
    case "stage":
        return gd.Int(self.world.stage) + 1
    case "run":
        return gd.Int(self.world.run)
    case "floor":
        return gd.Int(self.world.floor)
    case "wave":
        return gd.Int(self.director.wave)
    case "pending":
        return gd.Int(self.director.pending)
    case "alive":
        return gd.Int(self.director.alive)
    case "done":
        return gd.Int(self.director.done)
    case "rest_until":
        return gd.Int(self.director.rest_until)
    case "spawned":
        return gd.Int(self.spawn_i)
    case "living":
        return gd.Int(scrapyard_mobs_count(self))
    case "props":
        return gd.Int(scrapyard_props_count(self))
    case "projectiles":
        return gd.Int(len(self.flying))
    case "shots":
        return gd.Int(self.shots)
    case "booms":
        return gd.Int(solo_blasts)
    case "kills":
        return gd.Int(my_stat(self, "kills"))
    }

    runner, found := runner_mine(&self.boot)

    if !found {
        return -1
    }

    switch key {
    case "hp":
        return gd.Int(runner.health.hp)
    case "x":
        return gd.Int(runner.x)
    case "y":
        return gd.Int(runner.y)
    case "cores":
        return gd.Int(runner.cores)
    case "scrap":
        return gd.Int(my_stat(self, "scrap"))
    case "mag":
        return gd.Int(runner.weapon.def.mag)
    case "jam":
        return gd.Int(runner.weapon.def.jam_per_mille)
    case "iron":
        return gd.Int(runner.gun)
    }

    return -1
}

@(gd_method)
scrapyard_solo_position :: proc(self: ^Scrapyard) -> gd.Vector2 {
    runner, found := runner_mine(&self.boot)
    return found ? gd.Vector2{runner.x, runner.y} : gd.Vector2{}
}

@(gd_method)
scrapyard_solo_cover_count :: proc(self: ^Scrapyard) -> gd.Int {
    return gd.Int(len(self.covers))
}

@(gd_method)
scrapyard_solo_cover :: proc(self: ^Scrapyard, index: gd.Int) -> gd.Rect2 {
    if index < 0 || int(index) >= len(self.covers) {
        return {}
    }

    c := self.covers[index]
    return {{f32(c.x), f32(c.y)}, {f32(c.w), f32(c.h)}}
}

@(gd_method)
scrapyard_solo_prop :: proc(self: ^Scrapyard, index: gd.Int) -> gd.Vector3 {
    props: [2]gd.Vector3
    count := 0

    for _, m in self.mobs {
        if m.health.hp > 0 && mob_stats(m.kind).prop && count < 2 {
            props[count] = {m.x, m.y, f32(m.health.hp)}
            count += 1
        }
    }

    if count == 2 && (props[0].x > props[1].x || props[0].x == props[1].x && props[0].y > props[1].y) {
        props[0], props[1] = props[1], props[0]
    }

    return index >= 0 && int(index) < count ? props[index] : gd.Vector3{}
}
