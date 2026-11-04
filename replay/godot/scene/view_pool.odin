package replay_godot_scene

import "core:mem"
import "core:math"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import d "godot:replay/definitions"

View_Binding :: struct($Value, $Rig: typeid) {
    user:     rawptr,
    attach:   proc(user: rawptr, node: gd.Node2d) -> (Rig, bool),
    paint:    proc(user: rawptr, rig: ^Rig, value: Value),
    detach:   proc(user: rawptr, rig: ^Rig),
    frame:    proc(user: rawptr, rig: ^Rig, value: Value, dt: f64),
    diagnose: proc(_: rawptr) -> d.Report,
}

View_Pool_Error :: enum {
    None,
    Invalid,
    Capacity,
    Duplicate,
    Attach,
    Scene,
}

@(private)
View_Pool_Entry :: struct($Value, $Rig: typeid) {
    key:     u64,
    node:    gd.Node2d,
    rig:     Rig,
    last:    Value,
    painted: bool,
}

// One simulation pool per view owner. Value must be detached/value-safe; Rig may
// borrow Godot child nodes and own presentation resources through detach.
View_Pool2 :: struct($Entity, $Value, $Rig: typeid) {
    nodes:                  Nodes2,
    binding:                View_Binding(Value, Rig),
    entries:                []View_Pool_Entry(Value, Rig),
    instances:              []Instance2,
    index, desired:         v.Key_Index,
    free_slots:             []int,
    scope:                  v.View_Scope,
    scoped:                 bool,
    paints, skipped_paints: u64,
    problem:                d.Report,
    allocator:              mem.Allocator,
}

view_pool_init :: proc(
    p: ^View_Pool2($Entity, $Value, $Rig),
    parent: gd.Node,
    scene: gd.Packed_Scene,
    capacity: int,
    binding: View_Binding(Value, Rig),
    allocator := context.allocator,
) -> bool {
    if len(p.entries) != 0 ||
       !r.value_supported(Entity) ||
       !r.value_supported(Value) ||
       binding.attach == nil ||
       binding.paint == nil {
        return false
    }

    p.allocator, p.binding = allocator, binding

    if !nodes_init(&p.nodes, parent, scene, capacity, allocator) {
        return false
    }

    if !v.key_index_init(&p.index, capacity, allocator) || !v.key_index_init(&p.desired, capacity, allocator) {
        view_pool_destroy(p)
        return false
    }

    p.entries = make([]View_Pool_Entry(Value, Rig), capacity, allocator)
    p.instances = make([]Instance2, capacity, allocator)
    p.free_slots = make([]int, capacity, allocator)
    p.nodes.cache_properties = true
    return true
}

view_pool_load :: proc(
    p: ^View_Pool2($Entity, $Value, $Rig),
    parent: gd.Node,
    path: cstring,
    capacity: int,
    binding: View_Binding(Value, Rig),
    allocator := context.allocator,
) -> bool {
    scene := gd.load_scene(path)

    if scene == nil {
        return false
    }

    defer release_scene(scene)
    return view_pool_init(p, parent, scene, capacity, binding, allocator)
}

view_pool_clear :: proc(p: ^View_Pool2($Entity, $Value, $Rig)) {
    for &entry in p.entries {
        if entry.node != nil && p.binding.detach != nil {
            p.binding.detach(p.binding.user, &entry.rig)
        }

        entry = {}
    }

    nodes_clear(&p.nodes)
    v.key_index_clear(&p.index)
    v.key_index_clear(&p.desired)
    p.scoped = false
    p.scope = {}
}

view_pool_destroy :: proc(p: ^View_Pool2($Entity, $Value, $Rig)) {
    view_pool_clear(p)
    nodes_destroy(&p.nodes)
    v.key_index_destroy(&p.index)
    v.key_index_destroy(&p.desired)
    delete(p.entries, p.allocator)
    delete(p.instances, p.allocator)
    delete(p.free_slots, p.allocator)
    p^ = {}
}

// Full preflight before scope/lifetime changes. Replaced scopes discard bindings
// even if the numeric handles repeat. Attach runs once per new view, not per frame.
view_pool_present :: proc(
    p: ^View_Pool2($Entity, $Value, $Rig),
    scope: v.View_Scope,
    items: []v.View_Item(Entity, Value),
) -> View_Pool_Error {
    p.problem = {}

    if len(p.entries) == 0 || scope.epoch == 0 || (p.scoped && scope.epoch < p.scope.epoch) {
        return view_pool_fail(p, .Invalid, 0)
    }

    if len(items) > len(p.entries) {
        return view_pool_fail(p, .Capacity, 0)
    }

    v.key_index_clear(&p.desired)
    retained := p.scoped && p.scope == scope && len(items) == p.nodes.count

    for item, i in items {
        key := v.handle_key(item.handle)

        if key == 0 || !v.entity_view_valid(item.view) || item.source > .Authoritative {
            return view_pool_fail(p, .Invalid, key)
        }

        if v.key_index_put(&p.desired, key, i) != .None {
            return view_pool_fail(p, .Duplicate, key)
        }

        if retained {
            if _, found := v.key_index_get(&p.index, key); !found {
                retained = false
            }
        }

        p.instances[i] = {
            key   = key,
            pose  = item.view.pose,
            scale = item.view.scale,
            color = gd.Color(item.view.color),
        }
    }

    if retained {
        if !nodes_present(&p.nodes, p.instances[:len(items)]) {
            view_pool_clear(p)
            return view_pool_fail(p, .Scene, 0)
        }

        for item in items {
            at, found := v.key_index_get(&p.index, v.handle_key(item.handle))
            assert(found)
            view_pool_paint(p, &p.entries[at], item.view.value)
        }

        return .None
    }

    if p.scoped && p.scope != scope {
        // Clear invalidates the scratch desired index too; restore it below.
        view_pool_clear(p)

        for item, i in items {
            result := v.key_index_put(&p.desired, v.handle_key(item.handle), i)
            assert(result == .None)
        }
    }

    p.scope, p.scoped = scope, true

    for &entry in p.entries {
        if entry.node == nil {
            continue
        }

        if _, found := v.key_index_get(&p.desired, entry.key); !found {
            if p.binding.detach != nil {
                p.binding.detach(p.binding.user, &entry.rig)
            }

            entry = {}
        }
    }

    if !nodes_present(&p.nodes, p.instances[:len(items)]) {
        view_pool_clear(p)
        return view_pool_fail(p, .Scene, 0)
    }

    v.key_index_clear(&p.index)
    free_count := 0

    for offset in 0 ..< len(p.entries) {
        i := len(p.entries) - 1 - offset
        entry := &p.entries[i]

        if entry.node == nil {
            p.free_slots[free_count] = i
            free_count += 1
        } else {
            result := v.key_index_put(&p.index, entry.key, i)
            assert(result == .None)
        }
    }

    for item in items {
        key := v.handle_key(item.handle)
        slot, found := v.key_index_get(&p.index, key)

        if !found {
            free_count -= 1
            slot = p.free_slots[free_count]
            node, exists := nodes_get(&p.nodes, key)
            assert(exists)
            rig, ok := p.binding.attach(p.binding.user, node)

            if !ok {
                detail: d.Report

                if p.binding.diagnose != nil {
                    detail = p.binding.diagnose(p.binding.user)
                }

                if p.binding.detach != nil {
                    p.binding.detach(p.binding.user, &rig)
                }

                view_pool_clear(p)
                return view_pool_fail(p, .Attach, key, detail)
            }

            p.entries[slot] = {
                key  = key,
                node = node,
                rig  = rig,
            }
            result := v.key_index_put(&p.index, key, slot)
            assert(result == .None)
        }

        entry := &p.entries[slot]
        view_pool_paint(p, entry, item.view.value)
    }

    return .None
}

view_pool_get :: proc(
    p: ^View_Pool2($Entity, $Value, $Rig),
    handle: r.Handle(Entity),
) -> (
    node: gd.Node2d,
    found: bool,
) {
    return nodes_get(&p.nodes, v.handle_key(handle))
}

view_pool_invalidate :: proc {
    view_pool_invalidate_all,
    view_pool_invalidate_one,
}

@(private)
view_pool_invalidate_all :: proc(p: ^View_Pool2($Entity, $Value, $Rig)) {
    nodes_invalidate(&p.nodes)

    for &entry in p.entries {
        entry.painted = false
    }
}

@(private)
view_pool_invalidate_one :: proc(p: ^View_Pool2($Entity, $Value, $Rig), handle: r.Handle(Entity)) {
    key := v.handle_key(handle)
    nodes_invalidate(&p.nodes, key)

    if key == 0 {
        for &entry in p.entries {
            entry.painted = false
        }
    } else if slot, found := v.key_index_get(&p.index, key); found {
        p.entries[slot].painted = false
    }
}

@(private)
view_pool_paint :: proc(p: ^View_Pool2($Entity, $Value, $Rig), entry: ^View_Pool_Entry(Value, Rig), value: Value) {
    if !entry.painted || !reflect.equal(entry.last, value) {
        p.binding.paint(p.binding.user, &entry.rig, value)
        entry.last, entry.painted = value, true
        p.paints += 1
    } else {
        p.skipped_paints += 1
    }
}

// Presentation time belongs to the rig, not its detached data. Call once after
// present; unchanged values may skip paint while child animation keeps running.
// This hook owns child properties only, and must not reenter this view owner.
view_pool_frame :: proc(p: ^View_Pool2($Entity, $Value, $Rig), dt: f64) -> bool {
    if len(p.entries) == 0 || dt < 0 || math.is_nan(dt) || math.is_inf(dt) {
        return false
    }

    if p.binding.frame == nil {
        return true
    }

    for bucket in p.index.occupied[:p.index.count] {
        entry := &p.entries[p.index.values[bucket]]
        p.binding.frame(p.binding.user, &entry.rig, entry.last, dt)
    }

    return true
}
