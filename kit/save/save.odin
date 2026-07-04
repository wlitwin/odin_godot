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
import netgd "godot:kit/netgd"
import ksess "godot:kit/session"
import "core:mem"

MAGIC :: u32(0x46534C50) // "FSLP"
FORMAT :: u16(1)

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
	return ksess.session_host_resume(s, h.saved_by, name, r.data[r.off:])
}

// ---- file helpers (FileAccess: user:// works everywhere, web included) ---------

write_file :: proc(path: cstring, bytes: []u8) -> bool {
	f := gd.file_access_open(gd.new_string_cstring(path), .Write)
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
	return bool(gd.file_access_file_exists(gd.new_string_cstring(path)))
}

// The whole file; the caller owns the slice. ok=false when absent/unreadable.
read_file :: proc(path: cstring, allocator := context.allocator) -> (bytes: []u8, ok: bool) {
	gpath := gd.new_string_cstring(path)
	if !gd.file_access_file_exists(gpath) {
		return nil, false
	}
	f := gd.file_access_open(gpath, .Read)
	if cast(rawptr)f == nil {
		return nil, false
	}
	n := int(gd.file_access_get_length(f))
	pba := gd.file_access_get_buffer(f, gd.Int(n))
	gd.file_access_close(f)
	view := netgd.pba_view(&pba)
	bytes = make([]u8, len(view), allocator)
	copy(bytes, view)
	return bytes, true
}
