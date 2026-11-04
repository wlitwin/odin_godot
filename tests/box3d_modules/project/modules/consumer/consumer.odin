//gd:extends Node
//gd:class Consumer
package box3d_module_consumer

import b "godot:box3d"
import gd "godot:godot"
import bg "godot:box3d/godot"
import ph "godot:replay/physics"
import kp "godot:kit/physics"
import quota "godot:tests/box3d_modules/quota_fixture"
import r "godot:replay"

Consumer :: struct {
    owner:          gd.Node,
    capsule, clone: bg.Capsule,
    target:         b.World,
    kit:            bool,
    quota:          quota.Context,
}

@(gd_method)
consumer_native_images :: proc(self: ^Consumer) -> gd.Int {
    return gd.Int(native_image_count())
}

@(gd_method)
consumer_cookie :: proc(self: ^Consumer) -> gd.Int {
    contract, status := b.domain_contract_get()
    return status == .Ok ? gd.Int(contract.cookie) : 0
}

@(gd_method)
consumer_step :: proc(self: ^Consumer, world: gd.Int) -> gd.Int {
    return gd.Int(b.world_step_fixed(b.World(world)))
}

@(gd_method)
consumer_y :: proc(self: ^Consumer, world, key: gd.Int) -> f64 {
    body, status := b.body_resolve(b.World(world), b.Body_Key(key))

    if status != .Ok {
        return -10000
    }

    pose, pose_status := b.body_get_pose(body)
    return pose_status == .Ok ? f64(pose.position.y) : -10000
}

@(gd_method)
consumer_accept_capsule :: proc(self: ^Consumer, packet: gd.Packed_Byte_Array) -> bool {
    packet := packet
    view := gd.packed_byte_array_view(&packet)

    if len(view) != size_of(bg.Capsule) || self.capsule.user != nil {
        return false
    }

    bytes: [size_of(bg.Capsule)]u8
    copy(bytes[:], view)
    value := transmute(bg.Capsule)bytes

    if value.user == nil || value.invoke == nil || value.destroy == nil || value.realm == 0 {
        return false
    }

    self.capsule = value
    return true
}

@(gd_method)
consumer_accept_kit_capsule :: proc(self: ^Consumer, packet: gd.Packed_Byte_Array) -> bool {
    if !consumer_accept_capsule(self, packet) {
        return false
    }

    self.kit = true
    return true
}

@(gd_method)
consumer_foreign_owner_rejected :: proc(self: ^Consumer, packet: gd.Packed_Byte_Array) -> bool {
    packet := packet
    view := gd.packed_byte_array_view(&packet)

    if len(view) != size_of(bg.Owner) {
        return false
    }

    bytes: [size_of(bg.Owner)]u8
    copy(bytes[:], view)
    owner := transmute(bg.Owner)bytes
    return r.owner_access(owner) != .None
}

@(gd_method)
consumer_weak_read :: proc(self: ^Consumer) -> gd.Int {
    return gd.Int(self.capsule.invoke(self.capsule.user, 2, nil))
}

@(gd_method)
consumer_weak_execute :: proc(self: ^Consumer) -> gd.Int {
    return gd.Int(self.capsule.invoke(self.capsule.user, 3, nil))
}

@(gd_method)
consumer_capsule_y :: proc(self: ^Consumer, key: gd.Int) -> f64 {
    if self.capsule.user == nil {
        return -10000
    }

    if self.kit {
        state: b.Body_State
        args := kp.SDK_Checkpoint_Body_Args {
            key   = u64(key),
            state = &state,
        }
        status := self.capsule.invoke(self.capsule.user, 17, &args)
        return status == bg.OK ? f64(state.pose.position.y) : -10000
    }

    state: b.Body_State
    args := ph.Capsule_Body_State_Args{b.Body_Key(key), &state}
    status := self.capsule.invoke(self.capsule.user, ph.PHYSICS_CAPSULE_BODY_STATE, &args)
    return status == bg.OK ? f64(state.pose.position.y) : -10000
}

@(gd_method)
consumer_clone_capsule :: proc(self: ^Consumer) -> gd.Int {
    if self.capsule.user == nil || self.clone.user != nil {
        return 1
    }

    args := bg.Capsule_Clone_Args{&self.clone}
    return gd.Int(self.capsule.invoke(self.capsule.user, bg.CAPSULE_CLONE, &args))
}

@(gd_method)
consumer_release_capsules :: proc(self: ^Consumer) -> gd.Int {
    if self.clone.user != nil {
        status := self.clone.destroy(self.clone.user)

        if status != bg.OK {
            return gd.Int(status)
        }

        self.clone = {}
    }

    if self.capsule.user != nil {
        status := self.capsule.destroy(self.capsule.user)

        if status != bg.OK {
            return gd.Int(status)
        }

        self.capsule = {}
    }

    return 0
}

@(gd_method)
consumer_restore_target :: proc(self: ^Consumer) -> gd.Int {
    if self.target != 0 || self.capsule.user == nil {
        return 1
    }

    status: b.Status
    self.target, status = b.world_create(b.world_def_default())

    if status != .Ok {
        return gd.Int(status)
    }

    args := ph.Capsule_Native_Restore_Args {
        world = self.target,
    }
    result := self.capsule.invoke(self.capsule.user, ph.PHYSICS_CAPSULE_NATIVE_RESTORE, &args)

    if result != bg.OK {
        b.world_destroy(&self.target)
    }

    return gd.Int(result)
}

@(gd_method)
consumer_target_y :: proc(self: ^Consumer, key: gd.Int) -> f64 {
    return consumer_y(self, gd.Int(self.target), key)
}

@(gd_method)
consumer_target_step :: proc(self: ^Consumer) -> gd.Int {
    return gd.Int(b.world_step_fixed(self.target))
}

@(gd_method)
consumer_clear_target :: proc(self: ^Consumer) -> gd.Int {
    return gd.Int(b.world_destroy(&self.target))
}

@(gd_method)
consumer_quota_init :: proc(self: ^Consumer) -> gd.Int {
    if self.target != 0 {
        return 1
    }

    status: b.Status
    self.target, status = b.world_create(b.world_def_default())

    if status != .Ok {
        return gd.Int(status)
    }

    return gd.Int(quota.init(&self.quota, self.target, 22))
}

@(gd_method)
consumer_quota_allocate :: proc(self: ^Consumer, bytes: gd.Int) -> gd.Int {
    return gd.Int(quota.allocate(&self.quota, u64(bytes)))
}

@(gd_method)
consumer_quota_extra :: proc(self: ^Consumer) -> gd.Int {
    return gd.Int(quota.allocate(&self.quota, 1, 1))
}

@(gd_method)
consumer_quota_probe :: proc(self: ^Consumer) -> bool {
    return quota.probe(&self.quota)
}

@(gd_method)
consumer_quota_clear :: proc(self: ^Consumer) -> gd.Int {
    return gd.Int(quota.destroy(&self.quota))
}

@(gd_method)
consumer_admitted :: proc(self: ^Consumer) -> gd.Int {
    n, s := quota.admitted()
    return s == bg.OK ? gd.Int(n) : -1
}

consumer_exit_tree :: proc(self: ^Consumer) {
    quota.destroy(&self.quota)
    _ = consumer_release_capsules(self)

    if self.target != 0 {
        b.world_destroy(&self.target)
    }
}
