package replay_godot_debug

import replaygd "godot:replay/godot"

import c "godot:replay/telemetry"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import gd "godot:godot"

session_diagnostics_enable :: proc(options: ^replaygd.Session_Options) -> bool {
    _, ok := rec.link_add_application(&options.replication, {handles = diagnostics_classify})
    return ok
}

@(private)
diagnostics_classify :: proc(_: rawptr, _: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> bool {
    return channel == .Unreliable && c.handles(bytes)
}

session_diagnostics_frame :: proc(owner: ^c.Diagnostics, s: ^replaygd.Session($S, $C, $A, $E, $N)) -> bool {
    if !owner.ready {
        return false
    }

    // A caller may keep its presentation object after the session has closed.
    // Failure must not leave the previous session's measurements readable.
    if s == nil || !s.ready || N > c.MAX_SEATS {
        owner.enabled = false
        owner.bound = false
        owner.rows = {}
        owner.peers = {}
        owner.count = 0
        return false
    }

    wire: tr.Transport

    if s.link.ready {
        lane := -1

        for route, i in s.link.cfg.applications {
            if route.handles == diagnostics_classify {
                lane = i + 3
                break
            }
        }

        if lane < 0 {
            owner.enabled = false
            owner.bound = false
            return false
        }

        wire = rec.link_application_lane(&s.link, lane)
    }

    bindings: [net.MAX_PEERS]c.Binding
    count := 0
    local := c.Binding {
        seat = replaygd.session_seat(s),
    }
    epoch, content := s.options.network.epoch, s.options.network.content
    enabled := !s.fenced

    if s.authority {
        epoch, content = s.server.cfg.epoch, s.server.cfg.content

        if s.server.cfg.require_permit {
            enabled = enabled && s.server.permit.allow != nil && s.server.permit.allow(s.server.permit.user, epoch)
        }

        connections: [net.MAX_PEERS]net.Connection
        count = net.server_connections(&s.server, connections[:])

        for connection, i in connections[:count] {
            bindings[i] = {
                peer       = connection.peer,
                generation = connection.generation,
                seat       = connection.seat,
            }
        }
    } else {
        epoch, content = s.client.cfg.epoch, s.client.cfg.content
        local.generation = s.client.generation

        if s.client.cfg.require_permit {
            enabled = enabled && s.client.permit.allow != nil && s.client.permit.allow(s.client.permit.user, epoch)
        }

        // Replacing a gameplay baseline does not replace the admitted connection.
        // Round-trip probes remain valid during a gameplay baseline resync.
        admitted :=
            s.client.has_world &&
            s.client.generation != 0 &&
            (s.client.phase == .Running || s.client.phase == .Resyncing)
        enabled = enabled && admitted

        if enabled {
            bindings[0] = {
                peer       = s.client.authority,
                generation = s.client.generation,
            }
            count = 1
        }
    }

    if !c.configure(
        owner,
        wire,
        {s.options.replication.room, epoch, content},
        s.authority,
        local,
        bindings[:count],
        enabled,
        gd.time_get_ticks_msec(gd.singleton_time()),
    ) {
        return false
    }

    c.frame(owner)
    return true
}
