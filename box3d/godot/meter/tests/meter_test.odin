package box3d_godot_meter_test

import bm ".."
import "base:runtime"
import "core:mem"
import "core:testing"
import "core:fmt"
import bg "godot:box3d/godot"

@(private)
Host :: struct {
    live, requested, peak, limit: u64,
    protected, reject_growth:     bool,
}

@(private)
service :: proc(h: ^Host) -> bg.Service {
    return {realm = 31, user = h, request_totals = proc "c" (user: rawptr, out: ^bg.Request_Totals) -> bg.Status {
            h := cast(^Host)user

            if !h.protected {
                return bg.INCOMPATIBLE
            }

            out^ = {
                host  = h.requested,
                total = h.requested,
            }
            return bg.OK
        }, legacy_extra = proc "c" (user: rawptr, mark, implicit, extra: u64, out: ^u64) -> bg.Status {
            h := cast(^Host)user

            if !h.protected {
                return bg.INCOMPATIBLE
            }

            if extra > h.limit || h.live > h.limit - extra {
                return bg.CAPACITY
            }

            out^ = h.live + extra
            return bg.OK
        }, account = proc "c" (user: rawptr, category: u32, live, requested: u64) -> bg.Status {
            h := cast(^Host)user

            if !h.protected {
                return bg.INCOMPATIBLE
            }

            if requested < h.requested {
                return bg.INVALID_ARGUMENT
            }

            h.requested = requested

            if live > h.limit || (h.reject_growth && live > h.live) {
                h.reject_growth = false
                return bg.CAPACITY
            }

            h.live = live
            h.peak = max(h.peak, live)
            return bg.OK
        }}
}

@(test)
exact_successful_requests_resize_peak_rollback_and_detached_lease :: proc(t: ^testing.T) {
    testing.expect_value(t, bg.module_profile(), u32(0))
    h := Host {
        protected = true,
        limit     = 64 * 1024 * 1024,
    }
    // Cumulative accounting belongs to a producer/category even after a meter is
    // destroyed; use its current monotonic baseline when creating this fixture.
    h.requested = requested_baseline()
    ctx, status := bm.create(service(&h), 1, capacity = 2)
    testing.expect_value(t, status, bg.OK)
    initial, se := bm.stats(ctx)
    testing.expect_value(t, se, bg.OK)
    testing.expect_value(t, initial.live_bytes, u64(size_of(bm.Context)))
    testing.expect_value(t, h.live, initial.live_bytes)
    a := bm.allocator(ctx)
    testing.expect(t, bm.is_allocator(a))
    testing.expect(t, !bm.is_allocator(mem.Allocator{data = rawptr(uintptr(1)), procedure = a.procedure}))
    first, error := a.procedure(a.data, .Alloc, 16, 8, nil, 0, #location())
    testing.expect_value(t, error, mem.Allocator_Error.None)

    for &byte, i in first {
        byte = u8(i + 1)
    }

    testing.expect(t, bm.owns(ctx, raw_data(first), 16))
    testing.expect(t, bm.owns(ctx, &first[8], 8))
    testing.expect(t, !bm.owns(ctx, &first[8], 9))
    before, _ := bm.stats(ctx)
    h.reject_growth = true
    rejected, re := a.procedure(a.data, .Resize, 32, 8, raw_data(first), 16, #location())
    testing.expect_value(t, re, mem.Allocator_Error.Out_Of_Memory)
    testing.expect(t, raw_data(rejected) == nil)
    after, _ := bm.stats(ctx)
    testing.expect_value(t, after.live_bytes, before.live_bytes)
    testing.expect_value(t, after.requested_bytes, before.requested_bytes + 32)

    for byte, i in first {
        testing.expect_value(t, byte, u8(i + 1))
    }

    testing.expect(t, bm.owns(ctx, raw_data(first), 16))
    resized, resize_error := a.procedure(a.data, .Resize, 32, 8, raw_data(first), 16, #location())
    testing.expect_value(t, resize_error, mem.Allocator_Error.None)

    for byte, i in resized[:16] {
        testing.expect_value(t, byte, u8(i + 1))
    }

    for byte in resized[16:] {
        testing.expect_value(t, byte, u8(0))
    }

    after, _ = bm.stats(ctx)
    testing.expect_value(t, after.live_bytes, u64(size_of(bm.Context) + 32))
    testing.expect_value(t, after.requested_bytes, u64(size_of(bm.Context) + 16 + 32 + 32))
    testing.expect(t, h.peak >= u64(size_of(bm.Context) + 16 + 32))
    lease := bm.data_lease(ctx)
    testing.expect_value(t, lease.user, a.data)
    testing.expect_value(t, lease.retain(lease.user), bg.OK)
    testing.expect_value(t, bm.destroy(&ctx), bg.OK)
    testing.expect(t, ctx == nil)
    // Original context owner is gone, but actual retained allocator data lives.
    tracked, te := bm.context_for(a)
    testing.expect_value(t, te, bg.OK)
    testing.expect_value(t, bm.destroy(&tracked), bg.INVALID_HANDLE) // live allocation
    _, fe := a.procedure(a.data, .Free, 0, 8, raw_data(resized), 0, #location())
    testing.expect_value(t, fe, mem.Allocator_Error.None)
    testing.expect_value(t, lease.drop(lease.user), bg.OK)
    testing.expect_value(t, h.live, u64(0))
    testing.expect(t, !bm.is_allocator(a))
}

@(test)
multiple_contexts_one_category_table_full_and_budget_failures_are_atomic :: proc(t: ^testing.T) {
    h := Host {
        protected = true,
        limit     = 64 * 1024 * 1024,
        requested = requested_baseline(),
    }
    left, le := bm.create(service(&h), 1, capacity = 1)
    right, re := bm.create(service(&h), 1, capacity = 1)
    testing.expect_value(t, le, bg.OK)
    testing.expect_value(t, re, bg.OK)
    testing.expect_value(t, h.live, u64(2 * size_of(bm.Context)))
    a := bm.allocator(left)
    bytes, error := a.procedure(a.data, .Alloc, 16, 8, nil, 0, #location())
    testing.expect_value(t, error, mem.Allocator_Error.None)
    before, _ := bm.stats(left)
    _, full := a.procedure(a.data, .Alloc, 16, 8, nil, 0, #location())
    testing.expect_value(t, full, mem.Allocator_Error.Out_Of_Memory)
    after, _ := bm.stats(left)
    testing.expect_value(t, after, before)
    h.limit = h.live
    _, over := a.procedure(a.data, .Resize, 32, 8, raw_data(bytes), 16, #location())
    testing.expect_value(t, over, mem.Allocator_Error.Out_Of_Memory)
    after, _ = bm.stats(left)
    testing.expect_value(t, after, before)
    h.protected = false
    _, unprotected := a.procedure(a.data, .Free, 0, 8, raw_data(bytes), 0, #location())
    testing.expect_value(t, unprotected, mem.Allocator_Error.Invalid_Argument)
    h.protected = true
    _, _ = a.procedure(a.data, .Free, 0, 8, raw_data(bytes), 0, #location())
    testing.expect_value(t, bm.destroy(&left), bg.OK)
    testing.expect_value(t, h.live, u64(size_of(bm.Context)))
    testing.expect_value(t, bm.destroy(&right), bg.OK)
    testing.expect_value(t, h.live, u64(0))
    // Borrowed backing data and invalid capacity are rejected before allocation.
    borrowed := mem.Allocator {
        procedure = runtime.heap_allocator().procedure,
        data      = &h,
    }
    _, be := bm.create(service(&h), 1, borrowed)
    testing.expect_value(t, be, bg.UNSUPPORTED)
    _, ce := bm.create(service(&h), 1, capacity = bm.MAX_ALLOCATIONS + 1)
    testing.expect_value(t, ce, bg.INVALID_ARGUMENT)
    testing.expect_value(t, h.live, u64(0))
}

requested_baseline :: proc() -> u64 {
    s, _ := bm.category_stats(1)
    return s.requested_bytes
}

@(test)
explicit_block_alias_lease_retains_real_allocation_after_source_free :: proc(t: ^testing.T) {
    h := Host {
        protected = true,
        limit     = 64 * 1024 * 1024,
        requested = requested_baseline(),
    }
    ctx, status := bm.create(service(&h), 1, capacity = 2)
    testing.expect_value(t, status, bg.OK)
    a := bm.allocator(ctx)
    bytes, error := a.procedure(a.data, .Alloc, 64, 8, nil, 0, #location())
    testing.expect_value(t, error, mem.Allocator_Error.None)
    user := rawptr(&bytes[16])
    (cast(^u64)user)^ = 0x123456789abcdef
    _, bad_base := bm.block_lease(ctx, &bytes[8], 56, user, 8)
    testing.expect_value(t, bad_base, bg.INVALID_HANDLE)
    _, bad_size := bm.block_lease(ctx, raw_data(bytes), 63, user, 8)
    testing.expect_value(t, bad_size, bg.INVALID_HANDLE)
    _, bad_bounds := bm.block_lease(ctx, raw_data(bytes), 64, &bytes[60], 8)
    testing.expect_value(t, bad_bounds, bg.INVALID_ARGUMENT)
    lease, ls := bm.block_lease(ctx, raw_data(bytes), 64, user, 8)
    testing.expect_value(t, ls, bg.OK)
    testing.expect_value(t, lease.user, user)
    testing.expect_value(t, lease.drop(user), bg.INVALID_HANDLE) // never retained
    testing.expect_value(t, lease.retain(user), bg.OK)
    before, _ := bm.stats(ctx)
    _, pinned_resize := a.procedure(a.data, .Resize, 128, 8, raw_data(bytes), 64, #location())
    testing.expect_value(t, pinned_resize, mem.Allocator_Error.Invalid_Argument)
    after, _ := bm.stats(ctx)
    testing.expect_value(t, after, before)
    _, free_error := a.procedure(a.data, .Free, 0, 8, raw_data(bytes), 64, #location())
    testing.expect_value(t, free_error, mem.Allocator_Error.None)
    after, _ = bm.stats(ctx)
    testing.expect_value(t, after.live_bytes, before.live_bytes)
    testing.expect_value(t, after.requested_bytes, before.requested_bytes)
    testing.expect_value(t, (cast(^u64)user)^, u64(0x123456789abcdef))
    testing.expect_value(t, lease.retain(user), bg.OK) // clone still-owned alias
    testing.expect_value(t, bm.destroy(&ctx), bg.OK)
    testing.expect(t, ctx == nil)
    testing.expect_value(t, lease.drop(user), bg.OK)
    testing.expect_value(t, (cast(^u64)user)^, u64(0x123456789abcdef))
    testing.expect_value(t, lease.drop(user), bg.OK)
    testing.expect_value(t, h.live, u64(0))
    testing.expect(t, !bm.is_allocator(a))
    testing.expect_value(t, lease.drop(user), bg.INVALID_HANDLE)
    testing.expect_value(t, lease.retain(user), bg.INVALID_HANDLE)
}

// Observe the index as a set of stable Entry indices; actual allocator and
// block-lease calls below exercise lookup/removal without synthetic pointers.
@(private)
expect_index :: proc(t: ^testing.T, ctx: ^bm.Context) {
    live, free: [bm.MAX_ALLOCATIONS]bool
    live_count: u64

    for head in ctx.pointer_heads {
        link := head

        for _ in 0 ..< ctx.capacity {
            if link == 0 {
                break
            }

            index := u32(link - 1)
            testing.expect(t, index < ctx.capacity)

            if index >= ctx.capacity {
                return
            }

            testing.expect(t, !live[index])

            if live[index] {
                return
            }

            testing.expect(t, ctx.entries[index].pointer != nil)
            live[index] = true
            live_count += 1
            link = ctx.pointer_next[index]
        }

        testing.expect_value(t, link, u16(0))
    }

    testing.expect(t, ctx.free_count <= ctx.capacity)

    if ctx.free_count > ctx.capacity {
        return
    }

    for index in ctx.free_slots[:ctx.free_count] {
        testing.expect(t, u32(index) < ctx.capacity)

        if u32(index) >= ctx.capacity {
            return
        }

        testing.expect(t, !free[index] && !live[index])
        free[index] = true
        testing.expect(t, ctx.entries[index].pointer == nil)
        testing.expect_value(t, ctx.pointer_next[index], u16(0))
    }

    for entry, index in ctx.entries[:ctx.capacity] {
        testing.expect(t, live[index] == (entry.pointer != nil))
        testing.expect(t, live[index] != free[index])
    }

    testing.expect_value(t, live_count, ctx.values.allocation_count)
    testing.expect_value(t, live_count + u64(ctx.free_count), u64(ctx.capacity))
}

@(private)
index_of :: proc(ctx: ^bm.Context, pointer: rawptr) -> u32 {
    for entry, index in ctx.entries[:ctx.capacity] {
        if entry.pointer == pointer {
            return u32(index)
        }
    }

    assert(false, "test allocation missing from stable entries")
    return 0
}

@(test)
full_capacity_collisions_delete_and_resize_preserve_other_entries :: proc(t: ^testing.T) {
    h := Host {
        protected = true,
        limit     = 64 * 1024 * 1024,
        requested = requested_baseline(),
    }
    ctx, status := bm.create(service(&h), 1)
    testing.expect_value(t, status, bg.OK)

    if status != bg.OK {
        return
    }

    fmt.printf(
        "METER_INDEX context_bytes=%d entries=%d buckets=%d\n",
        size_of(bm.Context),
        bm.MAX_ALLOCATIONS,
        len(ctx.pointer_heads),
    )
    a := bm.allocator(ctx)
    blocks: [bm.MAX_ALLOCATIONS][]u8

    for &block, index in blocks {
        var_error: mem.Allocator_Error
        block, var_error = a.procedure(a.data, .Alloc, 16, 8, nil, 0, #location())
        testing.expect_value(t, var_error, mem.Allocator_Error.None)

        if var_error != nil {
            return
        }

        (cast(^u64)raw_data(block))^ = u64(index + 1)
    }

    expect_index(t, ctx)
    before, _ := bm.stats(ctx)
    _, full := a.procedure(a.data, .Alloc, 8, 8, nil, 0, #location())
    testing.expect_value(t, full, mem.Allocator_Error.Out_Of_Memory)
    after, _ := bm.stats(ctx)
    testing.expect_value(t, after, before)
    testing.expect_value(t, after.live_bytes, u64(size_of(bm.Context)) + 4096 * 16)

    // 4096 real pointers in 2048 buckets guarantee a real collision.
    first, second: u32
    found := false

    for head in ctx.pointer_heads {
        if head == 0 {
            continue
        }

        index := u32(head - 1)

        if next := ctx.pointer_next[index]; next != 0 {
            first, second, found = index, u32(next - 1), true
            break
        }
    }

    testing.expect(t, found)

    if !found {
        return
    }

    // Exact-base lease lookup must traverse the collision too, while an
    // interior address remains an invalid allocation base.
    base := ctx.entries[second].pointer
    user := rawptr(uintptr(base) + 8)
    lease, ls := bm.block_lease(ctx, base, 16, user, 8)
    testing.expect_value(t, ls, bg.OK)
    testing.expect_value(t, lease.retain(user), bg.OK)
    testing.expect_value(t, lease.drop(user), bg.OK)
    _, interior := bm.block_lease(ctx, user, 8, user, 8)
    testing.expect_value(t, interior, bg.INVALID_HANDLE)

    for index in ([2]u32{second, first}) {
        pointer := ctx.entries[index].pointer
        _, error := a.procedure(a.data, .Free, 0, 8, pointer, 16, #location())
        testing.expect_value(t, error, mem.Allocator_Error.None)
        blocks[index] = nil
        testing.expect(t, !bm.owns(ctx, pointer, 16))
        _, double_free := a.procedure(a.data, .Free, 0, 8, pointer, 16, #location())
        testing.expect_value(t, double_free, mem.Allocator_Error.Invalid_Pointer)
        expect_index(t, ctx)
    }

    for block, index in blocks {
        if len(block) > 0 {
            testing.expect_value(t, (cast(^u64)raw_data(block))^, u64(index + 1))
        }
    }

    for _ in 0 ..< 2 {
        block, error := a.procedure(a.data, .Alloc, 16, 8, nil, 0, #location())
        testing.expect_value(t, error, mem.Allocator_Error.None)
        index := index_of(ctx, raw_data(block))
        blocks[index] = block
        (cast(^u64)raw_data(block))^ = u64(index + 1)
    }

    expect_index(t, ctx)
    // Resize also works with no free Entry; it preserves the existing index.
    index := first
    old := blocks[index]
    generation := ctx.entries[index].generation
    resized, error := a.procedure(a.data, .Resize, 32, 8, raw_data(old), 16, #location())
    testing.expect_value(t, error, mem.Allocator_Error.None)
    testing.expect_value(t, index_of(ctx, raw_data(resized)), index)
    testing.expect_value(t, ctx.entries[index].generation, generation + 1)
    testing.expect_value(t, (cast(^u64)raw_data(resized))^, u64(index + 1))
    blocks[index] = resized
    _, stale := a.procedure(a.data, .Free, 0, 8, raw_data(old), 16, #location())
    testing.expect_value(t, stale, mem.Allocator_Error.Invalid_Pointer)
    expect_index(t, ctx)

    for block in blocks {
        _, error = a.procedure(a.data, .Free, 0, 8, raw_data(block), len(block), #location())
        testing.expect_value(t, error, mem.Allocator_Error.None)
    }

    expect_index(t, ctx)
    testing.expect_value(t, bm.destroy(&ctx), bg.OK)
    testing.expect_value(t, h.live, u64(0))
}

@(test)
churn_and_rejected_resize_leave_index_free_slots_and_payload_atomic :: proc(t: ^testing.T) {
    h := Host {
        protected = true,
        limit     = 64 * 1024 * 1024,
        requested = requested_baseline(),
    }
    ctx, status := bm.create(service(&h), 1, capacity = 17)
    testing.expect_value(t, status, bg.OK)
    a := bm.allocator(ctx)
    blocks: [17][]u8
    requested := u64(size_of(bm.Context))
    live := requested

    for &block in blocks {
        error: mem.Allocator_Error
        block, error = a.procedure(a.data, .Alloc, 16, 8, nil, 0, #location())
        testing.expect_value(t, error, mem.Allocator_Error.None)
        requested += 16
        live += 16
    }

    for round in 0 ..< 128 {
        position := (round * 7) % len(blocks)
        old := blocks[position]
        index := index_of(ctx, raw_data(old))
        generation := ctx.entries[index].generation
        _, error := a.procedure(a.data, .Free, 0, 8, raw_data(old), len(old), #location())
        testing.expect_value(t, error, mem.Allocator_Error.None)
        live -= u64(len(old))
        size := 8 + round % 31
        fresh, ae := a.procedure(a.data, .Alloc, size, 8, nil, 0, #location())
        testing.expect_value(t, ae, mem.Allocator_Error.None)
        blocks[position] = fresh
        requested += u64(size)
        live += u64(size)
        testing.expect_value(t, index_of(ctx, raw_data(fresh)), index)
        testing.expect_value(t, ctx.entries[index].generation, generation + 1)

        for &byte, n in fresh {
            byte = u8(n + 1)
        }

        before, _ := bm.stats(ctx)
        heads, links, slots, count := ctx.pointer_heads, ctx.pointer_next, ctx.free_slots, ctx.free_count
        // Preflight denial performs no successful backing request.
        h.limit = h.live
        _, denied := a.procedure(a.data, .Resize, size + 32, 8, raw_data(fresh), size, #location())
        testing.expect_value(t, denied, mem.Allocator_Error.Out_Of_Memory)
        after, _ := bm.stats(ctx)
        testing.expect_value(t, after, before)
        h.limit = 64 * 1024 * 1024
        // Account denial follows a successful temporary allocation, so cumulative
        // requested work advances although every old allocation/index stays put.
        h.reject_growth = true
        _, denied = a.procedure(a.data, .Resize, size + 32, 8, raw_data(fresh), size, #location())
        testing.expect_value(t, denied, mem.Allocator_Error.Out_Of_Memory)
        requested += u64(size + 32)
        after, _ = bm.stats(ctx)
        testing.expect_value(t, after.live_bytes, live)
        testing.expect_value(t, after.requested_bytes, requested)
        testing.expect_value(t, ctx.pointer_heads, heads)
        testing.expect_value(t, ctx.pointer_next, links)
        testing.expect_value(t, ctx.free_slots, slots)
        testing.expect_value(t, ctx.free_count, count)
        testing.expect_value(t, ctx.entries[index].generation, generation + 1)

        for byte, n in fresh {
            testing.expect_value(t, byte, u8(n + 1))
        }

        expect_index(t, ctx)
    }

    for block in blocks {
        _, error := a.procedure(a.data, .Free, 0, 8, raw_data(block), len(block), #location())
        testing.expect_value(t, error, mem.Allocator_Error.None)
    }

    expect_index(t, ctx)
    testing.expect_value(t, bm.destroy(&ctx), bg.OK)
    testing.expect_value(t, h.live, u64(0))
}

@(test)
pending_pinned_free_keeps_index_and_slot_until_last_drop :: proc(t: ^testing.T) {
    h := Host {
        protected = true,
        limit     = 64 * 1024 * 1024,
        requested = requested_baseline(),
    }
    ctx, status := bm.create(service(&h), 1, capacity = 1)
    testing.expect_value(t, status, bg.OK)
    a := bm.allocator(ctx)
    bytes, error := a.procedure(a.data, .Alloc, 32, 8, nil, 0, #location())
    testing.expect_value(t, error, mem.Allocator_Error.None)
    index := index_of(ctx, raw_data(bytes))
    generation := ctx.entries[index].generation
    user := rawptr(&bytes[8])
    lease, ls := bm.block_lease(ctx, raw_data(bytes), 32, user, 8)
    testing.expect_value(t, ls, bg.OK)
    testing.expect_value(t, lease.retain(user), bg.OK)
    testing.expect_value(t, lease.retain(user), bg.OK)
    before, _ := bm.stats(ctx)
    heads, links := ctx.pointer_heads, ctx.pointer_next
    _, pinned := a.procedure(a.data, .Resize, 64, 8, raw_data(bytes), 32, #location())
    testing.expect_value(t, pinned, mem.Allocator_Error.Invalid_Argument)
    _, fe := a.procedure(a.data, .Free, 0, 8, raw_data(bytes), 32, #location())
    testing.expect_value(t, fe, mem.Allocator_Error.None)
    testing.expect(t, ctx.entries[index].pending_free)
    testing.expect_value(t, ctx.entries[index].generation, generation)
    testing.expect_value(t, ctx.free_count, u32(0))
    testing.expect_value(t, ctx.pointer_heads, heads)
    testing.expect_value(t, ctx.pointer_next, links)
    _, full := a.procedure(a.data, .Alloc, 8, 8, nil, 0, #location())
    testing.expect_value(t, full, mem.Allocator_Error.Out_Of_Memory)
    after, _ := bm.stats(ctx)
    testing.expect_value(t, after, before)
    _, duplicate := a.procedure(a.data, .Free, 0, 8, raw_data(bytes), 32, #location())
    testing.expect_value(t, duplicate, mem.Allocator_Error.Invalid_Pointer)
    testing.expect_value(t, lease.drop(user), bg.OK)
    testing.expect_value(t, ctx.free_count, u32(0))
    expect_index(t, ctx)
    testing.expect_value(t, lease.drop(user), bg.OK)
    testing.expect_value(t, ctx.free_count, u32(1))
    expect_index(t, ctx)
    testing.expect_value(t, lease.drop(user), bg.INVALID_HANDLE)
    testing.expect_value(t, lease.retain(user), bg.INVALID_HANDLE)
    // A denied allocation must not consume the newly freed slot or install a
    // pointer, despite its successful temporary backing request being counted.
    before, _ = bm.stats(ctx)
    heads, links = ctx.pointer_heads, ctx.pointer_next
    slots, count := ctx.free_slots, ctx.free_count
    h.reject_growth = true
    _, rejected := a.procedure(a.data, .Alloc, 32, 8, nil, 0, #location())
    testing.expect_value(t, rejected, mem.Allocator_Error.Out_Of_Memory)
    after, _ = bm.stats(ctx)
    testing.expect_value(t, after.live_bytes, before.live_bytes)
    testing.expect_value(t, after.requested_bytes, before.requested_bytes + 32)
    testing.expect_value(t, ctx.pointer_heads, heads)
    testing.expect_value(t, ctx.pointer_next, links)
    testing.expect_value(t, ctx.free_slots, slots)
    testing.expect_value(t, ctx.free_count, count)
    testing.expect_value(t, ctx.entries[index].generation, generation)
    fresh, ae := a.procedure(a.data, .Alloc, 32, 8, nil, 0, #location())
    testing.expect_value(t, ae, mem.Allocator_Error.None)
    testing.expect_value(t, index_of(ctx, raw_data(fresh)), index)
    testing.expect_value(t, ctx.entries[index].generation, generation + 1)
    _, stale_alias := bm.block_lease(ctx, raw_data(fresh), 32, user, 8)
    testing.expect_value(t, stale_alias, raw_data(fresh) == raw_data(bytes) ? bg.INVALID_HANDLE : bg.INVALID_ARGUMENT)
    _, _ = a.procedure(a.data, .Free, 0, 8, raw_data(fresh), 32, #location())
    testing.expect_value(t, bm.destroy(&ctx), bg.OK)
    testing.expect_value(t, h.live, u64(0))
}
