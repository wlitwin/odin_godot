package replay_godot_scene

import "core:mem"
import gd "godot:godot"
import "godot:gdext"
import view "godot:replay/view"

Instance2 :: struct {
    key:   u64,
    pose:  view.Pose2,
    scale: [2]f32,
    color: gd.Color,
}

@(private)
Node_Entry :: struct {
    key:       u64,
    node:      gd.Node2d,
    last:      Instance2,
    presented: bool,
}

Nodes2_Stats :: struct {
    created, retired, property_writes, property_skips: u64,
}

// Owns a bounded mapping from presentation identity to a Godot scene instance.
// The scene root must be Node2D. Call after simulation with copied view data.
// The map retains its own scene reference; the parent must outlive the map.
Nodes2 :: struct {
    allocator:        mem.Allocator,
    parent:           gd.Node,
    scene:            gd.Packed_Scene,
    entries:          []Node_Entry,
    count:            int,
    index, desired:   view.Key_Index,
    free_slots:       []int,
    free_count:       int,
    cache_properties: bool, // opt-in exclusive ownership of position/rotation/scale/modulate
    stats:            Nodes2_Stats,
    invalid_root_key: u64, // last failed Node2D root check, diagnostic only
}

nodes_init :: proc(
    n: ^Nodes2,
    parent: gd.Node,
    scene: gd.Packed_Scene,
    capacity: int,
    allocator := context.allocator,
) -> bool {
    if len(n.entries) != 0 ||
       parent == nil ||
       scene == nil ||
       !bake_is_class(cast(gd.Object)scene, "PackedScene") ||
       capacity < 1 ||
       capacity > view.MAX_INDEX_CAPACITY {
        return false
    }

    n.allocator, n.parent, n.scene = allocator, parent, scene
    gd.ref_counted_reference(scene)
    n.entries = make([]Node_Entry, capacity, allocator)
    n.free_slots = make([]int, capacity, allocator)

    if !view.key_index_init(&n.index, capacity, allocator) || !view.key_index_init(&n.desired, capacity, allocator) {
        nodes_destroy(n)
        return false
    }

    return true
}

nodes_load :: proc(n: ^Nodes2, parent: gd.Node, path: cstring, capacity: int, allocator := context.allocator) -> bool {
    scene := gd.load_scene(path)

    if scene == nil {
        return false
    }

    defer release_scene(scene)
    return nodes_init(n, parent, scene, capacity, allocator)
}

scene_instance :: proc(parent: gd.Node, path: cstring) -> gd.Node {
    scene := gd.load_scene(path)

    if scene == nil {
        return nil
    }

    defer release_scene(scene)
    node := gd.instantiate(scene)

    if node != nil {
        gd.add_child(parent, node)
    }

    return node
}

@(private)
release_scene :: proc(scene: gd.Packed_Scene) {
    if scene != nil && gd.ref_counted_unreference(scene) {
        gdext.object_destroy(scene)
    }
}

nodes_clear :: proc(n: ^Nodes2) {
    for &entry in n.entries {
        if entry.node != nil {
            gd.canvas_item_set_visible(entry.node, false)
            gd.node_queue_free(entry.node)
            n.stats.retired += 1
        }

        entry = {}
    }

    n.count = 0
    view.key_index_clear(&n.index)
    view.key_index_clear(&n.desired)
    n.free_count = 0
}

nodes_destroy :: proc(n: ^Nodes2) {
    nodes_clear(n)
    delete(n.entries, n.allocator)
    delete(n.free_slots, n.allocator)
    view.key_index_destroy(&n.index)
    view.key_index_destroy(&n.desired)
    release_scene(n.scene)
    n^ = {}
}

nodes_present :: proc(n: ^Nodes2, instances: []Instance2) -> bool {
    n.invalid_root_key = 0

    if len(n.entries) == 0 || len(instances) > len(n.entries) {
        return false
    }

    view.key_index_clear(&n.desired)
    retained := len(instances) == n.count

    for inst, i in instances {
        if view.key_index_put(&n.desired, inst.key, i) != .None {
            return false
        }

        if retained {
            if _, found := view.key_index_get(&n.index, inst.key); !found {
                retained = false
            }
        }
    }

    // The common case retains exactly the same identities, including reordered
    // input. No lifecycle/free-slot/index rebuild or capacity scan is needed.
    if retained {
        for inst in instances {
            at, found := view.key_index_get(&n.index, inst.key)
            assert(found)
            nodes_apply(n, &n.entries[at], inst)
        }

        return true
    }

    // Release obsolete identities first so full pools can replace all their views.
    for &entry in n.entries {
        if entry.node == nil {
            continue
        }

        _, found := view.key_index_get(&n.desired, entry.key)

        if !found {
            gd.canvas_item_set_visible(entry.node, false)
            gd.node_queue_free(entry.node)
            n.stats.retired += 1
            entry = {}
            n.count -= 1
        }
    }

    view.key_index_clear(&n.index)
    n.free_count = 0

    // Descending free slots preserve the old lowest-vacant-slot allocation order.
    for offset in 0 ..< len(n.entries) {
        i := len(n.entries) - 1 - offset
        entry := &n.entries[i]

        if entry.node == nil {
            n.free_slots[n.free_count] = i
            n.free_count += 1
        } else {
            inserted := view.key_index_put(&n.index, entry.key, i)
            assert(inserted == .None)

            if inserted != .None {
                return false
            }
        }
    }

    for inst in instances {
        at, found := view.key_index_get(&n.index, inst.key)

        if !found {
            if n.free_count == 0 {
                return false
            }

            n.free_count -= 1
            at = n.free_slots[n.free_count]
        }

        entry := &n.entries[at]

        if !found {
            entry.node = gd.instantiate(n.scene)

            if entry.node == nil {
                return false
            }

            if !bake_is_class(cast(gd.Object)entry.node, "Node2D") {
                gdext.object_destroy(entry.node)
                entry.node = nil
                n.invalid_root_key = inst.key
                return false
            }

            entry.key = inst.key
            gd.add_child(n.parent, entry.node)
            n.count += 1
            n.stats.created += 1
            inserted := view.key_index_put(&n.index, inst.key, at)
            assert(inserted == .None)

            if inserted != .None {
                return false
            }
        }

        nodes_apply(n, entry, inst)
    }

    return true
}

nodes_get :: proc(n: ^Nodes2, key: u64) -> (node: gd.Node2d, ok: bool) {
    if at, found := view.key_index_get(&n.index, key); found {
        entry := n.entries[at]
        return entry.node, entry.node != nil
    }

    return nil, false
}

// Force owned properties to be applied again after an external writer changes
// them. Key zero invalidates all views. It does not create/restart any entity.
nodes_invalidate :: proc(n: ^Nodes2, key: u64 = 0) {
    if key == 0 {
        for &entry in n.entries {
            entry.presented = false
        }

        return
    }

    if at, found := view.key_index_get(&n.index, key); found {
        n.entries[at].presented = false
    }
}

@(private)
nodes_apply :: proc(n: ^Nodes2, entry: ^Node_Entry, inst: Instance2) {
    force := !n.cache_properties || !entry.presented

    if force || entry.last.pose.position != inst.pose.position {
        gd.node2d_set_position(entry.node, inst.pose.position)
        n.stats.property_writes += 1
    } else {
        n.stats.property_skips += 1
    }

    if force || entry.last.pose.angle != inst.pose.angle {
        gd.node2d_set_rotation(entry.node, gd.Float(inst.pose.angle))
        n.stats.property_writes += 1
    } else {
        n.stats.property_skips += 1
    }

    if force || entry.last.scale != inst.scale {
        gd.node2d_set_scale(entry.node, inst.scale)
        n.stats.property_writes += 1
    } else {
        n.stats.property_skips += 1
    }

    if force || entry.last.color != inst.color {
        gd.canvas_item_set_modulate(entry.node, inst.color)
        n.stats.property_writes += 1
    } else {
        n.stats.property_skips += 1
    }

    entry.last, entry.presented = inst, true
}
