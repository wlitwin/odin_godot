package wireabi_fixture

// Native executes this exact vector. Every cross-target compile separately
// proves the same struct size, offsets, scalar widths, enum width, and endian
// order, then compiles the same transmute-based byte producer below.
WIRE_FIXTURE_BYTES :: [12]u8 {
	0x44,
	0x33,
	0x22,
	0x11,
	0x66,
	0x55,
	0x02,
	0xa5,
	0xfe,
	0xff,
	0x34,
	0x12,
}

WIRE_FIXTURE_VALUE :: Wire_Payload {
	stamp = 0x11223344,
	inner = {x = 0x5566, mode = .Run, flags = 0xa5},
	samples = {-2, 0x1234},
}

#assert(size_of(Wire_Payload) == len(WIRE_FIXTURE_BYTES))
#assert(NET_ABI_FINGERPRINT == 0x6bf5e741849bef4a)
#assert(NET_FINGERPRINT == 0xfc3f66e9fcd2414b)
#assert(ODIN_ENDIAN == .Little)
#assert(offset_of(Wire_Payload, stamp) == 0)
#assert(offset_of(Wire_Payload, inner) == 4)
#assert(offset_of(Wire_Inner, x) == 0)
#assert(offset_of(Wire_Inner, mode) == 2)
#assert(offset_of(Wire_Inner, flags) == 3)
#assert(offset_of(Wire_Payload, samples) == 8)

// Exercised at runtime by the native fixture; the cross-target checks prove
// the same size, offsets, scalar widths, enum width, and little endian order.
Wire_Fixture_Actual_Bytes :: proc "contextless" () -> [12]u8 {
	return transmute([12]u8)WIRE_FIXTURE_VALUE
}
