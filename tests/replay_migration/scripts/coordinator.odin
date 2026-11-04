//gd:extends Node
//gd:class ReplayMigrationCoordinator
package replay_migration_fixture

import gd "godot:godot"
import auth "godot:replay/authority"
import db "godot:replay/authority/sqlite"
import tr "godot:replay/transport"
import net "godot:replay/net"
import scrapyard "godot:examples/replay_scrapyard/shared/game"
import cave "godot:examples/replay_cavecrawl/shared/cave"
import cave_owned "godot:examples/replay_cavecrawl/shared/owner_cave"
import slopball3d "godot:examples/replay_slopball3d/shared/pitch"
import slopball "godot:examples/replay_slopball/shared/pitch"
import speedball "godot:examples/replay_speedball/shared/pitch"
import claimball "godot:examples/replay_claimball/shared/pitch"
import quickdraw "godot:examples/replay_quickdraw/shared/duel"
import "core:fmt"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

ReplayMigrationCoordinator :: struct {
    owner:          gd.Node,
    store:          db.Store,
    service:        auth.Service,
    enet:           transportgd.Enet,
    websocket:      transportgd.Websocket,
    wire:           tr.Transport,
    ready:          bool,
    trace_revision: u64,
}

replay_migration_coordinator_ready :: proc(self: ^ReplayMigrationCoordinator) {
    port := gd.env_int("REPLAY_MIGRATION_PORT", 49500)

    if port < 1 || port > 65000 {
        return
    }

    if db.open(&self.store, gd.env_string("REPLAY_MIGRATION_DB", ""), true) != .None {
        return
    }

    game := gd.env_string("REPLAY_MIGRATION_GAME", "cave")
    room, content := u64(44), cave.CONTENT

    if game == "cave-owned" {
        content = cave_owned.CONTENT
    }

    if game == "quickdraw" {
        room, content = 45, quickdraw.CONTENT
    }

    if game == "slopball" {
        room, content = 46, slopball.CONTENT
    }

    if game == "slopball3d" {
        room, content = 47, slopball3d.CONTENT
    }

    if game == "scrapyard" {
        room, content = 48, scrapyard.CONTENT
    }

    if game == "speedball" {
        room, content = 49, speedball.CONTENT
    }

    if game == "claimball" {
        room, content = 50, claimball.CONTENT
    }

    record := auth.record_make(room, content, {1, 101})
    keys: [3]auth.Credential

    for i in 0 ..< 3 {
        identity := auth.Identity{u64(i + 1), u64(i + 101)}
        endpoint, _ := auth.endpoint("127.0.0.1", u16(port + i + 1))
        token := storagegd.session_token(fmt.tprintf("migration-%d", i + 1))
        record.members[i] = {
            identity          = identity,
            endpoint          = endpoint,
            enabled           = true,
            can_host          = i < 2,
            trusted_authority = i < 2,
            game_token_hash   = net.token_hash(token),
        }
        keys[i] = {
            identity = identity,
            key = {0 = u8(21 + i)},
        } // fixture credentials only
    }

    if gd.env_int("REPLAY_CONTROL_WS", 0) == 1 {
        if !transportgd.websocket_host(&self.websocket, u16(port)) {
            return
        }

        self.wire = transportgd.websocket_transport(&self.websocket)
    } else {
        if !transportgd.enet_host(&self.enet, u16(port), 8, bind_ip = "127.0.0.1") {
            return
        }

        self.wire = transportgd.enet_transport(&self.enet)
    }

    if auth.service_init(&self.service, record, db.commit, &self.store, auth.native_clock(), self.wire, keys[:]) !=
       .None {
        return
    }

    self.ready = true
    gd.print_str(fmt.tprintf("REPLAY_MIGRATION_COORDINATOR_READY room=%d content=%x", room, content))
}

replay_migration_coordinator_process :: proc(self: ^ReplayMigrationCoordinator, dt: f64) {
    if !self.ready {
        gd.print_str("REPLAY_MIGRATION_FAIL coordinator setup")
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
        return
    }

    if auth.service_pump(&self.service) != .None {
        gd.print_str("REPLAY_MIGRATION_FAIL coordinator storage")
        gd.scene_tree_quit(gd.get_tree(self.owner), 1)
    }

    if gd.env_int("REPLAY_MIGRATION_TRACE", 0) == 1 &&
       self.trace_revision != self.service.coordinator.record.revision {
        r := self.service.coordinator.record
        self.trace_revision = r.revision
        gd.print_str(
            fmt.tprintf(
                "COORD_TRACE revision=%d epoch=%d tick=%d point=%d/%d owner=%d nominee=%d successor_result=%v",
                r.revision,
                r.epoch,
                r.last_tick,
                r.point.archive.sequence,
                r.point.archive.tick,
                r.owner.member,
                r.nominee.member,
                r.requests[1].result,
            ),
        )
    }
}

replay_migration_coordinator_exit_tree :: proc(self: ^ReplayMigrationCoordinator) {
    auth.service_destroy(&self.service)
    tr.close(&self.wire)
    db.close(&self.store)
}
