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

import "core:fmt"
import "core:slice"

// Entity blobs are replicated state, not an upload lane. Bigger assets use
// kit/xfer so they are chunked and paced instead of blocking world/state
// traffic behind one reliable packet.
ENTITY_BLOB_MAX_BYTES :: 256 * 1024

Registry_Entry :: struct {
	id:            Net_Id,
	entity:        rawptr,
	set:           ^Command_Set, // commands + Entity_Desc (desc-only entities use an empty command table)
	shadow:        []u8,
	owner:         Player_Id, // PLAYER_ID_INVALID = host-owned
	// LOCAL prediction: this peer expects to own the entity (a transfer it just
	// requested) and is writing its owner-streamed fields NOW, before the host
	// confirms. While set, registry_sample_streams leaves it alone — the write
	// sticks instead of being stomped by the current owner's stream every frame
	// (the scratch-field dance every pass-the-object game hand-rolled). Cleared
	// by registry_set_owner when the real transfer lands. Per-peer, never on the
	// wire — the host and other peers never see it.
	predict_owner: bool,
	stream:        Stream_Ring, // remote-owned entities: buffered owner-stream snapshots
	warp:          u8, // owner side: bumped by registry_teleport; rides every stream snapshot
	tier:          u8, // owner side: stream every Nth tick (0/1 = every tick). A frequency
	// tier — cheap far/AI entities at 30Hz while players stay 60Hz.
	// Streams are unreliable last-value, so a skipped tick reads like a
	// dropped packet; interp smooths the sparser keyframes (keep the tier
	// PERIOD under interp_delay or remote motion stutters). Send-side
	// local hint, NOT replicated — a new authority re-applies it.
	blob:          []u8, // the entity's opaque payload (registry_set_blob) — nil = never set
	blob_ver:      u32, // bumped per set; receivers use it to drop re-received duplicates
	// The edge mirror (edge.odin): last-presented bytes of the class's
	// edge-declared fields. nil for classes without edge halves; seeded on
	// first sight and on resync — silently, both times.
	edge_shadow:   []u8,
	edge_seeded:   bool,
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
		delete(e.blob)
		delete(e.edge_shadow)
		stream_ring_destroy(&e.stream)
	}
	delete(reg.entries)
	reg.entries = nil
}

// Allocate the next authority id WITHOUT inserting — for a composer that must
// name the id before the entity exists (kit/session stamps it into the spawn
// tuple, then inserts). The allocation rule lives here either way.
registry_alloc_id :: proc(reg: ^Registry) -> Net_Id {
	id := reg.next_id
	reg.next_id += 1
	return id
}

// Raise the allocator floor without inserting — a resumed authority (host
// migration) adopts the dead host's high-water mark so it keeps allocating
// without collisions. The per-id insert chase below does this incrementally;
// this is the bulk form a snapshot restore needs.
registry_reserve_ids :: proc(reg: ^Registry, floor: Net_Id) {
	reg.next_id = max(reg.next_id, floor)
}

// Authority-side registration: allocates the id. The fresh shadow is zeroed,
// so the entity's first delta walk marks every non-zero field dirty — exactly
// the initial send a newly spawned entity needs.
registry_spawn :: proc(
	reg: ^Registry,
	entity: rawptr,
	set: ^Command_Set,
	owner := PLAYER_ID_INVALID,
) -> Net_Id {
	id := registry_alloc_id(reg)
	registry_insert(reg, id, entity, set, owner)
	return id
}

// Remote-side registration under an id received from the wire. Keeps next_id
// ahead of everything seen so a session that later BECOMES the authority
// (host migration) can keep allocating without collisions.
registry_insert :: proc(
	reg: ^Registry,
	id: Net_Id,
	entity: rawptr,
	set: ^Command_Set,
	owner := PLAYER_ID_INVALID,
) {
	assert(id != NET_ID_INVALID)
	assert(
		u32(id) & PROVISIONAL_BIT == 0,
		"provisional (high-bit) ids are lane-local and never enter the registry",
	)
	for cmd in set.commands {
		assert(action_desc_valid(cmd.action, .Immediate), "registry_insert: invalid immediate action descriptor")
	}
	// Comma-ok, NOT a bare missing-key index: indexing a map by an absent key
	// of a large value type faults in the current compiler (see the stats-map
	// note in kit/session) — and absent is this assert's NORMAL path.
	_, exists := reg.entries[id]
	assert(!exists, "net id registered twice")
	assert(
		len(reg.entries) < MAX_CONTAINER_ITEMS,
		"registry exceeds MAX_CONTAINER_ITEMS — partition the world/interest domain",
	)
	if set.net_id_offset > 0 {
		(cast(^Net_Id)(uintptr(entity) + uintptr(set.net_id_offset)))^ = id
	}
	entry := Registry_Entry {
		id     = id,
		entity = entity,
		set    = set,
		shadow = shadow_make(set.entity_desc),
		owner  = owner,
	}
	if n := edge_shadow_size(set); n > 0 {
		entry.edge_shadow = make([]u8, n)
	}
	reg.entries[id] = entry
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
	delete(e.blob)
	delete(e.edge_shadow)
	stream_ring_destroy(&e.stream)
	delete_key(&reg.entries, id)
	return true
}

// Resolve a wire id to a live entry. Returns a POINTER into the registry —
// mutations land in place, no store-back needed — valid until the next
// insert/remove. (The old by-value return copied a whole Stream_Ring per call
// and invited mutate-the-copy-and-forget bugs.)
registry_get :: proc(reg: ^Registry, id: Net_Id) -> (^Registry_Entry, bool) {
	e, ok := &reg.entries[id]
	return e, ok
}

registry_count :: proc(reg: ^Registry) -> int {
	return len(reg.entries)
}

// ---------------------------------------------------------------------------
// The per-net-tick walk: one batched message for all dirty entities.
//
// Batch layout: [count u16] then count × ([net_id u32][mask][dirty fields]).
// The mask width is per-entity — ceil(delta-lane members / 8), bit = subset
// ordinal (knet.WIRE_REV 2) — so heterogeneous entity types mix freely in
// one batch.

// Walk every entry, appending deltas for the dirty ones and committing their
// shadows. Returns how many entities were written; on 0 the writer only gained
// the zero count header — callers may skip sending the message entirely. Map
// iteration order is unspecified and irrelevant: entries are independent and
// receivers dispatch by id.
registry_write_deltas :: proc(w: ^Writer, reg: ^Registry, changed: ^[dynamic]Net_Id = nil) -> int {
	count_at := len(w.buf)
	write_u16(w, 0) // patched below
	count := 0
	for _, &e in reg.entries {
		if count >= MAX_CONTAINER_ITEMS {
			break
		}
		v := subset_view(e.set.entity_desc, .Delta)
		mask := diff_mask(e.entity, e.shadow, e.set.entity_desc)
		if mask == 0 {
			continue
		}
		row_bytes := 4 + v.mask_bytes
		for entry, ord in v.entries {
			if mask & (u64(1) << u64(ord)) != 0 {
				row_bytes += int(entry.wire_size)
			}
		}
		if row_bytes > MAX_PACKET_BYTES - len(w.buf) {
			continue // shadow stays dirty; a later packet can carry it
		}
		write_net_id(w, e.id)
		_ = write_delta(w, e.entity, e.shadow, e.set.entity_desc)
		if changed != nil {
			append(changed, e.id)
		}
		count += 1
	}
	assert(count <= int(max(u16)))
	writer_patch_u16(w, count_at, u16(count))
	return count
}

// One entity's segment inside a scratch buffer — recorded as a RANGE (a
// writer's buffer relocates as it grows; slice after the walk). Shared by the
// delta collect below and the stream-batch collect: both exist so a composer
// (kit/session's interest routing) can re-batch per recipient by copying
// ranges verbatim, without either side re-learning the byte layout.
Delta_Seg :: struct {
	id:       Net_Id,
	from, to: int,
}

// Interest-aware sibling of registry_write_deltas: the SAME walk and the same
// single shadow commit, but every dirty entity's segment ([id][mask][bytes])
// is recorded so the caller can compose PER-RECIPIENT batches (kit/session's
// interest management). Segments carry no count header — the composer writes
// its own per batch.
registry_collect_deltas :: proc(
	scratch: ^Writer,
	reg: ^Registry,
	segs: ^[dynamic]Delta_Seg,
	changed: ^[dynamic]Net_Id = nil,
) -> int {
	for _, &e in reg.entries {
		if len(segs) >= MAX_CONTAINER_ITEMS {
			break
		}
		v := subset_view(e.set.entity_desc, .Delta)
		mask := diff_mask(e.entity, e.shadow, e.set.entity_desc)
		if mask == 0 {
			continue
		}
		row_bytes := 4 + v.mask_bytes
		for entry, ord in v.entries {
			if mask & (u64(1) << u64(ord)) != 0 {
				row_bytes += int(entry.wire_size)
			}
		}
		if row_bytes > MAX_PACKET_BYTES - len(scratch.buf) {
			continue
		}
		start := len(scratch.buf)
		write_net_id(scratch, e.id)
		_ = write_delta(scratch, e.entity, e.shadow, e.set.entity_desc)
		if changed != nil {
			append(changed, e.id)
		}
		append(segs, Delta_Seg{id = e.id, from = start, to = len(scratch.buf)})
	}
	return len(segs)
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
// use the SAME predicate or the pair corrupts state. "Can replay" is the
// explicit Pending.replayable bit (zero-arg commands have empty bytes too) —
// the verb itself is resolved by STABLE id at replay
// time (command_find; a miss restores and drops). Never compare p.cmd against
// the set's length: ids are FNV hashes, not array positions, and that stale
// index check silently disabled reconcile for every generated command (the
// confirm-2 acid signature — a delta stomping an in-flight prediction).
@(private = "file")
pending_reconciles :: proc(p: Pending, e: ^Registry_Entry) -> bool {
	return p.entity == e.id && p.replayable
}

@(private = "file")
unwind_pending :: proc(ctx: ^Command_Ctx, e: ^Registry_Entry) {
	#reverse for &p in ctx.pending.entries {
		if pending_reconciles(p, e) {
			// Client-only path: predicted fields belong to the sim lane.
			fields_restore(e.entity, e.set.entity_desc, p.revert, {.Predicted})
		}
	}
}

@(private = "file")
replay_pending :: proc(ctx: ^Command_Ctx, e: ^Registry_Entry) {
	// Replays are re-predictions, never authoritative: the env keeps each
	// re-run's `_then` consequence quiet, exactly like the original prediction.
	env := Command_Env {
		authority = false,
		user      = ctx.game_user,
		by        = ctx.me,
	}
	for &p in ctx.pending.entries {
		if !pending_reconciles(p, e) {
			continue
		}
		delete(p.revert)
		p.revert = fields_capture(e.entity, e.set.entity_desc)
		r := reader_make(p.args)
		// Lookup by the verb's stable id (recorded from our own issue, so a miss
		// can't really happen — treated as a failed replay if it somehow does).
		c := command_find(e.set, p.cmd)
		if c == nil || !(c.invoke(e.entity, &r, &env) && !r.err) {
			fields_restore(e.entity, e.set.entity_desc, p.revert, {.Predicted})
		}
	}
}

@(private = "file")
has_pending_for :: proc(ctx: ^Command_Ctx, id: Net_Id) -> bool {
	if ctx == nil {
		return false
	}
	for &p in ctx.pending.entries {
		if p.entity == id && p.predicted {
			return true
		}
	}
	return false
}

@(private = "file")
registry_preflight_deltas :: proc(r: ^Reader, reg: ^Registry) -> bool {
	count := int(read_u16(r))
	if !reader_admit_count(r, count, 4) {
		return false
	}
	for _ in 0 ..< count {
		id := read_net_id(r)
		e, ok := &reg.entries[id]
		if r.err || !ok {
			r.err = true
			return false
		}
		v := subset_view(e.set.entity_desc, .Delta)
		mask: u64
		for i in 0 ..< v.mask_bytes {
			mask |= u64(read_u8(r)) << (u64(i) * 8)
		}
		if r.err || (len(v.entries) < 64 && mask >> u64(len(v.entries)) != 0) {
			r.err = true
			return false
		}
		for entry, ord in v.entries {
			if mask & (u64(1) << u64(ord)) != 0 {
				_ = reader_view(r, int(entry.wire_size))
			}
		}
		if r.err {
			return false
		}
	}
	if len(reader_remaining(r)) != 0 {
		r.err = true
		return false
	}
	return true
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
registry_apply_deltas :: proc(
	r: ^Reader,
	reg: ^Registry,
	ctx: ^Command_Ctx = nil,
	changed: ^[dynamic]Net_Id = nil,
) -> int {
	probe := r^
	if !registry_preflight_deltas(&probe, reg) {
		r.err = true
		return 0
	}
	count := int(read_u16(r))
	applied := 0
	for _ in 0 ..< count {
		id := read_net_id(r)
		if r.err {
			break
		}
		// Pointer lookup on purpose: a Registry_Entry is ~500 bytes with its
		// inline Stream_Ring — the by-value copy was the exact mutate-the-
		// copy-and-forget footgun registry_get's fix comment names.
		e, ok := &reg.entries[id]
		if !ok {
			r.err = true // can't size the unknown entity's fields — abandon the rest
			break
		}
		// Transaction boundary: apply_delta is deliberately a tiny in-place
		// codec, but a reliable session packet must never expose its prefix. The
		// full replicated-field capture includes the speculative state currently
		// on screen; restoring it also restores the exact pre-unwind prediction
		// without re-running gameplay code or rewriting pending reverts.
		before := fields_capture(e.entity, e.set.entity_desc, context.temp_allocator)
		reconcile := has_pending_for(ctx, id)
		if reconcile {
			unwind_pending(ctx, e)
		}
		_ = apply_delta(r, e.entity, e.set.entity_desc)
		if r.err {
			fields_restore(e.entity, e.set.entity_desc, before)
			break
		}
		if reconcile {
			replay_pending(ctx, e)
		}
		// Bless: the shadow tracks "state the framework last put here" so the
		// write guard (registry_write_guard) can tell a local rogue write from
		// everything legitimate. Captured after the replay on purpose — a
		// pending's speculation is legal (the guard skips pending entities),
		// and its retirement re-blesses.
		shadow_capture(e.entity, e.shadow, e.set.entity_desc)
		if changed != nil {
			append(changed, id)
		}
		applied += 1
	}
	return applied
}

// Full-state batch: every entity, every field — the join/backup snapshot.
// Same [count][net_id][fields] shape, no masks.
registry_write_fulls :: proc(w: ^Writer, reg: ^Registry) -> int {
	assert(len(reg.entries) <= int(max(u16)))
	assert(len(reg.entries) <= MAX_CONTAINER_ITEMS)
	write_u16(w, u16(len(reg.entries)))
	for _, &e in reg.entries {
		write_net_id(w, e.id)
		write_full(w, e.entity, e.set.entity_desc)
	}
	return len(reg.entries)
}

// `me` names the RECEIVER: entities this peer owns keep their .Owner_Stream
// fields (the batch's copy is a lagged echo of state this peer is the
// authority for). Join seeding omits it on purpose — a fresh process has no
// local owner state worth protecting, and the snapshot IS the seed. Shadows
// are blessed inline, symmetric with registry_apply_deltas; the separate
// registry_commit_shadows stays for the resume path (which applies spawn
// tuples, not this batch).
registry_apply_fulls :: proc(
	r: ^Reader,
	reg: ^Registry,
	ctx: ^Command_Ctx = nil,
	me := PLAYER_ID_INVALID,
) -> int {
	probe := r^
	probe_count := int(read_u16(&probe))
	if !reader_admit_count(&probe, probe_count, 4) {
		r.err = true
		return 0
	}
	for _ in 0 ..< probe_count {
		id := read_net_id(&probe)
		e, ok := &reg.entries[id]
		if probe.err || !ok {
			r.err = true
			return 0
		}
		_ = reader_view(&probe, desc_wire_size(e.set.entity_desc))
		if probe.err {
			r.err = true
			return 0
		}
	}
	if len(reader_remaining(&probe)) != 0 {
		r.err = true
		return 0
	}
	count := int(read_u16(r))
	applied := 0
	for _ in 0 ..< count {
		id := read_net_id(r)
		if r.err {
			break
		}
		e, ok := &reg.entries[id]
		if !ok {
			r.err = true
			break
		}
		// apply_full is the same in-place codec as apply_delta. Join/resync data
		// is reliable too, so a torn entity restores as one unit and is never
		// shadow-blessed as an authoritative baseline.
		before := fields_capture(e.entity, e.set.entity_desc, context.temp_allocator)
		owned_here := me != PLAYER_ID_INVALID && e.owner == me
		skip: Subset_Skips
		if owned_here {
			skip = {.Owner}
		}
		apply_full(r, e.entity, e.set.entity_desc, skip)
		if r.err {
			fields_restore(e.entity, e.set.entity_desc, before)
			break
		}
		// A full overwrites EVERY declared field — the baseline is authoritative
		// outright, so no unwind is needed before replaying pendings on top.
		if has_pending_for(ctx, id) {
			replay_pending(ctx, e)
		}
		shadow_capture(e.entity, e.shadow, e.set.entity_desc)
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
// Entity blobs — the variable-length escape hatch.
//
// One opaque, AUTHOR-DIRTIED payload per entity. Deliberately not a field:
// no diffing (the author says when it changed — which deletes the entire
// "how do you memcmp a pointer-bearing value" problem), no interpolation, no
// prediction capture/restore, no owner streams. The session layer ships it
// reliably on set and folds it into every full snapshot, so late joiners,
// backup hosts, and saves all carry it for free. Anything event-shaped still
// belongs in app messages; a blob is for state a NEW observer must see.

// Authority side: replace the entity's blob (bytes are copied; empty clears it).
// Bumps the version so receivers can drop re-received duplicates.
registry_set_blob :: proc(reg: ^Registry, id: Net_Id, data: []u8) -> bool {
	if len(data) > ENTITY_BLOB_MAX_BYTES {
		return false
	}
	e, ok := &reg.entries[id]
	if !ok {
		return false
	}
	delete(e.blob)
	e.blob = nil
	if len(data) > 0 {
		e.blob = make([]u8, len(data))
		copy(e.blob, data)
	}
	e.blob_ver += 1
	return true
}

// Receiver side: install a blob that arrived with an explicit version (wire /
// snapshot). Returns false when this version is already held — the caller
// skips its change notification (a rejoin re-receives the world).
registry_apply_blob :: proc(reg: ^Registry, id: Net_Id, ver: u32, data: []u8) -> bool {
	if len(data) > ENTITY_BLOB_MAX_BYTES {
		return false
	}
	e, ok := &reg.entries[id]
	if !ok || ver == e.blob_ver {
		return false
	}
	delete(e.blob)
	e.blob = nil
	if len(data) > 0 {
		e.blob = make([]u8, len(data))
		copy(e.blob, data)
	}
	e.blob_ver = ver
	return true
}

// The entity's current blob (a view — valid until the next set/apply/remove)
// and its version (0 = never set).
registry_blob :: proc(reg: ^Registry, id: Net_Id) -> (data: []u8, ver: u32) {
	if e, ok := &reg.entries[id]; ok {
		return e.blob, e.blob_ver
	}
	return nil, 0
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
	if e, found := &reg.entries[id]; found {
		e.warp += 1
	}
}

// OWNERSHIP TRANSFER: from now on, `owner`'s writes are what stream out of
// this entity's .Owner_Stream fields (PLAYER_ID_INVALID = nobody streams —
// host-authoritative deltas still flow like always). Ring and warp reset so
// remote screens SNAP to the new owner's first snapshot instead of
// interpolating across the handoff; the OLD owner stops streaming by
// construction (registry_write_streams only walks entities owned by me).
// In-flight packets from the old owner may land for ~a round trip — they
// carry the pre-bump warp, so the first new-warp sample supersedes them with
// a snap, never a blend. Every peer must apply the same transfer (the
// session layer broadcasts it ordered with spawns and deltas).
// `keep_fields` skips the handoff flush below, keeping the entity's CURRENT
// field values — used when this peer's own predicted-ownership write is the one
// becoming real (its fields already hold the truth; flushing a stale buffered
// sample over them would stomp the very prediction the transfer confirmed).
registry_set_owner :: proc(
	reg: ^Registry,
	id: Net_Id,
	owner: Player_Id,
	now: f64 = -1,
	keep_fields := false,
) -> bool {
	e, ok := &reg.entries[id]
	if !ok {
		return false
	}
	e.predict_owner = false // the transfer resolved; the local prediction is over
	if e.owner == owner {
		return true
	}
	e.owner = owner
	// The handoff SNAP the docs promise: flush the freshest buffered sample
	// into the fields BEFORE the ring dies. Without it, the new owner seeds
	// its sim from the render view — interp_delay behind — and a possession
	// shorter than that delay hands the NEXT owner a pose one possession
	// stale (slopball's rubber-band: every quick trade snapped the ball back
	// to the previous owner's previous spot). Watchers re-anchor too. Skipped
	// when THIS peer's prediction is what confirmed (keep_fields).
	if !keep_fields {
		stream_ring_flush_newest(&e.stream, e.entity, e.set.entity_desc)
	}
	stream_ring_reset(&e.stream)
	// ...and BRIDGE the seam: seed the fresh ring with those same fields so
	// watcher interpolation flows through the handoff instead of pausing an
	// interp window waiting for the new owner's first sample to come of age.
	if now >= 0 {
		stream_ring_seed(&e.stream, now, e.entity, e.set.entity_desc)
	}
	e.warp += 1
	return true
}

// LOCAL: predict that this peer is about to own `id` — its owner-streamed field
// writes hold instead of being stomped by the current owner's stream, so the
// pickup/strike/possession SHOWS the instant you act, before the host confirms.
// Set it when you issue the transfer request (a predicted command), writing the
// fields you want; registry_set_owner clears it when the real transfer lands
// (kept, if it landed on you). Clear it yourself if the request is DENIED — the
// entity then resumes sampling and snaps back to the true owner's stream.
registry_predict_owner :: proc(reg: ^Registry, id: Net_Id, predicting := true) {
	if e, ok := &reg.entries[id]; ok {
		e.predict_owner = predicting
	}
}

// Owner side: this entity streams only every `tier` ticks (0/1 = every tick).
// A frequency tier — the bandwidth lever for many cheap AI/far entities.
registry_set_stream_tier :: proc(reg: ^Registry, id: Net_Id, tier: u8) {
	if e, ok := &reg.entries[id]; ok {
		e.tier = tier
	}
}

// Write one stream batch for every entity owned by `me`. Returns the entity
// count; 0 = nothing owned that streams (skip the send). `tick` gates the
// per-entity frequency tier: a tiered entity is written only on the ticks its
// id+tier phase selects, so different entities send on different ticks and the
// byte rate stays smooth (~1/tier of them per tick) instead of pulsing.
// `keep_history`: the AUTHORITY's flag — every snapshot it ships of its OWN
// streamed entities (the mobs, its own avatar) is also pushed into that
// entity's ring, stamped with the same sender clock, so registry_rewound can
// wind host-owned bodies back to what a client's screen was drawing exactly
// like it winds other clients' bodies (whose rings fill from their inbound
// streams). Without it the host's own entities had no history and were
// judged LIVE for a lagged shooter — the one hole coop lag comp left, which
// every game with host-brained targets re-ledgered by hand.
registry_write_streams :: proc(
	w: ^Writer,
	reg: ^Registry,
	me: Player_Id,
	sender_now: f64,
	tick: u64 = 0,
	keep_history := false,
) -> int {
	write_f64(w, sender_now)
	count_at := len(w.buf)
	write_u16(w, 0) // patched below
	count := 0
	for _, &e in reg.entries {
		if count >= MAX_CONTAINER_ITEMS {
			break
		}
		if e.owner != me {
			continue
		}
		if e.tier > 1 && (tick + u64(e.id)) % u64(e.tier) != 0 {
			continue // off-phase this tick — the last snapshot still stands
		}
		n := stream_wire_size(e.set.entity_desc)
		if n == 0 {
			continue
		}
		if 7 + n > MAX_PACKET_BYTES - len(w.buf) {
			continue
		}
		assert(n <= int(max(u16)))
		write_net_id(w, e.id)
		write_u8(w, e.warp)
		write_u16(w, u16(n))
		stream_write(w, e.entity, e.set.entity_desc)
		if keep_history {
			// The ring holds STRUCT-layout snapshots (what the receive side
			// decodes to — wire encodings like f16 never reach a ring), so the
			// history is a subset_capture of the entity, not the wire bytes.
			v := subset_view(e.set.entity_desc, .Owner)
			hist := make([]u8, v.struct_bytes, context.temp_allocator)
			subset_capture(v, e.entity, hist)
			stream_ring_push(&e.stream, sender_now, hist, e.warp)
		}
		count += 1
	}
	assert(count <= int(max(u16)))
	writer_patch_u16(w, count_at, u16(count))
	return count
}

// The batch's sender-clock stamp — call once, before registry_apply_streams.
registry_stream_time :: proc(r: ^Reader) -> f64 {
	return read_f64(r)
}

// The read-side sibling of registry_write_streams: split a raw stream batch
// (everything after the transport's tag byte) into per-entity segments
// WITHOUT decoding them — for a relay that composes per-recipient batches
// (kit/session's interest routing), symmetric with registry_collect_deltas.
// Each segment's range covers [id][warp][len][bytes] whole, copyable
// verbatim. ok=false = torn batch, forward nothing (the next tick
// supersedes). The stream batch layout is written by registry_write_streams
// and parsed by apply_streams and HERE — never outside this file.
registry_collect_stream_segs :: proc(
	raw: []u8,
	segs: ^[dynamic]Delta_Seg,
) -> (
	sender_now: f64,
	ok: bool,
) {
	r := reader_make(raw)
	sender_now = read_f64(&r)
	count := int(read_u16(&r))
	if !reader_admit_count(&r, count, 7) {
		return 0, false
	}
	for _ in 0 ..< count {
		start := r.off
		id := read_net_id(&r)
		_ = read_u8(&r) // warp
		n := int(read_u16(&r))
		_ = reader_view(&r, n)
		if r.err {
			return 0, false
		}
		append(segs, Delta_Seg{id = id, from = start, to = r.off})
	}
	if len(reader_remaining(&r)) != 0 {
		return 0, false
	}
	return sender_now, true
}

// Buffer a received stream batch into the target entities' rings, stamped with
// `stamp` (the caller's timeline — see the header comment). When `sender` is
// known (the host resolved the transport peer to a seat), EVERY row must name
// an entity that seat currently owns and have the exact declared wire size;
// the complete batch is preflighted before any ring changes. A trusted host
// relay passes PLAYER_ID_INVALID: unknown/locally-owned/size-mismatched rows
// retain the forward-compatible skip-by-length behavior. Returns how many
// entities were buffered.
registry_apply_streams :: proc(
	r: ^Reader,
	reg: ^Registry,
	me: Player_Id,
	stamp: f64,
	sender := PLAYER_ID_INVALID,
) -> int {
	// Structural atomicity matters even on a last-value lane: a torn datagram
	// must not advance some entity rings while the rest of the batch is refused.
	// With a resolved sender this is also the ownership admission pass.
	probe := r^
	probe_count := int(read_u16(&probe))
	if !reader_admit_count(&probe, probe_count, 7) {
		r.err = true
		return 0
	}
	for _ in 0 ..< probe_count {
		id := read_net_id(&probe)
		_ = read_u8(&probe)
		n := int(read_u16(&probe))
		_ = reader_view(&probe, n)
		if probe.err {
			r.err = true
			return 0
		}
		if sender != PLAYER_ID_INVALID {
			e, found := &reg.entries[id]
			if !found || e.owner != sender || n != stream_wire_size(e.set.entity_desc) {
				r.err = true
				return 0
			}
		}
	}
	if len(reader_remaining(&probe)) != 0 {
		r.err = true
		return 0
	}

	count := int(read_u16(r))
	applied := 0
	for _ in 0 ..< count {
		id := read_net_id(r)
		warp := read_u8(r)
		n := int(read_u16(r))
		blob := reader_view(r, n)
		if r.err {
			break
		}
		e, ok := &reg.entries[id]
		if !ok || e.owner == me || n != stream_wire_size(e.set.entity_desc) {
			continue
		}
		// Wire encodings stop HERE: decode to struct layout before the ring, so
		// sampling/blending/warps stay byte-shape-identical to the entity.
		if desc_has_wire(e.set.entity_desc) {
			decoded := make([]u8, stream_data_size(e.set.entity_desc), context.temp_allocator)
			stream_decode(decoded, blob, e.set.entity_desc)
			blob = decoded
		}
		stream_ring_push(&e.stream, stamp, blob, warp)
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
		if e.owner == me || e.predict_owner || e.stream.count == 0 {
			continue // owned, or predicted-owned (my writes hold), or never streamed
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
Registry_Command_Outcome :: struct {
	responded: bool,
	reason:    Action_Reject_Reason,
	header:    Command_Header,
}

// Detailed authority ingress. `admission` lets the session name a refusal it
// owns (seat/rate) after this layer has parsed the addressed command. A valid
// header always receives a compact verdict, even when its entity went stale;
// malformed headers and replayed sequences remain silent because they cannot
// be correlated safely and replying would amplify garbage.
registry_host_command :: proc(
	reg: ^Registry,
	ctx: ^Command_Ctx,
	by: Player_Id,
	r: ^Reader,
	out: ^Writer,
	admission := Action_Reject_Reason.None,
	preparsed: ^Command_Header = nil,
	deduplicate := true,
) -> Registry_Command_Outcome {
	h: Command_Header
	if preparsed != nil {
		h = preparsed^
	} else {
		h = command_read_header(r)
	}
	result := Registry_Command_Outcome {
		reason = .Malformed,
		header = h,
	}
	if h.seq == 0 || (r.err && preparsed == nil) {
		return result
	}
	if deduplicate && !command_dedup(ctx, u64(by), h.seq) {
		result.reason = .Stale
		return result
	}
	if admission != .None {
		assert(action_reject_reason_valid(admission))
		command_result_write(out, h, admission)
		result.responded = true
		result.reason = admission
		return result
	}
	e, found := &reg.entries[h.entity]
	if !found {
		command_result_write(out, h, .Stale)
		result.responded = true
		result.reason = .Stale
		return result
	}
	// Access is descriptor policy, not gameplay predicate policy. Reject it
	// explicitly so a predicting client retires immediately instead of waiting
	// for timeout.
	c := command_find(e.set, h.cmd)
	if c == nil {
		command_result_write(out, h, .Malformed)
		result.responded = true
		result.reason = .Malformed
		return result
	}
	// registry_host_command is the REMOTE ingress. Authority-authored calls run
	// through their generated local wrapper and never arrive here.
	if !action_access_allows(c.policy, by, e.owner, false) {
		command_result_write(out, h, .Access)
		result.responded = true
		result.reason = .Access
		return result
	}
	if !action_args_allowed(c.policy, len(reader_remaining(r))) {
		command_result_write(out, h, .Malformed)
		result.responded = true
		result.reason = .Malformed
		return result
	}
	// THE authoritative run: the verb's `_then` consequence fires inside the
	// thunk. `by` is the ISSUER'S Player_Id — it keys the dedup window AND
	// rides the env (the old param said "peer_key: any stable per-sender key",
	// which stopped being true the day env.by was born from it).
	env := Command_Env {
		authority = true,
		user      = ctx.game_user,
		by        = by,
	}
	result.reason = command_execute(e.entity, e.set, h.cmd, r, &env)
	// Predicate races need the authority's current truth. Admission/syntax
	// refusals never ran gameplay and stay header-only.
	command_result_write(
		out,
		h,
		result.reason,
		e.entity,
		e.set,
		truth = result.reason == .Predicate,
	)
	result.responded = true
	return result
}

// Client side: route a received result to its entity. Unknown entity (it
// despawned while the command was in flight): the pending entry is popped and
// its revert freed — there is nothing to revert into.
registry_client_result :: proc(
	reg: ^Registry,
	ctx: ^Command_Ctx,
	r: ^Reader,
	me := PLAYER_ID_INVALID,
) -> Command_Result {
	res := command_result_read(r)
	if r.err {
		return res
	}
	if res.reason == .None {
		command_confirm(ctx, res.seq)
		// Bless: the entity keeps its speculative values (the authority just
		// said yes) but the pending that licensed them is gone — without the
		// capture, the write guard would flag the gap until the effect's own
		// delta arrives.
		if e, found := &reg.entries[res.entity]; found {
			shadow_capture(e.entity, e.shadow, e.set.entity_desc)
		}
		return res
	}
	if e, found := &reg.entries[res.entity]; found {
		owned_here := me != PLAYER_ID_INVALID && e.owner == me
		command_reject(ctx, res, r, e.entity, e.set, owned_here)
		// The reject's truth snapshot (a full) stomped the entity — replay any
		// LATER predictions still pending on it, exactly like an applied full.
		if has_pending_for(ctx, res.entity) {
			replay_pending(ctx, e)
		}
		shadow_capture(e.entity, e.shadow, e.set.entity_desc) // bless the landed truth
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

registry_expire_pending :: proc(
	reg: ^Registry,
	ctx: ^Command_Ctx,
	max_age_ticks: u64,
	me := PLAYER_ID_INVALID,
	out: ^[dynamic]Expired_Command = nil,
) -> int {
	expired := make([dynamic]Pending, context.temp_allocator)
	pending_expire(&ctx.pending, ctx.now_tick, max_age_ticks, &expired)
	for p in expired {
		if p.predicted {
			if e, found := &reg.entries[p.entity]; found {
				owned_here := me != PLAYER_ID_INVALID && e.owner == me
				skip := Subset_Skips{.Predicted}
				if owned_here {
					skip += {.Owner}
				}
				fields_restore(e.entity, e.set.entity_desc, p.revert, skip)
				shadow_capture(e.entity, e.shadow, e.set.entity_desc) // bless: the revert is framework truth now
			}
		}
		if out != nil {
			append(out, Expired_Command{seq = p.seq, entity = p.entity, cmd = p.cmd})
		}
		pending_dispose(p)
	}
	return len(expired)
}

// ---------------------------------------------------------------------------
// The delta-lane WRITE GUARD — the canonical co-op bug, made loud.
//
// A client assigning to a host-lane replicated field (`self.ball.score.l += 1`)
// compiles, looks right on its own screen, and never replicates: the host's
// shadow diff never saw the write, and no correction arrives until the host
// happens to dirty that field — possibly never. It is invisible in solo and
// host-seat testing, exactly where co-op games get tested.
//
// The guard turns it into a named failure within one net tick. The invariant:
// on a CLIENT, every entity's shadow holds "the bytes the framework last put
// here" — committed at every apply/replay/revert/confirm site (the blesses
// above). Any delta-lane divergence from it on an entity with no in-flight
// prediction is therefore a local rogue write. Owner-stream fields (yours to
// write) and predicted fields (the sim lane reconciles them) are excluded by
// diff_mask itself — the same skip the host's send walk uses.
//
// Cost: the same memcmp walk per net tick the host already pays to diff.
// The walk runs in EVERY build — the session turns a finding into the
// teaching assert in dev and into a counted log-once (session_guard_hits)
// under `-disable-assert`: a shipped build re-opening the divergence class
// this guard exists to kill would cost more than the walk does.

// Re-commit one entity's shadow: "these bytes are framework-blessed". The
// sim lane calls this when a tick-scheduled verb's speculation retires
// (its delta-lane writes stand confirmed outside any ctx pending).
registry_bless :: proc(reg: ^Registry, id: Net_Id) {
	if e, ok := &reg.entries[id]; ok {
		shadow_capture(e.entity, e.shadow, e.set.entity_desc)
	}
}

// A higher layer's extra "this entity's divergence is legal right now" — the
// boot installs one that knows about the sim lane's in-flight verbs.
Guard_Exempt_Proc :: proc(user: rawptr, id: Net_Id) -> bool

// The walk: on a client, report the first delta-lane field that moved outside
// the framework since its last bless. Call once per net tick, AFTER packet
// application; entities with a ctx pending (coop speculation) or an exempt
// verdict (sim speculation) are skipped whole. Returns found = false when the
// invariant holds; the session layer turns a finding into the teaching assert
// (split so tests can pin the detection without dying on it).
registry_write_guard :: proc(
	reg: ^Registry,
	ctx: ^Command_Ctx,
	exempt: Guard_Exempt_Proc = nil,
	exempt_user: rawptr = nil,
) -> (
	cls, field: string,
	id: Net_Id,
	found: bool,
) {
	for eid, &e in reg.entries {
		if has_pending_for(ctx, eid) {
			continue
		}
		if exempt != nil && exempt(exempt_user, eid) {
			continue
		}
		mask := diff_mask(e.entity, e.shadow, e.set.entity_desc)
		if mask == 0 {
			continue
		}
		field = "?"
		v := subset_view(e.set.entity_desc, .Delta)
		for e2, ord in v.entries {
			if mask & (1 << u64(ord)) != 0 {
				f := v.fields[e2.field]
				field = f.name != "" ? f.name : fmt.tprintf("field #%d", e2.field)
				break
			}
		}
		cls = e.set.entity_desc.name != "" ? e.set.entity_desc.name : "entity"
		return cls, field, eid, true
	}
	return "", "", NET_ID_INVALID, false
}

// ---- state hash: the cheapest desync forensic --------------------------------
//
// registry_state_hash folds the whole replicated world into one number, so two
// peers can compare a single u64 and know instantly whether their authoritative
// state agrees — the cheapest desync detector there is, and the natural seed of
// a replay/rewind that must prove it reproduced the run.
//
// It walks the entities in Net_Id ORDER (map iteration is unordered; the hash
// must not be), and folds in each entity's id, its owner, its .Delta-lane field
// bytes, and its blob. The .DELTA LANE ONLY, and that restriction is the whole
// design: owner-streamed fields interpolate and predicted fields run ahead of
// truth, so two HONEST peers disagree on those every single frame — hashing them
// would cry desync on a perfectly healthy session. What the delta lane carries
// is host-authoritative and applied byte-identically on every screen, so two
// synced peers land on the same number and a difference is a real divergence.
//
// FNV-1a, the kit's stable-hash law (decl.fnv1a64) — reimplemented over bytes
// here because kit/net sits below decl. The number is only ever COMPARED between
// same-build peers, never persisted, so byte order is a non-issue.
@(private = "file")
fnv1a64_bytes :: proc(h: u64, b: []u8) -> u64 {
	h := h
	for x in b {
		h = (h ~ u64(x)) * 0x100000001b3
	}
	return h
}

@(private = "file")
fnv1a64_u64 :: proc(h: u64, v: u64) -> u64 {
	h, v := h, v
	for _ in 0 ..< 8 {
		h = (h ~ (v & 0xff)) * 0x100000001b3
		v >>= 8
	}
	return h
}

registry_state_hash :: proc(reg: ^Registry) -> u64 {
	ids := make([]Net_Id, len(reg.entries), context.temp_allocator)
	i := 0
	for id in reg.entries {
		ids[i] = id
		i += 1
	}
	slice.sort(ids)
	h := u64(0xcbf29ce484222325)
	for id in ids {
		e := &reg.entries[id]
		h = fnv1a64_u64(h, u64(id))
		h = fnv1a64_u64(h, u64(e.owner))
		v := subset_view(e.set.entity_desc, .Delta)
		if v.struct_bytes > 0 {
			buf := make([]u8, v.struct_bytes, context.temp_allocator)
			subset_capture(v, e.entity, buf)
			h = fnv1a64_bytes(h, buf)
		}
		h = fnv1a64_u64(h, u64(e.blob_ver))
		h = fnv1a64_bytes(h, e.blob)
	}
	return h
}

// ---- coop lag compensation: judge a shot where the SHOOTER saw the target ----
//
// The sim lane rewinds against its tick ledger (ksim.lane_rewound); the coop
// lane has no ticks, so it rewinds against the Stream_Ring history every
// owner-streamed entity already buffers. registry_rewound winds every streamed
// entity EXCEPT the shooter's own back to time `t` (the caller derives it from
// the shooter's latency), runs `query`, and restores the live pose after — the
// exact bytes the shooter's screen was interpolating. Host-owned delta entities
// (owner PLAYER_ID_INVALID) carry no stream history and stay live: this is lag
// comp for the moving targets a coop shooter aims at — other players, streamed
// NPCs — not the static world. `query` may despawn an entity (the restore
// re-resolves the id and skips a gone one), but must not spawn one it expects
// rewound.
Rewound_Query :: proc(user: rawptr)

registry_rewound :: proc(
	reg: ^Registry,
	t: f64,
	shooter: Player_Id,
	user: rawptr,
	query: Rewound_Query,
) {
	Wound :: struct {
		id:   Net_Id,
		view: ^Subset_View,
		live: []u8,
	}
	wounds := make([dynamic]Wound, context.temp_allocator)
	for id, &e in reg.entries {
		// Everything with a stream history but the shooter's own body: other
		// clients' bodies (rings from their inbound streams) AND the authority's
		// own (rings it keeps of what it shipped — registry_write_streams
		// keep_history). No history = never streamed = judged live.
		if e.owner == PLAYER_ID_INVALID || e.owner == shooter || e.stream.count == 0 {
			continue
		}
		v := subset_view(e.set.entity_desc, .Owner)
		if v.struct_bytes == 0 {
			continue
		}
		live := make([]u8, v.struct_bytes, context.temp_allocator)
		subset_capture(v, e.entity, live)
		append(&wounds, Wound{id, v, live})
		stream_ring_sample(&e.stream, t, e.entity, e.set.entity_desc)
	}
	query(user)
	for w in wounds {
		if e, ok := &reg.entries[w.id]; ok {
			subset_restore(w.view, e.entity, w.live)
		}
	}
}
