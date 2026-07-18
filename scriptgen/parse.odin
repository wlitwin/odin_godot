package scriptgen

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
import "core:slice"
import "core:strconv"
import "core:strings"

// Render a type/expr node back to its source text by slicing the original buffer.
// Robust for arbitrary types (`f32`, `gd.Int`, `^gd.Node2d`, ...).
node_text :: proc(src: string, n: ^ast.Node) -> string {
	if n == nil {return ""}
	lo := n.pos.offset
	hi := n.end.offset
	if lo < 0 || hi > len(src) || lo > hi {return ""}
	return strings.trim_space(src[lo:hi])
}

// Pull the value of the `gd` key out of an Odin struct-field tag like
// `` `gd:"export" json:"x"` ``. Returns ("", false) if absent. The key must sit at the
// START of the tag or after whitespace — a bare substring match would also hit an
// UNRELATED key that merely ends in "gd" (`msgd:"..."`).
tag_gd_value :: proc(tag_text: string) -> (string, bool) {
	t := strings.trim(tag_text, "`")
	key := "gd:\""
	for at := 0; at < len(t); {
		i := strings.index(t[at:], key)
		if i < 0 {return "", false}
		abs := at + i
		at = abs + len(key)
		if abs != 0 && t[abs - 1] != ' ' && t[abs - 1] != '\t' {continue} // e.g. `msgd:"..."`
		rest := t[at:]
		j := strings.index(rest, "\"")
		if j < 0 {return "", false}
		return rest[:j], true
	}
	return "", false
}

// is_odin_ident — the ASCII identifier rule (letter/underscore first, then alnum/underscore).
// Signal arg names from `gd:"args=..."` tags are spliced into generated Odin code (the
// typed emit helpers' parameter names), so anything else must be rejected at parse time.
is_odin_ident :: proc(s: string) -> bool {
	if len(s) == 0 {return false}
	for i in 0 ..< len(s) {
		c := s[i]
		if c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {continue}
		if i > 0 && c >= '0' && c <= '9' {continue}
		return false
	}
	return true
}

@(private = "file")
is_ident_byte :: proc(c: byte) -> bool {
	return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}

// normalize_godot_qualifier rewrites `<alias>.` -> `gd.` (at identifier boundaries) in a
// spliced type text, where `alias` is the file's ACTUAL `godot:godot` import alias. Gen
// files always import `gd "godot:godot"`, so author spellings under any other alias
// (`godot.Vector2`, `g.Node2d`) must be normalized before they are spliced verbatim into
// generated code — and before map_variant, which only understands the `gd.` qualifier.
normalize_godot_qualifier :: proc(text, alias: string) -> string {
	if alias == "" || alias == "gd" || !strings.contains(text, alias) {return text}
	b := strings.builder_make()
	i := 0
	for i < len(text) {
		if strings.has_prefix(text[i:], alias) &&
		   i + len(alias) < len(text) && text[i + len(alias)] == '.' &&
		   (i == 0 || !is_ident_byte(text[i - 1])) {
			strings.write_string(&b, "gd.")
			i += len(alias) + 1
			continue
		}
		strings.write_byte(&b, text[i])
		i += 1
	}
	return strings.to_string(b)
}

// godot_import_alias returns the name the file's `godot:godot` import binds ("" when the
// file doesn't import it). `import gd "godot:godot"` -> "gd"; a bare `import "godot:godot"`
// -> the default package name "godot".
godot_import_alias :: proc(file: ^ast.File) -> string {
	for imp in file.imports {
		if strings.trim(imp.fullpath, "\"") != "godot:godot" {continue}
		if imp.name.text != "" && imp.name.text != "_" {return imp.name.text}
		return "godot"
	}
	return ""
}

// snake_case a PascalCase identifier: Ping -> ping, ToolProbe -> tool_probe.
to_snake :: proc(s: string) -> string {
	b := strings.builder_make()
	for r, i in s {
		if r >= 'A' && r <= 'Z' {
			if i != 0 {strings.write_rune(&b, '_')}
			strings.write_rune(&b, r + ('a' - 'A'))
		} else {
			strings.write_rune(&b, r)
		}
	}
	return strings.to_string(b)
}

// Strip a leading `<snake_struct>_` prefix from a proc name, if present.
strip_struct_prefix :: proc(proc_name, struct_name: string) -> string {
	prefix := strings.concatenate({to_snake(struct_name), "_"})
	if strings.has_prefix(proc_name, prefix) {
		return proc_name[len(prefix):]
	}
	return proc_name
}

lifecycle_keyword :: proc(name: string) -> (string, bool) {
	for kw in LIFECYCLE_KEYWORDS {
		if name == kw {return kw, true}
	}
	return "", false
}

// nearest_lifecycle reports a lifecycle keyword within edit-distance 1 of `name` (excluding
// an exact match, which lifecycle_keyword already caught). Used only for a typo warning.
nearest_lifecycle :: proc(name: string) -> (string, bool) {
	for kw in LIFECYCLE_KEYWORDS {
		if name != kw && edit_distance_le1(name, kw) {return kw, true}
	}
	return "", false
}

// edit_distance_le1 — true iff `a` becomes `b` with at most one insertion, deletion, or
// substitution. (A tiny single-edit check; not a full Levenshtein.)
edit_distance_le1 :: proc(a, b: string) -> bool {
	x, y := a, b // params are immutable; work on locals so we can normalize order
	lx, ly := len(x), len(y)
	if lx == ly {
		diffs := 0
		for i in 0 ..< lx {
			if x[i] != y[i] {
				diffs += 1
				if diffs > 1 {return false}
			}
		}
		return diffs == 1
	}
	// length differs by exactly 1: the longer must equal the shorter with one char inserted.
	if lx > ly {x, y = y, x; lx, ly = ly, lx}
	if ly - lx != 1 {return false}
	i, j := 0, 0
	skipped := false
	for i < lx && j < ly {
		if x[i] == y[j] {
			i += 1; j += 1
		} else {
			if skipped {return false}
			skipped = true
			j += 1 // skip one char in the longer string
		}
	}
	return true
}

// ---- marker scanning (//gd:extends / //gd:class / //gd:tool / //gd:icon) ----

// Markers are documented (and generated by the editor template) as the file HEADER —
// the `//gd:` lines above the `package` declaration. `pkg_line` is the package decl's
// 1-based line; only lines BEFORE it are recognized, so a `//gd:`-looking line inside a
// raw string or block comment in the body can never register a phantom marker. A
// marker-shaped line AFTER the package decl gets a warning (it used to be honored).
scan_markers :: proc(src: string, s: ^Script, pkg_line: int) {
	it := src
	ln := 0
	for line in strings.split_lines_iterator(&it) {
		ln += 1
		l := strings.trim_space(line)
		if !strings.has_prefix(l, "//gd:") {continue}
		loc := Loc{s.path, ln}
		if pkg_line > 0 && ln > pkg_line {
			warn_at(loc, "//gd: marker after the package declaration is ignored — markers go at the top of the file")
			continue
		}
		body := strings.trim_space(l[len("//gd:"):])
		if rest, ok := marker_arg(body, "extends"); ok {
			s.marked = true
			s.base = strings.trim_space(rest)
			if s.base == "" {error_at(loc, "//gd:extends needs a base class name")}
		} else if rest, ok := marker_arg(body, "class"); ok {
			s.marked = true
			s.class_name = strings.trim_space(rest)
			if s.class_name == "" {error_at(loc, "//gd:class needs a name")}
		} else if _, ok := marker_arg(body, "tool"); ok {
			s.marked = true
			s.tool = true
		} else if rest, ok := marker_arg(body, "icon"); ok {
			s.marked = true
			s.icon = strings.trim_space(rest)
		} else if _, ok := marker_arg(body, "signal"); ok {
			// The comment-marker signal form is GONE (breaking change) — signals are typed
			// struct fields now. Point straight at the replacement instead of "unknown marker".
			error_at(
				loc,
				"//gd:signal was removed — declare the signal as a typed struct field instead, e.g. `collected: gd.Signal1(int) `gd:\"args=value\"`` (gd.Signal0 for no payload; see docs/authoring-guide.md)",
			)
		} else {
			// A `//gd:` line that matches no known marker is almost always a typo
			// (`//gd:extend`, `//gd:singal`) that would otherwise silently no-op — and the
			// `//gd:` namespace is reserved, so erroring is safe.
			error_at(loc, "unknown //gd: marker %q (expected one of: extends/class/tool/icon)", body)
		}
	}
}

// marker_arg matches keyword `kw` at a WORD BOUNDARY, returning the text after it. The
// boundary check is what stops `//gd:tooltip` from matching `tool` and `//gd:extend` (no
// trailing `s`) from matching `extends` — both previously silently changed behaviour.
marker_arg :: proc(body, kw: string) -> (rest: string, ok: bool) {
	if !strings.has_prefix(body, kw) {return "", false}
	r := body[len(kw):]
	if len(r) == 0 {return "", true} // bare marker (e.g. `//gd:tool`)
	if r[0] == ' ' || r[0] == '\t' {return r, true}
	return "", false // e.g. `tooltip` after `tool` — not a boundary
}

// ---- signal fields (gd.Signal0 … Signal4, gd.SignalN) ---------------------------

// Detect an arity-family signal marker field type from its (gd.-normalized) rendered spelling and return
// the arity plus the raw parameter-list text ("" for Signal0). The godot qualifier is
// REQUIRED — an unqualified `Signal1(...)` is the user's own package-local type, not the
// marker. The runtime walk re-derives the same facts from type info at registration
// (runtime/register_class.odin signal_field_args, which checks the marker's phantom
// structure instead); scriptgen only needs them for the typed emit helper's signature.
signal_type_params :: proc(type_text: string) -> (arity: int, params: string, ok: bool) {
	t := type_text
	if strings.has_prefix(t, "gd.") {
		t = t[3:]
	} else if strings.has_prefix(t, "godot.") {
		t = t[6:]
	} else {
		return 0, "", false
	}
	if t == "Signal0" {return 0, "", true}
	HEAD :: len("Signal") // "Signal" + one arity digit + "(" ... ")"
	if !strings.has_prefix(t, "Signal") || len(t) < HEAD + 3 {return 0, "", false}
	n := int(t[HEAD] - '0')
	if n < 1 || n > 4 || t[HEAD + 1] != '(' || t[len(t) - 1] != ')' {return 0, "", false}
	return n, strings.trim_space(t[HEAD + 2:len(t) - 1]), true
}

// Split a rendered type-parameter list on TOP-LEVEL commas only — a parameter can itself
// be parametric (`Typed_Dictionary(gd.String, i64)`), whose inner commas must not split.
split_type_params :: proc(params: string) -> [dynamic]string {
	parts := make([dynamic]string)
	depth := 0
	start := 0
	for i in 0 ..< len(params) {
		switch params[i] {
		case '(':
			depth += 1
		case ')':
			depth -= 1
		case ',':
			if depth == 0 {
				append(&parts, strings.trim_space(params[start:i]))
				start = i + 1
			}
		}
	}
	append(&parts, strings.trim_space(params[start:]))
	return parts
}

// Parse one signal FIELD (`collected: gd.Signal1(int) `gd:\"args=value\"``) into a
// Signal_Info. The signal name is the field name (already a valid identifier — it parsed);
// arg names come from the optional `args=` tag or synthesize as argN. Only build-time
// validation + the emit-helper inputs happen here; registration is the runtime walk's job.
parse_signal_field :: proc(s: ^Script, floc: Loc, fname: string, arity: int, params: string, tag_val: string, has_tag: bool) {
	sig := Signal_Info {
		name = fname,
		line = floc.line,
	}

	// Payload types: every parameter must be Variant-able (same rule as method args).
	if arity > 0 {
		parts := split_type_params(params)
		defer delete(parts)
		if len(parts) != arity {
			error_at(floc, "%s.%s: malformed signal type parameters %q", s.struct_name, fname, params)
			return
		}
		for p, i in parts {
			vi, ok := map_variant(p)
			if !ok {
				error_at(floc, "%s.%s: signal payload parameter %d has unsupported type %q — every parameter must map to a Variant", s.struct_name, fname, i, p)
				return
			}
			append(&sig.args, Signal_Arg{name = fmt.tprintf("arg%d", i), vi = vi})
		}
	}

	// Optional `gd:"args=a,b"` — payload names, one per parameter, positionally. The names
	// become the emit helper's parameter names (spliced into generated code) and the
	// registered PropertyInfo names, so they must be plain identifiers.
	if has_tag {
		if !strings.has_prefix(tag_val, "args=") {
			error_at(floc, "%s.%s: a signal field's gd tag must be `args=name1,name2` (signals register by type and cannot be exported)", s.struct_name, fname)
		} else {
			names := strings.split(tag_val[len("args="):], ",")
			defer delete(names)
			// (split("") is [""] — a zero-payload `args=` also lands here, len 1 != 0.)
			if len(names) != arity {
				error_at(floc, "%s.%s: `args=` must name each of the signal's %d payload parameter(s) exactly once", s.struct_name, fname, arity)
			} else {
				for nm, i in names {
					aname := strings.trim_space(nm)
					if !is_odin_ident(aname) {
						error_at(floc, "%s.%s: signal arg name %q is not a valid identifier", s.struct_name, fname, aname)
						continue
					}
					sig.args[i].name = aname
				}
			}
		}
	}

	append(&s.signals, sig)
}

// Detect the general-form marker (gd.SignalN) on a field's type expression and return its
// single type-parameter NODE. Unlike the arity family (whose parameters are plain type
// spellings, matched from the rendered text), SignalN's parameter is an inline struct —
// an ast.Struct_Type node whose field names/types are read directly, no text-splitting.
// The godot qualifier is REQUIRED, same rule as signal_type_params: the file's actual
// `godot:godot` import alias, or the canonical gd./godot. spellings.
signal_n_param :: proc(type_expr: ^ast.Expr, alias: string) -> (param: ^ast.Expr, ok: bool) {
	if type_expr == nil {return nil, false}
	call, cok := type_expr.derived.(^ast.Call_Expr)
	if !cok {return nil, false}
	sel, sok := call.expr.derived.(^ast.Selector_Expr)
	if !sok || sel.field == nil || sel.field.name != "SignalN" {return nil, false}
	pkg, pok := sel.expr.derived.(^ast.Ident)
	if !pok {return nil, false}
	if pkg.name != alias && pkg.name != "gd" && pkg.name != "godot" {return nil, false}
	if len(call.args) != 1 {return nil, false}
	return call.args[0], true
}

// Parse one SignalN FIELD (`hit: gd.SignalN(struct { amount: int, who: ^gd.Node2d })`)
// into a Signal_Info: the payload struct's FIELD NAMES are the arg names (already valid
// identifiers — they parsed) and its field types the arg types. Mirrors the runtime
// walk's rules as build-time errors: the parameter must be an inline payload struct
// (never a single Variant-mappable type — the one-arg ambiguity gets the pointed
// suggestion), and a gd tag (`args=` included) is an error, field names being
// authoritative. Registration is still the runtime walk's job.
parse_signal_n_field :: proc(s: ^Script, src: string, floc: Loc, fname: string, param: ^ast.Expr, has_tag: bool) {
	if has_tag {
		error_at(floc, "%s.%s: a SignalN field takes no gd tag — the payload struct's field names ARE the arg names", s.struct_name, fname)
	}

	st, is_struct := param.derived.(^ast.Struct_Type)
	if !is_struct || st.is_raw_union {
		ptext := normalize_godot_qualifier(node_text(src, param), s.godot_alias)
		if _, mok := map_variant(ptext); mok && !is_struct {
			error_at(floc, "%s.%s: SignalN's parameter is the argument LIST as a struct, not a single payload type — use Signal1(%s) or SignalN(struct {{ pos: %s })", s.struct_name, fname, ptext, ptext)
		} else {
			error_at(floc, "%s.%s: SignalN's parameter must be an inline payload struct, e.g. SignalN(struct {{ amount: int }) — got %q", s.struct_name, fname, ptext)
		}
		return
	}

	sig := Signal_Info {
		name = fname,
		line = floc.line,
	}
	if st.fields != nil {
		for f in st.fields.list {
			atext := normalize_godot_qualifier(node_text(src, f.type), s.godot_alias)
			vi, vok := map_variant(atext)
			if !vok {
				flabel := "?"
				if len(f.names) > 0 {flabel = node_text(src, f.names[0])}
				error_at(floc, "%s.%s: signal payload field %q has unsupported type %q — every field must map to a Variant", s.struct_name, fname, flabel, atext)
				return
			}
			for nm in f.names {
				ident, iok := nm.derived.(^ast.Ident)
				if !iok || ident == nil {continue}
				append(&sig.args, Signal_Arg{name = ident.name, vi = vi})
			}
		}
	}

	append(&s.signals, sig)
}

// ---- AST parsing -------------------------------------------------------------

// Parse one script file. Returns ok=false when the file has no owner-struct (so it
// is not a script — e.g. a boot.odin or a plain helper file).
parse_script :: proc(path, src: string) -> (Script, bool) {
	s := Script {
		path = path,
		base = "Node",
	}

	file := ast.File {
		fullpath = path,
		src      = src,
	}
	p := parser.default_parser()
	if !parser.parse_file(&p, &file) {
		error_at(Loc{path = path}, "failed to parse")
		return s, false
	}
	s.pkg = file.pkg_name
	// The file's actual `godot:godot` import alias — marker/type spellings under it are
	// normalized to the gen files' `gd.` before mapping/splicing (see normalize_godot_qualifier).
	s.godot_alias = godot_import_alias(&file)
	scan_markers(src, &s, file.pkg_token.pos.line)

	// Pass 1: locate the script struct (first field named `owner`).
	struct_type: ^ast.Struct_Type
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok {continue}
		if len(vd.names) != 1 || len(vd.values) != 1 {continue}
		st, is_struct := vd.values[0].derived.(^ast.Struct_Type)
		if !is_struct {continue}
		if st.fields == nil || len(st.fields.list) == 0 {continue}
		f0 := st.fields.list[0]
		if len(f0.names) == 0 {continue}
		fname, _ := f0.names[0].derived.(^ast.Ident)
		if fname == nil || fname.name != "owner" {continue}
		name_ident, _ := vd.names[0].derived.(^ast.Ident)
		if name_ident == nil {continue}
		if struct_type != nil {
			// A second owner-struct used to be silently ignored — its exports/procs then
			// bound to nothing at runtime with no diagnostic.
			error_at(
				Loc{path, name_ident.pos.line},
				"one script struct per file; found %s and %s — move %s to its own file",
				s.struct_name,
				name_ident.name,
				name_ident.name,
			)
			continue
		}
		s.struct_name = name_ident.name
		s.doc = extract_doc(vd.docs) // `///` above the struct -> class description
		struct_type = st
	}
	if struct_type == nil {
		// A `//gd:` marker is an unambiguous declaration that this file IS a script. Finding
		// one but no script struct almost always means the struct's first field isn't named
		// `owner` (a typo, wrong name, or wrong position) — fail loudly instead of silently
		// dropping the class (which left the user with a node that does nothing, no error).
		if s.marked {
			error_at(
				Loc{path = path},
				"file has //gd: marker(s) (class %q) but no script struct — a script's struct must have its FIRST field named `owner`",
				s.class_name,
			)
		}
		return s, false
	}
	if s.class_name == "" {
		s.class_name = s.struct_name
	}

	// The resolution context for nested `using`/embedded fields: this file's package dir
	// (bare types) and its explicit-alias imports (imported bundles). See lookup_struct.
	nest_ctx := Struct_Def {
		dir     = dir_of(path),
		imports = collect_file_imports(&file),
	}

	// Exports: struct fields (after owner) tagged `gd:"export"` (or `gd:"onready=PATH"`).
	for f, i in struct_type.fields.list {
		if i == 0 {continue} // owner

		// Field name (first ident) — for error messages + offset_of.
		field_label := s.struct_name
		for nm in f.names {
			if ident, iok := nm.derived.(^ast.Ident); iok && ident != nil {
				field_label = ident.name
				break
			}
		}

		floc := Loc{s.path, f.pos.line}

		// Commands name their entity over the wire: remember whether the struct
		// declares a `net_id` field (validated iff @(gd_command) procs exist).
		for nm in f.names {
			if ident, iok := nm.derived.(^ast.Ident); iok && ident != nil && ident.name == "net_id" {
				s.net_id_type = strings.trim_space(node_text(src, f.type))
			}
		}

		// A kboot.Boot field is the "this game rides the boot" declaration —
		// scriptgen generates the four standard transport forwards for the
		// class (on_packet/on_peer_left/on_net_up/on_net_down), unless the
		// game defines its own (hand-written wins, name by name).
		{
			ftype := strings.trim_space(node_text(src, f.type))
			if ftype == "kboot.Boot" || strings.has_suffix(ftype, ".Boot") {
				for nm in f.names {
					if ident, iok := nm.derived.(^ast.Ident); iok && ident != nil {
						s.boot_field = ident.name
					}
				}
			}
		}

		val, has := tag_gd_value(f.tag.text)
		if !has && f.tag.text != "" {
			// A tag that LOOKS like an attempted gd tag but isn't the required `gd:"..."` form
			// (missing the inner quotes, or the colon) would otherwise be silently ignored — the
			// field isn't exported/onready-wired, then reads as nil/garbage and crashes at
			// runtime when you use it. Catch it at build time.
			raw := strings.trim(f.tag.text, "`")
			if strings.contains(raw, "gd:") || strings.contains(raw, "gd\"") {
				error_at(
					floc,
					"%s.%s: malformed gd tag %q — use the quoted form `gd:\"...\"`, e.g. `gd:\"onready=Sprite2D\"` or `gd:\"export\"`",
					s.struct_name,
					field_label,
					raw,
				)
			} else if ci := strings.index(raw, ":\""); ci > 0 {
				// A gd-shaped declaration under the WRONG NAMESPACE (`gs:"replicate"`)
				// contains no "gd:" at all and would silently not replicate/export.
				// Flag a namespace one edit from `gd`, and any namespace whose first
				// payload token is unmistakably ours.
				ns := raw[:ci]
				payload := raw[ci + 2:]
				if qi := strings.index(payload, "\""); qi >= 0 {payload = payload[:qi]}
				tok := payload
				if comma := strings.index(tok, ","); comma >= 0 {tok = tok[:comma]}
				tok = strings.trim_space(tok)
				gd_shaped :=
					tok == "export" || tok == "replicate" || tok == "backup" ||
					strings.has_prefix(tok, "onready=") || strings.has_prefix(tok, "args=") ||
					strings.has_prefix(tok, "entity=")
				if edit_distance_le1(ns, "gd") || gd_shaped {
					error_at(
						floc,
						"%s.%s: tag namespace %q is not `gd` — %q would silently not apply; write `gd:\"%s\"`",
						s.struct_name,
						field_label,
						ns,
						payload,
						payload,
					)
				}
			}
		}

		// Signal fields declare themselves by TYPE (gd.Signal0 … Signal4, or the general
		// gd.SignalN) — no tag needed (`gd:"args=..."` optionally names the arity family's
		// payload; SignalN forbids a tag), so these checks precede the tagged-fields-only
		// skip below. One field, one signal; multi-name fields (`a, b: gd.Signal0`)
		// declare one signal per name, like exports.
		{
			sig_type := normalize_godot_qualifier(node_text(src, f.type), s.godot_alias)
			if arity, params, is_sig := signal_type_params(sig_type); is_sig {
				for nm in f.names {
					ident, iok := nm.derived.(^ast.Ident)
					if !iok || ident == nil {continue}
					parse_signal_field(&s, floc, ident.name, arity, params, val, has)
				}
				continue
			}
			if param, is_sn := signal_n_param(f.type, s.godot_alias); is_sn {
				for nm in f.names {
					ident, iok := nm.derived.(^ast.Ident)
					if !iok || ident == nil {continue}
					parse_signal_n_field(&s, src, floc, ident.name, param, has)
				}
				continue
			}
		}

		// `gd:"manual"` on an embedded sim block opts its @(gd_tick) OUT of
		// auto-hoist — the wielder's own tick drives it. It still recurses like
		// an untagged embed (so its predict fields flatten into the descriptor);
		// only the auto-call is suppressed, via the `manual` flag threaded below.
		is_manual := has && strings.trim_space(val) == "manual"
		if !has || is_manual {
			// No gd tag (or `manual`): this may be a `using`/embedded sub-struct whose
			// fields carry gd tags. Resolve the field's type (same-package or imported
			// bundle) and recurse so nested `gd:"replicate"` (and, through `using`,
			// export/onready/signal) fields are discovered. Non-struct / unresolved /
			// typo'd types don't resolve and are skipped (nested-replicate-fields).
			nested := normalize_godot_qualifier(node_text(src, f.type), s.godot_alias)
			if def, subst, ok := resolve_type(nest_ctx, nested); ok {
				if is_manual && def.tick.proc_name == "" {
					error_at(
						floc,
						"%s.%s: `gd:\"manual\"` only applies to an embedded sim block with an @(gd_tick) — %q has none",
						s.struct_name, field_label, nested,
					)
				}
				entry_using := .Using in f.flags
				for nm in f.names {
					ident, iok := nm.derived.(^ast.Ident)
					if !iok || ident == nil {continue}
					// `using` flattens (members keep their leaf name); a plain embed
					// namespaces them under `<field>_` (see recurse_into / walk_members).
					name_prefix := entry_using ? "" : strings.concatenate({ident.name, "_"})
					visited := make(map[string]bool)
					recurse_into(&s, def, path_of(ident.name), &visited, name_prefix, subst, is_manual)
					delete(visited)
				}
			} else {
				if is_manual {
					error_at(
						floc,
						"%s.%s: `gd:\"manual\"` but the type %q didn't resolve to a sim block",
						s.struct_name, field_label, nested,
					)
				}
				unresolved_embed_check(floc, s.struct_name, field_label, nested, .Using in f.flags, nest_ctx.imports)
			}
			continue
		}
		// Tag is comma-separated tokens. The FIRST token selects the kind:
		//   - `onready=PATH`  -> a private auto-wired node ref (richer-authoring #1)
		//   - `export[,SPEC]` -> a serialized @export property
		specs := strings.split(val, ",")
		if len(specs) == 0 {continue}
		tok0 := strings.trim_space(specs[0])

		type_text := normalize_godot_qualifier(node_text(src, f.type), s.godot_alias)

		// richer-authoring #1: `gd:"onready=Sprite"` — must be an object-handle/pointer field.
		// The rt.Onready table itself is built by the runtime reflection walk
		// (runtime/register_class.odin); scriptgen keeps only the cheap build-time checks.
		if strings.has_prefix(tok0, "onready=") {
			path := strings.trim_space(tok0[len("onready="):])
			if path == "" {
				error_at(floc, "%s.%s: `onready=` needs a node path", s.struct_name, field_label)
				continue
			}
			vi, ok := map_variant(type_text)
			if !ok || vi.enum_name != ".Object" {
				error_at(floc, "%s.%s: `onready` field must be an object/node handle or pointer (got %q)", s.struct_name, field_label, type_text)
			}
			continue
		}

		// friendslop toolkit: `gd:"replicate[,interp][,owner]"` — a kit/net replicated
		// field. Only names + options are recorded here; generate.odin emits the
		// knet.Entity_Desc (offset_of/size_of are the consumer compiler's job) plus a
		// #assert that rejects non-POD fields at compile time with the field's name.
		if tok0 == "replicate" {
			rep, rok := parse_replicate_info(type_text, specs, floc, s.struct_name, field_label)
			if !rok {continue}
			// Multi-name fields (`x, y: f32 `gd:"replicate"``) replicate each name.
			for nm in f.names {
				ident, iok := nm.derived.(^ast.Ident)
				if !iok || ident == nil {continue}
				r := rep
				r.field = ident.name
				r.path = path_of(ident.name)
				append(&s.replicates, r)
			}
			continue
		}

		// friendslop toolkit: `gd:"backup"` — HOST-LOCAL state for host migration
		// AND save/resume (the same bytes ride both, session.odin's split). generate
		// emits a version-hashed <class>_backup_write/_read codec over these fields,
		// so a takeover restores the campaign, not a diorama — no hand-matched
		// write_u8/read_u8 lists to drift. POD (scalars/structs/fixed arrays),
		// map[POD]POD, and [dynamic]POD are supported; anything else is a build error.
		if tok0 == "backup" {
			kind, key, elem, bad := classify_backup(type_text)
			if bad != "" {
				error_at(floc, "%s.%s: gd:\"backup\" can't serialize %s", s.struct_name, field_label, bad)
				continue
			}
			for nm in f.names {
				ident, iok := nm.derived.(^ast.Ident)
				if !iok || ident == nil {continue}
				append(&s.backups, Backup_Info{
					field = ident.name,
					path  = path_of(ident.name),
					kind  = kind,
					key   = key,
					elem  = elem,
				})
			}
			continue
		}

		// friendslop toolkit: `gd:"profile=Type"` on the class's ksess.Session
		// field — the DECLARATION form of session_profile_install: the named
		// POD struct is this game's per-player profile row. scriptgen folds
		// the row's field-by-field shape into NET_FINGERPRINT (a drifted
		// profile refuses the join like any other wire skew — the raw install
		// call left it outside the version door: same-size drift scrambled
		// rows silently) and installs it inside the generated ready thunk,
		// before the game's ready can *_start.
		if strings.has_prefix(tok0, "profile=") {
			pt := strings.trim_space(tok0[len("profile="):])
			switch {
			case pt == "":
				error_at(floc, "%s.%s: `profile=` names the row struct, e.g. gd:\"profile=Loadout\"", s.struct_name, field_label)
			case !strings.has_suffix(type_text, ".Session") && type_text != "Session":
				error_at(floc, "%s.%s: `profile=` belongs on the ksess.Session field (got %q) — the row installs into that session", s.struct_name, field_label, type_text)
			case s.profile_type != "":
				error_at(floc, "%s.%s: a second profile declaration (%q; already %q) — one row type per session", s.struct_name, field_label, pt, s.profile_type)
			case len(f.names) != 1:
				error_at(floc, "%s.%s: one session field per profile declaration", s.struct_name, field_label)
			case:
				s.profile_type = pt
				if ident, iok := f.names[0].derived.(^ast.Ident); iok && ident != nil {
					s.profile_ses = ident.name
				}
			}
			continue
		}

		if tok0 != "export" {
			if strings.has_prefix(tok0, "args=") {
				error_at(
					floc,
					"%s.%s: `args=` is only valid on a signal field (gd.Signal0 … gd.Signal4)",
					s.struct_name,
					field_label,
				)
				continue
			}
			// The field HAS a `gd:"..."` tag (tag_gd_value succeeded) but its first token is
			// neither `export` nor `onready=` — almost certainly a misspelling (`exprot`)
			// that would otherwise silently leave the field un-exported.
			error_at(
				floc,
				"%s.%s: unknown gd tag %q (expected `export`, `replicate`, `backup`, or `onready=PATH`)",
				s.struct_name,
				field_label,
				tok0,
			)
			continue
		}

		vi, ok := map_variant(type_text)
		if !ok {
			error_at(floc, "%s.%s: export field of unsupported type %q", s.struct_name, field_label, type_text)
			continue
		}

		// Hints/groups/defaults are parsed by the RUNTIME reflection walk from this same
		// tag (runtime/register_class.odin) — scriptgen only extracts what codegen itself
		// consumes: the `get=`/`set=` accessor proc names (wrapper emission), the
		// field's Variant type (wrapper marshalling + the ctor set), and the
		// `entity=Name:id` declaration (the kboot entity table).
		getter := ""
		setter := ""
		entity_val := ""
		resource_val := ""
		for si in 1 ..< len(specs) {
			spec := strings.trim_space(specs[si])
			if spec == "" {continue}
			name := spec
			value := ""
			if eq := strings.index(spec, "="); eq >= 0 {
				name = strings.trim_space(spec[:eq])
				value = strings.trim_space(spec[eq + 1:])
			}
			switch name {
			case "get":
				getter = value
			case "set":
				setter = value
			case "entity":
				entity_val = value
			case "resource":
				resource_val = value
			}
		}

		// `entity=Name:id` — this exported scene BODIES a wire entity: the tag
		// is the whole factory declaration (resolve_entities validates the
		// target and pairs the typed hooks once the full module is parsed).
		if entity_val != "" {
			target, sep, id_text := strings.partition(entity_val, ":")
			id, id_ok := strconv.parse_int(strings.trim_space(id_text))
			switch {
			case sep != ":" || !id_ok:
				error_at(floc, "%s.%s: `entity=` wants `Name:id` — the struct this scene bodies and its stable wire id (e.g. entity=Mob:3)", s.struct_name, field_label)
			case id <= 0 || id > 65535:
				error_at(floc, "%s.%s: entity id %d is out of range — pick 1..65535 (0 reads as \"none\", and the id must stay STABLE across builds: saves, rejoins, and backups carry it)", s.struct_name, field_label, id)
			case resource_val != "PackedScene":
				error_at(floc, "%s.%s: `entity=` belongs on a PackedScene export — tag the field `gd:\"export,resource=PackedScene,entity=%s\"`", s.struct_name, field_label, entity_val)
			case len(f.names) != 1:
				error_at(floc, "%s.%s: one scene field per entity — split the multi-name declaration", s.struct_name, field_label)
			case:
				append(&s.entities, Entity_Tag{
					field   = field_label,
					target  = strings.trim_space(target),
					type_id = id,
					line    = f.pos.line,
				})
			}
		}

		for nm in f.names {
			ident, _ := nm.derived.(^ast.Ident)
			if ident == nil {continue}
			append(&s.exports, Export_Info {
				name      = ident.name,
				type_text = type_text,
				vi        = vi,
				getter    = getter,
				setter    = setter,
				line      = ident.pos.line,
				doc       = extract_doc(f.docs),
			})
		}
	}

	scan_bound_procs(&s, path, src, &file)

	return s, true
}

// scan_bound_procs collects the procs bound to `s`'s script struct (first param
// `^<Struct>`) from ONE parsed file: the script's own file during parse_script,
// then every top-level HELPER file (no owner-struct) in the package — a grown
// class may spread its @(gd_method)/@(gd_command)/lifecycle procs across sibling
// files instead of living in one monolith. `path`/`src` are the file being
// SCANNED, so diagnostics point at the helper, not the class's home file.
scan_bound_procs :: proc(s: ^Script, path, src: string, file: ^ast.File) {
	self_type := strings.concatenate({"^", s.struct_name})
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok {continue}
		if len(vd.names) != 1 || len(vd.values) != 1 {continue}
		pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
		if !is_proc {continue}
		name_ident, _ := vd.names[0].derived.(^ast.Ident)
		if name_ident == nil {continue}
		proc_name := name_ident.name

		pt := pl.type
		if pt == nil || pt.params == nil || len(pt.params.list) == 0 {continue}
		first := pt.params.list[0]
		if node_text(src, first.type) != self_type {continue}

		// `@(gd_command[="predict"])` — a friendslop-toolkit command (kit/net command
		// loop). NOT a Godot-callable method: it is issued from Odin code via the
		// generated `<proc>_cmd` wrapper, so it never joins the method tables. Checked
		// before the lifecycle match so a command can never be misread as a hook.
		if has_attr(vd, "gd_command") {
			config, _ := attr_value(vd, "gd_command")
			parse_command(s, src, Loc{path, name_ident.pos.line}, proc_name, pt, config)
			continue
		}

		// `@(gd_tick[="contested"])` — the class's sim-lane step (kit/sim). Like
		// commands it is never a Godot method: the generated thunk + Sim_Set
		// are its only callers.
		if has_attr(vd, "gd_tick") {
			config, _ := attr_value(vd, "gd_tick")
			parse_tick(s, src, Loc{path, name_ident.pos.line}, proc_name, pt, config)
			continue
		}

		// `@(gd_sample)` / `@(gd_step[="authority"])` — the lane's GAME half:
		// the device read and the world pass. Never Godot methods: the
		// generated `<snake>_lane_init` wiring is their only caller.
		if has_attr(vd, "gd_sample") {
			config, _ := attr_value(vd, "gd_sample")
			parse_sample(s, src, Loc{path, name_ident.pos.line}, proc_name, pt, config)
			continue
		}
		if has_attr(vd, "gd_step") {
			config, _ := attr_value(vd, "gd_step")
			parse_step(s, src, Loc{path, name_ident.pos.line}, proc_name, pt, config)
			continue
		}

		// `gd_rpc` implies `gd_method`: an RPC must be a registered method to be dispatchable.
		is_gd_rpc := has_attr(vd, "gd_rpc")
		is_gd_method := has_attr(vd, "gd_method") || is_gd_rpc
		stripped := strip_struct_prefix(proc_name, s.struct_name)

		if kw, is_lc := lifecycle_keyword(stripped); is_lc {
			has_delta := count_params(pt) >= 2
			append(&s.lifecycles, Lifecycle_Info{keyword = kw, proc_name = proc_name, has_delta = has_delta})
			continue
		}
		// Typo hint: a struct-bound proc whose stripped name is one edit from a lifecycle
		// keyword, and which isn't an explicit @(gd_method), is very likely a misspelled hook
		// (`player_redy`) that will silently never run. Warn (non-fatal — it might be a helper).
		if !is_gd_method {
			if kw, near := nearest_lifecycle(stripped); near {
				warnf(
					"%s: proc %q looks like a misspelled `%s` lifecycle — it will NOT run as one",
					s.struct_name,
					proc_name,
					kw,
				)
			}
			// A bare @(gd_connect) compiles and silently never connects — the
			// auto-wire targets a REGISTERED method. The docs state the rule;
			// this enforces it.
			if _, has_conn := attr_value(vd, "gd_connect"); has_conn {
				error_at(
					Loc{path, name_ident.pos.line},
					"%s: proc %q wears @(gd_connect) without @(gd_method) — the connection targets a registered method, so bare it would silently never connect. Add @(gd_method).",
					s.struct_name, proc_name,
				)
			}
		}
		if is_gd_method {
			m, _ := build_method_info(src, pt, Loc{path, name_ident.pos.line}, proc_name, s.struct_name, false)
			append(&s.methods, m)

			// `@(gd_connect="signal")` — auto-connect owner.signal -> this method on READY.
			if sig, has := attr_value(vd, "gd_connect"); has {
				append(&s.connections, Connection_Info{signal = sig, method = m.gd_name})
			}

			// `@(gd_rpc[="..."])` — expose this method to Godot's high-level multiplayer.
			// `attr_value` is "" for the bare `@(gd_rpc)` form (=> all defaults).
			if is_gd_rpc {
				config, _ := attr_value(vd, "gd_rpc")
				append(&s.rpcs, parse_rpc_config(m.gd_name, config))
			}
		}
	}
}

// validate_script — contract checks that must wait until EVERY file's procs are
// in (a @(gd_command) may live in a helper file, so parse_script alone can't see
// the full set). Commands lean on the replication machinery: prediction reverts,
// torn-state restore, and reject-truth snapshots all need the Entity_Desc, and
// the wire header needs the entity's net identity. Missing either is a build
// error HERE, with the fix spelled out — not a nil-descriptor crash at runtime.
validate_script :: proc(s: ^Script) {
	// The coop dirty mask AND the sim predict/command masks are each a single
	// u64, so an entity tops out at 64 replicated fields (predicted ones are a
	// subset, bounded by the same ceiling). Past 64 the high fields' bits shift
	// out and SILENTLY stop replicating — caught here at build time, naming the
	// class, instead of shadow_make's bare runtime assert or a quiet desync.
	if len(s.replicates) > 64 {
		error_at(
			Loc{path = s.path},
			"%s has %d replicated fields — at most 64 (the delta dirty mask and the sim predict mask are each one u64); group related fields into a sub-struct (a fixed array counts as one field)",
			s.struct_name, len(s.replicates),
		)
	}
	if len(s.commands) > 0 {
		if len(s.replicates) == 0 {
			error_at(
				Loc{path = s.path},
				"%s declares @(gd_command) procs but no gd:\"replicate\" fields — commands mutate replicated state (prediction, revert, and reject-truth all run off the field descriptor)",
				s.struct_name,
			)
		}
		nt := s.net_id_type
		if i := strings.last_index(nt, "."); i >= 0 {nt = nt[i + 1:]}
		if nt != "Net_Id" {
			error_at(
				Loc{path = s.path},
				"%s declares @(gd_command) procs but no `net_id: knet.Net_Id` field — commands name their entity over the wire; add the field (the session/registry layer assigns it)",
				s.struct_name,
			)
		}
		// `any_seat` widens a verb's COMMAND scope to every seat — only
		// meaningful on a contested sim class, and silently dead anywhere
		// else, which is exactly the class of quiet flag this build step
		// exists to refuse.
		for c in s.commands {
			if !c.any_seat {continue}
			if s.tick.proc_name == "" && len(s.block_ticks) == 0 {
				error_at(
					Loc{path = s.path},
					"command %s: `any_seat` is a sim-lane declaration — %s does not tick, and coop verbs are host-validated and issuable by any seat already; drop it",
					c.proc_name, s.struct_name,
				)
			} else if !s.tick.contested {
				error_at(
					Loc{path = s.path, line = s.tick.line},
					"command %s: `any_seat` opens the verb to every seat on a CONTESTED class only — mark %s's tick @(gd_tick=\"contested\") (predict-the-contested-object), or drop any_seat (verbs stay owner-only)",
					c.proc_name, s.struct_name,
				)
			}
		}
	}
	if s.tick.proc_name != "" || len(s.block_ticks) > 0 {
		has_predict := false
		for r in s.replicates {
			if r.predict {
				has_predict = true
				break
			}
		}
		if !has_predict {
			error_at(
				Loc{path = s.path, line = s.tick.line},
				"%s ticks (own @(gd_tick) or an embedded block's) but no gd:\"replicate,predict\" fields — the sim lane snapshots and reconciles predicted state; tag the fields the ticks mutate",
				s.struct_name,
			)
		}
	}
}

// ---------------------------------------------------------------------------
// Consequence pairing: `<wrapper>_then` (verbs-and-consequences)
//
// A command's cross-entity half used to live in the untyped command hook —
// a switch on (entity type, cmd index) reading scratch fields the verb left
// behind. The name-paired consequence replaces that: declare a plain proc
// named after the command's WRAPPER plus `_then` and scriptgen threads it the
// issuer, the verb's wire args, and the verb's returned payload, firing it on
// the AUTHORITY only, right after the verb applies. Shapes (game form casts
// ctx.game_user — the session installs the factory's user there):
//
//   chest_take_then :: proc(game: ^Cave, self: ^Chest, by: knet.Player_Id, slot: i32, taken: kitems.Slot)
//   door_toggle_then :: proc(self: ^Door, by: knet.Player_Id)
//
// Composed commands pair on the hoisted name (`runner_weapon_fire_then`), so
// a block ships the verb and the game keeps the consequence — no index keying.

Then_Candidate :: struct {
	path:    string,
	line:    int,
	src:     string,
	pt:      ^ast.Proc_Type,
	vd:      ^ast.Value_Decl,
	claimed: bool, // paired with a command — unclaimed survivors get a likely-typo warning
}

// Collect every top-level name-paired candidate in one parsed file: `*_then`
// (command consequences), `*_spawned` / `*_freed` (entity-table hooks).
// Pairing happens in resolve_then / resolve_entities once every script's
// full command table and entity tags are known.
scan_then_procs :: proc(idx: ^map[string]Then_Candidate, path, src: string, file: ^ast.File) {
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok {continue}
		if len(vd.names) != 1 || len(vd.values) != 1 {continue}
		pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
		if !is_proc {continue}
		name_ident, _ := vd.names[0].derived.(^ast.Ident)
		if name_ident == nil {continue}
		interesting := strings.has_suffix(name_ident.name, "_then") ||
			strings.has_suffix(name_ident.name, "_fx") ||
			strings.has_suffix(name_ident.name, "_apply") ||
			strings.has_suffix(name_ident.name, "_edge") ||
			strings.has_suffix(name_ident.name, "_spawned") ||
			strings.has_suffix(name_ident.name, "_freed")
		if !interesting {
			// Session event halves (`<game>_player_joined` …) pair by full
			// suffix — index any candidate wearing one.
			for ev in SESSION_EVENTS {
				at := len(name_ident.name) - len(ev.suffix)
				if at > 0 && name_ident.name[at - 1] == '_' && name_ident.name[at:] == ev.suffix {
					interesting = true
					break
				}
			}
		}
		if !interesting {
			// Migration halves (`<game>_backup` …) — same full-suffix pairing.
			for spec in MIGRATION_HALVES {
				at := len(name_ident.name) - len(spec.suffix)
				if at > 0 && name_ident.name[at - 1] == '_' && name_ident.name[at:] == spec.suffix {
					interesting = true
					break
				}
			}
		}
		if !interesting {continue}
		if pl.type == nil {continue}
		idx[name_ident.name] = Then_Candidate{
			path = path,
			line = name_ident.pos.line,
			src  = src,
			pt   = pl.type,
			vd   = vd,
		}
	}
}

// Pair `s`'s commands with their `<wrapper>_then` consequences and validate the
// contract at build time — a mispaired consequence must be a build error here,
// not a proc that silently never fires (the exact bug class the pairing kills).
resolve_then :: proc(s: ^Script, idx: ^map[string]Then_Candidate) {
	for &cmd in s.commands {
		wrapper := len(cmd.path) > 0 ? fmt.tprintf("%s_%s", to_snake(s.struct_name), cmd.name) : cmd.proc_name
		then_name := fmt.tprintf("%s_then", wrapper)
		cand, found := idx[then_name]
		if !found {
			// A direct verb's payload has exactly one consumer — its consequence.
			// (A COMPOSED verb's payload is the block's offer; declining is fine.)
			if cmd.payload_count > 0 && len(cmd.path) == 0 {
				warn_at(
					Loc{path = s.path},
					"command %s returns a payload but no `%s` consequence proc consumes it",
					cmd.proc_name,
					then_name,
				)
			}
			continue
		}
		cand.claimed = true
		idx[then_name] = cand
		loc := Loc{path = cand.path, line = cand.line}

		if has_attr(cand.vd, "gd_command") || has_attr(cand.vd, "gd_method") || has_attr(cand.vd, "gd_rpc") {
			error_at(loc, "consequence %s must be a plain proc — it is generated into the command's authority path, never registered", then_name)
			continue
		}

		// Flatten param type texts (a field entry may declare several names).
		types := make([dynamic]string, context.temp_allocator)
		if cand.pt.params != nil {
			for f in cand.pt.params.list {
				t := strings.trim_space(node_text(cand.src, f.type))
				for _ in 0 ..< max(1, len(f.names)) {
					append(&types, t)
				}
			}
		}

		self_type := fmt.tprintf("^%s", s.struct_name)
		at := 0
		game := ""
		if len(types) > at && strings.has_prefix(types[at], "^") && types[at] != self_type {
			game = types[at][1:] // the leading game param — generated code casts ctx.game_user to it
			at += 1
		}
		if !(len(types) > at && types[at] == self_type) {
			error_at(
				loc,
				"consequence %s: expected `self: %s` %s — the shapes are (self, by, args…, payload…) or (game, self, by, args…, payload…)",
				then_name, self_type, game == "" ? "first" : "after the game param",
			)
			continue
		}
		at += 1

		by_ok := false
		if len(types) > at {
			base := types[at]
			if j := strings.last_index(base, "."); j >= 0 {base = base[j + 1:]}
			by_ok = base == "Player_Id"
		}
		if !by_ok {
			error_at(loc, "consequence %s: the param after `self` must be the issuer (`by: knet.Player_Id`)", then_name)
			continue
		}
		at += 1

		rest := len(types) - at
		if rest != len(cmd.args) + cmd.payload_count {
			error_at(
				loc,
				"consequence %s: expected the verb's %d wire arg(s) then its %d payload value(s) after `by` — found %d param(s)",
				then_name, len(cmd.args), cmd.payload_count, rest,
			)
			continue
		}
		args_ok := true
		for a, k in cmd.args {
			wire, _, wok := command_wire_type(types[at + k])
			if !wok || wire != a.wire {
				error_at(
					loc,
					"consequence %s: param %q must have the verb's wire arg type %s (found %s)",
					then_name, a.name, a.type_text, types[at + k],
				)
				args_ok = false
			}
		}
		if !args_ok {continue}
		// Payload param TYPES are the compiler's to hold: the generated call
		// site passes the verb's returned values straight through.

		cmd.then_proc = then_name
		cmd.then_game = game
	}
}

// After every script resolved: an unclaimed pairing candidate that TOUCHES a
// script struct (a ^Struct param) is a typo'd or half-deleted pairing — the
// proc would silently never fire, the exact bug class the pairing exists to
// kill — so it is an ERROR with the expected names spelled out. The pairing
// suffixes are RESERVED on procs that touch script structs: pair them or
// rename them. A suffix-named proc touching no script struct keeps the old
// behavior (a `_then` warns — its prefix is a wrapper name, unguessable
// here; the rest stay silent): an innocent helper in a math file is none of
// our business.
check_unclaimed_pairs :: proc(idx: ^map[string]Then_Candidate, script_snakes: map[string]bool, by_struct: map[string]^Script) {
	for name, cand in idx {
		if cand.claimed {continue}
		loc := Loc{path = cand.path, line = cand.line}

		// The script structs this proc touches (^Struct params) — the
		// reserved-suffix gate, and where the fix-hint comes from.
		targets := make([dynamic]^Script, context.temp_allocator)
		if cand.pt.params != nil {
			for f in cand.pt.params.list {
				t := strings.trim_space(node_text(cand.src, f.type))
				if !strings.has_prefix(t, "^") {continue}
				s, ok := by_struct[t[1:]]
				if !ok {continue}
				dup := false
				for x in targets {
					if x == s {dup = true; break}
				}
				if !dup {append(&targets, s)}
			}
		}

		// Session event halves first (their suffixes can nest the legacy ones:
		// `_entity_spawned` ends in `_spawned`): an unclaimed event-suffix proc
		// touching a GAME SHELL (a class with the kboot.Boot field) whose PREFIX
		// is one edit from the game's snake is a typo'd pairing — the generated
		// `<snake>_events` dispatch would never call it. A genuinely different
		// prefix (`cave_lobby_WAS_kicked`, a query) or a bootless struct is an
		// innocent name: no near-pairing, nothing to silently miss.
		ev_flagged := false
		for ev in SESSION_EVENTS {
			at := len(name) - len(ev.suffix)
			if at <= 0 || name[at - 1] != '_' || name[at:] != ev.suffix {continue}
			prefix := name[:at - 1]
			for t in targets {
				if t.boot_field == "" {continue}
				if !edit_distance_le1(prefix, to_snake(t.struct_name)) {continue}
				error_at(
					loc,
					"proc %q looks like a session event half, but it doesn't pair — the ksess.%s half on %s is %q. Pair it, or rename it.",
					name, ev.variant, t.struct_name, fmt.tprintf("%s_%s", to_snake(t.struct_name), ev.suffix),
				)
				ev_flagged = true
				break
			}
			break // suffixes never nest within the table — first match decides
		}
		if ev_flagged {continue}

		// Migration halves, same teaching: an unclaimed migration-suffix proc
		// touching a game shell whose prefix is one edit from the game's snake
		// is a typo'd pairing kboot would never call.
		mig_flagged := false
		for spec in MIGRATION_HALVES {
			at := len(name) - len(spec.suffix)
			if at <= 0 || name[at - 1] != '_' || name[at:] != spec.suffix {continue}
			prefix := name[:at - 1]
			for t in targets {
				if t.boot_field == "" {continue}
				if !edit_distance_le1(prefix, to_snake(t.struct_name)) {continue}
				error_at(
					loc,
					"proc %q looks like a migration half, but it doesn't pair — kboot.boot_migration's `%s` half on %s is %q. Pair it, or rename it.",
					name, spec.suffix, t.struct_name, fmt.tprintf("%s_%s", to_snake(t.struct_name), spec.suffix),
				)
				mig_flagged = true
				break
			}
			break // suffixes never nest within the table — first match decides
		}
		if mig_flagged {continue}

		switch {
		case strings.has_suffix(name, "_then"):
			// A typo'd EVENT `_then` (`cave_loby_player_joined_then`) would fall
			// into the command-wrapper wording below — name the event pairing.
			ev_then := false
			base := strings.trim_suffix(name, "_then")
			for ev in SESSION_EVENTS {
				at := len(base) - len(ev.suffix)
				if at <= 0 || base[at - 1] != '_' || base[at:] != ev.suffix {continue}
				prefix := base[:at - 1]
				for t in targets {
					if t.boot_field == "" {continue}
					if !edit_distance_le1(prefix, to_snake(t.struct_name)) {continue}
					error_at(
						loc,
						"proc %q looks like a session event's authority half, but it doesn't pair — the ksess.%s halves on %s are %q and %q. Pair it, or rename it.",
						name, ev.variant, t.struct_name,
						fmt.tprintf("%s_%s", to_snake(t.struct_name), ev.suffix),
						fmt.tprintf("%s_%s_then", to_snake(t.struct_name), ev.suffix),
					)
					ev_then = true
					break
				}
				break
			}
			if ev_then {continue}
			if len(targets) == 0 {
				warn_at(
					loc,
					"proc %q looks like a command consequence, but no @(gd_command) generates a `%s` wrapper — it will never fire",
					name,
					strings.trim_suffix(name, "_then"),
				)
				continue
			}
			error_at(
				loc,
				"proc %q ends in `_then` but pairs with no verb or tick — it would silently never fire. %s Pair it, or rename it (`_then` is a reserved pairing suffix on procs touching script structs).",
				name, hint_then(targets[:]),
			)
		case strings.has_suffix(name, "_fx"):
			if len(targets) == 0 {continue}
			error_at(
				loc,
				"proc %q ends in `_fx` but pairs with no tick — it would silently never fire. %s Pair it, declare it `@(gd_fact)` (a world-pass fact's half — the generated `%s` door announces it), or rename it (`_fx` is a reserved pairing suffix on procs touching script structs).",
				name, hint_fx(targets[:]), strings.trim_suffix(name, "_fx"),
			)
		case strings.has_suffix(name, "_apply"):
			if len(targets) == 0 {continue}
			error_at(
				loc,
				"proc %q ends in `_apply` but pairs with no verb — it would silently never fire. %s Pair it, or rename it (`_apply` is a reserved pairing suffix on procs touching script structs).",
				name, hint_apply(targets[:]),
			)
		case strings.has_suffix(name, "_edge"):
			if len(targets) == 0 {continue}
			error_at(
				loc,
				"proc %q ends in `_edge` but pairs with no replicated delta-lane field — it would silently never fire. %s Pair it, or rename it (`_edge` is a reserved pairing suffix on procs touching script structs).",
				name, hint_edge(targets[:]),
			)
		case strings.has_suffix(name, "_spawned"):
			check_unclaimed_hook(loc, name, "_spawned", targets[:], script_snakes)
		case strings.has_suffix(name, "_freed"):
			check_unclaimed_hook(loc, name, "_freed", targets[:], script_snakes)
		}
	}
}

// The census hooks pair by NAME (`<target_snake>_spawned`/`_freed`) with an
// entity-tagged struct. Two ways to miss, both errors: the name matches a
// script that nothing entity-tags (tag the scene export), or a ^Target param
// says which entity the author meant while the prefix is typo'd (spell the
// expected name out).
@(private = "file")
check_unclaimed_hook :: proc(loc: Loc, name, suffix: string, targets: []^Script, script_snakes: map[string]bool) {
	kind := suffix == "_spawned" ? "spawn" : "free"
	if script_snakes[strings.trim_suffix(name, suffix)] {
		error_at(
			loc,
			"proc %q looks like an entity %s hook, but no scene field declares `entity=...` for that struct — it would silently never fire. Tag the scene export (`entity=Name:id`), or rename the proc.",
			name, kind,
		)
		return
	}
	for t in targets {
		for other in targets {
			for ent in other.entities {
				if ent.target != t.struct_name {continue}
				want := fmt.tprintf("%s%s", to_snake(t.struct_name), suffix)
				if name != want {
					error_at(
						loc,
						"proc %q has a ^%s param and ends in `%s`, but the %s hook pairs by NAME — `%s`. Rename it (or drop the suffix if it isn't the hook).",
						name, t.struct_name, suffix, kind, want,
					)
					return
				}
			}
		}
	}
}

// "Gunner pairs: gunner_buy_then, gunner_tick_then." — every _then the
// targeted classes generate, so the typo'd name has its fix beside it.
@(private = "file")
hint_then :: proc(targets: []^Script) -> string {
	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	for t in targets {
		if strings.builder_len(b) > 0 {strings.write_string(&b, " ")}
		names := make([dynamic]string, context.temp_allocator)
		for cmd in t.commands {
			wrapper := len(cmd.path) > 0 ? fmt.tprintf("%s_%s", to_snake(t.struct_name), cmd.name) : cmd.proc_name
			append(&names, fmt.tprintf("%s_then", wrapper))
		}
		if t.tick.proc_name != "" {
			append(&names, fmt.tprintf("%s_then", t.tick.proc_name))
		}
		if len(names) == 0 {
			fmt.sbprintf(&b, "%s declares no @(gd_command) verbs and no @(gd_tick), so nothing on it pairs a `_then`.", t.struct_name)
			continue
		}
		fmt.sbprintf(&b, "%s pairs: %s.", t.struct_name, strings.join(names[:], ", ", context.temp_allocator))
	}
	return strings.to_string(b)
}

@(private = "file")
hint_fx :: proc(targets: []^Script) -> string {
	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	for t in targets {
		if strings.builder_len(b) > 0 {strings.write_string(&b, " ")}
		if t.tick.proc_name != "" {
			fmt.sbprintf(&b, "%s's tick pairs as `%s_fx`.", t.struct_name, t.tick.proc_name)
		} else {
			fmt.sbprintf(&b, "%s has no @(gd_tick), so nothing on it pairs an `_fx`.", t.struct_name)
		}
	}
	return strings.to_string(b)
}

@(private = "file")
hint_edge :: proc(targets: []^Script) -> string {
	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	for t in targets {
		if strings.builder_len(b) > 0 {strings.write_string(&b, " ")}
		names := make([dynamic]string, context.temp_allocator)
		for r in t.replicates {
			if r.owner || r.predict {continue} // the delta lane only
			append(&names, fmt.tprintf("%s_%s_edge", to_snake(t.struct_name), strings.join(r.path, "_", context.temp_allocator)))
		}
		if len(names) == 0 {
			fmt.sbprintf(&b, "%s has no delta-lane replicated fields, so nothing on it edges.", t.struct_name)
			continue
		}
		fmt.sbprintf(&b, "%s's fields pair: %s.", t.struct_name, strings.join(names[:], ", ", context.temp_allocator))
	}
	return strings.to_string(b)
}

@(private = "file")
hint_apply :: proc(targets: []^Script) -> string {
	b: strings.Builder
	strings.builder_init(&b, context.temp_allocator)
	for t in targets {
		if strings.builder_len(b) > 0 {strings.write_string(&b, " ")}
		names := make([dynamic]string, context.temp_allocator)
		for cmd in t.commands {
			append(&names, fmt.tprintf("%s_apply", cmd.proc_name))
		}
		if len(names) == 0 {
			fmt.sbprintf(&b, "%s declares no @(gd_command) verbs, so nothing on it pairs an `_apply`.", t.struct_name)
			continue
		}
		fmt.sbprintf(&b, "%s's verbs pair: %s.", t.struct_name, strings.join(names[:], ", ", context.temp_allocator))
	}
	return strings.to_string(b)
}

// ---------------------------------------------------------------------------
// Entity tables: `entity=Name:id` on exported PackedScene fields
//
// The tag is the whole factory declaration — scriptgen emits the TYPE consts,
// typed thunks, and the kboot.Entity_Kind table; kit/boot's boot_entities
// drives it. Validation is a build error HERE: a dangling target, a duplicate
// wire id, or a mis-shaped hook must never become a silently absent entity.

// Validate a `<target>_spawned` / `<target>_freed` hook's shape. The fixed
// shapes (owner rides only the spawn):
//   <t>_spawned :: proc(game: ^Game, self: ^Target, id: knet.Net_Id, owner: knet.Player_Id)
//   <t>_freed   :: proc(game: ^Game, self: ^Target, id: knet.Net_Id)
@(private = "file")
validate_entity_hook :: proc(cand: Then_Candidate, name, game_struct, target: string, want_owner: bool) -> bool {
	loc := Loc{path = cand.path, line = cand.line}
	if has_attr(cand.vd, "gd_command") || has_attr(cand.vd, "gd_method") || has_attr(cand.vd, "gd_rpc") {
		error_at(loc, "entity hook %s must be a plain proc — the generated table dispatches it, it is never registered", name)
		return false
	}
	types := make([dynamic]string, context.temp_allocator)
	if cand.pt.params != nil {
		for f in cand.pt.params.list {
			t := strings.trim_space(node_text(cand.src, f.type))
			for _ in 0 ..< max(1, len(f.names)) {
				append(&types, t)
			}
		}
	}
	want := want_owner ? 4 : 3
	shape := fmt.tprintf("proc(game: ^%s, self: ^%s, id: knet.Net_Id)", game_struct, target)
	if want_owner {
		shape = fmt.tprintf("proc(game: ^%s, self: ^%s, id: knet.Net_Id, owner: knet.Player_Id)", game_struct, target)
	}
	if len(types) != want ||
	   types[0] != fmt.tprintf("^%s", game_struct) ||
	   types[1] != fmt.tprintf("^%s", target) ||
	   type_base(types[2]) != "Net_Id" ||
	   (want_owner && type_base(types[3]) != "Player_Id") {
		error_at(loc, "entity hook %s: expected `%s` — the game param is the struct carrying the entity= tags", name, shape)
		return false
	}
	return true
}

@(private = "file")
type_base :: proc(t: string) -> string {
	base := t
	if i := strings.last_index(base, "."); i >= 0 {base = base[i + 1:]}
	return base
}

// Pair and validate one script's entity tags against the module. `by_struct`
// maps every script struct name to its parsed Script; `seen_ids` accumulates
// wire-id claims across the whole module (ids collide across FILES too).
resolve_entities :: proc(s: ^Script, by_struct: map[string]^Script, seen_ids: ^map[int]string, idx: ^map[string]Then_Candidate) {
	for &e in s.entities {
		loc := Loc{path = s.path, line = e.line}
		target, known := by_struct[e.target]
		if !known {
			error_at(loc, "entity %s: no script struct named %q in this module — the tag names the struct the scene bodies (its //gd:class file)", e.target, e.target)
			continue
		}
		if len(target.replicates) == 0 && len(target.commands) == 0 {
			error_at(
				loc,
				"entity %s: the struct has no gd:\"replicate\" fields or @(gd_command) procs — a wire entity needs a descriptor (tag its state, or drop the entity= declaration)",
				e.target,
			)
			continue
		}
		if prev, dup := seen_ids[e.type_id]; dup {
			error_at(loc, "entity %s: wire id %d is already claimed by %s — ids are the entity's wire identity and must be unique", e.target, e.type_id, prev)
			continue
		}
		seen_ids[e.type_id] = fmt.aprintf("%s (%s:%d)", e.target, s.path, e.line)
		e.has_tick = target.tick.proc_name != "" || len(target.block_ticks) > 0 // the kinds row carries the Sim_Set

		tsnake := to_snake(e.target)
		sp_name := strings.concatenate({tsnake, "_spawned"})
		if cand, found := idx[sp_name]; found {
			if validate_entity_hook(cand, sp_name, s.struct_name, e.target, want_owner = true) {
				e.spawned = sp_name
			}
			cand.claimed = true
			idx[sp_name] = cand
		}
		fr_name := strings.concatenate({tsnake, "_freed"})
		if cand, found := idx[fr_name]; found {
			if validate_entity_hook(cand, fr_name, s.struct_name, e.target, want_owner = false) {
				e.freed = fr_name
			}
			cand.claimed = true
			idx[fr_name] = cand
		}
	}
}

// Classify a `gd:"replicate,interp"` field's type into a knet.Lerp_Kind literal
// — how stream sampling blends it between two snapshots. f32/f64 scalars, fixed
// arrays of them, and the engine's float value types (real_t = f32 in standard
// builds) lerp; everything else returns "" and the caller rejects the tag.
interp_lerp_kind :: proc(type_text: string) -> string {
	t := strings.trim_space(type_text)
	// fixed arrays: [N]f32 / [N]f64 (and nested, e.g. [2][2]f32)
	if strings.has_prefix(t, "[") {
		if i := strings.index_byte(t, ']'); i >= 0 {
			return interp_lerp_kind(t[i + 1:])
		}
		return ""
	}
	switch t {
	case "f32":
		return ".F32"
	case "f64":
		return ".F64"
	}
	base := t
	if i := strings.last_index(base, "."); i >= 0 {
		base = base[i + 1:]
	}
	switch base {
	case "Vector2", "Vector3", "Vector4", "Color":
		return ".F32"
	case "Quaternion":
		// NOT componentwise: rotations need hemisphere-safe nlerp (q == -q).
		return ".Quat"
	}
	return ""
}

// Map a command-arg type to kit/net's wire read_/write_ proc suffix plus the
// spelling spliced into the generated wrapper signature. Net_Id/Player_Id are
// normalized to the gen file's `knet.` qualifier whatever the author aliased
// `godot:kit/net` as. ok=false = not wire-serializable (the caller errors).
command_wire_type :: proc(type_text: string) -> (wire: string, splice: string, ok: bool) {
	t := strings.trim_space(type_text)
	base := t
	if i := strings.last_index(base, "."); i >= 0 {
		base = base[i + 1:]
	}
	switch base {
	case "Net_Id":
		return "net_id", "knet.Net_Id", true
	case "Player_Id":
		return "player_id", "knet.Player_Id", true
	}
	if base != t {
		return "", "", false // qualified non-kit/net type (gd.Vector2, ...)
	}
	switch t {
	case "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "f32", "f64", "bool", "string":
		return t, t, true
	}
	return "", "", false
}

// Build a Command_Info from one @(gd_command[="predict"]) proc. Cheap build-time
// contract checks live here: wire-serializable args only, and the proc must return
// exactly `bool` (true = applied; false = rejected, which auto-reverts the entity's
// declared fields on every peer). Shared by the entity scan (scan_bound_procs, direct
// commands) and the imported-package index (index_pkg_dir, composed commands).
//
// `struct_name` names the RECEIVER (`Runner` for a direct command, `Gun` for a composed
// one) — it only strips the proc-name prefix for the diagnostic verb. `allow_owner` is set
// for COMPOSED commands: a pointer parameter right after the receiver is the embedding
// entity (`owner: ^Entity` / `^$E`), which scriptgen fills with `self` rather than reading
// from the wire — so the block can touch its wielder. A direct command's receiver already
// IS the entity, so owner detection is off there and a pointer arg errors as un-wire-able.
// ok=false = a hard contract violation was reported (the caller drops the command).
build_command_info :: proc(
	src: string,
	pt: ^ast.Proc_Type,
	loc: Loc,
	proc_name, struct_name, config: string,
	allow_owner: bool,
) -> (
	Command_Info,
	bool,
) {
	cmd := Command_Info {
		proc_name = proc_name,
		name      = strip_struct_prefix(proc_name, struct_name),
	}
	ok := true

	for part in strings.split(config, ",") {
		tok := strings.trim_space(part)
		switch tok {
		case "":
		case "predict":
			cmd.predict = true
		case "any_seat":
			cmd.any_seat = true
		case:
			error_at(loc, "command %s: unknown config token %q (expected `predict` or `any_seat`)", proc_name, tok)
			ok = false
		}
	}

	// A composed command may name the embedding entity as its second param (a pointer, hence
	// never a wire arg). Detect and skip it — the decode thunk passes `self` there.
	start := 1
	if allow_owner && len(pt.params.list) > 1 {
		p1 := strings.trim_space(node_text(src, pt.params.list[1].type))
		if strings.has_prefix(p1, "^") {
			cmd.owner = true
			start = 2
		}
	}

	// The ISSUER param: `by: knet.Player_Id` next (shape-detected like the
	// wielder — the name AND type together are the declaration) is framework-
	// filled with the true issuer and never rides the wire, so a predicate can
	// arbitrate on WHO without trusting a client-claimed argument.
	if len(pt.params.list) > start && len(pt.params.list[start].names) == 1 {
		f := pt.params.list[start]
		if id, iok := f.names[0].derived.(^ast.Ident); iok && id != nil && id.name == "by" {
			base := strings.trim_space(node_text(src, f.type))
			if j := strings.last_index(base, "."); j >= 0 {base = base[j + 1:]}
			if base == "Player_Id" {
				cmd.wants_by = true
				start += 1
			}
		}
	}

	for fi in start ..< len(pt.params.list) {
		field := pt.params.list[fi]
		atext := strings.trim_space(node_text(src, field.type))
		wire, splice, wok := command_wire_type(atext)
		if !wok {
			if atext == "int" || atext == "uint" {
				error_at(
					loc,
					"command %s: arg type %q has platform-dependent width — command args cross the wire; use a fixed-width integer (i32, u16, ...)",
					proc_name,
					atext,
				)
			} else {
				error_at(
					loc,
					"command %s: unsupported arg type %q — command args must be wire primitives (fixed-width ints, f32/f64, bool, string, knet.Net_Id, knet.Player_Id)",
					proc_name,
					atext,
				)
			}
			ok = false
			continue
		}
		for nm in field.names {
			ident, iok := nm.derived.(^ast.Ident)
			if !iok || ident == nil {continue}
			// `by` is the RESERVED issuer name — a wire arg wearing it is either a
			// misplaced/mistyped issuer declaration or a client-claimed identity
			// (the exact spoofable-side wart the issuer param deletes). A player
			// the verb TARGETS stays legal under any other name (`who`, `target`).
			if ident.name == "by" {
				error_at(
					loc,
					"command %s: `by` is the reserved issuer param — declare it as `by: knet.Player_Id` immediately after the receiver and the framework fills it with the true issuer (it never rides the wire); an arg that merely names a player is fine as `who`/`target`",
					proc_name,
				)
				ok = false
				continue
			}
			append(&cmd.args, Command_Arg{name = ident.name, type_text = splice, wire = wire})
		}
	}

	// The FIRST result must be the applied bool. Results after it are the verb's
	// PAYLOAD — facts the run learned ("what was taken", "did a round leave") —
	// which never cross the wire: they thread straight into the name-paired
	// `<wrapper>_then` consequence on the authority, replacing the scratch-field
	// idiom. Payload types are unconstrained (in-process only); the generated
	// call site lets the compiler hold the `_then` signature to them.
	ret_ok := false
	if pt.results != nil && len(pt.results.list) > 0 && len(pt.results.list[0].names) <= 1 {
		ret_ok = strings.trim_space(node_text(src, pt.results.list[0].type)) == "bool"
		for extra in pt.results.list[1:] {
			cmd.payload_count += max(1, len(extra.names))
		}
	}
	if !ret_ok {
		error_at(
			loc,
			"command %s must return `bool` first — true = applied, false = rejected (a rejection auto-reverts the declared fields); results after it are the payload handed to a `%s_then` consequence",
			proc_name,
			proc_name,
		)
		ok = false
	}

	return cmd, ok
}

// A direct @(gd_command) on the entity itself: build it (owner threading is only for
// embedded blocks — the entity IS `self`) and append. Appended even on a contract error so
// the diagnostic isn't compounded by a phantom "unknown command"; had_error stops the build
// before generate() sees it.
parse_command :: proc(s: ^Script, src: string, loc: Loc, proc_name: string, pt: ^ast.Proc_Type, config: string) {
	cmd, _ := build_command_info(src, pt, loc, proc_name, s.struct_name, config, false)
	append(&s.commands, cmd)
}

// One @(gd_tick) proc — the class's sim-lane step. Accepted shapes, receiver first:
//
//   proc(self: ^T)                                  // inputless (a ball, a mover)
//   proc(self: ^T, input: T_Input)                  // driven by the owner's input
//   proc(self: ^T, lane: ^ksim.Lane)                // inputless, wants the lane (tick number, queries)
//   proc(self: ^T, input: T_Input, lane: ^ksim.Lane)
//
// A pointer param is the LANE (its type must end in `Lane`); a value param is
// the INPUT (a POD struct — it crosses the wire raw; the generated #assert
// enforces PODness at the consumer compile). No results: mutation IS the
// outcome — validation and rejection belong to @(gd_command) verbs.
parse_tick :: proc(s: ^Script, src: string, loc: Loc, proc_name: string, pt: ^ast.Proc_Type, config: string) {
	if s.tick.proc_name != "" {
		error_at(
			loc,
			"%s: second @(gd_tick) proc %q — %q already ticks this class; one tick per class, compose behavior inside it",
			s.struct_name, proc_name, s.tick.proc_name,
		)
		return
	}
	tk := Tick_Info{proc_name = proc_name, line = loc.line}
	ok := true

	for part in strings.split(config, ",") {
		tok := strings.trim_space(part)
		switch tok {
		case "":
		case "contested":
			// EVERY peer predicts this entity (the ball, the crown): contact
			// resolves on each screen's own timeline; the server reconciles.
			tk.contested = true
		case:
			error_at(loc, "tick %s: unknown config token %q (expected `contested`)", proc_name, tok)
			ok = false
		}
	}

	// Flatten the params after the receiver (one field entry may declare
	// several names — each is a param).
	types := make([dynamic]string, context.temp_allocator)
	for field in pt.params.list[1:] {
		text := strings.trim_space(node_text(src, field.type))
		for _ in 0 ..< max(1, len(field.names)) {
			append(&types, text)
		}
	}
	for text, i in types {
		if strings.has_prefix(text, "^") {
			base := text[1:]
			if j := strings.last_index(base, "."); j >= 0 {base = base[j + 1:]}
			if base != "Lane" || tk.wants_lane || i != len(types) - 1 {
				error_at(loc, "tick %s: unsupported param %q — the shape is (self[, input][, lane: ^ksim.Lane]); other state rides the entity or the lane", proc_name, text)
				ok = false
				continue
			}
			tk.wants_lane = true
			continue
		}
		if tk.input_type != "" {
			error_at(loc, "tick %s: a second value param %q — one input struct per tick; compose the fields into it", proc_name, text)
			ok = false
			continue
		}
		if text == "int" || text == "uint" {
			error_at(loc, "tick %s: input type %q has platform-dependent width — inputs cross the wire; wrap fixed-width fields in a struct", proc_name, text)
			ok = false
			continue
		}
		tk.input_type = text
	}

	// Results are the tick's PAYLOAD — facts it learned this tick (fired,
	// dashed, landed), threaded into the name-paired `<proc>_then` (authority
	// consequence) and `<proc>_fx` (presentation). They are not verdicts (a
	// tick can't reject), and they stay in-process unless the _fx declares
	// `mine` — the every-screen form, whose facts cross the wire (validated
	// against the wire primitives in resolve_tick_then).
	if pt.results != nil {
		for r in pt.results.list {
			text := strings.trim_space(node_text(src, r.type))
			for _ in 0 ..< max(1, len(r.names)) {
				tk.payload_count += 1
				append(&tk.payload_types, text)
			}
		}
	}

	if ok {
		s.tick = tk
	}
}

// One @(gd_sample) proc — the lane's device read, the ONE place that touches
// hardware (never called during a resim). Shape, receiver first:
//
//   proc(self: ^Game, tick: u64, input: ^Game_Input)
//
// The generated thunk writes through the pointer; resolve_sim pins T to a
// package @(gd_tick) input struct at build time, so sampling into a struct no
// tick reads dies here instead of desyncing quietly. One sample per input
// TYPE — a game driving two entity kinds declares two, one per kind.
parse_sample :: proc(s: ^Script, src: string, loc: Loc, proc_name: string, pt: ^ast.Proc_Type, config: string) {
	if config != "" {
		error_at(loc, "sample %s: @(gd_sample) takes no config (got %q)", proc_name, config)
		return
	}
	types := flatten_param_types(src, pt)
	if len(types) != 2 || types[0] != "u64" || !strings.has_prefix(types[1], "^") {
		error_at(loc, "sample %s: the shape is (self: ^%s, tick: u64, input: ^Your_Input)", proc_name, s.struct_name)
		return
	}
	if pt.results != nil {
		error_at(loc, "sample %s: no results — a sample WRITES the input struct; facts belong to ticks", proc_name)
		return
	}
	itype := types[1][1:]
	for existing in s.samples {
		if existing.input_type == itype {
			error_at(
				loc,
				"%s: a second @(gd_sample) writes %s — %q already fills that input class; one sample per input TYPE",
				s.struct_name, itype, existing.proc_name,
			)
			return
		}
	}
	append(&s.samples, Sim_Proc_Info{proc_name = proc_name, line = loc.line, input_type = itype})
}

// @(gd_step) procs — the lane's world passes, run AFTER entity ticks. Two
// slots, a class may fill one of each:
//
//   @(gd_step)              the EVERYWHERE pass — runs live AND in resims, on
//                           every peer: pure-sim contact between the pairs this
//                           peer has inputs for.
//   @(gd_step="authority")  the AUTHORITY pass — the host alone runs it, once
//                           per real tick (the authority never resims): respawn
//                           queues, adjudication sweeps, a match clock. A game
//                           needing both keeps them SEPARATE instead of folding
//                           `if lane_is_authority()` into one pass. In a
//                           package with NO @(gd_tick) classes this same
//                           declaration is the COOP game's host tick — routed
//                           through the boot accumulator (resolve_sim sets
//                           step_boot; generate emits `<snake>_step`).
//
// Shape, receiver first: proc(self: ^Game[, tick: u64]), no results. The tick
// param is the LANE's clock — a lane-routed step may take it; the boot-routed
// coop authority pass (resolve_sim) has no absolute tick and must omit it.
parse_step :: proc(s: ^Script, src: string, loc: Loc, proc_name: string, pt: ^ast.Proc_Type, config: string) {
	authority := false
	for part in strings.split(config, ",") {
		tok := strings.trim_space(part)
		switch tok {
		case "":
		case "authority":
			authority = true
		case:
			error_at(loc, "step %s: unknown config token %q (expected `authority`)", proc_name, tok)
			return
		}
	}
	types := flatten_param_types(src, pt)
	wants_tick := false
	switch {
	case len(types) == 0:
	case len(types) == 1 && types[0] == "u64":
		wants_tick = true
	case:
		error_at(loc, "step %s: the shape is (self: ^%s[, tick: u64])", proc_name, s.struct_name)
		return
	}
	if pt.results != nil {
		error_at(loc, "step %s: no results — world-pass facts are state; entity ticks carry payloads", proc_name)
		return
	}
	if authority {
		if s.step_auth.proc_name != "" {
			error_at(
				loc,
				"%s: second @(gd_step=\"authority\") proc %q — %q already runs the authority pass; one per lane, compose inside it",
				s.struct_name, proc_name, s.step_auth.proc_name,
			)
			return
		}
		s.step_auth = Sim_Proc_Info{proc_name = proc_name, line = loc.line, wants_tick = wants_tick}
	} else {
		if s.step.proc_name != "" {
			error_at(
				loc,
				"%s: second @(gd_step) proc %q — %q already runs the everywhere pass; mark one @(gd_step=\"authority\") if it's host-only adjudication",
				s.struct_name, proc_name, s.step.proc_name,
			)
			return
		}
		s.step = Sim_Proc_Info{proc_name = proc_name, line = loc.line, wants_tick = wants_tick}
	}
}

// The param type texts AFTER the receiver, one entry per declared name.
@(private = "file")
flatten_param_types :: proc(src: string, pt: ^ast.Proc_Type) -> []string {
	types := make([dynamic]string, context.temp_allocator)
	for field in pt.params.list[1:] {
		text := strings.trim_space(node_text(src, field.type))
		for _ in 0 ..< max(1, len(field.names)) {
			append(&types, text)
		}
	}
	return types[:]
}

// Every top-level proc name in one file — the package-wide name set that
// lets generated conveniences (census accessors) yield to hand-written
// procs name by name instead of colliding.
scan_proc_names :: proc(taken: ^map[string]bool, file: ^ast.File) {
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok || len(vd.names) != 1 || len(vd.values) != 1 {continue}
		if _, is_proc := vd.values[0].derived.(^ast.Proc_Lit); !is_proc {continue}
		if ident, iok := vd.names[0].derived.(^ast.Ident); iok && ident != nil {
			taken[ident.name] = true
		}
	}
}

// The typed census accessors yield to the game, name by name: an existing
// `runner_of` (scrapyard predates the generation with a player-keyed one)
// keeps its meaning; the other three still generate. Sets the per-tag flags
// generate() honors.
resolve_census :: proc(s: ^Script, taken: map[string]bool) {
	for &e in s.entities {
		tsnake := to_snake(e.target)
		e.gen_of = !taken[fmt.tprintf("%s_of", tsnake)]
		e.gen_owned = !taken[fmt.tprintf("%s_owned_by", tsnake)]
		e.gen_my = !taken[fmt.tprintf("my_%s", tsnake)]
		e.gen_ids = !taken[fmt.tprintf("%s_ids", tsnake)]
		e.gen_spawn = !taken[fmt.tprintf("%s_spawn", tsnake)]
	}
}

// Which probe return a replicated field's declared type maps to. Scalars
// only: compound fields (structs, arrays) are hand-written probes — a
// formatted view is game-shaped, not mechanical.
@(private = "file")
probe_scalar :: proc(type_text: string) -> (float, boolish, ok: bool) {
	t := type_text
	if i := strings.last_index(t, "."); i >= 0 {t = t[i + 1:]}
	switch t {
	case "f16", "f32", "f64", "Float":
		return true, false, true
	case "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "Int":
		return false, false, true
	case "bool", "b8", "b16", "b32", "b64":
		return false, true, true
	}
	return false, false, false
}

// The generated acid probes — the mechanical half of every game's hand-written
// queries.odin, synthesized as real @(gd_method)s so the test driver reads
// what this peer SEES with no game code. Per `entity=` kind: count, my-id,
// and one per replicated scalar field. Needs the boot (the census resolves
// through it); a hand-written proc wearing a probe's name wins, name by name.
resolve_probes :: proc(s: ^Script, by_struct: map[string]^Script, taken: map[string]bool) {
	if s.boot_field == "" || len(s.entities) == 0 {
		return
	}
	vi_int, iok := map_variant("gd.Int")
	vi_float, fok := map_variant("gd.Float")
	if !iok || !fok {
		return // unreachable: both are core Variant types
	}
	add :: proc(s: ^Script, taken: map[string]bool, p: Probe_Info, args: ..Arg) -> bool {
		if taken[p.name] {
			return false // hand-written wins
		}
		for m in s.methods {
			if m.gd_name == p.name {
				return false
			}
		}
		m := Method_Info {
			proc_name = fmt.tprintf("_%s_%s", to_snake(s.struct_name), p.name),
			gd_name   = p.name,
			ret       = p.form == .Field && p.float ? _probe_vi_float : _probe_vi_int,
		}
		for a in args {
			append(&m.args, a)
		}
		append(&s.methods, m)
		append(&s.probes, p)
		return true
	}
	_probe_vi_int = vi_int
	_probe_vi_float = vi_float
	id_arg := Arg{name = "id", type_text = "gd.Int", vi = vi_int}
	for e in s.entities {
		tsnake := to_snake(e.target)
		add(s, taken, Probe_Info{form = .Count, name = fmt.tprintf("probe_%s_count", tsnake), tsnake = tsnake, target = e.target})
		add(s, taken, Probe_Info{form = .My, name = fmt.tprintf("probe_my_%s", tsnake), tsnake = tsnake, target = e.target})
		tgt, known := by_struct[e.target]
		if !known {
			continue
		}
		for r in tgt.replicates {
			float, boolish, ok := probe_scalar(r.type_text)
			if !ok {
				continue
			}
			add(
				s, taken,
				Probe_Info{
					form = .Field,
					name = fmt.tprintf("probe_%s_%s", tsnake, strings.join(r.path, "_", context.temp_allocator)),
					tsnake = tsnake,
					target = e.target,
					access = strings.join(r.path, ".", context.temp_allocator),
					float = float,
					boolish = boolish,
				},
				id_arg,
			)
		}
	}
}

// resolve_probes' return-type scratch (Odin nested procs don't capture).
@(private = "file")
_probe_vi_int: Variant_Info
@(private = "file")
_probe_vi_float: Variant_Info

// The four standard transport forwards, written by nobody: a kboot.Boot
// field on the script struct declares them. Every session game wrote the
// same four one-liners (packet → wire_receive, peer_left/net_down →
// session_peer_disconnected, net_up → session_client_join) — and skipping
// the disconnect pair was the classic first playtest bug (an alt-F4'd
// friend haunts the roster; a failed join hangs on "Joining..."). Now the
// forwards exist by construction; a hand-written method of the same name
// wins, name by name. Runs BEFORE the method-name lint so boot_attach's
// methods list resolves against them like any @(gd_method).
resolve_boot_forwards :: proc(s: ^Script) {
	if s.boot_field == "" {
		return
	}
	vi_int, iok := map_variant("gd.Int")
	vi_pba, pok := map_variant("gd.Packed_Byte_Array")
	if !iok || !pok {
		return // unreachable: both are core Variant types
	}
	snake := to_snake(s.struct_name)
	add :: proc(s: ^Script, snake, name: string, args: ..Arg) {
		for m in s.methods {
			if m.gd_name == name {
				return // hand-written wins
			}
		}
		m := Method_Info {
			proc_name = fmt.tprintf("_%s_std_%s", snake, name),
			gd_name   = name,
			ret       = Variant_Info{enum_name = ".Nil", kind = .Nil},
		}
		for a in args {
			append(&m.args, a)
		}
		append(&s.methods, m)
		append(&s.std_forwards, name)
	}
	add(s, snake, "on_packet", Arg{name = "id", type_text = "gd.Int", vi = vi_int}, Arg{name = "packet", type_text = "gd.Packed_Byte_Array", vi = vi_pba})
	add(s, snake, "on_peer_left", Arg{name = "id", type_text = "gd.Int", vi = vi_int})
	add(s, snake, "on_net_up")
	add(s, snake, "on_net_down")
}

// Resolve the package's lane authoring surface, module-wide:
//
//   - every distinct @(gd_tick) input struct type is an input CLASS, assigned
//     a stable wire id (sorted by type name; 0 = primary). A player driving
//     two entity KINDS ships one input window per class each tick;
//   - each class's @(gd_sample) is matched to it by the struct it writes;
//   - @(gd_sample)/@(gd_step) live on ONE class — the game whose gen file
//     carries `<snake>_lane_init`.
resolve_sim :: proc(scripts: []^Script) {
	// The distinct input types across every tick in the package.
	types: [dynamic]string
	defer delete(types)
	for s in scripts {
		if s.tick.proc_name == "" || s.tick.input_type == "" {continue}
		seen := false
		for e in types {
			if e == s.tick.input_type {seen = true; break}
		}
		if !seen {append(&types, s.tick.input_type)}
	}
	slice.sort(types[:]) // stable ids: all peers rebuild together, so self-consistent is enough

	// Annotate each input-driven tick with the wire class its input rides.
	for s in scripts {
		if s.tick.proc_name == "" || s.tick.input_type == "" {continue}
		for ty, i in types {
			if ty == s.tick.input_type {
				s.tick.input_class = i
				break
			}
		}
	}

	// A package with no @(gd_tick) classes has no lane — an authority pass
	// there is the COOP game's fixed step, and it routes through the BOOT
	// accumulator instead: generate `<snake>_step(self, ticks)` (role gate +
	// same-frame edge pass inside), not lane wiring. The declaration is the
	// same either way — promoting a coop game to the sim lane just re-routes it.
	any_ticks := false
	for s in scripts {
		if s.tick.proc_name != "" || len(s.block_ticks) > 0 {
			any_ticks = true
			break
		}
	}

	// One lane owner per package: the class carrying @(gd_sample)/@(gd_step).
	// Its gen file gets <snake>_lane_init and every class registration.
	owner: ^Script
	for s in scripts {
		if len(s.samples) == 0 && s.step.proc_name == "" && s.step_auth.proc_name == "" {continue}
		if !any_ticks && len(s.samples) == 0 && s.step.proc_name == "" {
			// The boot-routed coop authority step.
			loc := Loc{path = s.path, line = s.step_auth.line}
			snake := to_snake(s.struct_name)
			if s.boot_field == "" {
				error_at(
					loc,
					"%s: @(gd_step=\"authority\") in a package with no @(gd_tick) classes rides the boot loop — %s needs a kboot.Boot field for the generated %s_step to gate on (or add the lane surface)",
					s.step_auth.proc_name, s.struct_name, snake,
				)
			} else if s.step_auth.wants_tick {
				error_at(
					loc,
					"%s: the boot-routed authority step is (self: ^%s) — there is no lane tick in the coop loop; count ticks in your own field (tag it gd:\"backup\" so a takeover resumes the count)",
					s.step_auth.proc_name, s.struct_name,
				)
			} else if s.step_auth.proc_name == fmt.tprintf("%s_step", snake) {
				error_at(
					loc,
					"%s: `%s_step` is the GENERATED wrapper's name (the role-gated per-frame call) — rename the authored pass (e.g. %s_host_tick)",
					s.step_auth.proc_name, snake, snake,
				)
			} else {
				s.step_boot = true
			}
			continue
		}
		if owner != nil {
			line := max(s.step.line, s.step_auth.line)
			if len(s.samples) > 0 {line = max(line, s.samples[0].line)}
			error_at(
				Loc{path = s.path, line = line},
				"%s declares @(gd_sample)/@(gd_step), but %s already does — one lane per package; a second lane is the hand-driven lane_set_sim's job",
				s.struct_name, owner.struct_name,
			)
			continue
		}
		owner = s
	}
	if owner == nil {return}

	// Pair each class with the sample that fills it (matched by input type). A
	// class with no sample is legal — those entities coast until owned, and the
	// wire registration takes a nil sample.
	for t, i in types {
		info := Input_Class_Info{class_id = i, type_name = t}
		for sm in owner.samples {
			if sm.input_type == t {
				info.sample = sm.proc_name
				info.line = sm.line
				break
			}
		}
		append(&owner.input_classes, info)
	}

	// No orphan samples: a @(gd_sample) writing a struct no @(gd_tick) reads
	// would feed nobody — the build error the single-input lane always raised.
	for sm in owner.samples {
		is_tick_input := false
		for t in types {
			if t == sm.input_type {is_tick_input = true; break}
		}
		if !is_tick_input {
			error_at(
				Loc{path = owner.path, line = sm.line},
				"%s: @(gd_sample) writes %s, but no @(gd_tick) in the package takes that input — the sample would feed nobody",
				sm.proc_name, sm.input_type,
			)
		}
	}
}

// A `@(gd_fact)` declaration found in the package scan — a world-pass fact's
// presentation half, held until resolve_facts (the lane owner isn't known
// before resolve_sim settles it). Collected by ATTRIBUTE, not suffix, so a
// misnamed declaration surfaces as a build error instead of a proc that
// silently never fires.
Fact_Candidate :: struct {
	path: string,
	line: int,
	src:  string,
	name: string,
	pt:   ^ast.Proc_Type,
	vd:   ^ast.Value_Decl,
}

scan_fact_procs :: proc(out: ^[dynamic]Fact_Candidate, path, src: string, file: ^ast.File) {
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok {continue}
		if len(vd.names) != 1 || len(vd.values) != 1 {continue}
		pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
		if !is_proc {continue}
		name_ident, _ := vd.names[0].derived.(^ast.Ident)
		if name_ident == nil {continue}
		if !has_attr(vd, "gd_fact") {continue}
		if pl.type == nil {continue}
		append(out, Fact_Candidate{
			path = path, line = name_ident.pos.line, src = src,
			name = name_ident.name, pt = pl.type, vd = vd,
		})
	}
}

// Resolve every `@(gd_fact)` declaration — the world-pass fact channel. The
// author writes ONE presentation half, `<event>_fx(game, anchor?, mine,
// args…)`; scriptgen generates the announce DOOR under the bare `<event>`
// name, and the door holds every gate the tick facts already get: the
// authority broadcasts (watchers fire on the watch clock, beside the delayed
// avatar), the causer's live pass fires now (mine=true), a resim replay never
// re-fires, screens with no part stay silent. An ANCHORED fact names an
// entity param after the game — the watch-clock anchor, the mine derivation
// (its tracked owner), and the despawn-drop all key on it. No anchor = a
// WORLD fact: the authority alone causes it (mine=true on its screen), every
// client presents it on the watch clock.
resolve_facts :: proc(scripts: []^Script, decls: []Fact_Candidate, idx: ^map[string]Then_Candidate, by_struct: map[string]^Script, taken: map[string]bool) {
	if len(decls) == 0 {return}

	// The lane owner resolve_sim settled: the class carrying @(gd_sample) or a
	// lane-routed @(gd_step). Facts ride its lane's watch clock.
	owner: ^Script
	for s in scripts {
		if len(s.samples) > 0 || s.step.proc_name != "" || (s.step_auth.proc_name != "" && !s.step_boot) {
			owner = s
			break
		}
	}

	RESERVED :: [?]string{"_then", "_fx", "_apply", "_edge", "_spawned", "_freed", "_cmd", "_spawn", "_step", "_events"}

	for cand in decls {
		loc := Loc{path = cand.path, line = cand.line}

		if v, _ := attr_value(cand.vd, "gd_fact"); v != "" {
			error_at(loc, "%s: @(gd_fact) takes no config — the shape declares everything (an entity param after the game = anchored; none = a world fact)", cand.name)
			continue
		}
		if has_attr(cand.vd, "gd_command") || has_attr(cand.vd, "gd_method") || has_attr(cand.vd, "gd_rpc") ||
		   has_attr(cand.vd, "gd_tick") || has_attr(cand.vd, "gd_step") || has_attr(cand.vd, "gd_sample") {
			error_at(loc, "%s: @(gd_fact) is a plain presentation half — it never registers, ticks, or decides; drop the other attribute", cand.name)
			continue
		}
		if !strings.has_suffix(cand.name, "_fx") {
			error_at(
				loc,
				"%s: a declared fact IS a presentation half — name it `%s_fx`; the step announces through the generated bare `%s` door",
				cand.name, cand.name, cand.name,
			)
			continue
		}
		door := strings.trim_suffix(cand.name, "_fx")
		if owner == nil {
			error_at(
				loc,
				"%s: @(gd_fact) rides the sim lane's watch clock, and this package has no lane (no @(gd_sample)/@(gd_step)) — coop presentation is `_edge` halves and session events (net.md)",
				cand.name,
			)
			continue
		}

		// The door is a generated proc under the bare event name — refuse the
		// names that can't be it.
		tick_clash := false
		for s in scripts {
			if s.tick.proc_name != "" && door == s.tick.proc_name {
				error_at(
					loc,
					"%s: that is %s's tick `_fx` — an entity tick's facts already broadcast through its own channel (return them from the tick); @(gd_fact) is for WORLD-PASS facts",
					cand.name, s.struct_name,
				)
				tick_clash = true
				break
			}
		}
		if tick_clash {continue}
		reserved_clash := false
		for suf in RESERVED {
			if strings.has_suffix(door, suf) {
				error_at(
					loc,
					"%s: the event name %q ends in the reserved suffix %q — the generated door would collide with that pairing family; rename the event",
					cand.name, door, suf,
				)
				reserved_clash = true
				break
			}
		}
		if reserved_clash {continue}
		if taken[door] {
			error_at(
				loc,
				"%s: `%s` is the GENERATED announce door's name and a proc already claims it — rename the hand-written `%s` (the door is the one path, so every announce holds the gates)",
				cand.name, door, door,
			)
			continue
		}
		if cmd_wire_id(door) == 0 {
			error_at(loc, "%s: the event name hashes to the reserved fact kind 0 — rename the event", cand.name)
			continue
		}

		// Shape: (game: ^<Owner>[, anchor: ^<Entity>], mine: bool, wire args…),
		// no results. Flatten params with their names.
		if cand.pt.results != nil {
			error_at(loc, "%s: a fact presents, it decides nothing — no results (consequences belong to verbs and ticks)", cand.name)
			continue
		}
		types := make([dynamic]string, context.temp_allocator)
		names := make([dynamic]string, context.temp_allocator)
		if cand.pt.params != nil {
			for f in cand.pt.params.list {
				t := strings.trim_space(node_text(cand.src, f.type))
				for ni in 0 ..< max(1, len(f.names)) {
					append(&types, t)
					nm := ""
					if ni < len(f.names) {
						if ident, iok := f.names[ni].derived.(^ast.Ident); iok && ident != nil {
							nm = ident.name
						}
					}
					append(&names, nm)
				}
			}
		}
		game_type := fmt.tprintf("^%s", owner.struct_name)
		if !(len(types) > 0 && types[0] == game_type) {
			error_at(
				loc,
				"%s: the first param is the game — `g: %s` (the lane owner; the door threads it via lane_game). Shapes: (game, mine, args…) for a world fact, (game, anchor, mine, args…) anchored",
				cand.name, game_type,
			)
			continue
		}
		at := 1
		anchor := ""
		anchor_param := ""
		if len(types) > at && strings.has_prefix(types[at], "^") {
			target := types[at][1:]
			if target == owner.struct_name {
				error_at(loc, "%s: the game is not an anchor — a world fact just omits the param (every client presents on the watch clock)", cand.name)
				continue
			}
			if _, is_script := by_struct[target]; !is_script {
				error_at(
					loc,
					"%s: anchor `%s` is not a script class in this package — the anchor is the lane-tracked entity the fact presents beside (its owner derives `mine`; its despawn drops late facts)",
					cand.name, types[at],
				)
				continue
			}
			anchor = target
			anchor_param = names[at] != "" ? names[at] : "anchor"
			at += 1
		}
		if !(len(types) > at && types[at] == "bool" && names[at] == "mine") {
			error_at(
				loc,
				"%s: `mine: bool` comes %s — the every-screen law: mine=true on the screen whose live simulation caused it, false on watchers (fired when their watch clock reaches the fact's tick)",
				cand.name, anchor == "" ? "after the game param" : "after the anchor",
			)
			continue
		}
		at += 1

		info := Fact_Info{
			name = door, fx_proc = cand.name, game = owner.struct_name,
			anchor = anchor, anchor_param = anchor_param,
			line = cand.line, path = cand.path,
		}
		args_ok := true
		for i in at ..< len(types) {
			wire, _, wok := command_wire_type(types[i])
			if !wok {
				error_at(
					loc,
					"%s: the fact tuple crosses the wire to watching screens, and %q is not a wire primitive (fixed-width ints, f32/f64, bool, string, knet.Net_Id, knet.Player_Id)",
					cand.name, types[i],
				)
				args_ok = false
				break
			}
			if names[i] == "l" || anchor_param == "l" {
				error_at(loc, "%s: `l` is the generated door's lane param — rename yours", cand.name)
				args_ok = false
				break
			}
			append(&info.arg_names, names[i] != "" ? names[i] : fmt.tprintf("a%d", i - at))
			append(&info.arg_types, types[i])
			append(&info.arg_wires, wire)
		}
		if !args_ok {continue}

		// One event, one door: a second declaration of the same name (any
		// file) or a u16 hash collision is fatal on the wire — name both.
		dup := false
		for f in owner.facts {
			if f.name == door {
				error_at(loc, "%s: fact %q is already declared at %s:%d — one door per event", cand.name, door, f.path, f.line)
				dup = true
				break
			}
			if cmd_wire_id(f.name) == cmd_wire_id(door) {
				error_at(loc, "facts %q and %q collide on wire id 0x%x — rename one event", f.name, door, cmd_wire_id(door))
				dup = true
				break
			}
		}
		if dup {continue}

		// Claim the `_fx` idx entry so the unclaimed-suffix sweep stays quiet.
		if c2, found := idx[cand.name]; found {
			c2.claimed = true
			idx[cand.name] = c2
		}

		append(&owner.facts, info)
	}
}

// Pair a game shell's SESSION EVENT halves — the name-paired replacement for
// the event-drain switch. For each SESSION_EVENTS row the game may declare:
//
//   <game>_<suffix>      :: proc(self: ^Game, <the event's fields>)  // fires wherever the event fires
//   <game>_<suffix>_then :: proc(self: ^Game, <the event's fields>)  // AUTHORITY only (two-role events)
//
// The generated `<snake>_events(self, events)` dispatch holds the switch AND
// the role gate, so neither survives in game code. Halves live on the game
// SHELL — the class with the kboot.Boot field, whose session the gate reads;
// a bootless class resolves nothing here (it has no generated dispatch to
// call, so a stray half surfaces as an undeclared-name error at the call
// site, never a silent no-fire).
resolve_session_events :: proc(s: ^Script, idx: ^map[string]Then_Candidate) {
	if s.boot_field == "" {
		return
	}
	snake := to_snake(s.struct_name)
	for ev, ei in SESSION_EVENTS {
		bare_name := fmt.tprintf("%s_%s", snake, ev.suffix)
		then_name := fmt.tprintf("%s_then", bare_name)
		half := Event_Half{ev = ei}
		if cand, found := idx[bare_name]; found {
			cand.claimed = true
			idx[bare_name] = cand
			if check_event_half(s, ev, bare_name, cand) {
				half.bare = bare_name
			}
		}
		if cand, found := idx[then_name]; found {
			// Claimed either way — the diagnosis here beats the unclaimed-_then
			// fallback (which would talk about @(gd_command) wrappers).
			cand.claimed = true
			idx[then_name] = cand
			loc := Loc{path = cand.path, line = cand.line}
			switch ev.role {
			case .Client:
				error_at(
					loc,
					"%s: ksess.%s never reaches the authority — there is no `_then` half; react in %s",
					then_name, ev.variant, bare_name,
				)
			case .Host:
				error_at(
					loc,
					"%s: ksess.%s is already authority-only — declare %s (the bare half) instead",
					then_name, ev.variant, bare_name,
				)
			case .Every:
				if check_event_half(s, ev, then_name, cand) {
					half.then_proc = then_name
				}
			}
		}
		if half.bare != "" || half.then_proc != "" {
			append(&s.event_halves, half)
		}
	}
}

// One event half's contract: a plain proc, `(self: ^Game, <the event's
// fields>)` exactly, no results — the generated dispatch passes the Ev
// struct's fields through positionally.
@(private = "file")
check_event_half :: proc(s: ^Script, ev: Session_Ev, name: string, cand: Then_Candidate) -> bool {
	loc := Loc{path = cand.path, line = cand.line}
	if has_attr(cand.vd, "gd_command") || has_attr(cand.vd, "gd_method") || has_attr(cand.vd, "gd_rpc") {
		error_at(loc, "%s must be a plain proc — the generated %s_events dispatch calls it, it is never registered", name, to_snake(s.struct_name))
		return false
	}
	base_of :: proc(t: string) -> string {
		b := t
		if j := strings.last_index(b, "."); j >= 0 {b = b[j + 1:]}
		return b
	}
	types := make([dynamic]string, context.temp_allocator)
	if cand.pt.params != nil {
		for f in cand.pt.params.list {
			t := strings.trim_space(node_text(cand.src, f.type))
			for _ in 0 ..< max(1, len(f.names)) {
				append(&types, t)
			}
		}
	}
	ok := len(types) == 1 + len(ev.params) && types[0] == fmt.tprintf("^%s", s.struct_name)
	if ok {
		for p, i in ev.params {
			if base_of(types[1 + i]) != base_of(p.type_) {
				ok = false
				break
			}
		}
	}
	if !ok || cand.pt.results != nil {
		shape := strings.builder_make(context.temp_allocator)
		fmt.sbprintf(&shape, "(self: ^%s", s.struct_name)
		for p in ev.params {
			fmt.sbprintf(&shape, ", %s: %s", p.name, p.type_)
		}
		strings.write_string(&shape, ")")
		error_at(
			loc,
			"%s: the shape is %s, no results — the generated dispatch passes ksess.%s's fields through",
			name, strings.to_string(shape), ev.variant,
		)
		return false
	}
	return true
}

// Pair a game shell's MIGRATION halves — kboot.boot_migration's four seams
// (the blob writer, the heir's read+mend, the non-entity pool wipe, the
// words). They pair on the SHELL by exact name, like session events; the
// generated `<snake>_succ_hooks` table carries them and the generated
// `<snake>_events` tail drains the kit's noted succession, so no fork, no
// wipe, no chase cap survives in game code.
resolve_migration :: proc(s: ^Script, idx: ^map[string]Then_Candidate) {
	if s.boot_field == "" {
		return
	}
	snake := to_snake(s.struct_name)
	slots := [?]^string{&s.succ_backup, &s.succ_took_over, &s.succ_wiped, &s.succ_migrating}
	for spec, i in MIGRATION_HALVES {
		name := fmt.tprintf("%s_%s", snake, spec.suffix)
		if cand, found := idx[name]; found {
			cand.claimed = true
			idx[name] = cand
			if check_migration_half(s, spec, name, cand) {
				slots[i]^ = strings.clone(name)
			}
		}
		then_name := fmt.tprintf("%s_then", name)
		if cand, found := idx[then_name]; found {
			cand.claimed = true
			idx[then_name] = cand
			error_at(
				Loc{path = cand.path, line = cand.line},
				"%s: migration halves have no `_then` — %s already runs on its fixed role (backup/took_over on the authority, wiped/migrating wherever the dance lands)",
				then_name, name,
			)
		}
	}
}

// One migration half's contract: a plain proc, `(self: ^Game, <the seam's
// params>)` exactly, no results — kboot calls it through the generated table.
@(private = "file")
check_migration_half :: proc(s: ^Script, spec: Migration_Half_Spec, name: string, cand: Then_Candidate) -> bool {
	loc := Loc{path = cand.path, line = cand.line}
	if has_attr(cand.vd, "gd_command") || has_attr(cand.vd, "gd_method") || has_attr(cand.vd, "gd_rpc") {
		error_at(loc, "%s must be a plain proc — kboot.boot_migration's generated table calls it, it is never registered", name)
		return false
	}
	base_of :: proc(t: string) -> string {
		b := t
		if j := strings.last_index(b, "."); j >= 0 {b = b[j + 1:]}
		return b
	}
	types := make([dynamic]string, context.temp_allocator)
	if cand.pt.params != nil {
		for f in cand.pt.params.list {
			t := strings.trim_space(node_text(cand.src, f.type))
			for _ in 0 ..< max(1, len(f.names)) {
				append(&types, t)
			}
		}
	}
	ok := len(types) == 1 + len(spec.params) && types[0] == fmt.tprintf("^%s", s.struct_name)
	if ok {
		for p, i in spec.params {
			if base_of(types[1 + i]) != base_of(p.type_) {
				ok = false
				break
			}
		}
	}
	if !ok || cand.pt.results != nil {
		shape := strings.builder_make(context.temp_allocator)
		fmt.sbprintf(&shape, "(self: ^%s", s.struct_name)
		for p in spec.params {
			fmt.sbprintf(&shape, ", %s: %s", p.name, p.type_)
		}
		strings.write_string(&shape, ")")
		error_at(
			loc,
			"%s: the shape is %s, no results — %s",
			name, strings.to_string(shape), spec.what,
		)
		return false
	}
	return true
}

// Pair a SIM-lane verb with its `<verb>_apply` half: the predicted-effect
// proc resims RE-RUN with the ledgered wire args (exact relative effects —
// an impulse — where the recorded-bytes patch would re-pin stale
// absolutes). Shape: (self: ^T, <the verb's wire args>), no results, no
// game param — it replays inside the tick pipeline, where only sim state
// exists. Declaring one on a class that doesn't tick is a build error: the
// half IS the resim's property.
resolve_command_applies :: proc(s: ^Script, idx: ^map[string]Then_Candidate) {
	ticks := s.tick.proc_name != "" || len(s.block_ticks) > 0
	for &c in s.commands {
		name := fmt.tprintf("%s_apply", c.proc_name)
		cand, found := idx[name]
		if !found {
			continue
		}
		loc := Loc{path = cand.path, line = cand.line}
		if !ticks {
			error_at(
				loc,
				"%s pairs a TICKING class's verb — %s doesn't tick, so its commands ride the knet loop and revert whole; predicted effects need the sim lane",
				name, s.struct_name,
			)
			continue
		}
		cand.claimed = true
		idx[name] = cand
		if has_attr(cand.vd, "gd_command") || has_attr(cand.vd, "gd_method") || has_attr(cand.vd, "gd_rpc") || has_attr(cand.vd, "gd_tick") {
			error_at(loc, "%s must be a plain proc — the generated verb thunk calls it, it is never registered", name)
			continue
		}
		types := make([dynamic]string, context.temp_allocator)
		if cand.pt.params != nil {
			for f in cand.pt.params.list {
				txt := strings.trim_space(node_text(cand.src, f.type))
				for _ in 0 ..< max(1, len(f.names)) {
					append(&types, txt)
				}
			}
		}
		ok := len(types) == 1 + len(c.args) && types[0] == fmt.tprintf("^%s", s.struct_name)
		if ok {
			for a, i in c.args {
				if types[1 + i] != a.type_text {
					ok = false
					break
				}
			}
		}
		if !ok || cand.pt.results != nil {
			error_at(
				loc,
				"%s: the shape is (self: ^%s, <%s's wire args>) with no results — resims re-run it with the LEDGERED args; facts belong to the verb",
				name, s.struct_name, c.proc_name,
			)
			continue
		}
		c.apply_proc = name
	}
}

// Pair a script's @(gd_tick) with its name-paired halves and validate the
// shapes at build time — the tick-domain mirror of resolve_then. The
// generated THUNK holds the role gates game code used to hand-write:
//
//   gunner_tick_then :: proc(game: ^Quickdraw, self: ^Gunner, by: knet.Player_Id, fired: bool, aim: f32)
//     AUTHORITY only, live and never resim (the authority never resims) —
//     the cross-entity consequence: adjudication, damage, pickups.
//   gunner_tick_fx :: proc(game: ^Quickdraw, self: ^Gunner, fired: bool, aim: f32)
//     the OWNING peer's LIVE pass only — muzzle flashes, sounds, shakes;
//     a resim replay never re-fires it.
//
// Both optional, both also accept the game-less (self-first) shape. Payload
// param TYPES are the compiler's to hold — the call site passes the tick's
// returned values straight through.
resolve_tick_then :: proc(s: ^Script, idx: ^map[string]Then_Candidate) {
	if s.tick.proc_name == "" {
		return
	}
	then_name := fmt.tprintf("%s_then", s.tick.proc_name)
	fx_name := fmt.tprintf("%s_fx", s.tick.proc_name)
	if game, _, ok := claim_tick_half(s, idx, then_name, true); ok {
		s.tick.then_proc = then_name
		s.tick.then_game = game
	}
	if game, mine, ok := claim_tick_half(s, idx, fx_name, false); ok {
		s.tick.fx_proc = fx_name
		s.tick.fx_game = game
		s.tick.fx_mine = mine
		if mine {
			// The every-screen form: the fact tuple crosses the wire to
			// watching screens, so every fact must be a wire primitive, and
			// at least one must be a bool — the EVENT trigger (the tuple
			// broadcasts on any tick a bool fact is true).
			cand := idx[fx_name]
			loc := Loc{path = cand.path, line = cand.line}
			bools := 0
			for ptype in s.tick.payload_types {
				wire, _, wok := command_wire_type(ptype)
				if !wok {
					error_at(
						loc,
						"%s declares `mine` — the tick's facts cross the wire to watching screens, and %q is not a wire primitive (fixed-width ints, f32/f64, bool, string, knet.Net_Id, knet.Player_Id)",
						fx_name, ptype,
					)
					continue
				}
				if wire == "bool" {
					bools += 1
				}
				append(&s.tick.payload_wires, wire)
			}
			if bools == 0 {
				error_at(
					loc,
					"%s declares `mine` but the tick returns no bool fact — a bool is the event trigger: the fact tuple broadcasts on any tick a bool fact is true",
					fx_name,
				)
			}
		}
	}
	if s.tick.payload_count > 0 && s.tick.then_proc == "" && s.tick.fx_proc == "" {
		warn_at(
			Loc{path = s.path, line = s.tick.line},
			"tick %s returns a payload but neither `%s` nor `%s` consumes it",
			s.tick.proc_name, then_name, fx_name,
		)
	}
}

// Pair each replicated field with its `<class>_<path>_edge` half — delta-lane
// change presentation, where THE PROC IS THE SUBSCRIPTION (no tag): declare it
// and the field's NET change per frame fires it with (old, new); don't, and
// the field costs nothing. The diff atom is the FIELD, so fields that must
// edge together are co-located into one POD struct (one field, one half, one
// atomic old/new). Delta lane only, held here: predicted state resims and
// owner-streamed state interpolates — each lane has its own presentation
// answer, and an edge on either would misfire by construction.
resolve_edges :: proc(s: ^Script, idx: ^map[string]Then_Candidate) {
	snake := to_snake(s.struct_name)
	for &r in s.replicates {
		name := fmt.tprintf("%s_%s_edge", snake, strings.join(r.path, "_", context.temp_allocator))
		cand, found := idx[name]
		if !found {continue}
		cand.claimed = true
		idx[name] = cand
		loc := Loc{path = cand.path, line = cand.line}

		field := fmt.tprintf("%s.%s", s.struct_name, strings.join(r.path, ".", context.temp_allocator))
		if r.predict {
			error_at(loc, "%s: %s is PREDICTED — the sim rewrites it on every reconcile, so a delta edge would fire on mispredict scrubs; predicted facts ride the mine-form `_fx` (sim.md)", name, field)
			continue
		}
		if r.owner {
			error_at(loc, "%s: %s is OWNER-STREAMED — it interpolates every frame; dress continuous state from the fields. `_edge` is the delta lane's", name, field)
			continue
		}
		if has_attr(cand.vd, "gd_command") || has_attr(cand.vd, "gd_method") || has_attr(cand.vd, "gd_rpc") || has_attr(cand.vd, "gd_tick") {
			error_at(loc, "%s must be a plain proc — the per-frame edge pass calls it, it is never registered", name)
			continue
		}
		if cand.pt.results != nil {
			error_at(loc, "%s: an edge half presents, it decides nothing — no results (consequences belong to verbs and ticks)", name)
			continue
		}

		types := make([dynamic]string, context.temp_allocator)
		if cand.pt.params != nil {
			for f in cand.pt.params.list {
				t := strings.trim_space(node_text(cand.src, f.type))
				for _ in 0 ..< max(1, len(f.names)) {
					append(&types, t)
				}
			}
		}
		self_type := fmt.tprintf("^%s", s.struct_name)
		at := 0
		game := ""
		if len(types) > at && strings.has_prefix(types[at], "^") && types[at] != self_type {
			game = types[at][1:]
			at += 1
		}
		if !(len(types) > at && types[at] == self_type) {
			error_at(loc, "%s: expected `self: %s` %s — the shapes are (self, old, new: %s) or (game, self, old, new: %s)", name, self_type, game == "" ? "first" : "after the game param", r.type_text, r.type_text)
			continue
		}
		at += 1
		// Compare BASE type names: an imported block's field type is spelled
		// bare at the block ("Gun_Mode") and qualified at the game
		// ("play.Gun_Mode") — both are the same type, and the generated call
		// site lets the compiler hold the exact match (the thunk derives the
		// cast with type_of, so no spelling is ever spliced).
		base_of :: proc(t: string) -> string {
			b := t
			if j := strings.last_index(b, "."); j >= 0 {b = b[j + 1:]}
			return b
		}
		if len(types) - at != 2 || types[at] != types[at + 1] || base_of(types[at]) != base_of(r.type_text) {
			error_at(loc, "%s: expected exactly `old, new: %s` after `self` (the field's declared type) — found %d param(s)%s", name, r.type_text, len(types) - at, len(types) > at ? fmt.tprintf(" starting with %q", types[at]) : "")
			continue
		}

		r.edge_proc = name
		r.edge_game = game
	}
}

@(private = "file")
claim_tick_half :: proc(s: ^Script, idx: ^map[string]Then_Candidate, name: string, wants_by: bool) -> (game: string, mine: bool, ok: bool) {
	cand, found := idx[name]
	if !found {
		return "", false, false
	}
	cand.claimed = true
	idx[name] = cand
	loc := Loc{path = cand.path, line = cand.line}

	if has_attr(cand.vd, "gd_command") || has_attr(cand.vd, "gd_method") || has_attr(cand.vd, "gd_rpc") || has_attr(cand.vd, "gd_tick") {
		error_at(loc, "%s must be a plain proc — the generated tick thunk calls it, it is never registered", name)
		return "", false, false
	}

	types := make([dynamic]string, context.temp_allocator)
	names := make([dynamic]string, context.temp_allocator)
	if cand.pt.params != nil {
		for f in cand.pt.params.list {
			t := strings.trim_space(node_text(cand.src, f.type))
			for ni in 0 ..< max(1, len(f.names)) {
				append(&types, t)
				nm := ""
				if ni < len(f.names) {
					if ident, iok := f.names[ni].derived.(^ast.Ident); iok && ident != nil {
						nm = ident.name
					}
				}
				append(&names, nm)
			}
		}
	}

	self_type := fmt.tprintf("^%s", s.struct_name)
	at := 0
	if len(types) > at && strings.has_prefix(types[at], "^") && types[at] != self_type {
		game = types[at][1:]
		at += 1
	}
	if !(len(types) > at && types[at] == self_type) {
		error_at(
			loc,
			"%s: expected `self: %s` %s — the shapes are (self%s, payload…) or (game, self%s, payload…)",
			name, self_type, game == "" ? "first" : "after the game param",
			wants_by ? ", by" : "", wants_by ? ", by" : "",
		)
		return "", false, false
	}
	at += 1

	if wants_by {
		by_ok := false
		if len(types) > at {
			base := types[at]
			if j := strings.last_index(base, "."); j >= 0 {base = base[j + 1:]}
			by_ok = base == "Player_Id"
		}
		if !by_ok {
			error_at(loc, "%s: the param after `self` must be the driving seat (`by: knet.Player_Id`)", name)
			return "", false, false
		}
		at += 1
	}

	// The presentation half may declare `mine: bool` right after `self` —
	// the EVERY-SCREEN form: the live pass fires it inline (mine=true), the
	// authority broadcasts the fact tuple, and watching screens fire it when
	// their watch clock reaches the fact's tick (mine=false). Detected by
	// NAME so an extra bool fact can never silently shift into the slot.
	if !wants_by && len(types) > at && types[at] == "bool" && names[at] == "mine" {
		mine = true
		at += 1
	}

	if len(types) - at != s.tick.payload_count {
		error_at(
			loc,
			"%s: expected the tick's %d payload value(s) after %s — found %d param(s)",
			name, s.tick.payload_count, wants_by ? "`by`" : (mine ? "`mine`" : "`self`"), len(types) - at,
		)
		return "", false, false
	}
	return game, mine, true
}

// Build a Method_Info from a @(gd_method)/@(gd_rpc) proc: the GDScript-exposed name (stripped),
// the Variant-mapped args, and the return. Shared by the entity scan (scan_bound_procs, direct
// methods) and the imported-package index (index_pkg_dir, composed block methods). Like commands,
// `allow_owner` (set for a composed method) treats a pointer param right after the receiver as the
// embedding entity — scriptgen fills it with `self`, it is not a Variant arg. rpc/connect config is
// the caller's to attach (it is attribute-based). ok=false = a contract violation was reported.
build_method_info :: proc(
	src: string,
	pt: ^ast.Proc_Type,
	loc: Loc,
	proc_name, struct_name: string,
	allow_owner: bool,
) -> (
	Method_Info,
	bool,
) {
	m := Method_Info {
		proc_name = proc_name,
		gd_name   = strip_struct_prefix(proc_name, struct_name),
		ret       = Variant_Info{enum_name = ".Nil", kind = .Nil},
		line      = loc.line,
	}
	ok := true
	// A composed method may name the embedding entity as its second param (a pointer, never a
	// Variant arg). Detect and skip it — the trampoline passes `self` there.
	start := 1
	if allow_owner && len(pt.params.list) > 1 {
		p1 := strings.trim_space(node_text(src, pt.params.list[1].type))
		if strings.has_prefix(p1, "^") {
			m.owner = true
			start = 2
		}
	}
	for fi in start ..< len(pt.params.list) {
		field := pt.params.list[fi]
		atext := node_text(src, field.type)
		vi, vok := map_variant(atext)
		if !vok {
			error_at(loc, "method %s: unsupported arg type %q", proc_name, atext)
			ok = false
			continue
		}
		for nm in field.names {
			ident, _ := nm.derived.(^ast.Ident)
			if ident == nil {continue}
			append(&m.args, Arg{name = ident.name, type_text = atext, vi = vi})
		}
	}
	if pt.results != nil && len(pt.results.list) > 0 {
		rtext := node_text(src, pt.results.list[0].type)
		vi, vok := map_variant(rtext)
		if !vok {
			error_at(loc, "method %s: unsupported return type %q", proc_name, rtext)
			ok = false
		} else {
			m.ret = vi
		}
	}
	return m, ok
}

// Extract the string value of a `@(name="value")` attribute. Returns ("", false) if the
// attribute is absent or not a string-valued Field_Value.
attr_value :: proc(vd: ^ast.Value_Decl, name: string) -> (string, bool) {
	for attr in vd.attributes {
		for elem in attr.elems {
			fv, ok := elem.derived.(^ast.Field_Value)
			if !ok {continue}
			ident, iok := fv.field.derived.(^ast.Ident)
			if !iok || ident.name != name {continue}
			lit, lok := fv.value.derived.(^ast.Basic_Lit)
			if !lok {return "", false}
			return strings.trim(lit.tok.text, "\"`"), true
		}
	}
	return "", false
}

// Total number of parameters (expanding multi-name fields).
count_params :: proc(pt: ^ast.Proc_Type) -> int {
	n := 0
	if pt.params == nil {return 0}
	for f in pt.params.list {
		n += max(1, len(f.names))
	}
	return n
}

// Parse the comma-separated `@(gd_rpc="...")` config string into an Rpc_Info. An empty
// `config` (bare `@(gd_rpc)`) yields the GDScript-default config. Recognized tokens:
//   - mode:     `authority` (default) | `any_peer`
//   - transfer: `reliable` (default) | `unreliable` | `unreliable_ordered`
//   - `call_local`         (default off)
//   - `channel=N`          (default 0)
// Unknown tokens are a codegen error (caught early, with the method name for context).
parse_rpc_config :: proc(method, config: string) -> Rpc_Info {
	r := Rpc_Info {
		method     = method,
		mode       = RPC_MODE_AUTHORITY,
		transfer   = TRANSFER_MODE_RELIABLE,
		call_local = false,
		channel    = 0,
	}
	if strings.trim_space(config) == "" {
		return r
	}
	for part in strings.split(config, ",") {
		tok := strings.trim_space(part)
		if tok == "" {continue}
		name := tok
		value := ""
		if eq := strings.index(tok, "="); eq >= 0 {
			name = strings.trim_space(tok[:eq])
			value = strings.trim_space(tok[eq + 1:])
		}
		switch name {
		case "authority":
			r.mode = RPC_MODE_AUTHORITY
		case "any_peer":
			r.mode = RPC_MODE_ANY_PEER
		case "reliable":
			r.transfer = TRANSFER_MODE_RELIABLE
		case "unreliable":
			r.transfer = TRANSFER_MODE_UNRELIABLE
		case "unreliable_ordered":
			r.transfer = TRANSFER_MODE_UNRELIABLE_ORDERED
		case "call_local":
			r.call_local = true
		case "channel":
			n, ok := strconv.parse_int(value)
			if !ok {
				errorf("rpc %q: `channel=` needs an integer (got %q)", method, value)
			} else {
				r.channel = n
			}
		case:
			errorf("rpc %q: unknown config token %q (want authority/any_peer/reliable/unreliable/unreliable_ordered/call_local/channel=N)", method, tok)
		}
	}
	return r
}

has_attr :: proc(vd: ^ast.Value_Decl, name: string) -> bool {
	for attr in vd.attributes {
		for elem in attr.elems {
			if ident, ok := elem.derived.(^ast.Ident); ok && ident.name == name {
				return true
			}
			// support `@(gd_method=...)` form (Field_Value)
			if fv, ok := elem.derived.(^ast.Field_Value); ok {
				if ident, iok := fv.field.derived.(^ast.Ident); iok && ident.name == name {
					return true
				}
			}
		}
	}
	return false
}

// ---- nested replicated fields (through `using`/embedded sub-structs) ---------
//
// A `gd:"replicate"` field can live inside a sub-struct the entity embeds — either
// promoted (`using m: Move`) or plain (`m: Move`, accessed `self.m.x`). parse_script
// recurses into any untagged field whose type resolves to a package struct (the
// g_struct_index), collecting each nested replicate field with its full ACCESS PATH
// from the entity root. generate.odin turns the path into a composed offset expression
// (`offset_of(Cls, m) + offset_of(type_of(Cls{}.m), x)`) that needs no import of the
// sub-struct's type — so this works identically for same-package and (later) imported
// bundles. See the nested-replicate-fields KB doc.

// A one-segment path (a top-level field). Heap-allocated so it outlives parse_script.
path_of :: proc(seg: string) -> []string {
	p := make([]string, 1)
	p[0] = seg
	return p
}

// prefix + [leaf], freshly allocated (sibling nested fields must not share backing).
extend_path :: proc(prefix: []string, leaf: string) -> []string {
	p := make([]string, len(prefix) + 1)
	copy(p, prefix)
	p[len(prefix)] = leaf
	return p
}

join_path :: proc(path: []string) -> string {
	return strings.join(path, ".")
}

// The identifier-safe join: {"weapon","ammo"} -> "weapon_ammo" — edge half
// names and their generated thunks, matching the hoisted-name convention.
join_snake :: proc(path: []string) -> string {
	return strings.join(path, "_")
}

// The entity-level name for a command or method composed from an embedded block: the access path
// joined with the verb by underscores. {"gun"} + "fire" -> "gun_fire"; {"loadout","primary"} +
// "fire" -> "loadout_primary_fire". Drives the command index const / decode thunk / issue wrapper
// and the method's registered name / trampoline — unique per field even for two blocks of the same
// type (primary vs secondary).
compose_member_name :: proc(path: []string, verb: string) -> string {
	b := strings.builder_make()
	for seg in path {
		strings.write_string(&b, seg)
		strings.write_byte(&b, '_')
	}
	strings.write_string(&b, verb)
	return strings.to_string(b)
}

// How the entity's generated file must reach a composed command's proc: the import alias +
// `godot:` path to qualify it with (play.gun_fire). ("","") when the block lives in the
// entity's OWN package — no qualifier, no import. `def_dir` is the block's package dir;
// `scripts_dir` the entity's. A `godot:kit/combat` block yields alias "kit_combat".
composed_pkg_ref :: proc(def_dir, scripts_dir: string) -> (alias, path: string) {
	if def_dir == scripts_dir || g_godot_root == "" {return "", ""}
	if !strings.has_prefix(def_dir, g_godot_root) {return "", ""}
	rel := strings.trim_prefix(def_dir[len(g_godot_root):], "/")
	if rel == "" {return "", ""}
	a := strings.builder_make()
	for i in 0 ..< len(rel) {
		strings.write_byte(&a, rel[i] == '/' ? '_' : rel[i])
	}
	return strings.to_string(a), strings.concatenate({"godot:", rel})
}

// THE SHELF LINT — the namespace contract, enforced where block-ness is
// actually asserted (the embed). `godot:play` is the coop/scratch shelf: its
// blocks ride the delta lane or stay local, so a gd:"replicate,predict"
// field there means the block was shelved one lane short — it belongs in
// `godot:play/sim`. And the mirror: a `godot:play/sim` block with NO
// predict-tagged fields isn't a sim block at all. Scoped to the two SHELF
// packages only (the block's dir under the godot: root at exactly play /
// play/sim) — game-local blocks compose however they like. Direct fields
// decide: a shelf block declares its own wire state.
shelf_lint :: proc(s: ^Script, def: Struct_Def, path: []string) {
	if g_godot_root == "" || !strings.has_prefix(def.dir, g_godot_root) {return}
	rel := strings.trim_prefix(def.dir[len(g_godot_root):], "/")
	if rel != "play" && rel != "play/sim" {return}
	has_predict := false
	for fld in def.fields {
		val, has := tag_gd_value(fld.tag)
		if !has {continue}
		specs := strings.split(val, ",", context.temp_allocator)
		if len(specs) == 0 || strings.trim_space(specs[0]) != "replicate" {continue}
		for spec in specs[1:] {
			if strings.trim_space(spec) == "predict" {
				has_predict = true
			}
		}
	}
	if rel == "play" && has_predict {
		error_at(
			Loc{path = s.path},
			"%s embeds %s (as %q) from the godot:play shelf, but the block carries gd:\"replicate,predict\" fields — predicted blocks live on the sim shelf: move it to play/sim (import psim \"godot:play/sim\")",
			s.struct_name, def.id, join_path(path),
		)
	} else if rel == "play/sim" && !has_predict {
		error_at(
			Loc{path = s.path},
			"%s embeds %s (as %q) from the godot:play/sim shelf, but the block carries no gd:\"replicate,predict\" fields — the sim shelf is for predicted blocks; timeline-free and coop blocks live on godot:play",
			s.struct_name, def.id, join_path(path),
		)
	}
}

// apply_subst rewrites whole-identifier generic parameters in a type text to their
// concrete args. With {S = "Gun_State"}: "S" -> "Gun_State", "Edge(S)" -> "Edge(Gun_State)",
// "[N]f32" -> "[4]f32" (with {N = "4"}). Only WHOLE identifiers are replaced, never a
// substring of a longer name. Empty subst returns the input untouched.
apply_subst :: proc(type_text: string, subst: map[string]string) -> string {
	if len(subst) == 0 {return type_text}
	b := strings.builder_make()
	i := 0
	for i < len(type_text) {
		c := type_text[i]
		if c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
			j := i
			for j < len(type_text) && is_ident_byte(type_text[j]) {j += 1}
			word := type_text[i:j]
			if repl, ok := subst[word]; ok {
				strings.write_string(&b, repl)
			} else {
				strings.write_string(&b, word)
			}
			i = j
		} else {
			strings.write_byte(&b, c)
			i += 1
		}
	}
	return strings.to_string(b)
}

// Detect a typed signal field (gd.Signal0 … Signal4 / gd.SignalN) from its normalized
// type text — used to reject signals inside nested structs (unsupported for now).
is_signal_field_type :: proc(type_text: string) -> bool {
	if _, _, ok := signal_type_params(type_text); ok {return true}
	return strings.has_prefix(type_text, "gd.SignalN(") || strings.has_prefix(type_text, "godot.SignalN(")
}

// Walk a resolved struct def's fields, appending each `gd:"replicate"` field to
// s.replicates (with its full access PATH, for the offset), generating a typed emit helper
// for each nested signal, and recursing into further untagged sub-structs (resolved through
// `def`'s own package + imports). `visited` (keyed by def id) guards cyclic type references.
// `name_prefix` is the engine-registration name prefix for members here: "" under an
// all-`using` path (members keep their promoted leaf name), or `<field>_<...>` accumulated
// through plain embeds — the SAME rule register_class.odin's walk_members applies, so the
// signal name scriptgen emits a helper for matches the name the runtime registers.
//
// Tag handling by kind:
//   * replicate — scanned through ANY nesting (using or plain, same-package or imported);
//     the wire keys fields by offset+order, so the name is irrelevant. scriptgen owns the descriptor.
//   * export/onready — registered (and validated) by the RUNTIME reflection walk; scriptgen
//     leaves them alone here (no line/doc/accessor metadata for nested exports yet).
//   * signal — registered by the runtime walk; scriptgen generates the typed `*_emit_*`
//     helper (arity family only — SignalN needs its AST payload node, which the index
//     doesn't carry, so it registers at runtime without a typed helper).
recurse_into :: proc(s: ^Script, def: Struct_Def, path: []string, visited: ^map[string]bool, name_prefix: string, subst: map[string]string, manual := false) {
	if visited[def.id] {return} // a type reachable from itself — stop, don't loop
	visited[def.id] = true
	defer delete_key(visited, def.id) // allow the same type at independent sibling positions

	{
		// Record the embedded-block name (def.id is "<dir>|<name>"): method-
		// family attributes on these receivers are legal (they hoist) —
		// lint_attributed_receivers exempts them.
		id := def.id
		if j := strings.last_index(id, "|"); j >= 0 {
			id = id[j + 1:]
		}
		g_embedded_blocks[id] = true
	}

	shelf_lint(s, def, path) // shelf blocks must sit on the lane their shelf names

	// verb-/method-composition (the dual of the nested-replicate collection below): hoist this
	// sub-struct's @(gd_command) and @(gd_method)/@(gd_rpc) procs onto the entity, keyed by the
	// access PATH to this field. The entity's generated file routes each thunk/trampoline into
	// `&self.<path>` and (if the block declared an owner param) passes `self`. Deeper embeds recurse
	// below and hoist under their longer paths, so a gun three levels down still registers on the
	// entity that owns the net id. The engine-facing name is path-prefixed (`weapon_reload`) so two
	// blocks of the same type never collide.
	if len(def.commands) > 0 || len(def.methods) > 0 || def.tick.proc_name != "" {
		alias, ppath := composed_pkg_ref(def.dir, dir_of(s.path))
		// Tick-composition: the block's step hoists onto the entity, routed
		// into `&self.<path>`, run AFTER the entity's own tick in field
		// order — the entity writes intent first, blocks integrate. A tick
		// that doesn't fit the block contract errors HERE, at the embed —
		// where block-ness is actually asserted.
		if def.tick.proc_name != "" && def.tick.bad != "" {
			error_at(
				Loc{path = s.path},
				"%s embeds %s (as %q), but its @(gd_tick) can't compose: %s",
				s.struct_name, def.id, join_path(path), def.tick.bad,
			)
		} else if def.tick.proc_name != "" && !manual {
			// `manual` (a `gd:"manual"` tag on the embed) opts OUT of auto-hoist:
			// the wielder's own tick drives this block's step wherever it wants
			// (any ordering, conditionally), so scriptgen must NOT also call it.
			// The predict fields still flatten (the walk below is unchanged) —
			// only the auto-call is skipped.
			append(&s.block_ticks, Hoisted_Tick{
				path        = path,
				pkg_alias   = alias,
				pkg_path    = ppath,
				proc_name   = def.tick.proc_name,
				wants_owner = def.tick.wants_owner,
				wants_lane  = def.tick.wants_lane,
			})
		}
		for c in def.commands {
			hoisted := c // shares the (read-only) args slice; path/name/pkg are entity-relative
			hoisted.path = path
			hoisted.pkg_alias = alias
			hoisted.pkg_path = ppath
			hoisted.name = compose_member_name(path, c.name)
			append(&s.commands, hoisted)
		}
		for mi in def.methods {
			hm := mi // shares the (read-only) args slice
			hm.path = path
			hm.pkg_alias = alias
			hm.pkg_path = ppath
			hm.gd_name = compose_member_name(path, mi.gd_name)
			append(&s.methods, hm)
			// Re-emit the rpc / connect config under the namespaced method name.
			if hm.is_rpc {
				rpc := mi.rpc
				rpc.method = hm.gd_name
				append(&s.rpcs, rpc)
			}
			if hm.connect != "" {
				append(&s.connections, Connection_Info{signal = hm.connect, method = hm.gd_name})
			}
		}
	}

	for fld in def.fields {
		fpath := extend_path(path, fld.name)
		// If `def` is a generic instantiation, resolve this field's generic params to the
		// concrete args first (`cur: S` -> `cur: Gun_State`) — so interp classification,
		// POD checks, and deeper resolution all see the real type. The OFFSET itself is
		// path-based (type_of at the consumer compile), so it resolves generics regardless.
		ftype := apply_subst(fld.type_text, subst)
		// Signals declare by TYPE (tag optional) — check before the tagged/skip branches.
		if is_signal_field_type(ftype) {
			if arity, params, ok := signal_type_params(ftype); ok {
				v, h := tag_gd_value(fld.tag)
				parse_signal_field(s, fld.loc, strings.concatenate({name_prefix, fld.name}), arity, params, v, h)
			}
			continue
		}
		val, has := tag_gd_value(fld.tag)
		if has {
			specs := strings.split(val, ",")
			if len(specs) > 0 && strings.trim_space(specs[0]) == "replicate" {
				rep, rok := parse_replicate_info(ftype, specs, fld.loc, s.struct_name, join_path(fpath))
				if rok {
					rep.field = fld.name
					rep.path = fpath
					append(&s.replicates, rep)
				}
			}
			// `gd:"backup"` rides nesting too (scrapyard tags host-local fields inside
			// a `using`-embedded sub-struct): collect it onto the class with its full
			// access path, exactly like replicate.
			if len(specs) > 0 && strings.trim_space(specs[0]) == "backup" {
				kind, key, elem, bad := classify_backup(ftype)
				if bad != "" {
					error_at(fld.loc, "%s.%s: gd:\"backup\" can't serialize %s", s.struct_name, join_path(fpath), bad)
				} else {
					append(&s.backups, Backup_Info{field = fld.name, path = fpath, kind = kind, key = key, elem = elem})
				}
			}
			// `gd:"profile=T"` is a TOP-LEVEL declaration on the game class's own
			// Session field — nested inside an embed it would silently never
			// install (neither the generated ready thunk nor the fingerprint
			// fold walks nested Sessions).
			if len(specs) > 0 && strings.has_prefix(strings.trim_space(specs[0]), "profile=") {
				error_at(
					fld.loc,
					"%s.%s: `profile=` declares on the class's OWN ksess.Session field — nested in an embed it silently never installs; move the declaration to the top level",
					s.struct_name, join_path(fpath),
				)
			}
			// export/onready (and any unknown tag) are the runtime reflection walk's to
			// register and validate — scriptgen owns only `replicate`/`backup` through nesting.
			continue
		}
		if sub, sub_subst, ok := resolve_type(def, ftype); ok {
			// `using` keeps the current name prefix; a plain embed extends it by `<field>_`.
			sub_prefix := fld.is_using ? name_prefix : strings.concatenate({name_prefix, fld.name, "_"})
			// A manual embed owns its whole subtree: the wielder drives this
			// block's tick, which drives its children — so a nested block under
			// a manual one must not auto-hoist either.
			recurse_into(s, sub, fpath, visited, sub_prefix, sub_subst, manual)
		} else {
			unresolved_embed_check(fld.loc, s.struct_name, join_path(fpath), ftype, fld.is_using, def.imports)
		}
	}
}

// The unresolved-embed trap (the recorded "gun that never replicated"): a
// field type the resolver can't see inside may CARRY kit tags — and skipping
// it as plain data makes replicate/backup/verbs vanish with no error. Same-
// package structs and godot: collection bundles resolve; this refuses the
// shapes that LOOK like tag-carrying embeds and provably can't be seen into:
// a relative/foreign-import qualified struct, a godot: bundle with no
// collection root, and a `using` embed that resolves to nothing. Engine
// (gd.) and stdlib (core:/base:/vendor:) types stay silent skips — they
// can't carry gd tags — and unqualified non-`using` misses stay silent too
// (a plain enum/union field is data, and a typo'd type is the compiler's
// error already).
// Struct names recurse_into embedded as blocks anywhere in the package —
// method-family attributes on THESE receivers are legal (composed blocks
// hoist @(gd_method)/@(gd_command) onto their wielder). Filled during parse,
// read by lint_attributed_receivers in pass 3.
g_embedded_blocks: map[string]bool

// A proc wearing a method-family attribute binds by its FIRST param
// (`self: ^<ScriptClass>`, or an embedded block's type — those hoist). Any
// other receiver binds to NOTHING: the method compiles and silently never
// registers — the reserved-suffix trap's attribute twin. Loud, per file.
lint_attributed_receivers :: proc(path, src: string, file: ^ast.File, script_structs: map[string]bool) {
	for decl in file.decls {
		vd, ok := decl.derived.(^ast.Value_Decl)
		if !ok {continue}
		if len(vd.names) != 1 || len(vd.values) != 1 {continue}
		pl, is_proc := vd.values[0].derived.(^ast.Proc_Lit)
		if !is_proc {continue}
		name_ident, _ := vd.names[0].derived.(^ast.Ident)
		if name_ident == nil {continue}
		attr := ""
		switch {
		case has_attr(vd, "gd_method"):
			attr = "gd_method"
		case has_attr(vd, "gd_rpc"):
			attr = "gd_rpc"
		case has_attr(vd, "gd_connect"):
			attr = "gd_connect"
		}
		if attr == "" {continue}
		recv := ""
		if pl.type != nil && pl.type.params != nil && len(pl.type.params.list) > 0 {
			recv = strings.trim_space(node_text(src, pl.type.params.list[0].type))
		}
		target := strings.has_prefix(recv, "^") ? recv[1:] : ""
		if j := strings.last_index(target, "."); j >= 0 {
			target = target[j + 1:]
		}
		if j := strings.index_byte(target, '('); j >= 0 {
			target = strings.trim_space(target[:j]) // a generic block receiver: ^Machine($S)
		}
		if target != "" && (script_structs[target] || g_embedded_blocks[target]) {
			continue
		}
		error_at(
			Loc{path = path, line = name_ident.pos.line},
			"proc %q wears @(%s) but its first param is %s — methods bind by receiver (`self: ^<ScriptClass>`, or an embedded block's type), so this one registers NOWHERE and silently never runs. Fix the receiver, or drop the attribute.",
			name_ident.name, attr, recv == "" ? "missing" : fmt.tprintf("%q", recv),
		)
	}
}

unresolved_embed_check :: proc(loc: Loc, class_name, field_label, type_text: string, is_using: bool, imports: map[string]string) {
	t := strings.trim_space(type_text)
	if len(t) == 0 || t[0] == '^' || strings.contains(t, "[") || strings.contains(t, "(") || strings.contains(t, "map[") {
		return // decorated types are never tag-carrying embeds
	}
	alias := ""
	name := t
	if dot := strings.index_byte(t, '.'); dot >= 0 {
		alias = t[:dot]
		name = t[dot + 1:]
	}
	if len(name) == 0 || !(name[0] >= 'A' && name[0] <= 'Z') {
		return // primitives and lowercase names: plain data by convention
	}
	if alias == "gd" || alias == "godot" {
		return // engine types are opaque on purpose
	}
	if alias != "" {
		imp, has := imports[alias]
		if !has {
			return // an alias the file never imported — the compiler's error, not ours
		}
		if strings.has_prefix(imp, "core:") || strings.has_prefix(imp, "base:") || strings.has_prefix(imp, "vendor:") {
			return // stdlib can't carry gd tags
		}
		if strings.has_prefix(imp, "godot:") {
			if g_godot_root == "" {
				error_at(
					loc,
					"%s.%s: %q rides import %q, but the godot: collection root is unknown (pass -godot:<root> or set ODIN_GODOT_ROOT) — the resolver can't see inside it, and gd:\"…\" tags on its fields would SILENTLY never register",
					class_name, field_label, t, imp,
				)
			}
			return // an indexed bundle whose name isn't a struct there: an enum/union — plain data
		}
		error_at(
			loc,
			"%s.%s: %q comes from import %q, which scriptgen cannot see inside — gd:\"…\" tags on its fields would SILENTLY never register (replicate, backup, and composed verbs all vanish). Move the struct into this package or a godot: collection bundle; plain data from elsewhere is fine by value under a non-struct type or behind ^.",
			class_name, field_label, t, imp,
		)
		return
	}
	if is_using {
		error_at(
			loc,
			"%s.%s: `using` embeds %q, but it doesn't resolve to a struct in this package — if it carries gd:\"…\" tags they would silently never register. Check the spelling, or drop `using` for plain data.",
			class_name, field_label, t,
		)
	}
}

// The verb's STABLE wire id: FNV-1a of the verb name, xor-folded to u16. What
// the generated constants hold and both command wires ship — reordering (or
// adding/removing) procs can no longer renumber the protocol; a version-skewed
// peer's unknown id MISSES the receiver's lookup and rejects cleanly instead
// of dispatching to whatever now lives at that position. A renamed verb is a
// new id on purpose: it IS a different verb.
cmd_wire_id :: proc(name: string) -> u16 {
	h: u32 = 0x811c9dc5
	for c in transmute([]u8)name {
		h = (h ~ u32(c)) * 0x01000193
	}
	return u16(h >> 16) ~ u16(h & 0xFFFF)
}

// Two verbs on one entity hashing to the same u16 — astronomically rare for a
// handful of names, deterministic, and fatal on the wire, so it's a build
// error naming both (rename one). Runs per script in main's resolution pass.
validate_command_ids :: proc(s: ^Script) {
	for c, i in s.commands {
		for j in i + 1 ..< len(s.commands) {
			o := s.commands[j]
			if cmd_wire_id(c.name) == cmd_wire_id(o.name) {
				error_at(
					Loc{path = s.path},
					"%s: commands %q and %q collide on wire id 0x%x — rename one verb",
					s.struct_name, c.name, o.name, cmd_wire_id(c.name),
				)
			}
		}
	}
}

// Classify a `gd:"backup"` field's type: a whole-POD value (scalar / POD struct
// / fixed [N]POD array), a map[POD]POD, or a [dynamic]POD. `bad` != "" is a
// rejection reason (a slice, a string — not self-contained + restorable); the
// caller reports it. Element PODness itself is enforced by the generated #assert.
classify_backup :: proc(type_text: string) -> (kind: Backup_Kind, key: string, elem: string, bad: string) {
	t := strings.trim_space(type_text)
	switch {
	case t == "string" || t == "cstring":
		return .Pod, "", "", "a string (not self-contained bytes) — copy it into a fixed [N]u8 or a [dynamic]u8"
	case strings.has_prefix(t, "map["):
		// Split key/value at the `]` that closes `map[`, honoring nested brackets
		// in the key (e.g. map[[2]int]V).
		depth := 0
		for i := 4; i < len(t); i += 1 {
			switch t[i] {
			case '[':
				depth += 1
			case ']':
				if depth == 0 {
					key = strings.trim_space(t[4:i])
					elem = strings.trim_space(t[i + 1:])
					if key == "" || elem == "" {
						return .Map, "", "", "a malformed map type"
					}
					return .Map, key, elem, ""
				}
				depth -= 1
			}
		}
		return .Map, "", "", "a malformed map type"
	case strings.has_prefix(t, "[dynamic]"):
		elem = strings.trim_space(t[len("[dynamic]"):])
		if elem == "" {
			return .Dyn, "", "", "a malformed dynamic-array type"
		}
		return .Dyn, "", elem, ""
	case strings.has_prefix(t, "[]"):
		return .Pod, "", "", "a slice (no owned storage to restore into) — use [dynamic]T or a map"
	case:
		// scalar / enum / vector / fixed [N]T array / POD struct — the whole
		// value's bytes ARE its state (the generated #assert enforces PODness).
		return .Pod, "", "", ""
	}
}

// Parse the OPTIONS half of a `gd:"replicate,..."` tag into a Replicate_Info (the
// caller fills in `field`/`path`). Shared by the top-level field loop and the nested
// walk. `specs` is the whole comma-split tag; specs[0] is "replicate". ok=false means
// the field can't be replicated and was already reported (skip it).
parse_replicate_info :: proc(
	type_text: string,
	specs: []string,
	floc: Loc,
	struct_name, field_label: string,
) -> (
	Replicate_Info,
	bool,
) {
	// Engine handle/heap types can never be replicated fields: object handles and Rids
	// are peer-local, and String/Array/Dictionary/Packed_* own heap memory a memcpy would
	// corrupt. Rejected HERE (with the type's name) because the generated POD #assert
	// can't see engine semantics — a gd.String is pointer-sized and memcmp-safe, and still
	// wrong to ship. POD engine value types (Vector2/3/4, Color, Transform*, ...) are fine.
	if vi, vok := map_variant(type_text); vok {
		denied :=
			vi.enum_name == ".Object" ||
			vi.enum_name == ".String" ||
			vi.enum_name == ".String_Name" ||
			vi.enum_name == ".Node_Path" ||
			vi.enum_name == ".Array" ||
			vi.enum_name == ".Dictionary" ||
			vi.enum_name == ".Callable" ||
			vi.enum_name == ".Signal" ||
			vi.enum_name == ".Rid" ||
			strings.has_prefix(vi.enum_name, ".Packed_")
		if denied {
			error_at(
				floc,
				"%s.%s: %q cannot be a replicated field — handles and heap-backed types don't cross the wire. Replicate POD state (ints/floats/bools/enums/vectors) and rebuild engine objects locally; send text/collections as explicit messages.",
				struct_name,
				field_label,
				type_text,
			)
			return {}, false
		}
	}
	// The COLLECTIONS stance, held at build time: variable-length state never
	// replicates as a field. The delta walk's whole contract is flat POD cells
	// (a shadow memcmp per field, a u64 dirty mask, byte-identical apply) — a
	// [dynamic]'s bytes are a header whose elements a memcpy would tear, and
	// element identity breaks byte-diffing anyway (insert-at-front shifts
	// every byte). The three honest shapes, all with worked examples:
	//   BOUNDED       -> a fixed array + count/sentinel (cavecrawl's [6]Slot
	//                    bag — one field, one diff atom; the cap is game
	//                    design, own it)
	//   RARE-CHANGE   -> an entity BLOB (session_set_blob — whole-value,
	//                    reliable, rides every snapshot; the inscription)
	//   LIVE ELEMENTS -> each element is an ENTITY: the registry IS the
	//                    diffed dynamic collection (spawn = insert, despawn
	//                    = remove, per-element fields diff normally; the
	//                    floor's pickups)
	if strings.has_prefix(type_text, "[dynamic]") ||
	   strings.has_prefix(type_text, "[]") ||
	   strings.has_prefix(type_text, "map[") {
		error_at(
			floc,
			"%s.%s: %q is variable-length — replicated fields are flat POD cells (the delta walk memcmps and memcpys them whole, and byte-diffing has no element identity). Pick the collection's real shape: BOUNDED -> fixed array + count/sentinel (`[6]Slot`); RARE-CHANGE bytes/text -> an entity blob (ksess.session_set_blob); LIVE elements -> spawn each as an ENTITY (the registry is the diffed collection). (gd:\"backup\" still takes [dynamic]/map — that codec restores whole, it never diffs.)",
			struct_name,
			field_label,
			type_text,
		)
		return {}, false
	}
	rep := Replicate_Info{type_text = type_text}
	for spec_raw in specs[1:] {
		spec := strings.trim_space(spec_raw)
		// `interp=NAME`: custom blend math — NAME is an author proc of type knet.Blend_Proc,
		// spliced verbatim into the generated descriptor (a missing/mistyped proc fails the
		// consumer compile on that line).
		if strings.has_prefix(spec, "interp=") {
			name := strings.trim_space(spec[len("interp="):])
			if name == "" {
				error_at(floc, "%s.%s: `interp=` needs `angle` or a blend proc name (a knet.Blend_Proc in this package)", struct_name, field_label)
				continue
			}
			// `interp=angle` is RESERVED: f32 radians blend the shortest arc
			// (a raw lerp from +3.1 to -3.1 sweeps the long way around) — the
			// built-in nobody should hand-write. Any other name is an author
			// Blend_Proc, spliced verbatim.
			if name == "angle" {
				if interp_lerp_kind(type_text) != ".F32" {
					error_at(floc, "%s.%s: `interp=angle` wants f32 radians (f32, or fixed arrays of f32) — %q isn't", struct_name, field_label, type_text)
					continue
				}
				rep.interp = true
				rep.lerp = ".Angle"
				continue
			}
			rep.interp = true
			rep.lerp = ".Custom"
			rep.blend = name
			continue
		}
		// `wire=f16` / `wire=NAME`: how the field's bytes are ENCODED in packets — half
		// floats (stock) or an author knet.Wire_Codec, spliced verbatim like a blend proc.
		// The struct-side value is untouched: shadows, prediction, and rings never see wire bytes.
		if strings.has_prefix(spec, "wire=") {
			name := strings.trim_space(spec[len("wire="):])
			if name == "" {
				error_at(floc, "%s.%s: `wire=` needs `f16` or a codec name (a knet.Wire_Codec in this package)", struct_name, field_label)
				continue
			}
			if name == "f16" {
				// The same classifier bare `interp` uses: .F32 means "f32 elements all the
				// way down" — exactly what a componentwise half-float encoding can carry.
				if interp_lerp_kind(type_text) != ".F32" {
					error_at(floc, "%s.%s: `wire=f16` needs f32 elements (f32, float vectors/colors, or fixed arrays of them) — %q has none to halve; use a custom codec with `wire=CODEC`", struct_name, field_label, type_text)
					continue
				}
				rep.wire = ".F16"
			} else {
				rep.wire = ".Custom"
				rep.codec = name
			}
			continue
		}
		// `slack=N`: this predicted float field's own reconcile tolerance (world
		// units), overriding the lane default — a fast contested object rides loose
		// drift while precise fields in the same lane stay tight. The numeric literal
		// is spliced into the descriptor as f32; validated float and predict-only below.
		if strings.has_prefix(spec, "slack=") {
			val := strings.trim_space(spec[len("slack="):])
			if _, ok := strconv.parse_f64(val); !ok {
				error_at(floc, "%s.%s: `slack=` needs a number — the reconcile tolerance in world units, e.g. slack=0.5", struct_name, field_label)
				continue
			}
			rep.slack = val
			continue
		}
		// `glide=N`: this field's render-error smoothing half-life (seconds), overriding
		// the lane default — a slow-gliding avatar and a snappy ball can share one lane.
		if strings.has_prefix(spec, "glide=") {
			val := strings.trim_space(spec[len("glide="):])
			if _, ok := strconv.parse_f64(val); !ok {
				error_at(floc, "%s.%s: `glide=` needs a number — the smoothing half-life in seconds, e.g. glide=0.1", struct_name, field_label)
				continue
			}
			rep.glide = val
			continue
		}
		// `cut=N`: this field's snap threshold (world units) — a reconcile error past it
		// is a teleport, and the whole entity snaps instead of gliding, overriding the lane.
		if strings.has_prefix(spec, "cut=") {
			val := strings.trim_space(spec[len("cut="):])
			if _, ok := strconv.parse_f64(val); !ok {
				error_at(floc, "%s.%s: `cut=` needs a number — the snap threshold in world units, e.g. cut=32", struct_name, field_label)
				continue
			}
			rep.cut = val
			continue
		}
		switch spec {
		case "interp":
			rep.interp = true
		case "owner":
			rep.owner = true
		case "predict":
			rep.predict = true
		case "":
		case:
			error_at(floc, "%s.%s: unknown replicate option %q (expected `interp`, `interp=angle`, `interp=BLEND_PROC`, `owner`, `predict`, `wire=f16`, or `wire=CODEC`)", struct_name, field_label, spec)
		}
	}
	// A field has ONE authority lane: `owner` streams from its owning peer,
	// `predict` is server-simulated and client-reconciled (kit/sim). Both at
	// once would mean two writers fighting over the same bytes every tick.
	if rep.predict && rep.owner {
		error_at(floc, "%s.%s: `owner` and `predict` are mutually exclusive — a field is owner-streamed OR server-sim-predicted, never both (pick the lane that owns its writes)", struct_name, field_label)
		return {}, false
	}
	// Bare `interp` must know HOW to blend: classify the declared type into a knet.Lerp_Kind
	// (quaternions get hemisphere-safe nlerp — a raw componentwise lerp garbles rotations near
	// the antipode). Non-float types can only snap — rejected loudly so a tagged int doesn't
	// silently stutter at the stream rate; `interp=BLEND_PROC` is the escape hatch.
	if rep.interp && rep.lerp == "" {
		rep.lerp = interp_lerp_kind(type_text)
		if rep.lerp == "" {
			error_at(floc, "%s.%s: `interp` needs a float-based field (f32/f64, float vectors/colors, or fixed arrays of them) — %q can only snap between samples; drop `interp`, use a float type, or supply custom math with `interp=BLEND_PROC`", struct_name, field_label, type_text)
			return {}, false
		}
	}
	// PREDICT fields get their float-ness classified even without `interp`:
	// kit/sim's reconcile TOLERANCE compares float fields within an epsilon
	// (held-input drift is continuous) and everything else exactly (a flag
	// byte differing is a real event). Blending still gates on .Interp, so
	// this is metadata only — and predict-only, keeping every coop-lane
	// generated file byte-identical.
	if rep.predict && !rep.interp && rep.lerp == "" {
		rep.lerp = interp_lerp_kind(type_text) // "" for non-floats: exact compare
	}
	// `slack=` is a predict-reconcile knob and only bites on float fields — discrete
	// predicted state always reconciles exactly (a differing byte is a real event),
	// so slack there would be silently ignored by predict_within. Reject both misuses.
	if rep.slack != "" {
		if !rep.predict {
			error_at(floc, "%s.%s: `slack=` is a kit/sim reconcile knob — it only applies to a gd:\"replicate,predict\" field (add `predict`, or drop slack=)", struct_name, field_label)
			return {}, false
		}
		if rep.lerp != ".F32" && rep.lerp != ".F64" {
			error_at(floc, "%s.%s: `slack=` needs a float predicted field (f32/f64, float vectors/colors, or fixed arrays of them) — discrete predicted state always reconciles exactly; drop slack= here", struct_name, field_label)
			return {}, false
		}
	}
	// `glide=`/`cut=` shape the GLIDE of a reconcile correction — render-error
	// smoothing, which only exists on a predicted field the eye INTERPOLATES, and
	// only floats carry that error (.Quat/.Custom snap, so they'd silently ignore it).
	glide_cut := rep.glide != "" ? "glide=" : (rep.cut != "" ? "cut=" : "")
	if glide_cut != "" {
		if !rep.predict || !rep.interp {
			error_at(floc, "%s.%s: `%s` shapes render-error smoothing — it needs a gd:\"replicate,predict,interp\" field; a non-interp predicted field snaps on reconcile, nothing to glide", struct_name, field_label, glide_cut)
			return {}, false
		}
		if rep.lerp != ".F32" && rep.lerp != ".F64" {
			error_at(floc, "%s.%s: `%s` needs a float predicted interp field (f32/f64, float vectors/colors, or fixed arrays of them) — only those carry a render error", struct_name, field_label, glide_cut)
			return {}, false
		}
	}
	return rep, true
}
