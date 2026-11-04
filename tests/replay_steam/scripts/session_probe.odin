//gd:extends Node
//gd:class SteamSessionProbe
package steam_probe
import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import net "godot:replay/net"
import r "godot:replay"
import v "godot:replay/view"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

Test_World :: struct {
    present: u8,
    chest:   u16,
    bags:    [2]u16,
}

Test_Control :: struct {
    unused: bool,
}

Test_Action :: struct {
    take: bool,
}

Test_Event :: struct {
    seat:   u16,
    amount: u16,
}

SteamSessionProbe :: struct {
    owner:                 gd.Node,
    runtime:               transportgd.Steam_Runtime,
    session:               rgd.Session(Test_World, Test_Control, Test_Action, Test_Event, 2),
    role:                  string,
    started, completed_at: u64,
    issued, done, live:    bool,
}

steam_session_probe_ready :: proc(self: ^SteamSessionProbe) {
    self.role = strings.clone(gd.env_string("STEAM_TEST_ROLE", "host"))
    self.live = gd.env_int("STEAM_LIVE", 0) == 1
    peer: gd.Variant
    defer gd.variant_destroy(&peer)

    if self.live {
        app := gd.env_int("STEAM_APP_ID", 0)

        if app < 1 || u64(app) > u64(max(u32)) || transportgd.steam_runtime_init(&self.runtime, u32(app)) != .None {
            session_fail(self, "Steam initialization")
            return
        }

        gd.print_str(fmt.tprintf("REPLAY_STEAM_LIVE_ID %d", self.runtime.steam_id))
    } else {
        fake := cast(gd.Object)gd.get_node(self.owner, "FakeSteam")

        if transportgd.steam_runtime_initialize(&self.runtime, fake, 480) != .None {
            session_fail(self, "runtime")
            return
        }

        method := gd.new_string_name("new_peer")
        defer gd.free_string_name(method)
        peer = gd.object_call(fake, method)
    }

    options := rgd.SESSION_OPTIONS
    options.role = self.role == "host" ? .Host : .Client
    options.backend = .Steam
    options.steam = transportgd.STEAM_CONFIG
    options.steam.runtime = &self.runtime

    if !self.live {
        options.steam.peer = cast(gd.Multiplayer_Peer)gd.variant_to_object(&peer)
    }

    options.steam.host_steam_id = 76561198000000001

    if self.live && self.role != "host" {
        id, ok := transportgd.steam_parse_id(gd.env_string("STEAM_HOST_ID", ""))

        if !ok || id == 0 {
            session_fail(self, "host Steam ID")
            return
        }

        options.steam.host_steam_id = id
    }

    options.steam.virtual_port = u16(gd.env_int("STEAM_TEST_PORT", 49499))
    options.token = storagegd.session_token(self.role)
    options.network.content = 0x535445414d31
    options.latency_ms = 120
    model := net.Model(Test_World, Test_Control, Test_Action, Test_Event, 2) {
        state_valid = proc(w: Test_World) -> bool {
            return w.chest + w.bags[0] + w.bags[1] == 5
        },
        control_valid = proc(_: Test_Control) -> bool {
            return true
        },
        action_valid = proc(a: Test_Action) -> bool {
            return a.take
        },
        hold = proc(c: Test_Control) -> Test_Control {
            return c
        },
        step = proc(w: ^Test_World, _: [2]Test_Control, joins, leaves: u64, _: ^r.Step(Test_Event)) {
            w.present = (w.present & ~u8(leaves)) | u8(joins)
        },
        action = proc(w: ^Test_World, seat: u16, a: Test_Action, ctx: ^r.Step(Test_Event)) -> bool {
            if !a.take || w.chest == 0 {
                return false
            }

            amount := w.chest
            w.bags[seat - 1] += amount
            w.chest = 0
            r.emit(ctx, u64(seat), 1, Test_Event{seat, amount})
            return true
        },
    }

    if err := rgd.session_open(&self.session, r.Frame(Test_World){state = {chest = 5}}, model, options); err != .None {
        session_fail(self, fmt.ctprintf("open %v", err))
        return
    }

    self.started = gd.time_get_ticks_msec(gd.singleton_time())
}

session_fail :: proc(self: ^SteamSessionProbe, text: cstring) {
    gd.print_str(fmt.tprintf("REPLAY_STEAM_SESSION_FAIL role=%s %s", self.role, text))
    self.done = true
    gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}

steam_session_probe_process :: proc(self: ^SteamSessionProbe, dt: f64) {
    if self.done {
        return
    }

    elapsed := gd.time_get_ticks_msec(gd.singleton_time()) - self.started

    if elapsed > (self.live ? 120000 : 12000) {
        session_fail(self, "timeout")
        return
    }

    if err := rgd.session_frame(&self.session, dt, Test_Control{}); err != .None {
        session_fail(self, "frame")
        return
    }

    changes: [512]v.Change(net.Net_Event(Test_Event))
    rgd.session_changes(&self.session, changes[:])
    frame, ok := rgd.session_authority_state(&self.session)

    if !ok {
        return
    }

    if self.role == "client" && frame.state.present == 3 && !self.issued {
        _, err := rgd.session_issue(&self.session, Test_Action{take = true})
        self.issued = err == .None
    }

    if frame.state.chest == 0 && frame.state.bags[1] == 5 {
        if self.completed_at == 0 {
            self.completed_at = elapsed
        }

        if elapsed - self.completed_at < (self.role == "host" ? 1500 : 200) {
            return
        }

        if self.role == "host" {
            cp: net.Checkpoint(Test_World, Test_Control, Test_Action, 2)
            defer net.checkpoint_destroy(&cp)

            if net.checkpoint_capture(&self.session.server, &cp) != .None || cp.frame.state.bags[1] != 5 {
                session_fail(self, "archive")
                return
            }
        }

        gd.print_str(
            fmt.tprintf(
                "%s role=%s retained=5",
                self.live ? "REPLAY_STEAM_LIVE_OK" : "REPLAY_STEAM_SESSION_OK",
                self.role,
            ),
        )
        self.done = true
        gd.scene_tree_quit(gd.get_tree(self.owner), 0)
    }
}

steam_session_probe_exit_tree :: proc(self: ^SteamSessionProbe) {
    rgd.session_close(&self.session)
    transportgd.steam_runtime_release(&self.runtime)
    delete(self.role)
}
