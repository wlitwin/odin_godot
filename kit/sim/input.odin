package kit_sim

// input — the inputs-only-up pipeline: client ring, redundant packets, and
// the server's per-player de-jitter buffer.
//
// The trust model of this lane: clients send INPUTS, never state. An input is
// a small fixed-size POD blob (the gd:"input" struct, once scriptgen lands;
// hand-built until then), sampled once per predicted tick.
//
// THE LOSS STORY IS REDUNDANCY, NOT RETRANSMIT. Every packet carries the last
// few unacked inputs (INPUT_REDUNDANCY, default 8), so at a 60 Hz send rate a
// single input survives ~7 consecutive packet losses before it is genuinely
// gone — at which point the server's hold-last policy repeats the previous
// input for the gap tick and FLAGS it, and the client's own prediction for
// that tick reconciles like any other mispredict. No reliable channel, no
// head-of-line blocking, nothing to wait for: the same last-value taste as
// owner streams, applied to intent.
//
// De-jitter is a BUFFER DEPTH, not a delay line: the server consumes exactly
// one input per player per tick (input_buffer_pop). The lead-control loop
// closes over the batch header's input-ack echo — the client measures how
// far its inputs ran ahead of the server's sim and bends its clock
// (lane.odin's ingest + tick.odin's lead_control); nothing extra is shipped.

import "base:intrinsics"
import "core:math"
import knet "godot:kit/net"

// How many trailing inputs ride every packet. 8 at 60 Hz ≈ 133ms of loss
// absorbed per packet — friendslop-grade generous, and still tiny bytes.
INPUT_REDUNDANCY :: 8

// Hard cap a receiver enforces on count/size before touching its buffers —
// remote input is untrusted by default, exactly like kit/net's Reader rules.
MAX_INPUT_REDUNDANCY :: 64
MAX_INPUT_SIZE :: 256

// Aggregate admission limits. Per-window bounds alone still let a seat fan a
// packet out over hundreds of registered classes, or combine several legal
// windows into one oversized message. These caps cover the whole SIM_INPUT
// payload (kind byte included) before the host allocates a per-seat buffer.
MAX_INPUT_CLASSES_PER_SEAT :: 16
MAX_INPUT_PACKET_BYTES :: 32 * 1024

// Frame-safe semantic admission for one typed input blob. scriptgen wraps an
// authored `@(gd_sample="validate")` pair in this raw runtime shape. The proc
// may clamp/normalize through `input` and returns whether the result is legal;
// it must not retain the pointer (packet/sample scratch lifetime only).
Input_Validate_Proc :: proc(user: rawptr, input: rawptr) -> bool

// Small typed building blocks used by scriptgen's @(gd_input) sanitizers. They
// live here so generated game code needs no math/reflection imports of its own.
input_finite_f16 :: proc(x: f16) -> bool {return !math.is_nan(x) && !math.is_inf(x)}
input_finite_f32 :: proc(x: f32) -> bool {return !math.is_nan(x) && !math.is_inf(x)}
input_finite_f64 :: proc(x: f64) -> bool {return !math.is_nan(x) && !math.is_inf(x)}
input_finite :: proc {
	input_finite_f16,
	input_finite_f32,
	input_finite_f64
}

input_unit_f32 :: proc(v: ^[$N]f32) -> bool {
	len2: f32
	for x in v^ {
		if !input_finite(x) {return false}
		len2 += x * x
	}
	if !input_finite(len2) {return false}
	if len2 > 1 {
		scale := 1 / math.sqrt(len2)
		for &x in v^ {x *= scale}
	}
	return true
}

input_unit_f64 :: proc(v: ^[$N]f64) -> bool {
	len2: f64
	for x in v^ {
		if !input_finite(x) {return false}
		len2 += x * x
	}
	if !input_finite(len2) {return false}
	if len2 > 1 {
		scale := 1 / math.sqrt(len2)
		for &x in v^ {x *= scale}
	}
	return true
}

input_unit :: proc {
	input_unit_f32,
	input_unit_f64
}

// Raw packet bytes can contain an enum's underlying integer even when no enum
// member owns that value. Iterating an enum visits its declared values, including
// sparse enums; this does not mistake min..max for membership.
input_enum_valid :: proc(value: $T) -> bool where intrinsics.type_is_enum(T) {
	for valid in T {
		if value == valid {return true}
	}
	return false
}

// Raw fixed-size blob append/view — the packet layout carries the size once
// in its header, so per-input length prefixes would be dead bytes. The view
// read applies the Reader's sticky-error bounds rule by hand, the same move
// registry_apply_streams makes for length-skipped stream payloads.
@(private = "file")
write_blob :: proc(w: ^knet.Writer, blob: []u8) {
	append(&w.buf, ..blob)
}


// ---------------------------------------------------------------------------
// Client side: the ring of inputs already fed to prediction.

Input_Ring :: struct {
	ring: Tick_Ring, // the tick-indexed store (ring.odin)
	head: u64,       // newest tick noted (0 = none yet)
	tail: u64,       // oldest tick still held — the first note anchors it (a
	                 // client joins mid-timeline, so tick 1 usually never existed
	                 // here), lapping advances it
}

// `slots` must cover the resim window (the client's maximum lead) — a replay
// that reaches for a lapped input has already lost the tick it would explain.
input_ring_make :: proc(size: int, slots: int, allocator := context.allocator) -> Input_Ring {
	assert(size > 0 && size <= MAX_INPUT_SIZE)
	return Input_Ring{ring = tick_ring_make(size, slots, allocator)}
}

input_ring_destroy :: proc(r: ^Input_Ring) {
	tick_ring_destroy(&r.ring)
}

// Note the input SAMPLED FOR `tick`, right before predicting that tick — the
// same bytes a reconcile replay will hand back for it. Ticks are noted in
// order (the sim loop owns the counter); noting backwards is a caller bug.
input_note :: proc(r: ^Input_Ring, tick: u64, input: rawptr) {
	assert(tick > r.head, "inputs are noted in tick order")
	tick_ring_note(&r.ring, tick, ([^]u8)(input)[:r.ring.size])
	if r.head == 0 {
		r.tail = tick
	}
	r.head = tick
	if r.head - r.tail >= u64(r.ring.slots) {
		r.tail = r.head - u64(r.ring.slots) + 1
	}
}

// The input noted for `tick` (a view — valid until that slot laps). ok=false
// for never-noted or lapped — THE LEDGER CONTRACT (ring.odin).
input_read :: proc(r: ^Input_Ring, tick: u64) -> (input: []u8, ok: bool) {
	return tick_ring_read(&r.ring, tick)
}

// Append one input packet: the unacked window, newest-tick-inclusive.
//
//   [first_tick u64][count u8][size u16]  count × size raw input bytes
//
// `acked` is the newest tick the server has confirmed receiving (0 = none):
// everything at or before it is dead weight and drops out of the window, so
// a healthy link ships ~1-2 inputs per packet and a lossy one automatically
// widens toward `redundancy`. Returns the input count written. A 0-count
// window STILL writes the header — the sim lane composes this with the snap
// ack in one packet, and a conditionally-absent segment would desync every
// read behind it.
input_write :: proc(w: ^knet.Writer, r: ^Input_Ring, acked: u64, redundancy := INPUT_REDUNDANCY) -> int {
	assert(redundancy >= 0 && redundancy <= MAX_INPUT_REDUNDANCY,
		"input redundancy exceeds the receiver's u8/bounded-work contract")
	// Keep release builds safe too: a bad hand-written caller must never wrap
	// the u8 count or make a receiver do more work than its advertised cap.
	redundancy_limit := clamp(redundancy, 0, MAX_INPUT_REDUNDANCY)
	// The window is the CONTIGUOUS run of noted ticks ending at head, walked
	// downward — never assumed. The ring legitimately has holes: a lead-
	// controller JUMP skips ticks wholesale (they were never simulated), and
	// the wire format can only describe a gapless run.
	first := r.head + 1 // the empty window, self-describing
	count := 0
	if r.head > 0 {
		red := min(redundancy_limit, r.ring.slots)
		for t := r.head; count < red && t > acked; t -= 1 {
			if _, ok := input_read(r, t); !ok {
				break // a hole (jump / lap): the window ends here
			}
			count += 1
			first = t
			if t == 1 {
				break
			}
		}
		if count == 0 {
			first = r.head + 1
		}
	}
	knet.write_u64(w, first)
	knet.write_u8(w, u8(count))
	knet.write_u16(w, u16(r.ring.size))
	for t := first; t < first + u64(count); t += 1 {
		blob, _ := input_read(r, t)
		write_blob(w, blob)
	}
	return count
}

// ---------------------------------------------------------------------------
// Server side: one Input_Buffer per player.

Input_Buffer :: struct {
	ring:        Tick_Ring, // the tick-indexed store (ring.odin)
	tags:        []u64, // per-tick rider, one per ring slot: the value `apply` was given for
	                    // the packet that delivered the tick (the sim lane rides the snap ack
	                    // here — it binds each input to the WORLD VIEW its sender aimed with)
	tag:         u64, // the last popped tick's rider, held-last across gaps like the input
	newest:      u64, // newest tick ever received — the ack the client trims by
	popped:      u64, // last tick consumed (0 = none): older arrivals are stale
	held:        []u8, // the hold-last copy a gap tick repeats (zeroed = neutral input until the first pop)
	fresh_count: u64, // pops that found the exact tick
	held_count:  u64, // pops that fell back to hold-last (the gap stat)
	fresh:       bool, // did the LAST pop find its tick (the driver's freshness bit) —
	                   // per-class now, so it rides the buffer instead of the peer
}

input_buffer_make :: proc(size: int, slots: int, allocator := context.allocator) -> Input_Buffer {
	assert(size > 0 && size <= MAX_INPUT_SIZE)
	return Input_Buffer {
		ring = tick_ring_make(size, slots, allocator),
		tags = make([]u64, slots, allocator),
		held = make([]u8, size, allocator)
	}
}

input_buffer_destroy :: proc(b: ^Input_Buffer) {
	tick_ring_destroy(&b.ring)
	delete(b.tags)
	delete(b.held)
	b.tags = nil
	b.held = nil
}

// Apply one received input packet (the input_write layout). Malformed or
// mis-sized packets set r.err and buffer nothing — remote input is untrusted.
// Duplicates (redundancy re-delivering, out-of-order arrival) and stale ticks
// (≤ popped) are skipped silently; that is the redundancy story working, not
// an error. Returns how many genuinely new inputs were buffered.
@(private)
Input_Window_Header :: struct {
	first: u64,
	count: int,
	size:  int
}

// Read and preflight one window without consuming its blob bytes. lane_handle
// uses this on a copy of the Reader to validate an entire multi-class packet
// before applying any class; input_buffer_apply uses the same gate for direct
// callers and tests.
@(private)
input_window_header :: proc(r: ^knet.Reader, expected_size: int, max_tick: u64) -> Input_Window_Header {
	h := Input_Window_Header{
		first = knet.read_u64(r),
		count = int(knet.read_u8(r)),
		size  = int(knet.read_u16(r))
	}
	if r.err || h.count > MAX_INPUT_REDUNDANCY || h.size != expected_size {
		r.err = true
		return h
	}
	// Validate the WHOLE window before touching the ring. Besides bounding how
	// far an untrusted client may write into the future, this catches u64 tick
	// wrap and truncation transactionally: malformed input buffers nothing,
	// rather than committing the prefix that happened to decode first.
	if h.count > 0 {
		last_delta := u64(h.count - 1)
		if h.first == 0 ||
		   h.first > max(u64) - last_delta ||
		   h.first + last_delta > max_tick ||
		   len(knet.reader_remaining(r)) < h.count * h.size {
			r.err = true
		}
	}
	return h
}

@(private)
input_window_validate :: proc(
	r: ^knet.Reader,
	expected_size: int,
	max_tick := max(u64),
	validate: Input_Validate_Proc = nil,
	user: rawptr = nil
) -> bool {
	h := input_window_header(r, expected_size, max_tick)
	if r.err {
		return false
	}
	for _ in 0 ..< h.count {
		blob := knet.reader_view(r, h.size)
		if r.err || (validate != nil && !validate(user, raw_data(blob))) {
			r.err = true
			return false
		}
	}
	return !r.err
}

input_buffer_apply :: proc(
	b: ^Input_Buffer,
	r: ^knet.Reader,
	tag: u64 = 0,
	max_tick := max(u64),
	validate: Input_Validate_Proc = nil,
	user: rawptr = nil
) -> int {
	// Direct callers get the same all-before-any semantic gate as lane_handle.
	// The probe's blob views alias the packet, so a sanitizer's clamped bytes
	// are exactly the bytes copied into the ring below.
	if validate != nil {
		probe := r^
		if !input_window_validate(&probe, b.ring.size, max_tick, validate, user) {
			r.err = true
			return 0
		}
	}
	h := input_window_header(r, b.ring.size, max_tick)
	if r.err {
		return 0
	}
	fresh := 0
	for k in 0 ..< h.count {
		t := h.first + u64(k)
		blob := knet.reader_view(r, h.size)
		if r.err {
			return fresh
		}
		if t == 0 {
			continue
		}
		if t > b.newest {
			// The ack tracks RECEIPT, stale or not: a client digging out of a
			// lead deficit needs its late inputs acknowledged to MEASURE the
			// hole (the lane's catch-up jump), and acked inputs leave the
			// redundant window either way.
			b.newest = t
		}
		if t <= b.popped {
			continue // stale: its tick already simulated (hold-last covered it)
		}
		// The buffer's own arrival guards read the stored stamp directly, then
		// note over the core (which restamps the same slot); tags rides beside.
		i := tick_ring_slot(&b.ring, t)
		if b.ring.tick[i] == t {
			continue // duplicate re-delivery
		}
		if b.ring.tick[i] > t {
			continue // slot holds a NEWER tick — never lap backwards
		}
		tick_ring_note(&b.ring, t, blob)
		b.tags[i] = tag
		fresh += 1
	}
	return fresh
}

// Consume the input for `tick` — the server calls this exactly once per
// player per simulated tick, monotonically. fresh=false means the tick never
// arrived (yet): the returned input is the hold-last copy (zeroed before the
// first pop — the neutral input) and the tick proc should treat the player as
// coasting; if the real input shows up later it is stale by definition and
// dropped. The returned slice is a view valid until the next pop.
input_buffer_pop :: proc(b: ^Input_Buffer, tick: u64) -> (input: []u8, fresh: bool) {
	assert(tick > b.popped, "pops advance one tick at a time, forward only")
	b.popped = tick
	if blob, ok := tick_ring_read(&b.ring, tick); ok {
		copy(b.held, blob)
		b.tag = b.tags[tick_ring_slot(&b.ring, tick)]
		b.fresh_count += 1
		b.fresh = true
		return b.held, true
	}
	b.held_count += 1 // b.tag holds the last real rider, like the input itself
	b.fresh = false
	return b.held, false
}
