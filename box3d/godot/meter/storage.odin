package box3d_godot_meter

import "core:mem"
import bg "godot:box3d/godot"

// Caller-owned control state for one stable metered payload. Do not copy a live
// Storage. Call storage_close only after the payload's resources have closed.
// Detached data leases can keep the payload/context alive after source close.
Storage :: struct($T: typeid) {
    memory: ^Context,
    data: ^T,
    allocator_owner, live_owner: bg.Owner,
    aliases: [MAX_BLOCK_LEASES]Storage_Alias,
    alias_count: int,
    closing, creator_released: bool,
    cleanup_status: bg.Status,
}

@(private)
Storage_Alias :: struct {
    user: rawptr,
    bytes: u64,
    owner, live_owner: bg.Owner,
    lease: bg.Data_Lease,
}

storage_open :: proc(
    storage: ^Storage($T), service: bg.Service, category: u32,
    live_instance: bool = false,
) -> bg.Status {
    if storage == nil || storage.memory != nil || storage.closing || size_of(T) == 0 || service.owner_create == nil { return bg.INVALID_ARGUMENT }
    status: bg.Status
    storage.memory, status = create(service, category)
    if status != bg.OK { return status }
    complete := false
    defer if !complete {
        result := storage_close(storage)
        if result != bg.OK { storage.cleanup_status = result }
    }
    error: mem.Allocator_Error
    storage.data, error = new(T, allocator(storage.memory))
    if error != .None { return bg.CAPACITY }
    lease, lease_status := storage_allocator_lease(storage.memory, storage.data)
    if lease_status != bg.OK { return lease_status }
    status = service.owner_create(service.user, 0, &lease, &storage.allocator_owner)
    if status != bg.OK { return status }
    if live_instance {
        status = service.owner_create(service.user, 1, &lease, &storage.live_owner)
        if status != bg.OK { return status }
    }
    complete = true
    return bg.OK
}

// An allocator capability pins both the context and its stable payload. Without
// this pin, a detached checkpoint could retain the context after source close
// while malloc reuses a retired callback address for another source. Exact
// subfield capabilities remain separate; this is only allocator lifetime.
@(private)
storage_allocator_lease :: proc(ctx: ^Context, data: rawptr) -> (bg.Data_Lease, bg.Status) {
    index, found := entry_lookup(ctx, data)
    if !found { return {}, bg.INVALID_HANDLE }
    for &alias in ctx.aliases {
        if alias.user == nil {
            alias = {user = ctx, entry = index, generation = ctx.entries[index].generation}
            return {user = ctx, retain = block_retain, drop = block_drop}, bg.OK
        }
    }
    return {}, bg.CAPACITY
}

// Read-only producer/context validation; this never dereferences the payload.
storage_check :: proc(storage: ^Storage($T)) -> bg.Status {
    if storage == nil { return bg.INVALID_ARGUMENT }
    if storage.memory == nil { return bg.OK }
    return guard(storage.memory)
}

// The returned capability is borrowed from Storage; consumers retain their own
// reference. Repeated binding of the exact same typed subfield reuses its owner.
storage_bind :: proc(storage: ^Storage($T), user: ^$U, live_instance: bool = false) -> (bg.Owner, bg.Status) {
    if storage == nil || storage.closing || storage.data == nil || user == nil { return {}, bg.INVALID_ARGUMENT }
    if status := guard(storage.memory); status != bg.OK { return {}, status }
    when size_of(U) == 0 || size_of(U) > size_of(T) {
        return {}, bg.INVALID_ARGUMENT
    } else {
        base, address := uintptr(storage.data), uintptr(user)
        if address < base || address - base > size_of(T) - size_of(U) { return {}, bg.INVALID_ARGUMENT }
    }
    for &alias in storage.aliases[:storage.alias_count] {
        if alias.user == rawptr(user) {
            alias.bytes = max(alias.bytes, u64(size_of(U)))
            return storage_alias_owner(storage,&alias,live_instance)
        }
    }
    if storage.alias_count == len(storage.aliases) { return {}, bg.CAPACITY }
    lease, status := block_lease(storage.memory, storage.data, size_of(T), user, size_of(U))
    if status != bg.OK { return {}, status }
    alias := &storage.aliases[storage.alias_count]
    alias^ = {user=user,bytes=size_of(U),lease=lease}
    storage.alias_count += 1
    return storage_alias_owner(storage,alias,live_instance)
}

@(private)
storage_alias_owner :: proc(storage: ^Storage($T), alias: ^Storage_Alias, live: bool) -> (bg.Owner,bg.Status) {
    owner := live ? &alias.live_owner : &alias.owner
    if owner.user != nil { return owner^, bg.OK }
    service := storage.memory.service
    status := service.owner_create(service.user,u32(live),&alias.lease,owner)
    if status != bg.OK { storage.closing = true; return {},status }
    return owner^,bg.OK
}

@(private)
storage_owner_drop :: proc(owner: ^bg.Owner) -> bg.Status {
    if owner.user == nil { return bg.OK }
    status := owner.drop(owner.user)
    if status == bg.OK { owner^ = {} }
    return status
}

// Each successful release is recorded before attempting the next one. A refused
// final drop retains control state and its code/data capability for retry.
storage_close :: proc(storage: ^Storage($T)) -> bg.Status {
    if storage == nil { return bg.OK }
    if storage.memory == nil { storage^ = {}; return bg.OK }
    if status := guard(storage.memory); status != bg.OK { return status }
    storage.closing = true
    for &alias in storage.aliases[:storage.alias_count] {
        if status := storage_owner_drop(&alias.live_owner); status != bg.OK { return status }
        if status := storage_owner_drop(&alias.owner); status != bg.OK { return status }
    }
    if storage.data != nil {
        memory := allocator(storage.memory)
        _, error := memory.procedure(memory.data, .Free, 0, align_of(T), storage.data, size_of(T), #location())
        if error != .None { return bg.INVALID_HANDLE }
        storage.data = nil
    }
    if status := storage_owner_drop(&storage.live_owner); status != bg.OK { return status }
    // Release the creator's meter reference while the independent allocator
    // owner still pins code and context. Keep memory as a borrowed pointer until
    // that last source-owned capability has actually dropped.
    if !storage.creator_released {
        source := storage.memory
        if status := destroy(&source); status != bg.OK { return status }
        storage.creator_released = true
        if storage.allocator_owner.user == nil {
            storage^ = {}
            return bg.OK
        }
    }
    if status := storage_owner_drop(&storage.allocator_owner); status != bg.OK { return status }
    storage^ = {}
    return bg.OK
}
