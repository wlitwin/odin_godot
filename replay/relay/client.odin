package replay_relay

import "core:crypto"
import auth "godot:replay/authority"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Client :: struct {
	ready, pending, complete, sent: bool,
	codecs: Codecs,
	clock: auth.Clock_Source,
	wire: tr.Transport,
	peer: tr.Peer_Id,
	key: auth.Key,
	request: Request,
	reply: Reply,
	grant: Grant,
	started, now, last_send, valid_until, refresh_at: u64,
	count: int,
	txb: [PACKET_BYTES]u8,
	rxb: [tr.MAX_PACKET_BYTES]u8,
	rejected: u64,
}
client_open :: proc(c: ^Client, room, content, member: u64, key: auth.Key, nonce: [16]u8, clock: auth.Clock_Source, wire: tr.Transport,
                    peer: tr.Peer_Id = 1, allocator := context.allocator) -> bool {
	if c.ready || room == 0 || content == 0 || member == 0 || key == (auth.Key{}) || nonce == ([16]u8{}) || peer == 0 || clock.read == nil {return false}
	if !codecs_init(&c.codecs, allocator) {return false}
	c.clock, c.wire, c.peer, c.key = clock, wire, peer, key
	c.request = {version = VERSION, room = room, content = content, member = member, nonce = nonce}
	c.ready = true; return true
}
client_close :: proc(c: ^Client) {codecs_destroy(&c.codecs); crypto.zero_explicit(c, size_of(Client))}
client_begin :: proc(c: ^Client) -> Error {
	if !c.ready || c.pending || c.request.sequence == max(u64) {return .Invalid}
	now, ok := c.clock.read(c.clock.user); if !ok || now < c.now {return .Clock}
	c.request.sequence += 1; c.request.verb, c.request.challenge = .Challenge, {}
	c.reply, c.pending, c.complete, c.sent = {}, true, false, false
	c.started, c.now, c.last_send = now, now, 0
	c.count = request_pack(&c.codecs, c.request, c.key, c.txb[:])
	return c.count == 0 ? .Invalid : .None
}
client_receive :: proc(c: ^Client, from: tr.Peer_Id, bytes: []u8) -> bool {
	if !c.ready || !c.pending {return false}
	if from != c.peer || len(bytes) != sc.HEADER_BYTES + c.codecs.reply.wire_size + 32 || !authenticated(c.key, REPLY_KIND, bytes) {c.rejected += 1; return false}
	reply: Reply
	meta, report := sc.unpack(&c.codecs.reply, &reply, bytes[:len(bytes) - 32], {kind = REPLY_KIND, epoch = u64(VERSION), content = c.request.content})
	if report.error != .None || meta.tick != c.request.sequence || reply.version != VERSION || reply.room != c.request.room || reply.content != c.request.content ||
	   reply.member != c.request.member || reply.sequence != c.request.sequence || reply.nonce != c.request.nonce || reply.request_hash != request_hash(c.txb[:c.count]) {c.rejected += 1; return false}
	if reply.error != .None {
		if reply.challenge != ([32]u8{}) || reply.grant != (Grant{}) {c.rejected += 1; return false}
		if reply.error == .Denied {c.valid_until, c.grant = 0, {}}
		c.reply, c.pending, c.complete = reply, false, true; return true
	}
	if c.request.verb == .Challenge {
		if reply.challenge == ([32]u8{}) || reply.grant != (Grant{}) {c.rejected += 1; return false}
		c.request.verb, c.request.challenge = .Acquire, reply.challenge
		c.count = request_pack(&c.codecs, c.request, c.key, c.txb[:]); c.sent = false
		return true
	}
	if reply.challenge != ([32]u8{}) || !grant_valid(reply.grant) {c.rejected += 1; return false}
	lifetime := (reply.grant.expires - reply.grant.issued) * 1000
	// Begin at the local request time, not receipt time. RTT is never added to
	// the credential lifetime. Leave a one-second allocation safety margin.
	if c.started > max(u64) - lifetime || c.now >= c.started + lifetime - 1000 {c.pending = false; c.reply = {error = .Expired}; c.complete = true; return true}
	c.valid_until, c.refresh_at = c.started + lifetime - 1000, c.started + lifetime / 2
	c.grant = reply.grant
	c.reply, c.pending, c.complete = reply, false, true
	return true
}
client_pump :: proc(c: ^Client) -> Error {
	if !c.ready {return .Invalid}
	now, ok := c.clock.read(c.clock.user)
	if !ok || now < c.now {c.pending = false; c.valid_until = 0; return .Clock}
	c.now = now; tr.poll(&c.wire)
	for _ in 0 ..< 32 {
		packet := tr.receive(&c.wire, c.rxb[:]); if packet.state == .Empty || packet.state == .Disconnected {break}
		if packet.state == .Received {client_receive(c, packet.from, c.rxb[:packet.count])} else {c.rejected += 1}
	}
	if c.pending {
		if now - c.started >= 10000 {c.pending = false; return .Unavailable}
		if !c.sent || now - c.last_send >= 250 {
			if tr.send(&c.wire, c.peer, .Reliable, c.txb[:c.count]) == .Sent {c.sent, c.last_send = true, now}
		}
	}
	return .None
}
client_grant :: proc(c: ^Client) -> (Grant, bool) {
	if !c.ready || !grant_valid(c.grant) {return {}, false}
	now, ok := c.clock.read(c.clock.user)
	if !ok || now < c.now || now >= c.valid_until {return {}, false}
	return c.grant, true
}
