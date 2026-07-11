package kit_net

// stream — owner-authoritative field streaming with delayed interpolated sampling.
//
// Fields flagged .Owner_Stream (gd:"replicate,owner") are authoritative on the
// peer that OWNS the entity, not the host. The owner writes them as last-value
// snapshots every net tick on the unreliable-ordered channel: a dropped packet
// is superseded by the next one, so there is no loss story at all. Everyone
// else (host included — it is just another remote peer for these fields) pushes
// arriving snapshots into a per-entity Stream_Ring and SAMPLES the ring at
// (timeline_now - delay), lerping .Interp fields between the bracketing pair
// (Lerp_Kind decides how) and stepping the rest. Clamp semantics match
// interp.odin: never extrapolate — hold.
//
// TIMELINE: ring timestamps are whatever the caller stamps pushes with. Two
// valid models: RECEIVER-ARRIVAL time (simple — sample at local_now - delay;
// jitter becomes small velocity wobble the delay absorbs) or SENDER time (the
// batch carries the owner's clock; map it through a per-peer Clock_Sync for a
// jitter-correct timeline). The wire format carries the sender stamp either way
// so a session can upgrade without a format change.
//
// These fields never appear in authority delta batches (diff_mask skips
// .Owner_Stream), so streams and deltas are disjoint: full snapshots seed the
// initial values, streams own them from then on.

import "core:math"

// Byte size of one stream snapshot in STRUCT layout (just the streamed fields,
// desc order, tightly packed) — the shape ring blobs hold and blending reads.
// 0 = this entity type streams nothing.
stream_data_size :: proc(desc: ^Entity_Desc) -> int {
	n := 0
	for f in desc.fields {
		if .Owner_Stream in f.flags {
			n += f.size
		}
	}
	return n
}

// Byte size of one stream snapshot ON THE WIRE (Wire_Kind encodings applied).
// Packets carry this; the receiver decodes to struct layout at the packet edge
// (stream_decode) so rings, warps, and blending never see wire bytes.
stream_wire_size :: proc(desc: ^Entity_Desc) -> int {
	n := 0
	for f in desc.fields {
		if .Owner_Stream in f.flags {
			n += field_wire_size(f)
		}
	}
	return n
}

// Decode one wire-encoded stream snapshot into a struct-layout blob (the caller
// sizes `dst` with stream_data_size). The packet-edge half of Wire_Kind.
stream_decode :: proc(dst: []u8, wire: []u8, desc: ^Entity_Desc) {
	doff, woff := 0, 0
	for f in desc.fields {
		if .Owner_Stream not_in f.flags {
			continue
		}
		field_decode(&dst[doff], ([^]u8)(&wire[woff]), f)
		doff += f.size
		woff += field_wire_size(f)
	}
}

@(private = "file")
stream_field_ptr :: proc(entity: rawptr, f: Field_Desc) -> [^]u8 {
	return ([^]u8)(rawptr(uintptr(entity) + f.offset))
}

// Owner side: append the streamed fields' current values, wire-encoded.
stream_write :: proc(w: ^Writer, entity: rawptr, desc: ^Entity_Desc) {
	for f in desc.fields {
		if .Owner_Stream not_in f.flags {
			continue
		}
		field_encode(w, stream_field_ptr(entity, f), f)
	}
}

// ---------------------------------------------------------------------------
// Receiver side: a fixed ring of timestamped snapshots per remote-owned entity.

Stream_Ring :: struct {
	times: [INTERP_CAP]f64,
	blobs: [INTERP_CAP][]u8, // each stream_data_size bytes, allocated on first use
	warps: [INTERP_CAP]u8, // the owner's teleport counter at each sample
	head:  int, // oldest sample
	count: int,
}

stream_ring_destroy :: proc(ring: ^Stream_Ring) {
	for b in ring.blobs {
		delete(b)
	}
	ring^ = {}
}

// Forget every buffered sample but keep the allocations. An OWNERSHIP
// TRANSFER calls this: the buffered timeline is the OLD owner's motion, and
// sampling across the handoff would glide the entity from where the old
// owner left it to wherever the new owner stands — a slide nobody performed.
stream_ring_reset :: proc(ring: ^Stream_Ring) {
	ring.head = 0
	ring.count = 0
}

// Write the ring's NEWEST sample straight into the entity — no render delay.
// The ownership-transfer snap: the freshest thing the old owner ever said,
// applied before the ring is reset out from under it.
stream_ring_flush_newest :: proc(ring: ^Stream_Ring, entity: rawptr, desc: ^Entity_Desc) {
	if ring.count == 0 {
		return
	}
	newest := (ring.head + ring.count - 1) % INTERP_CAP
	stream_blend(entity, desc, ring.blobs[newest], ring.blobs[newest], 0)
}

// Push one snapshot (copied). Stale arrivals — at or before the newest sample's
// stamp — are dropped, mirroring interp_push (the unreliable-ORDERED channel
// already discards reordered packets; this is the belt to those suspenders).
//
// A NEWER WARP COUNTER FLUSHES THE RING: a warp is the owner declaring a CUT
// (teleport, respawn, level change), and the buffered pre-warp samples are a
// doomed timeline nobody should watch — without the flush, remote screens
// keep rendering it for a full interp delay while the reliable channel's
// deltas have already moved the world on (a ball lingering in the cup after
// the next hole built itself, in puttputt's case). Flushing renders the cut
// at delta latency; the warp check in stream_ring_sample stays as the belt
// for a mixed-warp ring that can no longer normally occur.
//
// The warp comparison is u8 SERIAL arithmetic, not inequality, and it runs
// BEFORE the stale-stamp guard. Both halves are load-bearing:
//   * An OWNERSHIP TRANSFER bumps the warp and resets rings, but the OLD
//     owner's in-flight packets (pre-bump warp) can land ~an RTT after the
//     new owner's first sample. "Different warp = flush" would let each one
//     wipe the ring and snap every screen BACKWARD, once per stale packet —
//     an older serial must be DROPPED, never re-blended, exactly as the
//     supersede contract in registry.odin promises.
//   * Two packets pumped in one frame carry EQUAL stamps; if the second one
//     carries the warp bump, a stamps-first guard would eat the cut.
stream_ring_push :: proc(ring: ^Stream_Ring, t: f64, data: []u8, warp: u8 = 0, allocator := context.allocator) {
	if ring.count > 0 {
		newest := (ring.head + ring.count - 1) % INTERP_CAP
		nw := ring.warps[newest]
		if warp != nw {
			if (warp - nw) & 0x80 == 0 { // strictly newer serial: the cut wins now
				stream_ring_reset(ring)
			} else { // a doomed timeline's straggler: drop, never re-blend
				return
			}
		} else if t <= ring.times[newest] {
			return // same timeline: the ordered channel's belt against reorders
		}
	}
	slot: int
	if ring.count < INTERP_CAP {
		slot = (ring.head + ring.count) % INTERP_CAP
		ring.count += 1
	} else {
		slot = ring.head
		ring.head = (ring.head + 1) % INTERP_CAP
	}
	if ring.blobs[slot] == nil {
		ring.blobs[slot] = make([]u8, len(data), allocator)
	}
	assert(len(ring.blobs[slot]) == len(data), "stream snapshot size changed mid-session")
	copy(ring.blobs[slot], data)
	ring.times[slot] = t
	ring.warps[slot] = warp
}

// Blend the streamed fields of `lo`/`hi` at `alpha` straight into the entity.
@(private = "file")
stream_blend :: proc(entity: rawptr, desc: ^Entity_Desc, lo, hi: []u8, alpha: f32) {
	off := 0
	for f in desc.fields {
		if .Owner_Stream not_in f.flags {
			continue
		}
		dst := stream_field_ptr(entity, f)
		lerp := f.lerp if .Interp in f.flags else Lerp_Kind.Snap
		switch lerp {
		case .Snap:
			copy(dst[:f.size], lo[off:off + f.size]) // step: hold until the next stamp
		case .F32:
			df := ([^]f32)(dst)
			lf := ([^]f32)(&lo[off])
			hf := ([^]f32)(&hi[off])
			for i in 0 ..< f.size / 4 {
				df[i] = lf[i] + (hf[i] - lf[i]) * alpha
			}
		case .F64:
			df := ([^]f64)(dst)
			lf := ([^]f64)(&lo[off])
			hf := ([^]f64)(&hi[off])
			for i in 0 ..< f.size / 8 {
				df[i] = lf[i] + (hf[i] - lf[i]) * f64(alpha)
			}
		case .Quat:
			assert(f.size == 16, ".Quat blends exactly 4 x f32 (xyzw)")
			quat_nlerp(([^]f32)(dst), ([^]f32)(&lo[off]), ([^]f32)(&hi[off]), alpha)
		case .Custom:
			assert(f.blend != nil, "lerp = .Custom needs Field_Desc.blend")
			f.blend(rawptr(dst), rawptr(&lo[off]), rawptr(&hi[off]), alpha)
		}
		off += f.size
	}
}

// Normalized lerp with hemisphere agreement: q and -q are the same rotation,
// so blend toward whichever sign of `b` is nearer `a` (a raw componentwise lerp
// across hemispheres collapses through zero and garbles the rotation). nlerp
// isn't constant-velocity like slerp, but between stream samples ~50ms apart
// the difference is invisible — and it's branchless-cheap on the render path.
@(private = "file")
quat_nlerp :: proc(dst, a, b: [^]f32, alpha: f32) {
	dot := a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
	sign: f32 = dot < 0 ? -1 : 1
	out: [4]f32
	len2: f32 = 0
	for i in 0 ..< 4 {
		out[i] = a[i] + (b[i] * sign - a[i]) * alpha
		len2 += out[i] * out[i]
	}
	if len2 > 1e-8 {
		inv := 1.0 / math.sqrt(len2)
		for i in 0 ..< 4 {
			out[i] *= inv
		}
	} else {
		out = {a[0], a[1], a[2], a[3]} // exact antipode midpoint: hold the earlier sample
	}
	for i in 0 ..< 4 {
		dst[i] = out[i]
	}
}

// Sample the ring's timeline at `t` and write the result into the entity's
// streamed fields. ok=false only on an empty ring (entity keeps its last/spawn
// values). Same clamp discipline as interp_sample: before the oldest sample →
// oldest; past the newest → newest, held (never extrapolate).
stream_ring_sample :: proc(ring: ^Stream_Ring, t: f64, entity: rawptr, desc: ^Entity_Desc) -> bool {
	if ring.count == 0 {
		return false
	}
	oldest := ring.head
	newest := (ring.head + ring.count - 1) % INTERP_CAP
	if t <= ring.times[oldest] {
		stream_blend(entity, desc, ring.blobs[oldest], ring.blobs[oldest], 0)
		return true
	}
	if t >= ring.times[newest] {
		stream_blend(entity, desc, ring.blobs[newest], ring.blobs[newest], 0)
		return true
	}
	for i in 1 ..< ring.count {
		hi := (ring.head + i) % INTERP_CAP
		if t <= ring.times[hi] {
			lo := (ring.head + i - 1) % INTERP_CAP
			// A TELEPORT boundary (the owner bumped its warp counter —
			// respawn, level change, blink): never interpolate across the
			// jump. Snap to the far side; the slide across the map is
			// exactly the artifact the owner asked to skip.
			if ring.warps[lo] != ring.warps[hi] {
				stream_blend(entity, desc, ring.blobs[hi], ring.blobs[hi], 0)
				return true
			}
			span := ring.times[hi] - ring.times[lo]
			alpha := span > 0 ? f32((t - ring.times[lo]) / span) : 1
			stream_blend(entity, desc, ring.blobs[lo], ring.blobs[hi], alpha)
			return true
		}
	}
	stream_blend(entity, desc, ring.blobs[newest], ring.blobs[newest], 0) // unreachable; safe
	return true
}
