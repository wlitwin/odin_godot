//gd:extends Node
//gd:class ReplayTelemetryProbe
package replay_telemetry_probe

import gd "godot:godot"
import rgd "godot:replay/godot"
import dg "godot:replay/telemetry"
import sc "godot:replay/schema"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import debuggd "godot:replay/godot/debug"

ReplayTelemetryProbe :: struct {
    owner: gd.Node,
}

exercise :: proc() -> bool {
    m: tr.Memory

    if !tr.memory_init(&m, 91, {2, 32, 512, 256}) {
        return false
    }

    defer tr.memory_destroy(&m)
    ep: [2]tr.Memory_Endpoint

    for &peer, i in ep {
        if !tr.memory_open(&m, &peer, tr.Peer_Id(i + 1)) {
            return false
        }
    }

    defer for &peer in ep {
        wire := tr.memory_transport(&peer)
        tr.close(&wire)
    }

    d: dg.Diagnostics

    if !dg.init(&d) {
        return false
    }

    defer dg.destroy(&d)
    s: rgd.Session(u8, u8, u8, u8, 2)
    options := rgd.SESSION_OPTIONS
    options.network.epoch, options.network.content = 1, 19
    options.replication.room = 4

    if !debuggd.session_diagnostics_enable(&options) {
        return false
    }

    s.ready, s.role, s.options = true, .Client, options
    s.client.cfg = options.network
    s.client.authority = 1
    s.client.generation = 22
    s.client.seat = 2
    s.client.phase = .Resyncing
    s.client.has_world = true

    if !rec.link_init(&s.link, tr.memory_transport(&ep[1]), options.replication) {
        return false
    }

    defer rec.link_destroy(&s.link)
    packet := dg.Packet {
        version  = 1,
        room     = 4,
        binding  = 22,
        sequence = 1,
        kind     = .Report,
    }
    packet.rows[0] = {
        present = true,
        known   = true,
    }
    packet.rows[1] = {
        present       = true,
        known         = true,
        round_trip_ms = 42,
    }
    bytes: [512]u8

    if sc.pack(&d.codec, packet, {kind = dg.PACKET_KIND, epoch = 1, content = 19}, bytes[:]).error != .None {
        return false
    }

    wire := tr.memory_transport(&ep[0])

    if tr.send(&wire, 2, .Unreliable, bytes[:d.codec.wire_size + sc.HEADER_BYTES]) != .Sent {
        return false
    }

    if !tr.memory_advance(&m, 0) || !rec.link_pump(&s.link, gd.time_get_ticks_msec(gd.singleton_time())) {
        return false
    }

    if !debuggd.session_diagnostics_frame(&d, &s) || !dg.read(&d, 2).known || dg.read(&d, 2).round_trip_ms != 42 {
        gd.print_str("TELEMETRY_FAIL resync")
        return false
    }

    s.fenced = true

    if !debuggd.session_diagnostics_frame(&d, &s) || dg.read(&d, 2).known {
        gd.print_str("TELEMETRY_FAIL fence")
        return false
    }

    s.fenced = false
    s.client.phase = .Running

    if !debuggd.session_diagnostics_frame(&d, &s) || !d.enabled {
        return false
    }

    s.ready = false

    if debuggd.session_diagnostics_frame(&d, &s) || d.enabled {
        gd.print_str("TELEMETRY_FAIL closed session retains enabled telemetry")
        return false
    }

    gd.print_str("REPLAY_TELEMETRY_GODOT_OK routed_report=true resync=true fencing=true closed=true")
    return true
}

replay_telemetry_probe_ready :: proc(self: ^ReplayTelemetryProbe) {
    ok := exercise()
    gd.scene_tree_quit(gd.node_get_tree(self.owner), ok ? 0 : 1)
}
