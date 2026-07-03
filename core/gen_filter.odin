#+build darwin, linux, windows
package core

import "godot:godot"

import "core:fmt"
import "core:strings"

// ----------------------------------------------------------------------------
// Hide scriptgen's `*.gen.odin` build artifacts in the editor's FileSystem dock.
//
// Why this is done widget-side: EditorFileSystem admits files by EXTENSION only
// (editor_file_system.cpp `_process_file_system`: `scan_file.get_extension()` ->
// "odin"), so `player.gen.odin` passes the same gate as `player.odin`, and the
// engine has NO per-file exclusion hook — the only exclusions in the whole scan
// pipeline are OS-hidden files and `.gdignore` directories (verified against 4.6
// source). Neither helps: gen files must sit inside the script package directory
// (Odin packages are single-directory, so `.gdignore` would take the authored
// scripts with it), and dot-prefixing isn't "hidden" on Windows (the check there
// is FILE_ATTRIBUTE_HIDDEN, drivers/windows/dir_access_windows.cpp). Our loader
// already refuses to recognize gen files as resources (_recognize_path /
// _get_resource_type in loader.odin); that keeps them un-openable but not
// un-listed.
//
// So the Odin EditorPlugin hides them AFTER the dock builds its widgets, driven
// by `pl_process` (export_plugin.odin) each editor frame:
//
//   * Tree view (default layout shows files IN the tree): every dock rebuild does
//     `tree->clear(); root = tree->create_item();` — the root TreeItem is a FRESH
//     object with a fresh (never-reused) instance id. Comparing that id is a
//     2-call-per-frame dirty check that catches ALL rebuild paths (rescan, search,
//     sort, file ops...). On change, walk once via get_next_in_tree and
//     `set_visible(false)` items named `*.gen.odin` — hiding, never freeing, so
//     the dock's own TreeItem bookkeeping stays intact.
//
//   * Split-mode file list (an ItemList): no rebuild marker exists, so dirty =
//     item count OR first item's metadata (its res:// path) changed; matching
//     items are remove_item'd (safe: the dock reads paths from per-item metadata
//     at event time, so index shifts don't confuse it).
//
// Escape hatch: set the `odin_godot/show_generated_files` project setting to
// true (read per rebuild, not per frame; takes effect on the next rebuild). The
// setting is never registered or saved — a consumer's project.godot stays
// untouched unless they add it themselves.
//
// Fails SOFT everywhere: if the dock/Tree/ItemList aren't found (headless
// driver, future editor rework), resolution gives up after a few seconds and
// gen files simply show again — nothing else depends on this.
// ----------------------------------------------------------------------------

@(private = "file")
GEN_SUFFIX :: ".gen.odin"

@(private = "file")
Gen_Filter :: struct {
    tree:       godot.Tree, // the dock's tree view (nil until resolved)
    files:      godot.Item_List, // the dock's split-mode file list (may stay nil)
    gave_up:    bool, // resolution failed for RESOLVE_ATTEMPTS frames — stop trying
    attempts:   int,
    last_root:  u64, // instance id of the tree root at the last prune
    last_count: i32, // file list: item count after the last prune
    last_first: string, // file list: first item's metadata path after the last prune
    announced:  bool, // the one-shot "hid N files" console line was printed
}

@(private = "file")
gf: Gen_Filter

// ~5s at 60fps. The dock exists before plugins load, so in a real editor the very
// first attempt succeeds; this bound only stops per-frame find_children churn in
// environments that never get a dock (SceneTree-script drivers, future editors).
@(private = "file")
RESOLVE_ATTEMPTS :: 300

@(private = "file")
gen_filter_resolve :: proc() -> bool {
    if gf.tree != nil {return true}
    if gf.gave_up {return false}
    gf.attempts += 1
    if gf.attempts > RESOLVE_ATTEMPTS {
        gf.gave_up = true
        return false
    }
    ei := godot.singleton_editor_interface()
    if ei == nil {return false}
    dock := godot.editor_interface_get_file_system_dock(ei)
    if dock == nil {return false}
    pat := godot.new_string_cstring("*")
    defer godot.free_string(pat)

    ttree := godot.new_string_cstring("Tree")
    defer godot.free_string(ttree)
    tl := godot.node_find_children(cast(godot.Node)dock, pat, ttree, true, false)
    tarr := cast(^godot.Array)&tl
    if godot.array_size(tarr) > 0 {
        v := godot.array_get(tarr, 0)
        gf.tree = cast(godot.Tree)godot.variant_to_object(&v)
        godot.variant_destroy(&v)
    }

    tlist := godot.new_string_cstring("ItemList")
    defer godot.free_string(tlist)
    fl := godot.node_find_children(cast(godot.Node)dock, pat, tlist, true, false)
    farr := cast(^godot.Array)&fl
    if godot.array_size(farr) > 0 {
        v := godot.array_get(farr, 0)
        gf.files = cast(godot.Item_List)godot.variant_to_object(&v)
        godot.variant_destroy(&v)
    }
    return gf.tree != nil
}

@(private = "file")
show_generated_files :: proc() -> bool {
    ps := godot.singleton_project_settings()
    key := godot.new_string_cstring("odin_godot/show_generated_files")
    defer godot.free_string(key)
    if !bool(godot.project_settings_has_setting(ps, key)) {return false}
    def := godot.Variant{}
    v := godot.project_settings_get_setting(ps, key, def)
    defer godot.variant_destroy(&v)
    return godot.variant_to_bool(&v)
}

@(private = "file")
gen_filter_announce :: proc(hidden: int) {
    if hidden <= 0 || gf.announced {return}
    gf.announced = true
    godot.print_str(
        fmt.tprintf(
            "odin_godot: hid %d generated %s file(s) in the FileSystem dock " +
            "(build artifacts; set the odin_godot/show_generated_files project setting to true to show them)",
            hidden,
            GEN_SUFFIX,
        ),
    )
}

@(private = "file")
is_gen_name :: proc(s: godot.String) -> bool {
    name := string_to_odin(s)
    defer delete(name)
    return strings.has_suffix(name, GEN_SUFFIX)
}

@(private = "file")
gen_filter_prune_tree :: proc() {
    root := godot.tree_get_root(gf.tree)
    if root == nil {
        gf.last_root = 0
        return
    }
    id := godot.object_get_instance_id(cast(godot.Object)root)
    if id == gf.last_root {return}
    gf.last_root = id // cache even when showing: the setting flip re-evaluates next rebuild
    if show_generated_files() {return}
    hidden := 0
    for item := root; item != nil; item = godot.tree_item_get_next_in_tree(item, false) {
        txt := godot.tree_item_get_text(item, 0)
        hit := is_gen_name(txt)
        godot.free_string(txt)
        if hit {
            godot.tree_item_set_visible(item, false)
            hidden += 1
        }
    }
    gen_filter_announce(hidden)
}

// First item's metadata (the dock stores each entry's res:// path there) — the cheap
// "which directory is the list showing" fingerprint for the dirty check.
@(private = "file")
list_first_path :: proc(allocator := context.allocator) -> string {
    if godot.item_list_get_item_count(gf.files) == 0 {return ""}
    v := godot.item_list_get_item_metadata(gf.files, 0)
    defer godot.variant_destroy(&v)
    s := godot.variant_to_string(&v)
    defer godot.free_string(s)
    return string_to_odin(s, allocator)
}

@(private = "file")
gen_filter_prune_list :: proc() {
    if gf.files == nil {return}
    count := godot.item_list_get_item_count(gf.files)
    first := list_first_path()
    if count == gf.last_count && first == gf.last_first {
        delete(first)
        return
    }
    delete(first)
    if !show_generated_files() {
        hidden := 0
        for i := godot.Int(count) - 1; i >= 0; i -= 1 {
            txt := godot.item_list_get_item_text(gf.files, i)
            hit := is_gen_name(txt)
            godot.free_string(txt)
            if hit {
                godot.item_list_remove_item(gf.files, i)
                hidden += 1
            }
        }
        gen_filter_announce(hidden)
    }
    // Re-read AFTER pruning so the cached fingerprint matches what's displayed.
    gf.last_count = godot.item_list_get_item_count(gf.files)
    delete(gf.last_first)
    gf.last_first = list_first_path()
}

// Called from OdinEditorPlugin._process (export_plugin.odin) every editor frame.
// Idle cost once resolved: tree_get_root + get_instance_id + get_item_count +
// one metadata fetch — a handful of ptrcalls.
gen_filter_tick :: proc() {
    if !gen_filter_resolve() {return}
    gen_filter_prune_tree()
    gen_filter_prune_list()
}
