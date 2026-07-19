package kit_net

// subset — the flag-filtered VIEW of an Entity_Desc, built once, walked by
// everyone. Before this file, the walk it packages — `off := 0; for f in
// desc.fields { if .X not_in f.flags { continue }; …; off += f.size }` — was
// hand-rolled ~20 times across kit/net and kit/sim for four predicates, each
// copy free to drift its offset bookkeeping alone (the quat_nlerp twin class,
// at scale). The view precomputes, per (desc, lane subset): which fields are
// members, their packed STRUCT offsets (capture/restore/diff/blend blobs) and
// their packed WIRE offsets (encode/decode payloads — the two diverge under
// Wire_Kind.F16/.Custom), plus the subset's sizes and delta-mask width.
//
// The lanes partition: .Owner_Stream and .Predicted are mutually exclusive,
// so every field is in exactly one of {Owner, Predicted, Delta}; Full is the
// union. Ops that need per-field metadata (encode/decode/blend kinds) reach
// back through entries[i].field into the view's `fields` slice — the view
// stores the SLICE, never a ^Entity_Desc: hand-built test descs return their
// wrapper by value (a fresh stack copy per call) while the fields backing
// array is @(static), so the slice is the stable identity and the wrapper
// address is a trap. The same fact keys the cache.
//
// CACHE: process-lifetime, mutex-guarded (the kit runtime is single-threaded,
// but `odin test` drives suites in PARALLEL threads — an unguarded global map
// here is the exact "never mutate kit globals in tests" lesson), allocated
// from the heap allocator directly so a per-test tracking allocator doesn't
// bill a deliberate process-lifetime cache as that test's leak. Views are
// heap-boxed so returned pointers survive map growth. The backing arrays of
// every desc — generated ([?] file-static) and hand-built (@(static)) —
// outlive the process; a desc built over a freed heap slice would alias keys,
// and no such desc exists (don't make one).

import "base:runtime"
import "core:mem"
import "core:sync"

// The four subset predicates, first-class. Owner/Predicted/Delta partition
// the fields; Full is their union.
Lane_Subset :: enum u8 {
	Full, // every replicated field
	Owner, // .Owner_Stream — the owner-authoritative stream lane
	Predicted, // .Predicted — kit/sim's server-authority lane
	Delta, // neither — the authority delta lane
}

// The lanes an apply/restore leaves untouched — only .Owner and .Predicted
// are meaningful (the receiver owns the stream, or the sim lane owns the
// prediction, so a lagged host echo must not write those fields back). .Full
// and .Delta in the set are ignored.
Subset_Skips :: bit_set[Lane_Subset]

subset_member :: proc "contextless" (flags: Field_Flags, subset: Lane_Subset) -> bool {
	switch subset {
	case .Full:
		return true
	case .Owner:
		return .Owner_Stream in flags
	case .Predicted:
		return .Predicted in flags
	case .Delta:
		return .Owner_Stream not_in flags && .Predicted not_in flags
	}
	return false
}

// One member field: the desc index (the handle for encode/blend metadata and
// the coop mask bit) plus both packed offsets and both sizes, cached small
// and hot — the size/capture/diff paths never touch the fat Field_Desc.
Subset_Entry :: struct {
	field:      u16, // index into fields
	struct_off: u32, // packed offset in struct-layout blobs
	wire_off:   u32, // packed offset in wire-layout payloads
	size:       u32, // f.size
	wire_size:  u32, // field_wire_size(f)
}

Subset_View :: struct {
	fields:       []Field_Desc, // the desc's fields slice (stable backing; see header)
	entries:      []Subset_Entry, // members only, contiguous, desc order
	struct_bytes: int, // packed blob size — the old per-lane *_size
	wire_bytes:   int, // packed wire size — the old per-lane *_wire_size
	mask_bytes:   int, // ceil(len(entries)/8) — the delta mask width
	has_wire:     bool, // any member re-encodes (wire != .Raw)
}

@(private = "file")
Subset_Key :: struct {
	base:   rawptr, // raw_data(desc.fields) — the stable identity
	n:      int,
	subset: Lane_Subset,
}

@(private = "file")
g_views: map[Subset_Key]^Subset_View

@(private = "file")
g_views_mu: sync.Mutex

// The view for (desc, subset) — built on first use, cached for the process.
// The returned pointer is stable forever (views are heap-boxed).
subset_view :: proc(desc: ^Entity_Desc, subset: Lane_Subset) -> ^Subset_View {
	key := Subset_Key{raw_data(desc.fields), len(desc.fields), subset}
	sync.lock(&g_views_mu)
	defer sync.unlock(&g_views_mu)
	if v, ok := g_views[key]; ok {
		return v
	}
	context.allocator = runtime.heap_allocator()
	n := 0
	for f in desc.fields {
		if subset_member(f.flags, subset) {
			n += 1
		}
	}
	v := new(Subset_View)
	v.fields = desc.fields
	v.entries = make([]Subset_Entry, n)
	i, soff, woff := 0, 0, 0
	for f, fi in desc.fields {
		if !subset_member(f.flags, subset) {
			continue
		}
		ws := field_wire_size(f)
		v.entries[i] = Subset_Entry{u16(fi), u32(soff), u32(woff), u32(f.size), u32(ws)}
		if f.wire != .Raw {
			v.has_wire = true
		}
		soff += f.size
		woff += ws
		i += 1
	}
	v.struct_bytes = soff
	v.wire_bytes = woff
	v.mask_bytes = (n + 7) / 8
	if g_views == nil {
		g_views = make(map[Subset_Key]^Subset_View)
	}
	g_views[key] = v
	return v
}

@(private = "file")
entry_field_ptr :: proc "contextless" (entity: rawptr, f: Field_Desc) -> [^]u8 {
	return ([^]u8)(rawptr(uintptr(entity) + f.offset))
}

// ---- the generic ops --------------------------------------------------------

// Entity → packed blob (the old *_capture per lane). dst must be struct_bytes.
subset_capture :: proc(v: ^Subset_View, entity: rawptr, dst: []u8) {
	for e in v.entries {
		mem.copy(&dst[e.struct_off], entry_field_ptr(entity, v.fields[e.field]), int(e.size))
	}
}

// Packed blob → entity (the old *_restore per lane).
subset_restore :: proc(v: ^Subset_View, entity: rawptr, src: []u8) {
	for e in v.entries {
		mem.copy(entry_field_ptr(entity, v.fields[e.field]), &src[e.struct_off], int(e.size))
	}
}

// Entity == packed blob, byte-exact (the old *_matches).
subset_equal :: proc(v: ^Subset_View, entity: rawptr, blob: []u8) -> bool {
	for e in v.entries {
		if mem.compare(
			   (cast([^]u8)entry_field_ptr(entity, v.fields[e.field]))[:e.size],
			   blob[e.struct_off:e.struct_off + e.size],
		   ) !=
		   0 {
			return false
		}
	}
	return true
}

// Packed blob → wire, every member (full rows, stream snapshots from a ledger).
subset_write_blob :: proc(w: ^Writer, v: ^Subset_View, blob: []u8) {
	for e in v.entries {
		field_encode(w, &blob[e.struct_off], v.fields[e.field])
	}
}

// Entity → wire, every member (owner stream writes).
subset_write_entity :: proc(w: ^Writer, v: ^Subset_View, entity: rawptr) {
	for e in v.entries {
		field_encode(w, entry_field_ptr(entity, v.fields[e.field]), v.fields[e.field])
	}
}

// Wire → packed blob, every member; false = payload isn't exactly one full
// subset (the receiver's length gate, same discipline as the sim's full rows).
subset_decode_full :: proc(v: ^Subset_View, dst: []u8, wire: []u8) -> bool {
	if len(wire) != v.wire_bytes {
		return false
	}
	for e in v.entries {
		field_decode(&dst[e.struct_off], ([^]u8)(&wire[e.wire_off]), v.fields[e.field])
	}
	return true
}

// ---- the masked delta codec -------------------------------------------------
//
// [mask bytes, LE][dirty members wire-encoded, subset order] — mask bit i =
// the i-th MEMBER (subset ordinal), never a full-desc index. One law for
// every masked subset on the wire; the baseline is the CALLER's story (the
// sim lane deltas against an acked ledger tick; the coop lane, when it rides
// this in phase 2, against its shadow — with its commit as a post-step).

// Diff `now` against `base` (both packed blobs), write mask + dirty fields.
// Returns the mask (0 = clean — the caller decides if a clean row still
// ships; the sim batch does, an all-zero mask being its cheap heartbeat).
subset_delta_write :: proc(w: ^Writer, v: ^Subset_View, now: []u8, base: []u8) -> (mask: u64) {
	for e, ord in v.entries {
		if mem.compare(
			   now[e.struct_off:e.struct_off + e.size],
			   base[e.struct_off:e.struct_off + e.size],
		   ) !=
		   0 {
			mask |= 1 << u64(ord)
		}
	}
	for i in 0 ..< v.mask_bytes {
		write_u8(w, u8(mask >> (u64(i) * 8)))
	}
	for e, ord in v.entries {
		if mask & (1 << u64(ord)) != 0 {
			field_encode(w, &now[e.struct_off], v.fields[e.field])
		}
	}
	return mask
}

// Apply one masked payload onto `dst` (a packed blob pre-seeded with the
// baseline). false = malformed: short mask, truncated field, or trailing
// garbage — the whole row is refused, never half-applied past the check.
subset_delta_apply :: proc(v: ^Subset_View, dst: []u8, payload: []u8) -> bool {
	if len(payload) < v.mask_bytes {
		return false
	}
	mask: u64
	for i in 0 ..< v.mask_bytes {
		mask |= u64(payload[i]) << (u64(i) * 8)
	}
	woff := v.mask_bytes
	for e, ord in v.entries {
		if mask & (1 << u64(ord)) == 0 {
			continue
		}
		n := int(e.wire_size)
		if woff + n > len(payload) {
			return false
		}
		field_decode(&dst[e.struct_off], ([^]u8)(&payload[woff]), v.fields[e.field])
		woff += n
	}
	return woff == len(payload) // trailing garbage is malformed, not ignored
}
