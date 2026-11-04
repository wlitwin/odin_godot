package cavecrawl_scripts
import gd "godot:godot"
import ks "godot:kit/session"
import kn "godot:kit/net"

bench_active: bool
bench_times: [4096]u64
bench_count, bench_dropped: int
bench_tx: u64
bench_confirmed: u32
bench_sender: ks.Send_Proc
bench_send_user: rawptr

bench_install :: proc(self: ^CaveLobby) {
    bench_sender, bench_send_user = self.ses.send, self.ses.send_user
    self.ses.send = proc(user: rawptr, peer: ks.Peer_Id, bytes: []u8, channel: ks.Channel) {
        // With one remote participant, one send is one framed application packet.
        if bench_active {
            bench_tx += u64(len(bytes) + 1)
        }

        bench_sender(bench_send_user, peer, bytes, channel)
    }
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
cave_lobby_bench_boot :: proc(self: ^CaveLobby, host: bool) {
    if host {
        cave_lobby_on_host(self)
    } else {
        cave_lobby_on_join(self)
    }
}

@(gd_method)
cave_lobby_bench_begin :: proc(self: ^CaveLobby) {
    bench_count, bench_dropped = 0, 0
    bench_tx = 0
    bench_confirmed = 0
    bench_active = true
}

@(gd_method)
cave_lobby_bench_end :: proc(self: ^CaveLobby) {
    bench_active = false
}

@(gd_method)
cave_lobby_bench_sample :: proc(self: ^CaveLobby, index: gd.Int) -> gd.Int {
    if index == -1 {
        return gd.Int(bench_count)
    }

    if index == -2 {
        return gd.Int(bench_dropped)
    }

    return index >= 0 && index < gd.Int(bench_count) ? gd.Int(bench_times[index]) : -1
}

@(gd_method)
cave_lobby_bench_value :: proc(self: ^CaveLobby, key: string, remote: bool) -> gd.Float {
    switch key {
    case "confirmed":
        return gd.Float(bench_confirmed)
    case "visible_gems":
        return gd.Float(cave_lobby_world_gems(self))
    case "visible_bag":
        return gd.Float(cave_lobby_my_gems(self))
    case "visible_door":
        return cave_lobby_door_open(self) ? 1 : 0
    case "players":
        return gd.Float(ks.session_count(&self.ses, connected_only = true))
    case "ready":
        return cave_lobby_world_ready(self) ? 1 : 0
    case "tx":
        return gd.Float(bench_tx)
    case "mobs":
        return gd.Float(len(self.dwellers))
    case "depth":
        return self.level != nil ? gd.Float(self.level.depth) : 0
    case "gems":
        return gd.Float(cave_lobby_world_gems(self))
    case "door":
        return cave_lobby_door_open(self) ? 1 : 0
    case "hz":
        return gd.Float(ks.session_tick_hz(&self.ses))
    case "seed":
        return self.level != nil ? gd.Float(self.level.seed) : 0
    case "backup":
        return self.ses.is_host ? gd.Float(self.ses.backup_tick) : gd.Float(len(self.ses.backup))
    }

    for id, sp in self.spelunkers {
        mine := id == self.avatar_of[self.ses.me]

        if mine == remote {
            continue
        }

        switch key {
        case "x":
            return gd.Float(sp.x)
        case "y":
            return gd.Float(sp.y)
        case "render_x":
            return gd.Float(gd.node2d_get_position(sp.owner)[0])
        case "render_y":
            return gd.Float(gd.node2d_get_position(sp.owner)[1])
        case "hp":
            return gd.Float(sp.hp)
        case "bag":
            return gd.Float(kitems_count(sp))
        }
    }

    return -1
}

kitems_count :: proc(sp: ^Spelunker) -> u32 {
    n := u32(0)

    for stack in sp.bag {
        if stack.item == GEM {
            n += u32(stack.count)
        }
    }

    return n
}

@(gd_method)
cave_lobby_bench_backup :: proc(self: ^CaveLobby) -> bool {
    return true
} // already automatic

@(gd_method)
cave_lobby_bench_start_game :: proc(self: ^CaveLobby) {
    cave_lobby_on_start(self)
}

@(gd_method)
cave_lobby_bench_use :: proc(self: ^CaveLobby, door: bool) {
    cave_lobby_interact(self)
}
