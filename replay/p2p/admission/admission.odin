package replay_p2p_admission

import "core:crypto"
import "core:crypto/hmac"
import auth "godot:replay/authority"
import rec "godot:replay/recovery"

MAX_PLAYERS :: 8

// Ordered members are stable for the match. Credential incarnations can change
// through the trusted admission owner without changing the simulation roster.
Match :: struct {
    session, content, epoch: u64,
    members:                 [MAX_PLAYERS]u64,
    count:                   u8,
}

Registry :: struct {
    match:       Match,
    credentials: [MAX_PLAYERS]auth.Credential,
    enabled:     [MAX_PLAYERS]bool,
}

Proof :: [116]u8

match_valid :: proc(m: Match) -> bool {
    m := m

    if m.session == 0 || m.content == 0 || m.epoch == 0 || m.count < 2 || m.count > MAX_PLAYERS {
        return false
    }

    for member, i in m.members {
        if i >= int(m.count) {
            if member != 0 {
                return false
            }

            continue
        }

        if member == 0 {
            return false
        }

        for previous in m.members[:i] {
            if member == previous {
                return false
            }
        }
    }

    return true
}

registry_valid :: proc(reg: ^Registry) -> bool {
    if reg == nil || !match_valid(reg.match) {
        return false
    }

    for credential, i in reg.credentials {
        if i >= int(reg.match.count) {
            if credential != (auth.Credential{}) || reg.enabled[i] {
                return false
            }

            continue
        }

        key := credential.key

        if credential.identity.member != reg.match.members[i] ||
           !auth.identity_valid(credential.identity) ||
           !nonzero(key[:]) {
            return false
        }
    }

    return true
}

enabled :: proc(reg: ^Registry, identity: auth.Identity) -> bool {
    if !registry_valid(reg) {
        return false
    }

    for credential, i in reg.credentials {
        if credential.identity == identity {
            return reg.enabled[i]
        }
    }

    return false
}

code :: proc(m: Match) -> [64]u8 {
    digest := digest(m)
    result: [64]u8
    alphabet := "0123456789abcdef"

    for byte, i in digest {
        result[2 * i], result[2 * i + 1] = alphabet[byte >> 4], alphabet[byte & 15]
    }

    return result
}

proof :: proc(m: Match, identity: auth.Identity, key: auth.Key, challenge: auth.Nonce, create: bool) -> Proof {
    out: Proof
    nonce := challenge
    out[0], out[1] = 2, create ? 1 : 2
    put(out[4:12], m.session)
    put(out[12:20], m.epoch)
    put(out[20:28], identity.member)
    put(out[28:36], identity.incarnation)
    hash := digest(m)
    copy(out[36:68], hash[:])
    copy(out[68:84], nonce[:])
    tag := mac(key, out[:84])
    copy(out[84:], tag[:])
    return out
}

// Stateless verification: the frontend must issue a fresh random challenge,
// bind it to the physical connection, expire it, and consume it exactly once.
verify :: proc(
    reg: ^Registry,
    bytes: []u8,
    challenge: auth.Nonce,
    create: bool,
) -> (
    auth.Identity,
    [64]u8,
    auth.Error,
) {
    if !registry_valid(reg) {
        return {}, {}, .Invalid
    }

    if len(bytes) != size_of(Proof) ||
       bytes[0] != 2 ||
       bytes[1] != (create ? u8(1) : u8(2)) ||
       bytes[2] != 0 ||
       bytes[3] != 0 {
        return {}, {}, .Denied
    }

    nonce := challenge

    if !nonzero(nonce[:]) || crypto.compare_constant_time(bytes[68:84], nonce[:]) != 1 {
        return {}, {}, .Denied
    }

    identity := auth.Identity{get(bytes[20:28]), get(bytes[28:36])}
    key: auth.Key
    found := false

    for credential, i in reg.credentials {
        if credential.identity == identity && reg.enabled[i] {
            key, found = credential.key, true
            break
        }
    }

    if !found ||
       (create && identity.member != reg.match.members[0]) ||
       (!create && identity.member == reg.match.members[0]) {
        return {}, {}, .Denied
    }

    tag := mac(key, bytes[:84])

    if crypto.compare_constant_time(tag[:], bytes[84:]) != 1 {
        return {}, {}, .Denied
    }

    expected := digest(reg.match)

    if get(bytes[4:12]) != reg.match.session ||
       get(bytes[12:20]) != reg.match.epoch ||
       crypto.compare_constant_time(expected[:], bytes[36:68]) != 1 {
        return {}, {}, .Denied
    }

    return identity, code(reg.match), .None
}

@(private)
digest :: proc(m: Match) -> [32]u8 {
    bytes: [89]u8
    put(bytes[0:8], m.session)
    put(bytes[8:16], m.content)
    put(bytes[16:24], m.epoch)
    bytes[24] = m.count

    for member, i in m.members {
        put(bytes[25 + i * 8:33 + i * 8], member)
    }

    return rec.hash(bytes[:])
}

@(private)
mac :: proc(key: auth.Key, bytes: []u8) -> [32]u8 {
    key := key
    ctx: hmac.Context
    hmac.init(&ctx, .SHA256, key[:])
    domain := "replay-p2p-admission-v1"
    hmac.update(&ctx, transmute([]u8)domain)
    hmac.update(&ctx, bytes)
    out: [32]u8
    hmac.final(&ctx, out[:])
    return out
}

@(private)
put :: proc(bytes: []u8, value: u64) {
    for &byte, i in bytes {
        byte = u8(value >> uint(i * 8))
    }
}

@(private)
get :: proc(bytes: []u8) -> u64 {
    value: u64

    for byte, i in bytes {
        value |= u64(byte) << uint(i * 8)
    }

    return value
}

@(private)
nonzero :: proc(bytes: []u8) -> bool {
    value: u8

    for byte in bytes {
        value |= byte
    }

    return value != 0
}
