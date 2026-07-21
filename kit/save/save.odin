package kit_save

// kit/save — quit and resume a run (toolkit phase 6). This phase is cheap
// ON PURPOSE: the session snapshot that ships to the backup host every few
// seconds (phase 1) is already a complete re-hostable world, and
// session_host_resume already rebuilds one. Saving is that same contract
// pointed at a file, wrapped in a VERSIONED envelope:
//
//   [magic u32][format u16][game_version u16][saved_by u64][game blob][session snapshot]
//
//   * `format` is the TOOLKIT layout version — a mismatched save refuses to
//     parse instead of reading garbage.
//   * `game_version` is the GAME's own stamp (pass what you like; check what
//     you get) — content changes are the game's problem to detect.
//   * `saved_by` fixes the who-am-I question on restore: the host that SAVED
//     resumes under its own old Player_Id (hosts have no reconnect token —
//     they never JOINed — so the file remembers for them).
//   * The GAME BLOB carries host-side state the session cannot know about —
//     wave directors, AI clocks, quest flags. The session snapshot covers
//     identity/stats/entities; anything else the game owns, the game saves.
//
// Restore-into-lobby: save_restore seats the caller as host of the live
// world with every other player disconnected-but-reclaimable — friends
// rejoin with their persisted tokens and get their ids, stats, and owned
// entities back, exactly like any reconnect.
//
// The envelope is engine-free (bytes in, bytes out — unit-testable without
// Godot); write_file/read_file are thin FileAccess helpers so user:// paths
// work on every platform, web included.

import gd "godot:godot"
import "godot:gdext"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:mem"
import "base:intrinsics"

MAGIC :: u32(0x46534C50) // "FSLP"
// HAND-BUMPED, and the one place in the kit that still should be — see
// save.md's "what crosses time, what crosses the wire". Bytes crossing TIME
// take the generated FNV field hash (gd:"backup" blobs, write_pod); bytes
// crossing THE WIRE take a rev at the join door (ksess.PROTOCOL_REV,
// knet.WIRE_REV, each wire package's own). FORMAT is neither: it versions the
// ENVELOPE — magic, stamps, two length-prefixed ranges — which has no field
// set to hash and must be readable by a reader that has agreed to nothing yet.
// The changelog below IS the contract; bump it with the snapshot layout.
FORMAT :: u16(4) // 2: entity blobs + wire codecs · 3: the door — locked + denied — rides the roster · 4: host id in the snapshot (orphan re-own on takeover)

Header :: struct {
	game_version: u16,
	saved_by:     knet.Player_Id, // the host that wrote it
	game_blob:    []u8, // view into the reader's buffer
}

// Host: write a complete save into `w`.
save_write :: proc(s: ^ksess.Session, w: ^knet.Writer, game_version: u16, game_blob: []u8 = nil) {
	assert(s.is_host, "the authority saves the run")
	knet.write_u32(w, MAGIC)
	knet.write_u16(w, FORMAT)
	knet.write_u16(w, game_version)
	knet.write_u64(w, u64(s.me))
	knet.write_bytes(w, game_blob)
	ksess.session_snapshot(s, w)
}

// Parse and validate the envelope; the reader is left positioned on the
// session snapshot (hand it to save_restore). ok=false on wrong magic or a
// format from a different toolkit — never on a merely different game_version
// (that verdict belongs to the game).
save_read_header :: proc(r: ^knet.Reader) -> (h: Header, ok: bool) {
	if knet.read_u32(r) != MAGIC || knet.read_u16(r) != FORMAT {
		return {}, false
	}
	h.game_version = knet.read_u16(r)
	h.saved_by = knet.read_player_id(r)
	h.game_blob = knet.read_bytes(r)
	return h, !r.err
}

// Become the host of the saved run, under the identity that saved it. Call
// on a FRESH session with the factory installed (entities recreate through
// it); returns false on a corrupt snapshot.
save_restore :: proc(s: ^ksess.Session, name: string, r: ^knet.Reader, h: Header) -> bool {
	return ksess.session_host_resume(s, h.saved_by, name, knet.reader_remaining(r))
}

// Why a resume refused — each case is a different sentence to the player.
Resume_Error :: enum {
	Ok,
	No_File, // nothing saved at `path`
	Bad_Envelope, // wrong magic/format — not one of ours
	Wrong_Version, // a different game (or older content) wrote it
	Corrupt, // the session snapshot didn't parse
}

// The whole "Resume" button in one call: read the file, validate the
// envelope, check the game's version stamp, restore the run (the caller is
// seated as host; friends rejoin with their tokens like any reconnect).
// Returns the GAME BLOB — temp-allocated, parse it immediately — for the
// campaign state the session can't know about.
//
// Needs the factory installed (entities recreate through it). Transport
// order is flexible: nothing sends until the session ticks, so bring the
// wire up before or after — and a resume that succeeds before a transport
// that fails is safe to abandon, the next *_start re-inits.
resume :: proc(s: ^ksess.Session, name: string, path: cstring, game_version: u16) -> (game_blob: []u8, err: Resume_Error) {
	bytes, read_ok := read_file(path, context.temp_allocator)
	if !read_ok {
		return nil, .No_File
	}
	r := knet.reader_make(bytes)
	h, hok := save_read_header(&r)
	if !hok {
		return nil, .Bad_Envelope
	}
	if h.game_version != game_version {
		return nil, .Wrong_Version
	}
	if !save_restore(s, name, &r, h) {
		return nil, .Corrupt
	}
	return h.game_blob, .Ok
}

// ---- file helpers (FileAccess: user:// works everywhere, web included) ---------

write_file :: proc(path: cstring, bytes: []u8) -> bool {
	gpath := gd.new_string_cstring(path) // caller-owned engine String (Ergonomics rule)
	defer gd.free_string(gpath)
	f := gd.file_access_open(gpath, .Write)
	if cast(rawptr)f == nil {
		return false
	}
	pba := gd.new_packed_byte_array()
	defer gd.free_packed_byte_array(pba)
	if len(bytes) > 0 {
		gd.packed_byte_array_resize(&pba, gd.Int(len(bytes)))
		dst := gdext.packed_byte_array_operator_index(cast(gdext.TypePtr)&pba, 0)
		mem.copy(dst, raw_data(bytes), len(bytes))
	}
	gd.file_access_store_buffer(f, pba)
	gd.file_access_close(f)
	return true
}

file_exists :: proc(path: cstring) -> bool {
	gpath := gd.new_string_cstring(path)
	defer gd.free_string(gpath)
	return bool(gd.file_access_file_exists(gpath))
}

// The whole file; the caller owns the slice. ok=false when absent/unreadable.
read_file :: proc(path: cstring, allocator := context.allocator) -> (bytes: []u8, ok: bool) {
	gpath := gd.new_string_cstring(path)
	defer gd.free_string(gpath)
	if !gd.file_access_file_exists(gpath) {
		return nil, false
	}
	f := gd.file_access_open(gpath, .Read)
	if cast(rawptr)f == nil {
		return nil, false
	}
	n := int(gd.file_access_get_length(f))
	pba := gd.file_access_get_buffer(f, gd.Int(n))
	defer gd.free_packed_byte_array(pba) // engine-owned buffer, copied out below
	gd.file_access_close(f)
	view := gd.packed_byte_array_view(&pba)
	bytes = make([]u8, len(view), allocator)
	copy(bytes, view)
	return bytes, true
}

// ---- versioned local POD records -------------------------------------------
//
// A profile, a settings blob, unlocked cosmetics — state that lives on ONE
// machine, not in the session snapshot. Every game hand-rolled the same shape:
// a version u16, then a field-by-field write_u32/read_u8 pair, then a fresh-
// start on a version or length mismatch. record_* is that shape, once — the
// gd:"backup" POD discipline pointed at a file.
//
// The value IS its bytes (POD only — the #assert below refuses a pointer or a
// slice, which a raw copy would serialize as a dangling address). MIGRATION is
// append-only zero-default: add new fields at the END and leave the version
// alone — an older file is SHORTER, and record_decode reads its missing tail as
// zero. Bump the version only when you REORDER, REMOVE, or RETYPE a field, which
// makes an old file a .Skew the game restarts from rather than a silent misread.
// Same-machine bytes: padding and endianness are stable within a version, which
// is exactly the scope ("local record") this serves.
RECORD_MAGIC :: u32(0x5245_4344) // "RECD"

Record_Result :: enum u8 {
	Ok, // decoded into `value`
	Missing, // no file yet — a fresh start, silently
	Skew, // a different version — an incompatible format; start fresh, loudly
	Corrupt, // wrong magic / truncated / garbled; start fresh, loudly
}

// Frame a POD value into bytes: [MAGIC][version u16][size u32][raw bytes]. The
// pure half of record_write, so a game can send the record somewhere other than
// a file (and so it is testable without the engine's FileAccess).
record_encode :: proc(value: $T, version: u16, allocator := context.allocator) -> []u8 {
	#assert(
		intrinsics.type_is_nearly_simple_compare(T) && !intrinsics.type_is_pointer(T) && !intrinsics.type_is_multi_pointer(T),
		"ksave.record: T must be POD (ints/floats/bools/enums/vectors/fixed arrays — no strings, slices, maps, or pointers; a raw copy would serialize a dangling address)",
	)
	v := value
	w := knet.writer_make(allocator = allocator)
	knet.write_u32(&w, RECORD_MAGIC)
	knet.write_u16(&w, version)
	knet.write_u32(&w, u32(size_of(T)))
	append(&w.buf, ..(cast([^]u8)&v)[:size_of(T)])
	return knet.writer_bytes(&w)
}

// Parse bytes framed by record_encode back into a T of THIS build's layout. A
// shorter payload (an older, append-only version) leaves the extra tail zero;
// a longer one is truncated to this build's size. The pure half of record_read.
record_decode :: proc($T: typeid, bytes: []u8, version: u16) -> (value: T, result: Record_Result) {
	#assert(
		intrinsics.type_is_nearly_simple_compare(T) && !intrinsics.type_is_pointer(T) && !intrinsics.type_is_multi_pointer(T),
		"ksave.record: T must be POD (ints/floats/bools/enums/vectors/fixed arrays — no strings, slices, maps, or pointers)",
	)
	r := knet.reader_make(bytes)
	if knet.read_u32(&r) != RECORD_MAGIC {
		return {}, .Corrupt
	}
	if knet.read_u16(&r) != version {
		return {}, .Skew
	}
	size := int(knet.read_u32(&r))
	if r.err || size < 0 {
		return {}, .Corrupt
	}
	n := min(size, size_of(T))
	if r.off + n > len(bytes) {
		return {}, .Corrupt // the payload is shorter than its own length says
	}
	if n > 0 {
		mem.copy(&value, &bytes[r.off], n) // value is zero-init; any tail past n stays zero
	}
	return value, .Ok
}

// Save a POD record to `path` (a user:// file). false = the disk refused.
record_write :: proc(value: $T, path: cstring, version: u16) -> bool {
	bytes := record_encode(value, version, context.temp_allocator)
	return write_file(path, bytes)
}

// Load a POD record from `path`. .Missing = no file yet (a fresh start); .Skew /
// .Corrupt = there was one but this build cannot use it (start fresh, and say so
// — a silently-dropped save is a worse bug than a loud one).
record_read :: proc($T: typeid, path: cstring, version: u16) -> (value: T, result: Record_Result) {
	bytes, ok := read_file(path, context.temp_allocator)
	if !ok {
		return {}, .Missing
	}
	return record_decode(T, bytes, version)
}
