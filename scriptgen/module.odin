package scriptgen

import "core:fmt"
import "core:strings"
import decl "godot:decl"

// The module boundary is fixed before import validation or indexing. Code
// identities use declaring directories; generated import aliases are only
// local spellings and never become wire identities.
g_module_root: string

module_contains_dir :: proc(dir: string) -> bool {
    return(
        g_module_root != "" &&
        (dir == g_module_root ||
                strings.has_prefix(dir, strings.concatenate({g_module_root, "/"}, context.temp_allocator))) \
    )
}

module_import_dir :: proc(from_dir, imp: string) -> (string, bool) {
    if strings.contains_rune(imp, ':') {return "", false}
    dir := resolve_lexical(from_dir, imp)
    return dir, module_contains_dir(dir)
}

composition_import_dir :: proc(from_dir, imp: string) -> (string, bool) {
    if dir, ok := resolve_import_dir(imp); ok {return dir, true}
    return module_import_dir(from_dir, imp)
}

// Both inputs are normalized absolute directories inside this module.
module_relative_import :: proc(from_dir, to_dir: string) -> string {
    from := strings.split(from_dir, "/", context.temp_allocator)
    to := strings.split(to_dir, "/", context.temp_allocator)
    shared := 0
    for shared < min(len(from), len(to)) && from[shared] == to[shared] {shared += 1}
    path := strings.builder_make(context.temp_allocator)
    for _ in shared ..< len(from) {strings.write_string(&path, "../")}
    strings.write_string(&path, strings.join(to[shared:], "/", context.temp_allocator))
    return strings.to_string(path)
}

module_package_ref :: proc(from_dir, to_dir: string) -> (alias, path: string) {
    relative := rel_to_root(g_module_root, to_dir)
    return fmt.tprintf("_kit_pkg_%x", decl.fnv1a64(relative)), module_relative_import(from_dir, to_dir)
}

module_script_scope :: proc(ctx: ^Module_Ctx, from: ^Script) -> map[string]^Script {
    scope := make(map[string]^Script, context.temp_allocator)
    own_dir := dir_of(from.path)
    for pkg in ctx.packages {
        if pkg.dir == own_dir {
            for &p in pkg.pending {scope[p.script.struct_name] = &p.script}
        }
    }
    for alias, path in from.imports {
        dir, ok := module_import_dir(own_dir, path)
        if !ok {continue}
        for pkg in ctx.packages {
            if pkg.dir != dir {continue}
            for &p in pkg.pending {scope[fmt.tprintf("%s.%s", alias, p.script.struct_name)] = &p.script}
        }
    }
    return scope
}

module_type_matches :: proc(path: string, imports: map[string]string, spelling: string, target: ^Script) -> bool {
    if !strings.has_prefix(spelling, "^") {return false}
    def, _, ok := type_struct({spelling[1:], Struct_Def{dir = dir_of(path), imports = imports}, nil})
    return ok && def.dir == dir_of(target.path) && def.name == target.struct_name

}

entity_type :: proc(e: Entity_Tag) -> string {
    return e.type_expr != "" ? e.type_expr : e.target
}

entity_helper :: proc(e: Entity_Tag) -> string {
    return e.helper != "" ? e.helper : decl.snake_name(e.target)
}

entity_descriptor_prefix :: proc(e: Entity_Tag) -> string {
    if e.binding_prefix != "" {return e.binding_prefix}
    return entity_source_prefix(e)
}

entity_source_prefix :: proc(e: Entity_Tag) -> string {
    name := decl.snake_name(e.target)
    return e.pkg_alias != "" ? fmt.tprintf("%s.%s", e.pkg_alias, name) : name
}

module_type_identity :: proc(from: Struct_Def, spelling: string) -> (identity, name: string) {
    key, label, ok := type_identity({spelling, from, nil})
    if !ok {
        error_at(from.loc, "input type %q does not resolve; check generic argument count and use named types or integer literal arguments", spelling)
    }
    return key, label
}
