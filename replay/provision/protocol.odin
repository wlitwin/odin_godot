package replay_provision

import "core:crypto"
import "core:mem"
import auth "godot:replay/authority"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

PROTOCOL :: u16(1)
REQUEST_KIND :: u16(0x5051)
REPLY_KIND :: u16(0x5053)
PACKET_BYTES :: 1024
Verb :: enum u8 {Create, Invite, Join, Revoke}
Request :: struct {
	version: u16,
	verb: Verb,
	room, content: u64,
	claim, ticket: Secret,
	endpoint: auth.Endpoint,
	role: Role,
	uses: u8,
}
Reply :: struct {version: u16, room, content: u64, request_hash: [32]u8, result: Error, grant: Grant, ticket: Ticket}
Codecs :: struct {request, reply: sc.Schema}

codecs_init :: proc(c: ^Codecs, allocator := context.allocator) -> bool {
	if c.request.initialized || c.reply.initialized {return false}
	if sc.init(&c.request, Request, allocator = allocator).error != .None || sc.init(&c.reply, Reply, allocator = allocator).error != .None ||
	   max(c.request.wire_size, c.reply.wire_size) + sc.HEADER_BYTES > PACKET_BYTES {codecs_destroy(c); return false}
	return true
}
codecs_destroy :: proc(c: ^Codecs) {sc.destroy(&c.request); sc.destroy(&c.reply)}

request_valid :: proc(q: Request) -> bool {
	q := q
	if q.version != PROTOCOL || q.verb > .Revoke || q.room == 0 || q.content == 0 || !nonzero(q.claim[:]) {return false}
	switch q.verb {
	case .Create, .Join:
		if q.role != .Player || q.uses != 0 {return false}
		if (q.verb == .Create && q.ticket != (Secret{})) || (q.verb == .Join && !nonzero(q.ticket[:])) {return false}
		probe := auth.record_make(q.room, q.content, {1, 1})
		probe.members[0] = {identity = {1, 1}, endpoint = q.endpoint}
		return auth.record_valid(probe)
	case .Invite:
		return nonzero(q.ticket[:]) && q.endpoint == (auth.Endpoint{}) && q.role <= .Trusted_Peer && q.uses > 0 && q.uses < auth.MAX_MEMBERS
	case .Revoke:
		return nonzero(q.ticket[:]) && q.endpoint == (auth.Endpoint{}) && q.role == .Player && q.uses == 0
	}
	return false
}

request_pack :: proc(c: ^Codecs, q: Request, dst: []u8) -> int {
	if !request_valid(q) || !c.request.initialized {return 0}
	count := sc.HEADER_BYTES + c.request.wire_size
	if len(dst) < count || sc.pack(&c.request, q, {kind = REQUEST_KIND, epoch = u64(PROTOCOL), content = q.content}, dst[:count]).error != .None {return 0}
	return count
}

// This protocol carries bearer credentials. Embeddings MUST provide an
// authenticated confidential transport (verified TLS), or an explicitly local
// test channel. It does not encrypt packets or authenticate the server itself.
Client :: struct {
	ready, pending, complete: bool,
	codecs: Codecs,
	wire: tr.Transport,
	clock: auth.Clock_Source,
	peer: tr.Peer_Id,
	request: Request,
	reply: Reply,
	hash: [32]u8,
	started, now, last_send: u64,
	sent: bool,
	count: int,
	txb: [PACKET_BYTES]u8,
	rxb: [tr.MAX_PACKET_BYTES]u8,
	rejected: u64,
}
client_open :: proc(c: ^Client, wire: tr.Transport, clock: auth.Clock_Source, peer: tr.Peer_Id = 1, allocator := context.allocator) -> bool {
	if c.ready || clock.read == nil || peer == 0 || !codecs_init(&c.codecs, allocator) {return false}
	c.wire, c.clock, c.peer, c.ready = wire, clock, peer, true
	return true
}
client_close :: proc(c: ^Client) {codecs_destroy(&c.codecs); crypto.zero_explicit(c, size_of(Client))}
client_begin :: proc(c: ^Client, request: Request) -> Error {
	if !c.ready {return .Not_Ready}
	if c.pending {return .Invalid}
	count := request_pack(&c.codecs, request, c.txb[:])
	if count == 0 {return .Invalid}
	now, ok := c.clock.read(c.clock.user)
	if !ok || now < c.now {return .Clock}
	c.request, c.count, c.hash = request, count, rec.hash(c.txb[:count])
	c.reply = {}; c.pending, c.complete, c.sent = true, false, false
	c.started, c.now, c.last_send = now, now, 0
	return .None
}
client_receive :: proc(c: ^Client, from: tr.Peer_Id, bytes: []u8) -> bool {
	if !c.ready || !c.pending {return false}
	if from != c.peer || len(bytes) != sc.HEADER_BYTES + c.codecs.reply.wire_size {c.rejected += 1; return false}
	reply: Reply
	meta, report := sc.unpack(&c.codecs.reply, &reply, bytes, {kind = REPLY_KIND, epoch = u64(PROTOCOL), content = c.request.content})
	if report.error != .None || meta.tick != 0 || reply.version != PROTOCOL || reply.room != c.request.room || reply.content != c.request.content ||
	   reply.request_hash != c.hash || !reply_valid(reply, c.request) {c.rejected += 1; return false}
	c.reply, c.pending, c.complete = reply, false, true
	return true
}
client_pump :: proc(c: ^Client) -> Error {
	if !c.ready {return .Not_Ready}
	now, ok := c.clock.read(c.clock.user)
	if !ok || now < c.now {c.pending = false; return .Clock}
	c.now = now
	tr.poll(&c.wire)
	for _ in 0 ..< 32 {
		packet := tr.receive(&c.wire, c.rxb[:])
		if packet.state == .Empty || packet.state == .Disconnected {break}
		if packet.state == .Received {client_receive(c, packet.from, c.rxb[:packet.count])} else {c.rejected += 1}
	}
	if c.pending {
		if now - c.started >= 10000 {c.pending = false; return .Not_Ready}
		if !c.sent || now - c.last_send >= 250 {
			if tr.send(&c.wire, c.peer, .Reliable, c.txb[:c.count]) == .Sent {c.sent, c.last_send = true, now}
		}
	}
	return .None
}

@(private)
reply_valid :: proc(reply: Reply, q: Request) -> bool {
	g := reply.grant
	if reply.result != .None {return g == (Grant{}) && reply.ticket == (Ticket{})}
	switch q.verb {
	case .Create, .Join:
		return reply.ticket == (Ticket{}) && g.room == q.room && g.content == q.content && auth.identity_valid(g.identity) && g.identity.member <= auth.MAX_MEMBERS &&
		       nonzero(g.key[:]) && nonzero(g.token[:]) && (q.verb == .Create ? g.identity.member == 1 : g.identity.member > 1) &&
		       (!g.can_host || g.trusted_authority) && (!g.infrastructure || g.trusted_authority)
	case .Invite: return g == (Grant{}) && reply.ticket == (Ticket{q.room, q.ticket})
	case .Revoke: return g == (Grant{}) && reply.ticket == (Ticket{})
	}
	return false
}
