package kit_sim

// ring — the tick-indexed slot ledger three kit/sim structures share.
//
// The law, stated once: a fixed-size blob per tick, laid out slots × size,
// beside a parallel []u64 recording WHICH tick wrote each slot. A tick maps to
// slot tick %% slots, so writing a tick laps whatever sat `slots` ticks ago.
//
// THE LEDGER CONTRACT — ok=false, never a sentinel. Every read validates the
// stamp: the slot must still carry the exact tick asked for. An unwritten slot
// (stamp 0 — tick 0 predates any note) or a lapped slot (stamp is some other
// tick) reads ok=false, so a caller finding no entry decides its fallback BY
// CHOICE, never by mistaking zeroed or stale bytes for real state.
//
// The ring is pure storage: no head/tail, no hold-last, no per-slot rider.
// Those are POLICY and stay in the owners — History, Input_Ring and
// Input_Buffer each embed a Tick_Ring and add exactly their own.

Tick_Ring :: struct {
	size:  int,   // bytes per slot (0 = a stamp-only ledger — a predict-nothing History)
	slots: int,   // ring capacity in ticks
	data:  []u8,  // slots × size
	tick:  []u64, // which tick wrote each slot (0 = never)
}

// size may be 0 (a predict-nothing History keeps the stamp ledger over empty
// slots); owners that require a payload assert their own size bounds first.
tick_ring_make :: proc(size: int, slots: int, allocator := context.allocator) -> Tick_Ring {
	assert(slots > 0)
	return Tick_Ring {
		size  = size,
		slots = slots,
		data  = make([]u8, slots * size, allocator),
		tick  = make([]u64, slots, allocator),
	}
}

tick_ring_destroy :: proc(r: ^Tick_Ring) {
	delete(r.data)
	delete(r.tick)
	r.data = nil
	r.tick = nil
}

// The slot a tick maps to. Owners that carry a parallel per-slot rider
// (Input_Buffer's tags) or a guard that needs the stored stamp index by this.
tick_ring_slot :: proc(r: ^Tick_Ring, tick: u64) -> int {
	return int(tick % u64(r.slots))
}

// Copy `blob` in as the state AT `tick` and stamp the slot. len(blob) == size.
tick_ring_note :: proc(r: ^Tick_Ring, tick: u64, blob: []u8) {
	assert(len(blob) == r.size)
	i := tick_ring_slot(r, tick)
	copy(r.data[i * r.size:(i + 1) * r.size], blob)
	r.tick[i] = tick
}

// Stamp `tick`'s slot and hand back its writable bytes — for an owner that
// produces the payload straight into the ring rather than through a staging
// blob (History captures a live entity's predict set here). Fill it fully.
tick_ring_dst :: proc(r: ^Tick_Ring, tick: u64) -> []u8 {
	i := tick_ring_slot(r, tick)
	r.tick[i] = tick
	return r.data[i * r.size:(i + 1) * r.size]
}

// The bytes noted for `tick`, if the slot still carries it — a view into the
// ring, valid until that slot is re-noted. See THE LEDGER CONTRACT above:
// ok=false for never-written (including tick 0) and lapped.
tick_ring_read :: proc(r: ^Tick_Ring, tick: u64) -> (blob: []u8, ok: bool) {
	if tick == 0 {
		return nil, false
	}
	i := tick_ring_slot(r, tick)
	if r.tick[i] != tick {
		return nil, false
	}
	return r.data[i * r.size:(i + 1) * r.size], true
}
