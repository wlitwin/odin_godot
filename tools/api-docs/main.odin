// Export declarations through Odin's parser, without compiling or linking SDK
// packages. Source ranges preserve defaults, generics, tags, and calling conventions.
package main

import "core:encoding/json"
import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:os"
import "core:strings"

Member :: struct {
    name, signature, docs: string,
    line: int,
}

Symbol :: struct {
    name, kind, signature, docs, source, condition: string,
    line: int,
    private: bool,
    attributes, overloads: [dynamic]string,
    members: [dynamic]Member,
}

File :: struct {
    source, package_name: string,
    imports: map[string]string,
    symbols: [dynamic]Symbol,
}

text :: proc(file: ^ast.File, node: ^ast.Node) -> string {
    if node == nil { return "" }
    lo, hi := node.pos.offset, node.end.offset
    assert(lo >= 0 && hi >= lo && hi <= len(file.src))
    return strings.trim_space(file.src[lo:hi])
}

join_comments :: proc(a, b: string) -> string {
    if a == "" { return b }
    if b == "" { return a }
    return fmt.aprintf("%s\n\n%s", a, b)
}

comments :: proc(group: ^ast.Comment_Group) -> string {
    if group == nil { return "" }
    out: [dynamic]string
    for token in group.list {
        value := token.text
        if strings.has_prefix(value, "//") {
            value = strings.trim_prefix(value[2:], " ")
        } else if strings.has_prefix(value, "/*") {
            value = strings.trim_space(value[2:len(value)-2])
        }
        append(&out, value)
    }
    return strings.join(out[:], "\n")
}

leading_comments :: proc(file: ^ast.File, group: ^ast.Comment_Group) -> string {
    if group == nil { return "" }
    offset := group.pos.offset
    start := strings.last_index(file.src[:offset], "\n") + 1
    // The parser can attach a preceding field's trailing comment as a leading
    // group. Only whitespace may precede a genuine documentation comment.
    if strings.trim_space(file.src[start:offset]) != "" { return "" }
    return comments(group)
}

private_attribute :: proc(attributes: []^ast.Attribute) -> bool {
    for attribute in attributes {
        for element in attribute.elems {
            #partial switch value in element.derived {
            case ^ast.Ident:
                if value.name == "private" { return true }
            case ^ast.Field_Value:
                if field, ok := value.field.derived.(^ast.Ident); ok && field.name == "private" {
                    return true
                }
            }
        }
    }
    return false
}

field_members :: proc(out: ^Symbol, file: ^ast.File, fields: ^ast.Field_List) {
    if fields == nil { return }
    for field in fields.list {
        for name in field.names {
            name_text := text(file, &name.expr_base)
            if name_text == "_" { continue }
            docs := leading_comments(file, field.docs)
            if tail := comments(field.comment); tail != "" {
                docs = join_comments(docs, tail)
            }
            append(&out.members, Member{name_text, text(file, &field.node), docs, field.pos.line})
        }
    }
}

expression_members :: proc(out: ^Symbol, file: ^ast.File, expressions: []^ast.Expr) {
    for expression in expressions {
        name := text(file, &expression.expr_base)
        if field, ok := expression.derived.(^ast.Field_Value); ok {
            name = text(file, &field.field.expr_base)
        }
        docs := ""
        for group in file.comments {
            if group.end.line == expression.pos.line - 1 {
                docs = join_comments(docs, leading_comments(file, group))
            } else if group.pos.line == expression.end.line && group.pos.offset >= expression.end.offset {
                docs = join_comments(docs, comments(group))
            }
        }
        append(&out.members, Member{name, text(file, &expression.expr_base), docs, expression.pos.line})
    }
}

declarations :: proc(out: ^File, file: ^ast.File, statement: ^ast.Stmt, condition: string, private: bool) {
    if statement == nil { return }
    #partial switch declaration in statement.derived {
    case ^ast.Block_Stmt:
        for child in declaration.stmts { declarations(out, file, child, condition, private) }
    case ^ast.When_Stmt:
        expression := text(file, &declaration.cond.expr_base)
        prefix := condition
        if prefix != "" { prefix = fmt.aprintf("%s && ", prefix) }
        declarations(out, file, declaration.body, fmt.aprintf("%s(%s)", prefix, expression), private)
        declarations(out, file, declaration.else_stmt, fmt.aprintf("%s!(%s)", prefix, expression), private)
    case ^ast.Foreign_Block_Decl:
        declarations(out, file, declaration.body, condition, private || private_attribute(declaration.attributes[:]))
    case ^ast.Value_Decl:
        for name, i in declaration.names {
            symbol := Symbol {
                name = text(file, &name.expr_base),
                kind = declaration.is_mutable ? "variable" : "constant",
                signature = text(file, &declaration.node.decl_base.stmt_base),
                docs = leading_comments(file, declaration.docs),
                source = out.source,
                line = name.pos.line,
                condition = condition,
                private = private || private_attribute(declaration.attributes[:]),
            }
            if symbol.name == "_" { continue }
            if tail := comments(declaration.comment); tail != "" {
                symbol.docs = join_comments(symbol.docs, tail)
            }
            for attribute in declaration.attributes {
                append(&symbol.attributes, text(file, &attribute.node))
            }
            if !declaration.is_mutable && i < len(declaration.values) {
                expression := declaration.values[i]
                #partial switch value in expression.derived {
                case ^ast.Proc_Lit:
                    symbol.kind = "procedure"
                    if value.body != nil {
                        symbol.signature = strings.trim_space(file.src[declaration.pos.offset:value.body.pos.offset])
                    }
                case ^ast.Proc_Group:
                    symbol.kind = "overload"
                    for target in value.args { append(&symbol.overloads, text(file, &target.expr_base)) }
                case ^ast.Struct_Type:
                    symbol.kind = "struct"
                    field_members(&symbol, file, value.fields)
                case ^ast.Enum_Type:
                    symbol.kind = "enum"
                    expression_members(&symbol, file, value.fields)
                case ^ast.Union_Type:
                    symbol.kind = "union"
                    expression_members(&symbol, file, value.variants)
                case ^ast.Array_Type, ^ast.Dynamic_Array_Type, ^ast.Fixed_Capacity_Dynamic_Array_Type,
                     ^ast.Map_Type, ^ast.Pointer_Type, ^ast.Multi_Pointer_Type, ^ast.Matrix_Type,
                     ^ast.Relative_Type, ^ast.Typeid_Type, ^ast.Bit_Set_Type:
                    symbol.kind = "type"
                case ^ast.Bit_Field_Type:
                    symbol.kind = "type"
                case ^ast.Distinct_Type:
                    symbol.kind = "type"
                case ^ast.Proc_Type:
                    symbol.kind = "type"
                    field_members(&symbol, file, value.params)
                case ^ast.Helper_Type:
                    symbol.kind = "type"
                case ^ast.Ident, ^ast.Selector_Expr:
                    symbol.kind = "alias"
                case ^ast.Call_Expr:
                    // Generic type instantiation and compile-time value calls
                    // share this syntax. Preserve it without guessing a type.
                    #partial switch callee in value.expr.derived {
                    case ^ast.Ident, ^ast.Selector_Expr:
                        symbol.kind = "alias"
                    }
                }
            }
            append(&out.symbols, symbol)
        }
    }
}

main :: proc() {
    if len(os.args) != 4 {
        fmt.eprintln("usage: api-docs REPOSITORY FILE-LIST.JSON OUTPUT.JSON")
        os.exit(2)
    }
    input, error := os.read_entire_file(os.args[2], context.allocator)
    assert(error == nil)
    paths: []string
    assert(json.unmarshal(input, &paths) == nil)
    files: [dynamic]File
    for path in paths {
        fullpath := fmt.aprintf("%s/%s", os.args[1], path)
        source, read_error := os.read_entire_file(fullpath, context.allocator)
        assert(read_error == nil)
        file := ast.File{src = string(source), fullpath = fullpath}
        p := parser.default_parser()
        if !parser.parse_file(&p, &file) || file.syntax_error_count != 0 {
            fmt.eprintf("Cannot document %s: source parsing failed\n", path)
            os.exit(1)
        }
        tags := parser.parse_file_tags(file)
        if tags.ignore { continue }
        out := File{source = path, package_name = file.pkg_name, imports = make(map[string]string)}
        for declaration in file.imports {
            value := declaration.relpath.text
            if len(value) >= 2 { value = value[1:len(value)-1] }
            alias := declaration.name.text
            if alias == "" {
                parts := strings.split(value, "/")
                alias = parts[len(parts)-1]
                if colon := strings.last_index(alias, ":"); colon >= 0 { alias = alias[colon+1:] }
            }
            out.imports[alias] = value
        }
        conditions: [dynamic]string
        for tag in file.tags {
            if strings.has_prefix(tag.text, "#+build ") { append(&conditions, tag.text) }
        }
        condition := strings.join(conditions[:], "\n")
        for declaration in file.decls {
            declarations(&out, &file, declaration, condition, tags.private != .Public)
        }
        append(&files, out)
    }
    encoded, encode_error := json.marshal(files[:])
    assert(encode_error == nil)
    assert(os.write_entire_file(os.args[3], encoded) == nil)
}
