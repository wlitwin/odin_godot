package replay

// Small reproducible gameplay generator. Store this in State; never use it for
// identity tokens or other secrets. The transition is fully specified u64 math.
Rng :: struct {state: u64}

rng_make :: proc(seed: u64) -> Rng {
	return {seed == 0 ? u64(0x9e3779b97f4a7c15) : seed}
}

rng_next :: proc(r: ^Rng) -> u64 {
	if r.state == 0 {r^ = rng_make(0)}
	x := r.state
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	r.state = x
	return x
}
