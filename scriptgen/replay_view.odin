package scriptgen

import "core:fmt"
import "core:strings"
import "core:odin/ast"

// Optional declaration over public Replay/Godot helpers. It contributes no wire
// fields, lifecycle callbacks, game policy or independent runtime implementation.
Replay_View_Info :: struct {
    line:                                                     int,
    value, present, validate, retired, appearance, configure: string,
}

parse_replay_view_marker :: proc(s: ^Script, text: string, loc: Loc) {
    if s.replay_view.line != 0 {
        error_at(loc, "duplicate //gd:replay_view declaration")
        return
    }

    s.replay_view.line = loc.line
    seen := make(map[string]bool, context.temp_allocator)

    for part in strings.split(text, ",") {
        at := strings.index_byte(part, '=')

        if at < 1 {
            error_at(loc, "replay_view expects comma-separated name=identifier options")
            continue
        }

        key := strings.trim_space(part[:at])
        value := strings.trim_space(part[at + 1:])

        if !is_odin_ident(value) {
            error_at(loc, "replay_view %s must name a direct field or same-package procedure", key)
            continue
        }

        if seen[key] {
            error_at(loc, "duplicate replay_view option %q", key)
            continue
        }

        seen[key] = true

        switch key {
        case "value":
            s.replay_view.value = value
        case "present":
            s.replay_view.present = value
        case "validate":
            s.replay_view.validate = value
        case "retired":
            s.replay_view.retired = value
        case "appearance":
            s.replay_view.appearance = value
        case "configure":
            s.replay_view.configure = value
        case:
            error_at(loc, "unknown replay_view option %q", key)
        }
    }

    if s.replay_view.value == "" || s.replay_view.present == "" {
        error_at(loc, "replay_view requires value=<display field> and present=<procedure>")
    }

    if (s.replay_view.appearance == "") != (s.replay_view.configure == "") {
        error_at(loc, "replay_view appearance and configure must be declared together")
    }
}

validate_replay_view_fields :: proc(s: ^Script, fields: ^ast.Struct_Type, src: string) {
    info := s.replay_view

    if info.line == 0 {
        return
    }

    loc := Loc{s.path, info.line}

    // Engine class inheritance is checked with the same ClassDB metadata used
    // by other source declarations. Runtime/asset checks still inspect the scene.
    if covers, known := class_handle_covers("Node2D", s.base); known && !covers {
        error_at(loc, "replay_view requires a Node2D script")
    }

    found_value, found_appearance := false, info.appearance == ""

    for field in fields.fields.list {
        for name in field.names {
            ident, ok := name.derived.(^ast.Ident)

            if !ok {
                continue
            }

            if ident.name == info.value {
                found_value = true
            }

            if info.appearance != "" && ident.name == info.appearance {
                found_appearance = true
                text := strings.trim_space(node_text(src, field.type))

                if !strings.has_prefix(text, "^") {
                    error_at(
                        loc,
                        "replay_view appearance field %s must be a typed Resource script pointer",
                        info.appearance,
                    )
                }
            }
        }
    }

    if !found_value {
        error_at(loc, "replay_view display field %q does not exist on %s", info.value, s.struct_name)
    }

    if !found_appearance {
        error_at(loc, "replay_view appearance field %q does not exist on %s", info.appearance, s.struct_name)
    }
}

emit_replay_view :: proc(b: ^strings.Builder, s: ^Script) {
    info := s.replay_view

    if info.line == 0 {
        return
    }

    cls := s.struct_name
    snake := to_snake(cls)
    value := fmt.tprintf("type_of(%s{{}}.%s)", cls, info.value)
    base := fmt.tprintf("rview.Script_View(%s,%s)", value, cls)
    target := base

    if info.appearance != "" {
        target = fmt.tprintf("rview.Script_Archetype(%s,%s,type_of(%s{{}}.%s^))", value, cls, cls, info.appearance)
    }

    fmt.sbprintf(b, "// %s:%d — generated descriptor over public Replay helpers.\n", s.resource_path, info.line)

    for hook in ([3]string{"present", "validate", "retired"}) {
        name := hook == "present" ? info.present : hook == "validate" ? info.validate : info.retired

        if name != "" {
            fmt.sbprintf(
                b,
                "#assert(type_of(%s) == type_of(%s{{}}.%s), %q)\n",
                name,
                base,
                hook,
                fmt.tprintf("%s replay_view: %s has incompatible %s callback signature", s.struct_name, name, hook),
            )
        }
    }

    if info.configure != "" {
        fmt.sbprintf(
            b,
            "#assert(type_of(%s) == type_of(%s{{}}.configure), %q)\n",
            info.configure,
            target,
            fmt.tprintf("%s replay_view: %s has incompatible configure callback signature", cls, info.configure),
        )
    }

    fmt.sbprintf(b, "%s_replay_binding :: proc()->%s {{\n    return {{", snake, target)

    if info.appearance != "" {
        strings.write_string(b, "view={")
    }

    fmt.sbprintf(b, "present=%s", info.present)

    if info.validate != "" {
        fmt.sbprintf(b, ",validate=%s", info.validate)
    }

    if info.retired != "" {
        fmt.sbprintf(b, ",retired=%s", info.retired)
    }

    if info.appearance != "" {
        strings.write_string(b, "},configure=")
        strings.write_string(b, info.configure)
    }

    strings.write_string(b, "}\n}\n\n")
}
