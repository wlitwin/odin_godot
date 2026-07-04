package kit_net

// delta — descriptor-driven dirty tracking and delta serialization.
//
// A replicated entity declares its fields (in generated code: the gd:"replicate"
// tags become an Entity_Desc; in tests: built by hand). The core keeps a SHADOW
// copy of just those fields per entity; each net tick it memcmps entity-vs-shadow
// to produce a dirty mask, writes only the dirty fields, and commits the shadow.
// Receivers apply the mask + fields straight into the entity struct.
//
// Replicated fields are POD ONLY (ints/floats/bools/enums/fixed arrays of these):
// raw bytes are compared and copied — nothing here follows pointers. Strings and
// dynamic data are NOT replicable fields; they travel as explicit reliable
// messages. This single restriction is what makes shadows, reverts, and deltas
// memcpy-simple and allocation-free on the hot path.
//
// The same field layout serves three masters (one serialization, three uses):
//   * per-tick deltas          (write_delta / apply_delta)
//   * full snapshots           (write_full / apply_full — drop-in join, backup host)
//   * prediction reverts       (fields_capture / fields_restore — the automatic
//                               undo behind optimistic commands)

import "core:mem"

// Per-field metadata. `offset` is into the ENTITY struct (offset_of); fields are
// laid out in the shadow/wire in desc order, tightly packed.
Field_Desc :: struct {
	offset: uintptr,
	size:   int,
	flags:  Field_Flags,
	lerp:   Lerp_Kind, // how stream sampling blends this field (meaningful with .Interp)
}

Field_Flag :: enum u8 {
	Interp,       // remote peers interpolate this field (stream sampling lerps it)
	Owner_Stream, // owner-authoritative: travels ONLY via streams + full snapshots,
	              // NEVER in authority delta batches (diff_mask skips it)
}

Field_Flags :: bit_set[Field_Flag; u8]

// How interpolation blends a field's bytes between two stream samples. scriptgen
// classifies from the declared type; hand-built descriptors set it directly.
Lerp_Kind :: enum u8 {
	Snap, // step to the sample at-or-before the render time (any POD; the default)
	F32,  // treat the field as [size/4]f32 and lerp componentwise (f32, vectors, colors)
	F64,  // as F32 but f64 elements
}

// A replicated entity type. At most 64 fields so the dirty mask is one u64 —
// a struct wanting more should group them into sub-structs (fixed arrays are one
// field). Generated code produces one of these per class; tests build them by hand.
Entity_Desc :: struct {
	fields: []Field_Desc,
}

MAX_REPLICATED_FIELDS :: 64

// Total shadow/full-snapshot byte size for a descriptor.
desc_data_size :: proc(desc: ^Entity_Desc) -> int {
	n := 0
	for f in desc.fields {
		n += f.size
	}
	return n
}

// Width of the wire dirty mask: only as many bytes as the field count needs.
@(private = "file")
mask_bytes :: proc(desc: ^Entity_Desc) -> int {
	return (len(desc.fields) + 7) / 8
}

@(private = "file")
field_ptr :: proc(entity: rawptr, f: Field_Desc) -> rawptr {
	return rawptr(uintptr(entity) + f.offset)
}

// Allocate a zeroed shadow. Zero ≠ the entity's initial values, so the FIRST diff
// after spawn marks every non-zero field dirty — which is exactly the initial
// full send a fresh entity needs.
shadow_make :: proc(desc: ^Entity_Desc, allocator := context.allocator) -> []u8 {
	assert(len(desc.fields) <= MAX_REPLICATED_FIELDS)
	return make([]u8, desc_data_size(desc), allocator)
}

// Compare entity vs shadow, bit i set = field i differs. Does NOT modify the shadow.
//
// OWNER-STREAMED FIELDS ARE NEVER DIRTY HERE: they are authoritative on their
// owner and travel via the unreliable stream (+ full snapshots for joins) — an
// authority delta re-broadcasting them would fight the owner's stream on every
// peer (the host SAMPLES those fields locally, which would re-dirty them each
// tick). Excluding them at the mask level makes deltas and streams disjoint by
// construction.
diff_mask :: proc(entity: rawptr, shadow: []u8, desc: ^Entity_Desc) -> (mask: u64) {
	off := 0
	for f, i in desc.fields {
		if .Owner_Stream not_in f.flags {
			ep := ([^]u8)(field_ptr(entity, f))
			if mem.compare(ep[:f.size], shadow[off:off + f.size]) != 0 {
				mask |= 1 << u64(i)
			}
		}
		off += f.size
	}
	return
}

// Copy the entity's replicated fields into the shadow (the "committed as sent" state).
shadow_capture :: proc(entity: rawptr, shadow: []u8, desc: ^Entity_Desc) {
	off := 0
	for f in desc.fields {
		mem.copy(&shadow[off], field_ptr(entity, f), f.size)
		off += f.size
	}
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
// pass and zero bytes).
write_delta :: proc(w: ^Writer, entity: rawptr, shadow: []u8, desc: ^Entity_Desc) -> u64 {
	mask := diff_mask(entity, shadow, desc)
	if mask == 0 {
		return 0
	}
	write_mask(w, mask, mask_bytes(desc))
	off := 0
	for f, i in desc.fields {
		if mask & (1 << u64(i)) != 0 {
			ep := ([^]u8)(field_ptr(entity, f))
			old := len(w.buf)
			resize(&w.buf, old + f.size)
			mem.copy(&w.buf[old], ep, f.size)
			mem.copy(&shadow[off], ep, f.size) // commit shadow only for sent fields
		}
		off += f.size
	}
	return mask
}

// Apply a delta produced by write_delta. Returns the mask so higher layers can
// fire per-field change notifications (transition observers). On a truncated
// packet the reader's sticky error is set and the entity is left partially
// updated — the caller must check r.err and discard the whole packet's effects
// (packets are applied into a staging copy at the session layer when that matters).
apply_delta :: proc(r: ^Reader, entity: rawptr, desc: ^Entity_Desc) -> u64 {
	mask := read_mask(r, mask_bytes(desc))
	for f, i in desc.fields {
		if mask & (1 << u64(i)) != 0 {
			buf := field_ptr(entity, f)
			if r.err || r.off + f.size > len(r.data) {
				r.err = true
				return mask
			}
			mem.copy(buf, &r.data[r.off], f.size)
			r.off += f.size
		}
	}
	return mask
}

// Full-state write/apply: every field, no mask — join snapshots, backup-host
// shipping, save/load all reuse this exact layout.
write_full :: proc(w: ^Writer, entity: rawptr, desc: ^Entity_Desc) {
	for f in desc.fields {
		old := len(w.buf)
		resize(&w.buf, old + f.size)
		mem.copy(&w.buf[old], field_ptr(entity, f), f.size)
	}
}

apply_full :: proc(r: ^Reader, entity: rawptr, desc: ^Entity_Desc) {
	for f in desc.fields {
		if r.err || r.off + f.size > len(r.data) {
			r.err = true
			return
		}
		mem.copy(field_ptr(entity, f), &r.data[r.off], f.size)
		r.off += f.size
	}
}

// Capture/restore the replicated fields to/from a flat buffer (shadow layout).
// This pair IS the automatic revert behind predicted commands: capture before the
// optimistic run, restore on rejection/timeout, discard on confirmation.
fields_capture :: proc(entity: rawptr, desc: ^Entity_Desc, allocator := context.allocator) -> []u8 {
	buf := make([]u8, desc_data_size(desc), allocator)
	shadow_capture(entity, buf, desc)
	return buf
}

fields_restore :: proc(entity: rawptr, desc: ^Entity_Desc, snapshot: []u8) {
	assert(len(snapshot) == desc_data_size(desc))
	off := 0
	for f in desc.fields {
		mem.copy(field_ptr(entity, f), &snapshot[off], f.size)
		off += f.size
	}
}
