package kit_save

// The PERSISTENT IDENTITY helper. kit/session's identity model (see its
// header) makes a player BE a reconnect token: a random u64 secret the
// client generates once and keeps forever — reconnects, resumed saves,
// reclaimed stats and entities all ride on presenting the same token again.
// This is the "generates once and keeps" half, so no game hand-rolls the
// mint-hash-persist dance (or worse, forgets the persist and strands every
// player's identity at quit).

import gd "godot:godot"
import "core:time"

// Load the 8-byte token from `path`, or mint one and persist it there.
// Keep the file, keep the identity: pass the result to
// session_client_start every run. (Tests and shared machines that need to
// CHOOSE an identity can bypass this with their own token source — see
// cavecrawl's CAVE_TOKEN env override.)
persistent_token :: proc(path: cstring) -> u64 {
	if bytes, ok := read_file(path, context.temp_allocator); ok && len(bytes) == 8 {
		return (cast(^u64)raw_data(bytes))^
	}
	// First run: mint from the ENGINE clock — core:time is stuck inside the
	// wasm module (the same freeze the netgd clock swap exists for), and a
	// frozen mint would hand every fresh web player the SAME token, whose
	// holder's seat the next joiner then legitimately steals. core:time is
	// folded back in for extra native entropy (a harmless constant on web),
	// scrambled (golden-ratio multiply) so near-simultaneous first launches
	// don't collide on the low bits. Cryptographic strength is not the bar —
	// unguessable-by-friends is (this is friendslop; see the voice-of-v1
	// stance).
	usec := u64(gd.time_get_ticks_usec(gd.singleton_time()))
	token := (usec ~ u64(time.tick_now()._nsec)) * 0x9E3779B97F4A7C15
	bits := token
	_ = write_file(path, (cast([^]u8)&bits)[:8])
	return token
}

// The whole identity decision, in one call — every game grew this same
// ladder by hand, and one of them shipped the footgun it names:
//
//   1. `env` set (test harnesses, shared machines choosing who they are):
//      the token is an fnv64a hash of the env value — stable per string.
//   2. Otherwise the persisted file token (`path`) — the durable identity
//      that reconnects, resumed saves, and successions reclaim.
//   3. `per_instance` folds the process id in. THE FOOTGUN IT NAMES:
//      same-machine instances share user://, so two clicks of the same
//      build share a token — and the token IS identity, so the second
//      joiner legitimately STEALS the first's seat via the crashed-socket
//      reconnect path, leaving a ghost who can't chat or act. Turn this on
//      for games with nothing to reclaim across launches (party games,
//      score-only sessions); keep it OFF when saves/succession matter and
//      hand same-machine testers distinct env tokens instead.
Token_Options :: struct {
	env:          cstring, // env var naming an explicit token ("" = skip)
	path:         cstring, // user:// file for the persisted token
	per_instance: bool, // fold the pid in (see above — a deliberate trade)
}

token :: proc(opts: Token_Options, pid := u64(0)) -> u64 {
	if opts.env != "" {
		if v := gd.env_string(opts.env); v != "" {
			return fnv64a(transmute([]u8)v)
		}
	}
	base := persistent_token(opts.path)
	if opts.per_instance {
		p := pid != 0 ? pid : u64(gd.os_get_process_id(gd.singleton_os()))
		both: [16]u8
		(cast(^u64)&both[0])^ = base
		(cast(^u64)&both[8])^ = p
		return fnv64a(both[:])
	}
	return base
}

@(private = "file")
fnv64a :: proc(data: []u8) -> u64 {
	h := u64(1469598103934665603)
	for c in data {
		h = (h ~ u64(c)) * 1099511628211
	}
	return h
}
