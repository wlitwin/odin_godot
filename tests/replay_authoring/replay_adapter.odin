package replay_scrapyard

import gd "godot:godot"
import rgd "godot:replay/godot"

// Read-only observations and existing development/input drivers. No feature law.
@(gd_method)
replay_scrapyard_authoring_probe :: proc(self: ^ReplayScrapyard, key: string, seat: gd.Int) -> gd.Int {
    if key == "seat" {
        return gd.Int(rgd.session_seat(self.session))
    }

    frame, ok := rgd.session_authority_state(self.session)

    if key == "ready" {
        return gd.Int(ok && frame.state.stage != .Staging)
    }

    if key == "players" {
        n := 0

        for p in frame.state.players {
            if p.connected {
                n += 1
            }
        }

        return gd.Int(n)
    }

    if key == "stage" {
        return ok ? gd.Int(frame.state.stage) : -1
    }

    if seat < 1 || seat > 3 || !ok {
        return -1
    }

    player := frame.state.players[seat - 1]

    switch key {
    case "cash":
        return gd.Int(player.scrap)
    case "hp":
        return gd.Int(player.hp)
    case "x":
        return gd.Int(player.position[0])
    case "y":
        return gd.Int(player.position[1])
    case "marked_ready":
        return gd.Int(player.profile.ready)
    }

    return -1
}

@(gd_method)
replay_scrapyard_authoring_hold :: proc(self: ^ReplayScrapyard, held: bool) {
    replay_scrapyard_dev_revive(self, held)
}

@(gd_method)
replay_scrapyard_authoring_grant :: proc(self: ^ReplayScrapyard, seat, amount: gd.Int) -> bool {
    return replay_scrapyard_dev_grant_scrap(self, seat, amount) > 0
}

@(gd_method)
replay_scrapyard_authoring_down :: proc(self: ^ReplayScrapyard, seat: gd.Int) -> bool {
    return replay_scrapyard_dev_hurt(self, seat, 255) > 0
}

@(gd_method)
replay_scrapyard_authoring_prompt :: proc(self: ^ReplayScrapyard) -> string {
    value := gd.label_get_text(cast(gd.Label)gd.get_node(self.owner, "UI/CombatHUD/Prompt"))
    defer gd.free_string(value)
    return gd.gd_string_to_odin(value)
}
