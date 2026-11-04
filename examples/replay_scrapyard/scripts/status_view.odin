package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import game "../shared/game"
import content "../shared/content"

// Base gameplay status is derived from the world. Local save/recovery notices
// override it afterwards, in the same priority order as the HUD.
gameplay_status :: proc(w: ^game.World, player: game.Player, seat: u16, inside: bool) -> cstring {
    guns := w.catalog.guns
    status := fmt.ctprintf(
        "Observing · floor %d · mobs %d · Enter chat · Tab tally · Esc menu",
        w.floor,
        w.mobs.count,
    )

    if inside && seat > 0 {
        status = fmt.ctprintf(
            "HP %d · %s %d/%d %v · scrap %d · kills %d · WASD / Shift / mouse",
            player.hp,
            content.name_string(&guns[player.in_yard ? player.gun_id : player.profile.iron].name),
            player.gun.ammo,
            guns[player.in_yard ? player.gun_id : player.profile.iron].mechanism.mag,
            player.gun.mode,
            player.scrap,
            player.kills,
        )
    }

    for alive, i in w.mobs.alive {
        if alive && w.mobs.values[i].kind == 4 && w.mobs.values[i].hp > 0 {
            status = fmt.ctprintf("%s | TITAN %d/%d", status, w.mobs.values[i].hp, w.mobs.values[i].max_hp)
            break
        }
    }

    if w.rules.enabled && inside {
        if w.stage == .Clear {
            status =
                seat == 0 ? fmt.ctprintf("Observing · FLOOR %d CLEAR · waiting for the crew to depart", w.floor) : fmt.ctprintf("FLOOR %d CLEAR · shop below · gather alive on the east gate", w.floor)
        }

        if w.stage == .Clear && w.depart.left > 0 {
            status = fmt.ctprintf("%s · departing in %ds", status, (u32(w.depart.left) + game.HZ - 1) / game.HZ)
        } else if w.stage == .Over {
            status = "WIPED · returning to the surface"
        } else if w.stage == .Yard {
            status = fmt.ctprintf(
                "%s | floor %d wave %d/%d%s",
                status,
                w.floor,
                w.director.wave,
                w.wave_count,
                seat == 0 ? "" : " · hold F to revive",
            )
        }
    }

    return status
}

session_status :: proc(self: ^ReplayScrapyard, w: ^game.World, seat: u16, inside: bool, gameplay: cstring) -> cstring {
    status := gameplay

    if !inside && w.stage != .Staging {
        status = "The yard is live — choose a loadout and drop in."
    } else if !inside && seat == 0 && self.session.role == .Observer {
        status = "Observing staging · waiting for players"
    } else if !inside {
        status =
            w.host == 0 ? "Scrapyard staging · ready players start together" : fmt.ctprintf("Scrapyard staging · mark ready · runner %d starts", w.host)
    }

    if gd.time_get_ticks_msec(gd.singleton_time()) < self.saved_run[0].notice_until {
        status = self.saved_run[0].ok ? "Run saved." : "Could not save this run."
    }

    if self.saved_run[0].phase == .Checking || self.saved_run[0].phase == .Writing {
        status = "Saving run…"
    }

    if self.room.ready {
        if self.room.save.phase == .Checking || self.room.save.phase == .Uploading {
            status = "Saving party progress…"
        } else if self.room.save.phase == .Failed || self.room.save.phase == .Interrupted {
            status = "Party save status is uncertain. Try saving again."
        }
    }

    if self.local_profile[0].error {
        status = "Profile save failed — session progress has not been saved"
    }

    return status
}

paint_profile_status :: proc(self: ^ReplayScrapyard) {
    local := &self.local_profile[0]
    profile_notice: cstring = ""

    if local.enabled && local.loaded {
        if local.error {
            profile_notice = "Loadout and upgrades not saved."
        } else if local.writing {
            profile_notice = "Saving loadout and upgrades…"
        } else if local.has_record {
            profile_notice = "Loadout and upgrades saved"
        }
    }

    gd.set_string(self.profile_status, "text", profile_notice)
}
