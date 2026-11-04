package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import rgd "godot:replay/godot"
import game "../shared/game"
import content "../shared/content"
import flow "../shared/flow"
import profile "../shared/profile"

Muster_Row :: struct {
    root: gd.Control,
    body: gd.Sprite2d,
    name, iron, lamp: gd.Label,
}

Muster :: struct {
    rows: [game.SEATS]Muster_Row,
    buttons: [8]gd.Button,
    ready, start: gd.Button,
    starting, scoped: bool,
    epoch, connection: u64,
    generation: u32,
}

muster_ready :: proc(self: ^ReplayScrapyard) {
    m := &self.muster[0]

    for &row, i in m.rows {
        row.root = cast(gd.Control)gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Scroll/Layout/Roster/Row%d", i))
        row.body = cast(gd.Sprite2d)gd.get_node(row.root, "Body")
        row.name = cast(gd.Label)gd.get_node(row.root, "Name")
        row.iron = cast(gd.Label)gd.get_node(row.root, "Iron")
        row.lamp = cast(gd.Label)gd.get_node(row.root, "Lamp")
    }

    paths := [8]cstring {
        "Picks/LookPrev",
        "Picks/Look",
        "Picks/IronPrev",
        "Picks/Iron",
        "Abilities/LeftPrev",
        "Abilities/Left",
        "Abilities/RightPrev",
        "Abilities/Right",
    }

    for path, i in paths {
        m.buttons[i] = cast(gd.Button)gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Scroll/Layout/%s", path))
        gd.base_button_set_disabled(m.buttons[i], true)
    }

    methods := [4]cstring{"on_look_prev", "on_iron_prev", "on_ability0_prev", "on_ability1_prev"}

    for method, i in methods {
        gd.connect_to(m.buttons[i * 2], "pressed", self.owner, method)
    }

    m.ready = cast(gd.Button)gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Actions/Ready")
    m.start = cast(gd.Button)gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Actions/Start")
    gd.base_button_set_disabled(m.ready, true)
    gd.base_button_set_disabled(m.start, true)

    for section in ([5]cstring{"Roster", "Picks", "Abilities", "Picked", "Actions"}) {
        gd.canvas_item_set_visible(gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Scroll/Layout/%s", section)), false)
    }
}

// A restored/rejoined player gets the confirmed staging baseline. Optimistic
// choices from an earlier connection must not turn a new Ready click into Unready.
muster_scope :: proc(self: ^ReplayScrapyard, world: ^game.World, seat: u16) {
    if seat == 0 {
        return
    }

    m := &self.muster[0]

    if !m.scoped && !world.players[seat - 1].meta_claimed {
        return
    }

    epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
    connection := self.session.authority ? u64(0) : self.session.client.generation
    generation := world.players[seat - 1].generation

    if m.scoped && (m.epoch != epoch || m.connection != connection || m.generation != generation) {
        // Admission can replace the player generation in the same tick that accepts
        // its profile. Recognize that confirmation before rebasing the UI mode.
        local := &self.local_profile[0]
        wanted, valid := profile.resolve(self.choices[0], local.automatic, seat, &world.catalog)

        if world.players[seat - 1].meta_claimed &&
           valid &&
           profile.matching_choices(wanted, world.players[seat - 1].profile) {
            local.confirmed_automatic = local.automatic
        }

        if scrap_int("RSY_TRACE", 0) == 1 {
            gd.print_str(
                fmt.tprintf(
                    "RSY_AUTO_SCOPE epoch=%d->%d mode=%d confirmed=%d q=%d",
                    m.epoch,
                    epoch,
                    self.local_profile[0].automatic,
                    self.local_profile[0].confirmed_automatic,
                    world.players[seat - 1].profile.abilities[0],
                ),
            )
        }

        self.choices[0] = world.players[seat - 1].profile
        self.selected = true
        self.local_profile[0].automatic = self.local_profile[0].confirmed_automatic
        self.ready_retry = false
        self.ready_sequence = 0
        m.starting = false
    }

    m.scoped, m.epoch, m.connection, m.generation = true, epoch, connection, generation
}

muster_choose :: proc(self: ^ReplayScrapyard, field, direction: int) {
    if self.menu_open || !self.session.ready || self.session.fenced {
        return
    }

    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 || frame.state.players[seat - 1].in_yard {
        return
    }

    muster_scope(self, &frame.state, seat)
    select_profile(self, frame.state.players[seat - 1].profile)
    choice, mask := flow.muster_pick(
        &frame.state.catalog,
        self.choices[0],
        field,
        direction,
        self.local_profile[0].automatic,
    )
    resolved, valid := profile.resolve(choice, mask, seat, &frame.state.catalog)

    if !valid {
        return
    }

    self.choices[0], self.local_profile[0].automatic = resolved, mask
    self.selected = true
    self.ready_wanted = false
    self.ready_retry = false
    self.ready_sequence = 0
    self.muster[0].starting = false
    declare(self)
}

@(gd_method)
replay_scrapyard_on_look_prev :: proc(self: ^ReplayScrapyard) {
    muster_choose(self, 0, -1)
}

@(gd_method)
replay_scrapyard_on_iron_prev :: proc(self: ^ReplayScrapyard) {
    muster_choose(self, 1, -1)
}

@(gd_method)
replay_scrapyard_on_ability0_prev :: proc(self: ^ReplayScrapyard) {
    muster_choose(self, 2, -1)
}

@(gd_method)
replay_scrapyard_on_ability1_prev :: proc(self: ^ReplayScrapyard) {
    muster_choose(self, 3, -1)
}

muster_set_ready :: proc(self: ^ReplayScrapyard, wanted: bool) {
    if self.menu_open || !self.session.ready || self.session.fenced {
        return
    }

    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 {
        return
    }

    muster_scope(self, &frame.state, seat)
    select_profile(self, frame.state.players[seat - 1].profile)
    self.ready_wanted = wanted
    self.choices[0].ready = wanted
    declare(self)
    sequence, err := issue_action(self, {kind = .Ready, ready = wanted})

    if err == .None {
        self.ready_sequence = sequence
        self.ready_retry = false
    } else {
        self.ready_retry = true
    }
}

muster_start :: proc(self: ^ReplayScrapyard) {
    if self.menu_open || !self.session.ready || self.session.fenced {
        return
    }

    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || !flow.muster_can_start(&frame.state, seat) {
        return
    }

    muster_scope(self, &frame.state, seat)

    if frame.state.players[seat - 1].profile.ready {
        issue(self, {kind = .Start})
        return
    }

    self.muster[0].starting = true
    muster_set_ready(self, true)
}

muster_pending :: proc(self: ^ReplayScrapyard, world: ^game.World) {
    m := &self.muster[0]
    seat := rgd.session_seat(self.session)
    muster_scope(self, world, seat)

    if !m.starting {
        return
    }

    if !flow.muster_can_start(world, seat) {
        m.starting = false
        return
    }

    if game.all_ready(world) && issue(self, {kind = .Start}) {
        m.starting = false
    }
}

muster_paint :: proc(self: ^ReplayScrapyard, world: ^game.World, seat: u16, inside: bool) {
    if inside {
        return
    }

    m := &self.muster[0]
    pickable := seat > 0 && world.players[seat - 1].connected && !world.players[seat - 1].in_yard

    if pickable {
        muster_scope(self, world, seat)
        select_profile(self, world.players[seat - 1].profile)
    }

    muster_paint_sections(self, pickable)
    muster_paint_roster(self, world, seat)
    muster_paint_actions(self, world, seat, pickable)

    if pickable {
        muster_paint_choices(self, world)
    }

    message: cstring =
        seat == 0 ? "Watching the muster — the keeper starts the yard." : world.stage != .Staging ? "The yard is live — pick your kit, then drop in." : seat == world.host ? "START when your crew is ready — it readies you too." : "Pick your kit — the keeper starts the drop."

    if m.starting {
        message = "Readying your kit before the drop…"
    }

    gd.set_string(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Note"), "text", message)
}

muster_paint_sections :: proc(self: ^ReplayScrapyard, pickable: bool) {
    gd.set_string(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Title"), "text", "T H E   M U S T E R")
    gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Name"), false)
    gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Doors"), false)
    gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Roster"), true)

    for section in ([4]cstring{"Picks", "Abilities", "Picked", "Actions"}) {
        gd.canvas_item_set_visible(
            gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Scroll/Layout/%s", section)),
            pickable,
        )
    }
}

muster_paint_roster :: proc(self: ^ReplayScrapyard, world: ^game.World, seat: u16) {
    m := &self.muster[0]

    for row, i in m.rows {
        player := world.players[i]
        gd.canvas_item_set_visible(row.root, player.connected)

        if !player.connected {
            continue
        }

        mine := seat == u16(i + 1)
        claim := mine && !player.in_yard ? self.choices[0] : player.profile
        gd.sprite2d_set_texture(row.body, self.textures.idle[claim.look])
        gd.sprite2d_set_frame(row.body, 0)
        gd.set_string(
            row.name,
            "text",
            fmt.ctprintf("%s%s", game.name_string(&player.profile.name), mine ? "  (you)" : ""),
        )
        iron := player.in_yard ? player.gun_id : claim.iron
        first := claim.abilities[0] == 0 ? u8(1) : claim.abilities[0]
        second := claim.abilities[1] == 0 ? u8(2) : claim.abilities[1]
        gd.set_string(
            row.iron,
            "text",
            fmt.ctprintf(
                "%s · %s / %s",
                content.name_string(&world.catalog.guns[iron].name),
                content.name_string(&world.catalog.abilities[first].name),
                content.name_string(&world.catalog.abilities[second].name),
            ),
        )
        gd.set_string(row.lamp, "text", player.in_yard ? "IN THE YARD" : claim.ready ? "READY" : "...")
        gd.canvas_item_set_modulate(
            row.lamp,
            player.in_yard ? gd.Color{0.6, 0.65, 0.75, 0.8} : claim.ready ? gd.Color{0.5, 1, 0.5, 1} : gd.Color{0.7, 0.7, 0.7, 0.6},
        )
        gd.canvas_item_set_modulate(
            row.root,
            player.in_yard && !mine ? gd.Color{0.55, 0.58, 0.66, 0.7} : gd.Color{1, 1, 1, 1},
        )
    }
}

muster_paint_actions :: proc(self: ^ReplayScrapyard, world: ^game.World, seat: u16, pickable: bool) {
    m := &self.muster[0]

    for button in m.buttons {
        gd.base_button_set_disabled(button, !pickable || self.menu_open || self.session.fenced || m.starting)
    }

    gd.base_button_set_disabled(m.ready, !pickable || self.menu_open || self.session.fenced || m.starting)
    gd.canvas_item_set_visible(m.start, pickable && seat == world.host && world.stage == .Staging)
    gd.base_button_set_disabled(
        m.start,
        !flow.muster_can_start(world, seat) || self.menu_open || self.session.fenced || m.starting,
    )
}

muster_paint_choices :: proc(self: ^ReplayScrapyard, world: ^game.World) {
    m := &self.muster[0]
    picks := self.choices[0]
    left := picks.abilities[0] == 0 ? u8(1) : picks.abilities[0]
    right := picks.abilities[1] == 0 ? u8(2) : picks.abilities[1]
    mask := self.local_profile[0].automatic
    skin := mask & 1 != 0 ? fmt.tprintf("By seat: skin %d", picks.look) : fmt.tprintf("Skin %d", picks.look)
    iron := content.name_string(&world.catalog.guns[picks.iron].name)
    q := content.name_string(&world.catalog.abilities[left].name)
    e := content.name_string(&world.catalog.abilities[right].name)
    gd.set_string(
        self.picked_label,
        "text",
        fmt.ctprintf(
            "%s · %s%s\nQ: %s%s · E: %s%s",
            skin,
            mask & 2 != 0 ? "By seat: " : "",
            iron,
            mask & 4 != 0 ? "Auto: " : "",
            q,
            mask & 8 != 0 ? "Auto: " : "",
            e,
        ),
    )
    gd.set_string(
        m.ready,
        "text",
        world.stage != .Staging ? (picks.ready ? "DROPPING..." : "DROP IN") : (picks.ready ? "UNREADY" : "READY"),
    )
}
