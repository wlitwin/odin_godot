package godot

// Ergonomic environment-variable readers — hand-written and owned here
// (binding regeneration only rewrites *.gen.odin).
//
// Every multiplayer game grows these for its test harness (ports, names,
// tokens, latency injection), and the hand-rolled version has a trap both
// example games hit: `string_to_utf8_chars` reports the FULL length even
// when it exceeds the buffer, so an unclamped slice on a long value is a
// bounds-check crash. Written once, clamped once, here.

import "godot:gdext"
import "core:strconv"

// The environment variable's value, `fallback` when unset/empty. The result
// is allocated from `allocator` (temp by default — copy it if you keep it).
// Values longer than 255 bytes are truncated.
env_string :: proc(name: cstring, fallback := "", allocator := context.temp_allocator) -> string {
	env := os_get_environment(singleton_os(), new_string_cstring(name))
	buf: [256]u8
	n := gdext.string_to_utf8_chars(cast(gdext.StringPtr)&env, cast(cstring)&buf[0], len(buf) - 1)
	if n <= 0 {
		return fallback
	}
	out := make([]u8, min(int(n), len(buf) - 1), allocator)
	copy(out, buf[:len(out)])
	return string(out)
}

// The environment variable parsed as an int, `fallback` when unset/unparsable.
env_int :: proc(name: cstring, fallback := 0) -> int {
	if v, ok := strconv.parse_int(env_string(name, "")); ok {
		return v
	}
	return fallback
}
