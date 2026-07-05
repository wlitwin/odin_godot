package kit_net

// registry — Net_Id → entity bookkeeping and the per-tick replication walk.
//
// Every replicated entity registers here (the session layer will do it at
// spawn; tests do it directly). Each entry owns the entity's SHADOW copy, so
// the registry can do the whole net-tick send in one call: walk the entries,
// memcmp entity-vs-shadow, and append [net_id][delta] for just the dirty ones
// into one batched message. Receivers walk the same message and apply each
// delta to the entity the id resolves to. Idle entities cost one memcmp pass
// and zero bytes.
//
// The registry is also the command loop's missing resolver: registry_get turns
// the Net_Id in a command header / result / pending record back into a live
// entity, and registry_expire_pending reverts predictions whose results never
// arrived — an entity that despawned while a prediction was in flight is
// simply skipped (nothing to revert INTO; its revert buffer is still freed).
//
// Id allocation is authority-side (registry_spawn); remote peers mirror with
// registry_insert using the id from the wire. Net ids are never reused within
// a session — u32 space outlives any friendslop run.
//
// Engine-free, like the rest of kit/net. Ownership records (Player_Id) ride
// along for the owner-stream split the session layer does when it walks with
// a field-flag filter.

Registry_Entry :: struct {
	id:     Net_Id,
	entity: rawptr,
	set:    ^Command_Set, // commands + Entity_Desc (desc-only entities use an empty command table)
	shadow: []u8,
	owner:  Player_Id, // PLAYER_ID_INVALID = host-owned
	stream: Stream_Ring, // remote-owned entities: buffered owner-stream snapshots
	warp:   u8, // owner side: bumped by registry_teleport; rides every stream snapshot
}

Registry :: struct {
	next_id: Net_Id,
	entries: map[Net_Id]Registry_Entry,
}

registry_make :: proc(allocator := context.allocator) -> Registry {
	return Registry{next_id = 1, entries = make(map[Net_Id]Registry_Entry, allocator)}
}

registry_destroy :: proc(reg: ^Registry) {
	for _, &e in reg.entries {
		delete(e.shadow)
		stream_ring_destroy(&e.stream)
	}
	delete(reg.entries)
	reg.entries = nil
}

// Authority-side registration: allocates the id. The fresh shadow is zeroed,
// so the entity's first delta walk marks every non-zero field dirty — exactly
// the initial send a newly spawned entity needs.
registry_spawn :: proc(reg: ^Registry, entity: rawptr, set: ^Command_Set, owner := PLAYER_ID_INVALID) -> Net_Id {
	id := reg.next_id
	reg.next_id += 1
	registry_insert(reg, id, entity, set, owner)
	return id
}

// Remote-side registration under an id received from the wire. Keeps next_id
// ahead of everything seen so a session that later BECOMES the authority
// (host migration) can keep allocating without collisions.
registry_insert :: proc(reg: ^Registry, id: Net_Id, entity: rawptr, set: ^Command_Set, owner := PLAYER_ID_INVALID) {
	assert(id != NET_ID_INVALID)
	// Comma-ok, NOT a bare missing-key index: indexing a map by an absent key
	// of a large value type faults in the current compiler (see the stats-map
	// note in kit/session) — and absent is this assert's NORMAL path.
	_, exists := reg.entries[id]
	assert(!exists, "net id registered twice")
	if set.net_id_offset > 0 {
		(cast(^Net_Id)(uintptr(entity) + uintptr(set.net_id_offset)))^ = id
	}
	reg.entries[id] = Registry_Entry {
		id     = id,
		entity = entity,
		set    = set,
		shadow = shadow_make(set.entity_desc),
		owner  = owner,
	}
	if id >= reg.next_id {
		reg.next_id = id + 1
	}
}

registry_remove :: proc(reg: ^Registry, id: Net_Id) -> bool {
	e, ok := reg.entries[id]
	if !ok {
		return false
	}
	delete(e.shadow)
	stream_ring_destroy(&e.stream)
	delete_key(&reg.entries, id)
	return true
}

// Resolve a wire id to a live entry (nil entity = unknown/despawned).
registry_get :: proc(reg: ^Registry, id: Net_Id) -> (Registry_Entry, bool) {
	e, ok := reg.entries[id]
	return e, ok
}

registry_count :: proc(reg: ^Registry) -> int {
	return len(reg.entries)
}

// ---------------------------------------------------------------------------
// The per-net-tick walk: one batched message for all dirty entities.
//
// Batch layout: [count u16] then count × ([net_id u32][mask][dirty fields]).
// The mask width is per-entity (derived from its descriptor), so heterogeneous
// entity types mix freely in one batch.

// Walk every entry, appending deltas for the dirty ones and committing their
// shadows. Returns how many entities were written; on 0 the writer only gained
// the zero count header — callers may skip sending the message entirely. Map
// iteration order is unspecified and irrelevant: entries are independent and
// receivers dispatch by id.
registry_write_deltas :: proc(w: ^Writer, reg: ^Registry) -> int {
	count_at := len(w.buf)
	write_u16(w, 0) // patched below
	count := 0
	for _, &e in reg.entries {
		mask_at := len(w.buf)
		write_net_id(w, e.id)
		mask := write_delta(w, e.entity, e.shadow, e.set.entity_desc)
		if mask == 0 {
			resize(&w.buf, mask_at) // idle: drop the id we speculatively wrote
			continue
		}
		count += 1
	}
	assert(count <= int(max(u16)))
	w.buf[count_at] = u8(count)
	w.buf[count_at + 1] = u8(count >> 8)
	return count
}

// ---------------------------------------------------------------------------
// Prediction reconcile — the client-side answer to the in-flight race the acid
// test exposed: the host sends a delta BEFORE executing a command the client
// already predicted, and the delta stomps the optimistic values. The fix is
// the missing half of "prediction re-runs the SAME proc":
//
//   UNWIND  restore this entity's pending reverts newest-first, bringing the
//           entity back to its pre-prediction baseline (needed for DELTAS only:
//           a partial mask must not leave predicted values on fields it does
//           not carry — replaying on top of those would double-apply).
//   apply   the authoritative delta / full / reject-truth.
//   REPLAY  re-run each pending command oldest-first from its stored wire
//           bytes, recapturing its revert first — the fresh authoritative
//           state becomes the prediction's new baseline, so a later timeout
//           or truncated-truth fallback restores authoritative values, never
//           stale ones. A replay whose precondition no longer holds is
//           restored and effectively dropped locally; the host's result
//           (still in flight) has the final word either way.
//
// CORRECTNESS RELIES ON CHANNEL ORDERING: a delta that already CONTAINS a
// command's effect must arrive after that command's result — otherwise the
// still-pending command replays on top of its own effect. The session layer
// guarantees it by putting results and state batches on the same reliable
// ordered channel (one more reason for that channel plan).

// A pending takes part in reconcile iff it can replay: unwind and replay must
// use the SAME predicate or the pair corrupts state.
@(private = "file")
pending_reconciles :: proc(p: Pending, e: Registry_Entry) -> bool {
	return p.entity == e.id && p.args != nil && int(p.cmd) < len(e.set.commands)
}

@(private = "file")
unwind_pending :: proc(ctx: ^Command_Ctx, e: Registry_Entry) {
	#reverse for &p in ctx.pending.entries {
		if pending_reconciles(p, e) {
			fields_restore(e.entity, e.set.entity_desc, p.revert)
		}
	}
}

@(private = "file")
replay_pending :: proc(ctx: ^Command_Ctx, e: Registry_Entry) {
	for &p in ctx.pending.entries {
		if !pending_reconciles(p, e) {
			continue
		}
		delete(p.revert)
		p.revert = fields_capture(e.entity, e.set.entity_desc)
		r := reader_make(p.args)
		if !(e.set.commands[p.cmd].invoke(e.entity, &r) && !r.err) {
			fields_restore(e.entity, e.set.entity_desc, p.revert)
		}
	}
}

@(private = "file")
has_pending_for :: proc(ctx: ^Command_Ctx, id: Net_Id) -> bool {
	if ctx == nil {
		return false
	}
	for &p in ctx.pending.entries {
		if p.entity == id {
			return true
		}
	}
	return false
}

// Apply a delta batch. Pass the client's ctx so entities with in-flight
// predictions are reconciled (unwind → apply → replay, above); nil ctx skips
// that, which is what hosts and hand-driven tests want.
//
// An UNKNOWN id is unrecoverable mid-batch — field sizes come from the
// entity's descriptor, which this peer doesn't have — so the batch is
// abandoned there (r.err set) and the number of entities applied so far is
// returned. The session layer prevents this by construction: spawn/despawn
// messages ride the same reliable ordered channel as these batches, so a peer
// always knows every id a batch can name. That ordering contract is THE reason
// state batches go on the reliable channel rather than the stream one.
registry_apply_deltas :: proc(r: ^Reader, reg: ^Registry, ctx: ^Command_Ctx = nil) -> int {
	count := int(read_u16(r))
	applied := 0
	for _ in 0 ..< count {
		id := read_net_id(r)
		if r.err {
			break
		}
		e, ok := reg.entries[id]
		if !ok {
			r.err = true // can't size the unknown entity's fields — abandon the rest
			break
		}
		reconcile := has_pending_for(ctx, id)
		if reconcile {
			unwind_pending(ctx, e)
		}
		_ = apply_delta(r, e.entity, e.set.entity_desc)
		if r.err {
			break
		}
		if reconcile {
			replay_pending(ctx, e)
		}
		applied += 1
	}
	return applied
}

// Full-state batch: every entity, every field — the join/backup snapshot.
// Same [count][net_id][fields] shape, no masks.
registry_write_fulls :: proc(w: ^Writer, reg: ^Registry) -> int {
	assert(len(reg.entries) <= int(max(u16)))
	write_u16(w, u16(len(reg.entries)))
	for _, &e in reg.entries {
		write_net_id(w, e.id)
		write_full(w, e.entity, e.set.entity_desc)
	}
	return len(reg.entries)
}

registry_apply_fulls :: proc(r: ^Reader, reg: ^Registry, ctx: ^Command_Ctx = nil) -> int {
	count := int(read_u16(r))
	applied := 0
	for _ in 0 ..< count {
		id := read_net_id(r)
		if r.err {
			break
		}
		e, ok := reg.entries[id]
		if !ok {
			r.err = true
			break
		}
		apply_full(r, e.entity, e.set.entity_desc)
		if r.err {
			break
		}
		// A full overwrites EVERY declared field — the baseline is authoritative
		// outright, so no unwind is needed before replaying pendings on top.
		if has_pending_for(ctx, id) {
			replay_pending(ctx, e)
		}
		applied += 1
	}
	return applied
}

// After applying an authoritative full snapshot (join/reconnect), the local
// shadows must agree with what the authority believes was delivered, so the
// next local diff doesn't re-flag everything (relevant to a migrating host).
registry_commit_shadows :: proc(reg: ^Registry) {
	for _, &e in reg.entries {
		shadow_capture(e.entity, e.shadow, e.set.entity_desc)
	}
}

// ---------------------------------------------------------------------------
// Owner streams: the per-tick walk for the fields the HOST does not own.
//
// Batch layout: [sender_time f64][count u16] then count × ([net_id u32]
// [warp u8][len u16][streamed fields]). Unlike delta batches, every entity carries its
// byte LENGTH: streams ride the UNRELIABLE channel, so a batch may arrive
// before the spawn that would make its ids known — an unknown id is simply
// skipped by length instead of abandoning the batch (the next tick supersedes
// everything anyway). sender_time is the owner's clock; read it with
// registry_stream_time before applying, then stamp the ring with whichever
// timeline the session uses (arrival time, or sender time mapped through a
// per-peer Clock_Sync).

// TELEPORT: the owner declares a discontinuity in this entity's streamed
// fields — a respawn, a level change, a blink. The warp counter rides every
// subsequent stream snapshot; receivers never interpolate ACROSS a warp
// boundary, they snap to the far side (see stream_ring_sample). Riding the
// snapshots makes it drop-proof on the unreliable channel: whichever
// snapshot arrives first after the jump carries the new count.
registry_teleport :: proc(reg: ^Registry, id: Net_Id) {
	if e, found := reg.entries[id]; found {
		e.warp += 1
		reg.entries[id] = e
	}
}

// Write one stream batch for every entity owned by `me`. Returns the entity
// count; 0 = nothing owned that streams (skip the send).
registry_write_streams :: proc(w: ^Writer, reg: ^Registry, me: Player_Id, sender_now: f64) -> int {
	write_f64(w, sender_now)
	count_at := len(w.buf)
	write_u16(w, 0) // patched below
	count := 0
	for _, &e in reg.entries {
		if e.owner != me {
			continue
		}
		n := stream_data_size(e.set.entity_desc)
		if n == 0 {
			continue
		}
		assert(n <= int(max(u16)))
		write_net_id(w, e.id)
		write_u8(w, e.warp)
		write_u16(w, u16(n))
		stream_write(w, e.entity, e.set.entity_desc)
		count += 1
	}
	assert(count <= int(max(u16)))
	w.buf[count_at] = u8(count)
	w.buf[count_at + 1] = u8(count >> 8)
	return count
}

// The batch's sender-clock stamp — call once, before registry_apply_streams.
registry_stream_time :: proc(r: ^Reader) -> f64 {
	return read_f64(r)
}

// Buffer a received stream batch into the target entities' rings, stamped with
// `stamp` (the caller's timeline — see the header comment). Entities that are
// unknown, owned by `me` (never accept a stream for state this peer is
// authoritative over), or size-mismatched are skipped by length. Returns how
// many entities were buffered.
registry_apply_streams :: proc(r: ^Reader, reg: ^Registry, me: Player_Id, stamp: f64) -> int {
	count := int(read_u16(r))
	applied := 0
	for _ in 0 ..< count {
		id := read_net_id(r)
		warp := read_u8(r)
		n := int(read_u16(r))
		if r.err || r.off + n > len(r.data) {
			r.err = true
			break
		}
		blob := r.data[r.off:r.off + n]
		r.off += n
		e, ok := reg.entries[id]
		if !ok || e.owner == me || n != stream_data_size(e.set.entity_desc) {
			continue
		}
		stream_ring_push(&e.stream, stamp, blob, warp)
		reg.entries[id] = e // ring bookkeeping changed; store back (no map addressing)
		applied += 1
	}
	return applied
}

// Sample every remote-owned entity's ring at time `t`, writing interpolated
// values into the entities' streamed fields. Call once per FRAME (not per net
// tick) with t = timeline_now - interp delay. Returns how many entities moved.
registry_sample_streams :: proc(reg: ^Registry, t: f64, me: Player_Id) -> int {
	sampled := 0
	for _, &e in reg.entries {
		if e.owner == me || e.stream.count == 0 {
			continue
		}
		if stream_ring_sample(&e.stream, t, e.entity, e.set.entity_desc) {
			sampled += 1
		}
	}
	return sampled
}

// ---------------------------------------------------------------------------
// Command-loop glue: the registry is the resolver brick 4 left to the caller.

// Host side: handle one received command message end-to-end — header, dedup,
// resolve, execute, and (for resolvable entities) write the result into `out`.
// Returns whether a result was produced, plus the parsed header so the caller
// can tell its game WHAT ran (the session's command hook rides on it).
// Unknown entities produce NO result (the client's pending expiry is the
// safety net — we can't write truth for an entity we don't have).
registry_host_command :: proc(reg: ^Registry, ctx: ^Command_Ctx, peer_key: u64, r: ^Reader, out: ^Writer) -> (responded: bool, ok: bool, h: Command_Header) {
	h = command_read_header(r)
	if r.err || !command_dedup(ctx, peer_key, h.seq) {
		return false, false, h
	}
	e, found := reg.entries[h.entity]
	if !found {
		return false, false, h
	}
	ok = command_execute(e.entity, e.set, h.cmd, r)
	command_result_write(out, h, ok, e.entity, e.set)
	return true, ok, h
}

// Client side: route a received result to its entity. Unknown entity (it
// despawned while the command was in flight): the pending entry is popped and
// its revert freed — there is nothing to revert into.
registry_client_result :: proc(reg: ^Registry, ctx: ^Command_Ctx, r: ^Reader, me := PLAYER_ID_INVALID) -> Command_Result {
	res := command_result_read(r)
	if r.err {
		return res
	}
	if res.ok {
		command_confirm(ctx, res.seq)
		return res
	}
	if e, found := reg.entries[res.entity]; found {
		owned_here := me != PLAYER_ID_INVALID && e.owner == me
		command_reject(ctx, res, r, e.entity, e.set, owned_here)
		// The reject's truth snapshot (a full) stomped the entity — replay any
		// LATER predictions still pending on it, exactly like an applied full.
		if has_pending_for(ctx, res.entity) {
			replay_pending(ctx, e)
		}
	} else if p, had := pending_reject(&ctx.pending, res.seq); had {
		pending_dispose(p)
	}
	return res
}

// Revert every prediction whose result never arrived (loud auto-revert — a
// silent host must read as "no"). Entities that despawned meanwhile are
// skipped; every revert buffer is freed. Returns how many predictions expired.
// An expired prediction, reported so higher layers can emit an addressed
// rejection (a zero-valued event is useless to UI keyed on seq/entity).
Expired_Command :: struct {
	seq:    Intent_Seq,
	entity: Net_Id,
	cmd:    u16,
}

registry_expire_pending :: proc(reg: ^Registry, ctx: ^Command_Ctx, max_age_ticks: u64, me := PLAYER_ID_INVALID, out: ^[dynamic]Expired_Command = nil) -> int {
	expired := make([dynamic]Pending, context.temp_allocator)
	pending_expire(&ctx.pending, ctx.now_tick, max_age_ticks, &expired)
	for p in expired {
		if e, found := reg.entries[p.entity]; found {
			owned_here := me != PLAYER_ID_INVALID && e.owner == me
			fields_restore(e.entity, e.set.entity_desc, p.revert, skip_owner = owned_here)
		}
		if out != nil {
			append(out, Expired_Command{seq = p.seq, entity = p.entity, cmd = p.cmd})
		}
		pending_dispose(p)
	}
	return len(expired)
}
