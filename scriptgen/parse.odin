package scriptgen

import "core:fmt"
import "core:odin/ast"
import "core:odin/parser"
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

		if !has {continue}
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
			// Engine handle/heap types can never be replicated fields: object handles
			// and Rids are peer-local, and String/Array/Dictionary/Packed_* own heap
			// memory a memcpy would corrupt. Rejected HERE (with the type's name)
			// because the generated POD #assert can't see engine semantics — a
			// gd.String is pointer-sized and memcmp-safe, and still wrong to ship.
			// POD engine value types (Vector2/3/4, Color, Transform*, ...) replicate fine.
			if vi, vok := map_variant(type_text); vok {
				denied := vi.enum_name == ".Object" ||
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
						s.struct_name,
						field_label,
						type_text,
					)
					continue
				}
			}
			rep := Replicate_Info{}
			for spec_raw in specs[1:] {
				spec := strings.trim_space(spec_raw)
				switch spec {
				case "interp":
					rep.interp = true
				case "owner":
					rep.owner = true
				case "":
				case:
					error_at(
						floc,
						"%s.%s: unknown replicate option %q (expected `interp` / `owner`)",
						s.struct_name,
						field_label,
						spec,
					)
				}
			}
			// Multi-name fields (`x, y: f32 `gd:"replicate"``) replicate each name.
			for nm in f.names {
				ident, iok := nm.derived.(^ast.Ident)
				if !iok || ident == nil {continue}
				rep.field = ident.name
				append(&s.replicates, rep)
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
				"%s.%s: unknown gd tag %q (expected `export`, `replicate`, or `onready=PATH`)",
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
		// consumes: the `get=`/`set=` accessor proc names (wrapper emission) and the
		// field's Variant type (wrapper marshalling + the ctor set).
		getter := ""
		setter := ""
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

	// Procs bound to the struct (first param `^<Struct>`).
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
		}
		if is_gd_method {
			m := Method_Info {
				proc_name = proc_name,
				gd_name   = stripped,
				ret       = Variant_Info{enum_name = ".Nil", kind = .Nil},
			}
			// args: params after self.
			for fi in 1 ..< len(pt.params.list) {
				field := pt.params.list[fi]
				atext := node_text(src, field.type)
				vi, vok := map_variant(atext)
				if !vok {
					errorf("method %s: unsupported arg type %q", proc_name, atext)
					continue
				}
				for nm in field.names {
					ident, _ := nm.derived.(^ast.Ident)
					if ident == nil {continue}
					append(&m.args, Arg{name = ident.name, type_text = atext, vi = vi})
				}
			}
			// return type (first result, if any).
			if pt.results != nil && len(pt.results.list) > 0 {
				rtext := node_text(src, pt.results.list[0].type)
				vi, vok := map_variant(rtext)
				if !vok {
					errorf("method %s: unsupported return type %q", proc_name, rtext)
				} else {
					m.ret = vi
				}
			}
			append(&s.methods, m)

			// `@(gd_connect="signal")` — auto-connect owner.signal -> this method on READY.
			if sig, has := attr_value(vd, "gd_connect"); has {
				append(&s.connections, Connection_Info{signal = sig, method = stripped})
			}

			// `@(gd_rpc[="..."])` — expose this method to Godot's high-level multiplayer.
			// `attr_value` is "" for the bare `@(gd_rpc)` form (=> all defaults).
			if is_gd_rpc {
				config, _ := attr_value(vd, "gd_rpc")
				append(&s.rpcs, parse_rpc_config(stripped, config))
			}
		}
	}

	return s, true
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
