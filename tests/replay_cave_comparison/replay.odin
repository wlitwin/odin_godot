package replay_cavecrawl
import gd "godot:godot"
import rgd "godot:replay/godot"
import game "../shared/cave"
import p "godot:replay/play"
import scenegd "godot:replay/godot/scene"

bench_active: bool
bench_times: [4096]u64
bench_count, bench_dropped: int
bench_tx_start, bench_tx_stop: u64
bench_accepted_start: u32

bench_bytes :: proc(self: ^ReplayCave) -> u64 {
    if self.session.link.ready {
        return self.session.link.router.stats.tx_bytes
    }

    return self.session.authority ? self.session.server.stats.tx_bytes : self.session.client.stats.tx_bytes
}

bench_note :: proc(start: u64) {
    if bench_count == len(bench_times) {
        bench_dropped += 1
        return
    }

    bench_times[bench_count] = gd.time_get_ticks_usec(gd.singleton_time()) - start
    bench_count += 1
}

@(gd_method)
replay_cave_bench_boot :: proc(self: ^ReplayCave, host: bool) {}     // explicit role launch

@(gd_method)
replay_cave_bench_start_game :: proc(self: ^ReplayCave) {}     // explicit role uses playing state

@(gd_method)
replay_cave_bench_begin :: proc(self: ^ReplayCave) {
    bench_count, bench_dropped = 0, 0
    bench_tx_start = bench_bytes(self)
    bench_accepted_start = self.accepted
    bench_active = true
    packet_meter_begin(self)
}

@(gd_method)
replay_cave_bench_end :: proc(self: ^ReplayCave) {
    bench_tx_stop = bench_bytes(self)
    bench_active = false
    packet_meter_end(self)
}

@(gd_method)
replay_cave_bench_sample :: proc(self: ^ReplayCave, index: gd.Int) -> gd.Int {
    if index == -1 {
        return gd.Int(bench_count)
    }

    if index == -2 {
        return gd.Int(bench_dropped)
    }

    return index >= 0 && index < gd.Int(bench_count) ? gd.Int(bench_times[index]) : -1
}

@(gd_method)
replay_cave_bench_backup :: proc(self: ^ReplayCave) -> bool {
    return rgd.session_backup_seat(self.session, 2, game.HZ * 5) == .None
}

@(gd_method)
replay_cave_bench_use :: proc(self: ^ReplayCave, door: bool) {
    if door {
        replay_cave_door(self)
    } else {
        replay_cave_loot(self, 0)
    }
}

@(gd_method)
replay_cave_bench_value :: proc(self: ^ReplayCave, key: string, remote: bool) -> gd.Float {
    if key == "confirmed" {
        return gd.Float(self.accepted - bench_accepted_start)
    }

    if key == "visible_gems" || key == "visible_bag" || key == "visible_door" {
        shown, available := rgd.session_state(self.session)

        if !available {
            return -1
        }

        if key == "visible_gems" {
            return gd.Float(game.world_items(&shown.state, game.GEM))
        }

        if key == "visible_door" {
            return shown.state.door_open ? 1 : 0
        }

        seat := rgd.session_seat(self.session)

        if seat == 0 {
            return -1
        }

        bag := shown.state.players[seat - 1].bag
        return gd.Float(p.inventory_count(bag[:], game.GEM))
    }

    frame, ok := rgd.session_authority_state(self.session)

    if key == "ready" {
        return ok && replay_cave_probe_players(self) == 2 ? 1 : 0
    }

    if !ok {
        return -1
    }

    switch key {
    case "players":
        return gd.Float(replay_cave_probe_players(self))
    case "tx":
        return gd.Float((bench_active ? bench_bytes(self) : bench_tx_stop) - bench_tx_start)
    case "mobs":
        return gd.Float(frame.state.dwellers.count)
    case "depth":
        return gd.Float(frame.state.depth)
    case "gems":
        return gd.Float(game.world_items(&frame.state, game.GEM))
    case "door":
        return frame.state.door_open ? 1 : 0
    case "hz":
        return gd.Float(game.HZ)
    case "seed":
        return gd.Float(frame.state.seed)
    case "backup":
        receipt, found := rgd.session_backup_receipt(self.session)
        return found ? gd.Float(receipt.archive.tick) : 0
    }

    seat := rgd.session_seat(self.session)

    if remote {
        seat = seat == 1 ? 2 : 1
    }

    player := frame.state.players[seat - 1]

    switch key {
    case "x":
        return gd.Float(player.position[0])
    case "y":
        return gd.Float(player.position[1])
    case "hp":
        return gd.Float(player.hp)
    case "bag":
        bag := player.bag
        return gd.Float(p.inventory_count(bag[:], game.GEM))
    case "render_x", "render_y":
        node, found := scenegd.nodes_get(&self.players, u64(seat))

        if found {
            return gd.Float(gd.node2d_get_position(cast(gd.Node2d)node)[key == "render_x" ? 0 : 1])
        }
    }

    return -1
}
