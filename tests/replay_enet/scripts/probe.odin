//gd:extends Node
//gd:class ReplayWireProbe
package replay_enet_probe

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import game "godot:examples/replay_hello/shared/hello"
import transportgd "godot:replay/godot/transport"

ReplayWireProbe :: struct {
    owner:                       gd.Node,
    enet:                        transportgd.Enet,
    transport:                   tr.Transport,
    schema:                      sc.Schema,
    server, ready, failed:       bool,
    started, last_send, done_at: u64,
    reliable, unreliable:        bool,
    budget_deferrals:            u32,
    peers:                       [2]tr.Peer_Id,
    acked:                       [2]bool,
}

replay_wire_probe_ready :: proc(self: ^ReplayWireProbe) {
    self.started = u64(gd.time_get_ticks_msec(gd.singleton_time()))
    self.server = gd.env_string("REPLAY_TRANSPORT_ROLE", "client") == "host"
    port := gd.env_int("REPLAY_TRANSPORT_PORT", 49420)

    if port <= 0 || port > 65535 {
        replay_wire_probe_fail(self, "port")
        return
    }

    if report := sc.init(&self.schema, r.Frame(game.World)); report.error != .None {
        replay_wire_probe_fail(self, "schema")
        return
    }

    ok: bool

    if self.server {
        ok = transportgd.enet_host(&self.enet, u16(port), 2, bind_ip = "127.0.0.1")
    } else {
        ok = transportgd.enet_join(&self.enet, "127.0.0.1", u16(port))
    }

    if !ok {
        replay_wire_probe_fail(self, "open")
        return
    }

    self.transport = transportgd.enet_transport(&self.enet)
    self.ready = true

    if self.server {
        gd.print_str("REPLAY_ENET_HOST_READY")
    }
}

replay_wire_probe_process :: proc(self: ^ReplayWireProbe, dt: f64) {
    if !self.ready || self.failed {
        return
    }

    now := u64(gd.time_get_ticks_msec(gd.singleton_time()))

    if now - self.started > 15000 {
        replay_wire_probe_fail(self, "timeout")
        return
    }

    tr.poll(&self.transport)

    if self.done_at != 0 {
        if now >= self.done_at {
            gd.scene_tree_quit(gd.get_tree(self.owner), 0)
        }

        return
    }

    if !self.server && tr.status(&self.transport) == .Connected && now - self.last_send >= 50 {
        if !self.reliable {
            request := [1]u8{1}
            tr.send(&self.transport, 1, .Reliable, request[:])
        }

        if !self.unreliable {
            request := [1]u8{3}
            tr.send(&self.transport, 1, .Unreliable, request[:])
        }

        self.last_send = now
    }

    buffer: [tr.MAX_PACKET_BYTES]u8

    for _ in 0 ..< 64 {
        received := tr.receive(&self.transport, buffer[:1])

        if received.state == .Empty {
            break
        }

        if received.state == .Buffer_Too_Small {
            retained := received
            received = tr.receive(&self.transport, buffer[:])

            if received.state != .Received ||
               received.from != retained.from ||
               received.channel != retained.channel ||
               received.generation != retained.generation ||
               received.count != retained.count {
                replay_wire_probe_fail(self, "retained packet metadata")
                return
            }

            self.budget_deferrals += 1
        }

        if received.state != .Received {
            replay_wire_probe_fail(self, "receive")
            return
        }

        if received.generation == 0 || received.generation != tr.peer_generation(&self.transport, received.from) {
            replay_wire_probe_fail(self, "connection generation")
            return
        }

        if self.server {
            if received.count != 1 || received.from <= 1 {
                replay_wire_probe_fail(self, "sender metadata")
                return
            }

            index := -1

            for peer, i in self.peers {
                if peer == received.from {
                    index = i
                }
            }

            if index < 0 {
                for &peer, i in self.peers {
                    if peer == 0 {
                        peer = received.from
                        index = i
                        break
                    }
                }
            }

            if index < 0 {
                replay_wire_probe_fail(self, "peer limit")
                return
            }

            if self.acked[index] {
                continue
            }

            if buffer[0] == 2 {
                self.acked[index] = true
                continue
            }

            if buffer[0] != 1 && buffer[0] != 3 {
                replay_wire_probe_fail(self, "request")
                return
            }

            frame := r.Frame(game.World) {
                tick  = 10,
                state = game.initial(),
            }
            actor, _ := r.pool_get(&frame.state.actors, frame.state.players[0])
            actor.body.position[0] = 432
            meta := sc.Envelope_Meta {
                kind    = 1,
                epoch   = 1,
                tick    = frame.tick,
                content = 0x48454c4c4f,
            }

            if sc.pack(&self.schema, frame, meta, buffer[:]).error != .None {
                replay_wire_probe_fail(self, "encode")
                return
            }

            if tr.send(
                   &self.transport,
                   received.from,
                   received.channel,
                   buffer[:sc.HEADER_BYTES + self.schema.wire_size],
               ) !=
               .Sent {
                replay_wire_probe_fail(self, "send")
                return
            }
        } else {
            if received.from != 1 {
                replay_wire_probe_fail(self, "authority transport id")
                return
            }

            frame: r.Frame(game.World)
            meta, report := sc.unpack(
                &self.schema,
                &frame,
                buffer[:received.count],
                sc.Envelope_Meta{kind = 1, epoch = 1, content = 0x48454c4c4f},
            )

            if report.error != .None || meta.tick != frame.tick {
                replay_wire_probe_fail(self, "decode")
                return
            }

            actor, ok := r.pool_get(&frame.state.actors, frame.state.players[0])

            if !ok || frame.tick != 10 || actor.body.position[0] != 432 {
                replay_wire_probe_fail(self, "state")
                return
            }

            if received.channel == .Reliable {
                self.reliable = true
            } else {
                self.unreliable = true
            }
        }
    }

    if self.server && self.acked[0] && self.acked[1] {
        gd.print_str("REPLAY_ENET_SERVER_OK")
        self.done_at = now + 250
    }

    if !self.server && self.reliable && self.unreliable {
        if self.budget_deferrals < 2 {
            replay_wire_probe_fail(self, "receive retention not exercised")
            return
        }

        ack := [1]u8{2}
        tr.send(&self.transport, 1, .Reliable, ack[:])
        gd.print_str(
            fmt.tprintf(
                "REPLAY_ENET_CLIENT_OK id=%d retained=%d",
                transportgd.enet_id(&self.enet),
                self.budget_deferrals,
            ),
        )
        self.done_at = now + 500
    }
}

replay_wire_probe_fail :: proc(self: ^ReplayWireProbe, reason: string) {
    self.failed = true
    gd.print_str(fmt.tprintf("REPLAY_ENET_FAIL %s", reason))
    gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}

replay_wire_probe_exit_tree :: proc(self: ^ReplayWireProbe) {
    tr.close(&self.transport)
    sc.destroy(&self.schema)
}
