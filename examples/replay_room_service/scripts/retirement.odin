package replay_room_service

import "core:fmt"
import gd "godot:godot"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import rgd "godot:replay/godot"

room_creation_guard :: proc(user: rawptr, room: u64) -> p.Error {
    self := cast(^Game)user
    return db.creation_guard(&self.store, room)
}

reclaim_room :: proc(user: rawptr, hub: ^p.Hub) -> p.Error {
    self := cast(^Game)user

    if self.service.reclaim_idle_ms == 0 || self.checkpoints.ready {
        return .Capacity
    }

    for room, slot in hub.rooms {
        if room == nil {
            continue
        }

        eligible, error := p.hub_room_idle(hub, slot, self.service.reclaim_idle_ms)

        if error != .None {
            return error
        }

        if !eligible || !rgd.rendezvous_hub_release_idle_slot(&self.signal, slot) {
            continue
        }

        if error := p.hub_archive_room(hub, slot, self.service.reclaim_idle_ms, db.archive, &self.store);
           error != .None {
            return error
        }

        active := 0

        for item in hub.rooms {
            if item != nil {
                active += 1
            }
        }

        gd.print_str(
            fmt.tprintf(
                "REPLAY_ROOM_ARCHIVED active=%d capacity=%d private_history_retained=true",
                active,
                len(hub.rooms),
            ),
        )
        return .None
    }

    return .Capacity
}
