package replay_godot

import "core:crypto"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import pp "godot:replay/p2p/provision"

// Borrows the stable room owner. Every callback reads committed enrollment;
// registration changes cannot leave a cached credential admitted to signaling.
// A waiting room is inactive until all seats exist. This grants no game lease.
rendezvous_p2p_room_provider :: proc(room: ^pp.Room) -> Rendezvous_Provider {
    if room == nil || !room.ready {return {}}
    return {user = room, clock = room.enrollment.service.clock,
        state = proc(user: rawptr, now: u64) -> (Rendezvous_State, auth.Error) {
            reg, error := pp.registry(cast(^pp.Room)user)
            defer crypto.zero_explicit(&reg, size_of(reg))
            if error == .Not_Ready {return {}, .None}
            if error != .None {return {}, .Storage}
            return {reg.match.epoch, adm.code(reg.match), true}, .None
        },
        enabled = proc(user: rawptr, identity: auth.Identity) -> bool {
            reg, error := pp.registry(cast(^pp.Room)user)
            defer crypto.zero_explicit(&reg, size_of(reg))
            return error == .None && adm.enabled(&reg, identity)
        },
        verify = proc(user: rawptr, proof: []u8, challenge: auth.Nonce, create: bool) -> (auth.Identity, [64]u8, auth.Error) {
            reg, error := pp.registry(cast(^pp.Room)user)
            defer crypto.zero_explicit(&reg, size_of(reg))
            if error != .None {return {}, {}, .Denied}
            return adm.verify(&reg, proof, challenge, create)
        },
    }
}
