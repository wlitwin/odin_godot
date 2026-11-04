package p2p_provision_test

import "core:testing"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import pp "godot:replay/p2p/provision"
import tr "godot:replay/transport"

client_pump :: proc(f: ^Fixture, c: ^pp.Client, frames: int = 1, deliver: bool = true) {
    for _ in 0 ..< frames {
        f.now += 10
        assert(tr.memory_advance(&f.memory, f.now / 10))
        pp.client_frame(c)
        wire := tr.memory_transport(&f.endpoints[0])
        buffer: [tr.MAX_PACKET_BYTES]u8

        for _ in 0 ..< 32 {
            packet := tr.receive(&wire, buffer[:])

            if packet.state != .Received {
                break
            }

            if deliver {
                pp.control_receive(&f.room, packet.from, buffer[:packet.count])
            }
        }
    }
}

@(test)
client_registers_waits_for_fixed_roster_and_keeps_registration_current :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer destroy(&f)
    g, _ := pp.creator_grant(&f.room, ADMIN)
    c: pp.Client
    defer pp.client_close(&c)
    testing.expect(t, pp.client_open(&c, g, 2, {0 = 18}, {&f, clock}, tr.memory_transport(&f.endpoints[1])))
    client_pump(&f, &c, 100)
    testing.expect_value(t, c.phase, pp.Client_Phase.Waiting)
    _, _, ready := pp.client_admission(&c)
    testing.expect(t, !ready)
    testing.expect(
        t,
        c.lease.identity == (auth.Identity{1, 2}) && c.grant == g && f.room.bundle.enrollment.record.epoch == 0,
    )
    guest(&f)
    client_pump(&f, &c, 100)
    match, credential, available := pp.client_admission(&c)
    reg, _ := pp.registry(&f.room)
    testing.expect(t, available && match == reg.match && credential == reg.credentials[0])
    writes := f.ledger.writes
    client_pump(&f, &c, 100)
    testing.expect(t, c.phase == .Ready && f.ledger.writes > writes && f.room.bundle.enrollment.record.epoch == 0)
}

@(test)
fresh_client_reuses_durable_grant_but_registers_new_incarnation :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer destroy(&f)
    g := guest(&f)
    c: pp.Client
    defer pp.client_close(&c)
    assert(pp.client_open(&c, g, 2, {0 = 18}, {&f, clock}, tr.memory_transport(&f.endpoints[1])))
    client_pump(&f, &c, 100)
    match, credential, ready := pp.client_admission(&c)
    testing.expect(t, ready && credential.identity == (auth.Identity{2, 2}))
    pp.client_close(&c)
    restart(&f)
    assert(pp.client_open(&c, g, 2, {0 = 19}, {&f, clock}, tr.memory_transport(&f.endpoints[1])))
    client_pump(&f, &c, 100)
    current, new_credential, available := pp.client_admission(&c)
    testing.expect(
        t,
        available &&
        current == match &&
        new_credential.identity == (auth.Identity{2, 3}) &&
        new_credential.key == credential.key,
    )
    challenge := auth.Nonce {
        0 = 68,
    }
    old := adm.proof(match, credential.identity, credential.key, challenge, false)
    reg, _ := pp.registry(&f.room)
    _, _, denied := adm.verify(&reg, old[:], challenge, false)
    testing.expect_value(t, denied, auth.Error.Denied)
}

@(test)
client_refuses_authority_grants_and_bounds_unanswered_registration :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer destroy(&f)
    g := guest(&f)

    for variation in 0 ..< 5 {
        altered := g

        switch variation {
        case 0:
            altered.can_host = true
        case 1:
            altered.trusted_authority = true
        case 2:
            altered.infrastructure = true
        case 3:
            altered.key = {}
        case 4:
            altered.identity.member = 3
        }

        c: pp.Client
        testing.expect(t, !pp.client_open(&c, altered, 2, {0 = 18}, {&f, clock}, tr.memory_transport(&f.endpoints[1])))
        pp.client_close(&c)
    }

    c: pp.Client
    defer pp.client_close(&c)
    assert(pp.client_open(&c, g, 2, {0 = 18}, {&f, clock}, tr.memory_transport(&f.endpoints[1])))
    client_pump(&f, &c, 1010, false)
    testing.expect(t, c.phase == .Failed && c.control_error == .Busy)
    _, _, ready := pp.client_admission(&c)
    testing.expect(t, !ready)
}
