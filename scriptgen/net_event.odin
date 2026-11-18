package scriptgen

import decl "godot:decl"

// @(gd_event) resolution. The anchor selects the existing runtime:
// sim-tracked anchors become watch-clock events; cooperative entities and
// explicit static/immediate occurrences become session net events. An
// anchorless event in a lane-owning game also selects the watch clock unless
// it explicitly requests immediate timing.

import "core:fmt"
import "core:odin/ast"
import "core:strings"

@(private = "file")
net_event_params :: proc(cand: Fact_Candidate) -> (types, names: [dynamic]string) {
    types = make([dynamic]string, context.temp_allocator)
    names = make([dynamic]string, context.temp_allocator)

    if cand.pt.params == nil {
        return
    }

    for f in cand.pt.params.list {
        t := strings.trim_space(node_text(cand.src, f.type))

        for ni in 0 ..< max(1, len(f.names)) {
            append(&types, t)
            nm := ""

            if ni < len(f.names) {
                if ident, ok := f.names[ni].derived.(^ast.Ident); ok && ident != nil {
                    nm = ident.name
                }
            }

            append(&names, nm)
        }
    }

    return
}

module_script_type :: proc(scripts: []^Script, from: Struct_Def, spelling: string) -> (^Script, bool) {
    def, _, found := type_struct({spelling, from, nil})
    if !found {return nil, false}
    for s in scripts {
        if dir_of(s.path) == def.dir && s.struct_name == def.name {return s, true}
    }
    return nil, false
}

event_wire_anchor :: proc(event: $Event) -> string {
    return event.anchor_index < 0 ? "" : event.entity_refs[event.anchor_index].wire_name
}

emit_event_kind_guard :: proc(b: ^strings.Builder, ref: Event_Entity_Ref, boot, id, raw: string, index: int) {
    if ref.binding == nil {return}
    fmt.sbprintf(
        b,
        "\t_kind%d, _kind%d_ok := kboot.boot_entity(%s, %s, %s_TYPE)\n",
        index,
        index,
        boot,
        id,
        strings.to_upper(entity_helper(ref.binding^)),
    )
    fmt.sbprintf(b, "\tif !_kind%d_ok || _kind%d != rawptr(%s) {{return}}\n", index, index, raw)
}

@(private = "file")
net_event_session_clock :: proc(target: ^Script) -> bool {
    if target == nil {
        return false
    }

    for r in target.replicates {
        if r.owner && r.interp {
            return true
        }
    }

    return false
}

@(private)
net_event_audience_expr :: proc(audience: string) -> string {
    switch audience {
    case "owner":
        return ".Owner"
    case "observers":
        return ".Observers"
    }

    return ".Everyone"
}

// Resolve declarations after resolve_sim has classified every entity and
// identified the lane owner.
resolve_net_events :: proc(scripts: []^Script, decls: []Fact_Candidate, taken: map[string]Proc_Site) {
    GENERATED_SUFFIXES :: [?]string{"_cmd", "_spawn", "_step", "_events", "_event_routes"}

    for cand in decls {
        loc := Loc {
            path = cand.path,
            line = cand.line,
        }

        if has_attr(cand.vd, "gd_command") ||
           has_attr(cand.vd, "gd_message") ||
           has_attr(cand.vd, "gd_method") ||
           has_attr(cand.vd, "gd_rpc") ||
           has_attr(cand.vd, "gd_connect") ||
           has_attr(cand.vd, "gd_tick") ||
           has_attr(cand.vd, "gd_step") ||
           has_attr(cand.vd, "gd_sample") ||
           has_attr(cand.vd, "gd_half") {
            error_at(loc, "%s: @(gd_event) is a presentation declaration; drop the other proc attribute", cand.name)
            continue
        }

        if !strings.has_suffix(cand.name, "_fx") {
            error_at(
                loc,
                "%s: a network event is presentation — name the body `%s_fx`; scriptgen generates the suffix-free announce door",
                cand.name,
                cand.name,
            )
            continue
        }

        door := strings.trim_suffix(cand.name, "_fx")
        reserved := false

        for suffix in GENERATED_SUFFIXES {
            if strings.has_suffix(door, suffix) {
                error_at(loc, "%s: event name %q ends in generated suffix %q; rename it", cand.name, door, suffix)
                reserved = true
                break
            }
        }

        if reserved {
            continue
        }

        if _, exists := taken[door]; exists {
            error_at(
                loc,
                "%s: `%s` is the generated announce door and a proc already claims it; rename that proc or the event",
                cand.name,
                door,
            )
            continue
        }

        if cmd_wire_id(door) == 0 {
            error_at(loc, "%s: the event name hashes to reserved id 0; rename it", cand.name)
            continue
        }

        audience := "everyone"
        timing := "auto"
        anchor_name := ""
        anchor_set := false
        config_ok := true
        config, _ := attr_value(cand.vd, "gd_event")

        for part in strings.split(config, ",") {
            tok := strings.trim_space(part)

            switch {
            case tok == "":
            case strings.has_prefix(tok, "audience="):
                audience = strings.trim_space(tok[len("audience="):])

                if audience != "everyone" && audience != "owner" && audience != "observers" {
                    error_at(
                        loc,
                        "%s: event audience %q is unknown (everyone, owner, or observers)",
                        cand.name,
                        audience,
                    )
                    config_ok = false
                }
            case strings.has_prefix(tok, "timing="):
                timing = strings.trim_space(tok[len("timing="):])

                if timing != "auto" && timing != "immediate" && timing != "anchored" {
                    error_at(loc, "%s: event timing %q is unknown (auto, immediate, or anchored)", cand.name, timing)
                    config_ok = false
                }
            case strings.has_prefix(tok, "anchor="):
                if anchor_set {
                    error_at(loc, "%s: event anchor declared more than once", cand.name)
                    config_ok = false
                    continue
                }

                anchor_name = strings.trim_space(tok[len("anchor="):])

                if anchor_name == "" {
                    error_at(loc, "%s: `anchor=` needs an entity parameter name or `none`", cand.name)
                    config_ok = false
                }

                anchor_set = true
            case:
                error_at(
                    loc,
                    "%s: unknown event config token %q (audience=…, timing=…, anchor=…)",
                    cand.name,
                    tok,
                )
                config_ok = false
            }
        }

        if !config_ok {
            continue
        }

        if cand.pt.results != nil && len(cand.pt.results.list) > 0 {
            error_at(loc, "%s: an event presents and returns nothing", cand.name)
            continue
        }

        types, names := net_event_params(cand)

        if len(types) == 0 || !strings.has_prefix(types[0], "^") {
            error_at(loc, "%s: first parameter is the game script pointer", cand.name)
            continue
        }

        from := Struct_Def {
            dir     = dir_of(cand.path),
            imports = g_file_imports[norm_path(cand.path)],
            loc     = loc,
        }
        game_name := strings.trim_prefix(types[0], "^")
        game, game_ok := module_script_type(scripts, from, game_name)

        if !game_ok || game.boot_fields != 1 || game.session_fields != 1 {
            error_at(
                loc,
                "%s: first parameter %q must be the game script with one direct kboot.Boot and ksess.Session field",
                cand.name,
                types[0],
            )
            continue
        }

        if dir_of(game.path) != from.dir {
            error_at(
                loc,
                "%s: declare the event callback in the game owner's package (%s), so generated routing does not create a reverse import",
                cand.name,
                dir_of(game.path),
            )
            continue
        }
        game_name = game.struct_name

        mine_at := -1

        for i in 1 ..< len(types) {
            if types[i] == "bool" && names[i] == "mine" {
                mine_at = i
                break
            }
        }

        if mine_at < 0 {
            error_at(loc, "%s: `mine: bool` is required after entity parameters and before wire arguments", cand.name)
            continue
        }

        refs := make([dynamic]Event_Entity_Ref, context.temp_allocator)
        shape_ok := true

        for i in 1 ..< mine_at {
            if !strings.has_prefix(types[i], "^") {
                error_at(loc, "%s: parameter %q before mine is not an entity pointer", cand.name, names[i])
                shape_ok = false
                break
            }

            target_type := strings.trim_prefix(types[i], "^")
            target, known := module_script_type(scripts, from, target_type)
            if !known {
                error_at(loc, "%s: event entity %q has unknown script type %s", cand.name, names[i], types[i])
                shape_ok = false
                break
            }
            if target == game {
                error_at(loc, "%s: the game parameter cannot also be an event entity", cand.name)
                shape_ok = false
                break
            }
            name := names[i] != "" ? names[i] : fmt.tprintf("entity%d", i - 1)

            if name == "b" {
                error_at(loc, "%s: `b` is the generated door's Boot parameter; rename the entity", cand.name)
                shape_ok = false
                break
            }

            binding: ^Entity_Tag
            for &entry in game.entities {if entry.symbol == target {binding = &entry; break}}
            code, rendered := type_expression({target_type, from, nil}, dir_of(game.path), &game.code_imports)
            if !rendered {error_at(loc, "%s: cannot render entity type %s", cand.name, target_type); shape_ok = false; break}
            append(&refs, Event_Entity_Ref{parameter = name, symbol = target, binding = binding, type_code = code})
        }

        if !shape_ok {
            continue
        }

        anchor_index := -1

        switch {
        case anchor_set && anchor_name == "none":
        case anchor_set:
            for ref, i in refs {
                name := ref.parameter
                if name == anchor_name {
                    anchor_index = i
                    break
                }
            }

            if anchor_index < 0 {
                error_at(loc, "%s: `anchor=%s` does not name an event entity parameter", cand.name, anchor_name)
                continue
            }
        case len(refs) == 0:
        case len(refs) == 1:
            anchor_index = 0
        case:
            error_at(
                loc,
                "%s: %d entity parameters are ambiguous; choose anchor=PARAM or anchor=none",
                cand.name,
                len(refs),
            )
            continue
        }

        if audience == "owner" && anchor_index < 0 {
            error_at(loc, "%s: audience=owner needs an entity anchor", cand.name)
            continue
        }

        anchor_script: ^Script

        if anchor_index >= 0 {
            anchor_script = refs[anchor_index].symbol
        }

        sim_route :=
            (anchor_script != nil && (anchor_script.tick.proc_name != "" || len(anchor_script.block_ticks) > 0)) ||
            (anchor_index < 0 && game.lane_fields == 1 && timing != "immediate")

        if sim_route {
            if timing == "immediate" {
                error_at(
                    loc,
                    "%s: a sim-tracked anchor presents on its watch clock; use timing=auto/anchored (immediate sim events are intentionally not inferred)",
                    cand.name,
                )
                continue
            }

            timing = "anchored"

            if game.lane_fields != 1 {
                error_at(loc, "%s: sim event game %s needs one direct ksim.Lane field", cand.name, game_name)
                continue
            }

            for ref in refs {
                ts := ref.symbol
                target := ref.type_code

                if ts.tick.proc_name == "" && len(ts.block_ticks) == 0 {
                    error_at(loc, "%s: sim event entity %s is not lane-tracked", cand.name, target)
                    shape_ok = false
                    break
                }
            }
        } else {
            if timing == "auto" {
                if anchor_script != nil && net_event_session_clock(anchor_script) {
                    timing = "anchored"
                } else {
                    error_at(
                        loc,
                        "%s: timing=auto cannot prove a framework-owned presentation clock here; use timing=immediate, or anchor an owner+interp entity",
                        cand.name,
                    )
                    continue
                }
            }

            if timing == "anchored" && (anchor_script == nil || !net_event_session_clock(anchor_script)) {
                error_at(
                    loc,
                    "%s: timing=anchored needs an entity with owner+interp state; this cause is not rendered on the session interpolation clock",
                    cand.name,
                )
                continue
            }

            for ref in refs {
                ts := ref.symbol
                target := ref.type_code

                if ref.binding == nil || ts.net_id_type == "" {
                    error_at(
                        loc,
                        "%s: cooperative event entity %s must be a registered entity kind with a net_id field",
                        cand.name,
                        target,
                    )
                    shape_ok = false
                    break
                }
            }
        }

        if !shape_ok {
            continue
        }

        arg_names := make([dynamic]string, context.temp_allocator)
        arg_types := make([dynamic]string, context.temp_allocator)
        arg_wires := make([dynamic]string, context.temp_allocator)

        for i in mine_at + 1 ..< len(types) {
            wire, _, ok := command_wire_type(types[i])

            if !ok {
                error_at(loc, "%s: event argument %q is not a supported wire primitive", cand.name, types[i])
                shape_ok = false
                break
            }

            name := names[i] != "" ? names[i] : fmt.tprintf("a%d", i - mine_at - 1)

            if name == "b" {
                error_at(loc, "%s: `b` is the generated door's Boot parameter; rename the argument", cand.name)
                shape_ok = false
                break
            }

            append(&arg_names, name)
            code, rendered := type_expression({types[i], from, nil}, dir_of(game.path), &game.code_imports)
            if !rendered {error_at(loc, "%s: cannot render event argument %s", cand.name, types[i]); shape_ok = false; break}
            append(&arg_types, code)
            append(&arg_wires, wire)
        }

        if !shape_ok {
            continue
        }

        if sim_route {
            info := Fact_Info {
                name         = door,
                fx_proc      = cand.name,
                game         = game_name,
                anchor_index = anchor_index,
                entity_refs  = refs,
                arg_names    = arg_names,
                arg_types    = arg_types,
                arg_wires    = arg_wires,
                audience     = audience,
                line         = cand.line,
                path         = cand.path,
            }

            if anchor_index >= 0 {
                info.anchor_param = refs[anchor_index].parameter
            }

            dup := false

            for f in game.facts {
                if f.name == door || cmd_wire_id(f.name) == cmd_wire_id(door) {
                    error_at(
                        loc,
                        "%s: sim event %q duplicates/collides with event %q at %s:%d",
                        cand.name,
                        door,
                        f.name,
                        f.path,
                        f.line,
                    )
                    dup = true
                    break
                }
            }

            if !dup {
                append(&game.facts, info)
            }
        } else {
            info := Net_Event_Info {
                name         = door,
                fx_proc      = cand.name,
                game         = game_name,
                anchor_index = anchor_index,
                entity_refs  = refs,
                arg_names    = arg_names,
                arg_types    = arg_types,
                arg_wires    = arg_wires,
                audience     = audience,
                timing       = timing,
                line         = cand.line,
                path         = cand.path,
            }

            if anchor_index >= 0 {
                info.anchor_param = refs[anchor_index].parameter
            }

            dup := false

            for e in game.net_events {
                if e.name == door || cmd_wire_id(e.name) == cmd_wire_id(door) {
                    error_at(
                        loc,
                        "%s: event %q duplicates/collides with %q at %s:%d",
                        cand.name,
                        door,
                        e.name,
                        e.path,
                        e.line,
                    )
                    dup = true
                    break
                }
            }

            if !dup {
                append(&game.net_events, info)
            }
        }
    }

    for s in scripts {
        if len(s.net_events) == 0 {
            continue
        }

        name := fmt.tprintf("%s_event_routes", decl.snake_name(s.struct_name))

        if site, hand := taken[name]; hand && dir_of(site.loc.path) == dir_of(s.path) {
            error_at(
                site.loc,
                "%s is generated by @(gd_event) declarations on %s; rename the hand-written proc",
                name,
                s.struct_name,
            )
        }
    }
}
