package replay_authority

coordinator_init :: proc(c: ^Coordinator, record: Record, commit: Commit, user: rawptr, now_ms: u64) -> Error {
	if c.ready || commit == nil || !record_valid(record) || record.revision == max(u64) || record.coordinator_generation == max(u64) {return .Invalid}
	// Advancing the durable revision fences an earlier coordinator instance's CAS
	// writes. Restart also waits longer than any previously issued lease could last.
	next := record
	next.revision += 1; next.coordinator_generation += 1
	wait := u64(0)
	if record.epoch != 0 {
		d := u64(record.policy.drift_ppm)
		wait = (u64(record.policy.lease_ms) * (1000000 + d) + (1000000 - d) - 1) / (1000000 - d) + u64(record.policy.margin_ms)
	}
	if wait > max(u64) - now_ms {return .Clock}
	if !commit(user, record.revision, next) {return .Storage}
	c^ = {ready = true, record = next, commit = commit, user = user, now = now_ms,
	      restarted = record.epoch != 0, quarantine_until = now_ms + wait}
	return .None
}

// Trusted administration, not a request any game peer may authorize for itself.
coordinator_member :: proc(c: ^Coordinator, member: Member, now_ms: u64) -> Error {
	if err := coordinator_time(c, now_ms); err != .None {return err}
	if !identity_valid(member.identity) || !endpoint_valid(member.endpoint) {return .Invalid}
	index := -1
	for existing, i in c.record.members {if existing.identity.member == member.identity.member {index = i; break}}
	if index < 0 {for existing, i in c.record.members {if existing.identity.member == 0 {index = i; break}}}
	if index < 0 {return .Capacity}
	next := c.record
	if next.members[index] == member {return .None}
	if next.members[index].identity != member.identity {next.requests[index] = {}}
	if next.nominee.member == member.identity.member && (next.nominee != member.identity || !member.enabled || !member.can_host || !member.trusted_authority ||
	   (next.policy.mode == .Dedicated && !member.infrastructure)) {next.nominee, next.source_binding, next.prepared, next.point, next.released = {}, 0, false, {}, false}
	next.members[index] = member
	return coordinator_store(c, next)
}

coordinator_start :: proc(c: ^Coordinator, actor: Identity, request, now_ms: u64) -> Error {
	if err := coordinator_time(c, now_ms); err != .None {return err}
	if c.record.epoch != 0 || actor != c.record.bootstrap || request == 0 {return .Denied}
	member, allowed := host_member(c, actor)
	if !allowed {return .Denied}
	return coordinator_grant(c, member, request, .None, Point{}, now_ms)
}

coordinator_renew :: proc(c: ^Coordinator, actor: Identity, epoch, request, tick, now_ms: u64) -> Error {
	if err := coordinator_time(c, now_ms); err != .None {return err}
	if !coordinator_owner(c, actor, epoch) {return .Denied}
	if c.record.released || request <= c.record.owner_request || tick < c.record.last_tick {return .Stale}
	if u64(c.record.policy.lease_ms) > max(u64) - now_ms {return .Clock}
	next := c.record
	next.owner_request, next.last_tick = request, tick
	if err := coordinator_store(c, next); err != .None {return err}
	c.expires = now_ms + u64(c.record.policy.lease_ms)
	return .None
}

coordinator_nominate :: proc(c: ^Coordinator, actor: Identity, epoch: u64, successor: Identity, binding, now_ms: u64) -> Error {
	if err := coordinator_time(c, now_ms); err != .None {return err}
	if !coordinator_owner(c, actor, epoch) || c.record.released || successor == actor || binding == 0 {return .Denied}
	if _, allowed := host_member(c, successor); !allowed {return .Denied}
	if c.record.nominee == successor && c.record.source_binding == binding {return .None}
	next := c.record
	next.nominee, next.source_binding, next.prepared, next.point = successor, binding, false, {}
	return coordinator_store(c, next)
}

// Actor must already hold an owned, verified copy of this archive and retain it
// through claim/release. Prepared below makes that lifetime concrete.
coordinator_prepare :: proc(c: ^Coordinator, actor: Identity, point: Point, now_ms: u64) -> Error {
	if err := coordinator_time(c, now_ms); err != .None {return err}
	if actor != c.record.nominee {return .Denied}
	if _, allowed := host_member(c, actor); !allowed {return .Denied}
	if !point_valid(point) || point.scope.room != c.record.room || point.scope.content != c.record.content ||
	   point.scope.epoch != c.record.epoch || point.scope.binding != c.record.source_binding {return .Invalid}
	if c.record.prepared {
		if point == c.record.point {return .None}
		if c.record.released || point.archive.sequence <= c.record.point.archive.sequence || point.archive.tick < c.record.point.archive.tick {return .Stale}
	}
	next := c.record; next.prepared, next.point = true, point
	return coordinator_store(c, next)
}

// The authenticated old owner has irreversibly retired its local Lease before
// emitting this proof. Only an already prepared exact final checkpoint can be
// released early; an unconfirmed or stale release never advances authority.
coordinator_release :: proc(c: ^Coordinator, actor: Identity, retired: Retirement, final: Point, now_ms: u64) -> Error {
	if err := coordinator_time(c, now_ms); err != .None {return err}
	if c.record.released && actor == c.record.owner && retired.identity == actor && retired.room == c.record.room &&
	   retired.epoch == c.record.epoch && retired.revision != 0 && retired.revision <= c.record.revision && final == c.record.point {return .None}
	if !coordinator_owner(c, actor, retired.epoch) || retired.identity != actor || retired.room != c.record.room ||
	   retired.revision == 0 || retired.revision > c.record.revision {return .Denied}
	if !c.record.prepared || final != c.record.point || final.archive.tick < c.record.last_tick {return .No_Checkpoint}
	if c.record.released {return .None}
	next := c.record; next.released = true; next.last_tick = final.archive.tick
	if err := coordinator_store(c, next); err != .None {return err}
	c.active = false
	return .None
}

coordinator_claim :: proc(c: ^Coordinator, actor: Identity, epoch, request: u64, point: Point, now_ms: u64) -> Error {
	if err := coordinator_time(c, now_ms); err != .None {return err}
	if epoch != c.record.epoch || request == 0 {return .Stale}
	if now_ms < c.quarantine_until || (c.active && now_ms < c.expires) {return .Busy}
	if actor != c.record.nominee {return .Denied}
	member, allowed := host_member(c, actor)
	if !allowed {return .Denied}
	if !c.record.prepared || point != c.record.point {return .No_Checkpoint}
	if c.record.last_tick > point.archive.tick && c.record.last_tick - point.archive.tick > c.record.policy.max_known_rollback {return .Too_Old}
	kind := c.restarted ? Recovery_Kind.Coordinator_Restart : c.record.released ? .Planned : .Abrupt
	return coordinator_grant(c, member, request, kind, point, now_ms)
}

coordinator_view :: proc(c: ^Coordinator, now_ms: u64) -> (View, Error) {
	if err := coordinator_time(c, now_ms); err != .None {return {}, err}
	r := c.record
	remaining := c.active && !r.released && now_ms < c.expires ? u32(c.expires - now_ms) : 0
	return {room = r.room, content = r.content, revision = r.revision, epoch = r.epoch, coordinator_generation = r.coordinator_generation,
	        owner = r.owner, endpoint = r.authority_endpoint, remaining_ms = remaining, policy = r.policy,
	        recovery = r.recovery, recovered = r.recovered, last_known_tick = r.last_tick}, .None
}

// After coordinator restart, an unchanged authenticated owner may resume its
// own prepared world, but only after quarantine and under a NEW epoch. It must
// possess the checkpoint; this does not authorize reconstructing a lost world
// from an empty game. A nominee's ordinary claim may win first instead.
coordinator_recover_owner :: proc(c: ^Coordinator, actor: Identity, epoch, request: u64, point: Point, now_ms: u64) -> Error {
	if err := coordinator_time(c, now_ms); err != .None {return err}
	if actor != c.record.owner || epoch != c.record.epoch || request == 0 {return .Denied}
	if c.active && now_ms < c.expires {return .Busy}
	if now_ms < c.quarantine_until {return .Busy}
	member, allowed := host_member(c, actor)
	if !allowed {return .Denied}
	if c.record.released && (!c.record.prepared || point.archive.hash != c.record.point.archive.hash ||
	   point.archive.tick != c.record.point.archive.tick || point.archive.bytes != c.record.point.archive.bytes) {return .No_Checkpoint}
	// A grant may have committed just before its reply/service was lost. That
	// owner still holds the checkpoint approved by the grant, not an invented
	// checkpoint in the newly granted epoch. Its exact durable recovery point
	// remains an admissible source, subject to the known rollback limit.
	prior_grant := c.record.recovery != .None && point == c.record.recovered
	if !point_valid(point) || point.scope.room != c.record.room || point.scope.content != c.record.content ||
	   (point.scope.epoch != epoch && !prior_grant) {return .Invalid}
	if c.record.last_tick > point.archive.tick && c.record.last_tick - point.archive.tick > c.record.policy.max_known_rollback {return .Too_Old}
	return coordinator_grant(c, member, request, c.restarted ? .Coordinator_Restart : .Abrupt, point, now_ms)
}

@(private)
coordinator_time :: proc(c: ^Coordinator, now: u64) -> Error {
	if !c.ready {return .Not_Ready}
	if c.poisoned {return .Storage}
	if now < c.now {c.poisoned, c.active = true, false; return .Clock}
	c.now = now
	return .None
}

@(private)
coordinator_owner :: proc(c: ^Coordinator, actor: Identity, epoch: u64) -> bool {
	_, allowed := host_member(c, actor)
	return allowed && c.active && c.now < c.expires && actor == c.record.owner && epoch == c.record.epoch
}

@(private)
host_member :: proc(c: ^Coordinator, id: Identity) -> (Member, bool) {
	for member in c.record.members {
		if member.identity == id {
			return member, member.enabled && member.can_host && member.trusted_authority &&
			               (c.record.policy.mode == .Cooperative || member.infrastructure)
		}
	}
	return {}, false
}

@(private)
coordinator_store :: proc(c: ^Coordinator, next: Record) -> Error {
	if c.record.revision == max(u64) {return .Capacity}
	next := next; next.revision = c.record.revision + 1
	if !record_valid(next) {return .Invalid}
	if !c.commit(c.user, c.record.revision, next) {c.poisoned, c.active = true, false; return .Storage}
	c.record = next
	return .None
}

@(private)
coordinator_grant :: proc(c: ^Coordinator, member: Member, request: u64, kind: Recovery_Kind, point: Point, now: u64) -> Error {
	if c.record.epoch == max(u64) || u64(c.record.policy.lease_ms) > max(u64) - now {return .Capacity}
	next := c.record
	next.epoch += 1
	next.owner, next.authority_endpoint, next.owner_request = member.identity, member.endpoint, request
	next.recovery, next.recovered = kind, point
	next.last_tick = kind == .None ? 0 : point.archive.tick
	next.nominee, next.source_binding, next.prepared, next.point, next.released = {}, 0, false, {}, false
	if err := coordinator_store(c, next); err != .None {return err}
	c.active, c.restarted = true, false
	c.expires = now + u64(c.record.policy.lease_ms)
	return .None
}
