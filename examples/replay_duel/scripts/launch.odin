package replay_duel

import "core:fmt"
import "core:strconv"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import tr "godot:replay/transport"
import rgd "godot:replay/godot"
import transportgd "godot:replay/godot/transport"

// Reuse the binding's platform-neutral launch parser. Native RDP_FOO maps to
// ?foo= in the browser. Values used beyond this call are explicitly cloned.
duel_param :: proc(key: cstring, fallback: string = "") -> string {
    name := string(key)
    query := strings.to_lower(name[4:], context.temp_allocator)
    return gd.launch_param(key, query, fallback)
}

duel_int :: proc(key: cstring, fallback: int) -> int {
    text := duel_param(key, "")

    if len(text) == 0 {
        return fallback
    }

    value, valid := strconv.parse_int(text)
    return valid ? value : -1
}

duel_remotes :: proc(self: ^ReplayDuel, watch: bool, dst: []tr.Peer_Id) -> int {
    when gd.IS_WEB {
        return transportgd.rtc_peers(watch ? &self.watch_rtc : &self.rtc, dst)
    } else {
        if self.online_enabled && !watch {
            identity, ok := rgd.p2p_direct_identity(&self.direct)

            if !ok || len(dst) == 0 {
                return 0
            }

            dst[0] = tr.Peer_Id(identity.member)
            return 1
        }

        peers := watch ? self.watch_enet.remotes[:] : self.enet.remotes[:]
        return copy(dst, peers)
    }
}

duel_browser_rooms :: proc(self: ^ReplayDuel) {
    when gd.IS_WEB {
        if self.rtc.error != .None || self.watch_rtc.error != .None {
            duel_fail(self, fmt.tprintf("WebRTC %v/%v", self.rtc.error, self.watch_rtc.error))
            return
        }

        if self.listening && len(self.rtc.room) > 0 && !self.room_reported {
            self.room_reported = true
            gd.print_str(fmt.tprintf("RDP_ROOM %s", self.rtc.room))
        }

        if self.listening && len(self.watch_rtc.room) > 0 && !self.watch_room_reported {
            self.watch_room_reported = true
            gd.print_str(fmt.tprintf("RDP_WATCH_ROOM %s", self.watch_rtc.room))
        }

        if self.online_enabled {
            gd.set_string(
                self.room_label,
                "text",
                "Use Save & pause before closing, then Rejoin recent with your participant file.",
            )
        } else {
            gd.set_string(
                cast(gd.Object)self.room_label,
                "text",
                fmt.ctprintf("Room: %s    Watch: %s", self.rtc.room, self.watch_rtc.room),
            )
        }
    }
}

// Deterministic application-channel loss while WebRTC itself stays serviced.
// The peer can predict only its configured horizon, then resumes from inputs.
duel_player_blackout :: proc(self: ^ReplayDuel, now: u64) {
    duration := duel_int("RDP_BLACKOUT_MS", 0)

    if !self.test || !self.listening || duration <= 0 {
        return
    }

    if !self.player_paused && self.peer.timeline.confirmed >= 180 {
        self.player_paused = true
        self.player_pause_start = now
        self.player_pause_until = now + u64(duration)
        tr.delay_faults(&self.delay, 0, 10000, 0, 99)
        gd.print_str(fmt.tprintf("RDP_PLAYER_BLACKOUT tick=%d duration_ms=%d", self.peer.timeline.head, duration))
    }

    if self.player_paused && !self.player_resumed {
        if now - self.player_pause_start >= 1000 && !self.player_stall_reported {
            self.player_stall_reported = true
            self.player_stall_head = self.peer.timeline.head
            gd.print_str(
                fmt.tprintf(
                    "RDP_PLAYER_STALL head=%d confirmed=%d",
                    self.player_stall_head,
                    self.peer.timeline.confirmed,
                ),
            )
        }

        if now >= self.player_pause_until {
            if self.player_stall_reported && self.peer.timeline.head != self.player_stall_head {
                duel_fail(self, "blackout prediction exceeded stable horizon")
                return
            }

            self.player_resumed = true
            tr.delay_faults(
                &self.delay,
                u32(duel_int("RDP_JITTER", 0)),
                u32(duel_int("RDP_LOSS", 0)),
                u32(duel_int("RDP_DUPLICATE", 0)),
                42,
            )
            gd.print_str(
                fmt.tprintf(
                    "RDP_PLAYER_RESTORED head=%d elapsed_ms=%d",
                    self.peer.timeline.head,
                    now - self.player_pause_start,
                ),
            )
        }
    }
}

@(gd_method)
replay_duel_room_code :: proc(self: ^ReplayDuel, watch: bool) -> string {
    return watch ? self.watch_rtc.room : self.rtc.room
}


// Read-only browser acceptance/diagnostic view. It never supplies simulation input.
@(gd_method)
replay_duel_probe :: proc(self: ^ReplayDuel, field: gd.Int) -> gd.Int {
    if !self.peer.ready {
        return -1
    }

    frame, ok := r.current(&self.peer.timeline)

    if !ok {
        return -1
    }

    switch field {
    case 0:
        return gd.Int(frame.tick)
    case 1:
        return gd.Int(frame.state.fighters[0].position[0])
    case 2:
        return gd.Int(frame.state.fighters[0].position[1])
    case 3:
        return gd.Int(frame.state.shots)
    case 4:
        return gd.Int(self.peer.sampled)
    case 5:
        return self.saved ? 1 : 0
    case 6:
        return gd.Int(self.peer.timeline.confirmed)
    }

    return -1
}
