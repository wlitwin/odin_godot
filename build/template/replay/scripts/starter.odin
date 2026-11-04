//gd:extends Node2D
//gd:class ReplayStarter
package scripts

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/game"

ReplayStarter :: struct {
    owner:   gd.Node2d,
    status:  gd.Label `gd:"onready=Status"`,
    players: [game.SEATS]gd.Node2d,
    coin:    gd.Node2d `gd:"onready=Coin"`,
    session: rgd.Session(game.World, game.Control, game.Action, game.Event, game.SEATS),
    ready:   bool,
    drive:   i8,
    manual:  bool,
}

replay_starter_ready :: proc(self: ^ReplayStarter) {
    for &player, i in self.players {
        player = cast(gd.Node2d)gd.get_node(self.owner, fmt.ctprintf("Player%d", i + 1))
    }

    options := rgd.SESSION_OPTIONS
    role := gd.env_string("REPLAY_STARTER_ROLE", "solo")

    switch role {
    case "solo":
        options.role = .Solo
    case "host":
        options.role = .Host
    case "client":
        options.role = .Client
    case "observer":
        options.role = .Observer
    case:
        return
    }

    port := gd.env_int("REPLAY_STARTER_PORT", 49480)

    if port < 1 || port > 65535 {
        return
    }

    options.port = u16(port)
    options.network.content = game.CONTENT
    options.address = fmt.ctprintf("%s", gd.env_string("REPLAY_STARTER_ADDRESS", "127.0.0.1"))

    if error := rgd.session_open(&self.session, r.Frame(game.World){state = game.initial()}, game.model(), options);
       error != .None {
        gd.print_str(fmt.tprintf("REPLAY_STARTER_ERROR %v", error))
        return
    }

    self.ready = true
}

replay_starter_process :: proc(self: ^ReplayStarter, dt: f64) {
    if !self.ready {
        return
    }

    control := game.Control {
        move = self.drive,
    }

    if !self.manual {
        control.move = (gd.is_action_pressed("ui_right") ? i8(1) : 0) - (gd.is_action_pressed("ui_left") ? i8(1) : 0)
    }

    if gd.is_action_just_pressed("ui_accept") {
        replay_starter_take(self)
    }

    if error := rgd.session_frame(&self.session, dt, control); error != .None {
        gd.print_str(fmt.tprintf("REPLAY_STARTER_ERROR %v", error))
        return
    }

    // Consume presentation changes once per render frame. A larger game maps
    // semantic event IDs to effects; replay does not directly play engine audio.
    changes: [64]v.Change(net.Net_Event(game.Event))

    for rgd.session_changes(&self.session, changes[:]) > 0 {}

    frame, available := rgd.session_state(&self.session)

    if !available {
        gd.set_string(self.status, "text", "Connecting…")
        return
    }

    for node, i in self.players {
        gd.canvas_item_set_visible(node, frame.state.connected & (u8(1) << uint(i)) != 0)
        gd.node2d_set_position(node, {f32(frame.state.positions[i]), 180})
    }

    gd.canvas_item_set_visible(self.coin, frame.state.coins != 0)
    gd.set_string(
        self.status,
        "text",
        fmt.ctprintf(
            "REPLAY STARTER · seat %d · bags %d / %d\nArrows move · Space takes the coin near the center",
            rgd.session_seat(&self.session),
            frame.state.bags[0],
            frame.state.bags[1],
        ),
    )
}

replay_starter_exit_tree :: proc(self: ^ReplayStarter) {
    rgd.session_close(&self.session)
}

@(gd_method)
replay_starter_move :: proc(self: ^ReplayStarter, direction: gd.Int) {
    self.manual = true
    self.drive = i8(clamp(direction, -1, 1))
}

@(gd_method)
replay_starter_take :: proc(self: ^ReplayStarter) {
    if self.ready {
        rgd.session_issue(&self.session, game.Action{take = true})
    }
}

@(gd_method)
replay_starter_probe :: proc(self: ^ReplayStarter, key: string) -> gd.Int {
    frame, ok := rgd.session_authority_state(&self.session)

    if key == "ready" {
        return gd.Int(ok)
    }

    if !ok {
        return -1
    }

    seat := rgd.session_seat(&self.session)

    switch key {
    case "seat":
        return gd.Int(seat)
    case "coin":
        return gd.Int(frame.state.coins)
    case "bag1":
        return gd.Int(frame.state.bags[0])
    case "bag2":
        return gd.Int(frame.state.bags[1])
    case "x":
        return seat == 0 ? -1 : gd.Int(frame.state.positions[seat - 1])
    case "tick":
        return gd.Int(frame.tick)
    }

    return -1
}
