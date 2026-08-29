package kit_net

import "core:math"

// delta — descriptor-driven dirty tracking and delta serialization.
//
// A replicated entity declares its fields (in generated code: the gd:"replicate"
// tags become an Entity_Desc; in tests: built by hand). The core keeps a SHADOW
// copy of just those fields per entity; each net tick it memcmps entity-vs-shadow
// to produce a dirty mask, writes only the dirty fields, and commits the shadow.
// Receivers apply the mask + fields straight into the entity struct.
//
// Generated replicated fields have a recursive canonical raw ABI: fixed-width
// leaves, explicit enum storage, bounded fixed arrays, and no hidden struct
// padding. Raw bytes are compared and copied — nothing here follows pointers.
// Strings and dynamic data are NOT replicable fields; they travel as explicit
// reliable messages (or as an entity blob — see registry_set_blob). This is what
// keeps shadows, reverts, and deltas memcpy-simple and allocation-free. A field
// MAY re-encode its bytes on the wire (Wire_Kind: half floats, custom fixed-size
// codecs), but everything held in memory stays struct-layout.
//
// The same field layout serves three masters (one serialization, three uses):
//   * per-tick deltas          (write_delta / apply_delta)
//   * full snapshots           (write_full / apply_full — drop-in join, backup host)
//   * prediction reverts       (fields_capture / fields_restore — the automatic
//                               undo behind optimistic commands)

import "core:mem"

// Per-field metadata. `offset` is into the ENTITY struct (offset_of); fields are
// laid out in the shadow in desc order, tightly packed. On the WIRE each field
// occupies field_wire_size bytes (== size unless a Wire_Kind re-encodes it).
Field_Desc :: struct {
	offset: uintptr,
	size:   int,
	name:   string, // diagnostics only ("score.l") — generated descs fill it so
	// guard violations can name the field; hand-built descs may
	// leave it "" (reports fall back to the field ordinal)
	flags:  Field_Flags,
	lerp:   Lerp_Kind, // how stream sampling blends this field (meaningful with .Interp)
	blend:  Blend_Proc, // required iff lerp == .Custom
	wire:   Wire_Kind, // how the field's bytes are ENCODED in packets (default: raw)
	codec:  Wire_Codec, // required iff wire == .Custom
	slack:  f32, // kit/sim reconcile tolerance for THIS predicted float field, world
	// units (0 = inherit the lane default, Lane_Config.tolerance). Lets a
	// fast contested object ride loose drift while precise fields in the
	// same lane stay tight — a differing float within slack doesn't resim.
	// Only the predict reconcile reads it; coop-lane fields ignore it.
	glide:  f32, // kit/sim render-error smoothing half-life for THIS predicted interp
	// float field, seconds (0 = inherit Lane_Config.smooth_halflife). A
	// slower glide reads smoother; a faster one snaps back sooner.
	cut:    f32, // kit/sim snap threshold for THIS field, world units (0 = inherit
	// Lane_Config.smooth_cut). A reconcile error past it is a teleport —
	// the whole entity SNAPS (smoothing a cut looks worse than the cut).
}

Field_Flag :: enum u8 {
	Interp, // remote peers interpolate this field (stream sampling lerps it)
	Owner_Stream, // owner-authoritative: travels ONLY via streams + full snapshots,
	// NEVER in authority delta batches (diff_mask skips it)
	Predicted, // server-sim-authoritative (kit/sim): travels ONLY via tick-stamped
	// snapshots + full snapshots, NEVER in delta batches — the third
	// lane, disjoint from the other two the same way at the mask level.
	// Mutually exclusive with .Owner_Stream: a field is predicted-and-
	// reconciled or owner-streamed, never both.
}

Field_Flags :: bit_set[Field_Flag;u8]

// How interpolation blends a field's bytes between two stream samples. scriptgen
// classifies from the declared type; hand-built descriptors set it directly.
Lerp_Kind :: enum u8 {
	Snap, // step to the sample at-or-before the render time (any POD; the default)
	F32, // treat the field as [size/4]f32 and lerp componentwise (f32, vectors, colors)
	F64, // as F32 but f64 elements
	Quat, // 4 x f32 quaternion: nlerp with hemisphere flip + renormalize (a raw
	// componentwise lerp collapses through zero when q and -q meet)
	Angle, // f32 RADIANS (componentwise like F32): shortest-arc lerp — a raw
	// lerp from +3.1 to -3.1 sweeps the long way around the circle.
	// Declared `gd:"replicate,interp=angle"`; wrapped into (-π, π].
	Custom, // author-supplied Blend_Proc (special math: color spaces, splines, …)
}

// The shortest signed step from `a` to `b` around the circle, in (-π, π] —
// the .Angle blend's core, public because glide/error math needs the same
// wrap anywhere an angle difference is taken.
angle_arc :: proc "contextless" (a, b: f32) -> f32 {
	d := math.mod(b - a, math.TAU)
	switch {
	case d > math.PI:
		d -= math.TAU
	case d <= -math.PI:
		d += math.TAU
	}
	return d
}

angle_lerp :: proc "contextless" (a, b, alpha: f32) -> f32 {
	return a + angle_arc(a, b) * alpha
}

// How a field's bytes are ENCODED inside packets. The struct-side representation
// never changes: shadows, dirty diffing, prediction capture/restore, and stream
// rings all hold struct-layout bytes — wire bytes exist only between writer and
// reader, encoded at write time and decoded at the packet edge. That containment
// is what keeps custom encodings cheap: none of the comparison/revert machinery
// ever sees them. The wire size must be FIXED per field (that fixed-size contract
// is what lets a codec change the representation freely — quantize, pack, or ship
// an index into a structure both sides grow deterministically). Variable-length
// state doesn't belong in fields at all: use an entity blob or an app message.
Wire_Kind :: enum u8 {
	Raw, // ship the struct bytes verbatim (the default)
	F16, // f32 elements ship as half floats — half the bytes, ~3 significant digits
	// (integers exact to 2048; a fit for friendslop-scale positions/velocities)
	Custom, // author-supplied fixed-size codec (Wire_Codec)
}

// A fixed-size custom field encoding. `encode` writes exactly `size` wire bytes
// from the struct field; `decode` is its inverse. Authors declare one via the tag:
//
//     heading: f32 `gd:"replicate,wire=heading_codec"`
//
//     heading_codec :: knet.Wire_Codec {
//         size   = 1,
//         encode = proc(wire, field: rawptr) {(^u8)(wire)^ = u8((^f32)(field)^ * 256.0 / 360.0)},
//         decode = proc(field, wire: rawptr) {(^f32)(field)^ = f32((^u8)(wire)^) * 360.0 / 256.0},
//     }
//
// decode(encode(x)) should be STABLE (a second round trip changes nothing):
// receivers hold decoded values, and an unstable round trip makes confirmed
// predictions micro-snap. Note dirtiness is still diffed on STRUCT bytes — a
// change smaller than the wire precision still sends (and decodes to the same
// value); harmless, but pick a precision at least as fine as gameplay cares about.
Wire_Codec :: struct {
	size:   int,
	encode: proc(wire, field: rawptr), // struct field -> `size` wire bytes
	decode: proc(field, wire: rawptr), // `size` wire bytes -> struct field
}

// Custom field blend: write the interpolation of the field bytes at `a` (earlier
// sample) and `b` (later sample) into the ENTITY field at `dst`. All three point
// at exactly Field_Desc.size bytes. Authors declare one via the tag:
//
//     tint: [3]f32 `gd:"owner,interp=blend_oklab"`
//
//     blend_oklab :: proc(dst, a, b: rawptr, alpha: f32) { ... }
//
// (Wrapped HEADINGS are built in — `interp=angle` — don't hand-write those.)
// scriptgen splices the proc name into the generated descriptor, so a missing
// or wrongly-typed blend proc fails the consumer compile with the field's line.
Blend_Proc :: proc(dst, a, b: rawptr, alpha: f32)

// A replicated entity type. At most 64 fields so the dirty mask is one u64 —
// a struct wanting more should group them into sub-structs (fixed arrays are one
// field). Generated code produces one of these per class; tests build them by hand.
Entity_Desc :: struct {
	fields: []Field_Desc,
	name:   string, // diagnostics only ("Ball") — same contract as Field_Desc.name
}

MAX_REPLICATED_FIELDS :: 64
MAX_REPLICATED_FIELD_BYTES :: MAX_FIELD_BYTES
MAX_REPLICATED_ENTITY_BYTES :: MAX_FIELD_BYTES

// Total shadow byte size for a descriptor (struct-layout — capture/restore/diff).
desc_data_size :: proc(desc: ^Entity_Desc) -> int {
	return subset_view(desc, .Full).struct_bytes
}

// One field's size ON THE WIRE (== .size unless a Wire_Kind re-encodes it).
field_wire_size :: proc(f: Field_Desc) -> int {
	switch f.wire {
	case .Raw:
		return f.size
	case .F16:
		return f.size / 2
	case .Custom:
		return f.codec.size
	}
	return f.size
}

// Total full-snapshot byte size on the wire (spawn tuples, joins, backups).
desc_wire_size :: proc(desc: ^Entity_Desc) -> int {
	return subset_view(desc, .Full).wire_bytes
}

// Whether any field re-encodes on the wire (lets hot paths skip decode shims).
desc_has_wire :: proc(desc: ^Entity_Desc) -> bool {
	for f in desc.fields {
		if f.wire != .Raw {
			return true
		}
	}
	return false
}

// Append the field's wire encoding of the struct bytes at `src`. Byte order is
// native, like every raw field byte this package ships.
field_encode :: proc(w: ^Writer, src: rawptr, f: Field_Desc) {
	switch f.wire {
	case .Raw:
		sp := ([^]u8)(src)
		append(&w.buf, ..sp[:f.size])
	case .F16:
		sf := ([^]f32)(src)
		for i in 0 ..< f.size / 4 {
			h := f16(sf[i])
			hp := ([^]u8)(&h)
			append(&w.buf, ..hp[:2])
		}
	case .Custom:
		old := len(w.buf)
		resize(&w.buf, old + f.codec.size)
		f.codec.encode(&w.buf[old], src)
	}
}

// Decode field_wire_size(f) wire bytes at `wire` into the struct bytes at `dst`.
field_decode :: proc(dst: rawptr, wire: [^]u8, f: Field_Desc) {
	switch f.wire {
	case .Raw:
		mem.copy(dst, wire, f.size)
	case .F16:
		df := ([^]f32)(dst)
		for i in 0 ..< f.size / 4 {
			h: f16
			mem.copy(&h, wire[i * 2:], 2)
			df[i] = f32(h)
		}
	case .Custom:
		f.codec.decode(dst, wire)
	}
}

@(private = "file")
field_ptr :: proc(entity: rawptr, f: Field_Desc) -> rawptr {
	return rawptr(uintptr(entity) + f.offset)
}

// Allocate a zeroed shadow. Zero ≠ the entity's initial values, so the FIRST diff
// after spawn marks every non-zero field dirty — which is exactly the initial
// full send a fresh entity needs. Doubles as the descriptor's validation point
// (every registered entity passes through here): a malformed Wire_Kind fails
// loudly at registration instead of corrupting packets later.
shadow_make :: proc(desc: ^Entity_Desc, allocator := context.allocator) -> []u8 {
	assert(
		len(desc.fields) <= MAX_REPLICATED_FIELDS,
		"entity exceeds 64 replicated fields — the dirty mask (and the sim predict mask) is one u64; group fields into a sub-struct (scriptgen catches this at build time)",
	)
	struct_bytes, wire_bytes := 0, 0
	for f in desc.fields {
		assert(
			f.size > 0 && f.size <= MAX_REPLICATED_FIELD_BYTES,
			"replicated field exceeds MAX_REPLICATED_FIELD_BYTES",
		)
		switch f.wire {
		case .Raw:
		case .F16:
			// Size is all a descriptor can check: a hand-built desc tagging
			// non-f32 4-byte elements ships mangled bits — scriptgen rejects
			// that at the tag level; hand-authors are on their honor here.
			assert(f.size % 4 == 0, "wire = .F16 needs f32 elements (size divisible by 4)")
		case .Custom:
			assert(
				f.codec.size > 0 && f.codec.encode != nil && f.codec.decode != nil,
				"wire = .Custom needs a complete Field_Desc.codec (size, encode, decode)",
			)
		}
		wire_size := field_wire_size(f)
		assert(
			wire_size > 0 && wire_size <= MAX_REPLICATED_FIELD_BYTES,
			"replicated field wire encoding exceeds MAX_REPLICATED_FIELD_BYTES",
		)
		struct_bytes += f.size
		wire_bytes += wire_size
	}
	assert(
		struct_bytes <= MAX_REPLICATED_ENTITY_BYTES,
		"replicated entity struct payload exceeds MAX_REPLICATED_ENTITY_BYTES",
	)
	assert(
		wire_bytes <= MAX_REPLICATED_ENTITY_BYTES,
		"replicated entity wire payload exceeds MAX_REPLICATED_ENTITY_BYTES",
	)
	// Delta-packed: the shadow is the DELTA LANE's baseline and nothing
	// else's — owner-streamed and predicted fields carry their own baselines
	// (the stream ring, the predict ledger) and never had a row here.
	return make([]u8, subset_view(desc, .Delta).struct_bytes, allocator)
}

// Compare entity vs shadow, bit i set = field i differs. Does NOT modify the shadow.
//
// OWNER-STREAMED FIELDS ARE NEVER DIRTY HERE: they are authoritative on their
// owner and travel via the unreliable stream (+ full snapshots for joins) — an
// authority delta re-broadcasting them would fight the owner's stream on every
// peer (the host SAMPLES those fields locally, which would re-dirty them each
// tick). Excluding them at the mask level makes deltas and streams disjoint by
// construction.
//
// PREDICTED FIELDS ARE EXCLUDED THE SAME WAY: they travel via kit/sim's
// tick-stamped snapshot lane and are reconciled by rollback+resim on clients —
// a reliable delta landing on one would stomp a client's prediction outside
// the reconcile (no tick stamp, no history note, no replay). Same rule, third
// lane: the tag decides the wire, and the wires can never fight over a field.
// Mask bit i = the i-th DELTA-LANE member (subset ordinal — the same
// convention the sim lane's snap codec has always used; one mask law for
// every masked subset on the wire since knet.WIRE_REV 2). The shadow is
// delta-packed: it exists ONLY as this lane's baseline.
diff_mask :: proc(entity: rawptr, shadow: []u8, desc: ^Entity_Desc) -> (mask: u64) {
	v := subset_view(desc, .Delta)
	for e, ord in v.entries {
		ep := ([^]u8)(field_ptr(entity, v.fields[e.field]))
		if mem.compare(ep[:e.size], shadow[e.struct_off:e.struct_off + e.size]) != 0 {
			mask |= 1 << u64(ord)
		}
	}
	return
}

// Copy the entity's DELTA-LANE fields into the shadow (the "committed as
// sent" state). Owner-streamed and predicted fields never had a shadow row:
// their lanes carry their own baselines (the ring, the ledger).
shadow_capture :: proc(entity: rawptr, shadow: []u8, desc: ^Entity_Desc) {
	subset_capture(subset_view(desc, .Delta), entity, shadow)
}

@(private = "file")
write_mask :: proc(w: ^Writer, mask: u64, nbytes: int) {
	for i in 0 ..< nbytes {
		write_u8(w, u8(mask >> (u64(i) * 8)))
	}
}

@(private = "file")
read_mask :: proc(r: ^Reader, nbytes: int) -> (mask: u64) {
	for i in 0 ..< nbytes {
		mask |= u64(read_u8(r)) << (u64(i) * 8)
	}
	return
}

// Diff, serialize dirty fields, and commit the shadow. Returns the mask (0 = wrote
// nothing — the caller skips this entity entirely, so idle entities cost one memcmp
// pass and zero bytes). Entity-direct and zero-alloc on purpose: the per-tick
// send path stages nothing (the sim lane's blob-ledgered sibling is
// subset_delta_write — same view, same mask law, different baseline story).
write_delta :: proc(w: ^Writer, entity: rawptr, shadow: []u8, desc: ^Entity_Desc) -> u64 {
	mask := diff_mask(entity, shadow, desc)
	if mask == 0 {
		return 0
	}
	v := subset_view(desc, .Delta)
	write_mask(w, mask, v.mask_bytes)
	for e, ord in v.entries {
		if mask & (1 << u64(ord)) != 0 {
			ep := field_ptr(entity, v.fields[e.field])
			field_encode(w, ep, v.fields[e.field])
			mem.copy(&shadow[e.struct_off], ep, int(e.size)) // commit shadow: STRUCT bytes, never wire bytes
		}
	}
	return mask
}

// Apply a delta produced by write_delta. Returns the mask so higher layers can
// fire per-field change notifications (transition observers). This low-level
// decoder writes fields as it reads them; a direct caller that needs atomic
// mutation must stage or restore around it. registry_apply_deltas does exactly
// that for every live entity, so a malformed session packet commits nothing
// and never advances the entity's shadow baseline.
apply_delta :: proc(r: ^Reader, entity: rawptr, desc: ^Entity_Desc) -> u64 {
	v := subset_view(desc, .Delta)
	mask := read_mask(r, v.mask_bytes)
	for e, ord in v.entries {
		if mask & (1 << u64(ord)) != 0 {
			n := int(e.wire_size)
			wire := reader_view(r, n)
			if r.err {
				return mask
			}
			field_decode(
				field_ptr(entity, v.fields[e.field]),
				([^]u8)(raw_data(wire)),
				v.fields[e.field],
			)
		}
	}
	return mask
}

// Full-state write/apply: every field, no mask — join snapshots, backup-host
// shipping, save/load all reuse this exact layout.
write_full :: proc(w: ^Writer, entity: rawptr, desc: ^Entity_Desc) {
	subset_write_entity(w, subset_view(desc, .Full), entity)
}

@(private = "file")
subset_skipped :: proc "contextless" (flags: Field_Flags, skip: Subset_Skips) -> bool {
	return(
		(.Owner in skip && .Owner_Stream in flags) ||
		(.Predicted in skip && .Predicted in flags) \
	)
}

// `skip` names lanes to leave untouched (only .Owner and .Predicted are
// meaningful). .Owner is set when the RECEIVING peer owns this entity: for
// .Owner_Stream fields the owner IS the authority, so a host "truth" snapshot
// of them is only a lagged echo — writing it back teleports the owner
// (visibly, on every rejected cast while moving). .Predicted is the same
// argument for the THIRD lane: on a client, .Predicted fields are the sim
// lane's property (kit/sim reconciles them against tick-stamped truth) — a
// command reject-truth stomping them would fight the resim with an unstamped,
// un-ledgered write. Join/backup seeding passes an empty skip. The bytes are
// still consumed; the fields are left alone.
apply_full :: proc(r: ^Reader, entity: rawptr, desc: ^Entity_Desc, skip: Subset_Skips = {}) {
	v := subset_view(desc, .Full)
	for e in v.entries {
		f := v.fields[e.field]
		n := int(e.wire_size)
		wire := reader_view(r, n)
		if r.err {
			return
		}
		if !subset_skipped(f.flags, skip) {
			field_decode(field_ptr(entity, f), ([^]u8)(raw_data(wire)), f)
		}
	}
}

// Capture/restore the replicated fields to/from a flat buffer (shadow layout).
// This pair IS the automatic revert behind predicted commands: capture before the
// optimistic run, restore on rejection/timeout, discard on confirmation.
fields_capture :: proc(
	entity: rawptr,
	desc: ^Entity_Desc,
	allocator := context.allocator,
) -> []u8 {
	v := subset_view(desc, .Full)
	buf := make([]u8, v.struct_bytes, allocator)
	subset_capture(v, entity, buf)
	return buf
}

// `skip` mirrors apply_full: .Owner means an OWNER restoring a prediction
// revert must not restore its own streamed fields — the capture is a stale
// copy of state it kept writing while the command was in flight. .Predicted
// likewise: on a client the sim lane kept simulating those fields while the
// command flew, and a revert would rewind them outside the reconcile.
fields_restore :: proc(
	entity: rawptr,
	desc: ^Entity_Desc,
	snapshot: []u8,
	skip: Subset_Skips = {},
) {
	v := subset_view(desc, .Full)
	assert(len(snapshot) == v.struct_bytes)
	for e in v.entries {
		f := v.fields[e.field]
		if !subset_skipped(f.flags, skip) {
			mem.copy(field_ptr(entity, f), &snapshot[e.struct_off], f.size)
		}
	}
}
