package replay_cavecrawl

import gd "godot:godot"
import rgd "godot:replay/godot"
import r "godot:replay"
import p "godot:replay/play"
import sc "godot:replay/schema"
import game "../shared/cave"

// Ordinary action entry points also used by the full campaign acceptance driver.
@(gd_method)
replay_cave_heal :: proc(self: ^ReplayCave) {
    replay_cave_issue(self, game.Action{verb = .Heal})
}

@(gd_method)
replay_cave_revive :: proc(self: ^ReplayCave, seat: gd.Int) {
    if seat < 1 || seat > game.SEATS {
        return
    }

    replay_cave_issue(self, game.Action{verb = .Revive, index = u16(seat - 1)})
}

@(gd_method)
replay_cave_carry :: proc(self: ^ReplayCave) {
    replay_cave_issue(self, game.Action{verb = .Carry})
}

@(gd_method)
replay_cave_set_down :: proc(self: ^ReplayCave) {
    replay_cave_issue(self, game.Action{verb = .Set_Down})
}

@(gd_method)
replay_cave_grab :: proc(self: ^ReplayCave, index, generation: gd.Int) {
    if index < 0 || index >= 48 || generation < 1 || u64(generation) > u64(max(u32)) {
        return
    }

    replay_cave_issue(self, game.Action{verb = .Grab, index = u16(index), generation = u32(generation)})
}

// Read-only authority observations. No driver hook changes simulation state.
@(gd_method)
replay_cave_campaign_probe :: proc(self: ^ReplayCave, key: string, wanted: gd.Int) -> gd.Int {
    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return -1
    }

    w := &frame.state

    switch key {
    case "fault_drops":
        return gd.Int(self.session.delay.dropped)
    case "fault_duplicates":
        return gd.Int(self.session.delay.duplicated)
    case "scatter":
        return gd.Int(self.scatter_checksum)
    case "depth":
        return gd.Int(w.depth)
    case "won":
        return gd.Int(w.won)
    case "mobs":
        return gd.Int(w.dwellers.count)
    case "rocks":
        return gd.Int(w.rocks.count)
    case "pickups":
        return gd.Int(w.pickups.count)
    case "wave":
        return gd.Int(w.director.wave)
    case "pending":
        return gd.Int(w.director.remaining)
    case "done":
        return gd.Int(w.director.done)
    case "dens":
        return gd.Int(w.dens_used)
    case "clock":
        return gd.Int(w.clock)
    case "carrier":
        return gd.Int(w.relic.carrier)
    case "relic_version":
        return gd.Int(w.relic.version)
    case "rejected":
        return gd.Int(self.rejected)
    case "gem_total":
        return gd.Int(game.world_items(w, game.GEM))
    case "torch_total":
        return gd.Int(game.world_items(w, game.TORCH))
    }

    player := &w.players[clamp(int(wanted) - 1, 0, game.SEATS - 1)]

    switch key {
    case "x":
        return gd.Int(player.position[0])
    case "y":
        return gd.Int(player.position[1])
    case "hp":
        return gd.Int(player.hp)
    case "stamina":
        return gd.Int(player.stamina)
    case "rock_cd":
        return gd.Int(player.rock_cd)
    case "heal_cd":
        return gd.Int(player.heal_cd)
    case "deaths":
        return gd.Int(player.deaths)
    case "slain":
        return gd.Int(player.slain)
    case "damage":
        return gd.Int(player.damage)
    case "respawn":
        return gd.Int(player.respawn_at)
    case "bag_gems":
        return gd.Int(p.inventory_count(player.bag[:], game.GEM))
    case "bag_torches":
        return gd.Int(p.inventory_count(player.bag[:], game.TORCH))
    }

    if wanted >= 0 && wanted < 16 {
        index := int(wanted)
        mob := w.dwellers.values[index]

        switch key {
        case "mob_alive":
            return gd.Int(w.dwellers.alive[index])
        case "mob_x":
            return gd.Int(mob.position[0])
        case "mob_y":
            return gd.Int(mob.position[1])
        case "mob_hp":
            return gd.Int(mob.hp)
        }
    }

    if wanted >= 0 && wanted < 48 {
        index := int(wanted)
        pickup := w.pickups.values[index]

        switch key {
        case "pickup_alive":
            return gd.Int(w.pickups.alive[index])
        case "pickup_x":
            return gd.Int(pickup.position[0])
        case "pickup_y":
            return gd.Int(pickup.position[1])
        case "pickup_item":
            return gd.Int(pickup.stack.item)
        case "pickup_count":
            return gd.Int(pickup.stack.count)
        case "pickup_generation":
            return gd.Int(w.pickups.generations[index])
        }
    }

    return -1
}

@(gd_method)
replay_cave_campaign_hash :: proc(self: ^ReplayCave, tick: gd.Int) -> gd.Int {
    if !self.session.ready || tick < 0 {
        return -1
    }

    frame: r.Frame(game.World)
    found := false

    if self.session.authority {
        frame, found = r.read(&self.session.server.timeline, u64(tick))
    } else {
        client := &self.session.client
        at := int(u64(tick) % u64(client.cfg.history))

        if client.observed_valid[at] && client.observed[at].tick == u64(tick) {
            frame, found = client.observed[at], true
        }
    }

    if !found {
        return -1
    }

    codec := self.session.authority ? &self.session.server.codecs.state : &self.session.client.codecs.state
    bytes := make([]u8, codec.wire_size, context.temp_allocator)

    if sc.encode(codec, frame.state, bytes).error != .None {
        return -1
    }

    return gd.Int(sc.digest(bytes) & 0x7fff_ffff_ffff_ffff)
}
