package replay_scrapyard

import gd "godot:godot"
import game "../shared/game"
import content "../shared/content"
import rgd "godot:replay/godot"

// Submission returns a sequence, not an authority verdict. The authority's
// admission hook remains the security boundary even if a remote caller bypasses
// this convenience method and constructs its own action packet.
@(gd_method)
replay_scrapyard_dev_spawn :: proc(self: ^ReplayScrapyard, kind, wanted: gd.Int, dx, dy: gd.Float) -> gd.Int {
    if !self.development || kind < 0 || kind >= content.MAX_MOBS || wanted < 1 || wanted > game.SEATS {
        return 0
    }

    action := game.Action {
        kind = .Dev_Spawn,
        item = u8(kind),
        slot = u8(wanted - 1),
        aim = {f32(dx), f32(dy)},
    }

    if !game.action_valid(action) {
        return 0
    }

    sequence, err := issue_action(self, action)

    if err != .None {
        return 0
    }

    self.development_sequence, self.development_result, self.development_reason = sequence, 0, 0
    return gd.Int(sequence)
}

// Input-driver navigation, not a teleport or world edit. Used by reproducible
// fixtures to move around authored cover before an interaction.
@(gd_method)
replay_scrapyard_dev_walk :: proc(self: ^ReplayScrapyard, x, y: gd.Float, enabled: bool) {
    target := [2]f32{f32(x), f32(y)}

    if enabled && !game.point_valid(target) {
        return
    }

    self.auto_walk, self.walk_target = enabled, target
    self.manual, self.auto_combat, self.auto_gate, self.manual_fire = true, false, false, false
}

development_issue :: proc(self: ^ReplayScrapyard, command: game.Development) -> gd.Int {
    if !self.development || !game.development_valid(command) {
        return 0
    }

    sequence, err := issue_action(self, game.Action{kind = .Dev_Edit, development = command})

    if err != .None {
        return 0
    }

    self.development_sequence, self.development_result, self.development_reason = sequence, 0, 0
    return gd.Int(sequence)
}

@(gd_method)
replay_scrapyard_dev_hurt :: proc(self: ^ReplayScrapyard, seat, amount: gd.Int) -> gd.Int {
    if seat < 1 || seat > game.SEATS || amount < 1 || amount > 255 {
        return 0
    }

    return development_issue(self, {kind = .Hurt, seat = u16(seat), amount = u32(amount)})
}

@(gd_method)
replay_scrapyard_dev_jam :: proc(self: ^ReplayScrapyard, seat: gd.Int) -> gd.Int {
    if seat < 1 || seat > game.SEATS {
        return 0
    }

    return development_issue(self, {kind = .Jam, seat = u16(seat)})
}

@(gd_method)
replay_scrapyard_dev_status :: proc(self: ^ReplayScrapyard, seat, status: gd.Int) -> gd.Int {
    if seat < 1 || seat > game.SEATS || status < 1 || status >= content.MAX_STATUS {
        return 0
    }

    return development_issue(self, {kind = .Status, seat = u16(seat), status = u8(status)})
}

@(gd_method)
replay_scrapyard_dev_grant_scrap :: proc(self: ^ReplayScrapyard, seat, amount: gd.Int) -> gd.Int {
    if seat < 1 || seat > game.SEATS || amount < 1 || amount > 1000000 {
        return 0
    }

    return development_issue(self, {kind = .Grant_Scrap, seat = u16(seat), amount = u32(amount)})
}

@(gd_method)
replay_scrapyard_dev_grant_cores :: proc(self: ^ReplayScrapyard, seat, amount: gd.Int) -> gd.Int {
    if seat < 1 || seat > game.SEATS || amount < 1 || amount > 1000000 {
        return 0
    }

    return development_issue(self, {kind = .Grant_Cores, seat = u16(seat), amount = u32(amount)})
}

@(gd_method)
replay_scrapyard_dev_smite :: proc(self: ^ReplayScrapyard, seat: gd.Int) -> gd.Int {
    if seat < 1 || seat > game.SEATS {
        return 0
    }

    return development_issue(self, {kind = .Smite, seat = u16(seat)})
}

// Authoring convenience over the normal Profile action/admission path.
@(gd_method)
replay_scrapyard_authoring_equip :: proc(self: ^ReplayScrapyard, wanted: gd.Int) -> bool {
    if !self.development || wanted < 1 || wanted >= content.MAX_ABILITIES {
        return false
    }

    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok ||
       seat == 0 ||
       frame.state.players[seat - 1].in_yard ||
       !content.ability_present(&frame.state.catalog, u8(wanted)) {
        return false
    }

    select_profile(self, frame.state.players[seat - 1].profile)
    self.choices[0].abilities[0] = u8(wanted)
    self.local_profile[0].automatic = self.local_profile[0].automatic & ~u8(4)
    self.selected = true
    self.choices[0].ready = false
    declare(self)
    return true
}
