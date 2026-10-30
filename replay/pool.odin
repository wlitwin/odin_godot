package replay

// Handles are typed and scoped to a particular pool in a particular timeline.
// Keep handles in frame state; pointers returned by pool_get are step-local
// borrows and must never be stored in a frame or presentation object.
Handle :: struct($T: typeid) {
	index:      u32,
	generation: u32, // zero is invalid
}

Pool :: struct($T: typeid, $N: int) {
	values:      [N]T,
	generations: [N]u32,
	alive:       [N]bool,
	count:       u32,
}

// Lowest available slot first: allocation order is part of the saved world.
// A generation that exhausted u32 is retired instead of wrapping to a stale ID.
pool_insert :: proc(p: ^Pool($T, $N), value: T) -> (id: Handle(T), ok: bool) {
	#assert(N > 0 && u64(N) <= u64(max(u32)))
	for i in 0 ..< N {
		if p.alive[i] || p.generations[i] == max(u32) {continue}
		p.generations[i] += 1
		p.values[i] = value
		p.alive[i] = true
		p.count += 1
		return {u32(i), p.generations[i]}, true
	}
	return {}, false
}

pool_get :: proc(p: ^Pool($T, $N), id: Handle(T)) -> (value: ^T, ok: bool) {
	if id.generation == 0 || u64(id.index) >= u64(N) {return nil, false}
	i := int(id.index)
	if !p.alive[i] || p.generations[i] != id.generation {return nil, false}
	return &p.values[i], true
}

pool_remove :: proc(p: ^Pool($T, $N), id: Handle(T)) -> bool {
	if _, ok := pool_get(p, id); !ok {return false}
	p.alive[id.index] = false
	p.values[id.index] = {} // dead payloads cannot preserve hidden gameplay state
	p.count -= 1
	return true
}

// Clear membership while preserving generation history; a new floor cannot
// accidentally recreate an old entity handle from the previous floor.
pool_clear :: proc(p: ^Pool($T, $N)) {
	p.values, p.alive, p.count = {}, {}, 0
}
