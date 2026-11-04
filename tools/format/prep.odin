// Helper for tools/format/format.sh (see there for the whole pipeline).
//
//   prep split  LIST   rewrite each file named in LIST (one path per line) in place so every
//                      statement starts its own line: non-empty one-line blocks are opened,
//                      `do` bodies become braced blocks, `;`-joined statements are split, and
//                      block constructs (if/for/switch/when/blocks, procedure and type
//                      declarations) get a blank line between them and their neighbours.
//                      Only newlines are inserted (plus `do` -> `{ }`); odinfmt reindents after.
//                      odinfmt cannot do this itself: it keeps single-line blocks as written.
//   prep verify LIST   each line of LIST is `ORIGINAL<TAB>FORMATTED`. A pair passes when both
//                      parse and have the same tokens, comments and AST shape, ignoring only
//                      what formatting legitimately changes: semicolons, `do`, braces and
//                      grouping and attribute parentheses (the AST shape still pins block
//                      structure and precedence), trailing commas, and the `_:` odinfmt gives
//                      unnamed parameters (`proc(u32)` and `proc(_: u32)` are the same type).
//
// Both print one `PATH<TAB>REASON` line per file they reject and exit 1 if there was any.
package odinfmt_prep

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"
import "core:os"
import "core:reflect"
import "core:slice"
import "core:strings"

main :: proc() {
    if len(os.args) != 3 || (os.args[1] != "split" && os.args[1] != "verify") {
        fmt.eprintln("usage: prep split LIST | prep verify LIST")
        os.exit(2)
    }

    list, err := os.read_entire_file_from_path(os.args[2], context.allocator)

    if err != nil {
        fmt.eprintfln("prep: cannot read %s: %v", os.args[2], err)
        os.exit(2)
    }

    failed := 0

    for line in strings.split_lines(string(list)) {
        if line == "" {
            continue
        }

        reason: string
        path := line

        if os.args[1] == "split" {
            reason = split_file(line)
        } else {
            orig, _, formatted := strings.partition(line, "\t")
            path = orig
            reason = verify_pair(orig, formatted)
        }

        if reason != "" {
            fmt.printfln("%s\t%s", path, reason)
            failed += 1
        }

        free_all(context.temp_allocator)
    }

    os.exit(failed > 0 ? 1 : 0)
}

// ---------------------------------------------------------------------------
// split
// ---------------------------------------------------------------------------

Edit :: struct {
    offset: int, // byte offset in the original source
    remove: int, // bytes replaced at offset
    text:   string,
    seq:    int, // insertion order breaks ties at one offset
}

Splitter :: struct {
    src:   string,
    edits: [dynamic]Edit,
}

split_file :: proc(path: string) -> string {
    context.allocator = context.temp_allocator
    data, err := os.read_entire_file_from_path(path, context.allocator)

    if err != nil {
        return fmt.tprintf("cannot read: %v", err)
    }

    file, ok := parse(path, string(data))

    if !ok {
        return "does not parse"
    }

    s := Splitter {
        src = file.src,
    }
    split_list(&s, file.decls[:])
    v := ast.Visitor {
        visit = split_visit,
        data  = &s,
    }

    for decl in file.decls {
        ast.walk(&v, decl)
    }

    if len(s.edits) == 0 {
        return ""
    }

    out, applied := apply(s.src, s.edits[:])

    if !applied {
        return "overlapping edits"
    }

    if werr := os.write_entire_file(path, out); werr != nil {
        return fmt.tprintf("cannot write: %v", werr)
    }

    return ""
}

split_visit :: proc(v: ^ast.Visitor, node: ^ast.Node) -> ^ast.Visitor {
    if node == nil {
        return nil
    }

    s := (^Splitter)(v.data)

    #partial switch n in node.derived {
    case ^ast.Block_Stmt:
        split_block(s, n)
    case ^ast.Case_Clause:
        if len(n.body) > 0 {
            if n.body[0].pos.line == n.terminator.pos.line {
                add(s, n.terminator.pos.offset + len(n.terminator.text), 0, "\n")
            }

            split_list(s, n.body)
        }
    }

    return v
}

split_block :: proc(s: ^Splitter, b: ^ast.Block_Stmt) {
    if len(b.stmts) == 0 {
        return
    }

    if b.uses_do {
        // The parser keeps no position for `do` itself: the block opens at its one statement.
        at := find_do(s.src, b.open.offset)

        if at < 0 {
            return // a comment between `do` and its statement: leave it as written
        }

        same_line := strings.index_byte(s.src[at:b.open.offset], '\n') < 0
        add(s, at, len("do"), same_line ? "{\n" : "{")
        add(s, b.close.offset, 0, "\n}")
        return
    }

    open, close := b.open, b.close

    if open.line == 0 {
        // Switch bodies record only their extent: `{` through just past `}`.
        open, close = b.pos, b.end
        close.offset -= 1
    }

    if s.src[open.offset] != '{' || s.src[close.offset] != '}' {
        return // positions the parser left in an unexpected place: leave the block as written
    }

    if b.stmts[0].pos.line == open.line {
        add(s, open.offset + 1, 0, "\n")
    }

    split_list(s, b.stmts)

    if b.stmts[len(b.stmts) - 1].end.line == close.line {
        add(s, close.offset, 0, "\n")
    }
}

// Statements that share a line are broken right after the earlier one (and its `;`), so
// prefixes on the later one (labels, `#partial`, …) stay put. A block construct is also set
// off from its neighbours by a blank line, placed after the earlier statement's line so the
// later one keeps its comments and attributes.
split_list :: proc(s: ^Splitter, stmts: []^ast.Stmt) {
    for i in 1 ..< len(stmts) {
        prev, next := stmts[i - 1], stmts[i]
        blank := is_construct(prev) || is_construct(next)

        if prev.end.line == next.pos.line {
            at := prev.end.offset

            for at < len(s.src) && (s.src[at] == ' ' || s.src[at] == '\t') {
                at += 1
            }

            if at < len(s.src) && s.src[at] == ';' {
                at += 1
            }

            add(s, at, 0, blank ? "\n\n" : "\n")
            continue
        }

        if !blank {
            continue
        }

        eol := strings.index_byte(s.src[prev.end.offset:], '\n')

        if eol < 0 {
            continue
        }

        eol += prev.end.offset

        if !has_blank_line(s.src, eol, next.pos.offset) {
            // After the newline, not at prev's end: a `do` body's closing `}` goes there.
            add(s, eol + 1, 0, "\n")
        }
    }
}

// Block statements, and declarations of procedures and multi-line types.
is_construct :: proc(stmt: ^ast.Stmt) -> bool {
    #partial switch n in stmt.derived {
    case ^ast.If_Stmt, ^ast.When_Stmt, ^ast.For_Stmt, ^ast.Range_Stmt, ^ast.Inline_Range_Stmt:
        return true
    case ^ast.Switch_Stmt, ^ast.Type_Switch_Stmt, ^ast.Block_Stmt, ^ast.Foreign_Block_Decl:
        return true
    case ^ast.Defer_Stmt:
        return n.stmt != nil && is_construct(n.stmt)
    case ^ast.Value_Decl:
        for value in n.values {
            if is_construct_value(value) {
                return true
            }
        }
    }

    return false
}

is_construct_value :: proc(expr: ^ast.Expr) -> bool {
    #partial switch v in expr.derived {
    case ^ast.Proc_Lit:
        return v.body != nil
    case ^ast.Distinct_Type:
        return is_construct_value(v.type)
    case ^ast.Struct_Type, ^ast.Union_Type, ^ast.Enum_Type, ^ast.Bit_Field_Type:
        return true
    }

    return false
}

// Whether a whitespace-only line sits between the newline at `eol` and offset `to`.
has_blank_line :: proc(src: string, eol, to: int) -> bool {
    start := eol + 1

    for i in eol + 1 ..< to {
        if src[i] == '\n' {
            if strings.trim_space(src[start:i]) == "" {
                return true
            }

            start = i + 1
        }
    }

    return false
}

find_do :: proc(src: string, body: int) -> int {
    i := body

    for i > 0 && strings.is_space(rune(src[i - 1])) {
        i -= 1
    }

    if i < 2 || src[i - 2:i] != "do" {
        return -1
    }

    if i > 2 && is_ident_byte(src[i - 3]) {
        return -1
    }

    return i - 2
}

is_ident_byte :: proc(c: byte) -> bool {
    return c == '_' || c >= 0x80 || (c >= '0' && c <= '9') || (c | 0x20 >= 'a' && c | 0x20 <= 'z')
}

add :: proc(s: ^Splitter, offset, remove: int, text: string) {
    append(&s.edits, Edit{offset = offset, remove = remove, text = text, seq = len(s.edits)})
}

apply :: proc(src: string, edits: []Edit) -> (string, bool) {
    slice.sort_by(edits, proc(a, b: Edit) -> bool {
        return a.offset != b.offset ? a.offset < b.offset : a.seq < b.seq
    })
    out := strings.builder_make()
    at := 0

    for e in edits {
        if e.offset < at {
            return "", false
        }

        strings.write_string(&out, src[at:e.offset])
        strings.write_string(&out, e.text)
        at = e.offset + e.remove
    }

    strings.write_string(&out, src[at:])
    return strings.to_string(out), true
}

// ---------------------------------------------------------------------------
// verify
// ---------------------------------------------------------------------------

Shape :: struct {
    tokens:   [dynamic]string,
    comments: [dynamic]string,
    nodes:    [dynamic]Node_Sig,
}

Node_Sig :: struct {
    depth: int,
    kind:  typeid,
}

Shape_Walk :: struct {
    shape:   ^Shape,
    depth:   int,
    counted: [dynamic]bool, // per open node: did it take a depth level?
    parens:  map[int]bool, // offsets of grouping `(` and `)`
}

verify_pair :: proc(orig, formatted: string) -> string {
    context.allocator = context.temp_allocator
    a, a_err := os.read_entire_file_from_path(orig, context.allocator)
    b, b_err := os.read_entire_file_from_path(formatted, context.allocator)

    if a_err != nil || b_err != nil {
        return "cannot read"
    }

    if slice.equal(a, b) {
        return ""
    }

    sa, ok_a := shape_of(orig, string(a))

    if !ok_a {
        return "does not parse"
    }

    sb, ok_b := shape_of(formatted, string(b))

    if !ok_b {
        return "formatted copy does not parse"
    }

    if !slice.equal(sa.tokens[:], sb.tokens[:]) {
        return fmt.tprintf("tokens differ (%s)", first_difference(sa.tokens[:], sb.tokens[:]))
    }

    if !slice.equal(sa.comments[:], sb.comments[:]) {
        return fmt.tprintf("comments differ (%s)", first_difference(sa.comments[:], sb.comments[:]))
    }

    if !slice.equal(sa.nodes[:], sb.nodes[:]) {
        return "AST shape differs"
    }

    return ""
}

shape_of :: proc(path, src: string) -> (shape: Shape, ok: bool) {
    file := parse(path, src) or_return

    // The AST first: it also finds which parentheses only group.
    w := Shape_Walk {
        shape = &shape,
    }
    v := ast.Visitor {
        visit = shape_visit,
        data  = &w,
    }

    for decl in file.decls {
        ast.walk(&v, decl)
    }

    raw: [dynamic]tokenizer.Token
    t: tokenizer.Tokenizer
    tokenizer.init(&t, src, path, quiet)

    for tok := tokenizer.scan(&t); tok.kind != .EOF; tok = tokenizer.scan(&t) {
        #partial switch tok.kind {
        case .Comment:
            append(&shape.comments, strings.join(strings.fields(tok.text), " "))
        case .Semicolon:
        case:
            append(&raw, tok)
        }
    }

    for i := 0; i < len(raw); i += 1 {
        tok := raw[i]

        #partial switch tok.kind {
        case .Do, .Open_Brace, .Close_Brace:
            continue
        case .Open_Paren, .Close_Paren:
            if w.parens[tok.pos.offset] {
                continue
            }
        case .Comma:
            if i + 1 < len(raw) {
                #partial switch raw[i + 1].kind {
                case .Close_Paren, .Close_Bracket, .Close_Brace:
                    continue // trailing comma
                }
            }
        case .Ident:
            if tok.text == "_" && i > 0 && i + 1 < len(raw) && raw[i + 1].kind == .Colon {
                #partial switch raw[i - 1].kind {
                case .Open_Paren, .Comma:
                    i += 1 // `_:` naming a parameter
                    continue
                }
            }
        }

        append(&shape.tokens, tok.text)
    }

    return shape, true
}

shape_visit :: proc(v: ^ast.Visitor, node: ^ast.Node) -> ^ast.Visitor {
    w := (^Shape_Walk)(v.data)

    if node == nil {
        if pop(&w.counted) {
            w.depth -= 1
        }

        return nil
    }

    counted := true

    #partial switch n in node.derived {
    case ^ast.Paren_Expr:
        w.parens[n.open.offset] = true
        w.parens[n.close.offset] = true
        counted = false
    case ^ast.Attribute:
        if n.open.line != 0 {
            // odinfmt spells `@thread_local` as `@(thread_local)`
            w.parens[n.open.offset] = true
            w.parens[n.close.offset] = true
        }
    case ^ast.Ident:
        counted = n.name != "_" // see `_:` above; every other `_` still shows in the tokens
    case ^ast.Comment_Group:
        counted = false // compared as text; where odinfmt attaches a comment is not semantic
    }

    if counted {
        append(&w.shape.nodes, Node_Sig{w.depth, reflect.union_variant_typeid(node.derived)})
        w.depth += 1
    }

    append(&w.counted, counted)
    return v
}

first_difference :: proc(a, b: []string) -> string {
    for i in 0 ..< min(len(a), len(b)) {
        if a[i] != b[i] {
            lead := strings.join(a[max(i - 4, 0):i], " ")
            return fmt.tprintf("after `%s`: %q vs %q", lead, a[i], b[i])
        }
    }

    return fmt.tprintf("%d vs %d entries", len(a), len(b))
}

// ---------------------------------------------------------------------------

parse :: proc(path, src: string) -> (file: ^ast.File, ok: bool) {
    file = new(ast.File)
    file.fullpath = path
    file.src = src
    p := parser.default_parser()
    p.err = quiet
    p.warn = quiet

    if !parser.parse_file(&p, file) || p.error_count > 0 {
        return nil, false
    }

    return file, true
}

quiet :: proc(pos: tokenizer.Pos, msg: string, args: ..any) {}
