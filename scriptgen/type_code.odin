package scriptgen

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:strings"

// Code types include caches, backups and signals. Wire admissibility is a
// separate policy; rendering a pointer here never permits it in wire_type_layout.
Code_Type_Part :: struct {
    text:                     string,
    start, end, count, group: int,
}
Code_Type :: struct {
    text, kind: string,
    parts:      [dynamic]Code_Type_Part,
}

code_type_cache: map[string]Code_Type

code_type :: proc(text: string, integer := false) -> (Code_Type, bool) {
    cache_key := integer ? fmt.tprintf("integer:%s", text) : text
    if found, ok := code_type_cache[cache_key]; ok {return found, found.kind != ""}
    prefix :: "package type_code\nType :: "
    source := strings.concatenate({prefix, text}, context.temp_allocator)
    file := ast.File {
        src      = source,
        fullpath = "<type expression>",
    }
    p := parser.default_parser()
    p.err = proc(_: tokenizer.Pos, _: string, _: ..any) {}
    p.warn = p.err
    result := Code_Type {
        text = text,
    }
    if !parser.parse_file(&p, &file) {return result, false}
    add :: proc(result: ^Code_Type, source: string, n: ^ast.Node, count: int = 1, group: int = 0) {
        if n == nil {return}
        lo, hi := n.pos.offset, n.end.offset
        if _, typeid_token := n.derived.(^ast.Typeid_Type); typeid_token {hi = lo + len("typeid")}
        append(&result.parts, Code_Type_Part{source[lo:hi], lo - len(prefix), hi - len(prefix), count, group})
    }
    for decl in file.decls {
        vd, ok := decl.derived.(^ast.Value_Decl)
        if !ok || len(vd.values) != 1 {continue}
        if integer {
            #partial switch n in vd.values[0].derived {
            case ^ast.Paren_Expr:
                result.kind = "group"
                add(&result, source, n.expr)
            case ^ast.Binary_Expr:
                result.kind = n.op.text
                add(&result, source, n.left)
                add(&result, source, n.right)
            }
            continue
        }
        #partial switch n in vd.values[0].derived {
        case ^ast.Pointer_Type:
            result.kind = "pointer"; add(&result, source, n.elem)
        case ^ast.Multi_Pointer_Type:
            result.kind = "multi-pointer"; add(&result, source, n.elem)
        case ^ast.Array_Type:
            if n.len == nil {result.kind = "slice"; add(&result, source, n.elem)}
        case ^ast.Dynamic_Array_Type:
            result.kind = "dynamic-array"; add(&result, source, n.elem)
        case ^ast.Map_Type:
            result.kind = "map"; add(&result, source, n.key); add(&result, source, n.value)
        case ^ast.Call_Expr:
            // Opaque library generics such as gd.Signal1(T). Indexed structs
            // take the contextual declaration path before reaching this case.
            result.kind = "call"; add(&result, source, n.expr)
            for arg in n.args {add(&result, source, arg)}
        case ^ast.Proc_Type:
            result.kind = fmt.tprintf("proc:%v:%v:%v", n.calling_convention, n.tags, n.diverging)
            if n.params != nil {
                for f in n.params.list {add(&result, source, f.type, max(1, len(f.names)), 0)}
            }
            if n.results != nil {
                for f in n.results.list {add(&result, source, f.type, max(1, len(f.names)), 1)}
            }
        case:
            continue
        }
    }
    code_type_cache[cache_key] = result
    return result, result.kind != ""
}

code_builtin :: proc(value: Type_Use) -> (string, bool) {
    t := value.text
    if primitive := wire_primitive(t); primitive.ok {return primitive.kind, true}
    switch t {
    case "int",
         "uint",
         "uintptr",
         "i128",
         "u128",
         "b8",
         "b16",
         "b32",
         "b64",
         "string",
         "cstring",
         "rawptr",
         "any",
         "typeid",
         "complex32",
         "complex64",
         "complex128",
         "quaternion64",
         "quaternion128",
         "quaternion256":
        return t, true
    }
    if dot := strings.index_byte(t, '.'); dot >= 0 && !strings.contains(t, "(") {
        alias := t[:dot]
        if value.from.imports[alias] == "godot:godot" ||
           ((alias == "gd" || alias == "godot") && value.from.imports["@engine"] == "godot:godot") {
            return fmt.tprintf("gd.%s", t[dot + 1:]), true
        }
    }
    return "", false
}

code_type_identity :: proc(value: Type_Use, shape: Code_Type, depth: int) -> (identity, name: string, ok: bool) {
    key, label := strings.builder_make(context.temp_allocator), strings.builder_make(context.temp_allocator)
    fmt.sbprintf(&key, "%s(", shape.kind); fmt.sbprintf(&label, "%s(", shape.kind)
    for part in shape.parts {
        k, n, found := type_identity({part.text, value.from, value.bindings}, depth + 1)
        if !found {return "", "", false}
        fmt.sbprintf(&key, "%d:%d:%s;", part.group, part.count, k)
        fmt.sbprintf(&label, "%d:%d:%s;", part.group, part.count, n)
    }
    strings.write_byte(&key, ')'); strings.write_byte(&label, ')')
    return strings.to_string(key), strings.to_string(label), true
}

code_type_expression :: proc(
    value: Type_Use,
    shape: Code_Type,
    destination: string,
    imports: ^map[string]string,
    depth: int,
) -> (
    string,
    bool,
) {
    result := strings.builder_make(context.temp_allocator)
    at := 0
    for part in shape.parts {
        rendered, ok := type_expression({part.text, value.from, value.bindings}, destination, imports, depth + 1)
        if !ok {return "", false}
        strings.write_string(&result, shape.text[at:part.start])
        strings.write_string(&result, rendered)
        at = part.end
    }
    strings.write_string(&result, shape.text[at:])
    return strings.to_string(result), true
}
