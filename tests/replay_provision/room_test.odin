package replay_provision_test

import "core:testing"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import tr "godot:replay/transport"

Ledger :: struct {bundle: p.Bundle, writes: int, fail, lost_ack: bool}
Clock :: struct {now: u64}
Random :: struct {value: u8, fail: bool}
ADMIN :: p.Secret{0 = 41}
INVITE :: p.Secret{0 = 42}
CLAIM :: p.Secret{0 = 43}

commit :: proc(user: rawptr, expected: u64, next: p.Bundle) -> bool {
	l := cast(^Ledger)user
	if l.fail || l.bundle.record.revision != expected || next.record.revision != expected + 1 || !p.bundle_valid(next) {return false}
	l.bundle = next; l.writes += 1
	return !l.lost_ack
}
clock_read :: proc(user: rawptr) -> (u64, bool) {return (cast(^Clock)user).now, true}
random_read :: proc(user: rawptr, dst: []u8) -> bool {
	r := cast(^Random)user
	if r.fail {return false}
	r.value += 1; for &b in dst {b = r.value}
	return true
}
address :: proc(port: u16 = 45001) -> auth.Endpoint {e, ok := auth.endpoint("127.0.0.1", port); assert(ok); return e}
setup :: proc(r: ^p.Room, l: ^Ledger, c: ^Clock, rng: ^Random, dedicated: bool = false, wire: tr.Transport = {}) {
	policy := auth.DEFAULT_POLICY; if dedicated {policy.mode = .Dedicated}
	b, err := p.make_room(44, 55, ADMIN, address(), policy, {rng, random_read}); assert(err == .None)
	assert(p.open(r, b, commit, l, {c, clock_read}, wire, {rng, random_read}) == .None)
}

@(test)
join_retries_preserve_credentials_and_permissions_through_revocation_and_restart :: proc(t: ^testing.T) {
	r: p.Room; l: Ledger; c: Clock; rng: Random
	setup(&r, &l, &c, &rng); defer p.close(&r)
	ticket, err := p.invite(&r, ADMIN, INVITE, .Player)
	testing.expect_value(t, err, p.Error.None)
	g, error := p.join(&r, ticket, CLAIM, address(45002))
	testing.expect_value(t, error, p.Error.None)
	testing.expect(t, g.identity == (auth.Identity{2, 1}) && !g.can_host && !g.trusted_authority && !g.infrastructure)
	before := l.writes
	retry: p.Grant
	retry, error = p.join(&r, ticket, CLAIM, address(45002))
	testing.expect_value(t, error, p.Error.None); testing.expect_value(t, retry, g)
	testing.expect_value(t, l.writes, before)
	_, error = p.join(&r, ticket, {0 = 99}, address(45003)); testing.expect_value(t, error, p.Error.Denied)
	_, error = p.join(&r, ticket, CLAIM, address(45004)); testing.expect_value(t, error, p.Error.Denied)
	testing.expect_value(t, p.revoke(&r, ADMIN, ticket), p.Error.None)
	p.close(&r)
	testing.expect_value(t, p.open(&r, l.bundle, commit, &l, {&c, clock_read}, entropy = {&rng, random_read}), p.Error.None)
	retry, error = p.join(&r, ticket, CLAIM, address(45002))
	testing.expect_value(t, error, p.Error.None); testing.expect_value(t, retry, g)
	m := r.bundle.record.members[1]; m.enabled = false
	testing.expect_value(t, auth.coordinator_member(&r.service.coordinator, m, c.now), auth.Error.None)
	_, error = p.join(&r, ticket, CLAIM, address(45002)); testing.expect_value(t, error, p.Error.Denied)
	testing.expect(t, !l.bundle.record.members[1].enabled && l.bundle.enrollments[1].key == g.key)
}

@(test)
rebound_identity_and_disabled_roster_survive_restart_and_later_admission :: proc(t: ^testing.T) {
	r: p.Room; l: Ledger; c: Clock; rng: Random
	setup(&r, &l, &c, &rng); defer p.close(&r)
	ticket, _ := p.invite(&r, ADMIN, INVITE, .Player, 3)
	g, _ := p.join(&r, ticket, CLAIM, address(45002))
	m := r.bundle.record.members[1]; m.identity.incarnation = 9; m.endpoint = address(45009)
	testing.expect_value(t, auth.coordinator_member(&r.service.coordinator, m, 0), auth.Error.None)
	retry, err := p.join(&r, ticket, CLAIM, address(45002))
	testing.expect(t, err == .None && retry.identity == m.identity && retry.key == g.key && retry.token == g.token)
	m.enabled = false
	testing.expect_value(t, auth.coordinator_member(&r.service.coordinator, m, 0), auth.Error.None)
	p.close(&r)
	testing.expect_value(t, p.open(&r, l.bundle, commit, &l, {&c, clock_read}, entropy = {&rng, random_read}), p.Error.None)
	next, error := p.join(&r, ticket, {0 = 44}, address(45003))
	testing.expect(t, error == .None && next.identity.member == 3)
	testing.expect(t, r.service.credentials[1].identity == next.identity && r.service.credentials[1].key == next.key)
	testing.expect(t, r.service.budget[2] == 32 && !r.bundle.record.members[1].enabled)
	creator := r.bundle.record.members[0]; creator.enabled = false
	testing.expect_value(t, auth.coordinator_member(&r.service.coordinator, creator, 0), auth.Error.None)
	_, error = p.invite(&r, ADMIN, {0 = 45}, .Player); testing.expect_value(t, error, p.Error.Denied)
}

@(test)
failed_or_ambiguous_storage_never_publishes_a_half_join :: proc(t: ^testing.T) {
	for ambiguous in ([2]bool{false, true}) {
		r: p.Room; l: Ledger; c: Clock; rng: Random
		setup(&r, &l, &c, &rng)
		ticket, _ := p.invite(&r, ADMIN, INVITE, .Trusted_Peer)
		before := r.bundle
		l.fail, l.lost_ack = !ambiguous, ambiguous
		g, err := p.join(&r, ticket, CLAIM, address(45002))
		testing.expect_value(t, err, p.Error.Storage); testing.expect_value(t, g, p.Grant{})
		testing.expect_value(t, r.bundle, before)
		testing.expect(t, r.service.coordinator.poisoned && r.service.credentials[1] == (auth.Credential{}))
		_, err = p.join(&r, ticket, CLAIM, address(45002)); testing.expect_value(t, err, p.Error.Storage)
		p.close(&r); l.fail, l.lost_ack = false, false
		testing.expect_value(t, p.open(&r, l.bundle, commit, &l, {&c, clock_read}, entropy = {&rng, random_read}), p.Error.None)
		stored := l.bundle.enrollments[1]
		g, err = p.join(&r, ticket, CLAIM, address(45002))
		testing.expect_value(t, err, p.Error.None)
		if ambiguous {testing.expect_value(t, g.key, stored.key); testing.expect_value(t, g.token, stored.token)}
		testing.expect(t, g.can_host && g.trusted_authority && !g.infrastructure)
		testing.expect_value(t, l.bundle.invites[0].remaining, u8(0))
		p.close(&r)
	}
}

@(test)
invites_cannot_escalate_dedicated_authority_or_change_on_retry :: proc(t: ^testing.T) {
	r: p.Room; l: Ledger; c: Clock; rng: Random
	setup(&r, &l, &c, &rng, true); defer p.close(&r)
	_, err := p.invite(&r, ADMIN, INVITE, .Trusted_Peer); testing.expect_value(t, err, p.Error.Denied)
	_, err = p.invite(&r, CLAIM, INVITE, .Player); testing.expect_value(t, err, p.Error.Denied)
	_, err = p.invite(&r, ADMIN, ADMIN, .Player); testing.expect_value(t, err, p.Error.Invalid)
	ticket, error := p.invite(&r, ADMIN, INVITE, .Player, 2); testing.expect_value(t, error, p.Error.None)
	before := l.writes
	_, err = p.invite(&r, ADMIN, INVITE, .Player, 1); testing.expect_value(t, err, p.Error.Denied)
	testing.expect_value(t, l.writes, before)
	_, err = p.join(&r, ticket, INVITE, address()); testing.expect_value(t, err, p.Error.Invalid)
	_, err = p.join(&r, ticket, CLAIM, {}); testing.expect_value(t, err, p.Error.Invalid)
	testing.expect_value(t, l.writes, before)
	rng.fail = true
	_, err = p.join(&r, ticket, CLAIM, address()); testing.expect_value(t, err, p.Error.Entropy)
	testing.expect_value(t, l.writes, before)
}

@(test)
capacity_is_bounded_and_spent_invites_and_disabled_members_remain_tombstones :: proc(t: ^testing.T) {
	r: p.Room; l: Ledger; c: Clock; rng: Random
	setup(&r, &l, &c, &rng); defer p.close(&r)
	ticket, err := p.invite(&r, ADMIN, INVITE, .Player, 15); testing.expect_value(t, err, p.Error.None)
	for i in 0 ..< 15 {
		_, error := p.join(&r, ticket, {0 = u8(100 + i)}, address(u16(45100 + i)))
		testing.expect_value(t, error, p.Error.None)
	}
	_, err = p.join(&r, ticket, CLAIM, address()); testing.expect_value(t, err, p.Error.Denied)
	fresh, error := p.invite(&r, ADMIN, {0 = 50}, .Player); testing.expect_value(t, error, p.Error.None)
	_, err = p.join(&r, fresh, CLAIM, address()); testing.expect_value(t, err, p.Error.Capacity)
	m := r.bundle.record.members[4]; m.enabled = false
	auth.coordinator_member(&r.service.coordinator, m, c.now)
	_, err = p.join(&r, fresh, CLAIM, address()); testing.expect_value(t, err, p.Error.Capacity)
	for i in 2 ..< p.MAX_INVITES {_, error := p.invite(&r, ADMIN, {0 = u8(50 + i)}, .Player); testing.expect_value(t, error, p.Error.None)}
	_, err = p.invite(&r, ADMIN, {0 = 90}, .Player); testing.expect_value(t, err, p.Error.Capacity)
	testing.expect(t, p.bundle_valid(l.bundle))
}

@(test)
newly_enrolled_rpc_clients_can_migrate_only_with_trusted_invite :: proc(t: ^testing.T) {
	r: p.Room; l: Ledger; c: Clock; rng: Random
	memory: tr.Memory; endpoints: [4]tr.Memory_Endpoint
	tr.memory_init(&memory, cfg = {4, 128, tr.MAX_PACKET_BYTES, 8192}, faults = {latency_ticks = 1, retry_ticks = 3})
	defer tr.memory_destroy(&memory)
	for &e, i in endpoints {tr.memory_open(&memory, &e, tr.Peer_Id(i + 1))}
	defer {for &e in endpoints {wire := tr.memory_transport(&e); tr.close(&wire)}}
	setup(&r, &l, &c, &rng, wire = tr.memory_transport(&endpoints[0])); defer p.close(&r)
	grants: [3]p.Grant
	grants[0], _ = p.creator_grant(&r, ADMIN)
	for i in 1 ..< 3 {
		ticket, _ := p.invite(&r, ADMIN, {0 = u8(50 + i)}, i == 1 ? .Player : .Trusted_Peer)
		grants[i], _ = p.join(&r, ticket, {0 = u8(60 + i)}, address(u16(45001 + i)))
	}
	leases: [3]auth.Lease; clients: [3]auth.Rpc_Client
	for &client, i in clients {
		auth.lease_init(&leases[i], grants[i].identity, 44, 55, {&c, clock_read}, i == 0)
		assert(auth.rpc_client_init(&client, &leases[i], grants[i].key, {0 = u8(71 + i)}, tr.memory_transport(&endpoints[i + 1])))
	}
	defer {for &client in clients {auth.rpc_client_destroy(&client)}}
	call :: proc(r: ^p.Room, c: ^Clock, memory: ^tr.Memory, clients: []auth.Rpc_Client, index: int, command: auth.Command) -> auth.Reply {
		assert(auth.rpc_begin(&clients[index], command) == .None)
		for _ in 0 ..< 100 {
			c.now += 10; tr.memory_advance(memory, c.now / 10)
			auth.service_pump(&r.service)
			for &client in clients {auth.rpc_client_pump(&client)}
			if reply, ok := auth.rpc_completed(&clients[index]); ok {return reply}
		}
		panic("RPC did not complete")
	}
	testing.expect_value(t, call(&r, &c, &memory, clients[:], 0, {verb = .Start}).result, auth.Error.None)
	testing.expect_value(t, call(&r, &c, &memory, clients[:], 1, {verb = .Query}).result, auth.Error.None)
	testing.expect_value(t, call(&r, &c, &memory, clients[:], 0, {verb = .Nominate, epoch = 1, successor = grants[1].identity, binding = 9}).result, auth.Error.Denied)
	testing.expect_value(t, call(&r, &c, &memory, clients[:], 0, {verb = .Nominate, epoch = 1, successor = grants[2].identity, binding = 9}).result, auth.Error.None)
	point := auth.Point{scope = {room = 44, content = 55, epoch = 1, binding = 9}, archive = {sequence = 1, tick = 10, bytes = 100, hash = {0 = 1}}}
	testing.expect_value(t, call(&r, &c, &memory, clients[:], 2, {verb = .Prepare, point = point}).result, auth.Error.None)
	retired, _ := auth.lease_retire(&leases[0])
	testing.expect_value(t, call(&r, &c, &memory, clients[:], 0, {verb = .Release, retired = retired, point = point}).result, auth.Error.None)
	reply := call(&r, &c, &memory, clients[:], 2, {verb = .Claim, epoch = 1, point = point})
	testing.expect_value(t, reply.result, auth.Error.None)
	testing.expect(t, reply.view.epoch == 2 && reply.view.owner == grants[2].identity)
	testing.expect(t, l.bundle.record == r.service.coordinator.record && p.bundle_valid(l.bundle))
}
