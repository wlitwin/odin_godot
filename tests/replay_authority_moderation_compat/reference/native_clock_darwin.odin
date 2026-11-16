package authority_reference

foreign import libc "system:c"
@(private)
Timebase :: struct {numer, denom: u32}
foreign libc {
	@(private)
	mach_continuous_time :: proc "c" () -> u64 ---
	@(private)
	mach_timebase_info :: proc "c" (info: ^Timebase) -> i32 ---
}

@(private)
native_milliseconds :: proc(user: rawptr) -> (u64, bool) {
	info: Timebase
	if mach_timebase_info(&info) != 0 || info.denom == 0 {return 0, false}
	value := u128(mach_continuous_time()) * u128(info.numer) / u128(info.denom) / 1000000
	return u64(value), value <= u128(max(u64))
}
