//gd:extends Node
//gd:class Producer
package box3d_module_producer

import b "godot:box3d"
import gd "godot:godot"
import bg "godot:box3d/godot"
import ph "godot:replay/physics"
import r "godot:replay"
import meter "godot:box3d/godot/meter"
import kf "godot:tests/box3d_modules/kit/fixture"
import quota "godot:tests/box3d_modules/quota_fixture"
import "base:runtime"
import "core:mem"

Producer :: struct {
    owner:          gd.Node,
    world:          b.World,
    body:           b.Body,
    capsule:        bg.Capsule,
    kit_info:       kf.Factory_Info,
    quota:          quota.Context,
    borrowed_owner: bg.Owner,
}

Checkpoint_State :: struct {
    body: b.Body_Key,
}

Checkpoint_Event :: struct {
    kind: u32,
}

Weak_Payload :: struct {
    lifetime:  bg.Owner,
    allocator: mem.Allocator,
}

borrow_callback_calls: u64

borrow_retain :: proc "c" (user: rawptr) -> bg.Status {
    borrow_callback_calls += 1
    return bg.OK
}

borrow_drop :: proc "c" (user: rawptr) -> bg.Status {
    borrow_callback_calls += 1
    return bg.OK
}

RELOAD_BRAND :: #config(BOX3D_RELOAD_BRAND, 1)

@(gd_method)
producer_brand :: proc(self: ^Producer) -> gd.Int {
    return RELOAD_BRAND
}

@(gd_method)
producer_cookie :: proc(self: ^Producer) -> gd.Int {
    contract, status := b.domain_contract_get()
    return status == .Ok ? gd.Int(contract.cookie) : 0
}

@(gd_method)
producer_create :: proc(self: ^Producer) -> gd.Int {
    if self.world != 0 {
        return gd.Int(b.Status.Invalid_Argument)
    }

    status: b.Status
    self.world, status = b.world_create(b.world_def_default())

    if status != .Ok {
        return gd.Int(status)
    }

    def := b.body_def_default()
    def.type = .Dynamic
    def.pose.position = {0, 2, 0}
    self.body, status = b.body_create(self.world, def)

    if status != .Ok {
        b.world_destroy(&self.world)
        return gd.Int(status)
    }

    _, status = b.shape_box(self.body, b.shape_def_default(), {0.25, 0.25, 0.25})

    if status != .Ok {
        b.world_destroy(&self.world)
        self.body = 0
    }

    return gd.Int(status)
}

@(gd_method)
producer_world :: proc(self: ^Producer) -> gd.Int {
    return gd.Int(self.world)
}

@(gd_method)
producer_body_key :: proc(self: ^Producer) -> gd.Int {
    key, status := b.body_key(self.body)
    return status == .Ok ? gd.Int(key) : 0
}

@(gd_method)
producer_y :: proc(self: ^Producer) -> f64 {
    pose, status := b.body_get_pose(self.body)
    return status == .Ok ? f64(pose.position.y) : -10000
}

@(gd_method)
producer_clear :: proc(self: ^Producer) -> gd.Int {
    status := b.world_destroy(&self.world)

    if status == .Ok {
        self.body = 0
    }

    return gd.Int(status)
}

@(gd_method)
producer_capture :: proc(self: ^Producer) -> gd.Int {
    context.allocator = runtime.heap_allocator()

    if self.capsule.user != nil || self.world == 0 {
        return 1
    }

    service := bg.service_get()

    if service.realm == 0 {
        return 1
    }

    allocation_context, allocation_status := meter.create(service, bg.CATEGORY_REPLAY_CORE)

    if allocation_status != bg.OK {
        return gd.Int(allocation_status)
    }

    defer meter.destroy(&allocation_context)
    allocator := meter.allocator(allocation_context)
    owned, error := ph.owner_context_create(
        meter.data_lease(allocation_context),
        allocator_data = allocator.data,
        require_live_instance = false,
    )

    if error != .None {
        return 10 + gd.Int(error)
    }

    defer ph.owner_context_destroy(&owned)
    key, ks := b.body_key(self.body)

    if ks != .Ok {
        return gd.Int(ks)
    }

    cfg := ph.config_default(0x4d4f44554c455331, 1)
    cfg.initial_dynamic_bodies = 1
    cp, ce := ph.checkpoint_make(
        r.Frame(Checkpoint_State){state = {body = key}},
        Checkpoint_Event,
        self.world,
        cfg,
        allocator = allocator,
        ownership = owned,
    )

    if ce != .None {
        return 100 + gd.Int(ce)
    }

    defer r.complete_checkpoint_destroy(&cp)
    self.capsule, ce = ph.checkpoint_capsule_create(&cp, service, allocator)
    return ce == .None ? 0 : 200 + gd.Int(ce)
}

@(gd_method)
producer_capture_kit :: proc(self: ^Producer) -> gd.Int {
    if self.capsule.user != nil {
        return 1
    }

    return gd.Int(kf.create(&self.capsule, &self.kit_info))
}

@(gd_method)
producer_kit_key :: proc(self: ^Producer) -> gd.Int {
    return gd.Int(self.kit_info.key)
}

@(gd_method)
producer_kit_sources :: proc(self: ^Producer) -> gd.Int {
    return gd.Int(self.kit_info.source_objects_live)
}

@(gd_method)
producer_quota_init :: proc(self: ^Producer) -> gd.Int {
    return gd.Int(quota.init(&self.quota, self.world, 11))
}

@(gd_method)
producer_quota_allocate :: proc(self: ^Producer, bytes: gd.Int) -> gd.Int {
    return gd.Int(quota.allocate(&self.quota, u64(bytes)))
}

@(gd_method)
producer_quota_probe :: proc(self: ^Producer) -> bool {
    return quota.probe(&self.quota)
}

@(gd_method)
producer_quota_clear :: proc(self: ^Producer) -> gd.Int {
    return gd.Int(quota.destroy(&self.quota))
}

@(gd_method)
producer_reject_borrowed_self :: proc(self: ^Producer) -> gd.Int {
    service := bg.service_get()
    data := bg.Data_Lease{self, borrow_retain, borrow_drop}
    owner: bg.Owner
    status := service.owner_create(service.user, 0, &data, &owner)

    if status == bg.OK {
        owner.drop(owner.user)
    }

    if borrow_callback_calls != 0 {
        return -1
    }

    return gd.Int(status)
}

@(gd_method = "owned_return")
producer_owner_packet :: proc(self: ^Producer) -> gd.Packed_Byte_Array {
    result := gd.new_packed_byte_array()
    service := bg.service_get()

    if self.borrowed_owner.user == nil {
        data: bg.Data_Lease

        if service.owner_create(service.user, 0, &data, &self.borrowed_owner) != bg.OK {
            return result
        }
    }

    gd.packed_byte_array_resize(&result, size_of(bg.Owner))
    bytes := transmute([size_of(bg.Owner)]u8)self.borrowed_owner
    copy(gd.packed_byte_array_view(&result), bytes[:])
    return result
}

@(gd_method)
producer_capture_weak :: proc(self: ^Producer) -> gd.Int {
    if self.capsule.user != nil {
        return 1
    }

    service := bg.service_get()
    ctx, status := meter.create(service, bg.CATEGORY_REPLAY_CORE)

    if status != bg.OK {
        return gd.Int(status)
    }

    defer meter.destroy(&ctx)
    data := meter.data_lease(ctx)
    owner: bg.Owner

    if status = service.owner_create(service.user, 1, &data, &owner); status != bg.OK {
        return gd.Int(status)
    }

    defer owner.drop(owner.user)
    allocator := meter.allocator(ctx)
    payload, error := new(Weak_Payload, allocator)

    if error != nil {
        return gd.Int(bg.CAPACITY)
    }

    payload^ = {owner, allocator}

    dispatch := proc "c" (pointer: rawptr, operation: u32, args: rawptr) -> bg.Status {
        context = runtime.default_context()
        p := cast(^Weak_Payload)pointer

        if status := p.lifetime.check(p.lifetime.user, bg.READ); status != bg.OK {
            return status
        }

        switch operation {
        case bg.CAPSULE_DESTROY:
            allocator := p.allocator
            free(p, allocator)
            return bg.OK
        case 2:
            return p.lifetime.check(p.lifetime.user, bg.READ)
        case 3:
            return p.lifetime.check(p.lifetime.user, bg.EXECUTE)
        case:
            return bg.UNSUPPORTED
        }
    }

    status = service.capsule_create(service.user, &owner, payload, dispatch, &self.capsule)

    if status != bg.OK {
        free(payload, allocator)
    }

    return gd.Int(status)
}

// Test-only C-shaped, process-local POD transfer. This is not network/recovery
// bytes. Taking the packet moves one capsule owner; assignment never clones it.
@(gd_method = "owned_return")
producer_take_capsule :: proc(self: ^Producer) -> gd.Packed_Byte_Array {
    result := gd.new_packed_byte_array()

    if self.capsule.user == nil {
        return result
    }

    gd.packed_byte_array_resize(&result, size_of(bg.Capsule))
    view := gd.packed_byte_array_view(&result)
    bytes := transmute([size_of(bg.Capsule)]u8)self.capsule
    copy(view, bytes[:])
    self.capsule = {}
    return result
}

producer_exit_tree :: proc(self: ^Producer) {
    if self.borrowed_owner.user != nil {
        self.borrowed_owner.drop(self.borrowed_owner.user)
        self.borrowed_owner = {}
    }

    quota.destroy(&self.quota)

    if self.capsule.user != nil {
        self.capsule.destroy(self.capsule.user)
        self.capsule = {}
    }

    if self.world != 0 {
        b.world_destroy(&self.world)
    }
}
