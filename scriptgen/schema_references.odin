package scriptgen

import "core:fmt"
import "core:strings"

Wire_Codec_Def :: struct {
    id, dir, name: string,
    size:          int,
    loc:           Loc,
}

// Backup container element names belong to their declaring block, not the
// script package. Version labels deliberately exclude source directories and
// generated import aliases; reorganizing a game must not invalidate its saves.
resolve_backups :: proc(s: ^Script) {
    for &backup in s.backups {
        spellings := [2]string{backup.key, backup.elem}
        for spelling, i in spellings {
            if spelling == "" {continue}
            _, name, ok := type_identity({spelling, backup.type_context, nil})
            if !ok {
                error_at(
                    Loc{path = s.path},
                    "%s.%s: cannot resolve backup type %s",
                    s.struct_name,
                    join_path(backup.path),
                    spelling,
                )
                continue
            }
            if i == 0 {backup.key_name = name} else {backup.elem_name = name}
        }
    }
}

prepare_profile_names :: proc(scripts: []^Script) {
    first := make(map[string]string, context.temp_allocator)
    ambiguous := make(map[string]bool, context.temp_allocator)
    for s in scripts {
        if s.profile_type == "" {continue}
        if previous, found := first[s.profile_name]; found && previous != s.profile_identity {
            ambiguous[s.profile_name] = true
        } else {first[s.profile_name] = s.profile_identity}
    }
    for s in scripts {
        if ambiguous[s.profile_name] {s.profile_name = fmt.tprintf("%s.%s", s.struct_name, s.profile_name)}
    }
}

schema_value_location :: proc(from: Struct_Def, spelling: string) -> (dir, name: string, ok: bool) {
    dir, name = from.dir, strings.trim_space(spelling)
    if dot := strings.index_byte(name, '.'); dot >= 0 {
        path, found := from.imports[name[:dot]]
        if !found {return "", "", false}
        dir, ok = resolve_index_import_dir(from.dir, path)
        if !ok {return "", "", false}
        name = name[dot + 1:]
    }
    return dir, name, is_odin_ident(name)
}

resolve_codec :: proc(from: Struct_Def, spelling: string, active: map[string]bool) -> (Wire_Codec_Def, bool) {
    dir, name, ok := schema_value_location(from, spelling)
    if !ok {return {}, false}
    index_pkg_dir(dir)
    if definitions, found := g_wire_codecs[dir]; found {
        if codec, found := definitions[name]; found {return codec, true}
    }
    alias, found := wire_named_lookup(from, spelling)
    if !found || alias.kind != .Alias || active[alias.id] {return {}, false}
    active := active
    active[alias.id] = true
    defer delete_key(&active, alias.id)
    return resolve_codec(Struct_Def{dir = alias.dir, imports = alias.imports}, alias.underlying, active)
}

schema_value_code :: proc(
    ctx: ^Module_Ctx,
    owner: ^Script,
    from: Struct_Def,
    spelling: string,
    value: bool,
) -> (
    string,
    bool,
) {
    directory, name, ok := schema_value_location(from, spelling)
    if !ok {return "", false}
    if directory == dir_of(owner.path) {return name, true}
    if module_contains_dir(directory) {
        bridge := package_bridge(ctx, directory, name, value)
        alias, path := composed_pkg_ref(directory, dir_of(owner.path))
        owner.code_imports[alias] = path
        return fmt.tprintf(value ? "%s.%s()" : "%s.%s", alias, bridge), bridge != ""
    }
    code := type_reference(directory, name, dir_of(owner.path), &owner.code_imports)
    return code, code != ""
}

resolve_field_values :: proc(ctx: ^Module_Ctx, owner: ^Script) {
    for &field in owner.replicates {
        if field.codec != "" {
            active := make(map[string]bool, context.temp_allocator)
            codec, ok := resolve_codec(field.tag_context, field.codec, active)
            if !ok {
                error_at(
                    field.loc,
                    "%s.%s: custom wire codec %s must resolve to a Wire_Codec literal with a positive integer size",
                    owner.struct_name,
                    join_path(field.path),
                    field.codec,
                )
                continue
            }
            if previous, exists := ctx.codecs[codec.name]; exists && previous.id != codec.id {
                error_at(
                    field.loc,
                    "codec identity %s also names %s:%d; use a unique declaration name for each wire format/version",
                    codec.name,
                    previous.loc.path,
                    previous.loc.line,
                )
                continue
            }
            ctx.codecs[codec.name] = codec
            field.codec_name, field.codec_identity, field.codec_size = codec.name, codec.id, codec.size
            code, rendered := schema_value_code(ctx, owner, field.tag_context, field.codec, true)
            if !rendered {error_at(field.loc, "cannot reference codec %s from %s", field.codec, owner.struct_name)}
            field.codec_code = code
        }
        if field.blend != "" {
            code, rendered := schema_value_code(ctx, owner, field.tag_context, field.blend, false)
            if !rendered {error_at(field.loc, "cannot reference blend %s from %s", field.blend, owner.struct_name)}
            field.blend_code = code
        }
    }
}

resolve_messages :: proc(s: ^Script) {
    seen := make(map[int]string, context.temp_allocator)
    for &message in s.messages {
        ctx := message.type_context
        _, label, valid := type_identity({message.payload_type, ctx, nil})
        if !valid {
            error_at(
                ctx.loc,
                "message %s: payload %s does not resolve in the handler's import scope",
                message.proc_name,
                message.payload_type,
            )
            continue
        }
        code, rendered := type_expression({message.payload_type, ctx, nil}, dir_of(s.path), &s.code_imports)
        if !rendered {error_at(ctx.loc, "cannot render message payload %s", message.payload_type); continue}
        message.payload_code, message.payload_name = code, label
        active := make(map[string]bool, context.temp_allocator)
        tag, found := wire_u8_constant(ctx, message.tag_ident, &active)
        if !found {
            error_at(
                ctx.loc,
                "message %s: tag %s must resolve to a byte literal or alias in the handler's import scope",
                message.proc_name,
                message.tag_ident,
            )
            continue
        }
        if previous, duplicate := seen[tag]; duplicate {
            error_at(
                ctx.loc,
                "message %s: tag %d is already used by %s on this owner",
                message.proc_name,
                tag,
                previous,
            )
        }
        seen[tag] = message.proc_name
        message.tag_value = tag
    }
}
