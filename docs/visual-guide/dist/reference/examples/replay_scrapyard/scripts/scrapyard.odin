//gd:extends Node2D
//gd:class ReplayScrapyard
package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import rt "godot:runtime"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import r "godot:replay"
import net "godot:replay/net"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/game"
import views "views"
import display "../shared/presentation"
import debuggd "godot:replay/godot/debug"
import inputgd "godot:replay/godot/input"
import scenegd "godot:replay/godot/scene"

ReplayScrapyard :: struct {
    owner: gd.Node2d,
    online: Scrap_Online,
    world_node: gd.Node2d `gd:"onready=World"`,
    arena_node: gd.Node2d,
    gate: Gate_Art,
    camera: gd.Camera2d `gd:"onready=Camera"`,
    camera_follow: Camera_Follow,
    follow_label: gd.Label `gd:"onready=UI/Following"`,
    social: [1]Scrap_Social,
    diagnostics: [1]dg.Diagnostics,
    chat_panel: gd.Control `gd:"onready=UI/Chat"`,
    chat_input: gd.Line_Edit `gd:"onready=UI/Chat/Input"`,
    chat_lines: gd.Rich_Text_Label `gd:"onready=UI/Chat/Lines"`,
    chat_notice: gd.Label `gd:"onready=UI/Chat/Notice"`,
    ping_root: gd.Node2d,
    status: gd.Label `gd:"onready=UI/Status"`,
    profile_status: gd.Label `gd:"onready=UI/ProfileStatus"`,
    menu_veil: gd.Color_Rect `gd:"onready=UI/MenuVeil"`,
    menu_input_guard: bool,
    menu_panel: gd.Panel_Container `gd:"onready=UI/Menu"`,
    tally_panel: gd.Panel_Container `gd:"onready=UI/Tally"`,
    tally_cells: [game.SEATS][8]gd.Label,
    hud: ^ReplayScrapyardHud,
    transitions: ^ReplayScrapyardTransitions,
    notice_label: gd.Label `gd:"onready=UI/Notice"`,
    spray_preview: gd.Texture_Rect `gd:"onready=UI/Menu/Scroll/Column/SprayPreview"`,
    menu_open, tally_open: bool,
    notice_until: u64,
    ability_label: gd.Label `gd:"onready=UI/Abilities"`,
    shop: gd.Nine_Patch_Rect `gd:"onready=UI/Shop"`,
    shop_wallet: gd.Label `gd:"onready=UI/Shop/Wallet"`,
    shop_hint: gd.Label `gd:"onready=UI/Shop/CardHint"`,
    shop_cards: [9]gd.Button `gd:"onready=UI/Shop/Card%d"`,
    lobby: gd.Control `gd:"onready=UI/Lobby"`,
    name_edit: gd.Line_Edit `gd:"onready=UI/Lobby/Scroll/Layout/Name"`,
    muster: [1]Muster,
    picked_label: gd.Label `gd:"onready=UI/Lobby/Scroll/Layout/Picked"`,
    session: ^rgd.Session(game.World, game.Control, game.Action, game.Event, game.SEATS),
    standalone: rgd.Session(game.World, game.Control, game.Action, game.Event, game.SEATS),
    room: rgd.Room(game.World, game.Control, game.Action, game.Event, game.SEATS),
    local_profile: [1]Local_Profile,
    recovery_probe: [1]Recovery_Probe,
    assets: [1]rgd.Session_Assets,
    spray_local: [1]Spray_Local,
    spray_dependencies: [1]Spray_Dependencies,
    assets_paused: bool,
    spray_rigs: [game.SEATS]Spray_Rig,
    spray_dialog: gd.File_Dialog,
    saved_run: [1]Saved_Run,
    bench: [1]Bench,
    audio: [1]Audio,
    feedback: [1]Feedback,
    screen_fx: [1]Screen_Fx,
    vignette: gd.Texture_Rect `gd:"onready=ScreenFx/Vignette"`,
    floor_veil: gd.Color_Rect `gd:"onready=ScreenFx/FloorVeil"`,
    settings: [1]Settings,
    resume_requested: bool,
    pending_open: bool,
    pending_role: rgd.Session_Role,
    textures: Textures,
    rigs: [game.SEATS]^views.ScrapRunnerView,
    runner_bindings: [game.SEATS]scenegd.Script_Binding(display.Runner_View, views.ScrapRunnerView),
    combat_bridge: [1]Combat_Bridge,
    turret_bridge: [1]Turret_Bridge,
    turret_intent: [1]net.Action_Intent(game.Action),
    shot_rigs: [game.MAX_SHOTS]gd.Line2d,
    shell_rigs: [game.MAX_SHOTS]gd.Mesh_Instance2d,
    flash_rigs: [game.MAX_FLASHES]gd.Line2d,
    flame_rigs: [2][game.MAX_FLASHES]Flame_Rig,
    arc_rigs: [game.MAX_FLASHES]gd.Mesh_Instance2d,
    lob_rigs: [2][game.MAX_LOBS]Glob_Rig,
    spit_rigs: [game.MAX_SHOTS]Glob_Rig,
    zone_rigs: [game.MAX_ZONES]gd.Mesh_Instance2d,
    disc_rigs: [2][game.MAX_FLASHES]gd.Mesh_Instance2d,
    bot_scene: [1]game.World,
    choices: [1]game.Profile,
    smoothing: [game.SEATS]v.Smoother2,
    buttons: r.Buttons,
    selected, declared, ready, manual, dash_next, arena_built: bool,
    dash_intent: [1]net.Action_Intent(game.Action),
    declare_sequence, ready_sequence: u64,
    ready_wanted, ready_retry: bool,
    manual_move, manual_aim: [2]f32,
    manual_fire, auto_combat, auto_gate, manual_revive: bool,
    development, auto_walk: bool,
    recording: debuggd.Debug_Recording,
    walk_target: [2]f32,
    development_sequence: u64,
    development_result, development_reason: gd.Int,
    shot_effects, shot_cancels: u32,
    last_reset, last_correction: u64,
    built_key: u32,
    dash_effects, dash_cancels: u32,
}

replay_scrapyard_ready :: proc(self: ^ReplayScrapyard) {
    self.development = scrap_int("RSY_DEV", 0) == 1
    self.session = &self.standalone
    bind_gameplay_actions()
    connect_lobby_controls(self)
    name := gd.new_string(scrap_param("RSY_NAME", "runner"))
    gd.line_edit_set_text(self.name_edit, name)
    gd.free_string(name)

    if !initialize_scene_components(self) {
        return
    }

    self.ready = true
    screen_ready(self)
    flow_ready(self)
    muster_ready(self)

    if !audio_ready(self) {
        fail(self, "audio resources")
        return
    }

    settings_ready(self)
    online_ready(self)
    inputgd.bind_key("rsy_save", .F5)
    inputgd.bind_key("rsy_stamp", .G)
    gd.connect_to(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Doors/Resume"), "pressed", self.owner, "on_resume")
    gd.connect_to(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Spray"), "pressed", self.owner, "on_spray_pick")
    role := scrap_param("RSY_ROLE", "")
    self.resume_requested = scrap_int("RSY_RESUME", 0) == 1

    switch role {
    case "solo":
        open(self, .Solo)
    case "host":
        open(self, .Host)
    case "client":
        open(self, .Client)
    case "observer":
        open(self, .Observer)
    case "server":
        open(self, .Server)
    }

    gd.print_str(fmt.tprintf("RSY_PROTOCOL content=%x protocol=%d", game.CONTENT, net.PROTOCOL_VERSION))
    gd.print_str("REPLAY_SCRAPYARD_READY")
}

// Input is captured before advancing the session. Corrections and event changes
// are consumed before painting the resulting predicted/authoritative frames.
replay_scrapyard_process :: proc(self: ^ReplayScrapyard, dt: f64) {
    bench_started := self.bench[0].active ? gd.time_get_ticks_usec(gd.singleton_time()) : u64(0)

    defer if bench_started != 0 {
        bench_note(&self.bench[0], .Frame, gd.time_get_ticks_usec(gd.singleton_time()) - bench_started)
    }

    defer finish_frame(self, dt)

    typing := poll_frame_ui(self)

    if !self.ready || (!self.session.ready && !self.room.ready) {
        return
    }

    poll_frame_services(self, typing)
    control := sample_gameplay_input(self, typing)

    if !advance_gameplay_session(self, dt, control) {
        return
    }

    update_prediction_smoothing(self)
    dispatch_session_changes(self)
    present_session_frame(self, dt)
}

fail :: proc(self: ^ReplayScrapyard, message: string) {
    gd.print_str(fmt.tprintf("REPLAY_SCRAPYARD_FAIL %s", message))
    gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}

replay_scrapyard_exit_tree :: proc(self: ^ReplayScrapyard) {
    debuggd.debug_recording_destroy(&self.recording)
    combat_bridge_close(self)
    turret_bridge_close(self)
    runner_scenes_close(self)
    feedback_close(self)
    dg.destroy(&self.diagnostics[0])
    co.destroy(&self.social[0].comms)
    audio_close(self)
    settings_close(self)
    delete(self.bench[0].samples)
    browser_run_close(&self.saved_run[0])
    spray_close(self)

    if self.room.ready {
        rgd.room_close(&self.room)
    } else {
        rgd.session_close(self.session)
    }

    online_close(self)
    profile_close(&self.local_profile[0])
    textures_destroy(&self.textures)
}
