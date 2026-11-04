//gd:extends Node
//gd:class AuthorizedRtcProbe
package web_authority_client

import "core:fmt"
import gd "godot:godot"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import rgd "godot:replay/godot"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

AuthorizedRtcProbe :: struct {
    owner:                                            gd.Node,
    socket:                                           transportgd.Websocket,
    wire:                                             tr.Transport,
    clock:                                            rgd.Browser_Lease_Clock,
    lease:                                            auth.Lease,
    rpc:                                              auth.Rpc_Client,
    authorization:                                    transportgd.Rtc_Grant_Auth,
    rtc, attacker:                                    transportgd.Rtc,
    data:                                             tr.Transport,
    ready, failed, opened, denied, sent, reported:    bool,
    member:                                           int,
    last_rpc, last_reply, started:                    u64,
    received:                                         int,
    heartbeat_at, heartbeats, heartbeats_during_loss: u64,
    buffer:                                           [tr.MAX_PACKET_BYTES]u8,
}

authorized_rtc_probe_ready :: proc(self: ^AuthorizedRtcProbe) {
    member := gd.web_query("member")
    self.member = member == "1" ? 1 : member == "2" ? 2 : member == "3" ? 3 : 4
    identity := auth.Identity{u64(self.member), u64(self.member + 100)}

    if !transportgd.websocket_join(&self.socket, gd.web_query("url")) {
        signal_fail(self, "control socket")
        return
    }

    self.wire = transportgd.websocket_transport(&self.socket)

    if auth.lease_init(&self.lease, identity, 44, 55, rgd.browser_lease_clock(&self.clock), self.member == 1) !=
       .None {
        signal_fail(self, "lease")
        return
    }

    key := auth.Key {
        0 = u8(20 + self.member),
    }

    if !auth.rpc_client_init(&self.rpc, &self.lease, key, auth.Nonce(storagegd.session_token()), self.wire) {
        signal_fail(self, "RPC")
        return
    }

    self.authorization.identity, self.authorization.key = identity, key
    self.ready = true
}

authorized_rtc_probe_process :: proc(self: ^AuthorizedRtcProbe, dt: f64) {
    if !self.ready || self.failed {
        return
    }

    now, ok := self.lease.clock.read(self.lease.clock.user)

    if !ok || now > 90000 {
        signal_fail(self, "clock/timeout")
        return
    }

    if auth.rpc_client_pump(&self.rpc) != .None {
        signal_fail(self, "RPC pump")
        return
    }

    if reply, complete := auth.rpc_completed(&self.rpc); complete && reply.sequence != self.last_reply {
        self.last_reply = reply.sequence

        if reply.result != .None && reply.result != .Busy {
            signal_fail(self, fmt.tprintf("RPC result %v", reply.result))
            return
        }
    }

    if !self.rpc.pending && now - self.last_rpc >= 250 {
        command := auth.Command {
            verb = .Query,
        }

        if self.member == 1 {
            command =
                self.lease.view.epoch == 0 ? auth.Command{verb = .Start} : auth.Command{verb = .Renew, epoch = self.lease.view.epoch, tick = 1}
        }

        if auth.rpc_begin(&self.rpc, command) != .None {
            signal_fail(self, "RPC begin")
            return
        }

        self.last_rpc = now
    }

    if self.lease.view.epoch != 1 || !auth.lease_live(&self.lease, 1) {
        return
    }

    self.authorization.view = self.lease.view

    if self.member == 2 && !self.denied {
        if !self.attacker.ready {
            if !transportgd.rtc_open(
                &self.attacker,
                transportgd.rtc_grant_config(&self.authorization, gd.web_query("url"), true),
            ) {
                signal_fail(self, "attack setup")
                return
            }
        }

        wire := transportgd.rtc_transport(&self.attacker)
        tr.poll(&wire)

        if self.attacker.error == .Authentication {
            self.denied = true
            transportgd.rtc_close(&self.attacker)
            gd.print_str("RZA_NONOWNER_REJECTED")
        } else if self.attacker.error != .None {
            signal_fail(self, "unexpected rejection")
            return
        }

        return
    }

    if !self.opened {
        if !transportgd.rtc_open(
            &self.rtc,
            transportgd.rtc_grant_config(&self.authorization, gd.web_query("url"), self.member == 1),
        ) {
            signal_fail(self, "RTC open")
            return
        }

        self.data = transportgd.rtc_transport(&self.rtc)
        self.opened = true
    }

    tr.poll(&self.data)

    if self.rtc.error != .None {
        signal_fail(self, fmt.tprintf("RTC %v", self.rtc.error))
        return
    }

    if self.member == 1 && self.rtc.registered && !self.reported {
        self.reported = true
        gd.print_str(fmt.tprintf("RZA_ROOM %s", self.rtc.room))
    }

    if self.member != 1 && tr.peer_connected(&self.data, 1) && !self.sent {
        for &byte, i in self.buffer {
            byte = u8((i + self.member) % 251)
        }

        if tr.send(&self.data, 1, .Reliable, self.buffer[:]) != .Sent {
            signal_fail(self, "send")
            return
        }

        self.sent = true
    }

    if self.member != 1 && self.received > 0 && now - self.heartbeat_at >= 50 {
        heartbeat := [3]u8{0xfe, u8(self.member), 1}

        if tr.send(&self.data, 1, .Reliable, heartbeat[:]) != .Sent {
            signal_fail(self, "heartbeat send")
            return
        }

        self.heartbeat_at = now
    }

    for _ in 0 ..< 32 {
        packet := tr.receive(&self.data, self.buffer[:])

        if packet.state == .Empty {
            break
        }

        if packet.state == .Received && packet.count == 3 && self.buffer[0] == 0xfe {
            if self.member == 1 {
                if tr.send(&self.data, packet.from, .Reliable, self.buffer[:3]) != .Sent {
                    signal_fail(self, "heartbeat echo")
                    return
                }
            } else if packet.from != 1 || self.buffer[1] != u8(self.member) {
                signal_fail(self, "heartbeat sender")
                return
            }

            self.heartbeats += 1

            if self.rtc.signaling_lost || self.rtc.reconnecting {
                self.heartbeats_during_loss += 1
            }

            continue
        }

        if packet.state != .Received || packet.count != len(self.buffer) || packet.channel != .Reliable {
            signal_fail(self, "packet")
            return
        }

        if self.member == 1 {
            if tr.send(&self.data, packet.from, .Reliable, self.buffer[:]) != .Sent {
                signal_fail(self, "echo")
                return
            }
        } else {
            if packet.from != 1 {
                signal_fail(self, "authority id")
                return
            }

            for byte, i in self.buffer {
                if byte != u8((i + self.member) % 251) {
                    signal_fail(self, "payload")
                    return
                }
            }
        }

        self.received += 1

        if self.received == (self.member == 1 ? 2 : 1) {
            gd.print_str(fmt.tprintf("RZA_DATA_OK member=%d received=%d", self.member, self.received))
        }
    }
}

authorized_rtc_probe_exit_tree :: proc(self: ^AuthorizedRtcProbe) {
    transportgd.rtc_close(&self.attacker)
    tr.close(&self.data)
    auth.rpc_client_destroy(&self.rpc)
    tr.close(&self.wire)
}

signal_fail :: proc(self: ^AuthorizedRtcProbe, reason: string) {
    self.failed = true
    gd.print_str(fmt.tprintf("RZA_FAIL %s", reason))
}


@(gd_method)
authorized_rtc_probe_drop_signal :: proc(self: ^AuthorizedRtcProbe) {
    transportgd.rtc_drop_signaling(&self.rtc)
}

@(gd_method)
authorized_rtc_probe_stat :: proc(self: ^AuthorizedRtcProbe, field, peer: gd.Int) -> gd.Int {
    switch field {
    case 0:
        return gd.Int(self.rtc.id)
    case 1:
        return gd.Int(self.rtc.signaling_resumes)
    case 2:
        return gd.Int(self.heartbeats)
    case 3:
        return gd.Int(self.heartbeats_during_loss)
    case 4:
        return gd.Int(transportgd.rtc_connection_serial(&self.rtc, tr.Peer_Id(peer)))
    case 5:
        return gd.Int(self.rtc.signaling_lost)
    }

    return 0
}


@(gd_method)
authorized_rtc_probe_hold_signal :: proc(self: ^AuthorizedRtcProbe, hold: bool) {
    self.rtc.config.resume_signaling = !hold

    if hold {
        transportgd.rtc_drop_signaling(&self.rtc)
    }
}
