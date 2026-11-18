package scriptgen

import "core:fmt"
import "core:slice"
import "core:strings"
import decl "godot:decl"

Entity_Claim :: struct {
    symbol:    ^Script,
    loc:       Loc,
    stream_hz: int,
    avatar:    bool,
}

Package_Bridge :: struct {
    name, procedure: string,
    value:           bool,
}

package_bridge :: proc(ctx: ^Module_Ctx, directory, procedure: string, value: bool = false) -> string {
    name := fmt.tprintf(value ? "_kit_value_%s" : "_kit_proc_%s", procedure)
    for &pkg in ctx.packages {
        if pkg.dir != directory {continue}
        for bridge in pkg.bridges {if bridge.name == name {return name}}
        append(&pkg.bridges, Package_Bridge{name, procedure, value})
        return name
    }
    return ""
}

prepare_package_bridges :: proc(ctx: ^Module_Ctx) {
    for &pkg in ctx.packages {
        for &pending in pkg.pending {
            source := &pending.script
            for &command in source.commands {
                directory := dir_of(command.loc.path)
                if directory != pkg.dir && module_contains_dir(directory) {
                    command.call_proc = package_bridge(ctx, directory, command.proc_name)
                }
            }
            for &block in source.block_ticks {
                directory, ok := composition_import_dir(pkg.dir, block.pkg_path)
                if ok && directory != pkg.dir && module_contains_dir(directory) {
                    block.call_proc = package_bridge(ctx, directory, block.proc_name)
                }
            }
        }
    }
}

command_call_name :: proc(command: Command_Info) -> string {
    return command.call_proc != "" ? command.call_proc : command.proc_name
}

block_call_name :: proc(block: Hoisted_Tick) -> string {
    return block.call_proc != "" ? block.call_proc : block.proc_name
}

// Several scene fields can share one gameplay declaration. Collapse them
// before callbacks, census helpers and wire schemas are resolved, so those
// remain properties of the type rather than copies for each presentation.
prepare_entity_scenes :: proc(ctx: ^Module_Ctx) {
    for &pkg in ctx.packages {
        for &pending in pkg.pending {
            owner := &pending.script
            scope := module_script_scope(ctx, owner)
            groups := make([dynamic]Entity_Tag, context.temp_allocator)
            by_symbol := make(map[^Script]int, context.temp_allocator)
            for tag in owner.entities {
                symbol, known := scope[tag.target]
                if !known {append(&groups, tag); continue}     // resolve_entities names the missing type
                index, found := by_symbol[symbol]
                if !found {
                    index = len(groups)
                    by_symbol[symbol] = index
                    append(&groups, tag)
                }
                group := &groups[index]
                loc := Loc {
                    path = owner.path,
                    line = tag.line,
                }
                if group.type_id != tag.type_id {
                    error_at(
                        loc,
                        "entity %s already uses wire id %d; scene variants share that gameplay identity",
                        tag.target,
                        group.type_id,
                    )
                    continue
                }
                id := tag.variant == "Default" ? u32(0) : decl.fnv1a32(tag.variant)
                if id == 0 && tag.variant != "Default" {
                    error_at(loc, "scene variant %s hashes to reserved Default id 0; rename it", tag.variant)
                }
                for previous in group.scenes {
                    if previous.id == id {
                        error_at(
                            loc,
                            "entity %s: scene variant %s duplicates or collides with %s at line %d",
                            tag.target,
                            tag.variant,
                            previous.name,
                            previous.line,
                        )
                    }
                }
                if tag.variant != "Default" && (tag.avatar || tag.stream_hz != 0) {
                    error_at(
                        loc,
                        "entity %s: declare avatar/stream_hz on the Default scene; named variants inherit the type's settings",
                        tag.target,
                    )
                }
                append(&group.scenes, Entity_Scene_Tag{tag.field, tag.variant, id, tag.line})
                if tag.variant == "Default" {
                    // A scene-field reorder must not rename the type's helpers.
                    group.field, group.line, group.target = tag.field, tag.line, tag.target
                    group.avatar, group.stream_hz = tag.avatar, tag.stream_hz
                    group.variant = tag.variant
                }
            }
            for &group in groups {
                if len(group.scenes) == 0 {continue}
                slice.sort_by(group.scenes[:], proc(a, b: Entity_Scene_Tag) -> bool {return a.id < b.id})
                if group.scenes[0].id != 0 {
                    error_at(
                        Loc{path = owner.path, line = group.line},
                        "entity %s needs a Default scene: omit variant= on one scene field",
                        group.target,
                    )
                }
            }
            owner.entities = groups
        }
    }
}

entity_variant_type :: proc(entity: Entity_Tag) -> string {
    result := strings.builder_make(context.temp_allocator)
    for word, i in strings.split(entity_helper(entity), "_") {
        if i > 0 {strings.write_byte(&result, '_')}
        if len(word) > 0 {
            strings.write_string(&result, strings.to_upper(word[:1]))
            strings.write_string(&result, word[1:])
        }
    }
    strings.write_string(&result, "_Variant")
    return strings.to_string(result)
}

prepare_entity_helpers :: proc(ctx: ^Module_Ctx) {
    for &pkg in ctx.packages {
        counts := make(map[string]int, context.temp_allocator)
        for &pending in pkg.pending {
            scope := module_script_scope(ctx, &pending.script)
            for &entity in pending.script.entities {
                if symbol, ok := scope[entity.target]; ok {
                    entity.helper = decl.snake_name(symbol.struct_name)
                    counts[entity.helper] += 1
                }
            }
        }
        for &pending in pkg.pending {
            for &entity in pending.script.entities {
                if counts[entity.helper] > 1 {
                    entity.helper = fmt.tprintf(
                        "%s_%s",
                        decl.snake_name(pending.script.struct_name),
                        decl.snake_name(entity.field),
                    )
                }
            }
        }
    }
}

kit_bridge :: proc(s: ^Script, category: string, member: string = "") -> string {
    return(
        member == "" ? fmt.tprintf("_kit_%s_%s", decl.snake_name(s.struct_name), category) : fmt.tprintf("_kit_%s_%s_%s", decl.snake_name(s.struct_name), category, member) \
    )
}

owner_half_matches :: proc(cand: Half_Candidate, owner, entity: ^Script, strict_owner: bool) -> bool {
    if cand.pt.params == nil || len(cand.pt.params.list) == 0 {return false}
    first := node_text(cand.src, cand.pt.params.list[0].type)
    if module_type_matches(cand.path, cand.imports, first, entity) {return true}
    if len(cand.pt.params.list) < 2 {return false}
    second := node_text(cand.src, cand.pt.params.list[1].type)
    return(
        module_type_matches(cand.path, cand.imports, second, entity) &&
        (!strict_owner || module_type_matches(cand.path, cand.imports, first, owner)) \
    )
}

binding_game_valid :: proc(owner: ^Script, path, game, callback: string) -> bool {
    if game == "" {return true}
    if module_type_matches(path, g_file_imports[norm_path(path)], fmt.tprintf("^%s", game), owner) {return true}
    error_at(
        Loc{path = owner.path},
        "%s: callback %s expects ^%s; declare an owner-specific half for ^%s",
        owner.struct_name,
        callback,
        game,
        owner.struct_name,
    )
    return false
}

resolve_owner_bindings :: proc(ctx: ^Module_Ctx) {
    for &pkg in ctx.packages {
        for &pending in pkg.pending {
            owner := &pending.script
            for &entity in owner.entities {
                source := entity.symbol
                if source == nil {continue}
                slots := make([dynamic]string, context.temp_allocator)
                for command in source.commands {
                    stem :=
                        len(command.path) > 0 ? fmt.tprintf("%s_%s", decl.snake_name(source.struct_name), command.name) : command.proc_name
                    append(&slots, fmt.tprintf("%s_then", stem), fmt.tprintf("%s_apply", command.proc_name))
                }
                for field in source.replicates {
                    append(
                        &slots,
                        fmt.tprintf("%s_%s_edge", decl.snake_name(source.struct_name), join_snake(field.path)),
                    )
                }
                if source.tick.proc_name !=
                   "" {append(&slots, fmt.tprintf("%s_then", source.tick.proc_name), fmt.tprintf("%s_fx", source.tick.proc_name))}

                selected := make(map[string]Half_Candidate, context.temp_allocator)
                sites := make(map[string]Proc_Site, context.temp_allocator)
                explicit_owner := false
                for slot in slots {
                    preferred := fmt.tprintf("%s_%s", decl.snake_name(owner.struct_name), slot)
                    actual := slot
                    source_prefix := fmt.tprintf("%s_", decl.snake_name(source.struct_name))
                    specific := ""
                    if entity_helper(entity) != decl.snake_name(source.struct_name) &&
                       strings.has_prefix(slot, source_prefix) {
                        specific = fmt.tprintf("%s_%s", entity_helper(entity), slot[len(source_prefix):])
                    }
                    if _, found := pkg.procs[preferred]; found {actual = preferred; explicit_owner = true}
                    if _, found := pkg.procs[specific];
                       specific != "" && found {actual = specific; explicit_owner = true}
                    if cand, found := pkg.halves[actual]; found {
                        if owner_half_matches(cand, owner, source, actual == slot) {
                            selected[slot] = cand
                            sites[slot] = pkg.procs[actual]
                        }
                    } else if site, found := pkg.procs[actual]; found && !site.half {
                        sites[slot] = site
                    }
                }

                // Existing same-package callbacks already belong to the default
                // descriptor. An explicitly owner-prefixed half selects a new one.
                specialize :=
                    (dir_of(source.path) != pkg.dir || explicit_owner) && (len(selected) > 0 || len(sites) > 0)
                bound := source
                if specialize {
                    bound = new_clone(source^)
                    bound.commands = slice.clone_to_dynamic(source.commands[:])
                    bound.replicates = slice.clone_to_dynamic(source.replicates[:])
                    bound.block_ticks = slice.clone_to_dynamic(source.block_ticks[:])
                    if _, overrides_fx := selected[fmt.tprintf("%s_fx", source.tick.proc_name)];
                       overrides_fx {bound.tick.payload_wires = nil}
                    resolve_then(bound, &selected, sites, false)
                    resolve_tick_then(bound, &selected, sites, false)
                    resolve_edges(bound, &selected, sites)
                    resolve_command_applies(bound, &selected, sites)
                    for _, cand in selected {
                        if cand.claimed {pkg.halves[cand.name] = cand}
                    }
                }

                for command in bound.commands {binding_game_valid(owner, command.then_path, command.then_game, command.then_proc)}
                for field in bound.replicates {binding_game_valid(owner, field.edge_path, field.edge_game, field.edge_proc)}
                binding_game_valid(owner, bound.tick.then_path, bound.tick.then_game, bound.tick.then_proc)
                binding_game_valid(owner, bound.tick.fx_path, bound.tick.fx_game, bound.tick.fx_proc)
                if !specialize {continue}

                source.kit_bridges = true
                source.kit_input_bridge |= source.tick.input_type != ""
                entity.binding = bound
                entity.binding_prefix = fmt.tprintf(
                    "_kit_%s_%s",
                    decl.snake_name(owner.struct_name),
                    entity_helper(entity),
                )
                qualify_owner_binding(owner, &entity)
            }
        }
    }
}

qualify_owner_binding :: proc(owner: ^Script, entity: ^Entity_Tag) {
    source, bound := entity.symbol, entity.binding
    qual := entity.pkg_alias != "" ? fmt.tprintf("%s.", entity.pkg_alias) : ""
    source_upper := strings.to_upper(decl.snake_name(source.struct_name))
    for &command in bound.commands {
        if command.call_proc != "" {
            command.pkg_alias, command.pkg_path = composed_pkg_ref(dir_of(command.loc.path), dir_of(owner.path))
            owner.code_imports[command.pkg_alias] = command.pkg_path
        } else {
            command.call_proc = kit_bridge(source, "command", command.name)
            command.pkg_alias, command.pkg_path = entity.pkg_alias, entity.pkg_path
        }
        command.policy_expr = fmt.tprintf("%s%s_POLICY_%s", qual, source_upper, strings.to_upper(command.name))
        if command.then_proc != "" {
            if dir_of(command.then_path) != dir_of(owner.path) {
                command.then_proc = fmt.tprintf("%s%s", qual, kit_bridge(source, "then", command.name))
            }
            if command.then_game != "" {command.then_game = owner.struct_name}
        }
        if command.apply_proc != "" && dir_of(command.apply_path) != dir_of(owner.path) {
            command.apply_proc = fmt.tprintf("%s%s", qual, kit_bridge(source, "apply", command.name))
        }
    }
    for &field in bound.replicates {
        if field.edge_proc != "" && dir_of(field.edge_path) != dir_of(owner.path) {
            field.edge_proc = fmt.tprintf("%s%s", qual, kit_bridge(source, "edge", join_snake(field.path)))
        }
        if field.edge_game != "" {field.edge_game = owner.struct_name}
    }
    if bound.tick.proc_name != "" {bound.tick.proc_name = fmt.tprintf("%s%s", qual, kit_bridge(source, "tick"))}
    if bound.tick.input_type != "" {bound.tick.input_code = fmt.tprintf("%s%s", qual, kit_bridge(source, "Input"))}
    if bound.tick.then_proc != "" && dir_of(bound.tick.then_path) != dir_of(owner.path) {
        bound.tick.then_proc = fmt.tprintf("%s%s", qual, kit_bridge(source, "tick_then"))
    }
    if bound.tick.fx_proc != "" && dir_of(bound.tick.fx_path) != dir_of(owner.path) {
        bound.tick.fx_proc = fmt.tprintf("%s%s", qual, kit_bridge(source, "tick_fx"))
    }
    if bound.tick.then_game != "" {bound.tick.then_game = owner.struct_name}
    if bound.tick.fx_game != "" {bound.tick.fx_game = owner.struct_name}
    for &block in bound.block_ticks {
        if block.call_proc != "" {
            directory, _ := composition_import_dir(dir_of(source.path), block.pkg_path)
            block.pkg_alias, block.pkg_path = composed_pkg_ref(directory, dir_of(owner.path))
            owner.code_imports[block.pkg_alias] = block.pkg_path
        } else {
            block.call_proc = kit_bridge(source, "block", join_snake(block.path))
            block.pkg_alias, block.pkg_path = entity.pkg_alias, entity.pkg_path
        }
    }
}

warn_unconsumed_payloads :: proc(ctx: ^Module_Ctx) {
    if had_error {return}
    for pkg in ctx.packages {
        for &pending in pkg.pending {
            source := &pending.script
            tick_consumed := source.tick.then_proc != "" || source.tick.fx_proc != ""
            for command in source.commands {
                consumed := command.then_proc != ""
                for owner_pkg in ctx.packages {
                    for owner in owner_pkg.pending {
                        for entity in owner.script.entities {
                            if entity.symbol != source || entity.binding == nil {continue}
                            tick_consumed |= entity.binding.tick.then_proc != "" || entity.binding.tick.fx_proc != ""
                            for bound in entity.binding.commands {
                                if bound.name == command.name && bound.then_proc != "" {consumed = true}
                            }
                        }
                    }
                }
                if command.payload_count > 0 && len(command.path) == 0 && !consumed {
                    warn_at(
                        Loc{path = source.path},
                        "command %s returns a payload but no `%s_then` consequence proc consumes it",
                        command.proc_name,
                        command.proc_name,
                    )
                }
            }
            if source.tick.payload_count > 0 && !tick_consumed {
                // A tick-only entity may have no commands to enter the loop above.
                for owner_pkg in ctx.packages {
                    for owner in owner_pkg.pending {
                        for entity in owner.script.entities {
                            if entity.symbol == source && entity.binding != nil {
                                tick_consumed |=
                                    entity.binding.tick.then_proc != "" || entity.binding.tick.fx_proc != ""
                            }
                        }
                    }
                }
                if !tick_consumed {warn_at(Loc{path = source.path, line = source.tick.line}, "tick %s returns a payload but neither `%s_then` nor `%s_fx` consumes it", source.tick.proc_name, source.tick.proc_name, source.tick.proc_name)}
            }
        }
    }
}

emit_kit_bridges :: proc(b: ^strings.Builder, s: ^Script) {
    if s.kit_input_bridge {fmt.sbprintf(b, "%s :: %s\n", kit_bridge(s, "Input"), s.tick.input_code)}
    if !s.kit_bridges {return}
    for command in s.commands {
        qual := command.pkg_alias != "" ? fmt.tprintf("%s.", command.pkg_alias) : ""
        if command.call_proc ==
           "" {fmt.sbprintf(b, "%s :: proc {{%s%s}}\n", kit_bridge(s, "command", command.name), qual, command.proc_name)}
        if command.then_proc !=
           "" {fmt.sbprintf(b, "%s :: proc {{%s}}\n", kit_bridge(s, "then", command.name), command.then_proc)}
        if command.apply_proc !=
           "" {fmt.sbprintf(b, "%s :: proc {{%s}}\n", kit_bridge(s, "apply", command.name), command.apply_proc)}
    }
    for field in s.replicates {
        if field.edge_proc !=
           "" {fmt.sbprintf(b, "%s :: proc {{%s}}\n", kit_bridge(s, "edge", join_snake(field.path)), field.edge_proc)}
    }
    if s.tick.proc_name != "" {fmt.sbprintf(b, "%s :: proc {{%s}}\n", kit_bridge(s, "tick"), s.tick.proc_name)}
    if s.tick.then_proc != "" {fmt.sbprintf(b, "%s :: proc {{%s}}\n", kit_bridge(s, "tick_then"), s.tick.then_proc)}
    if s.tick.fx_proc != "" {fmt.sbprintf(b, "%s :: proc {{%s}}\n", kit_bridge(s, "tick_fx"), s.tick.fx_proc)}
    for block in s.block_ticks {
        qual := block.pkg_alias != "" ? fmt.tprintf("%s.", block.pkg_alias) : ""
        if block.call_proc ==
           "" {fmt.sbprintf(b, "%s :: proc {{%s%s}}\n", kit_bridge(s, "block", join_snake(block.path)), qual, block.proc_name)}
    }
    strings.write_byte(b, '\n')
}

emit_owner_bindings :: proc(b: ^strings.Builder, owner: ^Script) {
    for entity in owner.entities {
        if entity.binding == nil {continue}
        emit_entity_commands(
            b,
            entity.binding,
            entity_type(entity),
            entity.binding_prefix,
            false,
            entity_source_prefix(entity),
        )
        emit_entity_sim(
            b,
            entity.binding,
            entity_type(entity),
            entity.binding_prefix,
            false,
            entity_source_prefix(entity),
        )
    }
}

// Wire metadata describes the union of this module's immutable bindings.
// Keep owner callbacks out of the leaf's emitted default code; only the
// callback-independent contract and optional fact tuple belong in this view.
wire_binding_view :: proc(ctx: ^Module_Ctx, source: ^Script, names: map[^Script]string) -> ^Script {
    view := new_clone(source^)
    view.struct_name = names[source]
    view.commands = slice.clone_to_dynamic(source.commands[:])
    view.entities = slice.clone_to_dynamic(source.entities[:])
    for &entity in view.entities {
        if entity.symbol != nil {entity.target = names[entity.symbol]}
    }
    for pkg in ctx.packages {
        for pending in pkg.pending {
            for entity in pending.script.entities {
                if entity.symbol != source || entity.binding == nil {continue}
                bound := entity.binding
                if bound.tick.fx_mine {
                    view.tick.fx_mine = true
                    view.tick.payload_wires = bound.tick.payload_wires
                }
                for &command in view.commands {
                    for selected in bound.commands {
                        if selected.name != command.name || selected.then_proc == "" {continue}
                        // The schema names the semantic hook slot; the selected
                        // descriptor names its actual owner-specific procedure.
                        if command.then_proc == "" {
                            stem :=
                                len(command.path) > 0 ? fmt.tprintf("%s_%s", decl.snake_name(source.struct_name), command.name) : command.proc_name
                            command.then_proc = fmt.tprintf("%s_then", stem)
                        }
                        if selected.then_game != "" {command.then_game = selected.then_game}
                    }
                }
            }
        }
    }
    view.facts = slice.clone_to_dynamic(source.facts[:])
    for &event in view.facts {
        event.entity_refs = slice.clone_to_dynamic(event.entity_refs[:])
        for &ref in event.entity_refs {ref.wire_name = names[ref.symbol]}
    }
    view.net_events = slice.clone_to_dynamic(source.net_events[:])
    for &event in view.net_events {
        event.entity_refs = slice.clone_to_dynamic(event.entity_refs[:])
        for &ref in event.entity_refs {ref.wire_name = names[ref.symbol]}
    }
    return view
}

// Code qualification follows imports; wire names must survive moving a source
// directory or renaming an import alias. Existing kind IDs disambiguate equal
// local type names. A standalone wire owner can use its explicit class alias.
module_wire_names :: proc(scripts: []^Script) -> map[^Script]string {
    counts := make(map[string]int, context.temp_allocator)
    names := make(map[^Script]string, context.temp_allocator)
    for s in scripts {counts[s.struct_name] += 1}
    for s in scripts {
        name := s.struct_name
        if counts[name] > 1 {
            if s.entity_id != 0 {
                name = fmt.tprintf("%s#%d", name, s.entity_id)
            } else if s.class_name != "" {
                name = s.class_name
            } else if len(s.replicates) > 0 ||
               len(s.commands) > 0 ||
               s.tick.proc_name != "" ||
               len(s.facts) > 0 ||
               len(s.net_events) > 0 ||
               len(s.messages) > 0 ||
               s.profile_type != "" ||
               len(s.rpcs) > 0 {
                error_at(
                    Loc{path = s.path},
                    "wire type %s is declared in multiple packages; give it a stable entity= kind ID or a unique //gd:class alias",
                    name,
                )
            }
        }
        names[s] = name
    }
    claimed := make(map[string]^Script, context.temp_allocator)
    for s in scripts {
        if len(s.replicates) == 0 &&
           len(s.commands) == 0 &&
           s.tick.proc_name == "" &&
           len(s.facts) == 0 &&
           len(s.net_events) == 0 &&
           len(s.messages) == 0 &&
           s.profile_type == "" &&
           len(s.rpcs) == 0 {continue}
        name := names[s]
        if previous, duplicate := claimed[name]; duplicate && previous != s {
            error_at(
                Loc{path = s.path},
                "wire identity %q also names %s; use distinct entity kind IDs or class aliases",
                name,
                previous.path,
            )
        } else {claimed[name] = s}
    }
    return names
}
