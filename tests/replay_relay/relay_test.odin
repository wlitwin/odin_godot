package relay_test

import "core:testing"
import rel "godot:replay/relay"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import rgd "godot:replay/godot"

KEY :: auth.Key{0 = 17}
Fixture :: struct {wall, mono: u64, enabled: bool, memory: tr.Memory, endpoints: [3]tr.Memory_Endpoint, server: rel.Server, client: rel.Client}
clock :: proc(user: rawptr) -> (u64, u64, bool) {f := cast(^Fixture)user; return f.wall, f.mono, true}
mono :: proc(user: rawptr) -> (u64, bool) {return (cast(^Fixture)user).mono, true}
authorize :: proc(user: rawptr, room, content, member: u64) -> (auth.Key, u64, bool) {
	if room != 44 || content != 55 || member != 2 {return {}, 0, false}
	return KEY, 3, (cast(^Fixture)user).enabled
}
setup :: proc(f: ^Fixture) {
	f.wall, f.enabled = 1700000000, true
	assert(tr.memory_init(&f.memory, cfg = {3, 128, tr.MAX_PACKET_BYTES, 8192}, faults = {latency_ticks = 1, retry_ticks = 3}))
	for &e, i in f.endpoints {tr.memory_open(&f.memory, &e, tr.Peer_Id(i + 1))}
	url, ok := rel.url("turn:127.0.0.1:3478?transport=udp"); assert(ok)
	assert(rel.server_open(&f.server, {content = 55, secret = "0123456789abcdef0123456789abcdef", urls = {0 = url}, ttl = 10, relay_only = true}, authorize, f, {f, clock}, tr.memory_transport(&f.endpoints[0])))
	assert(rel.client_open(&f.client, 44, 55, 2, KEY, {0 = 1}, {f, mono}, tr.memory_transport(&f.endpoints[1])))
}
close :: proc(f: ^Fixture) {rel.client_close(&f.client); rel.server_close(&f.server); for &e in f.endpoints {w := tr.memory_transport(&e); tr.close(&w)}; tr.memory_destroy(&f.memory)}
step :: proc(f: ^Fixture) {
	f.mono += 10; f.wall = 1700000000 + f.mono / 1000; tr.memory_advance(&f.memory, f.mono / 10)
	assert(rel.client_pump(&f.client) == .None)
	wire := tr.memory_transport(&f.endpoints[0]); buffer: [tr.MAX_PACKET_BYTES]u8
	for _ in 0 ..< 32 {packet := tr.receive(&wire, buffer[:]); if packet.state != .Received {break}; rel.server_receive(&f.server, packet.from, buffer[:packet.count])}
}
acquire :: proc(f: ^Fixture) {
	assert(rel.client_begin(&f.client) == .None)
	for _ in 0 ..< 100 {step(f); if f.client.complete {return}}
	panic("relay request did not complete")
}

@(test)
coturn_compatibility_hmac_vectors_cover_short_and_hashed_keys :: proc(t: ^testing.T) {
	value := rel.credential("key", "The quick brown fox jumps over the lazy dog")
	testing.expect_value(t, string(value[:rel.fixed_count(value)]), "3nybhbi3iqa8ino29wqQcBydtNk=")
	key: [100]u8; for &b in key {b = 'a'}
	value = rel.credential(string(key[:]), "1700000010:000000000000002c:0000000000000002:0000000000000003")
	testing.expect_value(t, string(value[:rel.fixed_count(value)]), "ScvZ2x/nuFLRE/XuF0U8lFuhd6M=")
}

@(test)
authenticated_challenge_issues_bounded_expiry_and_refreshes_without_local_wall_clock :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer close(&f)
	acquire(&f)
	g, ok := rel.client_grant(&f.client)
	testing.expect(t, ok && f.client.reply.error == .None && rel.grant_valid(g) && g.expires - g.issued == 10 && f.server.issued == 1)
	testing.expect(t, f.client.valid_until <= f.client.started + 9000)
	previous := g
	f.mono += 5000; f.wall += 5
	acquire(&f)
	g, ok = rel.client_grant(&f.client)
	testing.expect(t, ok && g.expires > previous.expires && g.credential != previous.credential && f.server.issued == 2)
	f.mono = f.client.valid_until
	_, ok = rel.client_grant(&f.client); testing.expect(t, !ok)
}

@(test)
acquire_is_connection_bound_and_duplicate_never_extends_issued_expiry :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer close(&f)
	acquire(&f)
	before := f.client.reply.grant
	packet := f.client.txb; count := f.client.count
	testing.expect(t, rel.server_receive(&f.server, 3, packet[:count]))
	testing.expect_value(t, f.server.issued, u64(1))
	f.mono += 1000; f.wall += 1
	testing.expect(t, rel.server_receive(&f.server, 2, packet[:count]))
	testing.expect(t, f.server.replayed == 1 && f.server.issued == 1)
	f.client.pending, f.client.complete = true, false
	for _ in 0 ..< 5 {step(&f)}
	testing.expect_value(t, f.client.reply.grant, before)
	packet[count - 1] ~= 1
	testing.expect(t, !rel.server_receive(&f.server, 2, packet[:count]))
}

@(test)
disabled_members_and_clock_reversal_cannot_issue_credentials :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer close(&f)
	f.enabled = false; acquire(&f)
	testing.expect(t, f.client.reply.error == .Denied && f.server.issued == 0)
	f.enabled = true; f.mono += 3000; acquire(&f)
	testing.expect(t, f.client.reply.error == .None)
	f.wall = 1
	packet := f.client.txb
	testing.expect(t, rel.server_receive(&f.server, 2, packet[:f.client.count]) && f.server.poisoned)
	testing.expect_value(t, f.server.issued, u64(1))
}

@(test)
expired_challenges_and_cross_scope_or_forged_requests_are_rejected :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer close(&f)
	assert(rel.client_begin(&f.client) == .None)
	for _ in 0 ..< 20 {step(&f); if f.client.request.verb == .Acquire {break}}
	testing.expect_value(t, f.client.request.verb, rel.Verb.Acquire)
	packet := f.client.txb; count := f.client.count
	f.mono += 6000; f.wall += 6
	testing.expect(t, rel.server_receive(&f.server, 2, packet[:count]))
	testing.expect_value(t, f.server.issued, u64(0))
	q := f.client.request; q.room = 45
	count = rel.request_pack(&f.client.codecs, q, KEY, packet[:]); testing.expect(t, !rel.server_receive(&f.server, 2, packet[:count]))
	q = f.client.request; q.member = 3
	count = rel.request_pack(&f.client.codecs, q, KEY, packet[:]); testing.expect(t, !rel.server_receive(&f.server, 2, packet[:count]))
	q = f.client.request
	count = rel.request_pack(&f.client.codecs, q, {0 = 18}, packet[:]); testing.expect(t, !rel.server_receive(&f.server, 2, packet[:count]))
}

@(test)
refresh_keeps_unexpired_cache_but_membership_denial_retires_it :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer close(&f)
	acquire(&f); old, valid := rel.client_grant(&f.client); testing.expect(t, valid)
	f.mono += 3000; f.wall += 3
	assert(rel.client_begin(&f.client) == .None)
	cached, available := rel.client_grant(&f.client); testing.expect(t, available && cached == old)
	f.enabled = false
	for _ in 0 ..< 20 {step(&f); if f.client.complete {break}}
	testing.expect_value(t, f.client.reply.error, rel.Error.Denied)
	_, available = rel.client_grant(&f.client); testing.expect(t, !available)
}

@(test)
runtime_ice_source_never_returns_expired_credentials_during_provider_outage :: proc(t: ^testing.T) {
	f: Fixture; setup(&f); defer close(&f)
	acquire(&f)
	// This view borrows the test client; it owns no engine objects or strings.
	view := rgd.Relay_Connection{ready = true, client = f.client, ice_json = `{"iceTransportPolicy":"relay"}`}
	_, ready := rgd.relay_ice_source(&view); testing.expect(t, ready)
	f.mono = f.client.refresh_at
	assert(rel.client_begin(&f.client) == .None)
	f.mono = f.client.valid_until
	view.client = f.client
	json, valid := rgd.relay_ice_source(&view); testing.expect(t, !valid && json == "")
	// A missing provider response does not imply a successful refresh.
	f.mono = f.client.started + 10001
	testing.expect_value(t, rel.client_pump(&f.client), rel.Error.Unavailable)
	_, valid = rel.client_grant(&f.client); testing.expect(t, !valid)
}
