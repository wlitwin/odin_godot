package replay_quickdraw

import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import auth "godot:replay/authority"
import sc "godot:replay/schema"
import rgd "godot:replay/godot"
import game "../shared/duel"

open_session :: proc(self: ^ReplayQuickdraw, initial: game.World, opts: rgd.Session_Options) -> net.Error {
    if self.online.launch {
        options, ok := rgd.party_room_options(&self.online.party, opts)

        if !ok {
            return .Invalid_Config
        }

        options.session.discover_epoch = false

        if opts.role == .Observer {
            options.session.replication.accept_checkpoints = false
        }

        self.session = &self.room.session
        return rgd.room_open(&self.room, r.Frame(game.World){state = initial}, game.model(), options)
    }

    port := quickdraw_int("RQ_COORD_PORT", 0)

    if port == 0 {
        return rgd.session_open(self.session, r.Frame(game.World){state = initial}, game.model(), opts)
    }

    member := quickdraw_int("RQ_MEMBER", 0)
    incarnation := quickdraw_int("RQ_INCARNATION", 101)
    key, valid := control_key(quickdraw_param("RQ_COORD_KEY", ""))

    if port < 1 || port > 65535 || member < 1 || member > 3 || incarnation < 1 || !valid {
        return .Invalid_Config
    }

    options := rgd.Room_Options {
        identity     = {u64(member), u64(incarnation)},
        key          = key,
        room         = 45,
        coordinator  = "127.0.0.1",
        control_port = u16(port),
        bootstrap    = member == 1,
        session      = opts,
    }

    if member == 1 {
        options.successor, options.successor_seat = {2, 102}, 2
    }

    if member == 2 {
        options.successor, options.successor_seat = {1, 101}, 1
    }

    options.session.replication.accept_checkpoints = member <= 2
    self.session = &self.room.session
    return rgd.room_open(&self.room, r.Frame(game.World){state = initial}, game.model(), options)
}

control_key :: proc(value: string) -> (auth.Key, bool) {
    key: auth.Key

    if len(value) != 64 {
        return key, false
    }

    for c, i in value {
        digit := c >= '0' && c <= '9' ? int(c - '0') : c >= 'a' && c <= 'f' ? int(c - 'a') + 10 : -1

        if digit < 0 {
            return key, false
        }

        key[i / 2] = key[i / 2] << 4 | u8(digit)
    }

    return key, true
}

issue :: proc(self: ^ReplayQuickdraw, action: game.Action) -> (u64, net.Error) {
    if self.room.ready {
        return rgd.room_issue(&self.room, action)
    }

    return rgd.session_issue(self.session, action)
}

// Harness diagnostics operate on real session/archive state. They do not install
// test worlds, grant authority or advance a second substitute simulation.
Recovery_Probe :: struct {
    point:                           auth.Point,
    frame:                           r.Frame(game.World),
    checked_migration:               u64,
    restored_exact, restored_combat: bool,
}

combat_frame :: proc(w: game.World) -> bool {
    return(
        w.players[1].hp == 0 &&
        w.players[1].respawn_at > w.clock &&
        w.players[2].boots &&
        w.bullets.count > 0 &&
        w.players[2].fire_cd > 0 &&
        w.history.entries[w.clock % 32].valid \
    )
}

observe_recovery :: proc(self: ^ReplayQuickdraw) {
    p := &self.recovery_probe
    prepared := &self.room.prepared

    if prepared.ready && prepared.point != p.point {
        cp: net.Checkpoint(game.World, game.Controls, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&cp)
        codec := &self.session.link.incoming.archive_codec

        if !codec.ready {
            codec = nil
        }

        if net.checkpoint_decode(
               &cp,
               prepared.bytes,
               game.model(),
               self.room.options.session.network.content,
               codec = codec,
           ) ==
           .None {
            p.point, p.frame = prepared.point, cp.frame
        }
    }

    if self.room.migrations > p.checked_migration &&
       self.session.authority &&
       self.room.recovery.to_epoch == self.session.server.cfg.epoch {
        p.checked_migration = self.room.migrations
        frame, found := r.read(&self.session.server.timeline, self.room.recovery.checkpoint_tick)
        p.restored_exact = found && p.point == self.room.lease.view.recovered && reflect.equal(frame, p.frame)
        p.restored_combat = p.restored_exact && combat_frame(frame.state)
        gd.print_str(
            fmt.tprintf(
                "RQ_COMBAT_RESTORED exact=%v combat=%v tick=%d bullets=%d fire_cd=%d respawn=%d buys=%d history=%v",
                p.restored_exact,
                p.restored_combat,
                frame.tick,
                frame.state.bullets.count,
                frame.state.players[2].fire_cd,
                frame.state.players[1].respawn_at,
                frame.state.buys,
                reflect.equal(frame.state.history, p.frame.state.history),
            ),
        )
    }
}

truth :: proc(self: ^ReplayQuickdraw) -> (r.Frame(game.World), bool) {
    if self.session == nil || !self.session.ready {
        return {}, false
    }

    if self.session.authority {
        return r.current(&self.session.server.timeline)
    }

    return self.session.client.authority_frame, self.session.client.has_world
}

@(gd_method)
replay_quickdraw_drive :: proc(self: ^ReplayQuickdraw, x, y, buttons, target, drone: gd.Int) {
    self.manual = true
    self.manual_move = {i8(clamp(x, -1, 1)), i8(clamp(y, -1, 1))}
    self.manual_buttons, self.manual_drone = u8(buttons) & 7, i8(clamp(drone, -1, 1))
    self.manual_target = u16(clamp(target, 0, game.SEATS))
}

@(gd_method)
replay_quickdraw_purchase :: proc(self: ^ReplayQuickdraw) -> bool {
    _, err := issue(self, game.Action{item = 1})
    return err == .None
}

@(gd_method)
replay_quickdraw_handoff :: proc(self: ^ReplayQuickdraw) -> bool {
    return rgd.room_handoff(&self.room) == .None
}

// Fault fixture: exercise the legitimate signed Claim RPC while the current
// owner still has its lease. The coordinator must deny takeover as Busy.
@(gd_method)
replay_quickdraw_early_claim :: proc(self: ^ReplayQuickdraw) -> bool {
    if self.room.phase != .Following || !self.room.prepared.ready || self.room.rpc.pending {
        return false
    }

    self.room.phase = .Claiming
    return true
}

@(gd_method)
replay_quickdraw_probe :: proc(self: ^ReplayQuickdraw, name: gd.String, seat: gd.Int) -> gd.Int {
    defer gd.free_string(name)
    field := gd.gd_string_to_odin(name)

    if self.session == nil {
        return 0
    }

    f, _ := truth(self)
    w := f.state
    index := int(clamp(seat, 1, game.SEATS)) - 1
    player := w.players[index]
    p := &self.recovery_probe

    switch field {
    case "steady":
        return gd.Int(
            self.session.ready &&
            !self.session.fenced &&
            (self.session.authority || self.session.client.phase == .Running),
        )
    case "players":
        count := gd.Int(0)

        for player in w.players {
            if player.connected {
                count += 1
            }
        }

        return count
    case "seat":
        return gd.Int(rgd.session_seat(self.session))
    case "authority":
        return gd.Int(self.session.authority)
    case "epoch":
        return gd.Int(self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch)
    case "head":
        return gd.Int(f.tick)
    case "shots":
        return gd.Int(w.shots)
    case "hits":
        return gd.Int(w.hits)
    case "lobs":
        return gd.Int(w.lobs)
    case "lands":
        return gd.Int(w.lands)
    case "bullets":
        return gd.Int(w.bullets.count)
    case "buys":
        return gd.Int(w.buys)
    case "hp":
        return gd.Int(player.hp)
    case "life":
        return gd.Int(player.life)
    case "boots":
        return gd.Int(player.boots)
    case "gold":
        return gd.Int(player.gold)
    case "combat_backup":
        return gd.Int(p.point.archive.sequence != 0 && combat_frame(p.frame.state))
    case "backup_sequence":
        return gd.Int(
            self.session.authority ? self.session.link.outgoing.acknowledged.archive.sequence : p.point.archive.sequence,
        )
    case "backup_tick":
        return gd.Int(
            self.session.authority ? self.session.link.outgoing.acknowledged.archive.tick : p.point.archive.tick,
        )
    case "control_error":
        return gd.Int(self.room.control_error)
    case "last_result":
        return gd.Int(self.room.last_result)
    case "claim_rejections":
        return gd.Int(self.room.claim_rejections)
    case "busy_claims":
        return gd.Int(self.room.busy_claims)
    case "reply_error":
        return gd.Int(self.room.rpc.reply.result)
    case "link_error":
        return gd.Int(self.session.link.error)
    case "link_model_error":
        return gd.Int(self.session.link.model_error)
    case "transfer_phase":
        return gd.Int(self.session.link.outgoing.phase)
    case "transfer_failure":
        return gd.Int(self.session.link.incoming.failure)
    case "restored_exact":
        return gd.Int(p.restored_exact)
    case "restored_combat":
        return gd.Int(p.restored_combat)
    case "restored_hits":
        return gd.Int(p.frame.state.hits)
    case "restored_lobs":
        return gd.Int(p.frame.state.lobs)
    case "restored_life":
        return gd.Int(p.frame.state.players[1].life)
    case "room_phase":
        return gd.Int(self.room.phase)
    case "recovery_ready":
        return gd.Int(self.room.recovery.ready)
    case "recovery_kind":
        return gd.Int(self.room.lease.view.recovery)
    case "recovery_tick":
        return gd.Int(self.room.recovery.checkpoint_tick)
    case "lost_ticks":
        return gd.Int(self.room.recovery.known_lost_ticks)
    case "interruption":
        return gd.Int(self.room.recovery.interruption_ms)
    case "archive_bytes":
        return gd.Int(self.room.recovery.archive_bytes)
    case "install_us":
        return gd.Int(self.room.recovery.install_us)
    case "mixed":
        return gd.Int(self.session.authority || self.session.client.mixed_presentation)
    case:
        return -1
    }
}

@(gd_method)
replay_quickdraw_probe_hash :: proc(self: ^ReplayQuickdraw, tick: gd.Int) -> gd.Int {
    if tick < 0 || self.session == nil || !self.session.ready {
        return -1
    }

    f: r.Frame(game.World)
    found := false

    if self.session.authority {
        f, found = r.read(&self.session.server.timeline, u64(tick))
    } else {
        c := &self.session.client
        at := int(u64(tick) % u64(c.cfg.history))

        if c.observed_valid[at] && c.observed[at].tick == u64(tick) {
            f, found = c.observed[at], true
        }
    }

    if !found {
        return -1
    }

    codec := self.session.authority ? &self.session.server.codecs.state : &self.session.client.codecs.state
    bytes := make([]u8, codec.wire_size, context.temp_allocator)

    if sc.encode(codec, f.state, bytes).error != .None {
        return -1
    }

    return gd.Int(sc.digest(bytes) & 0x7fff_ffff_ffff_ffff)
}
