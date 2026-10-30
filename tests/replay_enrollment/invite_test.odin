package enrollment_test

import "core:testing"
import p "godot:replay/provision"

@(test)
creator_invites_are_stable_scoped_capabilities_and_codes_roundtrip :: proc(t: ^testing.T) {
	e: p.Enrollment_Journal; setup(&e); defer p.enrollment_close(&e)
	assert(p.enrollment_begin(&e, request())); assert(p.enrollment_receipt(&e, 1))
	assert(p.enrollment_accept(&e, response(&e))); assert(p.enrollment_receipt(&e, 2))
	q, ok := p.creator_invite(e.record, .Trusted_Peer, 3); testing.expect(t, ok && p.request_valid(q))
	retry, valid := p.creator_invite(e.record, .Trusted_Peer, 3); testing.expect(t, valid && retry == q)
	testing.expect(t, q.ticket != q.claim && q.ticket != e.record.grant.key)
	changed, _ := p.creator_invite(e.record, .Player, 3); testing.expect(t, changed.ticket != q.ticket)
	changed, _ = p.creator_invite(e.record, .Trusted_Peer, 2); testing.expect(t, changed.ticket != q.ticket)
	changed, _ = p.creator_invite(e.record, .Trusted_Peer, 3, 1); testing.expect(t, changed.ticket != q.ticket)
	other := e.record; other.service, _ = p.service_url("wss://other.example.test")
	changed, _ = p.creator_invite(other, .Trusted_Peer, 3); testing.expect(t, changed.ticket != q.ticket)
	code, encoded := p.ticket_code({q.room, q.ticket}); testing.expect(t, encoded)
	ticket, decoded := p.ticket_parse(string(code[:])); testing.expect(t, decoded && ticket == (p.Ticket{q.room, q.ticket}))
	code[21] = 'g'; _, decoded = p.ticket_parse(string(code[:])); testing.expect(t, !decoded)
	_, decoded = p.ticket_parse("RP1.0000000000000000.0000000000000000000000000000000000000000000000000000000000000000"); testing.expect(t, !decoded)
	_, encoded = p.ticket_code({max(u64), {0 = 1}}); testing.expect(t, encoded)
}
