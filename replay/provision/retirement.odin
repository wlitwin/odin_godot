package replay_provision

import auth "godot:replay/authority"

// Optional trusted embedding hooks. No client packet can select a retirement
// policy, inspect archived credentials or remove an arbitrary resident room.
Creation_Guard :: proc(user: rawptr, room: u64) -> Error
Reclaim :: proc(user: rawptr, hub: ^Hub) -> Error
Archive :: proc(user: rawptr, expected: Bundle) -> bool

// Eligibility is necessary, not sufficient: the embedding must also release
// any signaling/checkpoint references and protect live physical connections.
hub_room_idle :: proc(h: ^Hub, slot: int, idle_ms: u64) -> (bool, Error) {
    if !h.ready || h.poisoned || slot < 0 || slot >= len(h.rooms) ||
       h.rooms[slot] == nil || idle_ms < 1000 || idle_ms > 86400000 {return false, .Invalid}
    now, valid := h.clock.read(h.clock.user)
    if !valid || now < h.now || now < h.activity[slot] {hub_poison(h); return false, .Clock}
    if now - h.activity[slot] < idle_ms {return false, .None}
    view, error := auth.coordinator_view(&h.rooms[slot].service.coordinator, now)
    if error != .None {hub_poison(h); return false, .Clock}
    return view.remaining_ms == 0, .None
}

// Archive under a durable compare-and-swap before freeing the stable room
// owner. An uncertain archive fences the hub, just like uncertain creation.
hub_archive_room :: proc(h: ^Hub, slot: int, idle_ms: u64, archive: Archive, user: rawptr) -> Error {
    if archive == nil {return .Invalid}
    eligible, error := hub_room_idle(h, slot, idle_ms)
    if error != .None {return error}
    if !eligible {return .Denied}
    room := h.rooms[slot]
    if !archive(user, room.bundle) {hub_poison(h); return .Storage}
    close(room)
    free(room, h.allocator)
    h.rooms[slot], h.activity[slot] = nil, 0
    return .None
}
