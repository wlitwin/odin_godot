package replay_authority_test

import "core:testing"
import auth "godot:replay/authority"
import tr "godot:replay/transport"

replacement_client :: proc(f: ^Rpc_Fixture) {
	old_wire := tr.memory_transport(&f.endpoints[2]); tr.close(&old_wire)
	auth.rpc_client_destroy(&f.clients[1])
	f.leases[1] = {}
	auth.lease_init(&f.leases[1], B, 44, 55, clock_source(&f.clock), false)
	auth.rpc_client_init(&f.clients[1], &f.leases[1], f.service.credentials[1].key,
	                     auth.Nonce{0 = 77}, tr.memory_transport(&f.endpoints[3]))
}

@(test)
challenge_proof_rebinds_only_identity_and_preserves_permissions :: proc(t: ^testing.T) {
	f: Rpc_Fixture; rpc_setup(&f); defer rpc_destroy(&f)
	rpc_call(&f, 1, {verb = .Query})
	old := f.ledger.record.members[1]
	stale_query, stale_count := f.clients[1].txb, f.clients[1].count
	replacement_client(&f)
	before := f.ledger.writes
	reply := rpc_call(&f, 1, {verb = .Challenge})
	testing.expect_value(t, reply.result, auth.Error.None)
	testing.expect_value(t, f.ledger.writes, before)
	testing.expect_value(t, reply.registration_identity, auth.Identity{B.member, B.incarnation + 1})
	wrong := reply.challenge; wrong[0] ~= 1
	testing.expect_value(t, rpc_call(&f, 1, {verb = .Rebind, incarnation = reply.registration_identity.incarnation, challenge = wrong}).result, auth.Error.Stale)
	reply = rpc_call(&f, 1, {verb = .Challenge})
	proof := auth.Command{verb = .Rebind, incarnation = reply.registration_identity.incarnation, challenge = reply.challenge}
	testing.expect_value(t, rpc_call(&f, 1, proof).result, auth.Error.None)
	testing.expect_value(t, f.leases[1].identity.incarnation, B.incarnation + 1)
	testing.expect_value(t, f.ledger.record.members[1].can_host, old.can_host)
	testing.expect_value(t, f.ledger.record.members[1].trusted_authority, old.trusted_authority)
	testing.expect_value(t, f.ledger.record.members[1].game_token_hash, old.game_token_hash)
	committed := f.ledger.writes
	auth.service_receive(&f.service, 3, stale_query[:stale_count])
	testing.expect_value(t, f.ledger.writes, committed)
	testing.expect_value(t, f.ledger.record.members[1].identity.incarnation, B.incarnation + 1)
	// Retry of the exact committed proof is idempotent even though its request
	// identity was the previous incarnation.
	auth.service_receive(&f.service, 4, f.clients[1].txb[:f.clients[1].count])
	testing.expect_value(t, f.ledger.writes, committed)
}

@(test)
active_owner_cannot_be_replaced_and_failed_registration_is_not_published :: proc(t: ^testing.T) {
	f: Rpc_Fixture; rpc_setup(&f); defer rpc_destroy(&f)
	rpc_call(&f, 0, {verb = .Start})
	testing.expect_value(t, rpc_call(&f, 0, {verb = .Challenge}).result, auth.Error.Busy)
	replacement_client(&f)
	reply := rpc_call(&f, 1, {verb = .Challenge})
	testing.expect_value(t, reply.result, auth.Error.None)
	f.ledger.fail = true
	testing.expect_value(t, rpc_call(&f, 1, {verb = .Rebind, incarnation = reply.registration_identity.incarnation, challenge = reply.challenge}).result, auth.Error.Storage)
	testing.expect_value(t, f.ledger.record.members[1].identity, B)
}

@(test)
registration_challenge_expires_and_does_not_survive_coordinator_restart :: proc(t: ^testing.T) {
	f: Rpc_Fixture; rpc_setup(&f); defer rpc_destroy(&f)
	reply := rpc_call(&f, 1, {verb = .Challenge})
	proof := auth.Command{verb = .Rebind, incarnation = reply.registration_identity.incarnation, challenge = reply.challenge}
	keys := [2]auth.Credential{f.service.credentials[0], f.service.credentials[1]}
	auth.service_destroy(&f.service)
	auth.service_init(&f.service, f.ledger.record, commit, &f.ledger, clock_source(&f.clock), tr.memory_transport(&f.endpoints[0]), keys[:])
	testing.expect_value(t, rpc_call(&f, 1, proof).result, auth.Error.Stale)
	reply = rpc_call(&f, 1, {verb = .Challenge})
	proof = {verb = .Rebind, incarnation = reply.registration_identity.incarnation, challenge = reply.challenge}
	for _ in 0 ..< 501 {rpc_step(&f)}
	testing.expect_value(t, rpc_call(&f, 1, proof).result, auth.Error.Stale)
	testing.expect_value(t, f.ledger.record.members[1].identity, B)
}
