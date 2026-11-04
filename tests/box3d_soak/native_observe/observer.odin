package native_observe_test

// Opt-in TEST binding only; production packages never import these symbols.
import "core:mem"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"

Mode :: enum u32 {
    Off,
    Structure,
    Timed,
}

Clock :: #type proc "c" (_: rawptr, _: ^u64) -> u32

Span :: struct {
    id, parent_id, root_ordinal, start_us, end_us: u64,
    phase:                                         u32,
    status:                                        i32,
}

Block :: struct {
    version,
    struct_bytes,
    mode,
    capacity,
    count,
    stack_depth,
    error_flags,
    state:                                                 u32,
    token,
    cookie,
    next_span_id,
    root_count,
    clock_reads,
    clock_errors,
    overflow_count,
    nesting_errors,
    last_clock_us,
    phase_mask: u64,
    stack:                                                                                                                         [16]u64,
    spans:                                                                                                                         [1024]Span,
}

Config :: struct {
    version: u32,
    mode:    Mode,
    mask:    u64,
    clock:   Clock,
    user:    rawptr,
}

ABI :: struct {
    version, span_bytes, config_bytes, block_bytes, span_align, block_align, span_capacity, stack_capacity: u32,
    phases, static_bytes:                                                                                   u64,
}

#assert(
    size_of(Span) == 48 &&
    size_of(Block) == 49392 &&
    align_of(Block) == 8 &&
    offset_of(Block, spans) == 240 &&
    size_of(Config) == 32 &&
    size_of(ABI) == 48,
)
LIB :: #config(BOX3D_LIBRARY, "")
foreign import observe {"system:" + LIB}

foreign observe {
    @(link_name = "ogb3_test_native_observe_abi_v1")
    abi :: proc "c" (_: u64, _: ^ABI) -> i32 ---
    @(link_name = "ogb3_test_native_observe_begin_v1")
    begin_native :: proc "c" (_: u64, _: ^Config, _: ^Block, _: u64, _: ^u64) -> i32 ---
    @(link_name = "ogb3_test_native_observe_end_v1")
    end_native :: proc "c" (_: u64, _: u64) -> i32 ---
}

Owner :: struct {
    block:                       ^Block,
    code_data:                   bg.Owner,
    memory:                      ^bm.Context,
    allocator:                   mem.Allocator,
    cookie, token, static_bytes: u64,
    free_requested:              bool,
}

check :: proc(owner: ^Owner, access: u32) -> bg.Status {
    if owner == nil || owner.block == nil {
        return bg.INVALID_HANDLE
    }

    if status := b.domain_access_check(); status != .Ok {
        return bg.INCOMPATIBLE
    }

    service := bg.service_get()

    // Owner.user is Core's opaque generational token. Data_Lease.user was the
    // exact block passed to owner_create; those two pointers are NOT aliases.
    if owner.code_data.realm != service.realm || owner.code_data.check == nil {
        return bg.INCOMPATIBLE
    }

    return owner.code_data.check(owner.code_data.user, access)
}

create :: proc(memory: ^bm.Context, test_declining_drop: bool = false) -> (Owner, bg.Status) {
    if b.domain_access_check() != .Ok {
        return {}, bg.INCOMPATIBLE
    }

    service := bg.service_get()
    allocator := bm.allocator(memory)

    if service.realm == 0 || !bm.is_allocator(allocator) {
        return {}, bg.INCOMPATIBLE
    }

    metadata: ABI

    if status := abi(service.domain.cookie, &metadata); status != 0 {
        return {}, bg.Status(status)
    }

    if metadata.version != 1 ||
       metadata.block_bytes != 49392 ||
       metadata.span_bytes != 48 ||
       metadata.config_bytes != 32 ||
       metadata.block_align != 8 ||
       metadata.span_align != 8 ||
       metadata.span_capacity != 1024 ||
       metadata.stack_capacity != 16 ||
       metadata.phases != 0x7fff {
        return {}, bg.INCOMPATIBLE
    }

    block, error := new(Block, allocator)

    if error != nil || block == nil {
        return {}, bg.OUT_OF_MEMORY
    }

    lease, ls := bm.block_lease(memory, block, u64(size_of(Block)), block, u64(size_of(Block)))

    if ls != bg.OK {
        free(block, allocator)
        return {}, ls
    }

    if test_declining_drop {
        wrapped, ws := drop_test_wrap(lease)

        if ws != bg.OK {
            free(block, allocator)
            return {}, ws
        }

        lease = wrapped
    }

    owner: bg.Owner
    status := service.owner_create(service.user, 0, &lease, &owner)

    if status != bg.OK {
        if test_declining_drop {
            drop_test_cancel()
        }

        free(block, allocator)
        return {}, status
    }

    if owner.realm != service.realm ||
       owner.context_caps & (bg.MANAGED_DATA | bg.INDEPENDENT_CONTEXT) != (bg.MANAGED_DATA | bg.INDEPENDENT_CONTEXT) {
        drop := owner.drop(owner.user)

        if drop != bg.OK {
            return {block, owner, memory, allocator, service.domain.cookie, 0, metadata.static_bytes, false}, drop
        }

        free(block, allocator)
        return {}, bg.INCOMPATIBLE
    }

    return {block, owner, memory, allocator, service.domain.cookie, 0, metadata.static_bytes, false}, bg.OK
}

begin :: proc(owner: ^Owner, mode: Mode, clock: Clock = nil, mask: u64 = 0x0fff) -> bg.Status {
    if status := check(owner, bg.EXECUTE); status != bg.OK {
        return status
    }

    if owner.free_requested {
        return bg.INVALID_HANDLE
    }

    if owner.token != 0 {
        return bg.UNSUPPORTED
    }

    cfg := Config{1, mode, mask, clock, mode == .Timed ? owner.block : nil}
    token: u64
    status := begin_native(owner.cookie, &cfg, owner.block, u64(size_of(Block)), &token)

    if status == 0 {
        owner.token = token
    }

    return bg.Status(status)
}

end :: proc(owner: ^Owner) -> bg.Status {
    if status := check(owner, bg.READ); status != bg.OK {
        return status
    }

    if owner.token == 0 {
        return bg.INVALID_HANDLE
    }

    status := end_native(owner.cookie, owner.token)

    if status == 0 {
        owner.token = 0
    }

    return bg.Status(status)
}

destroy :: proc(owner: ^Owner) -> bg.Status {
    if owner == nil || owner.block == nil {
        return bg.OK
    }

    if owner.token != 0 {
        if status := end(owner); status != bg.OK {
            return status
        }
    }

    if status := check(owner, bg.READ); status != bg.OK {
        return status
    }

    // Code/data stay alive through free and Core's eventual outer return. The
    // pinned block becomes pending-free until its actual DataLease is dropped.
    block, allocator := owner.block, owner.allocator

    if !owner.free_requested {
        free(block, allocator)
        owner.free_requested = true
    }

    status := owner.code_data.drop(owner.code_data.user)

    if status != bg.OK {
        return status
    }

    owner^ = {}
    return bg.OK
}
