package replay_duel

import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import rb "godot:replay/p2p"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import v "godot:replay/view"
import game "../shared/duel"
import sc "godot:replay/schema"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

duel_watch_source :: proc(self: ^ReplayDuel, now: u64) {
    if self.watch_source_failed {
        return
    }

    if self.watch_failover &&
       self.listening &&
       self.watch_source.ready &&
       self.peer.timeline.confirmed >= 300 &&
       self.watch_source.transfer.acknowledged.archive.tick >= 250 {
        self.watch_retired, self.watch_source_failed = true, true
        rb.watch_source_destroy(&self.watch_source)
        tr.close(&self.watch_wire)
        gd.print_str(
            fmt.tprintf("RDP_WATCH_SOURCE_RETIRED confirmed=%d player_continues=true", self.peer.timeline.confirmed),
        )
        return
    }

    tr.delay_time(&self.watch_delay, now)
    tr.poll(&self.watch_wire)

    if self.peer.timeline.confirmed >= 150 && !self.watch_join_reported {
        self.watch_join_reported = true
        gd.print_str(fmt.tprintf("RDP_WATCH_JOIN_READY tick=%d", self.peer.timeline.confirmed))
    }

    if !self.watch_source.ready {
        remotes: [16]tr.Peer_Id

        if tr.status(&self.watch_wire) != .Connected || duel_remotes(self, true, remotes[:]) != 1 {
            return
        }

        cfg := rec.DEFAULT_CONFIG
        cfg.retry_ms, cfg.timeout_ms = 50, 1000
        point: rb.Watch_Anchor
        resume: ^rb.Watch_Anchor
        binding := u64(77)

        if self.watch_failover && !self.listening {
            value, error := duel_watch_anchor_read()

            if error == .Waiting {
                return
            }

            if error != .None {
                duel_watch_source_stop(self, error)
                return
            }

            point = value
            resume = &point
            binding = 78
        }

        if err := rb.watch_source_init(
            &self.watch_source,
            &self.peer,
            remotes[0],
            self.watch_wire,
            binding,
            cfg,
            resume = resume,
        ); err != .None {
            if err != .Waiting {
                duel_watch_source_stop(self, err)
            }

            return
        }

        if resume != nil {
            gd.print_str(
                fmt.tprintf(
                    "RDP_WATCH_SOURCE_RESUMED local=%d anchor=%d confirmed=%d",
                    self.peer.local,
                    point.tick,
                    self.peer.timeline.confirmed,
                ),
            )
        }
    }

    if err := rb.watch_source_pump(&self.watch_source, now); err != .None && err != .Transport {
        duel_watch_source_stop(self, err)
    }
}

duel_watch_source_stop :: proc(self: ^ReplayDuel, error: rb.Error) {
    gd.print_str(fmt.tprintf("RDP_WATCH_SOURCE_STOP error=%v", error))
    self.watch_source_failed = true
    rb.watch_source_destroy(&self.watch_source)
    tr.close(&self.watch_wire)
}

duel_watch_process :: proc(self: ^ReplayDuel, now: u64) {
    if self.watch_failover &&
       self.watch.ready &&
       self.watch.has_world &&
       !self.watch_rebound &&
       tr.status(&self.wire) == .Disconnected {
        if !duel_watch_switch(self, now) {
            return
        }
    }

    if !self.watch.ready {
        tr.poll(&self.wire)

        if tr.status(&self.wire) != .Connected {
            return
        }

        cfg := duel_config(self)
        transfer := rec.DEFAULT_CONFIG
        transfer.retry_ms, transfer.timeout_ms = 50, 1000

        if rb.watch_init(
               &self.watch,
               r.Frame(game.World){state = game.initial(42)},
               game.model(),
               [2]tr.Peer_Id{1, 2},
               1,
               self.wire,
               77,
               cfg,
               transfer,
           ) !=
           .None {
            duel_fail(self, "watch init")
            return
        }
    }

    if self.watch_paused && !self.watch_resumed && now >= self.watch_pause_until {
        self.watch_resumed = true
        tr.delay_faults(
            &self.delay,
            u32(duel_int("RDP_JITTER", 0)),
            u32(duel_int("RDP_LOSS", 0)),
            u32(duel_int("RDP_DUPLICATE", 0)),
            77,
        )
        gd.print_str("RDP_WATCH_LINK_RESTORED")
    }

    if err := rb.watch_pump(&self.watch, now); err != .None && err != .Transport {
        duel_fail(self, fmt.tprintf("watch %v tick=%d", err, self.watch.report.tick))
        return
    }

    frame, found := rb.watch_current(&self.watch)

    if !found {
        return
    }

    timeline := rb.watch_timeline(&self.watch)

    if self.watch_reset != self.watch.reset.sequence {
        self.watch_reset = self.watch.reset.sequence
        v.journal_destroy(&self.journal)
        v.journal_init(&self.journal, baseline = self.watch.reset.baseline_tick, cfg = {128, 32, 8192})
        base, _ := r.read(timeline, self.watch.reset.baseline_tick)
        self.baseline_shots, self.shots_begun, self.shots_canceled = base.state.shots, 0, 0
        gd.print_str(
            fmt.tprintf(
                "RDP_WATCH_RESET sequence=%d previous=%d baseline=%d",
                self.watch_reset,
                self.watch.reset.previous_tick,
                self.watch.reset.baseline_tick,
            ),
        )
    }

    for tick := self.journal.confirmed + 1; tick <= frame.tick; tick += 1 {
        events: [32]r.Occurrence(game.Event)
        n, err := r.copy_events(timeline, tick, events[:])

        if err != .None || v.sync_tick(&self.journal, tick, events[:n]) != .None {
            duel_fail(self, "watch event history")
            return
        }
    }

    if v.advance_time(&self.journal, frame.tick, frame.tick) != .None {
        duel_fail(self, "watch event time")
        return
    }

    changes: [256]v.Change(game.Event)

    for {
        n := v.drain(&self.journal, changes[:])

        if n == 0 {
            break
        }

        for change in changes[:n] {
            if change.occurrence.value.kind == .Shot {
                if change.kind == .Begin {
                    self.shots_begun += 1
                }

                if change.kind == .Cancel {
                    self.shots_canceled += 1
                }
            }
        }
    }

    paint(self, frame.state)
    gd.set_string(
        cast(gd.Object)self.status,
        "text",
        fmt.ctprintf("Spectating   Tick %d   Kills %d : %d", frame.tick, frame.state.kills[0], frame.state.kills[1]),
    )
    blackout := duel_int("RDP_WATCH_BLACKOUT_MS", 0)

    if self.test && blackout > 0 && !self.watch_paused && frame.tick >= 220 {
        self.watch_paused, self.watch_pause_until = true, now + u64(blackout)
        tr.delay_faults(&self.delay, 0, 10000, 0, 77)
        gd.print_str(fmt.tprintf("RDP_WATCH_BLACKOUT tick=%d duration_ms=%d", frame.tick, blackout))
    }

    if self.test && frame.tick == self.test_until && !self.reported {
        if !reference_equal(frame.state, self.test_until, self.neutral_until) ||
           self.baseline_shots + self.shots_begun - self.shots_canceled != frame.state.shots {
            duel_fail(self, "watch reference/events")
            return
        }

        if blackout > 0 && (!self.watch_resumed || self.watch.stats.resets < 2) {
            duel_fail(self, "watch blackout recovery")
            return
        }

        if self.watch_failover &&
           (!self.watch_rebound ||
                   self.watch.rebind_pending ||
                   self.watch.stats.rebinds != 1 ||
                   self.watch.stats.resets != 1) {
            duel_fail(self, "watch failover continuity")
            return
        }

        gd.print_str(
            fmt.tprintf(
                "RDP_WATCH_RESULT tick=%d hash=%d shots=%d hits=%d kills=%d,%d installs=%d replayed=%d resets=%d skipped=%d bytes=%d visible_shots=%d",
                frame.tick,
                self.watch.states[self.watch.active].chain,
                frame.state.shots,
                frame.state.hits,
                frame.state.kills[0],
                frame.state.kills[1],
                self.watch.stats.installed,
                self.watch.stats.replayed,
                self.watch.stats.resets,
                self.watch.stats.skipped_ticks,
                self.watch.stats.bytes,
                self.shots_begun,
            ),
        )
        gd.print_str("REPLAY_DUEL_WATCH_OK")

        if self.watch_failover {
            gd.print_str("REPLAY_DUEL_WATCH_FAILOVER_OK rebinds=1 extra_resets=0")
        }

        self.reported, self.done_at = true, now + 1000
    }

    when !gd.IS_WEB {
        if self.done_at != 0 && now >= self.done_at {
            gd.scene_tree_quit(gd.get_tree(self.owner), 0)
        }
    }
}

// Native fixture provider: two known loopback participants and a private
// control file carry the anchor. This is not public spectator authentication.
duel_watch_anchor_read :: proc() -> (rb.Watch_Anchor, rb.Error) {
    path := duel_param("RDP_WATCH_CONTROL", "")

    if len(path) == 0 {
        return {}, .Invalid_Config
    }

    name := gd.new_string_odin(path)
    exists := gd.file_access_file_exists(name)
    gd.free_string(name)

    if !exists {
        return {}, .Waiting
    }

    bytes, error := storagegd.storage_read(path, 128)
    defer delete(bytes)

    if error != .None {
        return {}, .Invalid_Archive
    }

    schema: sc.Schema
    defer sc.destroy(&schema)

    if sc.init(&schema, rb.Watch_Anchor).error != .None {
        return {}, .Schema
    }

    point: rb.Watch_Anchor

    if sc.decode(&schema, &point, bytes).error != .None {
        return {}, .Invalid_Archive
    }

    return point, .None
}

duel_watch_switch :: proc(self: ^ReplayDuel, now: u64) -> bool {
    when gd.IS_WEB {
        duel_fail(self, "native spectator provider required")
        return false
    } else {
        before, known := rb.watch_current(&self.watch)

        if !known {
            return false
        }

        tr.close(&self.wire)
        port := duel_int("RDP_PORT", 49520)

        if !transportgd.enet_join(&self.enet, "127.0.0.1", u16(port + 2)) {
            duel_fail(self, "replacement spectator connection")
            return false
        }

        base := transportgd.enet_transport(&self.enet)

        if !tr.delay_init(&self.delay, base, u32(duel_int("RDP_LATENCY", 0))) {
            tr.close(&base)
            duel_fail(self, "replacement spectator delay")
            return false
        }

        tr.delay_faults(
            &self.delay,
            u32(duel_int("RDP_JITTER", 0)),
            u32(duel_int("RDP_LOSS", 0)),
            u32(duel_int("RDP_DUPLICATE", 0)),
            78,
        )
        tr.delay_time(&self.delay, now)
        self.wire = tr.delay_transport(&self.delay)
        point, error := rb.watch_rebind(&self.watch, 1, self.wire, 78, now)

        if error != .None {
            duel_fail(self, fmt.tprintf("watch rebind %v", error))
            return false
        }

        after, valid := rb.watch_current(&self.watch)

        if !valid || !reflect.equal(after, before) || point.tick != before.tick {
            duel_fail(self, "watch retained frame")
            return false
        }

        schema: sc.Schema
        defer sc.destroy(&schema)
        bytes: [128]u8

        if sc.init(&schema, rb.Watch_Anchor).error != .None ||
           sc.encode(&schema, point, bytes[:schema.wire_size]).error != .None ||
           storagegd.storage_write(duel_param("RDP_WATCH_CONTROL", ""), bytes[:schema.wire_size], 128) != .None {
            duel_fail(self, "spectator anchor publication")
            return false
        }

        self.watch_rebound = true
        gd.print_str(
            fmt.tprintf("RDP_WATCH_REBOUND tick=%d chain=%d binding=78 retained=true", point.tick, point.chain),
        )
        return true
    }
}
