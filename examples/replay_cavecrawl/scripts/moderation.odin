package replay_cavecrawl

import "core:fmt"
import gd "godot:godot"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import lb "godot:replay/lobby"

Cave_Moderation :: struct {
    panel:            gd.Control,
    players:          gd.Option_Button,
    button:           gd.Base_Button,
    notice:           gd.Label,
    roster:           u64,
    pending, removed: bool,
    names:            [4]lb.Name,
    bindings:         [4]net.Connection,
}

cave_moderation_ready :: proc(self: ^ReplayCave) {
    m := &self.moderation
    m.panel = cast(gd.Control)gd.get_node(self.owner, "Lobby/Panel/Column/Moderation")
    m.players = cast(gd.Option_Button)gd.get_node(m.panel, "Players")
    m.button = cast(gd.Base_Button)gd.get_node(m.panel, "Remove")
    m.notice = cast(gd.Label)gd.get_node(m.panel, "Notice")
    gd.connect_to(m.button, "pressed", self.owner, "on_remove_player")
}

@(gd_method)
replay_cave_on_remove_player :: proc(self: ^ReplayCave) {
    chosen := gd.option_button_get_selected_id(self.moderation.players)

    if chosen > 0 && chosen <= 4 && self.session.authority {
        connection, live := net.server_seat_connection(&self.session.server, u16(chosen))

        if !live || connection != self.moderation.bindings[chosen - 1] {
            gd.set_string(self.moderation.notice, "text", "The player connection changed. Select the player again.")
            return
        }

        replay_cave_kick(self, gd.Int(chosen))
    }
}

// Host operation, not a gameplay RPC available to guests. Room removal requires
// coordinator acknowledgment; direct sessions use their durable checkpoint ban.
@(gd_method)
replay_cave_kick :: proc(self: ^ReplayCave, seat: gd.Int) {
    if !self.ready ||
       !self.session.authority ||
       self.moderation.pending ||
       seat < 1 ||
       seat > 4 ||
       u16(seat) == rgd.session_seat(self.session) {
        return
    }

    error :=
        self.room.ready ? rgd.room_remove(&self.room, u16(seat)) : net.server_kick(&self.session.server, u16(seat), true)

    if error != .None {
        gd.set_string(self.moderation.notice, "text", fmt.ctprintf("Could not remove player: %v", error))
        return
    }

    self.moderation.pending = self.room.ready
    gd.set_string(
        self.moderation.notice,
        "text",
        self.room.ready ? "Removing player…" : "Player removed. Rejoining this session is blocked.",
    )
}

cave_moderation_removed :: proc(self: ^ReplayCave) -> bool {
    if !self.ready {
        return false
    }

    removed := self.room.ready && self.room.removed

    if !self.session.authority && self.session.client.phase == .Rejected {
        removed = removed || self.session.client.rejection == .Banned || self.session.client.rejection == .Removed
    }

    if !removed {
        return false
    }

    replay_cave_on_leave(self)
    self.moderation.removed = true
    gd.set_string(self.lobby_status, "text", "You were removed from this party. Rejoining is blocked.")
    gd.print_str("REPLAY_CAVE_REMOVED")
    return true
}

cave_moderation_frame :: proc(self: ^ReplayCave) {
    m := &self.moderation
    available := self.ready && self.session.authority && (!self.room.ready || self.room.phase == .Hosting)
    gd.canvas_item_set_visible(m.panel, available)

    if !available {
        return
    }

    if m.pending && (self.room.removal.phase == .Removed || self.room.removal.phase == .Failed) {
        m.pending = false
        gd.set_string(
            m.notice,
            "text",
            self.room.removal.phase == .Removed ? "Player removed. Rejoining this party is blocked." : "Removal could not be confirmed. Try again after reconnecting.",
        )
    }

    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return
    }

    mask := u64(0)
    bindings: [4]net.Connection

    for seat in 1 ..= 4 {
        connection, live := net.server_seat_connection(&self.session.server, u16(seat))

        if live {
            mask |= u64(1) << uint(seat - 1)
            bindings[seat - 1] = connection
        }
    }

    if mask != m.roster || m.names != frame.state.lobby.names || m.bindings != bindings {
        chosen := gd.option_button_get_selected_id(m.players)
        gd.option_button_clear(m.players)
        index := 0
        selected := 0

        for name, i in frame.state.lobby.names {
            if mask & (u64(1) << uint(i)) != 0 {
                name := name
                text := gd.new_string_odin(fmt.tprintf("%s (seat %d)", lb.text(&name), i + 1))
                gd.option_button_add_item(m.players, text, gd.Int(i + 1))
                gd.free_string(text)

                if chosen == i32(i + 1) {
                    selected = index
                }

                index += 1
            }
        }

        if index > 0 {
            gd.option_button_select(m.players, gd.Int(selected))
        }

        m.roster, m.names, m.bindings = mask, frame.state.lobby.names, bindings
    }

    gd.base_button_set_disabled(m.button, m.pending || mask == 0)
}
