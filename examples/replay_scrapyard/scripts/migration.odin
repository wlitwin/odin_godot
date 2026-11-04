package replay_scrapyard

import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import auth "godot:replay/authority"
import rgd "godot:replay/godot"
import game "../shared/game"
import scenegd "godot:replay/godot/scene"
import transportgd "godot:replay/godot/transport"

open_session :: proc(self: ^ReplayScrapyard, initial: game.World, options: rgd.Session_Options) -> net.Error {
    if self.online.launch {
        if self.resume_requested {
            return .Invalid_Config
        }

        opts, valid := rgd.party_room_options(&self.online.party, options)

        if !valid {
            return .Invalid_Config
        }

        opts.preparation_ready, opts.preparation_user = spray_preparation_ready, self
        opts.checkpoint_assets = {
            collect = game.checkpoint_assets,
            validate = scenegd.asset_png_valid,
        }
        opts.checkpoint_cache = &self.assets[0].cache
        self.session = &self.room.session
        err := rgd.room_open(&self.room, r.Frame(game.World){state = initial}, session_model(self), opts)

        if err == .None {
            self.online.launch = false
        }

        return err
    }

    port := scrap_int("RSY_COORD_PORT", 0)
    resume := self.resume_requested
    url := scrap_param("RSY_COORD_URL", "")

    if port == 0 && !(gd.IS_WEB && url != "") {
        if resume {
            return resume_run(self, options)
        }

        return rgd.session_open(self.session, r.Frame(game.World){state = initial}, session_model(self), options)
    }

    if resume {
        return .Invalid_Config
    }

    member := scrap_int("RSY_MEMBER", 0)
    incarnation := scrap_int("RSY_INCARNATION", 101)
    key, valid := control_key(scrap_param("RSY_COORD_KEY", ""))

    if (port < 1 && !gd.IS_WEB) || port > 65535 || member < 1 || member > 3 || incarnation < 1 || !valid {
        return .Invalid_Config
    }

    opts := rgd.Room_Options {
        identity = {u64(member), u64(incarnation)},
        key = key,
        room = 48,
        coordinator = "127.0.0.1",
        control_port = u16(port),
        bootstrap = member == 1,
        session = options,
    }

    when gd.IS_WEB {
        opts.control_backend = .Websocket
        opts.coordinator = url
        opts.session.backend = .Rtc
        opts.session.rtc.url = url
        ice, ice_error := transportgd.rtc_ice_settings("RSY_ICE_JSON")

        if ice_error != .None {
            return .Invalid_Config
        }

        opts.session.rtc.ice_json = ice
    }

    if member == 1 {
        opts.successor = {2, 102}
    }

    if member == 2 {
        opts.successor = {1, 101}
    }

    opts.session.replication.accept_checkpoints = member <= 2
    opts.preparation_ready, opts.preparation_user = spray_preparation_ready, self
    self.session = &self.room.session
    return rgd.room_open(&self.room, r.Frame(game.World){state = initial}, session_model(self), opts)
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

frame_session :: proc(self: ^ReplayScrapyard, dt: f64, control: game.Control) -> net.Error {
    if self.room.ready {
        return rgd.room_frame(&self.room, dt, control)
    }

    return rgd.session_frame(self.session, dt, control)
}

Recovery_Probe :: struct {
    point: auth.Point,
    frame: r.Frame(game.World),
    checked: u64,
    exact, active: bool,
}

active_combat :: proc(w: game.World) -> bool {
    return(
        w.stage == .Yard &&
        w.mobs.count > 0 &&
        w.zones.count > 0 &&
        w.lobs.count > 0 &&
        w.players[0].casts >= 2 &&
        w.players[0].ability_cd[0].remaining > 0 \
    )
}

observe_recovery :: proc(self: ^ReplayScrapyard) {
    probe := &self.recovery_probe[0]
    prepared := &self.room.prepared

    if prepared.ready && prepared.point != probe.point {
        cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&cp)
        codec := &self.session.link.incoming.archive_codec

        if !codec.ready {
            codec = nil
        }

        if net.checkpoint_decode(&cp, prepared.bytes, game.model(), game.CONTENT, codec = codec) == .None {
            probe.point = prepared.point
            probe.frame = cp.frame
        }
    }

    if self.room.migrations > probe.checked &&
       self.session.authority &&
       self.room.recovery.to_epoch == self.session.server.cfg.epoch {
        probe.checked = self.room.migrations
        frame, found := r.read(&self.session.server.timeline, self.room.recovery.checkpoint_tick)
        probe.exact = found && probe.point == self.room.lease.view.recovered && reflect.equal(frame, probe.frame)
        probe.active = probe.exact && active_combat(frame.state)
        gd.print_str(
            fmt.tprintf(
                "RSY_COMBAT_RESTORED exact=%v active=%v tick=%d zones=%d casts=%d mobs=%d lobs=%d cooldown=%d",
                probe.exact,
                probe.active,
                frame.tick,
                frame.state.zones.count,
                frame.state.players[0].casts,
                frame.state.mobs.count,
                frame.state.lobs.count,
                frame.state.players[0].ability_cd[0].remaining,
            ),
        )
    }
}

@(gd_method)
replay_scrapyard_handoff :: proc(self: ^ReplayScrapyard) -> bool {
    if scrap_int("RSY_SLOW_BACKUP", 0) == 1 && self.session.link.outgoing.ready {
        self.session.link.outgoing.cfg.bytes_per_second = 16 * 1024
        self.session.link.outgoing.cfg.bytes_per_update = 2048
        self.session.link.outgoing.clock.budget = 0
    }

    return rgd.room_handoff(&self.room) == .None
}
