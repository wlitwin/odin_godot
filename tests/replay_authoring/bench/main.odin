package main
import "core:fmt"
import "core:mem"
import "core:time"
import content "../../../examples/replay_scrapyard/shared/content"
import v "godot:replay/view"
import game "../../../examples/replay_scrapyard/shared/game"
import display "../../../examples/replay_scrapyard/shared/presentation"
import scenegd "godot:replay/godot/scene"

main :: proc() {
    tracking: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking, context.allocator)
    defer mem.tracking_allocator_destroy(&tracking)
    context.allocator = mem.tracking_allocator(&tracking)
    start := time.tick_now()
    sum := u64(0)

    for _ in 0 ..< 100 {
        value := content.stock()
        sum += u64(value.guns[0].damage)
    }

    elapsed := time.tick_since(start)
    fmt.printf(
        "STOCK_LOAD samples=100 ns=%d checksum=%d live=%d peak=%d total=%d\n",
        i64(elapsed),
        sum,
        tracking.current_memory_allocated,
        tracking.peak_memory_allocated,
        tracking.total_memory_allocated,
    )
    // Exact Odin buffer payload sizes (excludes allocator metadata and Godot-owned
    // resources/nodes). All scene pools have the same configured entity capacity.
    P :: scenegd.View_Pool2(game.Mob, display.Mob_View, rawptr)
    p: P
    capacity := game.MAX_MOBS
    buckets := 2

    for buckets < capacity * 2 {
        buckets *= 2
    }

    index := buckets * (size_of(u64) + size_of(int)) + capacity * size_of(u32)
    per_pool := capacity * (size_of(p.entries[0]) + size_of(p.instances[0]) + size_of(int)) + 2 * index
    per_pool += capacity * (size_of(p.nodes.entries[0]) + size_of(int)) + 2 * index
    extra :=
        content.MAX_MOBS * (size_of(P) + capacity * size_of(v.View_Item(game.Mob, display.Mob_View)) + size_of(int)) +
        index
    fmt.printf(
        "ARCHETYPE_BUFFERS entity_capacity=%d id_limit=%d registered=7 prior_single=%d current=%d increase=%d\n",
        capacity,
        content.MAX_MOBS,
        per_pool,
        7 * per_pool + extra,
        6 * per_pool + extra,
    )

    if tracking.current_memory_allocated != 0 {
        panic("benchmark leaked")
    }
}
