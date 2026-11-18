package kit_ui_bindings

// Shared by Core's editor component and kit/ui's runtime adoption. This package
// has no session, transport or code-generator dependencies.
import gd "godot:godot"
import "core:fmt"
import "core:strings"

CLASS_NAME :: "OdinKitUIBindings"

Kind :: enum i64 {
    Lobby,
    Chat,
    Scoreboard,
}

Field :: enum {
    Title,
    Status,
    Players,
    Host,
    Join,
    Start,
    Code,
    Lines,
    Input,
    Grid,
}

Spec :: struct {
    kind:                               Kind,
    property, class_name, default_path: cstring,
    optional:                           bool,
}

SPECS := [Field]Spec {
    .Title   = {.Lobby, "title", "Label", "%Title", false},
    .Status  = {.Lobby, "status", "Label", "%Status", false},
    .Players = {.Lobby, "players", "Control", "%Players", false},
    .Host    = {.Lobby, "host", "Button", "%Host", false},
    .Join    = {.Lobby, "join", "Button", "%Join", false},
    .Start   = {.Lobby, "start", "Button", "%Start", false},
    .Code    = {.Lobby, "code", "LineEdit", "", true},
    .Lines   = {.Chat, "lines", "Control", "%Lines", false},
    .Input   = {.Chat, "input", "LineEdit", "%Input", false},
    .Grid    = {.Scoreboard, "grid", "GridContainer", "%Grid", false},
}

Report :: struct {
    count, length: int,
    buffer:        [4096]u8,
}

Result :: struct {
    root, component: gd.Node,
    nodes:           [Field]gd.Node,
    report:          Report,
}

text :: proc(report: ^Report) -> string {
    return string(report.buffer[:report.length])
}

problem :: proc(report: ^Report, message: string) {
    report.count += 1

    if report.length > 0 {
        report.length += copy(report.buffer[report.length:], "\n")
    }

    report.length += copy(report.buffer[report.length:], message)
}

is_class :: proc(node: gd.Node, name: cstring) -> bool {
    return node != nil && gd.object_is_class(cast(gd.Object)node, gd.sname(name))
}

kind_valid :: proc(kind: i64) -> bool {
    return kind >= i64(Kind.Lobby) && kind <= i64(Kind.Scoreboard)
}

label :: proc(node: gd.Node) -> string {
    name := gd.node_get_name(node)
    defer gd.free_string_name(name)
    value := gd.new_string_string_name(name)
    defer gd.free_string(value)
    return gd.gd_string_to_odin(value, context.temp_allocator)
}

@(private)
name_count :: proc(node, owner: gd.Node, name: string) -> int {
    count := 0

    for i in 0 ..< gd.node_get_child_count(node, false) {
        child := gd.node_get_child(node, gd.Int(i), false)

        if gd.node_get_owner(child) == owner && label(child) == name {
            count += 1
        }

        count += name_count(child, owner, name)
    }

    return count
}

// Explicit paths are relative to the component, just like other Godot NodePath
// properties. They must stay inside the widget. %Names are scoped to its owner.
resolve :: proc(root: gd.Node, expected: Kind) -> (result: Result) {
    result.root = root

    if !is_class(root, "Control") {
        problem(&result.report, "Kit UI: the widget scene root must be a Control.")
        return
    }

    count := 0

    for i in 0 ..< gd.node_get_child_count(root, false) {
        child := gd.node_get_child(root, gd.Int(i), false)

        if is_class(child, CLASS_NAME) {
            result.component = child
            count += 1
        }
    }

    if count != 1 {
        problem(
            &result.report,
            fmt.tprintf(
                "Kit UI %s: expected one direct child OdinKitUIBindings; found %d. Copy a Kit UI template or add the bindings node.",
                label(root),
                count,
            ),
        )
        return
    }

    kind := gd.get_int(cast(gd.Object)result.component, "widget")

    if !kind_valid(kind) || Kind(kind) != expected {
        problem(
            &result.report,
            fmt.tprintf("Kit UI %s: bindings Widget must be %s (got %d).", label(root), expected, kind),
        )
        return
    }

    for spec, field in SPECS {
        if spec.kind != expected {
            continue
        }

        value := gd.get_value(cast(gd.Object)result.component, spec.property)
        defer gd.variant_destroy(&value)
        path := gd.variant_to_node_path(&value)
        defer gd.free_node_path(path)
        path_string := gd.new_string_node_path(path)
        defer gd.free_string(path_string)
        path_text := gd.gd_string_to_odin(path_string, context.temp_allocator)

        if path_text == "" {
            if !spec.optional {
                problem(
                    &result.report,
                    fmt.tprintf(
                        "Kit UI %s.%s: assign a %s reference in the bindings Inspector.",
                        label(root),
                        spec.property,
                        spec.class_name,
                    ),
                )
            }

            continue
        }

        if gd.node_path_is_absolute(&path) || gd.node_path_get_subname_count(&path) > 0 {
            problem(
                &result.report,
                fmt.tprintf(
                    "Kit UI %s.%s: use a relative node path inside this widget, not '%s'.",
                    label(root),
                    spec.property,
                    path_text,
                ),
            )
            continue
        }

        // A template's %Name is deliberately a unique role in its scene.
        // Explicit paths remain available when decorative nodes share a name.
        if strings.has_prefix(path_text, "%") && !strings.contains(path_text, "/") {
            count := name_count(root, gd.node_get_owner(result.component), path_text[1:])

            if count > 1 {
                problem(
                    &result.report,
                    fmt.tprintf(
                        "Kit UI %s.%s: unique reference '%s' matches %d scene-owned nodes. Assign an explicit relative path.",
                        label(root),
                        spec.property,
                        path_text,
                        count,
                    ),
                )
                continue
            }
        }

        target := gd.node_get_node_or_null(result.component, path)

        if target == nil {
            problem(
                &result.report,
                fmt.tprintf(
                    "Kit UI %s.%s: %s reference '%s' is missing. Assign the control in the bindings Inspector.",
                    label(root),
                    spec.property,
                    spec.class_name,
                    path_text,
                ),
            )
            continue
        }

        if target != root && !gd.node_is_ancestor_of(root, target) {
            problem(
                &result.report,
                fmt.tprintf(
                    "Kit UI %s.%s: '%s' must point inside this widget scene.",
                    label(root),
                    spec.property,
                    path_text,
                ),
            )
            continue
        }

        if !is_class(target, spec.class_name) {
            actual := gd.object_get_class(cast(gd.Object)target)
            defer gd.free_string(actual)
            problem(
                &result.report,
                fmt.tprintf(
                    "Kit UI %s.%s: '%s' must be %s; found %s.",
                    label(root),
                    spec.property,
                    path_text,
                    spec.class_name,
                    gd.gd_string_to_odin(actual, context.temp_allocator),
                ),
            )
            continue
        }

        for other, other_field in result.nodes {
            if other == target {
                problem(
                    &result.report,
                    fmt.tprintf(
                        "Kit UI %s.%s: '%s' is already assigned to %s. Each binding needs its own control.",
                        label(root),
                        spec.property,
                        path_text,
                        SPECS[other_field].property,
                    ),
                )
            }
        }

        result.nodes[field] = target
    }

    return
}
