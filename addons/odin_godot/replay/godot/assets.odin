package replay_godot

import a "godot:replay/assets"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import gd "godot:godot"

// Lives beside a Session/Room. Cache ownership outlives transport replacement;
// peer workers are rebuilt from the current admitted roster and authority epoch.
Session_Assets :: struct {
    ready:                bool,
    cache:                a.Cache,
    mesh:                 a.Mesh,
    config:               a.Mesh_Config,
    wire_user:            rawptr,
    epoch, content, room: u64,
    authority:            bool,
    validator_user:       rawptr,
    validator:            proc(user: rawptr, ref: a.Ref, bytes: []u8) -> bool,
    policy_user:          rawptr,
    authorize:            proc(user: rawptr, peer: tr.Peer_Id, ref: a.Ref) -> bool,
}

session_assets_init :: proc(
    owner: ^Session_Assets,
    cache := a.DEFAULT_CACHE_CONFIG,
    config := a.DEFAULT_MESH_CONFIG,
    validator: proc(user: rawptr, ref: a.Ref, bytes: []u8) -> bool = nil,
    validator_user: rawptr = nil,
    authorize: proc(user: rawptr, peer: tr.Peer_Id, ref: a.Ref) -> bool = nil,
    policy_user: rawptr = nil,
) -> a.Error {
    if owner.ready || cache.entries > a.MAX_WATCHED {
        return .Invalid_Config
    }

    if err := a.cache_init(&owner.cache, cache); err != .None {
        return err
    }

    owner.ready, owner.config = true, config
    owner.validator, owner.validator_user = validator, validator_user
    owner.authorize, owner.policy_user = authorize, policy_user
    return .None
}

session_assets_destroy :: proc(owner: ^Session_Assets) {
    a.mesh_destroy(&owner.mesh)
    a.cache_destroy(&owner.cache)
    owner^ = {}
}

session_assets_enable :: proc(options: ^Session_Options) -> bool {
    if options.replication.application_handles != nil && options.replication.application_handles != assets_classify {
        return false
    }

    options.replication.application_handles, options.replication.application_user = assets_classify, nil
    return true
}

@(private)
assets_classify :: proc(user: rawptr, from: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> bool {
    return channel == .Unreliable && a.handles(bytes)
}

// Call after Session/Room.frame, including when gameplay is fenced. References
// are the application's public working set (and any extra retained dependencies).
// Neither asset availability nor transfer callbacks mutate simulation state.
session_assets_frame :: proc(
    owner: ^Session_Assets,
    s: ^Session($S, $C, $A, $E, $N),
    refs: []a.Ref,
    local_refs: []a.Ref = nil,
) -> a.Mesh_Error {
    if !owner.ready {
        return .Not_Ready
    }

    if !s.ready {
        a.mesh_destroy(&owner.mesh)
        owner.wire_user = nil
        return .None
    }

    wire: tr.Transport

    if s.link.ready {
        if s.link.cfg.application_handles != assets_classify {
            return .Invalid_Config
        }

        wire = rec.link_application_transport(&s.link)
    }

    epoch := s.authority ? s.server.cfg.epoch : s.client.cfg.epoch
    content := s.authority ? s.server.cfg.content : s.client.cfg.content
    room := s.options.replication.room

    if !owner.mesh.ready ||
       owner.wire_user != wire.user ||
       owner.epoch != epoch ||
       owner.content != content ||
       owner.room != room ||
       owner.authority != s.authority {
        a.mesh_destroy(&owner.mesh)

        if err := a.mesh_init(
            &owner.mesh,
            &owner.cache,
            wire,
            owner.config,
            validator = owner.validator,
            validator_user = owner.validator_user,
            authorize = owner.authorize,
            policy_user = owner.policy_user,
        ); err != .None {
            return err
        }

        owner.wire_user, owner.epoch, owner.content, owner.room, owner.authority =
            wire.user, epoch, content, room, s.authority
    }

    if err := a.mesh_watch(&owner.mesh, refs); err != .None {
        return err
    }

    if err := a.mesh_announce(&owner.mesh, s.role == .Client ? local_refs : nil); err != .None {
        return err
    }

    // This facade's cache is for public room assets. Earlier cached revisions
    // remain available to a peer filling a retained checkpoint's dependencies.
    public: [a.MAX_WATCHED]a.Ref
    available := a.cache_refs(&owner.cache, public[:])

    if available > len(public) {
        return .Capacity
    }

    if err := a.mesh_publish(&owner.mesh, public[:available]); err != .None {
        return err
    }

    connections: [net.MAX_PEERS]net.Connection
    count := 0

    if s.authority {
        count = net.server_connections(&s.server, connections[:])
    } else if s.client.phase == .Running {
        connections[0] = {
            peer       = s.client.authority,
            generation = s.client.generation,
        }
        count = 1
    }

    for peer in owner.mesh.peers {
        if !peer.ready {
            continue
        }

        keep := false

        for connection in connections[:count] {
            if peer.peer == connection.peer {
                keep = true
                break
            }
        }

        if !keep {
            a.mesh_unbind(&owner.mesh, peer.peer)
        }
    }

    for connection in connections[:count] {
        if err := a.mesh_bind(
            &owner.mesh,
            connection.peer,
            {room, epoch, connection.generation, content},
            accept_offers = s.authority && !connection.spectator,
        ); err != .None {
            return err
        }
    }

    return a.mesh_frame(&owner.mesh, gd.time_get_ticks_msec(gd.singleton_time()))
}
