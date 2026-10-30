package replay_deterministic

// Q24.8 coordinates. Operations use fixed-width integer intermediates and
// explicit range failure. Multiplication/division truncate toward zero.
Fixed :: distinct i32
SCALE :: i64(256)
Vec2 :: [2]Fixed
Aabb2 :: struct {min, max: Vec2}

from_int :: proc(value: i32) -> (Fixed, bool) {return narrow(i64(value) * SCALE)}
to_int :: proc(value: Fixed) -> i32 {return i32(i64(value) / SCALE)}
add :: proc(a, b: Fixed) -> (Fixed, bool) {return narrow(i64(a) + i64(b))}
sub :: proc(a, b: Fixed) -> (Fixed, bool) {return narrow(i64(a) - i64(b))}
mul :: proc(a, b: Fixed) -> (Fixed, bool) {return narrow(i64(a) * i64(b) / SCALE)}
div :: proc(a, b: Fixed) -> (Fixed, bool) {
	if b == 0 {return 0, false}
	return narrow(i64(a) * SCALE / i64(b))
}

@(private)
narrow :: proc(value: i64) -> (Fixed, bool) {
	if value < i64(min(i32)) || value > i64(max(i32)) {return 0, false}
	return Fixed(value), true
}

overlap :: proc(a, b: Aabb2) -> bool {
	return a.min[0] < b.max[0] && a.max[0] > b.min[0] && a.min[1] < b.max[1] && a.max[1] > b.min[1]
}

// Squared circle comparison avoids floating roots and overflow in x²+y².
circles_overlap :: proc(a, b: Vec2, ar, br: Fixed) -> bool {
	if ar < 0 || br < 0 {return false}
	radius := u64(i64(ar) + i64(br))
	dx, dy := i64(a[0]) - i64(b[0]), i64(a[1]) - i64(b[1])
	x := u64(dx < 0 ? -dx : dx); y := u64(dy < 0 ? -dy : dy)
	if x > radius || y > radius {return false}
	r2, x2 := radius * radius, x * x
	return x2 <= r2 && y * y <= r2 - x2
}

isqrt :: proc(value: u64) -> u32 {
	n, result, bit := value, u64(0), u64(1) << 62
	for bit > n {bit >>= 2}
	for bit != 0 {
		if n >= result + bit {n -= result + bit; result = (result >> 1) + bit} else {result >>= 1}
		bit >>= 2
	}
	return u32(result)
}
