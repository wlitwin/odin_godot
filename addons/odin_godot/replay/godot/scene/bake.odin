package replay_godot_scene

import "core:math"
import gd "godot:godot"
import "godot:gdext"
import d "godot:replay/definitions"

// Synchronous authoring scope. Detached scene instances are owned until baking
// returns, including all failure paths. No node/resource enters the output value.
Bake_Context :: struct {
    report: d.Report,
    roots:  [16]gd.Node,
    count:  int,
}

bake_fail :: proc(ctx: ^Bake_Context, path, message: string) {
    if ctx.report.error == .None {
        ctx.report = d.problem(.Invalid, path, message)
    }
}

bake_is_class :: proc(object: gd.Object, kind: string) -> bool {
    if object == nil {
        return false
    }

    name := gd.new_string_name(kind)
    defer gd.free_string_name(name)
    return gd.object_is_class(object, name)
}

bake :: proc {
    bake_basic,
    bake_validated,
}

@(private)
bake_basic :: proc(
    store: ^d.Store($Value),
    source: $Source,
    semantic: u64,
    extract: proc(_: Source, _: ^Bake_Context) -> Value,
) -> (
    d.Ref,
    d.Report,
) {
    validator: proc(_: Value) -> d.Report
    return bake_validated(store, source, semantic, extract, validator)
}

@(private)
bake_validated :: proc(
    store: ^d.Store($Value),
    source: $Source,
    semantic: u64,
    extract: proc(_: Source, _: ^Bake_Context) -> Value,
    validate: proc(_: Value) -> d.Report,
) -> (
    d.Ref,
    d.Report,
) {
    if extract == nil || !store.ready {
        return {}, d.problem(.Invalid, "$", "missing extractor or uninitialized store")
    }

    ctx: Bake_Context

    defer for node in ctx.roots[:ctx.count] {
        gdext.object_destroy(node)
    }

    candidate := extract(source, &ctx)

    if ctx.report.error != .None {
        return {}, ctx.report
    }

    return d.publish(store, candidate, semantic, validate)
}

// Borrowed return valid only during extraction. Scenes remain outside the tree:
// extraction does not run _ready. Constructor behavior still belongs to assets.
bake_scene2 :: proc(ctx: ^Bake_Context, scene: gd.Packed_Scene, path: string) -> gd.Node2d {
    if ctx.report.error != .None {
        return nil
    }

    if !bake_is_class(cast(gd.Object)scene, "PackedScene") {
        bake_fail(ctx, path, "expected PackedScene")
        return nil
    }

    if ctx.count == len(ctx.roots) {
        bake_fail(ctx, path, "too many temporary scenes (maximum 16)")
        return nil
    }

    node := gd.instantiate(scene)

    if node == nil {
        bake_fail(ctx, path, "scene could not instantiate")
        return nil
    }

    ctx.roots[ctx.count] = node
    ctx.count += 1

    if !bake_is_class(node, "Node2D") {
        bake_fail(ctx, path, "expected Node2D root")
        return nil
    }

    root := cast(gd.Node2d)node

    if gd.node2d_get_position(root) != (gd.Vector2{}) ||
       gd.node2d_get_scale(root) != (gd.Vector2{1, 1}) ||
       gd.node2d_get_rotation(root) != 0 ||
       gd.node2d_get_skew(root) != 0 {
        bake_fail(ctx, path, "root transform must be identity")
        return nil
    }

    return root
}

// Positions are root-local, including transformed intermediate parents. Scene
// remains detached so conversion is independent of the live world's transform.
bake_marker2 :: proc(ctx: ^Bake_Context, root: gd.Node2d, path: string) -> (gd.Vector2, bool) {
    if ctx.report.error != .None || root == nil {
        return {}, false
    }

    text := gd.new_string(path)
    name := gd.new_node_path(text)
    gd.free_string(text)
    node := gd.node_get_node_or_null(root, name)
    gd.free_node_path(name)

    if !bake_is_class(node, "Marker2D") {
        bake_fail(ctx, path, "expected Marker2D")
        return {}, false
    }

    // Walk local transforms: global-transform queries on detached nodes are not
    // available in every engine configuration.
    point := gd.Vector2{}
    current := node

    for current != root {
        if current == nil || !bake_is_class(current, "Node2D") {
            bake_fail(ctx, path, "marker ancestry must consist of Node2D")
            return {}, false
        }

        if gd.canvas_item_is_set_as_top_level(cast(gd.Canvas_Item)current) {
            bake_fail(ctx, path, "top-level marker ancestry is not supported")
            return {}, false
        }

        xf := gd.canvas_item_get_transform(cast(gd.Canvas_Item)current)
        point = xf.x * point.x + xf.y * point.y + xf.origin
        current = gd.node_get_parent(current)
    }

    for x in point {
        if math.is_nan(x) || math.is_inf(x) {
            bake_fail(ctx, path, "marker position must be finite")
            return {}, false
        }
    }

    return point, true
}

bake_int :: proc(ctx: ^Bake_Context, value, minimum, maximum: i64, path: string) -> i64 {
    if value < minimum || value > maximum {
        bake_fail(ctx, path, "integer outside allowed range")
        return 0
    }

    return value
}

// Explicit domain bounds plus checked narrowing. Inspector hints are not used
// as game validation. Small fixed-width integers cover IDs/counters/amounts.
bake_integer :: proc(ctx: ^Bake_Context, $T: typeid, value, minimum, maximum: i64, path: string) -> T {
    #assert(size_of(T) <= 4 && (T == u8 || T == u16 || T == u32 || T == i8 || T == i16 || T == i32))

    if minimum < i64(min(T)) || maximum > i64(max(T)) || minimum > maximum {
        bake_fail(ctx, path, "declared bake bounds do not fit target integer")
        return 0
    }

    result := bake_int(ctx, value, minimum, maximum, path)
    return ctx.report.error == .None ? T(result) : T(0)
}

bake_resource :: proc(ctx: ^Bake_Context, resource: gd.Resource, $Script: typeid, path: string) -> ^Script {
    if ctx.report.error != .None {
        return nil
    }

    script, report := resource_script(resource, Script, path)

    if report.error != .None {
        bake_fail(ctx, d.report_path(&report), d.report_message(&report))
    }

    return script
}
