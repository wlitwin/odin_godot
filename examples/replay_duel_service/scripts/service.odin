//gd:extends Node
//gd:class ReplayDuelService
package replay_duel_service

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import pp "godot:replay/p2p/provision"
import db "godot:replay/p2p/provision/sqlite"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import game "godot:examples/replay_duel/shared/duel"
import transportgd "godot:replay/godot/transport"

ReplayDuelService :: struct {
    owner:     gd.Node,
    ready:     bool,
    tls:       gd.Tls_Options,
    store:     db.Store,
    socket:    transportgd.Websocket,
    wire:      tr.Transport,
    rooms:     pp.Hub,
    pairs:     pp.Pair_Service,
    signaling: rgd.P2P_Rendezvous_Hub,
}

replay_duel_service_ready :: proc(self: ^ReplayDuelService) {
    port := gd.env_int("DUEL_SERVICE_PORT", 9081)
    local := gd.env_int("DUEL_SERVICE_LOCAL", 0) == 1
    address := gd.env_string("DUEL_SERVICE_BIND", "127.0.0.1")

    if port < 1 || port > 65535 || (local && address != "127.0.0.1" && address != "::1") {
        fail(self, "invalid bind configuration")
        return
    }

    if !local {
        certificate := gd.new_x509_certificate()
        gd.ref_counted_init_ref(certificate)
        defer unref(certificate)
        key := gd.new_crypto_key()
        gd.ref_counted_init_ref(key)
        defer unref(key)
        cert_path := gd.new_string_odin(gd.env_string("DUEL_SERVICE_CERT", ""))
        defer gd.free_string(cert_path)
        key_path := gd.new_string_odin(gd.env_string("DUEL_SERVICE_KEY", ""))
        defer gd.free_string(key_path)

        if gd.x509_certificate_load(certificate, cert_path) != .Ok || gd.crypto_key_load(key, key_path, false) != .Ok {
            fail(self, "TLS certificate/key")
            return
        }

        self.tls = gd.tls_options_server(key, certificate)

        if self.tls == nil {
            fail(self, "TLS options")
            return
        }
    }

    path := gd.env_string("DUEL_SERVICE_DB", "")

    if db.open(&self.store, path, gd.env_int("DUEL_SERVICE_CREATE", 0) == 1) != .None {
        fail(self, "private room database")
        return
    }

    existing: [pp.MAX_ROOMS]pp.Bundle
    count, error := db.load_all(&self.store, game.CONTENT, existing[:])

    if error != .None {
        fail(self, "room inventory")
        return
    }

    socket_cfg := transportgd.DEFAULT_WEBSOCKET_CONFIG
    socket_cfg.peers = 128

    if !transportgd.websocket_host(&self.socket, u16(port), bind_ip = address, cfg = socket_cfg, tls = self.tls) {
        fail(self, "listen")
        return
    }

    self.wire = transportgd.websocket_transport(&self.socket)
    cfg := pp.HUB_CONFIG
    cfg.content, cfg.players, cfg.rooms = game.CONTENT, 2, pp.MAX_ROOMS

    if pp.hub_open(&self.rooms, cfg, existing[:count], db.commit, &self.store, auth.native_clock(), self.wire) !=
       .None {
        fail(self, "room service")
        return
    }

    if !pp.pair_service_open(&self.pairs, &self.rooms) {
        fail(self, "pair service")
        return
    }

    if !rgd.p2p_rendezvous_hub_init(&self.signaling, &self.rooms, &self.socket) {
        fail(self, "signaling service")
        return
    }

    self.ready = true
    gd.print_str(fmt.tprintf("REPLAY_DUEL_SERVICE_READY port=%d rooms=%d tls=%t", port, count, !local))
}

replay_duel_service_process :: proc(self: ^ReplayDuelService, dt: f64) {
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

        if message.state != .Received {
            continue
        }

        if message.text {
            rgd.p2p_rendezvous_hub_receive(&self.signaling, message.from, buffer[:message.count])
        } else if !pp.hub_receive(&self.rooms, message.from, buffer[:message.count]) &&
           !pp.hub_control_receive(&self.rooms, message.from, buffer[:message.count]) {
            pp.pair_service_receive(&self.pairs, message.from, buffer[:message.count])
        }
    }

    rgd.p2p_rendezvous_hub_pump(&self.signaling)
    stop := gd.env_string("DUEL_SERVICE_STOP_FILE", "")

    if stop != "" {
        path := gd.new_string_odin(stop)
        defer gd.free_string(path)

        if gd.file_access_file_exists(path) {
            gd.print_str("REPLAY_DUEL_SERVICE_STOPPED")
            gd.scene_tree_quit(gd.get_tree(self.owner), 0)
        }
    }
}

replay_duel_service_exit_tree :: proc(self: ^ReplayDuelService) {
    rgd.p2p_rendezvous_hub_destroy(&self.signaling)
    pp.pair_service_close(&self.pairs)
    pp.hub_close(&self.rooms)
    transportgd.websocket_close(&self.socket)
    db.close(&self.store)
    unref(self.tls)
}

unref :: proc(o: gd.Ref_Counted) {
    if o != nil && gd.ref_counted_unreference(o) {
        gdext.object_destroy(o)
    }
}

fail :: proc(self: ^ReplayDuelService, message: string) {
    gd.print_str(fmt.tprintf("REPLAY_DUEL_SERVICE_FAIL %s", message))
    self.ready = false
    gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}
