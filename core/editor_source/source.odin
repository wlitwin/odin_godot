package editor_source

import "core:fmt"
import "core:strings"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import vmem "core:mem/virtual"
import decl "godot:decl"
import "base:runtime"

// The pinned tokenizer checks its initialization flag before taking its lock,
// without checking again inside it. Initialize before editor/test worker threads
// can race their first parse (the AST/parser data remains per call).
@(init)
initialize_tokenizer :: proc "contextless" () {
    context = runtime.default_context()
    t: tokenizer.Tokenizer
    tokenizer.init(&t, "", "editor.odin", quiet)
}

Function :: struct {
    name, exposed, receiver: string,
    line: int,
}

Info :: struct {
    script, godot_alias: string,
    functions: [dynamic]Function,
}

@(private)
quiet :: proc(pos: tokenizer.Pos, msg: string, args: ..any) {}

// Parse declarations, so comments, strings and nested local procedures never
// become editor functions. Recoverable syntax errors leave earlier declarations
// available while the developer is still typing.
inspect :: proc(source: string, allocator := context.allocator) -> (info: Info) {
    arena: vmem.Arena
    if vmem.arena_init_growing(&arena) != nil {return}
    defer vmem.arena_destroy(&arena)
    context.allocator = vmem.arena_allocator(&arena)
    p := parser.default_parser()
    p.err, p.warn = quiet, quiet
    file := ast.File{fullpath = "editor.odin", src = source}
    _ = parser.parse_file(&p, &file)
    info.functions = make([dynamic]Function, allocator)

    for imp in file.imports {
        if strings.trim(imp.fullpath, "\"") == "godot:godot" {
            alias := imp.name.text
            if alias == "" {alias = "godot"}
            if alias != "_" {info.godot_alias = strings.clone(alias, allocator)}
        }
    }
    declarations := make([dynamic]^ast.Node)
    collect :: proc(node: ^ast.Node, out: ^[dynamic]^ast.Node) {
        if node == nil {return}
        #partial switch n in node.derived {
        case ^ast.When_Stmt:
            collect(n.body, out)
            collect(n.else_stmt, out)
        case ^ast.Block_Stmt:
            for child in n.stmts {collect(child, out)}
        case ^ast.Value_Decl:
            append(out, node)
        case:
        }
    }
    for node in file.decls {collect(node, &declarations)}
    for node in declarations {
        value := node.derived.(^ast.Value_Decl)
        if len(value.names) != 1 || len(value.values) != 1 {continue}
        name, named := value.names[0].derived.(^ast.Ident)
        if !named {continue}
        #partial switch v in value.values[0].derived {
        case ^ast.Struct_Type:
            if v.fields == nil || len(v.fields.list) == 0 || len(v.fields.list[0].names) == 0 {continue}
            first, ok := v.fields.list[0].names[0].derived.(^ast.Ident)
            if ok && first.name == "owner" {
                if info.script != "" { // ambiguous scripts are already generator errors
                    delete(info.script, allocator)
                    info.script = ""
                    return
                }
                info.script = strings.clone(name.name, allocator)
            }
        case ^ast.Proc_Lit:
            receiver := ""
            if v.type != nil && v.type.params != nil && len(v.type.params.list) > 0 {
                field := v.type.params.list[0]
                if field.type != nil {
                    if pointer, ok := field.type.derived.(^ast.Pointer_Type); ok && pointer.elem != nil {
                        if ident, named := pointer.elem.derived.(^ast.Ident); named {receiver = ident.name}
                    }
                }
            }
            exposed := ""
            for attribute in value.attributes {
                for elem in attribute.elems {
                    ident, named := elem.derived.(^ast.Ident)
                    if pair, paired := elem.derived.(^ast.Field_Value); paired {
                        ident, named = pair.field.derived.(^ast.Ident)
                    }
                    if named && (ident.name == "gd_method" || ident.name == "gd_rpc") {
                        exposed = name.name
                        if receiver != "" {
                            prefix := strings.concatenate({decl.snake_name(receiver), "_"})
                            exposed = strings.trim_prefix(exposed, prefix)
                        }
                    }
                }
            }
            append(&info.functions, Function{strings.clone(name.name, allocator), strings.clone(exposed, allocator),
                                             strings.clone(receiver, allocator), name.pos.line})
        case:
        }
    }
    return
}

find_callback :: proc(info: Info, name: string) -> int {
    for fn in info.functions {
        if fn.exposed == name && fn.receiver == info.script {return fn.line}
    }
    return -1
}

outline_name :: proc(info: Info, fn: Function) -> string {
    if fn.exposed != "" && fn.receiver == info.script {return fn.exposed}
    // Godot also uses this list to place connection gutters. A plain helper
    // with a method's exposed name must not steal its gutter or outline entry.
    if find_callback(info, fn.name) >= 0 {return fmt.tprintf("%s (Odin helper)", fn.name)}
    return fn.name
}

callback_problem :: proc(info: Info, name: string) -> string {
    if info.script == "" {return "the target needs exactly one owner-first script struct"}
    if info.godot_alias == "" {return "the target needs a godot:godot import"}
    generated := fmt.tprintf("%s_%s", decl.snake_name(info.script, context.temp_allocator), name)
    for fn in info.functions {
        if fn.name == generated {
            return fmt.tprintf("%s already exists without this Godot method; give it a ^%s receiver and @(gd_method), or rename the helper", generated, info.script)
        }
    }
    return ""
}

// Bindings preserve acronym spellings differently from Godot (Node2D/Node2d).
// Resolve against the shipped declarations, not another PascalCase algorithm.
normalize :: proc(name: string, allocator := context.temp_allocator) -> string {
    b := strings.builder_make(allocator)
    for c in name {
        if c == '_' {continue}
        strings.write_rune(&b, c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c)
    }
    return strings.to_string(b)
}

// ScriptCreateDialog supplies a filename stem, which may be an Odin keyword or
// contain punctuation. The path remains its identity; emit a valid type name.
script_identifier :: proc(stem: string, allocator := context.allocator) -> string {
    b := strings.builder_make(allocator)
    upper := true
    if len(stem) > 0 && stem[0] >= '0' && stem[0] <= '9' {strings.write_byte(&b, '_')}
    for c in stem {
        if c == '_' || !(c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9') {
            strings.write_byte(&b, '_')
            upper = true
            continue
        }
        strings.write_rune(&b, upper && c >= 'a' && c <= 'z' ? c - ('a' - 'A') : c)
        upper = false
    }
    text := strings.to_string(b)
    if strings.trim(text, "_") == "" {delete(text, allocator); return strings.clone("NewScript", allocator)}
    return text
}

index_bindings :: proc(source: string, index: ^map[string]string, allocator := context.allocator) {
    text := source
    for line in strings.split_lines_iterator(&text) {
        line := strings.trim_space(line)
        at := strings.index(line, " :: ")
        if at <= 0 || line[0] < 'A' || line[0] > 'Z' {continue}
        name := line[:at]
        valid := true
        for c in name {
            if !(c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '_') {valid = false}
        }
        key := normalize(name)
        if valid && !(key in index^) {index^[strings.clone(key, allocator)] = strings.clone(name, allocator)}
    }
}

argument_type :: proc(hint, alias: string, bindings: map[string]string, allocator := context.allocator) -> string {
    switch hint {
    case "bool": return strings.clone("bool", allocator)
    case "int": return strings.clone("i64", allocator)
    case "float": return strings.clone("f64", allocator)
    case "String": return strings.clone("string", allocator)
    }
    name := bindings[normalize(hint)]
    if name == "" {name = "Variant"} // untyped/custom values retain their actual engine type
    return strings.concatenate({alias, ".", name}, allocator)
}

@(private)
parameter_name :: proc(name: string, used: ^map[string]bool) -> string {
    b := strings.builder_make(context.temp_allocator)
    for c in strings.trim_space(name) {
        strings.write_rune(&b, c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '_' ? c : '_')
    }
    base := strings.to_string(b)
    if base == "" || base == "_" {base = "argument"}
    if base[0] >= '0' && base[0] <= '9' {base = strings.concatenate({"arg_", base}, context.temp_allocator)}
    for keyword in ([]string{"package", "import", "proc", "struct", "union", "enum", "map", "bit_set", "if", "else", "for", "switch", "case", "in", "not_in", "return", "defer", "when", "where", "using", "cast", "transmute", "auto_cast", "distinct", "context", "or_else", "or_return", "break", "continue", "fallthrough", "nil", "true", "false", "dynamic", "matrix", "foreign", "do"}) {
        if base == keyword {base = strings.concatenate({base, "_"}, context.temp_allocator); break}
    }
    result := base
    for suffix := 2; (result in used^); suffix += 1 {result = fmt.tprintf("%s_%d", base, suffix)}
    used^[result] = true
    return result
}

make_function :: proc(info: Info, name: string, args: []string, bindings: map[string]string, allocator := context.allocator) -> string {
    if callback_problem(info, name) != "" {return ""}
    b := strings.builder_make(allocator)
    prefix := decl.snake_name(info.script, context.temp_allocator)
    // Keep annotation and signature on one line: Godot positions the caret on
    // the next line after appending a newly generated callback.
    fmt.sbprintf(&b, "@(gd_method) %s_%s :: proc(self: ^%s", prefix, name, info.script)
    used := make(map[string]bool, context.temp_allocator)
    used["self"] = true
    for arg in args {
        at := strings.index_byte(arg, ':')
        raw_name, hint := arg, ""
        if at >= 0 {raw_name, hint = arg[:at], strings.trim_space(arg[at+1:])}
        typ := argument_type(hint, info.godot_alias, bindings, context.temp_allocator)
        fmt.sbprintf(&b, ", %s: %s", parameter_name(raw_name, &used), typ)
    }
    strings.write_string(&b, ") {\n\t// Handle the signal.\n}\n")
    return strings.to_string(b)
}
