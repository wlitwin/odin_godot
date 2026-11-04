package p2p_provision_test

import "core:testing"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import pp "godot:replay/p2p/provision"
import rgd "godot:replay/godot"

@(test)
godot_provider_reads_committed_roster_on_every_admission :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer destroy(&f)
    provider := rgd.rendezvous_p2p_room_provider(&f.room)
    state, error := provider.state(provider.user, 0)
    testing.expect(t, error == .None && !state.active)
    g := guest(&f)
    state, error = provider.state(provider.user, 0)
    testing.expect(t, error == .None && state.active)
    reg, _ := pp.registry(&f.room)
    challenge := auth.Nonce {
        0 = 62,
    }
    proof := adm.proof(reg.match, g.identity, g.key, challenge, false)
    identity, code, accepted := provider.verify(provider.user, proof[:], challenge, false)
    testing.expect(
        t,
        accepted == .None &&
        identity == g.identity &&
        code == state.code &&
        provider.enabled(provider.user, g.identity),
    )
    lease: auth.Lease
    rpc: auth.Rpc_Client
    init_rpc(&f, g, &lease, &rpc)
    defer auth.rpc_client_destroy(&rpc)
    reply := call(&f, &rpc, {verb = .Challenge})
    reply = call(
        &f,
        &rpc,
        {verb = .Rebind, challenge = reply.challenge, incarnation = reply.registration_identity.incarnation},
    )
    testing.expect_value(t, reply.result, auth.Error.None)
    testing.expect(t, !provider.enabled(provider.user, g.identity) && provider.enabled(provider.user, lease.identity))
    _, _, accepted = provider.verify(provider.user, proof[:], challenge, false)
    testing.expect_value(t, accepted, auth.Error.Denied)
    fresh := adm.proof(reg.match, lease.identity, g.key, challenge, false)
    identity, code, accepted = provider.verify(provider.user, fresh[:], challenge, false)
    testing.expect(t, accepted == .None && identity == lease.identity && code == state.code)
    f.room.enrollment.service.coordinator.poisoned = true
    testing.expect(t, !provider.enabled(provider.user, lease.identity))
    _, error = provider.state(provider.user, 0)
    testing.expect_value(t, error, auth.Error.Storage)
}
