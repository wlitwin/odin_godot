package replay_authority

import rec "godot:replay/recovery"

VERSION :: u16(3)
MAX_MEMBERS :: 16
Identity :: struct {member, incarnation: u64}
Endpoint :: struct {host: [96]u8, port: u16}
Mode :: enum u8 {Cooperative, Dedicated}
Recovery_Kind :: enum u8 {None, Planned, Abrupt, Coordinator_Restart}
Error :: enum u8 {None, Invalid, Not_Ready, Clock, Storage, Denied, Stale, Busy, No_Checkpoint, Too_Old, Capacity}
Request_Frontier :: struct {sequence: u64, hash: [32]u8, result: Error, nonce: [16]u8}

Policy :: struct {mode: Mode, lease_ms, drift_ppm, margin_ms: u32, max_known_rollback: u64}
DEFAULT_POLICY :: Policy{.Cooperative, 2000, 1000, 20, 120}
Member :: struct {identity: Identity, endpoint: Endpoint, enabled, can_host, trusted_authority, infrastructure: bool, game_token_hash: [32]u8}
Point :: struct {scope: rec.Scope, archive: rec.Archive}
Retirement :: struct {identity: Identity, room, epoch, revision: u64}

// Durable decision state. Commit must compare revision atomically and durably
// store the complete next record. A successful decision is never returned first.
// Member identities/permissions are provisioned by a trusted admission service.
Record :: struct {
	version: u16,
	room, content, revision, coordinator_generation, epoch: u64,
	policy: Policy,
	bootstrap, owner, nominee: Identity,
	authority_endpoint: Endpoint,
	members: [MAX_MEMBERS]Member,
	requests: [MAX_MEMBERS]Request_Frontier,
	owner_request, last_tick, source_binding: u64,
	prepared: bool,
	point: Point,
	released: bool,
	recovery: Recovery_Kind,
	recovered: Point,
}

Commit :: proc(user: rawptr, expected_revision: u64, next: Record) -> bool
Coordinator :: struct {
	ready, poisoned, active, restarted: bool,
	record: Record,
	commit: Commit,
	user: rawptr,
	now, expires, quarantine_until: u64,
}

// Relative remaining duration, not a foreign machine's absolute clock value.
// Transport/RPC glue must authenticate the coordinator and correlate its reply
// to the exact local request captured by Lease before sending.
View :: struct {
	room, content, revision, epoch, coordinator_generation: u64,
	owner: Identity,
	endpoint: Endpoint,
	remaining_ms: u32,
	policy: Policy,
	recovery: Recovery_Kind,
	recovered: Point,
	last_known_tick: u64,
}

identity_valid :: proc(id: Identity) -> bool {return id.member != 0 && id.incarnation != 0}
@(private)
policy_valid :: proc(p: Policy) -> bool {
	return p.mode <= .Dedicated && p.lease_ms >= 250 && p.lease_ms <= 30000 &&
	       p.drift_ppm <= 10000 && p.margin_ms >= 2 && p.margin_ms < p.lease_ms / 4 && p.max_known_rollback <= 1000000
}
@(private)
endpoint_valid :: proc(e: Endpoint) -> bool {
	if e.port == 0 || e.host[0] == 0 || e.host[len(e.host) - 1] != 0 {return false}
	ended := false
	for b in e.host {if b == 0 {ended = true} else if ended || b < 33 || b > 126 {return false}}
	return true
}

endpoint :: proc(host: string, port: u16) -> (Endpoint, bool) {
	e: Endpoint
	if len(host) == 0 || len(host) >= len(e.host) {return e, false}
	copy(e.host[:], transmute([]u8)host); e.port = port
	return e, endpoint_valid(e)
}

record_make :: proc(room, content: u64, bootstrap: Identity, policy := DEFAULT_POLICY) -> Record {
	return {version = VERSION, room = room, content = content, bootstrap = bootstrap, policy = policy}
}

record_valid :: proc(r: Record) -> bool {
	r := r
	if r.version != VERSION || r.room == 0 || r.content == 0 || !identity_valid(r.bootstrap) || !policy_valid(r.policy) {return false}
	for member, i in r.members {
		if member.identity.member == 0 {if member != (Member{}) || r.requests[i] != (Request_Frontier{}) {return false}; continue}
		if !identity_valid(member.identity) || !endpoint_valid(member.endpoint) {return false}
		if r.requests[i].result > .Capacity || (r.requests[i].sequence == 0 && r.requests[i] != (Request_Frontier{})) {return false}
		if r.requests[i].sequence != 0 && !nonzero(r.requests[i].hash[:]) {return false}
		for previous in r.members[:i] {if previous.identity.member == member.identity.member {return false}}
	}
	if r.epoch == 0 {return r.owner == (Identity{}) && r.owner_request == 0 && r.last_tick == 0 && r.authority_endpoint == (Endpoint{}) &&
	                       r.nominee == (Identity{}) && r.source_binding == 0 && !r.prepared && r.point == (Point{}) &&
	                       !r.released && r.recovery == .None && r.recovered == (Point{})}
	if !identity_valid(r.owner) || !endpoint_valid(r.authority_endpoint) || r.owner_request == 0 || r.coordinator_generation == 0 {return false}
	if r.nominee != (Identity{}) && (!identity_valid(r.nominee) || r.source_binding == 0) {return false}
	if r.nominee == (Identity{}) && (r.source_binding != 0 || r.prepared) {return false}
	if !r.prepared && r.point != (Point{}) {return false}
	if r.prepared && (!point_valid(r.point) || r.point.scope.room != r.room || r.point.scope.content != r.content ||
	   r.point.scope.epoch != r.epoch || r.point.scope.binding != r.source_binding || !identity_valid(r.nominee)) {return false}
	if r.released && !r.prepared {return false}
	if r.recovery > .Coordinator_Restart {return false}
	if r.recovery == .None && r.recovered != (Point{}) {return false}
	if r.recovery != .None && (!point_valid(r.recovered) || r.recovered.scope.epoch >= r.epoch ||
	   r.recovered.scope.room != r.room || r.recovered.scope.content != r.content) {return false}
	return true
}

point_valid :: proc(p: Point) -> bool {
	if p.scope.room == 0 || p.scope.content == 0 || p.scope.epoch == 0 || p.scope.binding == 0 ||
	   p.archive.sequence == 0 || p.archive.tick == max(u64) || p.archive.bytes < 52 || p.archive.bytes > 1024 * 1024 {return false}
	bits := u8(0); for b in p.archive.hash {bits |= b}
	return bits != 0
}
