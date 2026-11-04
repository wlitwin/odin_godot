package replay_recipes

import replay "godot:replay"
import net "godot:replay/net"
import p2p "godot:replay/p2p"
import transport "godot:replay/transport"
import view "godot:replay/view"
import replaygd "godot:replay/godot"
import storagegd "godot:replay/godot/storage"
import hello "godot:examples/replay_hello/shared/hello"
import duel "godot:examples/replay_duel/shared/duel"

Hello_Session :: replaygd.Session(hello.World, hello.Controls, hello.Action, hello.Event, 2)
Hello_Room :: replaygd.Room(hello.World, hello.Controls, hello.Action, hello.Event, 2)

// Keep the destination owner stable and close it on every failed/successful
// lifetime. These examples return errors to the caller instead of hiding them.
open_session :: proc(session: ^Hello_Session, role: replaygd.Session_Role, token: net.Token) -> net.Error {
    options := replaygd.SESSION_OPTIONS
    options.role, options.token = role, token
    options.network.content = 1 // Replace with the game's versioned content ID.
    return replaygd.session_open(
        session,
        replay.Frame(hello.World){state = hello.initial()},
        hello.network_model(),
        options,
    )
}

session_frame :: proc(
    session: ^Hello_Session,
    dt: f64,
    controls: hello.Controls,
    consume: proc(_: view.Change(net.Net_Event(hello.Event))),
) -> net.Error {
    if error := replaygd.session_frame(session, dt, controls); error != .None {
        return error
    }

    changes: [64]view.Change(net.Net_Event(hello.Event))

    for {
        count := replaygd.session_changes(session, changes[:])

        if count == 0 {
            break
        }

        for change in changes[:count] {
            if consume != nil {
                consume(change)
            }
        }
    }

    // Present the detached session_state after draining changes; do not modify
    // session.server/client timeline values to smooth a scene transform.
    return .None
}

open_room_after_enrollment :: proc(room: ^Hello_Room, party: ^replaygd.Party) -> net.Error {
    session := replaygd.SESSION_OPTIONS
    session.role = .Client
    session.network.content = party.config.content
    options, ready := replaygd.party_room_options(party, session)

    if !ready {
        return .Not_Initialized
    }

    return replaygd.room_open(room, replay.Frame(hello.World){state = hello.initial()}, hello.network_model(), options)
}

// The native Direct transport exposes stable member IDs only after admission.
// Pump Party before Direct; initialize once. Browser users obtain the analogous
// admitted bindings from RTC and use the same Runner API.
open_p2p_after_native_admission :: proc(
    peer: ^p2p.Runner(duel.World, duel.Input, duel.Event, 2),
    party: ^replaygd.P2P_Party,
    direct: ^replaygd.P2P_Direct,
) -> p2p.Error {
    identity, admitted := replaygd.p2p_direct_identity(direct)

    if !admitted || !party.ready || identity.member != direct.remote {
        return .Not_Ready
    }

    cfg := p2p.DEFAULT_CONFIG
    cfg.session, cfg.epoch, cfg.content =
        party.authorization.match.session, party.authorization.match.epoch, duel.CONTENT
    roster := [2]transport.Peer_Id {
        transport.Peer_Id(party.authorization.match.members[0]),
        transport.Peer_Id(party.authorization.match.members[1]),
    }
    local := u16(party.authorization.identity.member == u64(roster[0]) ? 0 : 1)
    return p2p.init(
        peer,
        replay.Frame(duel.World){state = duel.initial(42)},
        duel.model(),
        roster,
        local,
        replaygd.p2p_direct_transport(direct),
        cfg,
    )
}

// Authoritative archives and P2P participant archives are intentionally different
// APIs. Neither operation replaces the application's storage/authority decision.
save_authority :: proc(session: ^Hello_Session, path: string) -> storagegd.Storage_Result {
    return replaygd.session_save(session, path)
}

planned_handoff :: proc(room: ^Hello_Room) -> net.Error {
    return replaygd.room_handoff(room)
}

close_room :: proc(room: ^Hello_Room) {
    replaygd.room_close(room)
}

close_session :: proc(session: ^Hello_Session) {
    replaygd.session_close(session)
}
