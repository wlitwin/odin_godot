package enrollment_test

import "core:testing"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import rec "godot:replay/recovery"

SERVICE :: "wss://rooms.example.test/admission"
request :: proc() -> p.Request {
	endpoint, _ := auth.endpoint("127.0.0.1", 45001)
	return {version = p.PROTOCOL, verb = .Create, room = 44, content = 55, claim = {0 = 41}, endpoint = endpoint}
}
setup :: proc(e: ^p.Enrollment_Journal) {assert(p.enrollment_open(e, SERVICE, 55)); assert(p.enrollment_loaded(e, {}, false, 0))}
response :: proc(e: ^p.Enrollment_Journal) -> p.Reply {
	bytes: [p.PACKET_BYTES]u8
	count := p.request_pack(&e.protocol, e.record.request, bytes[:]); assert(count != 0)
	return {version = p.PROTOCOL, room = 44, content = 55, request_hash = rec.hash(bytes[:count]),
	        grant = {room = 44, content = 55, identity = {1, 1}, key = {0 = 51}, token = {0 = 61}, can_host = true, trusted_authority = true}}
}

@(test)
network_request_and_credential_are_unavailable_until_their_receipts :: proc(t: ^testing.T) {
	e: p.Enrollment_Journal; setup(&e); defer p.enrollment_close(&e)
	testing.expect(t, p.enrollment_begin(&e, request()))
	_, allowed := p.enrollment_request(&e); testing.expect(t, !allowed)
	bytes, expected, writing := p.enrollment_write(&e)
	testing.expect(t, writing && expected == 0 && len(bytes) > 0)
	record, ok := p.enrollment_decode(&e.codec, bytes, 55); testing.expect(t, ok && record.state == .Pending)
	testing.expect(t, p.enrollment_receipt(&e, 1))
	q, ready := p.enrollment_request(&e); testing.expect(t, ready && q == request())
	reply := response(&e)
	testing.expect(t, p.enrollment_accept(&e, reply))
	_, available := p.enrollment_grant(&e); testing.expect(t, !available)
	testing.expect(t, e.record.state == .Pending && e.record.grant == (p.Grant{}))
	testing.expect(t, p.enrollment_receipt(&e, 2))
	g, valid := p.enrollment_grant(&e); testing.expect(t, valid && g == reply.grant)
	testing.expect_value(t, e.buffer, [p.ENROLLMENT_BYTES]u8{})
	loaded: p.Enrollment_Journal; defer p.enrollment_close(&loaded)
	assert(p.enrollment_open(&loaded, SERVICE, 55))
	testing.expect(t, p.enrollment_loaded(&loaded, e.record, true, 2))
	g, valid = p.enrollment_grant(&loaded); testing.expect(t, valid && g == reply.grant)
	_, allowed = p.enrollment_request(&loaded); testing.expect(t, !allowed)
}

@(test)
failed_writes_expose_neither_unstored_requests_nor_unstored_credentials :: proc(t: ^testing.T) {
	for grant in ([2]bool{false, true}) {
		e: p.Enrollment_Journal; setup(&e); defer p.enrollment_close(&e)
		assert(p.enrollment_begin(&e, request()))
		if grant {assert(p.enrollment_receipt(&e, 1)); assert(p.enrollment_accept(&e, response(&e)))}
		before, ambiguous := e.record, e.candidate
		testing.expect(t, !p.enrollment_receipt(&e, 0, .Store))
		testing.expect_value(t, e.record, before)
		_, request_ok := p.enrollment_request(&e); _, grant_ok := p.enrollment_grant(&e)
		testing.expect(t, !request_ok && !grant_ok && e.phase == .Failed)
		// Storage might have committed despite losing its acknowledgement.
		p.enrollment_close(&e); assert(p.enrollment_open(&e, SERVICE, 55))
		testing.expect(t, p.enrollment_loaded(&e, ambiguous, true, ambiguous.revision))
		testing.expect_value(t, e.phase, grant ? p.Enrollment_Phase.Ready : p.Enrollment_Phase.Pending)
	}
}

@(test)
corrupt_scope_and_stale_replies_cannot_replace_a_durable_request :: proc(t: ^testing.T) {
	e: p.Enrollment_Journal; setup(&e); defer p.enrollment_close(&e)
	assert(p.enrollment_begin(&e, request())); assert(p.enrollment_receipt(&e, 1))
	before := e.record; reply := response(&e); reply.request_hash[0] ~= 1
	testing.expect(t, !p.enrollment_accept(&e, reply) && e.record == before && e.phase == .Pending)
	reply = response(&e); reply.grant.content = 56
	testing.expect(t, !p.enrollment_accept(&e, reply) && e.record == before)
	other: p.Enrollment_Journal; defer p.enrollment_close(&other)
	assert(p.enrollment_open(&other, "wss://other.example.test/admission", 55))
	testing.expect(t, !p.enrollment_loaded(&other, before, true, 1) && other.error == .Scope)
	p.enrollment_close(&other); assert(p.enrollment_open(&other, SERVICE, 55))
	testing.expect(t, !p.enrollment_loaded(&other, before, true, 2) && other.error == .Corrupt)
	before.service[2048] = 1; testing.expect(t, !p.enrollment_record_valid(before))
}

@(test)
refusal_retains_exact_request_for_explicit_retry_and_slots_never_change_identity :: proc(t: ^testing.T) {
	e: p.Enrollment_Journal; setup(&e); defer p.enrollment_close(&e)
	assert(p.enrollment_begin(&e, request())); assert(p.enrollment_receipt(&e, 1))
	before := e.record; reply := response(&e); reply.result, reply.grant = .Rate_Limited, {}
	testing.expect(t, !p.enrollment_accept(&e, reply) && e.phase == .Refused && e.record == before)
	_, allowed := p.enrollment_request(&e); testing.expect(t, !allowed)
	testing.expect(t, p.enrollment_retry(&e))
	q, ok := p.enrollment_request(&e); testing.expect(t, ok && q == before.request)
	assert(p.enrollment_accept(&e, response(&e)))
	testing.expect(t, p.enrollment_transition(before, true, 1, e.candidate))
	changed := e.candidate; changed.request.claim[0] += 1
	testing.expect(t, !p.enrollment_transition(before, true, 1, changed))
	testing.expect(t, !p.enrollment_transition({}, false, 0, e.candidate))
	assert(p.enrollment_receipt(&e, 2)); changed = e.record; changed.revision += 1
	testing.expect(t, !p.enrollment_transition(e.record, true, 2, changed))
	testing.expect(t, !p.enrollment_record_valid(changed))
}
