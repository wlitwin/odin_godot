package gdext_alloc_test

// ----------------------------------------------------------------------------
// Regression test for the `gdext.godot_allocator` zeroing bug.
//
// `godot_allocator_proc` used to treat `.Alloc` and `.Alloc_Non_Zeroed`
// identically — never zeroing — because Godot's `mem_alloc` returns raw
// (non-zeroed) memory. But `.Alloc` is contractually zeroed, and Odin's growing
// Arena (the type behind `godot_context().temp_allocator`) reads a fresh
// `Memory_Block` header expecting zero: `memory_block_alloc` does
// `assert(block.used == 0)`. With non-zeroed backing memory that field is
// garbage and the editor aborts — which is exactly what a big `gd.` autocomplete
// did, once the process had churned the heap enough that malloc handed back
// dirty (reused) memory instead of fresh zero pages.
//
// This harness makes the failure DETERMINISTIC: it points gdext's interface
// allocators at a libc malloc that POISONS every allocation with 0xAA, then
// (1) asserts `.Alloc` still returns zeroed memory and (2) forces a
// godot-backed Arena to grow past several blocks without tripping the assert.
// Pre-fix this aborts; post-fix it prints GDEXT_ALLOC_OK.
// ----------------------------------------------------------------------------

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:mem"
import libc "core:c/libc"

import "godot:gdext"

// A non-zeroing malloc that poisons memory with 0xAA — faithfully simulates
// Godot's mem_alloc returning dirty, previously-freed heap memory.
poison_alloc :: proc "c" (p_bytes: c.size_t) -> rawptr {
	p := libc.malloc(p_bytes)
	if p != nil {
		libc.memset(p, 0xAA, p_bytes)
	}
	return p
}

poison_realloc :: proc "c" (p_ptr: rawptr, p_bytes: c.size_t) -> rawptr {
	return libc.realloc(p_ptr, p_bytes)
}

wrap_free :: proc "c" (p_ptr: rawptr) {
	libc.free(p_ptr)
}

main :: proc() {
	// Route gdext's Godot interface allocators through the poisoning wrappers.
	gdext.mem_alloc = poison_alloc
	gdext.mem_realloc = poison_realloc
	gdext.mem_free = wrap_free

	a := gdext.godot_allocator()

	// (1) `.Alloc` must return ZEROED memory despite the poisoned backing.
	buf, err := mem.alloc_bytes(4096, allocator = a)
	assert(err == nil, "gdext .Alloc failed")
	for b in buf {
		assert(b == 0, "gdext .Alloc returned non-zeroed memory (the bug)")
	}
	mem.free_bytes(buf, a)

	// (2) An Arena backed by the godot allocator must grow across multiple
	//     blocks without tripping memory_block_alloc's `assert(block.used == 0)`.
	//     This is the exact path godot_context().temp_allocator takes when a big
	//     `gd.` completion outgrows the first block.
	arena: runtime.Arena
	arena.backing_allocator = a
	ta := runtime.Allocator{runtime.arena_allocator_proc, &arena}

	target := 2 * runtime.DEFAULT_TEMP_ALLOCATOR_BACKING_SIZE + (1 << 20)
	done := 0
	for done < target {
		chunk, e := mem.alloc_bytes(64 * 1024, allocator = ta)
		assert(e == nil, "arena grow alloc failed")
		// Touch each page so a real write lands (catches bad block bookkeeping).
		for j := 0; j < len(chunk); j += 4096 {
			chunk[j] = byte(j)
		}
		done += len(chunk)
	}
	free_all(ta) // exercises the arena's .Free_All path too

	fmt.println("GDEXT_ALLOC_OK")
}
