package main

// ----------------------------------------------------------------------------
// Headless proof of OdinLanguage._lookup_code's PURE symbol->(class,member) mapping.
//
// `_lookup_code` is dispatched by the editor through the GDExtension virtual table and is NOT
// callable from GDScript (same as `_complete_code`), so the load-bearing pure logic — mapping a
// clicked `gd.<class>_<member>` binding symbol back to its (snake class, member) via longest-prefix
// match with `_`-boundary disambiguation — is proven here by calling the SAME shared procedure the
// core dll uses: `lookup.resolve_symbol`. Core's `lv_lookup_code` is the thin Godot glue on top
// (ClassDB classification + building the LookupResult Dictionary), which needs a live editor.
//
// Asserts longest-prefix, the `node` vs `node2d` `_`-boundary disambiguation, the `gd.` strip,
// the exact-class case, and unknown/empty symbols. Prints LOOKUP_OK on success.
// ----------------------------------------------------------------------------

import "core:fmt"
import "core:os"
import lookup "godot:core/lookup" // godot collection == repo root, so this is core/lookup

fail :: proc(msg: string) {
    fmt.eprintln("LOOKUP_FAIL:", msg)
    os.exit(1)
}

// A representative class set (subset of the real godot/*.gen.odin basenames). `node` AND `node2d`
// both present so the boundary check is genuinely exercised.
make_set :: proc() -> map[string]bool {
    m := make(map[string]bool)
    for c in ([]string{"node", "node2d", "node3d", "sprite2d", "control", "color_picker", "object", "ref_counted"}) {
        m[c] = true
    }
    return m
}

expect :: proc(symbol: string, set: map[string]bool, want_class: string, want_member: string, want_is_class: bool, want_ok: bool) {
    cls, member, is_class, ok := lookup.resolve_symbol(symbol, set)
    if ok != want_ok || cls != want_class || member != want_member || is_class != want_is_class {
        fail(
            fmt.tprintf(
                "resolve_symbol(%q) = {{class=%q member=%q is_class=%v ok=%v}}, want {{class=%q member=%q is_class=%v ok=%v}}",
                symbol,
                cls,
                member,
                is_class,
                ok,
                want_class,
                want_member,
                want_is_class,
                want_ok,
            ),
        )
    }
    fmt.printf("  ok: %q -> class=%q member=%q is_class=%v ok=%v\n", symbol, cls, member, is_class, ok)
}

main :: proc() {
    set := make_set()

    // 1. The canonical method case.
    expect("node2d_set_position", set, "node2d", "set_position", false, true)

    // 2. `_`-boundary disambiguation: `node` is a prefix of `node2d_...` but the char after `node`
    //    is `2`, not `_`, so the LONGEST valid match is `node2d`, NOT `node`.
    expect("node2d_get_skew", set, "node2d", "get_skew", false, true)
    //    A genuine `node_` member resolves to `node` (boundary IS `_`).
    expect("node_get_parent", set, "node", "get_parent", false, true)

    // 3. Longest-prefix among real classes: `color_picker_*` must pick `color_picker`, not some
    //    shorter class. (No bare `color` class is in this set; the longer wins regardless.)
    expect("color_picker_set_pick_color", set, "color_picker", "set_pick_color", false, true)

    // 4. The `gd.` package qualifier is stripped (editor may pass `gd.node2d_set_position`).
    expect("gd.node2d_set_position", set, "node2d", "set_position", false, true)
    expect("gd.node3d_set_position", set, "node3d", "set_position", false, true)

    // 5. Exact class token -> the class itself (is_class = true, no member).
    expect("node2d", set, "node2d", "", true, true)
    expect("gd.control", set, "control", "", true, true)

    // 6. Unknown / non-class symbols -> graceful miss (ok = false). Covers global utility
    //    functions like `gd.print` (no class prefix) and pure garbage.
    expect("print", set, "", "", false, false)
    expect("deg_to_rad", set, "", "", false, false)
    expect("", set, "", "", false, false)
    expect("gd.", set, "", "", false, false)
    expect("notaclass_foo", set, "", "", false, false)
    //    A token equal to a class prefix but with NO `_` boundary and not exact -> miss.
    //    e.g. `nodepath` shares prefix `node` but `node` + `p` has no `_` boundary.
    expect("nodepath", set, "", "", false, false)

    fmt.println("LOOKUP_OK")
}
