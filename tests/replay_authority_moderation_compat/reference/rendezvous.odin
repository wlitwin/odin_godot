package authority_reference

import "core:crypto"
import "core:crypto/hmac"
import rec "godot:replay/recovery"

RENDEZVOUS_BYTES :: 116
// The signaling connection must issue a fresh challenge, expire it, and consume
// it once. This proof binds a create/join request to that connection's challenge,
// current room/content/authority term, and the registered process identity.
Rendezvous_Proof :: [RENDEZVOUS_BYTES]u8

rendezvous_code :: proc(view: View) -> [64]u8 {
    digest := rendezvous_digest(view)
    result: [64]u8
    alphabet := "0123456789abcdef"

    for byte, i in digest {
        result[2 * i] = alphabet[byte >> 4]
        result[2 * i + 1] = alphabet[byte & 15]
    }

    return result
}

rendezvous_proof :: proc(
    view: View,
    identity: Identity,
    key: Key,
    challenge: Nonce,
    create: bool,
) -> Rendezvous_Proof {
    proof: Rendezvous_Proof
    challenge := challenge
    proof[0] = 1
    proof[1] = create ? 1 : 2
    rendezvous_put(proof[4:12], view.room)
    rendezvous_put(proof[12:20], view.epoch)
    rendezvous_put(proof[20:28], identity.member)
    rendezvous_put(proof[28:36], identity.incarnation)
    digest := rendezvous_digest(view)
    copy(proof[36:68], digest[:])
    copy(proof[68:84], challenge[:])
    tag := rendezvous_mac(key, proof[:84])
    copy(proof[84:], tag[:])
    return proof
}

// Use alongside Service on the same trusted coordinator host. A valid room name
// alone never authorizes room creation. No store mutation or lease renewal occurs.
rendezvous_verify :: proc(s: ^Service, proof: []u8, challenge: Nonce, create: bool) -> (Identity, [64]u8, Error) {
    if !s.ready {
        return {}, {}, .Not_Ready
    }

    expected_kind := u8(create ? 1 : 2)

    if len(proof) != RENDEZVOUS_BYTES || proof[0] != 1 || proof[1] != expected_kind || proof[2] != 0 || proof[3] != 0 {
        return {}, {}, .Invalid
    }

    nonce := challenge

    if !nonzero(nonce[:]) || crypto.compare_constant_time(proof[68:84], nonce[:]) != 1 {
        return {}, {}, .Denied
    }

    identity := Identity{rendezvous_get(proof[20:28]), rendezvous_get(proof[28:36])}
    key: Key
    found := false

    for credential in s.credentials {
        if credential.identity.member == identity.member {
            key = credential.key
            found = true
            break
        }
    }

    if !found {
        return {}, {}, .Denied
    }

    tag := rendezvous_mac(key, proof[:84])

    if crypto.compare_constant_time(tag[:], proof[84:]) != 1 {
        return {}, {}, .Denied
    }

    now, valid := s.clock.read(s.clock.user)

    if !valid {
        s.coordinator.poisoned = true
        s.coordinator.active = false
        return {}, {}, .Clock
    }

    view, err := coordinator_view(&s.coordinator, now)

    if err != .None {
        return {}, {}, err
    }

    if view.remaining_ms == 0 ||
       view.room != rendezvous_get(proof[4:12]) ||
       view.epoch != rendezvous_get(proof[12:20]) {
        return {}, {}, .Stale
    }

    digest := rendezvous_digest(view)

    if crypto.compare_constant_time(digest[:], proof[36:68]) != 1 {
        return {}, {}, .Denied
    }

    enabled := false

    for member in s.coordinator.record.members {
        if member.identity == identity && member.enabled {
            enabled = true
            break
        }
    }

    if !enabled || (create && view.owner != identity) {
        return {}, {}, .Denied
    }

    return identity, rendezvous_code(view), .None
}

@(private)
rendezvous_digest :: proc(view: View) -> [32]u8 {
    data: [40]u8
    rendezvous_put(data[0:8], view.room)
    rendezvous_put(data[8:16], view.content)
    rendezvous_put(data[16:24], view.epoch)
    rendezvous_put(data[24:32], view.owner.member)
    rendezvous_put(data[32:40], view.owner.incarnation)
    return rec.hash(data[:])
}

@(private)
rendezvous_mac :: proc(key: Key, data: []u8) -> [32]u8 {
    key := key
    ctx: hmac.Context
    hmac.init(&ctx, .SHA256, key[:])
    domain := "replay-rendezvous-v1"
    hmac.update(&ctx, transmute([]u8)domain)
    hmac.update(&ctx, data)
    result: [32]u8
    hmac.final(&ctx, result[:])
    return result
}

@(private)
rendezvous_put :: proc(bytes: []u8, value: u64) {
    for &byte, i in bytes {
        byte = u8(value >> uint(i * 8))
    }
}

@(private)
rendezvous_get :: proc(bytes: []u8) -> u64 {
    value := u64(0)

    for byte, i in bytes {
        value |= u64(byte) << uint(i * 8)
    }

    return value
}
