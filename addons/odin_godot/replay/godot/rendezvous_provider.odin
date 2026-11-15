package replay_godot

import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import wiregd "godot:replay/godot/internal/wire"
import transportgd "godot:replay/godot/transport"

Rendezvous_State :: struct {
    epoch:  u64,
    code:   [64]u8,
    active: bool,
}

// A trusted provider owns credential storage, roster updates and revocation.
// Callbacks and user must remain alive at stable addresses while open.
Rendezvous_Provider :: struct {
    user:    rawptr,
    clock:   auth.Clock_Source,
    state:   proc(user: rawptr, now: u64) -> (Rendezvous_State, auth.Error),
    enabled: proc(user: rawptr, identity: auth.Identity) -> bool,
    verify:  proc(
        user: rawptr,
        proof: []u8,
        challenge: auth.Nonce,
        create: bool,
    ) -> (
        auth.Identity,
        [64]u8,
        auth.Error,
    ),
}

@(private)
rendezvous_service_provider :: proc(s: ^auth.Service) -> Rendezvous_Provider {
    return {user = s, clock = s.clock, state = proc(user: rawptr, now: u64) -> (Rendezvous_State, auth.Error) {
            s := cast(^auth.Service)user
            view, error := auth.coordinator_view(&s.coordinator, now)
            return {view.epoch, auth.rendezvous_code(view), view.remaining_ms != 0}, error
        }, enabled = proc(user: rawptr, identity: auth.Identity) -> bool {
            s := cast(^auth.Service)user

            for member in s.coordinator.record.members {
                if member.identity == identity && member.enabled {
                    return true
                }
            }

            return false
        }, verify = proc(
            user: rawptr,
            proof: []u8,
            challenge: auth.Nonce,
            create: bool,
        ) -> (
            auth.Identity,
            [64]u8,
            auth.Error,
        ) {
            return auth.rendezvous_verify(cast(^auth.Service)user, proof, challenge, create)
        }}
}

// Fixed-roster P2P admission has no gameplay authority lease. This provider
// admits transport identities only; it does not choose or simulate a world.
rendezvous_p2p_provider :: proc(registry: ^adm.Registry, clock: auth.Clock_Source) -> Rendezvous_Provider {
    return {user = registry, clock = clock, state = proc(user: rawptr, now: u64) -> (Rendezvous_State, auth.Error) {
            reg := cast(^adm.Registry)user

            if !adm.registry_valid(reg) {
                return {}, .Invalid
            }

            return {reg.match.epoch, adm.code(reg.match), true}, .None
        }, enabled = proc(user: rawptr, identity: auth.Identity) -> bool {
            return adm.enabled(cast(^adm.Registry)user, identity)
        }, verify = proc(
            user: rawptr,
            proof: []u8,
            challenge: auth.Nonce,
            create: bool,
        ) -> (
            auth.Identity,
            [64]u8,
            auth.Error,
        ) {
            return adm.verify(cast(^adm.Registry)user, proof, challenge, create)
        }}
}

Rtc_P2P_Auth :: struct {
    match:    adm.Match,
    identity: auth.Identity,
    key:      auth.Key,
}

rtc_p2p_config :: proc(a: ^Rtc_P2P_Auth, url: string, create: bool) -> transportgd.Rtc_Config {
    code := adm.code(a.match)
    room := make([]u8, len(code), context.temp_allocator)
    copy(room, code[:])
    return {
        url = url,
        room = string(room),
        host = create,
        require_identity = true,
        resume_signaling = true,
        authorization_user = a,
        authorize = proc(user: rawptr, challenge, room: string, create: bool) -> string {
            a := cast(^Rtc_P2P_Auth)user
            nonce: auth.Nonce

            if !adm.match_valid(a.match) || !wiregd.hex_decode(nonce[:], challenge) {
                return ""
            }

            expected := adm.code(a.match)

            if room != string(expected[:]) {
                return ""
            }

            proof := adm.proof(a.match, a.identity, a.key, nonce, create)
            return wiregd.hex_encode(proof[:])
        },
    }
}
