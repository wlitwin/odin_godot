package authority_reference

import win "core:sys/windows"

@(private)
native_milliseconds :: proc(user: rawptr) -> (u64, bool) {
	frequency, counter: win.LARGE_INTEGER
	if !win.QueryPerformanceFrequency(&frequency) || !win.QueryPerformanceCounter(&counter) || frequency <= 0 || counter < 0 {return 0, false}
	value := u128(counter) * 1000 / u128(frequency)
	return u64(value), value <= u128(max(u64))
}
