//gd:extends Node
//gd:class ReplayCommsProbe
package replay_comms_probe

import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import rgd "godot:replay/godot"
import co "godot:replay/comms"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import lb "godot:replay/lobby"

ReplayCommsProbe :: struct {
    owner: gd.Node,
}

Fixture :: struct {
    memory:       tr.Memory,
    ep:           [2]tr.Memory_Endpoint,
    host, client: co.Comms,
    session:      rgd.Session(u8, u8, u8, u8, 2),
    tick:         u64,
    observer:     bool,
    display:      lb.Name,
}

HOST :: co.Binding {
    peer = 1,
    generation = 11,
    seat = 1,
    identity = {0 = 1},
}
GUEST :: co.Binding {
    peer = 2,
    generation = 22,
    seat = 2,
    identity = {0 = 2},
}

pump :: proc(f: ^Fixture) -> bool {
    f.tick += 1

    if !tr.memory_advance(&f.memory, f.tick) {
        return false
    }

    guest := GUEST
    guest.identity = net.token_hash(f.session.token)

    if f.observer {
        guest.seat = 0
        guest.spectator = true
        guest.observer_name_allowed = true
    }

    if !co.configure(
        &f.host,
        tr.memory_transport(&f.ep[0]),
        {4, 1, 19},
        true,
        HOST,
        []co.Binding{guest},
        true,
        gd.time_get_ticks_msec(gd.singleton_time()),
    ) {
        return false
    }

    co.frame(&f.host)

    if !rec.link_pump(&f.session.link, gd.time_get_ticks_msec(gd.singleton_time())) {
        return false
    }

    return rgd.session_comms_frame(&f.client, &f.session, observer_name = f.display)
}

exercise :: proc() -> bool {
    f: Fixture

    if !tr.memory_init(&f.memory, 91, {2, 512, 8192, 65536}) {
        return false
    }

    defer tr.memory_destroy(&f.memory)

    for &ep, i in f.ep {
        if !tr.memory_open(&f.memory, &ep, tr.Peer_Id(i + 1)) {
            return false
        }
    }

    defer for &ep in f.ep {
        wire := tr.memory_transport(&ep)
        tr.close(&wire)
    }

    if !co.init(&f.host) {
        return false
    }

    defer co.destroy(&f.host)

    if !co.init(&f.client) {
        return false
    }

    defer co.destroy(&f.client)
    options := rgd.SESSION_OPTIONS
    options.network.epoch, options.network.content = 1, 19
    options.replication.room = 4

    if !rgd.session_comms_enable(&options) {
        return false
    }

    s := &f.session
    s.ready = true
    s.role = .Client
    s.token = {
        0 = 2,
    }
    s.options = options
    s.client.cfg = options.network
    s.client.authority = 1
    s.client.generation = 22
    s.client.seat = 2
    s.client.phase = .Running
    s.client.has_world = true

    if !rec.link_init(&s.link, tr.memory_transport(&f.ep[1]), options.replication) {
        return false
    }

    defer rec.link_destroy(&s.link)

    if !pump(&f) || co.system(&f.host, "before reset") != .None {
        return false
    }

    for _ in 0 ..< 8 {
        if !pump(&f) {
            return false
        }
    }

    if f.client.line_count != 1 {
        return false
    }

    // Emulate the valid metadata at a same-connection gameplay resync. The
    // actual adapter and routed reliable messages still run, not a chat mock.
    if co.say(&f.client, "queued before reset") != .None {
        return false
    }

    s.client.phase = .Resyncing

    if co.system(&f.host, "during reset") != .None {
        return false
    }

    for _ in 0 ..< 12 {
        if !pump(&f) {
            return false
        }
    }

    if !f.client.enabled || f.client.pending_count != 0 || f.client.line_count != 3 || f.client.scope_drops != 0 {
        gd.print_str(
            fmt.tprintf(
                "REPLAY_COMMS_RESYNC_FAIL enabled=%v pending=%d lines=%d rejected=%d retired=%d",
                f.client.enabled,
                f.client.pending_count,
                f.client.line_count,
                f.client.rejected,
                f.client.scope_drops,
            ),
        )
        return false
    }

    s.client.phase = .Running

    if co.say(&f.client, "after reset") != .None {
        return false
    }

    for _ in 0 ..< 12 {
        if !pump(&f) {
            return false
        }
    }

    if f.client.line_count != 4 || !reflect.equal(f.host.lines[:4], f.client.lines[:4], true) {
        return false
    }

    // Resync eligibility never grants a lease or bypasses rejection/admission.
    s.client.phase = .Resyncing
    s.fenced = true

    if !pump(&f) || f.client.enabled {
        return false
    }

    s.fenced = false
    s.client.phase = .Rejected

    if !pump(&f) || f.client.enabled {
        return false
    }

    s.client.phase = .Joining
    s.client.generation = 0
    s.client.has_world = false

    if !pump(&f) || f.client.enabled {
        return false
    }

    // A real Session adapter supplies a negotiated spectator label independently
    // of model seats; the relay still stamps the authenticated token binding.
    f.observer = true
    f.display, _ = lb.name("Watcher Ω")
    s.role = .Observer
    s.client.phase = .Running
    s.client.generation = 22
    s.client.seat = 0
    s.client.spectator = true
    s.client.has_world = true
    s.client.observer_names_negotiated = true

    if !pump(&f) || co.say(&f.client, "observer adapter") != .None {
        return false
    }

    for _ in 0 ..< 12 {
        if !pump(&f) {
            return false
        }
    }

    entry := f.host.lines[f.host.line_count - 1]

    if entry.name != f.display ||
       entry.seat != 0 ||
       entry.identity != net.token_hash(s.token) ||
       co.mark(&f.client, 1, {1, 2, 0}) != .Permission {
        return false
    }

    gd.print_str("REPLAY_COMMS_OBSERVER_ADAPTER_OK name=true identity=true no_seat=true marker_denied=true")
    gd.print_str(
        "REPLAY_COMMS_GODOT_OK resync_delivery=true queued_echo=true next_request=true fencing=true admission=true",
    )
    return true
}

replay_comms_probe_ready :: proc(self: ^ReplayCommsProbe) {
    ok := exercise()
    gd.scene_tree_quit(gd.node_get_tree(self.owner), ok ? 0 : 1)
}
