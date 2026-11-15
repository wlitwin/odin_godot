package replay_checkpoint

import "core:mem"
import p "godot:replay/provision"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

// One deployment-selected model/backend and bounded endpoint per resident room.
// Sync only mirrors already-admitted rooms; incoming checkpoint packets cannot
// create a room, load storage, or restart an authority coordinator for routing.
Hub :: struct {
    ready:     bool,
    allocator: mem.Allocator,
    provision: ^p.Hub,
    backend:   Backend,
    servers:   []^Server,
    codecs:    Codecs,
}

hub_open :: proc(h: ^Hub, provision: ^p.Hub, backend: Backend, allocator := context.allocator) -> Error {
    if h.ready ||
       provision == nil ||
       !provision.ready ||
       provision.poisoned ||
       backend.load == nil ||
       backend.publish == nil {
        return .Invalid
    }

    h.allocator, h.provision, h.backend = allocator, provision, backend

    if !codecs_init(&h.codecs, allocator) {
        hub_close(h)
        return .Capacity
    }

    h.servers = make([]^Server, len(provision.rooms), allocator)
    h.ready = true

    if error := hub_sync(h); error != .None {
        hub_close(h)
        return error
    }

    return .None
}

hub_close :: proc(h: ^Hub) {
    for s in h.servers {
        if s != nil {
            server_close(s)
            free(s, h.allocator)
        }
    }

    delete(h.servers, h.allocator)
    codecs_destroy(&h.codecs)
    h^ = {}
}

hub_sync :: proc(h: ^Hub) -> Error {
    if !h.ready || !h.provision.ready {
        return .Invalid
    }

    if h.provision.poisoned {
        return .Storage
    }

    if len(h.servers) != len(h.provision.rooms) {
        return .Invalid
    }

    for room, i in h.provision.rooms {
        if room == nil {
            if h.servers[i] != nil {
                return .Invalid
            }

            continue
        }

        if h.servers[i] != nil {
            if h.servers[i].authority != &room.service {
                return .Invalid
            }

            continue
        }

        endpoint := new(Server, h.allocator)

        if !server_open(endpoint, &room.service, h.backend, h.provision.wire, allocator = h.allocator) {
            server_close(endpoint)
            free(endpoint, h.allocator)
            return .Storage
        }

        h.servers[i] = endpoint
    }

    return .None
}

hub_update :: proc(h: ^Hub) -> Error {
    if error := hub_sync(h); error != .None {
        return error
    }

    for endpoint in h.servers {
        if endpoint != nil {
            server_update(endpoint)
        }
    }

    return .None
}

hub_receive :: proc(h: ^Hub, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !h.ready ||
       !h.provision.ready ||
       h.provision.poisoned ||
       len(bytes) < sc.HEADER_BYTES + 32 ||
       len(bytes) > PACKET_BYTES {
        return false
    }

    meta, _, report := sc.inspect(bytes[:len(bytes) - 32])

    if report.error != .None || meta.content != h.provision.config.content {
        return false
    }

    room_id: u64

    if meta.kind == REQUEST_KIND {
        q: Request

        if !read(&h.codecs.request, &q, bytes, REQUEST_KIND, meta.content) {
            return false
        }

        room_id = q.room
    } else if meta.kind == UPSTREAM_KIND {
        d: Data

        if !read(&h.codecs.data, &d, bytes, UPSTREAM_KIND, meta.content) {
            return false
        }

        room_id = d.room
    } else {
        return false
    }

    for endpoint in h.servers {
        if endpoint != nil && endpoint.authority.coordinator.record.room == room_id {
            return server_receive(endpoint, from, bytes)
        }
    }

    return false
}
