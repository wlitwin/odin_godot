package replay_module_test

import "core:testing"
import "core:mem"
import "base:runtime"
import r "godot:replay"
import bg "godot:box3d/godot"
import f "godot:tests/replay_external/fixture"
import life "fixture"

// Focused pure-hook fixture only. Actual stable Core/generation return-pin
// acceptance belongs to the separately built Godot module tests.
Owner_Host :: struct {
    active, weak_alive, weak_required, deny_drop: bool,
    refs:                                         u32,
    checks, retains, drops:                       u32,
    ctx:                                          ^life.Context,
}

owner_check :: proc "c" (pointer: rawptr, access: u32) -> bg.Status {
    host := cast(^Owner_Host)pointer
    host.checks += 1

    if !host.active || host.ctx == nil {
        return bg.INCOMPATIBLE
    }

    if access == bg.EXECUTE && host.weak_required && !host.weak_alive {
        return bg.INVALID_HANDLE
    }

    return bg.OK
}

owner_retain_hook :: proc "c" (pointer: rawptr) -> bg.Status {
    context = runtime.default_context()
    host := cast(^Owner_Host)pointer

    if !host.active || host.ctx == nil {
        return bg.INVALID_HANDLE
    }

    life.context_retain(host.ctx)
    host.refs += 1
    host.retains += 1
    return bg.OK
}

owner_drop_hook :: proc "c" (pointer: rawptr) -> bg.Status {
    context = runtime.default_context()
    host := cast(^Owner_Host)pointer

    if !host.active || host.ctx == nil || host.refs == 0 {
        return bg.INVALID_HANDLE
    }

    if host.deny_drop {
        return bg.CAPACITY
    }

    temporary := host.ctx
    host.refs -= 1
    host.drops += 1

    if host.refs == 0 {
        host.ctx = nil
    }

    life.context_release(&temporary)
    return bg.OK
}

create_owner :: proc(host: ^Owner_Host, source: ^life.Source_Instance, weak: bool) -> r.Owner {
    host^ = {
        active        = true,
        weak_alive    = true,
        weak_required = weak,
        refs          = 1,
        ctx           = source.ctx,
    }
    life.context_retain(source.ctx)
    return {
        user = host,
        realm = 73,
        context_caps = bg.MANAGED_DATA | (weak ? bg.WEAK_INSTANCE : bg.INDEPENDENT_CONTEXT),
        check = owner_check,
        retain = owner_retain_hook,
        drop = owner_drop_hook,
    }
}

@(test)
whole_complete_owner_retains_real_allocator_after_source_free_and_rejects_unprotected_access :: proc(t: ^testing.T) {
    testing.expect_value(t, r.owner_realm_install(73), r.Error.None)
    log: life.Log
    source := life.source_create(&log, 17)
    host: Owner_Host
    creator := create_owner(&host, source, false)
    stats: f.Stats
    base, base_owner := f.checkpoint(i64, &stats, 11, r.Frame(f.Game){state = {sum = 2}})
    defer f.owner_destroy(&base_owner)
    defer r.complete_checkpoint_destroy(&base)
    external := base._external
    external.owner = creator
    external.owner_allocator_data = life.context_allocator(host.ctx).data
    image, clone_error := external.clone(base._image)
    testing.expect_value(t, clone_error, r.Error.None)
    events := []r.Occurrence(i64){{id = {epoch = 1, tick = 0, source = 1, key = 2}, value = 5}}
    checkpoint, error := r.complete_checkpoint_adopt(
        base.frame,
        i64,
        external,
        image,
        base._image_bytes,
        1,
        events,
        life.context_allocator(host.ctx),
    )
    testing.expect_value(t, error, r.Error.None)
    testing.expect(t, host.ctx.tracker.current_memory_allocated > 0)
    life.source_destroy(&source)
    host.weak_alive = false
    testing.expect_value(t, log.instances_freed, u64(1))
    testing.expect_value(t, log.contexts_freed, u64(0))
    testing.expect_value(t, r.owner_drop(&creator), r.Error.None)
    before := checkpoint._image
    live := host.ctx.tracker.current_memory_allocated
    refs := host.refs
    host.active = false
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.External_State)
    testing.expect_value(t, checkpoint._image, before)
    testing.expect_value(t, host.ctx.tracker.current_memory_allocated, live)
    testing.expect_value(t, host.refs, refs)
    host.active = true
    old := checkpoint.owner.realm
    checkpoint.owner.realm = 74
    checks := host.checks
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.External_State)
    testing.expect_value(t, host.checks, checks)
    testing.expect_value(t, checkpoint._image, before)
    checkpoint.owner.realm = old
    copy, copy_error := r.complete_checkpoint_clone(&checkpoint, life.context_allocator(host.ctx))
    testing.expect_value(t, copy_error, r.Error.None)
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.None)
    testing.expect_value(t, log.contexts_freed, u64(0))
    testing.expect_value(t, r.complete_checkpoint_destroy(&copy), r.Error.None)
    testing.expect_value(t, log.contexts_freed, u64(1))
    testing.expect_value(t, host.refs, u32(0))
    testing.expect(t, host.ctx == nil)
}

@(test)
weak_source_owner_allows_cached_clone_destroy_but_rejects_execution_after_actual_source_free :: proc(t: ^testing.T) {
    testing.expect_value(t, r.owner_realm_install(73), r.Error.None)
    log: life.Log
    source := life.source_create(&log, 19)
    host: Owner_Host
    creator := create_owner(&host, source, true)
    stats: f.Stats
    base, base_owner := f.checkpoint(i64, &stats, 4)
    defer f.owner_destroy(&base_owner)
    defer r.complete_checkpoint_destroy(&base)
    external := base._external
    external.owner = creator
    external.owner_allocator_data = life.context_allocator(host.ctx).data
    image, clone_error := external.clone(base._image)
    testing.expect_value(t, clone_error, r.Error.None)
    checkpoint, error := r.complete_checkpoint_adopt(
        base.frame,
        i64,
        external,
        image,
        base._image_bytes,
        allocator = life.context_allocator(host.ctx),
    )
    testing.expect_value(t, error, r.Error.None)
    life.source_destroy(&source)
    host.weak_alive = false
    testing.expect_value(t, r.owner_drop(&creator), r.Error.None)
    timeline: r.Timeline(f.Game, f.Input, i64)
    testing.expect_value(t, r.init_complete(&timeline, &checkpoint, f.step, {128, 8}), r.Error.External_State)
    testing.expect_value(t, len(timeline.records), 0)
    copy, copy_error := r.complete_checkpoint_clone(&checkpoint, life.context_allocator(host.ctx))
    testing.expect_value(t, copy_error, r.Error.None)
    testing.expect_value(t, r.complete_checkpoint_destroy(&copy), r.Error.None)
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.None)
    testing.expect_value(t, log.instances_freed, u64(1))
    testing.expect_value(t, log.contexts_freed, u64(1))
}

@(test)
timeline_owner_guards_entire_runtime_cleanup_and_rejects_unretained_allocator_user :: proc(t: ^testing.T) {
    testing.expect_value(t, r.owner_realm_install(73), r.Error.None)
    log: life.Log
    source := life.source_create(&log, 23)
    host: Owner_Host
    creator := create_owner(&host, source, false)
    stats: f.Stats
    base, base_owner := f.checkpoint(i64, &stats, 7, history = 128)
    defer f.owner_destroy(&base_owner)
    defer r.complete_checkpoint_destroy(&base)
    external := base._external
    external.owner = creator
    external.owner_allocator_data = life.context_allocator(host.ctx).data
    image, ie := external.clone(base._image)
    testing.expect_value(t, ie, r.Error.None)
    checkpoint, ce := r.complete_checkpoint_adopt(
        base.frame,
        i64,
        external,
        image,
        base._image_bytes,
        allocator = life.context_allocator(host.ctx),
    )
    testing.expect_value(t, ce, r.Error.None)
    timeline: r.Timeline(f.Game, f.Input, i64)
    // A different raw allocator context is not covered by this retained lease.
    other_log: life.Log
    other := life.source_create(&other_log, 29)
    testing.expect_value(
        t,
        r.init_complete(&timeline, &checkpoint, f.step, {128, 8}, allocator = life.context_allocator(other.ctx)),
        r.Error.Unsupported_Value,
    )
    testing.expect_value(t, len(timeline.records), 0)
    // Nil data is not sufficient: arbitrary procedure may hide borrowed globals.
    custom := mem.Allocator {
        procedure = proc(
            user: rawptr,
            mode: mem.Allocator_Mode,
            size, alignment: int,
            old: rawptr,
            old_size: int,
            location: runtime.Source_Code_Location,
        ) -> (
            []u8,
            mem.Allocator_Error,
        ) {
            return nil, .Out_Of_Memory
        },
    }
    testing.expect_value(
        t,
        r.init_complete(&timeline, &checkpoint, f.step, {128, 8}, allocator = custom),
        r.Error.Unsupported_Value,
    )
    testing.expect_value(t, len(timeline.records), 0)
    life.source_destroy(&other)
    testing.expect_value(t, other_log.contexts_freed, u64(1))
    dummy := u64(9)
    testing.expect_value(
        t,
        r.init_complete(&timeline, &checkpoint, f.step, {128, 8}, user = &dummy),
        r.Error.Unsupported_Value,
    )
    testing.expect_value(t, len(timeline.records), 0)
    testing.expect_value(
        t,
        r.init_complete(&timeline, &checkpoint, f.step, {128, 8}, allocator = life.context_allocator(host.ctx)),
        r.Error.None,
    )
    life.source_destroy(&source)
    host.weak_alive = false
    testing.expect_value(t, r.owner_drop(&creator), r.Error.None)
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.None)
    testing.expect_value(t, log.instances_freed, u64(1))
    testing.expect_value(t, log.contexts_freed, u64(0))
    before := host.ctx.tracker.current_memory_allocated
    records := rawptr(raw_data(timeline.records))
    refs := host.refs
    host.active = false
    testing.expect_value(t, r.destroy(&timeline), r.Error.External_State)
    testing.expect_value(t, rawptr(raw_data(timeline.records)), records)
    testing.expect_value(t, host.ctx.tracker.current_memory_allocated, before)
    testing.expect_value(t, host.refs, refs)
    host.active = true
    testing.expect_value(t, r.advance(&timeline, f.Input{delta = 3, event = true}).error, r.Error.None)
    testing.expect_value(t, r.destroy(&timeline), r.Error.None)
    testing.expect_value(t, log.contexts_freed, u64(1))
    testing.expect_value(t, host.refs, u32(0))
}

@(test)
complete_cleanup_tombstone_retries_only_declined_final_owner_drop :: proc(t: ^testing.T) {
    testing.expect_value(t, r.owner_realm_install(73), r.Error.None)
    log: life.Log
    source := life.source_create(&log, 37)
    host: Owner_Host
    creator := create_owner(&host, source, false)
    stats: f.Stats
    base, base_owner := f.checkpoint(i64, &stats, 13)
    defer f.owner_destroy(&base_owner)
    defer r.complete_checkpoint_destroy(&base)
    external := base._external
    external.owner = creator
    external.owner_allocator_data = life.context_allocator(host.ctx).data
    image, ie := external.clone(base._image)
    testing.expect_value(t, ie, r.Error.None)
    events := []r.Occurrence(i64){{id = {epoch = 1, tick = 0, source = 1, key = 1}, value = 9}}
    checkpoint, ce := r.complete_checkpoint_adopt(
        base.frame,
        i64,
        external,
        image,
        base._image_bytes,
        1,
        events,
        life.context_allocator(host.ctx),
    )
    testing.expect_value(t, ce, r.Error.None)
    life.source_destroy(&source)
    testing.expect_value(t, r.owner_drop(&creator), r.Error.None)
    host.deny_drop = true
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.External_State)
    testing.expect(t, checkpoint._image == nil && len(checkpoint.events) == 0 && !r.owner_is_nil(checkpoint.owner))
    testing.expect_value(t, host.ctx.tracker.current_memory_allocated, i64(0))
    testing.expect_value(t, log.contexts_freed, u64(0))
    images := stats.images
    host.deny_drop = false
    testing.expect_value(t, r.complete_checkpoint_destroy(&checkpoint), r.Error.None)
    testing.expect_value(t, stats.images, images)
    testing.expect_value(t, log.contexts_freed, u64(1))
    testing.expect_value(t, host.refs, u32(0))
}
