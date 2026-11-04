//gd:extends Node
//gd:class ReplayAdmissionServer
package admission_server
import "core:fmt"
import gd "godot:godot"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import game "godot:examples/replay_duel/shared/duel"
import transportgd "godot:replay/godot/transport"

ReplayAdmissionServer :: struct {
    owner:    gd.Node,
    registry: adm.Registry,
    socket:   transportgd.Websocket,
    wire:     tr.Transport,
    signal:   rgd.Rendezvous,
    ready:    bool,
}

replay_admission_server_ready :: proc(self: ^ReplayAdmissionServer) {
    port := gd.env_int("RDP_AUTH_PORT", 49760)
    self.registry.match = {
        session = 123,
        content = game.CONTENT,
        epoch = 1,
        members = {0 = 1, 1 = 2},
        count = 2,
    }
    count := gd.env_int("RDP_AUTH_PLAYERS", 2)

    if count < 2 || count > 8 {
        fail(self, "players")
        return
    }

    self.registry.match.count = u8(count)

    for i in 0 ..< int(count) {
        self.registry.match.members[i] = u64(i + 1)
        self.registry.credentials[i] = {
            identity = {u64(i + 1), u64(i + 101)},
            key = {0 = u8(i + 21)},
        }
        self.registry.enabled[i] = true
    }

    if port < 1 || port > 65535 || !transportgd.websocket_host(&self.socket, u16(port)) {
        fail(self, "socket")
        return
    }

    self.wire = transportgd.websocket_transport(&self.socket)
    cfg := rgd.DEFAULT_RENDEZVOUS_CONFIG
    cfg.mesh = true
    cfg.resume_ms = 1000

    if !rgd.rendezvous_provider_init(
        &self.signal,
        rgd.rendezvous_p2p_provider(&self.registry, auth.native_clock()),
        &self.socket,
        cfg,
    ) {
        fail(self, "provider")
        return
    }

    self.ready = true
    code := adm.code(self.registry.match)
    gd.print_str(
        fmt.tprintf(
            "P2P_ADMISSION_SCOPE session=123 content=%d epoch=1 count=%d code=%s",
            game.CONTENT,
            count,
            string(code[:]),
        ),
    )
    gd.print_str("REPLAY_SIGNAL_READY authenticated_p2p")
}

replay_admission_server_process :: proc(self: ^ReplayAdmissionServer, dt: f64) {
    if !self.ready {
        return
    }

    tr.poll(&self.wire)
    buffer: [tr.MAX_PACKET_BYTES]u8

    for _ in 0 ..< 32 {
        message := transportgd.websocket_receive(&self.socket, buffer[:])

        if message.state == .Empty {
            break
        }

        if message.state == .Received && message.text {
            rgd.rendezvous_receive(&self.signal, message.from, buffer[:message.count])
        }
    }

    if rgd.rendezvous_pump(&self.signal) != .None {
        fail(self, "pump")
    }

    done := gd.new_string_odin(gd.env_string("RDP_AUTH_DONE", ""))
    defer gd.free_string(done)

    if gd.file_access_file_exists(done) {
        gd.print_str(
            fmt.tprintf(
                "P2P_ADMISSION_SERVICE_OK admitted=%d rejected=%d relayed=%d",
                self.signal.stats.admitted,
                self.signal.stats.rejected,
                self.signal.stats.relayed,
            ),
        )
        gd.scene_tree_quit(gd.get_tree(self.owner), 0)
    }
}

replay_admission_server_exit_tree :: proc(self: ^ReplayAdmissionServer) {
    rgd.rendezvous_destroy(&self.signal)
    transportgd.websocket_close(&self.socket)
}

fail :: proc(self: ^ReplayAdmissionServer, reason: string) {
    gd.print_str(fmt.tprintf("P2P_ADMISSION_SERVICE_FAIL %s", reason))
    gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}
