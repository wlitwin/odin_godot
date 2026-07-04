package kit_net

// wire — the byte format. A bounds-checked, little-endian, append-based Writer and
// a cursor Reader. Deliberately boring: fixed-width fields, u16-length strings, no
// varints (the friendslop napkin says bandwidth is not the constraint; simplicity
// and debuggability are). All multi-byte values are little-endian on the wire —
// every supported target (desktop + wasm32) is LE, so encode/decode is a copy.
//
// ERROR MODEL: a Reader that runs past its data sets `err` and returns zero values
// from then on; callers check `r.err` ONCE after a decode block instead of per
// field. A malformed/truncated packet can never read out of bounds or panic —
// remote input is untrusted by default.

import "core:mem"

Writer :: struct {
	buf: [dynamic]u8,
}

writer_make :: proc(cap := 256, allocator := context.allocator) -> Writer {
	return Writer{buf = make([dynamic]u8, 0, cap, allocator)}
}

writer_destroy :: proc(w: ^Writer) {
	delete(w.buf)
	w.buf = nil
}

// Reset for reuse without releasing capacity — the per-tick send path allocates
// nothing in steady state.
writer_reset :: proc(w: ^Writer) {
	clear(&w.buf)
}

writer_bytes :: proc(w: ^Writer) -> []u8 {
	return w.buf[:]
}

@(private = "file")
write_raw :: proc(w: ^Writer, p: rawptr, n: int) {
	old := len(w.buf)
	resize(&w.buf, old + n)
	mem.copy(&w.buf[old], p, n)
}

write_u8 :: proc(w: ^Writer, v: u8) {
	append(&w.buf, v)
}

write_bool :: proc(w: ^Writer, v: bool) {
	append(&w.buf, u8(v ? 1 : 0))
}

write_u16 :: proc(w: ^Writer, v: u16) {
	v := v
	write_raw(w, &v, 2)
}

write_u32 :: proc(w: ^Writer, v: u32) {
	v := v
	write_raw(w, &v, 4)
}

write_u64 :: proc(w: ^Writer, v: u64) {
	v := v
	write_raw(w, &v, 8)
}

write_i8 :: proc(w: ^Writer, v: i8) {write_u8(w, transmute(u8)v)}
write_i16 :: proc(w: ^Writer, v: i16) {write_u16(w, transmute(u16)v)}
write_i32 :: proc(w: ^Writer, v: i32) {write_u32(w, transmute(u32)v)}
write_i64 :: proc(w: ^Writer, v: i64) {write_u64(w, transmute(u64)v)}
write_f32 :: proc(w: ^Writer, v: f32) {write_u32(w, transmute(u32)v)}
write_f64 :: proc(w: ^Writer, v: f64) {write_u64(w, transmute(u64)v)}

write_net_id :: proc(w: ^Writer, v: Net_Id) {write_u32(w, u32(v))}
write_player_id :: proc(w: ^Writer, v: Player_Id) {write_u64(w, u64(v))}

// u16 length prefix: a single wire string is capped at 65535 bytes. Long payloads
// (join snapshots) are chunked ABOVE this layer, not smuggled through strings.
write_string :: proc(w: ^Writer, s: string) {
	n := len(s)
	assert(n <= int(max(u16)), "wire string exceeds u16 length prefix")
	write_u16(w, u16(n))
	if n > 0 {
		write_raw(w, raw_data(s), n)
	}
}

write_bytes :: proc(w: ^Writer, b: []u8) {
	n := len(b)
	assert(n <= int(max(u32)))
	write_u32(w, u32(n))
	if n > 0 {
		write_raw(w, raw_data(b), n)
	}
}

// ---------------------------------------------------------------------------

Reader :: struct {
	data: []u8,
	off:  int,
	err:  bool, // sticky: set on the first out-of-bounds read, checked once by callers
}

reader_make :: proc(data: []u8) -> Reader {
	return Reader{data = data}
}

@(private = "file")
read_raw :: proc(r: ^Reader, out: rawptr, n: int) -> bool {
	if r.err || r.off + n > len(r.data) {
		r.err = true
		return false
	}
	mem.copy(out, &r.data[r.off], n)
	r.off += n
	return true
}

read_u8 :: proc(r: ^Reader) -> (v: u8) {
	_ = read_raw(r, &v, 1)
	return
}

read_bool :: proc(r: ^Reader) -> bool {
	return read_u8(r) != 0
}

read_u16 :: proc(r: ^Reader) -> (v: u16) {
	_ = read_raw(r, &v, 2)
	return
}

read_u32 :: proc(r: ^Reader) -> (v: u32) {
	_ = read_raw(r, &v, 4)
	return
}

read_u64 :: proc(r: ^Reader) -> (v: u64) {
	_ = read_raw(r, &v, 8)
	return
}

read_i8 :: proc(r: ^Reader) -> i8 {return transmute(i8)read_u8(r)}
read_i16 :: proc(r: ^Reader) -> i16 {return transmute(i16)read_u16(r)}
read_i32 :: proc(r: ^Reader) -> i32 {return transmute(i32)read_u32(r)}
read_i64 :: proc(r: ^Reader) -> i64 {return transmute(i64)read_u64(r)}
read_f32 :: proc(r: ^Reader) -> f32 {return transmute(f32)read_u32(r)}
read_f64 :: proc(r: ^Reader) -> f64 {return transmute(f64)read_u64(r)}

read_net_id :: proc(r: ^Reader) -> Net_Id {return Net_Id(read_u32(r))}
read_player_id :: proc(r: ^Reader) -> Player_Id {return Player_Id(read_u64(r))}

// Returns a view INTO the reader's buffer (zero-copy). Callers that keep the
// string beyond the packet's lifetime must clone it.
read_string :: proc(r: ^Reader) -> string {
	n := int(read_u16(r))
	if r.err || r.off + n > len(r.data) {
		r.err = true
		return ""
	}
	s := string(r.data[r.off:r.off + n])
	r.off += n
	return s
}

// Zero-copy view, same lifetime rule as read_string.
read_bytes :: proc(r: ^Reader) -> []u8 {
	n := int(read_u32(r))
	if r.err || r.off + n > len(r.data) {
		r.err = true
		return nil
	}
	b := r.data[r.off:r.off + n]
	r.off += n
	return b
}
