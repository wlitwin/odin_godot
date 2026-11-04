package replay_godot_transport

import wiregd "godot:replay/godot/internal/wire"

import auth "godot:replay/authority"

// Keep this owner alive at a stable address while its RTC connection is open.
// Obtain view from the authenticated control client. The relay independently
// verifies current authority, membership and process incarnation.
Rtc_Grant_Auth :: struct {
    view:     auth.View,
    identity: auth.Identity,
    key:      auth.Key,
}

rtc_grant_config :: proc(a: ^Rtc_Grant_Auth, url: string, create: bool) -> Rtc_Config {
    code := auth.rendezvous_code(a.view)
    room := make([]u8, len(code), context.temp_allocator)
    copy(room, code[:])
    return {
        url = url,
        room = string(room),
        host = create,
        resume_signaling = true,
        authorization_user = a,
        authorize = rtc_grant_authorize,
    }
}

@(private)
rtc_grant_authorize :: proc(user: rawptr, challenge, room: string, create: bool) -> string {
    a := cast(^Rtc_Grant_Auth)user
    nonce: auth.Nonce

    if !wiregd.hex_decode(nonce[:], challenge) {
        return ""
    }

    code := auth.rendezvous_code(a.view)

    if room != string(code[:]) {
        return ""
    }

    proof := auth.rendezvous_proof(a.view, a.identity, a.key, nonce, create)
    return wiregd.hex_encode(proof[:])
}
