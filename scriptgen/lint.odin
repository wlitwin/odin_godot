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
import "core:strings"

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


// THE METHOD TRAP, made loud. A class's proc scan covers its OWN home file
// plus HEADERLESS helper files — so an attributed (or lifecycle-named) proc
// whose receiver is a DIFFERENT script struct, written inside some class's
// home file, binds to NOTHING: the home's scan rejects the receiver, and the
// receiver's scan never visits another class's home. It compiles, connects,
// and fails only when the signal actually fires (a day of dead shop-card
// clicks). Named at build time instead. Plain cross-class helpers (no
// attribute, no lifecycle name) are legitimate and stay silent.
lint_misplaced :: proc(path, src, own: string, script_structs: map[string]bool) {
	file := ast.File {
		fullpath = path,
		src      = src,
	}
	p := parser.default_parser()
	p.err = lint_parse_diag
	p.warn = lint_parse_diag
	if !parser.parse_file(&p, &file) {return}
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok || len(vd.names) != 1 || len(vd.values) != 1 {continue}
		pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
		if !is_proc || pl.type == nil || pl.type.params == nil || len(pl.type.params.list) == 0 {continue}
		name_ident, _ := vd.names[0].derived.(^ast.Ident)
		if name_ident == nil {continue}
		t := strings.trim_space(node_text(src, pl.type.params.list[0].type))
		if len(t) < 2 || t[0] != '^' {continue}
		recv := t[1:]
		if recv == own || !script_structs[recv] {continue}
		attributed :=
			has_attr(vd, "gd_method") ||
			has_attr(vd, "gd_rpc") ||
			has_attr(vd, "gd_command") ||
			has_attr(vd, "gd_connect") ||
			has_attr(vd, "gd_tick") ||
			has_attr(vd, "gd_sample") ||
			has_attr(vd, "gd_step")
		_, is_lc := lifecycle_keyword(strip_struct_prefix(name_ident.name, recv))
		if !attributed && !is_lc {continue}
		error_at(
			Loc{path = path, line = name_ident.pos.line},
			"%s takes ^%s but lives in %s's home file — it binds to NOTHING there (a class's scan covers its own file + headerless helpers only); move it to a headerless file",
			name_ident.name,
			recv,
			own,
		)
	}
}

// ---------------------------------------------------------------------------
// The method-NAME lint. boot_attach's Options.methods, netgd.wire_listen, and
// netgd.listen_packets connect Godot signals to @(gd_method)s BY STRING — a
// typo'd name compiles, connects nothing, and fails as behavior: an unwired
// `peer_disconnected` forward is the alt-F4'd-friend-haunts-the-roster bug,
// an unwired `connection_failed` hangs a failed join on "Joining..." forever.
// scriptgen knows every registered method name, so a bad string is a BUILD
// error here. An empty string stays a deliberate skip. Names built at runtime
// (variables, concatenations) are skipped — this catches the literal, which
// is how every game writes them.

Method_Claim :: struct {
	struct_name: string, // the script whose methods the name must resolve in
	method:      string,
	call:        string, // which call claimed it — for the diagnostic
	path:        string,
	line:        int,
}

@(private = "file")
Claim_State :: struct {
	claims:      ^[dynamic]Method_Claim,
	path:        string,
	src:         string,
	struct_name: string, // the enclosing proc's script (first `^Struct` param)
}

// Collect method-name string literals from one parsed file. The enclosing
// proc's first `^<script>` param names the script the strings must resolve
// against (boot_attach in a helper file still binds to the game's class).
scan_method_claims :: proc(claims: ^[dynamic]Method_Claim, path, src: string, file: ^ast.File, script_structs: map[string]bool) {
	st := Claim_State {
		claims = claims,
		path   = path,
		src    = src,
	}
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok || len(vd.values) != 1 {continue}
		pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
		if !is_proc || pl.body == nil || pl.type == nil || pl.type.params == nil || len(pl.type.params.list) == 0 {continue}
		first := pl.type.params.list[0]
		if first.type == nil {continue}
		ptr, is_ptr := first.type.derived.(^ast.Pointer_Type)
		if !is_ptr {continue}
		elem, is_ident := ptr.elem.derived.(^ast.Ident)
		if !is_ident || elem.name not_in script_structs {continue}
		st.struct_name = elem.name
		context.user_ptr = &st
		ast.inspect(pl.body, claim_visit)
		context.user_ptr = nil
	}
}

@(private = "file")
claim_add :: proc(st: ^Claim_State, e: ^ast.Expr, call: string) {
	expr := e
	// The named-field Methods form (`{host = "on_host"}`) claims through its value.
	if fv, is_fv := expr.derived.(^ast.Field_Value); is_fv {
		expr = fv.value
	}
	bl, ok := expr.derived.(^ast.Basic_Lit)
	if !ok || bl.tok.kind != .String {return}
	name := strings.trim(node_text(st.src, expr), "\"`")
	if name == "" {return} // empty = skip this signal, on purpose
	append(st.claims, Method_Claim{struct_name = st.struct_name, method = name, call = call, path = st.path, line = expr.pos.line})
}

@(private = "file")
claim_visit :: proc(node: ^ast.Node) -> bool {
	if node == nil {return false}
	st := cast(^Claim_State)context.user_ptr
	call, ok := node.derived.(^ast.Call_Expr)
	if !ok {return true}
	callee := node_text(st.src, call.expr)
	if i := strings.last_index(callee, "."); i >= 0 {callee = callee[i + 1:]}
	switch callee {
	case "wire_listen", "listen_packets":
		// (wire/node first, then the receiving method names, positionally)
		if len(call.args) < 2 {return true}
		for arg in call.args[1:] {
			claim_add(st, arg, callee)
		}
	case "boot_attach":
		// Find the Options literal's `methods = {...}` field, wherever it sits.
		for arg in call.args {
			cl, is_cl := arg.derived.(^ast.Comp_Lit)
			if !is_cl {continue}
			for elem in cl.elems {
				fv, is_fv := elem.derived.(^ast.Field_Value)
				if !is_fv {continue}
				if node_text(st.src, fv.field) != "methods" {continue}
				mcl, is_m := fv.value.derived.(^ast.Comp_Lit)
				if !is_m {continue}
				for me in mcl.elems {
					claim_add(st, me, "boot_attach methods")
				}
			}
		}
	}
	return true
}

// Validate the claims once every script's method table is complete (methods
// may live in helper files — pass 2 must have run).
lint_method_claims :: proc(claims: []Method_Claim, by_struct: map[string]^Script) {
	for c in claims {
		s, known := by_struct[c.struct_name]
		if !known {continue}
		found := false
		for m in s.methods {
			if m.gd_name == c.method {
				found = true
				break
			}
		}
		if !found {
			error_at(
				Loc{path = c.path, line = c.line},
				"%s: %q names no @(gd_method) of %s — the signal will never connect (declare `@(gd_method) %s_%s :: proc(self: ^%s, ...)`, or pass \"\" to skip on purpose)",
				c.call, c.method, c.struct_name, to_snake(c.struct_name), c.method, c.struct_name,
			)
		}
	}
}

// ---------------------------------------------------------------------------
// The raw-verb lint. A @(gd_command) proc is the framework's to run: the
// generated `<verb>_cmd` wrapper is the ONLY door that predicts, ships,
// validates, dedups, and fires the `_then`. The raw proc is one suffix away
// and callable from anywhere — on the host it MOSTLY works (mutates and
// replicates, but skips `_then` and the command hook), on a client it is the
// silent local-only write. Both compile. Named here at build time instead.

Cmd_Call :: struct {
	callee: string, // final identifier ("chest_take" — package qualifier stripped)
	path:   string,
	line:   int,
}

@(private = "file")
Cmd_Call_State :: struct {
	calls: ^[dynamic]Cmd_Call,
	path:  string,
	src:   string,
}

// Collect every call's final identifier from one parsed file (validated
// against the module's command procs once those are fully resolved).
scan_command_calls :: proc(calls: ^[dynamic]Cmd_Call, path, src: string, file: ^ast.File) {
	st := Cmd_Call_State {
		calls = calls,
		path  = path,
		src   = src,
	}
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok || len(vd.values) != 1 {continue}
		pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
		if !is_proc || pl.body == nil {continue}
		context.user_ptr = &st
		ast.inspect(pl.body, cmd_call_visit)
		context.user_ptr = nil
	}
}

@(private = "file")
cmd_call_visit :: proc(node: ^ast.Node) -> bool {
	if node == nil {return false}
	st := cast(^Cmd_Call_State)context.user_ptr
	call, ok := node.derived.(^ast.Call_Expr)
	if !ok {return true}
	callee := node_text(st.src, call.expr)
	if i := strings.last_index(callee, "."); i >= 0 {callee = callee[i + 1:]}
	if callee == "" {return true}
	append(st.calls, Cmd_Call{callee = callee, path = st.path, line = call.pos.line})
	return true
}

// Validate once every script's command set is complete (composed verbs
// hoist from imported blocks, so pass 2 must have run).
lint_command_calls :: proc(calls: []Cmd_Call, scripts: []^Script) {
	for c in calls {
		for s in scripts {
			for &cmd in s.commands {
				if c.callee != cmd.proc_name {continue}
				wrapper := len(cmd.path) > 0 ? strings.concatenate({to_snake(s.struct_name), "_", cmd.name}) : cmd.proc_name
				error_at(
					Loc{path = c.path, line = c.line},
					"%s is a @(gd_command) verb — a direct call skips the framework (no `_then`, no dedup or validation on the host; a silent local-only write on a client). Issue it through the generated wrapper: `%s_cmd(&boot, self, ...)`",
					cmd.proc_name, wrapper,
				)
				break
			}
		}
	}
}
