//gd:extends Node
//gd:class ReplayWorkbench
package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import rt "godot:runtime"
import rgd "godot:replay/godot"
import game "../shared/game"
import "defs"
import scenegd "godot:replay/godot/scene"

// F6 scene: boots the actual game, waits for normal admission/ready/start, then
// submits recorded development actions. No renderer-only substitute world.
ReplayWorkbench :: struct {
    owner: gd.Node,
    ability: ^gd.Resource `gd:"export,resource=AbilityDef"`,
    cast_on_start: bool `gd:"export"`,
    ability_id: u8,
    ability_pending, cast_sent: bool,
    game_scene: ^gd.Resource `gd:"export,resource=PackedScene"`,
    /// Clear through normal deaths/director transitions; grant shop funds.
    open_shop: bool `gd:"export"`,
    /// Spawn a live Titan; this holds the floor in combat even with open_shop.
    boss: bool `gd:"export"`,
    stormcaller: bool `gd:"export"`,
    /// Refresh rally and chill every two seconds through the status rules.
    statuses: bool `gd:"export"`,
    hurt: bool `gd:"export"`,
    jam: bool `gd:"export"`,
    kegs: gd.Int `gd:"export,range=0:12"`,
    menu: bool `gd:"export"`,
    wipe: bool `gd:"export"`,
    note: bool `gd:"export"`,
    tally: bool `gd:"export"`,
    game: ^ReplayScrapyard,
    ready_sent, start_sent, staged, confirmed, failed: bool,
    st_clock, smite_clock: f64,
    last_sequence: u64,
    environment: [16]Workbench_Environment,
    environment_count: int,
}

Workbench_Environment :: struct {
    key: cstring,
    prior: string,
    present: bool,
}

workbench_environment :: proc(self: ^ReplayWorkbench, key: cstring, value: string) {
    assert(self.environment_count < len(self.environment))
    name := gd.new_string_cstring(key)
    defer gd.free_string(name)
    old := gd.os_get_environment(gd.singleton_os(), name)
    defer gd.free_string(old)
    self.environment[self.environment_count] = {
        key,
        gd.gd_string_to_odin(old, context.allocator),
        gd.os_has_environment(gd.singleton_os(), name),
    }
    self.environment_count += 1
    text := gd.new_string_odin(value)
    defer gd.free_string(text)
    gd.os_set_environment(gd.singleton_os(), name, text)
}

replay_workbench_ready :: proc(self: ^ReplayWorkbench) {
    if self.ability != nil {
        ctx: scenegd.Bake_Context
        id, _ := defs.bake_ability(cast(gd.Resource)self.ability, &ctx, "$workbench.ability")

        if ctx.report.error != .None {
            content_report(&ctx.report)
            self.failed = true
            return
        }

        self.ability_id = id
        path := gd.resource_get_path(cast(gd.Resource)self.ability)
        workbench_environment(self, "RSY_AUTHORING_ABILITY", gd.gd_string_to_odin(path))
        gd.free_string(path)
    } else {
        workbench_environment(self, "RSY_AUTHORING_ABILITY", "")
    }

    workbench_environment(self, "RSY_RECORDING_PATH", "user://workbench.rplrec")
    workbench_environment(self, "RSY_ROLE", "solo")
    workbench_environment(self, "RSY_DEV", "1")
    workbench_environment(self, "RSY_PERSIST", "0")
    workbench_environment(self, "RSY_RESUME", "0")
    workbench_environment(self, "RSY_RUN", "1")
    workbench_environment(self, "RSY_WAVES", "1")
    workbench_environment(self, "RSY_REST", "30")
    workbench_environment(self, "RSY_WAVE_BASE", self.open_shop ? "3" : "6")
    workbench_environment(self, "RSY_WAVE_GROWTH", "0")
    workbench_environment(self, "RSY_BARRELS", "0")
    workbench_environment(self, "RSY_SEED", "1337")
    workbench_environment(self, "RSY_SAVE", "user://workbench-run.replay")
    workbench_environment(self, "RSY_SPRAY", "user://workbench-spray.png")
    workbench_environment(self, "RSY_SPRAY_STORE", "user://workbench-spray.png")

    if self.game_scene == nil {
        self.failed = true
        gd.print_str("RSY_WORKBENCH_FAIL missing game scene")
        return
    }

    node := gd.instantiate(cast(gd.Packed_Scene)self.game_scene)
    gd.add_child(self.owner, node)
    self.game = rt.script_of(node, ReplayScrapyard)

    if self.game == nil {
        self.failed = true
        gd.print_str("RSY_WORKBENCH_FAIL wrong game scene")
        return
    }

    gd.print_str("RSY_WORKBENCH_BOOT")
}

workbench_issued :: proc(self: ^ReplayWorkbench, sequence: gd.Int) {
    if sequence <= 0 {
        self.failed = true
        gd.print_str("RSY_WORKBENCH_FAIL development submission")
        return
    }

    self.last_sequence = u64(sequence)
}

replay_workbench_process :: proc(self: ^ReplayWorkbench, dt: f64) {
    if self.failed || self.game == nil || !self.game.session.ready {
        return
    }

    sy := self.game
    frame, ok := rgd.session_authority_state(sy.session)

    if !ok {
        return
    }

    seat := rgd.session_seat(sy.session)

    if seat == 0 {
        return
    }

    player := frame.state.players[seat - 1]

    if !self.staged {
        if !workbench_enter_yard(self, player) {
            return
        }

        workbench_stage_encounter(self, seat, player)
    }

    if !workbench_confirm_encounter(self, frame.tick) {
        return
    }

    workbench_update_encounter(self, seat, player, frame.state.stage, dt)
}

// The workbench enters through the same equip, ready and start actions as play.
workbench_enter_yard :: proc(self: ^ReplayWorkbench, player: game.Player) -> bool {
    sy := self.game

    if !player.meta_claimed {
        return false
    }

    if self.ability_id != 0 && player.profile.abilities[0] != self.ability_id {
        if !self.ability_pending {
            self.ability_pending = replay_scrapyard_authoring_equip(sy, gd.Int(self.ability_id))

            if !self.ability_pending {
                self.failed = true
            }
        }

        return false
    }

    if !player.profile.ready && !self.ready_sent {
        replay_scrapyard_on_ready(sy)
        self.ready_sent = true
        return false
    }

    if !player.in_yard {
        if player.profile.ready && !self.start_sent {
            replay_scrapyard_on_start(sy)
            self.start_sent = true
        }

        return false
    }

    return true
}

workbench_stage_encounter :: proc(self: ^ReplayWorkbench, seat: u16, player: game.Player) {
    sy := self.game

    if self.stormcaller {
        workbench_issued(self, replay_scrapyard_dev_spawn(sy, 6, gd.Int(seat), 110, 0))
    }

    if self.boss {
        workbench_issued(self, replay_scrapyard_dev_spawn(sy, 4, gd.Int(seat), 260, -40))
    }

    for k in 0 ..< clamp(int(self.kegs), 0, 12) {
        workbench_issued(
            self,
            replay_scrapyard_dev_spawn(sy, 5, gd.Int(seat), gd.Float(120 + k % 4 * 60), gd.Float(-90 + k / 4 * 70)),
        )
    }

    if self.open_shop {
        workbench_issued(self, replay_scrapyard_dev_grant_scrap(sy, gd.Int(seat), 500))
        workbench_issued(self, replay_scrapyard_dev_grant_cores(sy, gd.Int(seat), 20))
    }

    if self.hurt {
        workbench_issued(self, replay_scrapyard_dev_hurt(sy, gd.Int(seat), gd.Int(game.max_health(player.parts) / 2)))
    }

    if self.jam {
        workbench_issued(self, replay_scrapyard_dev_jam(sy, gd.Int(seat)))
    }

    if self.statuses {
        workbench_issued(self, replay_scrapyard_dev_status(sy, gd.Int(seat), 4))
        workbench_issued(self, replay_scrapyard_dev_status(sy, gd.Int(seat), 3))
        self.st_clock = 2
    }

    sy.menu_open, sy.tally_open = self.menu, self.tally

    if self.note {
        flow_note(sy, "A note from the workbench — the yard is running.")
    }

    if self.wipe {
        workbench_issued(self, replay_scrapyard_dev_hurt(sy, gd.Int(seat), 255))
    }

    self.staged = true
    gd.print_str("RSY_WORKBENCH_STAGED")
}

workbench_confirm_encounter :: proc(self: ^ReplayWorkbench, tick: u64) -> bool {
    sy := self.game

    if !self.confirmed {
        if self.last_sequence != 0 && sy.development_result == 0 {
            return false
        }

        if self.last_sequence != 0 && sy.development_result < 0 {
            self.failed = true
            gd.print_str("RSY_WORKBENCH_FAIL authority refused preview")
            return false
        }

        self.confirmed = true
        gd.print_str(fmt.tprintf("RSY_WORKBENCH_CONFIRMED tick=%d", tick))
    }

    return true
}

workbench_update_encounter :: proc(
    self: ^ReplayWorkbench,
    seat: u16,
    player: game.Player,
    stage: game.Stage,
    dt: f64,
) {
    sy := self.game

    if self.cast_on_start && !self.cast_sent && self.confirmed && player.hp > 0 {
        self.cast_sent = replay_scrapyard_dev_cast(
            sy,
            0,
            gd.Float(player.position[0]),
            gd.Float(player.position[1]),
            true,
        )
    }

    self.st_clock -= dt
    self.smite_clock -= dt

    if self.statuses && player.hp > 0 && self.st_clock <= 0 {
        self.st_clock = 2
        workbench_issued(self, replay_scrapyard_dev_status(sy, gd.Int(seat), 4))
        workbench_issued(self, replay_scrapyard_dev_status(sy, gd.Int(seat), 3))
    }

    if self.open_shop && stage == .Yard && self.smite_clock <= 0 {
        self.smite_clock = 0.2
        workbench_issued(self, replay_scrapyard_dev_smite(sy, gd.Int(seat)))
    }
}

@(gd_method)
replay_workbench_game_node :: proc(self: ^ReplayWorkbench) -> gd.Node {
    return self.game != nil ? cast(gd.Node)self.game.owner : nil
}

@(gd_method)
replay_workbench_is_staged :: proc(self: ^ReplayWorkbench) -> bool {
    return self.confirmed && !self.failed
}

replay_workbench_exit_tree :: proc(self: ^ReplayWorkbench) {
    for saved in self.environment[:self.environment_count] {
        key := gd.new_string_cstring(saved.key)
        defer gd.free_string(key)

        if saved.present {
            value := gd.new_string_odin(saved.prior)
            gd.os_set_environment(gd.singleton_os(), key, value)
            gd.free_string(value)
        } else {
            gd.os_unset_environment(gd.singleton_os(), key)
        }

        delete(saved.prior)
    }

    self.environment_count = 0
    self.game = nil
}

@(gd_method)
replay_workbench_export_recording :: proc(self: ^ReplayWorkbench) -> bool {
    if self.game == nil || !self.confirmed {
        return false
    }

    self.game.recording.pending = true
    return true
}

@(gd_method)
replay_workbench_recording_exports :: proc(self: ^ReplayWorkbench) -> gd.Int {
    return self.game == nil ? 0 : gd.Int(self.game.recording.exports)
}
