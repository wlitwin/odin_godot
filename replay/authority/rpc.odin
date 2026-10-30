package replay_authority

import "core:crypto"
import "core:crypto/hmac"
import "core:mem"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

RPC_VERSION :: u16(2)
RPC_REQUEST :: u16(0x5201)
RPC_REPLY :: u16(0x5202)
RPC_BYTES :: 8192
Key :: [32]u8
Nonce :: [16]u8
Credential :: struct {identity: Identity, key: Key}
Verb :: enum u8 {Query, Start, Renew, Nominate, Prepare, Release, Claim, Recover_Owner, Challenge, Rebind}
Command :: struct {verb: Verb, epoch, tick, binding: u64, successor: Identity, point: Point, retired: Retirement,
                   challenge: [32]u8, incarnation: u64, endpoint: Endpoint}
Request :: struct {version: u16, room: u64, identity: Identity, nonce: Nonce, sequence: u64, command: Command}
Reply :: struct {
	version: u16,
	identity: Identity,
	nonce: Nonce,
	sequence: u64,
	request_hash: [32]u8,
	result: Error,
	replayed: bool,
	view: View,
	nominee: Identity,
	binding: u64,
	prepared, released: bool,
	point: Point,
	sequence_floor: u64,
	challenge: [32]u8,
	registration_identity: Identity,
	members: [MAX_MEMBERS]Member,
}
Rpc_Codecs :: struct {request, reply: sc.Schema}
Rpc_Stats :: struct {rx_packets, tx_packets, rejected, duplicates, commits, deferred: u64}

rpc_codecs_init :: proc(c: ^Rpc_Codecs, allocator := context.allocator) -> bool {
	if c.request.initialized || c.reply.initialized {return false}
	if sc.init(&c.request, Request, allocator = allocator).error != .None || sc.init(&c.reply, Reply, allocator = allocator).error != .None {rpc_codecs_destroy(c); return false}
	if max(c.request.wire_size, c.reply.wire_size) + sc.HEADER_BYTES + 32 > RPC_BYTES {rpc_codecs_destroy(c); return false}
	return true
}
rpc_codecs_destroy :: proc(c: ^Rpc_Codecs) {sc.destroy(&c.request); sc.destroy(&c.reply)}

// Supply a fresh cryptographic nonce for each client instance. Member incarnation
// is independently provisioned per game process; reconnects retain the Lease's
// sequence. Nonces are not authority identities or substitutes for admission.
rpc_nonce :: proc() -> (Nonce, bool) {
	nonce: Nonce
	when crypto.HAS_RAND_BYTES {crypto.rand_bytes(nonce[:]); return nonce, true} else {return nonce, false}
}

@(private)
nonzero :: proc(bytes: []u8) -> bool {b := u8(0); for value in bytes {b |= value}; return b != 0}

@(private)
rpc_mac :: proc(key: Key, kind: u16, bytes: []u8) -> [32]u8 {
	k := key
	ctx: hmac.Context
	hmac.init(&ctx, .SHA256, k[:])
	domain := kind == RPC_REQUEST ? "replay-authority-request-v2" : "replay-authority-reply-v2"
 if kind==RPC_REMOVE_REQUEST {domain="replay-authority-remove-request-v1"}
 if kind==RPC_REMOVE_REPLY {domain="replay-authority-remove-reply-v1"}
	hmac.update(&ctx, transmute([]u8)domain)
	hmac.update(&ctx, bytes)
	tag: [32]u8
	hmac.final(&ctx, tag[:])
	return tag
}

@(private)
rpc_pack :: proc(schema: ^sc.Schema, packet: $T, key: Key, kind: u16, content, sequence: u64, dst: []u8) -> int {
	count := sc.HEADER_BYTES + schema.wire_size
	if len(dst) < count + 32 {return 0}
	if sc.pack(schema, packet, {kind = kind, epoch = u64(RPC_VERSION), tick = sequence, content = content}, dst[:count]).error != .None {return 0}
	tag := rpc_mac(key, kind, dst[:count])
	copy(dst[count:count + 32], tag[:])
	return count + 32
}

@(private)
rpc_authenticated :: proc(key: Key, kind: u16, bytes: []u8) -> bool {
	if len(bytes) < sc.HEADER_BYTES + 32 || len(bytes) > RPC_BYTES {return false}
	tag := rpc_mac(key, kind, bytes[:len(bytes) - 32])
	return crypto.compare_constant_time(tag[:], bytes[len(bytes) - 32:]) == 1
}

Rpc_Client :: struct {
	ready, pending, sent: bool,
	lease: ^Lease,
	wire: tr.Transport,
	coordinator: tr.Peer_Id,
	key: Key,
	nonce: Nonce,
	codecs: Rpc_Codecs,
	request: Request,
	reply: Reply,
	request_hash: [32]u8,
	last_send, started, retry_ms, timeout_ms: u64,
	stats: Rpc_Stats,
	txb: [RPC_BYTES]u8,
	rxb: [tr.MAX_PACKET_BYTES]u8,
	count: int,
 request_kind:u16,
}

rpc_client_init :: proc(c: ^Rpc_Client, lease: ^Lease, key: Key, nonce: Nonce, wire: tr.Transport,
                        coordinator: tr.Peer_Id = 1, retry_ms: u64 = 150, timeout_ms: u64 = 3000,
                        allocator := context.allocator) -> bool {
	k, n := key, nonce
	if c.ready || lease == nil || !lease.ready || !nonzero(k[:]) || !nonzero(n[:]) || coordinator == 0 ||
	   retry_ms < 10 || retry_ms > 10000 || timeout_ms < retry_ms || timeout_ms > 120000 {return false}
	c.lease, c.key, c.nonce, c.wire, c.coordinator = lease, key, nonce, wire, coordinator
	c.retry_ms, c.timeout_ms = retry_ms, timeout_ms
	if !rpc_codecs_init(&c.codecs, allocator) {return false}
	c.ready = true
	return true
}

rpc_client_destroy :: proc(c: ^Rpc_Client) {
	if c.pending && c.lease != nil {lease_cancel_request(c.lease)}
	rpc_codecs_destroy(&c.codecs)
	crypto.zero_explicit(&c.key, size_of(c.key))
	c^ = {}
}

rpc_begin :: proc(c: ^Rpc_Client, command: Command) -> Error {
 return rpc_begin_kind(c,command,RPC_REQUEST)
}

@(private)
rpc_begin_kind :: proc(c:^Rpc_Client,command:Command,kind:u16)->Error {
	if !c.ready {return .Not_Ready}
	if c.pending {return .Busy}
	if command.verb > .Rebind {return .Invalid}
	sequence, err := lease_request(c.lease)
	if err != .None {return err}
	c.request = {RPC_VERSION, c.lease.room, c.lease.identity, c.nonce, sequence, command}
	c.reply = {}
	c.request_kind=kind
	c.count = rpc_pack(&c.codecs.request, c.request, c.key, kind, c.lease.content, sequence, c.txb[:])
	if c.count == 0 {lease_cancel_request(c.lease); return .Invalid}
	c.request_hash = rec.hash(c.txb[:c.count - 32])
	c.pending, c.sent, c.started = true, false, c.lease.sent_at
	return .None
}

rpc_client_receive :: proc(c: ^Rpc_Client, from: tr.Peer_Id, bytes: []u8) -> bool {
	if !c.ready || !c.pending {return false}
	c.stats.rx_packets += 1
 reply_kind:=c.request_kind==RPC_REMOVE_REQUEST ? RPC_REMOVE_REPLY : RPC_REPLY
	if from != c.coordinator || len(bytes) != sc.HEADER_BYTES + c.codecs.reply.wire_size + 32 ||
	   !rpc_authenticated(c.key, reply_kind, bytes) {c.stats.rejected += 1; return false}
	packet: Reply
	meta, report := sc.unpack(&c.codecs.reply, &packet, bytes[:len(bytes) - 32], {kind = reply_kind, epoch = u64(RPC_VERSION), content = c.lease.content})
	if report.error != .None || packet.version != RPC_VERSION || packet.identity != c.lease.identity || packet.nonce != c.nonce ||
	   packet.sequence != c.request.sequence || meta.tick != packet.sequence || packet.request_hash != c.request_hash {c.stats.rejected += 1; return false}
	if c.request.command.verb == .Rebind && packet.result == .None &&
	   (packet.registration_identity.member != c.lease.identity.member || !identity_valid(packet.registration_identity)) {c.stats.rejected += 1; return false}
	if lease_accept(c.lease, packet.sequence, packet.view) != .None {c.stats.rejected += 1; return false}
	c.reply, c.pending = packet, false
	if c.request.command.verb == .Rebind && packet.result == .None {
		c.lease.identity = packet.registration_identity
	}
	// A reconnecting RPC wrapper can resume a sequence already held by this
	// incarnation, but a new game process must use a newly provisioned incarnation.
	c.lease.sequence = max(c.lease.sequence, packet.sequence_floor)
	return true
}

rpc_client_pump :: proc(c: ^Rpc_Client) -> Error {
	if !c.ready {return .Not_Ready}
	if err := lease_time(c.lease); err != .None {return err}
	now := c.lease.now
	tr.poll(&c.wire)
	for _ in 0 ..< 32 {
		packet := tr.receive(&c.wire, c.rxb[:])
		if packet.state == .Empty || packet.state == .Disconnected {break}
		if packet.state != .Received {c.stats.rejected += 1; continue}
		rpc_client_receive(c, packet.from, c.rxb[:packet.count])
	}
	if !c.pending {return .None}
	if c.lease.poisoned {return .Clock}
	if now - c.started >= c.timeout_ms {c.pending = false; lease_cancel_request(c.lease); return .Busy}
	if !c.sent || now - c.last_send >= c.retry_ms {
		if tr.send(&c.wire, c.coordinator, .Reliable, c.txb[:c.count]) == .Sent {
			c.sent, c.last_send = true, now; c.stats.tx_packets += 1
		} else {c.stats.deferred += 1}
	}
	return .None
}

rpc_completed :: proc(c: ^Rpc_Client) -> (Reply, bool) {
	return c.reply, c.ready && !c.pending && c.reply.sequence != 0 && c.reply.sequence == c.request.sequence
}
