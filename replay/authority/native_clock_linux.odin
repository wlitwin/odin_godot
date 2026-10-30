package replay_authority

import linux "core:sys/linux"

@(private)
native_milliseconds :: proc(user: rawptr) -> (u64, bool) {
	ts, err := linux.clock_gettime(.BOOTTIME)
	if err != nil {return 0, false}
	value := u128(ts.time_sec) * 1000 + u128(ts.time_nsec) / 1000000
	return u64(value), value <= u128(max(u64))
}
