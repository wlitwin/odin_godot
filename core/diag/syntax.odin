package diag

// ----------------------------------------------------------------------------
// TIER 1 of validation — the RESIDENT parser.
//
// `odin check` gives the real type errors but re-type-checks the whole godot
// collection (~0.5s warm on a game-sized package) per run — that cost is
// irreducible (no incremental checker exists), so it runs on the async worker
// (async.odin) and its results trail the typing by a debounce + check + poke
// cycle. But MOST diagnostics while typing are SYNTAX errors (the half-typed
// expression, the missing brace) — and those don't need the checker at all:
// the compiler's own parser is a library (core:odin/parser) and parses a
// script file in about a millisecond, in-process.
//
// parse_syntax is that tier: parse the LIVE buffer alone and collect every
// parser/tokenizer error. validate_async runs it synchronously per (debounced)
// call — a syntactically broken buffer gets its squiggle on the FIRST debounce
// and never schedules the slow check at all (`odin check` would stop at the
// same syntax error anyway, so no type information is lost).
//
// ols is deliberately NOT in this path: the pinned ols computes diagnostics by
// spawning the SAME external `odin check` (ols src/server/check.odin), so a
// persistent LSP session buys diagnostics nothing — that finding retired the
// "ols-backed incremental check" backlog idea. The persistent ols session
// (core/complete/session.odin) serves what ols IS resident for: completion,
// signature help, goto-definition.
// ----------------------------------------------------------------------------

import "base:runtime"
import "core:fmt"
import vmem "core:mem/virtual"
import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"

// The parser's Error_Handler carries no user pointer — the collector rides
// context.user_ptr (parse_file runs in our context, so the handler sees it).
@(private = "file")
Collector :: struct {
    diags:     ^[dynamic]Diagnostic,
    allocator: runtime.Allocator,
}

@(private = "file")
collect_error :: proc(pos: tokenizer.Pos, msg: string, args: ..any) {
    c := (^Collector)(context.user_ptr)
    if c == nil {return}
    append(
        c.diags,
        Diagnostic {
            line    = max(pos.line, 1),
            column  = max(pos.column, 1),
            message = fmt.aprintf(msg, ..args, allocator = c.allocator),
        },
    )
}

// Parser warnings are style-tier noise for a red-squiggle line; drop them.
@(private = "file")
drop_warning :: proc(pos: tokenizer.Pos, msg: string, args: ..any) {}

// parse_syntax — parse `source` standalone and return every syntax error. An
// empty list means "syntactically sound; type truth needs the checker". The
// diagnostics (and their messages) are owned by `allocator`; the AST itself is
// scratch, freed whole before returning.
parse_syntax :: proc(source: string, abs_path: string, allocator := context.allocator) -> [dynamic]Diagnostic {
    diags := make([dynamic]Diagnostic, allocator)
    col := Collector{&diags, allocator}

    // The AST is garbage the moment this returns — grow it in a scratch arena.
    arena: vmem.Arena
    if vmem.arena_init_growing(&arena) != nil {
        return diags // no memory for a parse: report nothing rather than break the editor
    }
    defer vmem.arena_destroy(&arena)

    p := parser.default_parser()
    p.err = collect_error
    p.warn = drop_warning

    file := ast.File {
        fullpath = abs_path,
        src      = source,
    }

    context.user_ptr = &col
    context.allocator = vmem.arena_allocator(&arena)
    _ = parser.parse_file(&p, &file)

    return diags
}
