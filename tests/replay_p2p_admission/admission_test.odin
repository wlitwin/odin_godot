package admission_test
import "core:testing"
import adm "godot:replay/p2p/admission"
import auth "godot:replay/authority"

registry :: proc() -> adm.Registry {
    reg := adm.Registry {
        match = {session = 123, content = 456, epoch = 7, members = {0 = 11, 1 = 22, 2 = 33}, count = 3},
    }

    for i in 0 ..< 3 {
        reg.credentials[i] = {
            identity = {reg.match.members[i], u64(101 + i)},
            key = {0 = u8(21 + i)},
        }
        reg.enabled[i] = true
    }

    return reg
}

@(test)
ordered_members_and_roles_are_authenticated :: proc(t: ^testing.T) {
    reg := registry()
    testing.expect(t, adm.registry_valid(&reg))
    nonce := auth.Nonce {
        0 = 42,
    }

    for credential, i in reg.credentials[:3] {
        bytes := adm.proof(reg.match, credential.identity, credential.key, nonce, i == 0)
        identity, code, error := adm.verify(&reg, bytes[:], nonce, i == 0)
        testing.expect(t, error == .None && identity == credential.identity && code == adm.code(reg.match))
        wrong := adm.proof(reg.match, credential.identity, credential.key, nonce, i != 0)
        _, _, error = adm.verify(&reg, wrong[:], nonce, i != 0)
        testing.expect_value(t, error, auth.Error.Denied)
    }
}

@(test)
proof_cannot_cross_match_content_roster_epoch_challenge_or_credential :: proc(t: ^testing.T) {
    reg := registry()
    who := reg.credentials[1]
    nonce := auth.Nonce {
        0 = 42,
    }

    for variation in 0 ..< 10 {
        match := reg.match
        identity := who.identity
        key := who.key

        switch variation {
        case 0:
            match.session += 1
        case 1:
            match.content += 1
        case 2:
            match.epoch += 1
        case 3:
            match.members[1], match.members[2] = match.members[2], match.members[1]
        case 4:
            match.count = 2
            match.members[2] = 0
        case 5:
            identity.incarnation -= 1
        case 6:
            identity.member = 33
        case 7:
            key[0] += 1
        }

        bytes := adm.proof(match, identity, key, nonce, false)
        challenge := nonce

        if variation == 8 {
            challenge[1] = 1
        }

        if variation == 9 {
            bytes[len(bytes) - 1] ~= 1
        }

        _, _, error := adm.verify(&reg, bytes[:], challenge, false)
        testing.expect_value(t, error, auth.Error.Denied)
    }

    bytes := adm.proof(reg.match, who.identity, who.key, nonce, false)
    _, _, error := adm.verify(&reg, bytes[:], {}, false)
    testing.expect_value(t, error, auth.Error.Denied)

    for length in 0 ..< len(bytes) {
        _, _, error = adm.verify(&reg, bytes[:length], nonce, false)
        testing.expect_value(t, error, auth.Error.Denied)
    }
}

@(test)
revocation_and_incarnation_changes_invalidate_old_proof_without_changing_match_code :: proc(t: ^testing.T) {
    reg := registry()
    who := reg.credentials[1]
    nonce := auth.Nonce {
        0 = 42,
    }
    code := adm.code(reg.match)
    bytes := adm.proof(reg.match, who.identity, who.key, nonce, false)
    reg.enabled[1] = false
    _, _, error := adm.verify(&reg, bytes[:], nonce, false)
    testing.expect_value(t, error, auth.Error.Denied)
    reg.enabled[1] = true
    reg.credentials[1].identity.incarnation += 1
    _, _, error = adm.verify(&reg, bytes[:], nonce, false)
    testing.expect_value(t, error, auth.Error.Denied)
    fresh := adm.proof(reg.match, reg.credentials[1].identity, who.key, nonce, false)
    identity, actual, accepted := adm.verify(&reg, fresh[:], nonce, false)
    testing.expect(t, accepted == .None && actual == code && identity == reg.credentials[1].identity)
}

@(test)
invalid_registry_cannot_admit_members :: proc(t: ^testing.T) {
    for variant in 0 ..< 7 {
        reg := registry()

        switch variant {
        case 0:
            reg.match.count = 1
        case 1:
            reg.match.members[2] = reg.match.members[1]
        case 2:
            reg.match.members[7] = 99
        case 3:
            reg.credentials[1].key = {}
        case 4:
            reg.credentials[1].identity.incarnation = 0
        case 5:
            reg.credentials[1].identity.member = 33
        case 6:
            reg.enabled[7] = true
        }

        testing.expect(t, !adm.registry_valid(&reg))
    }
}
