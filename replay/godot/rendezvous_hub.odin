package replay_godot

import "core:mem"
import gd "godot:godot"
import "godot:gdext"
import p "godot:replay/provision"
import tr "godot:replay/transport"
import wiregd "godot:replay/godot/internal/wire"
import transportgd "godot:replay/godot/transport"

Rendezvous_Hub :: struct {
    ready:     bool,
    allocator: mem.Allocator,
    hub:       ^p.Hub,
    socket:    ^transportgd.Websocket,
    rooms:     []Rendezvous,
    bindings:  [128]Rendezvous_Binding,
}

@(private)
Rendezvous_Binding :: struct {
    peer: tr.Peer_Id,
    room: int,
}

rendezvous_hub_init :: proc(
    r: ^Rendezvous_Hub,
    hub: ^p.Hub,
    socket: ^transportgd.Websocket,
    allocator := context.allocator,
) -> bool {
    if r.ready || hub == nil || !hub.ready || socket == nil || !socket.ready || !socket.server {
        return false
    }

    r.allocator, r.hub, r.socket = allocator, hub, socket
    r.rooms = make([]Rendezvous, len(hub.rooms), allocator)
    r.ready = true
    return true
}

rendezvous_hub_destroy :: proc(r: ^Rendezvous_Hub) {
    for &room in r.rooms {
        rendezvous_destroy(&room)
    }

    delete(r.rooms, r.allocator)
    r^ = {}
}

// Trusted room lifecycle seam: drop the cached service pointer before the hub
// archives/frees its room. A connected physical peer prevents reclamation.
rendezvous_hub_release_idle_slot :: proc(r: ^Rendezvous_Hub, slot: int) -> bool {
    if !r.ready || slot < 0 || slot >= len(r.rooms) {
        return false
    }

    for binding in r.bindings {
        if binding.peer != 0 && binding.room == slot && rendezvous_connection_live(r.socket, binding.peer) {
            return false
        }
    }

    for peer in r.rooms[slot].peers {
        if peer.physical != 0 && rendezvous_connection_live(r.socket, peer.physical) {
            return false
        }
    }

    rendezvous_destroy(&r.rooms[slot])

    for &binding in r.bindings {
        if binding.room == slot {
            binding = {}
        }
    }

    return true
}

rendezvous_hub_pump :: proc(r: ^Rendezvous_Hub) {
    if !r.ready {
        return
    }

    for &signal, i in r.rooms {
        room := r.hub.rooms[i]

        if room == nil || r.hub.poisoned || room.service.coordinator.poisoned {
            if signal.ready {
                rendezvous_destroy(&signal)
            }

            continue
        }

        if !signal.ready {
            if !rendezvous_init(&signal, &room.service, r.socket) {
                continue
            }
        }

        rendezvous_pump(&signal)
    }

    for &binding in r.bindings {
        if binding.peer != 0 && !rendezvous_connection_live(r.socket, binding.peer) {
            binding = {}
        }
    }
}

// Whether `bytes` from `from` belongs to this hub: the peer is already bound to
// one of its rooms, or the message names one of its current rendezvous codes.
// Unlike rendezvous_hub_receive it never disconnects or binds, so a service
// hosting several hubs on one socket can ask each in turn.
rendezvous_hub_claims :: proc(r: ^Rendezvous_Hub, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !r.ready || from == 0 {
        return false
    }

    for binding in r.bindings {
        if binding.peer == from {
            return true
        }
    }

    if len(bytes) > 32768 || !wiregd.json_depth(bytes) {
        return false
    }

    rendezvous_hub_pump(r)
    text := gd.new_string_odin(string(bytes))
    defer gd.free_string(text)
    value := gd.json_parse_string(text)
    defer gd.variant_destroy(&value)

    if gdext.variant_get_type(&value) != .Dictionary {
        return false
    }

    data := gd.variant_to_dictionary(&value)
    defer gd.free_dictionary(data)
    code := wiregd.get_string(&data, "room", 64)
    defer delete(code)

    if len(code) != 64 {
        return false
    }

    for &room in r.rooms {
        if room.ready && string(room.code[:]) == code {
            return true
        }
    }

    return false
}

// The first bounded JSON message selects an opaque current rendezvous code.
// That choice confers no membership: the existing per-room challenge/MAC and
// process-registration proof still authenticates this physical connection.
rendezvous_hub_receive :: proc(r: ^Rendezvous_Hub, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !r.ready || from == 0 {
        return false
    }

    rendezvous_hub_pump(r)

    for binding in r.bindings {
        if binding.peer == from {
            return rendezvous_receive(&r.rooms[binding.room], from, bytes)
        }
    }

    if len(bytes) > 32768 || !wiregd.json_depth(bytes) {
        transportgd.websocket_disconnect(r.socket, from)
        return false
    }

    text := gd.new_string_odin(string(bytes))
    defer gd.free_string(text)
    value := gd.json_parse_string(text)
    defer gd.variant_destroy(&value)

    if gdext.variant_get_type(&value) != .Dictionary {
        transportgd.websocket_disconnect(r.socket, from)
        return false
    }

    data := gd.variant_to_dictionary(&value)
    defer gd.free_dictionary(data)
    code := wiregd.get_string(&data, "room", 64)
    defer delete(code)

    if len(code) != 64 {
        transportgd.websocket_disconnect(r.socket, from)
        return false
    }

    slot := -1

    for &room, i in r.rooms {
        if room.ready && string(room.code[:]) == code {
            slot = i
            break
        }
    }

    if slot < 0 {
        transportgd.websocket_disconnect(r.socket, from)
        return false
    }

    for &binding in r.bindings {
        if binding.peer == 0 {
            binding = {from, slot}
            return rendezvous_receive(&r.rooms[slot], from, bytes)
        }
    }

    transportgd.websocket_disconnect(r.socket, from)
    return false
}
