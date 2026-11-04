package scrapyard_scripts
import gd "godot:godot"
import ks "godot:kit/session"

@(gd_method)
scrapyard_dedicated_boot :: proc(self: ^Scrapyard, server: bool) {
    if server {
        scrapyard_on_host(self)
    } else {
        scrapyard_on_join(self)
    }
}

@(gd_method)
scrapyard_dedicated_profile :: proc(self: ^Scrapyard, look: gd.Int) {
    scrapyard_dev_loadout(self, look, 0)
}

@(gd_method)
scrapyard_dedicated_drive :: proc(self: ^Scrapyard, x, y: gd.Int, fire: bool) {
    scrapyard_dev_walk(self, x, y, 0.3)
    scrapyard_dev_autofire(self, fire ? 1.5 : 0)
}

@(gd_method)
scrapyard_dedicated_position :: proc(self: ^Scrapyard) -> gd.Vector2 {
    player, ok := runner_mine(&self.boot)
    return ok ? gd.Vector2{player.x, player.y} : gd.Vector2{}
}

@(gd_method)
scrapyard_dedicated_probe :: proc(self: ^Scrapyard, key: string) -> gd.Int {
    player, found := runner_mine(&self.boot)

    switch key {
    case "ready":
        return gd.Int(bool(scrapyard_is_seated(self)))
    case "authority":
        return gd.Int(self.ses.is_host)
    case "seat":
        return found ? gd.Int(self.ses.me) : 0
    case "avatars":
        return gd.Int(len(self.runners))
    case "hp":
        return found ? gd.Int(player.health.hp) : -1
    case "iron":
        return found ? gd.Int(player.gun) : -1
    case "cores":
        return found ? gd.Int(player.cores) : -1
    case "kills":
        return found ? gd.Int(my_stat(self, "kills")) : 0
    case "stage":
        return self.world != nil ? gd.Int(self.world.stage) + 1 : 0
    case "floor":
        return self.world != nil ? gd.Int(self.world.floor) : 0
    case "run":
        return self.world != nil ? gd.Int(self.world.run) : 0
    case "clock":
        return gd.Int(ks.session_tick_no(&self.ses))
    case "wave":
        return gd.Int(self.director.wave)
    case "spawned":
        return gd.Int(self.spawn_i)
    case "rest_until":
        return gd.Int(self.director.rest_until)
    case "living":
        return gd.Int(scrapyard_mobs_count(self))
    }

    return -1
}
