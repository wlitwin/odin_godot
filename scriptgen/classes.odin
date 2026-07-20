// The ENGINE CLASS INDEX — the one place scriptgen knows what a `gd.*` handle
// type IS to Godot, and which class descends from which.
//
// WHY IT EXISTS. `//gd:extends Node2D` and `owner: gd.Node2d` are two spellings
// of the same fact, and NOTHING cross-checked them. The pair that misbehaves is
// the one where the handle is NARROWER than the base: `//gd:extends Node` with
// `owner: gd.Node2d` compiles clean (every class handle is a rawptr alias, so
// Odin has no opinion), registers a plain Node with the engine, and then every
// `gd.node2d_*` call in the script reaches through that handle into an object
// that was never a Node2D. It dies at the engine boundary, far from the tag
// that lied. Meanwhile the WIDER direction is legal and common — `//gd:extends
// CharacterBody2D` with `owner: gd.Node2d` is how half the examples are written,
// because the script only ever calls Node2D methods on it.
//
// So the rule is ancestry, not equality: the owner handle must BE the declared
// base or one of its ancestors.
//
// WHERE THE FACTS COME FROM. `godot/godot.gen.odin` is the generated alias
// table, and each alias line IS an inheritance edge — `Node2d :: Canvas_Item`,
// `Canvas_Item :: Node`, `Node :: Object` — because every non-refcounted class
// handle is an alias of its parent's handle. `godot/<snake>.gen.odin` carries
// the authoritative Godot spelling on its `__class_name` line (`node2d.gen.odin`
// -> "Node2D"), which is what core/lookup.odin already reads for goto-definition;
// no PascalCase round-trip algorithm is invented here, because the acronym
// classes (JSON, GLTFDocument) don't round-trip.
//
// EVERY LOOKUP DEGRADES TO SILENCE. The index needs `-godot:<root>` (or
// ODIN_GODOT_ROOT); without it, or for a base the bindings don't cover (a
// user's own global class name), the check simply doesn't run. A build that
// can't see the engine's class list must not start inventing errors about it.
package scriptgen

import "core:os"
import "core:strings"

@(private = "file")
g_class_parent: map[string]string // Odin handle name -> Odin handle name of its base
@(private = "file")
g_class_parent_built: bool
@(private = "file")
g_class_by_norm: map[string]string // normalized Godot/Odin spelling -> Odin handle name
@(private = "file")
g_class_godot: map[string]string // Odin handle name -> Godot spelling ("" = negative cache)

// Fold a class name to the spelling-insensitive key that matches an Odin handle
// name against a Godot one: lowercase, underscores dropped. `Character_Body2d`
// and `CharacterBody2D` both fold to "characterbody2d"; `Json` and `JSON` both
// to "json". Godot's own class names are unique under this fold, so it is a
// mapping and not a guess.
@(private = "file")
class_norm :: proc(name: string) -> string {
	b := strings.builder_make(context.temp_allocator)
	for i in 0 ..< len(name) {
		c := name[i]
		if c == '_' {continue}
		if c >= 'A' && c <= 'Z' {c += 'a' - 'A'}
		strings.write_byte(&b, c)
	}
	return strings.to_string(b)
}

// Build the parent map from `<root>/godot/godot.gen.odin`'s alias lines. One
// read of one file; anything unparseable is skipped rather than reported (the
// gen file is bindgen's output, not the author's).
@(private = "file")
ensure_class_index :: proc() {
	if g_class_parent_built {return}
	g_class_parent_built = true // even on failure: a one-shot empty index degrades to no-check
	if g_godot_root == "" {return}
	// godot.gen.odin holds the generated class edges; Variant.odin holds the two
	// hand-written roots they terminate in (`Ref_Counted :: ^Object`, which is
	// why the parent side tolerates a leading `^`, and `Object :: gd.ObjectPtr`,
	// which is qualified and so parses as no edge at all — correctly, Object is
	// the root). Without Variant.odin every RefCounted-descended class dead-ends
	// one step short of Object and `//gd:extends RefCounted` + `owner: gd.Object`
	// would read as a mismatch.
	for rel in ([]string{"/godot/godot.gen.odin", "/godot/Variant.odin"}) {
		path := strings.concatenate({g_godot_root, rel})
		data, rerr := os.read_entire_file(path, context.allocator)
		if rerr != nil {continue}
		it := string(data)
		for line in strings.split_lines_iterator(&it) {
			l := strings.trim_space(line)
			sep := strings.index(l, " :: ")
			if sep <= 0 {continue}
			name := strings.trim_space(l[:sep])
			parent := strings.trim_space(l[sep + 4:])
			parent = strings.trim_left(parent, "^")
			// Alias lines only: a bare `A :: B` where both sides are plain idents.
			if !ident_like(name) || !ident_like(parent) {continue}
			g_class_parent[name] = parent
			g_class_by_norm[class_norm(name)] = name
			g_class_by_norm[class_norm(parent)] = parent
		}
	}
}

@(private = "file")
ident_like :: proc(s: string) -> bool {
	if len(s) == 0 {return false}
	if !(s[0] >= 'A' && s[0] <= 'Z') {return false} // class handles are PascalCase
	for i in 0 ..< len(s) {
		c := s[i]
		if c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') {continue}
		return false
	}
	return true
}

// The Godot spelling of an Odin handle name, read from that class's own gen
// file's `__class_name` line. "" when the class isn't a ClassDB class (the
// builtin Variant types carry no such line) or the file isn't there.
godot_class_name :: proc(odin_name: string) -> string {
	if g_godot_root == "" {return ""}
	if cached, found := g_class_godot[odin_name]; found {return cached}
	path := strings.concatenate({g_godot_root, "/godot/", strings.to_lower(odin_name, context.temp_allocator), ".gen.odin"})
	pascal := ""
	if data, rerr := os.read_entire_file(path, context.temp_allocator); rerr == nil {
		marker := "__class_name = new_string_name_cstring(\""
		if idx := strings.index(string(data), marker); idx >= 0 {
			rest := string(data)[idx + len(marker):]
			if end := strings.index_byte(rest, '"'); end >= 0 {
				pascal = strings.clone(rest[:end])
			}
		}
	}
	g_class_godot[odin_name] = pascal // cache the negative too — one read per name per run
	return pascal
}

// Is `handle` (an Odin class-handle name) the class `base` names, or one of its
// ancestors? `known` is false when the index can't place `base` at all, which is
// the caller's cue to stay silent rather than accuse.
class_handle_covers :: proc(handle, base: string) -> (covers: bool, known: bool) {
	ensure_class_index()
	if len(g_class_by_norm) == 0 {return false, false}
	base_odin, found := g_class_by_norm[class_norm(base)]
	if !found {return false, false}
	if _, is_class := g_class_by_norm[class_norm(handle)]; !is_class {return false, false}
	cur := base_odin
	for i := 0; i < 64; i += 1 { // the depth bound is a cycle guard, not a real limit
		if class_norm(cur) == class_norm(handle) {return true, true}
		next, has := g_class_parent[cur]
		if !has {break}
		cur = next
	}
	return false, true
}
