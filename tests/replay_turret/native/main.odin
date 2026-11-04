package main
import "core:fmt"
import "core:mem"
import c "../corpus"

main :: proc() {
    tracking: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking, context.allocator)
    defer mem.tracking_allocator_destroy(&tracking)
    context.allocator = mem.tracking_allocator(&tracking)
    hash, ok := c.verify()
    assert(ok)
    fmt.printf(
        "TURRET_CORPUS_OK hash=%d live=%d peak=%d total=%d\n",
        hash,
        tracking.current_memory_allocated,
        tracking.peak_memory_allocated,
        tracking.total_memory_allocated,
    )
    assert(tracking.current_memory_allocated == 0)
}
