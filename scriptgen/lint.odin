// The self-vs-owner lint. Every engine handle (gd.Object and all its class
// aliases: gd.Node, gd.Node2d, ...) is a rawptr alias, so passing the ODIN
// SCRIPT STRUCT pointer (`self`) where an engine object belongs COMPILES
// SILENTLY — Odin converts any pointer to rawptr — and segfaults when the
// engine dereferences the struct as a godot::Object*. The type system can't
// catch it; scriptgen already parses every package file, so it names the
// mistake at build time instead:
//
//     gd.add_child(self, node)        // error: pass self.owner
//     gd.connect_to(p, "s", self, m)  // error: pass self.owner
//     cast(gd.Object)self             // error: the cast crashes identically
//
// Scope: arguments (and gd-type casts) that are BARE parameters typed
// `^<script struct>` — the `self` of lifecycle procs and of helper procs in
// sibling files. Locals aliasing self are not tracked; this catches the
// mistake as it is actually made.
package scriptgen

import "core:odin/ast"
import "core:odin/parser"
import "core:odin/tokenizer"

// Parse diagnostics stay silent (same rule as main's helper pass): a file that
// doesn't parse is reported properly by `odin build` — never double-print.
@(private = "file")
lint_parse_diag :: proc(pos: tokenizer.Pos, format: string, args: ..any) {}

@(private = "file")
Lint_State :: struct {
	path:   string,
	alias:  string, // this file's `godot:godot` import alias (normally "gd")
	params: map[string]string, // script-pointer param name -> struct name, current proc
}

lint_handles :: proc(path, src: string, script_structs: map[string]bool) {
	file := ast.File {
		fullpath = path,
		src      = src,
	}
	p := parser.default_parser()
	p.err = lint_parse_diag
	p.warn = lint_parse_diag
	if !parser.parse_file(&p, &file) {return} // odin build reports parse errors properly
	alias := godot_import_alias(&file)
	if alias == "" {return} // no godot import — no engine calls to misuse

	st := Lint_State {
		path   = path,
		alias  = alias,
		params = make(map[string]string),
	}
	defer delete(st.params)

	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok || len(vd.values) != 1 {continue}
		pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
		if !is_proc || pl.body == nil || pl.type == nil || pl.type.params == nil {continue}
		clear(&st.params)
		for field in pl.type.params.list {
			if field.type == nil {continue}
			ptr, is_ptr := field.type.derived.(^ast.Pointer_Type)
			if !is_ptr {continue}
			elem, is_ident := ptr.elem.derived.(^ast.Ident)
			if !is_ident || elem.name not_in script_structs {continue}
			for nm in field.names {
				if id, iok := nm.derived.(^ast.Ident); iok {
					st.params[id.name] = elem.name
				}
			}
		}
		if len(st.params) == 0 {continue}
		context.user_ptr = &st
		ast.inspect(pl.body, lint_visit)
		context.user_ptr = nil
	}
}

@(private = "file")
lint_visit :: proc(node: ^ast.Node) -> bool {
	if node == nil {return false} // inspect's post-visit call
	st := cast(^Lint_State)context.user_ptr
	#partial switch n in node.derived {
	case ^ast.Call_Expr:
		sel, sok := n.expr.derived.(^ast.Selector_Expr)
		if !sok {return true}
		pkg, pok := sel.expr.derived.(^ast.Ident)
		if !pok || pkg.name != st.alias {return true}
		for arg in n.args {
			id, iok := arg.derived.(^ast.Ident)
			if !iok {continue}
			if sname, hit := st.params[id.name]; hit {
				error_at(
					Loc{st.path, id.pos.line},
					"%s.%s: `%s` is the ^%s script struct, not an engine object — pass %s.owner",
					st.alias,
					sel.field.name,
					id.name,
					sname,
					id.name,
				)
			}
		}
	case ^ast.Type_Cast:
		sel, sok := n.type.derived.(^ast.Selector_Expr)
		if !sok {return true}
		pkg, pok := sel.expr.derived.(^ast.Ident)
		if !pok || pkg.name != st.alias {return true}
		id, iok := n.expr.derived.(^ast.Ident)
		if !iok {return true}
		if sname, hit := st.params[id.name]; hit {
			error_at(
				Loc{st.path, id.pos.line},
				"cast(%s.%s)%s: `%s` is the ^%s script struct — a cast doesn't make it an engine object; pass %s.owner",
				st.alias,
				sel.field.name,
				id.name,
				id.name,
				sname,
				id.name,
			)
		}
	}
	return true
}
