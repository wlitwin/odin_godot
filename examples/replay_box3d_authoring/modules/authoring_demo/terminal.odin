package replay_authoring_demo

import bd "godot:box3d/diagnostics"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"

put64 :: proc(dst: []u8, value: u64) {
    for i in 0 ..< 8 {
        dst[i] = u8(value >> uint(i * 8))
    }
}

get64 :: proc(src: []u8) -> u64 {
    value: u64

    for i in 0 ..< 8 {
        value |= u64(src[i]) << uint(i * 8)
    }

    return value
}

terminal_send :: proc(self: ^ReplayAuthoringDemo, wire: ^tr.Transport, peer: tr.Peer_Id, kind: u8) {
    bytes: [512]u8
    copy(bytes[:8], "RB3TAIL1")
    bytes[8] = kind
    s := &self.state.session
    epoch := self.hosting ? s.server.cfg.epoch : s.client.cfg.epoch
    put64(bytes[16:24], epoch)
    put64(bytes[24:32], self.target)

    if kind == 4 {
        copy(bytes[32:48], s.token[:])
    } else if self.have_final && kind != 5 {
        _, error := bd.signature_encode(self.final_signature, bytes[32:])

        if error != .None {
            error_set(self, "terminal.signature.encode")
            return
        }
    }

    result := tr.send(wire, peer, .Reliable, bytes[:])

    if result != .Sent && result != .Backpressure && result != .Disconnected {
        error_set(self, "terminal.application.send")
    }
}

// The existing Replay application lane carries only startup/terminal metadata.
// Framework Hello/Welcome/facts/ACK, admission and complete physics are untouched.
terminal :: proc(self: ^ReplayAuthoringDemo) {
    s := &self.state.session
    wire := rec.link_application_transport(rgd.session_link(s))
    self.tail_frames += 1
    bytes: [512]u8

    for _ in 0 ..< 16 {
        packet := tr.receive(&wire, bytes[:])

        if packet.state != .Received {
            break
        }

        if packet.count != len(bytes) || string(bytes[:8]) != "RB3TAIL1" {
            continue
        }

        if get64(bytes[24:32]) != self.target {
            error_set(self, "terminal.target mismatch")
            return
        }

        epoch := self.hosting ? s.server.cfg.epoch : s.client.cfg.epoch

        if get64(bytes[16:24]) != epoch {
            continue
        }

        index := -1

        if self.hosting {
            for peer, i in s.server.peers {
                if !peer.local && !peer.spectator && peer.phase == .Running && peer.connection == packet.from {
                    index = i
                    break
                }
            }

            if index < 0 {
                continue
            }
        } else if packet.from != s.client.authority {
            continue
        }

        kind := bytes[8]

        if self.hosting && kind == 4 {
            token: net.Token
            copy(token[:], bytes[32:48])
            peer := s.server.peers[index]

            if net.token_hash(token) != peer.token_hash {
                continue
            }

            if self.terminal_ready &&
               (self.terminal_peer != peer.connection || self.terminal_generation != peer.generation) {
                error_set(self, "terminal.admitted scope changed")
                return
            }

            self.terminal_peer = peer.connection
            self.terminal_generation = peer.generation
            self.terminal_epoch = epoch
            self.terminal_ready = true
            self.go = true
            terminal_send(self, &wire, packet.from, 5)
            continue
        }

        if !self.hosting && kind == 5 {
            if s.client.phase == .Running {
                self.go = true
            }

            continue
        }

        if !self.have_final {
            continue
        }

        signature, error := bd.signature_decode(bytes[32:])

        if error != .None || bd.compare(self.final_signature, signature) != .Match {
            continue
        }

        if self.hosting {
            peer := s.server.peers[index]

            if !self.terminal_ready ||
               peer.connection != self.terminal_peer ||
               peer.generation != self.terminal_generation ||
               epoch != self.terminal_epoch {
                error_set(self, "terminal.final scope mismatch")
                return
            }

            if kind == 1 {
                terminal_send(self, &wire, packet.from, 2)
            }

            if kind == 3 {
                self.terminal_final = true
                log_json("SAMPLE_TAIL", struct {
                    framework, role, stage: string,
                    epoch, tick:            u64,
                    signature_match:        bool,
                }{"Replay", self.role, "final_accepted", epoch, signature.tick, true})
                finish(self)
                return
            }
        } else if kind == 2 {
            self.got_close = true
            terminal_send(self, &wire, s.client.authority, 3)
            log_json("SAMPLE_TAIL", struct {
                framework, role, stage: string,
                epoch, tick:            u64,
                signature_match:        bool,
            }{"Replay", self.role, "close_accepted", epoch, signature.tick, true})
        }
    }

    if self.hosting {
        if self.terminal_ready && !self.have_final && self.tail_frames % 10 == 1 {
            terminal_send(self, &wire, self.terminal_peer, 5)
        }
    } else if s.client.phase == .Running {
        if !self.go {
            if self.tail_frames % 10 == 1 {
                terminal_send(self, &wire, s.client.authority, 4)
            }
        } else if self.have_final && self.tail_frames % 10 == 1 {
            terminal_send(self, &wire, s.client.authority, self.got_close ? 3 : 1)
        }
    }
}
