package scriptgen

import "base:intrinsics"
import "core:fmt"
import "core:strconv"
import "core:strings"

// A type argument retains its caller's scope. Text substitution into the
// generic declaration's imports would silently select a different Local_Type.
Type_Use :: struct {
    text:     string,
    from:     Struct_Def,
    bindings: ^Type_Bindings,
}

Type_Bindings :: struct {
    values: map[string]Type_Use,
}

type_follow :: proc(value: Type_Use) -> Type_Use {
    value := value
    for _ in 0 ..< 64 {
        value.text = strings.trim_space(value.text)
        if value.bindings == nil {return value}
        next, found := value.bindings.values[value.text]
        if !found {return value}
        value = next
    }
    return {}
}

type_integer :: proc(value: Type_Use, depth: int = 0) -> (int, bool) {
    if depth >= 64 {return 0, false}
    value := type_follow(value)
    text, _ := strings.replace_all(value.text, "_", "", context.temp_allocator)
    if number, ok := strconv.parse_int(text); ok {return number, true}
    if named, found := wire_named_lookup(value.from, value.text); found && named.kind == .Alias {
        return type_integer({named.underlying, Struct_Def{dir = named.dir, imports = named.imports}, nil}, depth + 1)
    }
    // Fixed body/pool capacities often use a named count from another package.
    // Use the Odin parser for precedence and keep evaluating in the caller's scope.
    if strings.index_any(value.text, "+-*(") < 0 {return 0, false}
    expr, parsed := code_type(value.text, true)
    if !parsed || len(expr.parts) == 0 {return 0, false}
    lhs, ok := type_integer({expr.parts[0].text, value.from, value.bindings}, depth+1)
    if !ok || expr.kind == "group" {return lhs, ok}
    rhs, valid := type_integer({expr.parts[1].text, value.from, value.bindings}, depth+1)
    if !valid {return 0, false}
    result: int
    overflow: bool
    switch expr.kind {
    case "+": result, overflow = intrinsics.overflow_add(lhs, rhs)
    case "-": result, overflow = intrinsics.overflow_sub(lhs, rhs)
    case "*": result, overflow = intrinsics.overflow_mul(lhs, rhs)
    case: return 0, false
    }
    return result, !overflow
}

type_array :: proc(value: Type_Use) -> (count: int, elem: Type_Use, ok: bool) {
    value := type_follow(value)
    for _ in 0 ..< 64 {
        named, found := wire_named_lookup(value.from, value.text)
        if !found || named.kind != .Alias {break}
        value = type_follow({named.underlying, Struct_Def{dir = named.dir, imports = named.imports}, nil})
    }
    if !strings.has_prefix(value.text, "[") {return}
    end := strings.index_byte(value.text, ']')
    if end <= 1 || end == len(value.text) - 1 {return}
    count, ok = type_integer({value.text[1:end], value.from, value.bindings})
    if !ok || count <= 0 {return 0, {}, false}
    return count, {value.text[end + 1:], value.from, value.bindings}, true
}

// Transparent aliases retain their declaration scope while resolving.
type_struct :: proc(value: Type_Use, depth: int = 0) -> (Struct_Def, ^Type_Bindings, bool) {
    if depth >= 64 {return {}, nil, false}
    value := type_follow(value)
    text := value.text
    if text == "" {return {}, nil, false}
    if named, ok := wire_named_lookup(value.from, text); ok && named.kind == .Alias {
        return type_struct({named.underlying, Struct_Def{dir = named.dir, imports = named.imports}, nil}, depth + 1)
    }
    base := text
    arguments: [dynamic]string
    if paren := strings.index_byte(text, '('); paren >= 0 {
        if !strings.has_suffix(text, ")") {return {}, nil, false}
        base = strings.trim_space(text[:paren])
        arguments = split_type_params(text[paren + 1:len(text) - 1])
        if len(arguments) > 0 && strings.trim_space(arguments[len(arguments) - 1]) == "" {
            pop(&arguments)
        }
    }
    defer delete(arguments)
    def, found := wire_struct_lookup(value.from, base)
    if !found || len(arguments) != len(def.poly_params) {return {}, nil, false}
    if len(arguments) == 0 {return def, nil, true}
    bindings := new(Type_Bindings, context.temp_allocator)
    bindings.values = make(map[string]Type_Use, context.temp_allocator)
    for parameter, i in def.poly_params {
        bindings.values[parameter] = {arguments[i], value.from, value.bindings}
    }
    return def, bindings, true
}

type_identity :: proc(value: Type_Use, depth: int = 0) -> (identity, name: string, ok: bool) {
    if depth >= 64 {return "", "", false}
    value := type_follow(value)
    text := value.text
    if builtin, ok := code_builtin(value); ok {return builtin, builtin, true}
    if count, elem, array := type_array(value); array {
        key, label, found := type_identity(elem, depth + 1)
        return fmt.tprintf("[%d]%s", count, key), fmt.tprintf("[%d]%s", count, label), found
    }
    if named, found := wire_named_lookup(value.from, text); found {
        if named.kind == .Alias {
            return type_identity(
                {named.underlying, Struct_Def{dir = named.dir, imports = named.imports}, nil},
                depth + 1,
            )
        }
        return named.id, named.name, true
    }
    if def, bindings, found := type_struct(value); found {
        return type_struct_identity(def, bindings, depth)
    }
    if shape, ok := code_type(text); ok {return code_type_identity(value, shape, depth)}
    return "", "", false
}

type_reference :: proc(dir, name, destination: string, imports: ^map[string]string) -> string {
    if dir == destination {return name}
    alias, path := composed_pkg_ref(dir, destination)
    if alias == "" {return ""}
    switch path {
    case "godot:kit/net":
        alias = "knet"
    case "godot:kit/sim":
        alias = "ksim"
    case "godot:kit/session":
        alias = "ksess"
    case "godot:kit/boot":
        alias = "kboot"
    case "godot:kit/netgd":
        alias = "netgd"
    case "godot:runtime":
        alias = "rt"
    case "godot:gdext":
        alias = "gdext"
    case:
    }
    imports[alias] = path
    return fmt.tprintf("%s.%s", alias, name)
}

// Render into a particular package, accumulating only the imports it needs.
// Preserve public alias spellings so an alias may hide a private implementation.
type_expression :: proc(
    value: Type_Use,
    destination: string,
    imports: ^map[string]string,
    depth: int = 0,
) -> (
    string,
    bool,
) {
    if depth >= 64 {return "", false}
    value := type_follow(value)
    text := value.text
    if builtin, ok := code_builtin(value); ok {return builtin, true}
    if named, found := wire_named_lookup(value.from, text); found {
        result := type_reference(named.dir, named.name, destination, imports)
        return result, result != ""
    }
    if count, elem, array := type_array(value); array {
        child, ok := type_expression(elem, destination, imports, depth + 1)
        return fmt.tprintf("[%d]%s", count, child), ok
    }
    if def, bindings, found := type_struct(value); found {
        result := strings.builder_make(context.temp_allocator)
        reference := type_reference(def.dir, def.name, destination, imports)
        if reference == "" {return "", false}
        strings.write_string(&result, reference)
        if len(def.poly_params) > 0 {
            strings.write_byte(&result, '(')
            for parameter, i in def.poly_params {
                if i > 0 {strings.write_string(&result, ", ")}
                arg := bindings.values[parameter]
                if def.poly_kinds[i] == "typeid" {
                    part, ok := type_expression(arg, destination, imports, depth + 1)
                    if !ok {return "", false}
                    strings.write_string(&result, part)
                } else {
                    n, ok := type_integer(arg)
                    if !ok {return "", false}
                    fmt.sbprintf(&result, "%d", n)
                }
            }
            strings.write_byte(&result, ')')
        }
        return strings.to_string(result), true
    }
    if shape, ok := code_type(text); ok {return code_type_expression(value, shape, destination, imports, depth)}
    return "", false
}

type_rebase :: proc(value: Type_Use, destination: string) -> (Type_Use, bool) {
    imports := make(map[string]string, context.temp_allocator)
    imports["@engine"] = "godot:godot"
    text, ok := type_expression(value, destination, &imports)
    return {text, Struct_Def{dir = destination, imports = imports}, nil}, ok
}

// Constraint support is semantic: transparent numeric aliases are numeric,
// enums are checked as enums, and unrelated structs are never guessed to be one.
type_rule_kind :: proc(value: Type_Use, depth: int = 0) -> (kind: string, is_enum: bool) {
    if depth >= 64 {return "", false}
    value := type_follow(value)
    if p := wire_primitive(value.text); p.ok {return p.kind, false}
    if named, ok := wire_named_lookup(value.from, value.text); ok {
        if named.kind == .Enum {return "enum", true}
        if named.kind == .Alias {
            return type_rule_kind(
                {named.underlying, Struct_Def{dir = named.dir, imports = named.imports}, nil},
                depth + 1,
            )
        }
    }
    return "", false
}

type_struct_identity :: proc(
    def: Struct_Def,
    bindings: ^Type_Bindings,
    depth: int = 0,
) -> (
    identity, label: string,
    ok: bool,
) {
    key, name := strings.builder_make(context.temp_allocator), strings.builder_make(context.temp_allocator)
    strings.write_string(&key, def.id)
    strings.write_string(&name, def.name)
    if len(def.poly_params) > 0 {
        strings.write_byte(&key, '('); strings.write_byte(&name, '(')
        for parameter, i in def.poly_params {
            if i > 0 {strings.write_byte(&key, ','); strings.write_byte(&name, ',')}
            arg := bindings.values[parameter]
            if def.poly_kinds[i] == "typeid" {
                ak, an, aok := type_identity(arg, depth + 1)
                if !aok {return "", "", false}
                strings.write_string(&key, ak); strings.write_string(&name, an)
            } else {
                n, nok := type_integer(arg)
                if !nok {return "", "", false}
                fmt.sbprintf(&key, "%d", n); fmt.sbprintf(&name, "%d", n)
            }
        }
        strings.write_byte(&key, ')'); strings.write_byte(&name, ')')
    }
    return strings.to_string(key), strings.to_string(name), true

}

// Only contextual parameters require rewriting; ordinary opaque fields retain
// their original declaring scope and remain the compiler's responsibility.
type_materialize :: proc(value: Type_Use, destination: string) -> (Type_Use, map[string]string, bool) {
    value := value
    if value.bindings == nil {return value, nil, true}
    mentions := false
    i := 0
    for i < len(value.text) {
        if (value.text[i] >= 'A' && value.text[i] <= 'Z') ||
           (value.text[i] >= 'a' && value.text[i] <= 'z') ||
           value.text[i] == '_' {
            start := i
            for i < len(value.text) && is_ident_byte(value.text[i]) {i += 1}
            if _, found := value.bindings.values[value.text[start:i]]; found {mentions = true}
        } else {i += 1}
    }
    if !mentions {value.bindings = nil; return value, nil, true}
    result, ok := type_rebase(value, destination)
    return result, result.from.imports, ok
}
