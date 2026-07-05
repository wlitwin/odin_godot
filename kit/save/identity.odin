package kit_save

// The PERSISTENT IDENTITY helper. kit/session's identity model (see its
// header) makes a player BE a reconnect token: a random u64 secret the
// client generates once and keeps forever — reconnects, resumed saves,
// reclaimed stats and entities all ride on presenting the same token again.
// This is the "generates once and keeps" half, so no game hand-rolls the
// mint-hash-persist dance (or worse, forgets the persist and strands every
// player's identity at quit).

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
	// First run: mint from the monotonic clock, scrambled (golden-ratio
	// multiply) so near-simultaneous first launches don't collide on the
	// low bits. Cryptographic strength is not the bar — unguessable-by-
	// friends is (this is friendslop; see the voice-of-v1 stance).
	token := u64(time.tick_now()._nsec) * 0x9E3779B97F4A7C15
	bits := token
	_ = write_file(path, (cast([^]u8)&bits)[:8])
	return token
}
