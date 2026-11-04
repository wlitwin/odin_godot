package replay_scrapyard

import gd "godot:godot"
import rt "godot:runtime"
import dg "godot:replay/telemetry"
import inputgd "godot:replay/godot/input"

bind_gameplay_actions :: proc() {
    if !gd.has_action("rsy_left") {
        inputgd.bind_key("rsy_left", .A)
        inputgd.bind_key("rsy_right", .D)
        inputgd.bind_key("rsy_up", .W)
        inputgd.bind_key("rsy_down", .S)
        inputgd.bind_key("rsy_dash", .Shift)
        inputgd.bind_mouse("rsy_fire", .Left)
        inputgd.bind_key("rsy_cast0", .Q)
        inputgd.bind_key("rsy_cast1", .E)
        inputgd.bind_key("rsy_revive", .F)
        inputgd.bind_key("rsy_turret", .T)
        inputgd.bind_key("rsy_buy1", gd.Key('1'))
        inputgd.bind_key("rsy_buy2", gd.Key('2'))
        inputgd.bind_key("rsy_buy3", gd.Key('3'))
        inputgd.bind_key("rsy_buy4", gd.Key('4'))
        inputgd.bind_key("rsy_buy5", gd.Key('9'))
        inputgd.bind_key("rsy_part0", gd.Key('5'))
        inputgd.bind_key("rsy_part1", gd.Key('6'))
        inputgd.bind_key("rsy_part2", gd.Key('7'))
        inputgd.bind_key("rsy_part3", gd.Key('8'))
    }
}

connect_lobby_controls :: proc(self: ^ReplayScrapyard) {
    buttons := [10]cstring {
        "UI/Lobby/Scroll/Layout/Doors/Solo",
        "UI/Lobby/Scroll/Layout/Doors/Host",
        "UI/Lobby/Scroll/Layout/Doors/Join",
        "UI/Lobby/Scroll/Layout/Doors/Watch",
        "UI/Lobby/Scroll/Layout/Picks/Look",
        "UI/Lobby/Scroll/Layout/Picks/Iron",
        "UI/Lobby/Scroll/Layout/Actions/Ready",
        "UI/Lobby/Scroll/Layout/Actions/Start",
        "UI/Lobby/Scroll/Layout/Abilities/Left",
        "UI/Lobby/Scroll/Layout/Abilities/Right",
    }
    methods := [10]cstring {
        "on_solo",
        "on_host",
        "on_join",
        "on_watch",
        "on_look",
        "on_iron",
        "on_ready",
        "on_start",
        "on_ability0",
        "on_ability1",
    }

    for path, i in buttons {
        gd.connect_to(gd.get_node(self.owner, path), "pressed", self.owner, methods[i])
    }
}

initialize_scene_components :: proc(self: ^ReplayScrapyard) -> bool {
    if !textures_load(&self.textures) {
        fail(self, "textures")
        return false
    }

    if !dg.init(&self.diagnostics[0]) {
        fail(self, "diagnostics")
        return false
    }

    if !social_ready(self) {
        fail(self, "communications")
        return false
    }

    if !feedback_init(self) {
        fail(self, "feedback pool")
        return false
    }

    self.hud = rt.script_of(gd.get_node(self.owner, "UI/CombatHUD"), ReplayScrapyardHud)

    if self.hud == nil {
        fail(self, "combat HUD")
        return false
    }

    self.transitions = rt.script_of(gd.get_node(self.owner, "UI/Transitions"), ReplayScrapyardTransitions)

    if self.transitions == nil {
        fail(self, "transition UI")
        return false
    }

    if !runner_scenes_init(self) {
        fail(self, "runner scene components")
        return false
    }

    if !combat_bridge_init(self) {
        fail(self, "combat bridge")
        return false
    }

    if !turret_bridge_init(self) {
        fail(self, "turret bridge")
        return false
    }

    combat_rigs_make(self)

    if !spray_open(self) {
        fail(self, "asset service")
        return false
    }

    return true
}
