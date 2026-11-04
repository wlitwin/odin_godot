package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import v "godot:replay/view"
import game "../shared/game"
import inputgd "godot:replay/godot/input"

dispatch_session_changes :: proc(self: ^ReplayScrapyard) {
    audio_prepare(self)
    feedback_prepare(self)
    changes: [320]v.Change(net.Net_Event(game.Event))

    for {
        n := rgd.session_changes(self.session, changes[:])

        if n == 0 {
            break
        }

        for change in changes[:n] {
            audio_event(self, change)
            runner_effect(self, change)
            feedback_event(self, change)
            observe_action_results(self, change)
            count_gameplay_effects(self, change)
        }
    }
}

observe_action_results :: proc(self: ^ReplayScrapyard, change: v.Change(net.Net_Event(game.Event))) {
    event := change.occurrence.value

    if event.kind == .Action_Result &&
       event.seat == rgd.session_seat(self.session) &&
       event.sequence == self.development_sequence &&
       change.confirmed &&
       change.kind != .Cancel {
        self.development_result = event.applied ? 1 : -1
        self.development_reason = gd.Int(event.reason)
    }

    inputgd.intent_observe(&self.dash_intent[0], self.session, change)
    inputgd.intent_observe(&self.turret_intent[0], self.session, change)

    if event.kind == .Action_Result &&
       event.seat == rgd.session_seat(self.session) &&
       change.confirmed &&
       change.kind != .Cancel &&
       !event.applied &&
       (event.reason == .Stale || event.reason == .Future) {
        if event.sequence == self.declare_sequence {
            self.declared = false
        }

        if event.sequence == self.ready_sequence {
            self.ready_retry = true
        }
    }

    if event.kind == .Action_Result &&
       (gd.env_int("REPLAY_MIGRATION_TRACE", 0) == 1 || scrap_int("RSY_TRACE", 0) == 1) &&
       change.kind == .Begin {
        gd.print_str(
            fmt.tprintf(
                "RSY_ACTION seat=%d sequence=%d applied=%v reason=%v",
                event.seat,
                event.sequence,
                event.applied,
                event.reason,
            ),
        )
    }
}

count_gameplay_effects :: proc(self: ^ReplayScrapyard, change: v.Change(net.Net_Event(game.Event))) {
    event := change.occurrence.value

    if event.kind == .Gameplay && event.value.kind == .Dash {
        if change.kind == .Begin {
            self.dash_effects += 1
        }

        if change.kind == .Cancel {
            self.dash_cancels += 1
        }
    }

    if event.kind == .Gameplay && event.value.kind == .Shot {
        if change.kind == .Begin {
            self.shot_effects += 1
        }

        if change.kind == .Cancel {
            self.shot_cancels += 1
        }

        trace_shot_query(self, change)
    }
}

trace_shot_query :: proc(self: ^ReplayScrapyard, change: v.Change(net.Net_Event(game.Event))) {
    event := change.occurrence.value

    if self.session.authority && scrap_int("RSY_TRACE_QUERY", 0) == 1 {
        tick := change.occurrence.id.tick
        record, recorded := r.read(&self.session.server.timeline, tick)
        input, sampled := r.read_input(&self.session.server.timeline, tick)
        at := int(event.value.seat - 1)

        if recorded && sampled && record.state.catalog.guns[record.state.players[at].gun_id].family >= 3 {
            v := input.views[at]
            player := record.state.players[at]
            floor := u64(0)

            for peer in self.session.server.peers {
                if peer.seat == u16(at + 1) {
                    floor = peer.rtt_floor_ms
                    break
                }
            }

            gd.print_str(
                fmt.tprintf(
                    "RSY_QUERY tick=%d seat=%d from=%d to=%d fraction=%d input=%v result=%v rtt_floor=%d rejected_views=%d expired_views=%d",
                    tick,
                    at + 1,
                    v.from,
                    v.to,
                    v.fraction,
                    v.status,
                    player.last_query,
                    floor,
                    self.session.server.stats.rejected_views,
                    self.session.server.stats.expired_views,
                ),
            )
        }
    }
}
