package scriptgen

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
// `` `gd:"export" json:"x"` ``. Returns ("", false) if absent.
tag_gd_value :: proc(tag_text: string) -> (string, bool) {
	t := strings.trim(tag_text, "`")
	key := "gd:\""
	i := strings.index(t, key)
	if i < 0 {return "", false}
	rest := t[i + len(key):]
	j := strings.index(rest, "\"")
	if j < 0 {return "", false}
	return rest[:j], true
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

// ---- marker scanning (//gd:extends / //gd:class / //gd:tool / //gd:signal) ----

scan_markers :: proc(src: string, s: ^Script) {
	it := src
	for line in strings.split_lines_iterator(&it) {
		l := strings.trim_space(line)
		if !strings.has_prefix(l, "//gd:") {continue}
		body := strings.trim_space(l[len("//gd:"):])
		if rest, ok := marker_arg(body, "extends"); ok {
			s.marked = true
			s.base = strings.trim_space(rest)
			if s.base == "" {errorf("//gd:extends needs a base class name")}
		} else if rest, ok := marker_arg(body, "class"); ok {
			s.marked = true
			s.class_name = strings.trim_space(rest)
			if s.class_name == "" {errorf("//gd:class needs a name")}
		} else if _, ok := marker_arg(body, "tool"); ok {
			s.marked = true
			s.tool = true
		} else if rest, ok := marker_arg(body, "icon"); ok {
			s.marked = true
			s.icon = strings.trim_space(rest)
		} else if rest, ok := marker_arg(body, "signal"); ok {
			s.marked = true
			parse_signal_marker(strings.trim_space(rest), s)
		} else {
			// A `//gd:` line that matches no known marker is almost always a typo
			// (`//gd:extend`, `//gd:singal`) that would otherwise silently no-op — and the
			// `//gd:` namespace is reserved, so erroring is safe.
			errorf("unknown //gd: marker %q (expected one of: extends/class/tool/icon/signal)", body)
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

// Parse `pinged(value: int, other: float)` into a Signal_Info.
parse_signal_marker :: proc(decl: string, s: ^Script) {
	open := strings.index(decl, "(")
	if open < 0 {
		errorf("malformed //gd:signal (missing '('): %q", decl)
		return
	}
	name := strings.trim_space(decl[:open])
	close := strings.last_index(decl, ")")
	if close < 0 || close < open {
		errorf("malformed //gd:signal (missing ')'): %q", decl)
		return
	}
	sig := Signal_Info {
		name = name,
	}
	params := strings.trim_space(decl[open + 1:close])
	if params != "" {
		for part in strings.split(params, ",") {
			p := strings.trim_space(part)
			colon := strings.index(p, ":")
			if colon < 0 {
				errorf("signal %q arg %q missing `: type`", name, p)
				continue
			}
			aname := strings.trim_space(p[:colon])
			atype := strings.trim_space(p[colon + 1:])
			vi, ok := map_variant(atype)
			if !ok {
				errorf("signal %q arg %q: unsupported type %q", name, aname, atype)
				continue
			}
			append(&sig.args, Signal_Arg{name = aname, vi = vi})
		}
	}
	append(&s.signals, sig)
}

// ---- AST parsing -------------------------------------------------------------

// Parse one script file. Returns ok=false when the file has no owner-struct (so it
// is not a script — e.g. a boot.odin or a plain helper file).
parse_script :: proc(path, src: string) -> (Script, bool) {
	s := Script {
		base = "Node",
	}
	scan_markers(src, &s)

	file := ast.File {
		fullpath = path,
		src      = src,
	}
	p := parser.default_parser()
	if !parser.parse_file(&p, &file) {
		errorf("failed to parse %q", path)
		return s, false
	}
	s.pkg = file.pkg_name

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
		s.struct_name = name_ident.name
		struct_type = st
		break
	}
	if struct_type == nil {
		// A `//gd:` marker is an unambiguous declaration that this file IS a script. Finding
		// one but no script struct almost always means the struct's first field isn't named
		// `owner` (a typo, wrong name, or wrong position) — fail loudly instead of silently
		// dropping the class (which left the user with a node that does nothing, no error).
		if s.marked {
			errorf(
				"%q has //gd: marker(s) (class %q) but no script struct — a script's struct must have its FIRST field named `owner`",
				path,
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
		val, has := tag_gd_value(f.tag.text)
		if !has {continue}
		// Tag is comma-separated tokens. The FIRST token selects the kind:
		//   - `onready=PATH`  -> a private auto-wired node ref (richer-authoring #1)
		//   - `export[,SPEC]` -> a serialized @export property
		specs := strings.split(val, ",")
		if len(specs) == 0 {continue}
		tok0 := strings.trim_space(specs[0])

		// Field name (first ident) — for error messages + offset_of.
		field_label := s.struct_name
		for nm in f.names {
			if ident, iok := nm.derived.(^ast.Ident); iok && ident != nil {
				field_label = ident.name
				break
			}
		}
		type_text := node_text(src, f.type)

		// richer-authoring #1: `gd:"onready=Sprite"` — must be an object-handle/pointer field.
		if strings.has_prefix(tok0, "onready=") {
			path := strings.trim_space(tok0[len("onready="):])
			if path == "" {
				errorf("%s.%s: `onready=` needs a node path", s.struct_name, field_label)
				continue
			}
			vi, ok := map_variant(type_text)
			if !ok || vi.enum_name != ".Object" {
				errorf("%s.%s: `onready` field must be an object/node handle or pointer (got %q)", s.struct_name, field_label, type_text)
				continue
			}
			for nm in f.names {
				ident, _ := nm.derived.(^ast.Ident)
				if ident == nil {continue}
				append(&s.onready, Onready_Info{field = ident.name, path = path})
			}
			continue
		}

		if tok0 != "export" {
			// The field HAS a `gd:"..."` tag (tag_gd_value succeeded) but its first token is
			// neither `export` nor `onready=` — almost certainly a misspelling (`exprot`)
			// that would otherwise silently leave the field un-exported.
			errorf(
				"%s.%s: unknown gd tag %q (expected `export` or `onready=PATH`)",
				s.struct_name,
				field_label,
				tok0,
			)
			continue
		}

		vi, ok := map_variant(type_text)
		if !ok {
			errorf("%s.%s: export field of unsupported type %q", s.struct_name, field_label, type_text)
			continue
		}

		// Trailing tokens: at most one hint spec, plus optional group/subgroup/default/get/set.
		hint := 0
		hint_string := ""
		group := ""
		subgroup := ""
		has_default := false
		default_num := f64(0)
		default_str := ""
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
			case "group":
				group = value
			case "subgroup":
				subgroup = value
			case "default":
				num, str, dok := parse_default(s.struct_name, field_label, vi, value)
				if dok {
					has_default = true
					default_num = num
					default_str = str
				}
			case "get":
				getter = value
			case "set":
				setter = value
			case:
				// Anything else is a hint spec (range/enum/multiline/file/resource/...).
				if hint != 0 {
					errorf("%s.%s: only one export hint allowed (got extra %q)", s.struct_name, field_label, spec)
					break
				}
				h, hs, hok := parse_hint_spec(s.struct_name, field_label, spec)
				if hok {
					hint = h
					hint_string = hs
				}
			}
		}

		for nm in f.names {
			ident, _ := nm.derived.(^ast.Ident)
			if ident == nil {continue}
			append(&s.exports, Export_Info {
				name        = ident.name,
				type_text   = type_text,
				vi          = vi,
				hint        = hint,
				hint_string = hint_string,
				group       = group,
				subgroup    = subgroup,
				has_default = has_default,
				default_num = default_num,
				default_str = default_str,
				getter      = getter,
				setter      = setter,
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
