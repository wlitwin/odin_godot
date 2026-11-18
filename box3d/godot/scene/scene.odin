// A local fixed-step world with automatic presentation bindings. No Kit/Replay
// clock, callback lease, checkpoint, or networking policy belongs to this owner.
package box3d_godot_scene

import "core:fmt"
import "core:math"
import "core:mem"
import b "godot:box3d"
import a "godot:box3d/authoring"
import ar "godot:box3d/authoring/runtime"
import ga "godot:box3d/godot/authoring"
import gd "godot:godot"
import "godot:gdext"

Scene :: struct {
    _source:   u64,
    _revision: u64,
    _initial:  a.Baked_Scene,
    _runtime:  ar.Built_Scene,
    _bindings: []Binding,
    _poses:    []gd.Transform3d,
    _allocator: mem.Allocator,
}

@(private)
Binding :: struct {
    node, parent_body: u64,
    body_index:        int,
}

Error :: enum { None, Authoring, Build, Binding, Timing, Allocation, Native, Interrupted }
Diagnostic :: struct {
    error:         Error,
    native_status: b.Status,
    authoring:     ga.Diagnostic,
    bake:          a.Diagnostic,
}

diagnostic_destroy :: proc(d: ^Diagnostic) {
    if d != nil { ga.diagnostic_destroy(&d.authoring); d^ = {} }
}

// Returned text belongs to the current temporary allocator.
describe :: proc(d: Diagnostic) -> string {
    switch d.error {
    case .None: return ""
    case .Interrupted: return "Physics presentation was interrupted by scene reset or destruction."
    case .Authoring:
        if len(d.authoring.authoring_errors_json) > 0 {
            return fmt.tprintf("Invalid physics content: %s", string(d.authoring.authoring_errors_json))
        }
        return fmt.tprintf("Cannot read physics content: %v / %v at %s", d.authoring.error, d.authoring.bake_diagnostic.error, d.authoring.bake_diagnostic.field)
    case .Build: return fmt.tprintf("Cannot create physics: %v at %s (%v)", d.bake.error, d.bake.field, d.bake.native_status)
    case .Binding: return "Physics presentation changed: keep bound body nodes in their captured World and body hierarchy, with finite rigid transforms."
    case .Timing: return fmt.tprintf("Set physics/common/physics_ticks_per_second to %d for this Box3D timing profile.", b.FIXED_HZ)
    case .Allocation: return "Cannot allocate the authored physics scene."
    case .Native: return fmt.tprintf("Box3D operation failed: %v", d.native_status)
    }
    return ""
}

@(private)
allocate :: proc($T: typeid, count: int, allocator: mem.Allocator) -> ([]T, bool) {
    if count == 0 { return nil, true }
    bytes, error := mem.alloc_bytes(count * size_of(T), align_of(T), allocator)
    if error != .None { return nil, false }
    for &value in bytes { value = 0 }
    return (cast([^]T)raw_data(bytes))[:count], true
}

@(private)
node_for_id :: proc(id: u64) -> gd.Node3d {
    if id == 0 { return nil }
    return cast(gd.Node3d)gdext.object_get_instance_from_id(gdext.ObjectInstanceId(id))
}

@(private)
rigid :: proc(t: gd.Transform3d) -> bool {
    t := t
    if !gd.transform3d_is_finite(&t) { return false }
    for row in 0 ..< 3 {
        for other in 0 ..< 3 {
            dot := f32(0)
            for c in 0 ..< 3 { dot += t.basis[row][c] * t.basis[other][c] }
            expected := row == other ? f32(1) : f32(0)
            if math.abs(dot - expected) > 0.001 { return false }
        }
    }
    return gd.basis_determinant(&t.basis) > 0
}

// A plain Node can break transform inheritance, but never World membership.
// Capturing the nearest body ancestor also detects reorderings that would make
// parent-before-child publication invalid after a runtime reparent.
@(private)
parent_body :: proc(node: gd.Node, source: gd.Node) -> (u64, bool) {
    found := u64(0)
    current := gd.node_get_parent(node)
    for _ in 0 ..< 4096 {
        if current == source { return found, true }
        if current == nil || gd.object_has_method(current, gd.sname("box3d_definition")) { return 0, false }
        if found == 0 && gd.object_has_method(current, gd.sname("box3d_body_header")) {
            found = gd.object_get_instance_id(current)
        }
        current = gd.node_get_parent(current)
    }
    return 0, false
}

@(private)
validate_bindings :: proc(scene: ^Scene) -> Diagnostic {
    if scene == nil { return {error = .Binding} }
    source := node_for_id(scene._source)
    if source == nil || !gd.node_is_inside_tree(source) || !rigid(gd.node3d_get_global_transform(source)) {
        return {error = .Binding}
    }
    for binding in scene._bindings {
        node := node_for_id(binding.node)
        if node == nil || !gd.node_is_inside_tree(node) || !rigid(gd.node3d_get_global_transform(node)) {
            return {error = .Binding}
        }
        parent, scoped := parent_body(node, source)
        if !scoped || parent != binding.parent_body { return {error = .Binding} }
    }
    return {}
}

// Call once while the authored World is in the tree. Keep this owner through
// temporary exit/re-entry; destroy it in the owning script's finalize hook.
// Even a failed open can return retained native ownership: always destroy it.
open :: proc(source: gd.Node3d, allocator := context.allocator) -> (scene: Scene, problem: Diagnostic) {
    scene._allocator = allocator
    if source == nil || !gd.node_is_inside_tree(source) { return scene, {error = .Binding} }
    if gd.engine_get_physics_ticks_per_second(gd.singleton_engine()) != b.FIXED_HZ {
        return scene, {error = .Timing}
    }
    scene._source = gd.object_get_instance_id(source)
    extracted: ga.Diagnostic
    scene._initial, extracted = ga.extract(source, allocator)
    if extracted.error != .None { return scene, {error = .Authoring, authoring = extracted} }
    ga.diagnostic_destroy(&extracted)
    ok: bool
    scene._bindings, ok = allocate(Binding, len(scene._initial.data.bodies), allocator)
    if !ok { return scene, {error = .Allocation} }
    scene._poses, ok = allocate(gd.Transform3d, len(scene._bindings), allocator)
    if !ok { return scene, {error = .Allocation} }
    class_name := gd.sname("Node3D")
    pending: [4096]gd.Node
    pending[0] = source
    count, visited, bound := 1, 0, 0
    for count > 0 {
        count -= 1
        node := pending[count]
        visited += 1
        if visited > len(pending) { return scene, {error = .Binding} }
        if node != source && gd.object_has_method(node, gd.sname("box3d_definition")) { continue }
        if gd.object_has_method(node, gd.sname("box3d_body_header")) {
            if !gd.object_is_class(node, class_name) || bound >= len(scene._bindings) { return scene, {error = .Binding} }
            key := gd.get_string(node, "stable_key", context.temp_allocator)
            index := -1
            for body, i in scene._initial.data.bodies {
                if body.stable_key == key { index = i; break }
            }
            if index < 0 { return scene, {error = .Binding} }
            for existing in scene._bindings[:bound] {
                if existing.body_index == index { return scene, {error = .Binding} }
            }
            parent, scoped := parent_body(node, source)
            if !scoped { return scene, {error = .Binding} }
            scene._bindings[bound] = {gd.object_get_instance_id(node), parent, index}
            bound += 1
        }
        children := int(gd.node_get_child_count(node, false))
        if children > len(pending) - count { return scene, {error = .Binding} }
        // Stack reverse order gives the original tree's parent-before-child order.
        for i := children - 1; i >= 0; i -= 1 {
            pending[count] = gd.node_get_child(node, i64(i), false)
            count += 1
        }
    }
    if bound != len(scene._bindings) { return scene, {error = .Binding} }
    if problem = validate_bindings(&scene); problem.error != .None { return }
    scene._runtime, problem.bake = ar.build(&scene._initial, a.content_id64(&scene._initial))
    if problem.bake.error != .None { problem.error = .Build }
    scene._revision = 1
    // Authored nodes already have the initial poses. Avoid publishing transforms
    // before the caller has installed this returned owner in its own storage.
    return
}

@(private)
pose_transform :: proc(pose: b.Pose) -> gd.Transform3d {
    x, y, z, w := pose.rotation.x, pose.rotation.y, pose.rotation.z, pose.rotation.w
    return {
        basis = {
            {1 - 2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)},
            {2*(x*y+z*w), 1 - 2*(x*x+z*z), 2*(y*z-x*w)},
            {2*(x*z-y*w), 2*(y*z+x*w), 1 - 2*(x*x+y*y)},
        },
        origin = {pose.position.x, pose.position.y, pose.position.z},
    }
}

@(private)
sync_poses :: proc(scene: ^Scene, cut: bool) -> Diagnostic {
    source := node_for_id(scene._source)
    if source == nil { return {error = .Binding} }
    frame := gd.node3d_get_global_transform(source)
    revision, native_world := scene._revision, scene._runtime.world
    for binding, i in scene._bindings {
        pose, status := b.body_get_pose(scene._runtime.bodies[binding.body_index].handle)
        if status != .Ok { return {error = .Native, native_status = status} }
        scene._poses[i] = gd.transform3d_multiply_transform3d(frame, pose_transform(pose))
        if !rigid(scene._poses[i]) { return {error = .Binding} }
    }
    for binding, i in scene._bindings {
        node := node_for_id(binding.node)
        if node == nil { return {error = .Binding} }
        gd.node3d_set_global_transform(node, scene._poses[i])
        // Engine transform notifications can synchronously remove the owning
        // script. Core pins its storage while this callback runs, but finalize
        // can already have released these slices and the native world.
        if scene._revision != revision || scene._runtime.world != native_world { return {error = .Interrupted} }
        if cut {
            node = node_for_id(binding.node)
            if node == nil { return {error = .Binding} }
            gd.node_reset_physics_interpolation(node)
            if scene._revision != revision || scene._runtime.world != native_world { return {error = .Interrupted} }
        }
    }
    return {}
}

// Reset only from the captured bake, never from nodes moved by the simulation.
// Failure leaves a destroyable/retryable owner. Native destruction is checked
// before replacing it, so denied cleanup cannot lose the original handles.
reset :: proc(scene: ^Scene) -> Diagnostic {
    if problem := validate_bindings(scene); problem.error != .None { return problem }
    if status := ar.built_destroy(&scene._runtime); status != .Ok { return {error = .Native, native_status = status} }
    problem: a.Diagnostic
    scene._runtime, problem = ar.build(&scene._initial, a.content_id64(&scene._initial))
    if problem.error != .None { return {error = .Build, bake = problem} }
    scene._revision += 1
    return sync_poses(scene, true)
}

step_fixed :: proc(scene: ^Scene) -> Diagnostic {
    if gd.engine_get_physics_ticks_per_second(gd.singleton_engine()) != b.FIXED_HZ { return {error = .Timing} }
    if problem := validate_bindings(scene); problem.error != .None { return problem }
    if status := b.world_step_fixed(scene._runtime.world); status != .Ok { return {error = .Native, native_status = status} }
    scene._revision += 1
    return sync_poses(scene, false)
}

// Resolve an authored node to its current handle after any number of resets.
// Use the handle for gameplay forces/queries; this owner retains its lifetime.
body_for_node :: proc(scene: ^Scene, node: gd.Node3d) -> (b.Body, bool) {
    if scene == nil || node == nil { return 0, false }
    for binding in scene._bindings {
        // The caller may hold an onready pointer whose node was freed. Resolve
        // our weak ID first; never dereference the supplied raw pointer.
        if node_for_id(binding.node) == node && binding.body_index < len(scene._runtime.bodies) {
            handle := scene._runtime.bodies[binding.body_index].handle
            return handle, handle != 0
        }
    }
    return 0, false
}

destroy :: proc(scene: ^Scene) -> b.Status {
    if scene == nil { return .Ok }
    if status := ar.built_destroy(&scene._runtime); status != .Ok { return status }
    if scene._initial.data.schema_version != 0 { a.destroy(&scene._initial) }
    delete(scene._bindings, scene._allocator)
    delete(scene._poses, scene._allocator)
    scene^ = {}
    return .Ok
}
