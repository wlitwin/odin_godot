package replay_provision_test

import "core:testing"
import p "godot:replay/provision"

@(test)
short_code_v1_vectors_and_user_input_normalization :: proc(t: ^testing.T) {
    code, valid := p.short_code({0 = 1}, 55)
    testing.expect(t, valid && string(code[:]) == "H86Q3")
    guest, guest_ok := p.short_ticket_parse(" h86q3\n", 55)
    watch, watch_ok := p.short_ticket_parse("H86Q3", 55, 1)
    testing.expect(t, guest_ok && watch_ok && guest.room == 0x94e929b3c65acc76 && guest.room == watch.room)
    expected := p.Secret {
        0x35,
        0x1c,
        0xfb,
        0xe7,
        0x00,
        0x4f,
        0x19,
        0x83,
        0xa8,
        0x00,
        0x4c,
        0x7f,
        0x7e,
        0xa7,
        0x11,
        0x2d,
        0x9e,
        0x47,
        0x05,
        0x8d,
        0x11,
        0x09,
        0x81,
        0x78,
        0x0e,
        0x6f,
        0x81,
        0xd9,
        0xf4,
        0xc2,
        0x15,
        0x4a,
    }
    testing.expect_value(t, guest.secret, expected)
    testing.expect(t, guest.secret != watch.secret)
    other, _ := p.short_ticket_parse("H86Q3", 56)
    testing.expect(t, other.room != guest.room && other.secret != guest.secret)

    for text in ([7]string{"", "H86Q", "H86Q30", "H8OQ3", "H81Q3", "H8 Q3", "\u014186Q3"}) {
        _, ok := p.short_ticket_parse(text, 55)
        testing.expect(t, !ok)
    }

    _, valid = p.short_ticket_parse("H86Q3", 55, 2)
    testing.expect(t, !valid)
    _, valid = p.short_code({}, 55)
    testing.expect(t, !valid)
    _, valid = p.short_ticket_parse("H86Q3", 0)
    testing.expect(t, !valid)
}

@(test)
short_code_uses_existing_protocol_single_use_and_independent_member_credentials :: proc(t: ^testing.T) {
    f: Hub_Fixture
    hub_setup(&f)
    defer hub_destroy(&f)
    code, ok := p.short_code(ADMIN, 55)
    assert(ok)
    ticket, valid := p.short_ticket_parse(string(code[:]), 55)
    assert(valid)
    q := create_request(ticket.room)
    creator := hub_call(&f, q)
    testing.expect_value(t, creator.result, p.Error.None)
    url, _ := p.service_url("wss://rooms.example.test")
    record := p.Enrollment_Record {
        version  = p.ENROLLMENT_VERSION,
        revision = 2,
        state    = .Ready,
        service  = url,
        request  = q,
        grant    = creator.grant,
    }
    invite, issued := p.creator_short_invite(record)
    assert(issued)
    testing.expect(
        t,
        p.request_valid(invite) && invite.role == .Player && invite.uses == 1 && invite.ticket == ticket.secret,
    )
    testing.expect_value(t, hub_call(&f, invite).result, p.Error.None)
    join := p.Request {
        version  = p.PROTOCOL,
        verb     = .Join,
        room     = ticket.room,
        content  = 55,
        claim    = CLAIM,
        ticket   = ticket.secret,
        endpoint = address(45002),
    }
    guest := hub_call(&f, join)
    testing.expect_value(t, guest.result, p.Error.None)
    testing.expect(t, !guest.grant.can_host && !guest.grant.trusted_authority && guest.grant.key != creator.grant.key)
    before := f.ledger.writes
    testing.expect_value(t, hub_call(&f, join).grant, guest.grant)
    testing.expect_value(t, f.ledger.writes, before)
    testing.expect_value(t, hub_call(&f, invite).result, p.Error.None)
    join.claim = {
        0 = 77,
    }
    join.endpoint = address(45003)
    testing.expect_value(t, hub_call(&f, join).result, p.Error.Denied)
    watch_invite, watch_valid := p.creator_short_invite(record, 1)
    assert(watch_valid)
    testing.expect_value(t, hub_call(&f, watch_invite).result, p.Error.None)
    watch, _ := p.short_ticket_parse(string(code[:]), 55, 1)
    join.ticket = watch.secret
    observer := hub_call(&f, join)
    testing.expect_value(t, observer.result, p.Error.None)
    testing.expect(
        t,
        !observer.grant.can_host && !observer.grant.trusted_authority && observer.grant.key != guest.grant.key,
    )
    _, invalid := p.creator_short_invite(record, 2)
    testing.expect(t, !invalid)
    // The published code is never an administrator claim.
    f.clock.now += 1000 // Refill the existing per-peer limiter before testing authorization.
    invite.claim = ticket.secret
    testing.expect_value(t, hub_call(&f, invite).result, p.Error.Denied)
}

@(test)
short_code_collision_cannot_replace_an_existing_creator :: proc(t: ^testing.T) {
    // Independent HMAC fixtures found by a deterministic birthday search.
    first := p.Secret {
        0 = 0x76,
        1 = 0x05,
    }
    second := p.Secret {
        0 = 0x17,
        1 = 0x10,
    }
    first_code, _ := p.short_code(first, 55)
    second_code, _ := p.short_code(second, 55)
    testing.expect(t, first_code == second_code && string(first_code[:]) == "VGP3G")
    f: Hub_Fixture
    hub_setup(&f)
    defer hub_destroy(&f)
    ticket, _ := p.short_ticket_parse(string(first_code[:]), 55)
    q := create_request(ticket.room)
    q.claim = first
    original := hub_call(&f, q)
    assert(original.result == .None)
    before := f.ledger.writes
    q.claim = second
    testing.expect_value(t, hub_call(&f, q).result, p.Error.Denied)
    testing.expect_value(t, f.ledger.writes, before)
    q.claim = first
    testing.expect_value(t, hub_call(&f, q).grant, original.grant)
}
