//gd:extends Node
//gd:class PhysicsLifetime
package physics_lifetime

import "base:runtime"
import "core:mem"
import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import b "godot:box3d"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"

PhysicsLifetime :: struct {
    owner:    gd.Node,
    world:    b.World,
    snapshot: b.Snapshot,
}

Payload :: struct {
    allocator: mem.Allocator,
    owner:     bg.Owner,
}

saved: b.Snapshot
capsule: bg.Capsule
finals, closed: int
expected_digest: u64

dispatch :: proc "c" (user: rawptr, operation: u32, _: rawptr) -> bg.Status {
    context = runtime.default_context()
    p := cast(^Payload)user

    switch operation {
    case bg.CAPSULE_DESTROY:
        allocator := p.allocator
        free(p, allocator)
        return bg.OK
    case 2:
        return p.owner.check(p.owner.user, bg.READ)
    case 3:
        return p.owner.check(p.owner.user, bg.EXECUTE)
    }

    return bg.UNSUPPORTED
}

@(gd_method)
physics_lifetime_open :: proc(self: ^PhysicsLifetime) -> bool {
    status: b.Status
    self.world, status = b.world_create(b.world_def_default())

    if status != .Ok {
        return false
    }

    self.snapshot, status = b.snapshot_capture(self.world)

    if status != .Ok {
        return false
    }

    saved, status = b.snapshot_clone(&self.snapshot)

    if status != .Ok {
        return false
    }

    digests, ds := b.snapshot_digests(&saved)

    if ds != .Ok {
        return false
    }

    expected_digest = digests.complete_solver_digest
    service := bg.service_get()
    ctx, cs := meter.create(service, bg.CATEGORY_REPLAY_CORE)

    if cs != bg.OK {
        return false
    }

    defer meter.destroy(&ctx)
    lease := meter.data_lease(ctx)
    owner: bg.Owner

    if service.owner_create(service.user, 1, &lease, &owner) != bg.OK {
        return false
    }

    defer owner.drop(owner.user)
    allocator := meter.allocator(ctx)
    p, err := new(Payload, allocator)

    if err != nil {
        return false
    }

    p^ = {allocator, owner}

    if service.capsule_create(service.user, &owner, p, dispatch, &capsule) != bg.OK {
        free(p, allocator)
        return false
    }

    return capsule.invoke(capsule.user, 3, nil) == bg.OK
}

physics_lifetime_finalize :: proc(self: ^PhysicsLifetime) {
    if self.world == 0 {
        return
    }

    finals += 1

    if capsule.invoke(capsule.user, 3, nil) != bg.OK {
        gd.print_str("PHYSICS_FINALIZE_BAD_CONTEXT")
        return
    }

    if b.snapshot_destroy(&self.snapshot) != .Ok || b.world_destroy(&self.world) != .Ok {
        gd.print_str("PHYSICS_FINALIZE_BAD_CLOSE")
        return
    }

    self.world = 0
    closed += 1
}

@(gd_method)
physics_lifetime_verify :: proc(self: ^PhysicsLifetime, negative: bool) -> bool {
    if finals != (negative ? 0 : 1) || closed != (negative ? 0 : 1) {
        return false
    }

    if capsule.invoke(capsule.user, 3, nil) != bg.INVALID_HANDLE || capsule.invoke(capsule.user, 2, nil) != bg.OK {
        return false
    }

    digests, ds := b.snapshot_digests(&saved)

    if ds != .Ok || digests.complete_solver_digest != expected_digest {
        return false
    }

    world, status := b.world_create(b.world_def_default())

    if status != .Ok {
        return false
    }

    defer b.world_destroy(&world)

    if b.snapshot_restore(world, &saved) != .Ok {
        return false
    }

    clone, cs := b.snapshot_clone(&saved)

    if cs != .Ok {
        return false
    }

    if b.snapshot_destroy(&clone) != .Ok {
        return false
    }

    return true
}

@(gd_method)
physics_lifetime_close_globals :: proc(self: ^PhysicsLifetime) -> bool {
    ok := capsule.destroy(capsule.user) == bg.OK && b.snapshot_destroy(&saved) == .Ok
    capsule = {}
    return ok
}
