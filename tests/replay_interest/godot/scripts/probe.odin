//gd:extends Node2D
//gd:class InterestProbe
package interest_probe

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import net "godot:replay/net"
import r "godot:replay"
import v "godot:replay/view"
import game "../shared/arena"
import storagegd "godot:replay/godot/storage"

InterestProbe :: struct {
    owner:                     gd.Node2d,
    status:                    gd.Label `gd:"onready=Status"`,
    session:                   rgd.Session(game.World, game.Control, game.Action, game.Event, game.SEATS),
    role:                      string,
    started:                   u64,
    first_mask:                u64,
    changed, issued, done:     bool,
    checked, events, verdicts: u64,
}

interest_probe_ready :: proc(self: ^InterestProbe) {
    self.role = strings.clone(gd.env_string("INTEREST_ROLE", "host"))
    options := rgd.SESSION_OPTIONS
    options.network.content = game.CONTENT
    options.network.history = 256
    options.network.snapshot_every = 2
    options.latency_ms, options.jitter_ms, options.loss_permyriad, options.duplicate_permyriad = 120, 20, 500, 500
    options.port = u16(gd.env_int("INTEREST_PORT", 49712))
    options.token = storagegd.session_token(self.role)

    switch self.role {
    case "host":
        options.role = .Host
    case "client":
        options.role = .Client
    case "observer":
        options.role = .Observer
    }

    if err := rgd.session_open(
        &self.session,
        r.Frame(game.World){state = game.initial()},
        game.player_model(),
        options,
    ); err != .None {
        fail(self, fmt.ctprintf("open %v", err))
        return
    }

    self.started = gd.time_get_ticks_msec(gd.singleton_time())
}

fail :: proc(self: ^InterestProbe, why: cstring) {
    gd.print_str(fmt.tprintf("REPLAY_INTEREST_GODOT_FAIL role=%s %s", self.role, why))
    self.done = true
    gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}

interest_probe_process :: proc(self: ^InterestProbe, dt: f64) {
    if self.done || !self.session.ready {
        return
    }

    elapsed := gd.time_get_ticks_msec(gd.singleton_time()) - self.started

    if elapsed > 12000 {
        fail(self, "fixture timeout")
        return
    }

    control := game.Control {
        move = self.role == "client" && elapsed >= 2000 && elapsed < 4600 ? -1 : 0,
    }

    if err := rgd.session_frame(&self.session, dt, control); err != .None {
        fail(self, fmt.ctprintf("frame %v", err))
        return
    }

    changes: [512]v.Change(net.Net_Event(game.Event))
    n := rgd.session_changes(&self.session, changes[:])

    for change in changes[:n] {
        if !(change.kind == .Confirm || (change.kind == .Begin && change.confirmed)) {
            continue
        }

        e := change.occurrence.value

        if e.kind == .Gameplay {
            self.events += 1

            if !self.session.authority && e.value.value != 0 {
                fail(self, "event nonce leaked")
                return
            }
        } else {
            self.verdicts += 1

            if !self.session.authority && (self.role == "observer" || e.seat != rgd.session_seat(&self.session)) {
                fail(self, "foreign action verdict")
                return
            }
        }
    }

    frame, ok := rgd.session_authority_state(&self.session)

    if !ok {
        return
    }

    if self.role == "client" && elapsed >= 1600 && !self.issued {
        _, err := rgd.session_issue(&self.session, game.Action{claim = true})

        if err == .None {
            self.issued = true
        }
    }

    if !self.session.authority {
        who := net.Recipient{rgd.session_seat(&self.session), self.role == "observer"}

        if !game.replica_valid(
            net.Replica(game.World, game.Control, game.SEATS){frame.state, self.session.client.held},
            who,
        ) {
            fail(self, "invalid received view")
            return
        }

        for object, i in frame.state.objects {
            if frame.state.visible & (u64(1) << uint(i)) != 0 && !game.visible(frame.state, who, i) {
                fail(self, "out-of-range object")
                return
            }
        }

        if self.checked == 0 {
            self.first_mask = frame.state.visible
        } else if self.first_mask != frame.state.visible {
            self.changed = true
        }

        self.checked += 1
    }

    gd.set_string(
        self.status,
        "text",
        fmt.ctprintf(
            "%s  tick %d\nVisible objects: %x\nFinal effects: %d",
            self.role,
            frame.tick,
            frame.state.visible,
            self.events,
        ),
    )

    if elapsed < (self.role == "host" ? 9000 : 7500) {
        return
    }

    if self.role == "host" {
        if frame.state.players[1].score != 1 || !game.state_valid(frame.state) {
            fail(self, "authority world or action")
            return
        }

        cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&cp)

        if net.checkpoint_capture(&self.session.server, &cp) != .None ||
           cp.frame.state.secret != game.SECRET ||
           cp.frame.state.objects[0].nonce == 0 {
            fail(self, "incomplete authority checkpoint")
            return
        }
    } else {
        if self.checked < 100 || self.events < 1 {
            fail(self, "insufficient received coverage")
            return
        }

        if self.role == "client" && (!self.changed || self.verdicts != 1 || frame.state.players[1].score != 1) {
            fail(self, "movement/own verdict")
            return
        }
    }

    gd.print_str(
        fmt.tprintf(
            "REPLAY_INTEREST_GODOT_OK role=%s checked=%d events=%d verdicts=%d changed=%t",
            self.role,
            self.checked,
            self.events,
            self.verdicts,
            self.changed,
        ),
    )
    self.done = true
    gd.scene_tree_quit(gd.get_tree(self.owner), 0)
}

interest_probe_exit_tree :: proc(self: ^InterestProbe) {
    rgd.session_close(&self.session)
    delete(self.role)
}
