package replay_scrapyard

import gd "godot:godot"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/game"
import content "../shared/content"
import profile "../shared/profile"

issue_action :: proc(self: ^ReplayScrapyard, action: game.Action) -> (u64, net.Error) {
    if self.room.ready {
        return rgd.room_issue(&self.room, action)
    }

    return rgd.session_issue(self.session, action)
}

issue :: proc(self: ^ReplayScrapyard, action: game.Action) -> bool {
    _, err := issue_action(self, action)
    return err == .None
}

select_profile :: proc(self: ^ReplayScrapyard, fallback: game.Profile) {
    if self.selected {
        return
    }

    self.choices[0] = fallback

    if self.local_profile[0].has_record {
        self.choices[0] = self.local_profile[0].record.profile
        self.choices[0].ready = false
    }

    self.selected = true
}

declare :: proc(self: ^ReplayScrapyard) {
    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 || frame.state.players[seat - 1].in_yard {
        return
    }

    select_profile(self, frame.state.players[seat - 1].profile)
    resolved, resolved_ok := profile.resolve(
        self.choices[0],
        self.local_profile[0].automatic,
        seat,
        &frame.state.catalog,
    )

    if resolved_ok {
        self.choices[0] = resolved
    }

    if !content.gun_present(&frame.state.catalog, self.choices[0].iron) {
        self.choices[0].iron = content.next_gun(&frame.state.catalog, frame.state.catalog.gun_count - 1)
    }

    for &id, slot in self.choices[0].abilities {
        if !content.ability_present(&frame.state.catalog, id) {
            id =
                content.ability_present(&frame.state.catalog, u8(slot + 1)) ? u8(slot + 1) : content.next_ability(&frame.state.catalog, 0)
        }
    }

    text := gd.line_edit_get_text(self.name_edit)
    self.choices[0].name = game.name(gd.gd_string_to_odin(text))
    gd.free_string(text)
    self.choices[0].meta = self.local_profile[0].record.profile.meta
    sequence, err := issue_action(self, game.Action{kind = .Profile, profile = self.choices[0]})
    self.declared = err == .None

    if self.declared {
        self.declare_sequence = sequence
    }
}

@(gd_method)
replay_scrapyard_on_solo :: proc(self: ^ReplayScrapyard) {
    open_new(self, .Solo)
}

@(gd_method)
replay_scrapyard_on_host :: proc(self: ^ReplayScrapyard) {
    if self.online.enabled {
        online_begin(self, .Create)
    } else {
        open_new(self, .Host)
    }
}

@(gd_method)
replay_scrapyard_on_join :: proc(self: ^ReplayScrapyard) {
    if self.online.enabled {
        online_begin(self, .Join)
    } else {
        open_new(self, .Client)
    }
}

@(gd_method)
replay_scrapyard_on_watch :: proc(self: ^ReplayScrapyard) {
    if self.online.enabled {
        online_begin(self, .Join, true)
    } else {
        open_new(self, .Observer)
    }
}

@(gd_method)
replay_scrapyard_on_look :: proc(self: ^ReplayScrapyard) {
    muster_choose(self, 0, 1)
}

@(gd_method)
replay_scrapyard_on_iron :: proc(self: ^ReplayScrapyard) {
    muster_choose(self, 1, 1)
}

ability_pick :: proc(self: ^ReplayScrapyard, slot: int) {
    muster_choose(self, slot + 2, 1)
}

@(gd_method)
replay_scrapyard_on_ability0 :: proc(self: ^ReplayScrapyard) {
    ability_pick(self, 0)
}

@(gd_method)
replay_scrapyard_on_ability1 :: proc(self: ^ReplayScrapyard) {
    ability_pick(self, 1)
}

@(gd_method)
replay_scrapyard_on_ready :: proc(self: ^ReplayScrapyard) {
    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 {
        return
    }

    muster_scope(self, &frame.state, seat)
    select_profile(self, frame.state.players[seat - 1].profile)
    muster_set_ready(self, !self.choices[0].ready)
}

@(gd_method)
replay_scrapyard_on_start :: proc(self: ^ReplayScrapyard) {
    muster_start(self)
}
