package replay_godot

import c "godot:replay/comms"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import gd "godot:godot"

// The Comms value lives beside Session/Room, so locally received scrollback
// survives an authority/transport replacement. It is not a gameplay checkpoint.
session_comms_enable :: proc(options: ^Session_Options) -> bool {
    _, ok := rec.link_add_application(&options.replication, {handles = comms_classify})
    return ok
}

@(private)
comms_classify :: proc(_: rawptr, _: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> bool {
    return channel == .Reliable && c.handles(bytes)
}

session_comms_frame :: proc(
    owner: ^c.Comms,
    s: ^Session($S, $C, $A, $E, $N),
    names: []lb.Name = nil,
    observer_name: lb.Name = {},
) -> bool {
    if !owner.ready || s == nil || !s.ready || (len(names) != 0 && len(names) != N) {
        return false
    }

    wire: tr.Transport

    if s.link.ready {
        lane := -1

        for route, i in s.link.cfg.applications {
            if route.handles == comms_classify {
                lane = i + 3
                break
            }
        }

        if lane < 0 {
            return false
        }

        wire = rec.link_application_lane(&s.link, lane)
    }

    bindings: [net.MAX_PEERS]c.Binding
    count := 0
    local := c.Binding {
        seat      = session_seat(s),
        identity  = net.token_hash(s.token),
        spectator = s.role == .Observer,
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
                peer                  = connection.peer,
                generation            = connection.generation,
                seat                  = connection.seat,
                identity              = connection.token_hash,
                spectator             = connection.spectator,
                observer_name_allowed = net.server_observer_names(&s.server, connection.peer),
            }

            if connection.seat > 0 && len(names) > 0 {
                bindings[i].name = names[connection.seat - 1]
            }
        }
    } else {
        epoch, content = s.client.cfg.epoch, s.client.cfg.content
        local.generation = s.client.generation
        local.observer_name_allowed = s.client.observer_names_negotiated

        if s.client.cfg.require_permit {
            enabled = enabled && s.client.permit.allow != nil && s.client.permit.allow(s.client.permit.user, epoch)
        }

        // Replacing a gameplay baseline does not replace the admitted connection.
        // Disabling here would discard reliable deliveries and retire/reset the
        // sender's request frontier while the authority still retained it.
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

    if local.seat > 0 && len(names) > 0 {
        local.name = names[local.seat - 1]
    } else if local.spectator {
        local.name = observer_name
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
