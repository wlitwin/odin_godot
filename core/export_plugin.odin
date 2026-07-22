#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

// ----------------------------------------------------------------------------
// Phase 5 — the EXPORT pipeline.
//
// An exported game has no Odin compiler, so the `.odin` scripts must be compiled
// AHEAD OF TIME, at export, and the resulting `libodinscripts.<ext>` bundled next
// to the stable `core` dll. Two GDExtension classes implement this, registered ONLY
// at the `.Editor` initialization level (an exported game never reaches `.Editor`,
// so neither is present at runtime — the same `core` dll plays both roles):
//
//   * OdinExportPlugin   (extends EditorExportPlugin) — the real work. In its
//     `_export_begin` it (1) runs the scriptgen + `odin build` pipeline for the
//     TARGET platform, producing a fresh scripts dll, and (2) `add_shared_object`s
//     that dll so the exporter copies it beside the executable (macOS: into
//     `Contents/Frameworks/`, alongside the auto-exported `core` dll). The `core`
//     dll itself is exported automatically by Godot's GDExtension export handling
//     (it is listed in `[libraries]` of the `.gdextension`), so we do not re-add it.
//
//   * OdinEditorPlugin   (extends EditorPlugin) — a thin host. GDExtension can only
//     register an EDITOR plugin by class name (`editor_add_plugin`); there is no
//     exposed `EditorExport` singleton in the binding. So this plugin, in its
//     `_enter_tree`, constructs the OdinExportPlugin and `add_export_plugin`s it.
//
// At runtime in the EXPORTED game the core locates the scripts dll as a SIBLING of
// itself (see `core_dll_dir` in scripts.odin) rather than via `res://`, because in an
// export `res://` is packed and cannot be `dlopen`ed.
// ----------------------------------------------------------------------------

@(private = "file")
odin_export_class_name: godot.String_Name

@(private = "file")
odin_editor_plugin_class_name: godot.String_Name

@(private = "file")
export_virtuals: [dynamic]Virtual_Entry

@(private = "file")
editor_plugin_virtuals: [dynamic]Virtual_Entry

@(private = "file")
odin_editor_plugin_object: gdext.ObjectPtr

OdinExportPlugin :: struct {
    object: gdext.ObjectPtr,
}

OdinEditorPlugin :: struct {
    object: gdext.ObjectPtr,
}

@(private = "file")
export_binding_callbacks := gdext.InstanceBindingCallbacks {
    create    = nil,
    free      = nil,
    reference = nil,
}

// ---- OdinExportPlugin instance plumbing ----

@(private = "file")
export_create_instance :: proc "c" (class_user_data: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()
    object := gdext.classdb_construct_object(godot.editor_export_plugin_name_ref())
    self := new(OdinExportPlugin)
    self.object = object
    gdext.object_set_instance(object, &odin_export_class_name, self)
    gdext.object_set_instance_binding(object, gdext.library, self, &export_binding_callbacks)
    return object
}

@(private = "file")
export_free_instance :: proc "c" (class_user_data: rawptr, instance: gdext.ExtensionClassInstancePtr) {
    context = gdext.godot_context()
    if instance == nil {return}
    free(cast(^OdinExportPlugin)instance)
}

@(private = "file")
export_get_virtual_call_data :: proc "c" (class_user_data: rawptr, name: gdext.StringNamePtr) -> rawptr {
    context = gdext.godot_context()
    return lookup_virtual(export_virtuals[:], name)
}

// ---- OdinEditorPlugin instance plumbing ----

@(private = "file")
editor_plugin_create_instance :: proc "c" (class_user_data: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()
    object := gdext.classdb_construct_object(godot.editor_plugin_name_ref())
    self := new(OdinEditorPlugin)
    self.object = object
    gdext.object_set_instance(object, &odin_editor_plugin_class_name, self)
    gdext.object_set_instance_binding(object, gdext.library, self, &export_binding_callbacks)
    return object
}

@(private = "file")
editor_plugin_free_instance :: proc "c" (class_user_data: rawptr, instance: gdext.ExtensionClassInstancePtr) {
    context = gdext.godot_context()
    if instance == nil {return}
    free(cast(^OdinEditorPlugin)instance)
}

@(private = "file")
editor_plugin_get_virtual_call_data :: proc "c" (class_user_data: rawptr, name: gdext.StringNamePtr) -> rawptr {
    context = gdext.godot_context()
    return lookup_virtual(editor_plugin_virtuals[:], name)
}

// ---- virtuals ----

@(private = "file")
ep_get_name :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string(ret, godot.new_string_cstring("OdinExportPlugin"))
}

@(private = "file")
pl_get_plugin_name :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_string(ret, godot.new_string_cstring("OdinGodot"))
}

// OdinEditorPlugin._enter_tree — construct + register the export plugin. This runs
// when `editor_add_plugin` inserts us into the editor tree, which happens during the
// extension's `.Editor`-level init (before any export command executes).
// A custom Callable is always valid + takes no args. Providing these (rather than leaving the
// struct's optional fields nil) avoids any chance the engine calls a nil function pointer.
@(private)
menu_callable_is_valid :: proc "c" (userdata: rawptr) -> bool {return true}
@(private)
menu_callable_argc :: proc "c" (userdata: rawptr, is_valid: ^bool) -> i64 {
    if is_valid != nil {is_valid^ = true}
    return 0
}

// make_menu_callable — a custom Callable backed by an Odin "c" proc, for
// add_tool_menu_item. Package-private: core/debug_launch.odin registers its own items.
@(private)
make_menu_callable :: proc(fn: gdext.ExtensionCallableCustomCall) -> godot.Callable {
    info := gdext.ExtensionCallableCustomInfo2 {
        token                   = gdext.library,
        call_func               = fn,
        is_valid_func           = menu_callable_is_valid,
        get_argument_count_func = menu_callable_argc,
    }
    cb: godot.Callable
    gdext.callable_custom_create2(cast(gdext.TypePtr)&cb, &info)
    return cb
}

// "Build Odin Scripts" body: kick the SAME background build the save/reload path runs
// (force=true so a manual click always rebuilds + gives feedback). Editor main thread.
@(private = "file")
build_menu_call :: proc "c" (userdata: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr, err: ^gdext.CallError) {
    context = gdext.godot_context()
    if err != nil {err.error = .Ok} // signal success — else Godot logs "Error calling function from tool menu"
    reload_request(force = true)
}

// "Set Up Odin Scripts" body: copy the bundled template into res://scripts/ (the template
// lives inside the addon, which is `.gdignore`d, so it's invisible in the FileSystem dock —
// users otherwise have to reach for their OS file manager).
@(private = "file")
setup_menu_call :: proc "c" (userdata: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr, err: ^gdext.CallError) {
    context = gdext.godot_context()
    context.allocator = runtime.heap_allocator()
    if err != nil {err.error = .Ok} // signal success — else Godot logs "Error calling function from tool menu"
    setup_scripts_from_template()
}

@(private)
editor_msg_error :: proc(s: string) {
    m := godot.new_string_odin(s)
    godot.gd_push_error(godot.variant_from_string(&m))
}

@(private)
editor_msg_warn :: proc(s: string) {
    m := godot.new_string_odin(s)
    godot.gd_push_warning(godot.variant_from_string(&m))
}

@(private = "file")
dir_has_odin :: proc(dir: string) -> bool {
    if !os.exists(dir) {return false}
    fis, derr := os.read_directory_by_path(dir, -1, context.temp_allocator)
    if derr != nil {return false}
    for fi in fis {
        if strings.has_suffix(fi.name, ".odin") {return true}
    }
    return false
}

@(private = "file")
rescan_editor_filesystem :: proc() {
    ei := godot.singleton_editor_interface()
    if ei == nil {return}
    rfs := godot.editor_interface_get_resource_filesystem(ei)
    if rfs == nil {return}
    godot.editor_file_system_scan(rfs)
}

// Copy the addon's template scripts into res://scripts/ so a new project can start without a
// trip to the file manager. Refuses to clobber an existing scripts dir that has .odin sources.
@(private = "file")
setup_scripts_from_template :: proc() {
    root := odin_collection_root()
    defer delete(root)
    if root == "" {
        editor_msg_error("odin_godot: couldn't locate the addon — set the `odin_godot/root` project setting, then retry.")
        return
    }
    // The built addon ships the template at <root>/template/scripts; an in-repo checkout
    // keeps it at <root>/build/template/scripts (dist.nix moves it up when packaging).
    src := strings.concatenate({root, "/template/scripts"})
    defer delete(src)
    if !os.exists(src) {
        alt := strings.concatenate({root, "/build/template/scripts"})
        if os.exists(alt) {
            delete(src)
            src = alt
        } else {
            delete(alt)
        }
    }

    gres := godot.new_string_cstring("res://scripts")
    destg := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
    dest := string_to_odin(destg)
    defer delete(dest)

    if dir_has_odin(dest) {
        editor_msg_warn(fmt.tprintf("odin_godot: res://scripts already exists with .odin files — leaving it untouched (%s).", dest))
        return
    }
    fis, derr := os.read_directory_by_path(src, -1, context.temp_allocator)
    if derr != nil {
        editor_msg_error(
            fmt.tprintf(
                "odin_godot: template not found at %s (nor under build/template/scripts) — is the addon intact?",
                src,
            ),
        )
        return
    }
    if !os.exists(dest) {
        if mkerr := os.make_directory(dest); mkerr != nil {
            editor_msg_error(fmt.tprintf("odin_godot: couldn't create %s.", dest))
            return
        }
    }
    copied := 0
    for fi in fis {
        if fi.type == .Directory || strings.has_suffix(fi.name, ".gen.odin") {continue}
        data, rerr := os.read_entire_file(fi.fullpath, context.temp_allocator)
        if rerr != nil {continue}
        out := strings.concatenate({dest, "/", fi.name}, context.temp_allocator)
        if werr := os.write_entire_file(out, data); werr == nil {copied += 1}
    }
    rescan_editor_filesystem()
    godot.print_str(
        fmt.tprintf(
            "odin_godot: created res://scripts/ (%d file(s)) from the template. Next: Project > Tools > Build Odin Scripts, then Play.",
            copied,
        ),
    )
}

@(private = "file")
pl_enter_tree :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    self := cast(^OdinEditorPlugin)instance
    ep_object := gdext.classdb_construct_object(&odin_export_class_name)
    godot.editor_plugin_add_export_plugin(
        cast(godot.Editor_Plugin)self.object,
        cast(godot.Editor_Export_Plugin)ep_object,
    )
    // Project > Tools items, so a new user never has to leave Godot:
    //   * "Set Up Odin Scripts" — copy the bundled template into res://scripts/ (the template
    //     is inside the .gdignore'd addon, so it's invisible in the FileSystem dock otherwise).
    //   * "Build Odin Scripts" — compile the scripts dll (reuses the save-path build, streaming
    //     the same "rebuilding…" / "reloaded" status to the Output).
    plug := cast(godot.Editor_Plugin)self.object
    setup_name := godot.new_string_cstring("Set Up Odin Scripts")
    godot.editor_plugin_add_tool_menu_item(plug, setup_name, make_menu_callable(setup_menu_call))
    build_name := godot.new_string_cstring("Build Odin Scripts")
    godot.editor_plugin_add_tool_menu_item(plug, build_name, make_menu_callable(build_menu_call))
    //   * "Generate ols.json" — completion/checker config for EXTERNAL editors: any
    //     ols-based one (Neovim/Zed/Sublime/Helix), and JetBrains IDEs, whose Odin
    //     plugin imports ols.json (right-click it) to configure collections. All
    //     platforms — it's just a file write.
    ols_name := godot.new_string_cstring("Generate ols.json (IDE Completion)")
    godot.editor_plugin_add_tool_menu_item(plug, ols_name, make_menu_callable(ols_menu_call))
    //   * the debugger items ("Debug Game (LLDB)" / break-at-cursor / VS Code config) —
    //     core/debug_launch.odin (no-op on Windows: core/debug_launch_windows.odin).
    debug_register_menu_items(plug)
    // Toolbar build-status widget ("building… / build FAILED / live ✓") — see
    // core/build_status.odin. Torn down in _exit_tree.
    build_status_create(plug)
    // Teach the script editor's Find-in-Files (Ctrl+Shift+F) to search `.odin`.
    register_search_extension()
    // Drive the FileSystem-dock gen-file filter (core/gen_filter.odin) from _process.
    // EXPLICIT set_process: the engine's is-_process-overridden auto-enable doesn't
    // fire for virtual-call-data extension classes (same reason instance.odin calls
    // set_process by hand for script instances).
    godot.node_set_process(cast(godot.Node)self.object, true)
}

// OdinEditorPlugin._process — per-frame tick for the FileSystem-dock `*.gen.odin`
// filter. The dirty checks inside make the idle cost a handful of ptrcalls.
@(private = "file")
pl_process :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    gen_filter_tick()
}

// register_search_extension — add "odin" to `editor/script/search_in_file_extensions`
// so the script editor's Find-in-Files searches `.odin` files.
//
// Godot builds that filter list from a HARDCODED default in main.cpp — `gd`, `cs` (only
// if C# is present), `gdshader` — with NO hook for a GDExtension scripting language to
// contribute its extension (verified against 4.6 source). So `.gd`/`.cs` are searchable
// but `.odin` is silently skipped: the file walker treats the list as an allowlist
// (find_in_files.cpp `extension_filter.has(file.get_extension())`). Extensions are bare
// (no leading dot), and the dialog re-reads GLOBAL_GET each time it opens, so appending
// here at _enter_tree (which runs long before the user opens the dialog) takes effect
// this session. We DON'T ProjectSettings.save() — the in-memory value is enough and
// re-applied every launch, so a consumer's project.godot stays untouched.
@(private = "file")
register_search_extension :: proc "contextless" () {
    KEY :: "editor/script/search_in_file_extensions"
    v := godot.get_setting(KEY)
    defer godot.variant_destroy(&v)
    // The setting is a PACKED_STRING_ARRAY (main.cpp GLOBAL_DEF_NOVAL); if it's somehow
    // absent/another type the conversion yields an empty array and we still write a valid one.
    exts := godot.variant_to_packed_string_array(&v)
    defer psa_destroy(&exts)
    if !psa_ensure(&exts, "odin") {
        return // already present (persisted by a prior session or the user)
    }
    nv := godot.variant_from_packed_string_array(&exts)
    defer godot.variant_destroy(&nv)
    godot.set_setting(KEY, nv)
}

// OdinEditorPlugin._exit_tree — detach + free the toolbar widget (its Label must not
// outlive the extension dll that backs it).
@(private = "file")
pl_exit_tree :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    self := cast(^OdinEditorPlugin)instance
    build_status_destroy(cast(godot.Editor_Plugin)self.object)
}

// OdinEditorPlugin._build — Godot calls this on EVERY editor plugin when the user
// presses Play; returning false CANCELS the run (the C#-compilation hook). Waits out an
// in-flight background scripts build and refuses to launch on a failed one — otherwise
// save-then-Play silently runs the PREVIOUS dll. Body in core/build_status.odin.
@(private = "file")
pl_build :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    (cast(^godot.Bool)ret)^ = godot.Bool(build_gate_before_play())
}

// "Generate ols.json" body: write <project>/ols.json pointing the `godot` collection at
// the addon (plus base/core/vendor at the Odin share dir when resolvable) with the
// checker args every script package needs (-no-entry-point + the @(gd_*) attributes —
// without them an external checker flags every marked proc). Refuses to clobber an
// existing file: users hand-tune ols.json, and regenerating is one delete away.
@(private = "file")
ols_menu_call :: proc "c" (userdata: rawptr, args: [^]gdext.VariantPtr, argc: i64, ret: gdext.VariantPtr, err: ^gdext.CallError) {
    context = gdext.godot_context()
    context.allocator = runtime.heap_allocator()
    if err != nil {err.error = .Ok}

    root := odin_collection_root()
    defer delete(root)
    if root == "" {
        editor_msg_error("odin_godot: couldn't locate the addon — set the `odin_godot/root` project setting, then retry.")
        return
    }
    gres := godot.new_string_cstring("res://ols.json")
    pg := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
    path := string_to_odin(pg)
    defer delete(path)
    if os.exists(path) {
        editor_msg_warn(fmt.tprintf("odin_godot: %s already exists — leaving it untouched (delete it to regenerate).", path))
        return
    }

    share := resolve_odin_share()
    defer delete(share)

    b := strings.builder_make(context.temp_allocator)
    strings.write_string(&b, "{\n    \"collections\": [\n")
    fmt.sbprintf(&b, "        {{\"name\": \"godot\", \"path\": \"%s\"}}", root)
    if share != "" {
        for c in ([3]string{"base", "core", "vendor"}) {
            fmt.sbprintf(&b, ",\n        {{\"name\": \"%s\", \"path\": \"%s/%s\"}}", c, share, c)
        }
    }
    strings.write_string(&b, "\n    ],\n")
    strings.write_string(
        &b,
        "    \"enable_snippets\": true,\n" +
        "    \"enable_hover\": true,\n" +
        "    \"enable_semantic_tokens\": true,\n" +
        "    \"checker_args\": \"-no-entry-point -custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc -custom-attribute:gd_command -custom-attribute:gd_tick -custom-attribute:gd_sample -custom-attribute:gd_step -custom-attribute:gd_fact -custom-attribute:gd_message\"\n}\n",
    )
    if werr := os.write_entire_file(path, transmute([]byte)strings.to_string(b)); werr != nil {
        editor_msg_error(fmt.tprintf("odin_godot: couldn't write %s.", path))
        return
    }
    godot.print_str(
        fmt.tprintf(
            "odin_godot: wrote %s — ols-based editors pick it up automatically; in JetBrains IDEs right-click it and choose the Odin plugin's import action.",
            path,
        ),
    )
}

// Map a target OS feature tag -> the scripts dll suffix the EXPORTED core will look for.
@(private = "file")
target_ext :: proc(target: string) -> string {
    switch target {
    case "windows":
        return ".dll"
    case "linux":
        return ".so"
    case:
        return ".dylib" // macos (web handled separately)
    }
}

// Inspect the export feature set for the target-OS tag.
@(private = "file")
detect_target :: proc(features: ^godot.Packed_String_Array) -> string {
    n := godot.packed_string_array_size(features)
    for i in 0 ..< n {
        s := godot.packed_string_array_get(features, i64(i))
        feat := string_to_odin(s)
        defer delete(feat)
        switch feat {
        case "macos":
            return "macos"
        case "linux", "linuxbsd":
            return "linux"
        case "windows":
            return "windows"
        case "web":
            return "web"
        }
    }
    return ""
}

// Absolute filesystem path of `res://` for the project being exported.
@(private = "file")
project_dir :: proc(allocator := context.allocator) -> string {
    gres := godot.new_string_odin("res://")
    global := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
    s := string_to_odin(global, allocator)
    return strings.trim_suffix(s, "/")
}

// Directory component of a binary path (for prepending to PATH). "/a/b/odin" -> "/a/b";
// a bare name with no slash -> "." (it was found on PATH, so "." is a harmless prefix).
@(private = "file")
dir_of :: proc(path: string) -> string {
    if idx := strings.last_index_byte(path, '/'); idx >= 0 {
        return path[:idx]
    }
    return "."
}

// Optimization level for the EXPORTED scripts: project setting `odin_godot/export_optimization`,
// default "speed". A shipped game should be optimized (the dev rebuild-on-save loop stays at
// -o:none for fast iteration — see build_export_scripts.sh). VALIDATED to one of Odin's -o:
// levels because it's spliced into a shell command; an unknown value falls back to "speed".
@(private = "file")
export_opt_level :: proc() -> string {
    ps := godot.singleton_project_settings()
    key := godot.new_string_cstring("odin_godot/export_optimization")
    if bool(godot.project_settings_has_setting(ps, key)) {
        def := godot.Variant{}
        v := godot.project_settings_get_setting(ps, key, def)
        s := godot.variant_to_string(&v)
        cand := string_to_odin(s, context.temp_allocator)
        switch cand {
        case "none":       return "none"
        case "minimal":    return "minimal"
        case "size":       return "size"
        case "speed":      return "speed"
        case "aggressive": return "aggressive"
        case "": // unset/empty -> default below
        case:
            export_log(
                fmt.tprintf(
                    "odin export: ignoring invalid odin_godot/export_optimization=%q " +
                    "(use none|minimal|size|speed|aggressive) — using speed",
                    cand,
                ),
            )
        }
    }
    return "speed"
}

// OdinExportPlugin._export_begin — compile scripts for the target, bundle the dll.
@(private = "file")
ep_export_begin :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    context.allocator = runtime.heap_allocator()

    features := cast(^godot.Packed_String_Array)args[0]
    target := detect_target(features)
    if target == "" {
        export_error("odin export: could not determine target platform from features")
        return
    }

    proj := project_dir()
    defer delete(proj)
    // Same resolution as validate/reload: `odin_godot/root` setting -> ODIN_GODOT_ROOT env
    // -> derived. NEVER a hardcoded checkout path — a consumer exporting from a GUI-launched
    // editor has neither the env nor the maintainer's filesystem.
    root := odin_collection_root()
    defer delete(root)
    if root == "" {
        export_error(
            "odin export: couldn't locate the odin_godot collection — set the " +
            "`odin_godot/root` project setting to the addon/checkout path, then retry.",
        )
        return
    }

    if target == "web" {
        // Web: the FULL extension (core + binding + this project's scripts) is AOT-compiled
        // into ONE Emscripten SIDE_MODULE wasm at <proj>/bin/libodin_godot.wasm. The
        // project's .gdextension references it as `web.{debug,release}.wasm32`, so Godot's
        // own GDExtension export handling bundles it automatically (exactly like the macOS
        // dylib) — no add_shared_object needed. Our job here is just to (re)build that wasm
        // so the file the .gdextension points at actually exists at export time.
        //
        // Resolve BOTH toolchain binaries the way the native reload path does (project
        // setting -> env -> PATH), then prepend their dirs to PATH and pass ODIN=/EMCC=
        // explicitly. This is what lets web export work from an editor launched OUTSIDE a
        // toolchain shell (Finder/Steam) — where neither `odin` nor `emcc` is on the
        // inherited PATH (build_web.sh runs `odin`, and `emcc` shells its own sibling tools).
        odin_bin, odin_ok := resolve_odin_bin()
        if !odin_ok {
            export_error(
                "odin export: `odin` not found — cannot build the web wasm. Set the " +
                "`odin_godot/odin_bin` project setting to your odin binary (absolute path), " +
                "or launch the editor from a shell where `odin` is on PATH.",
            )
            return
        }
        defer delete(odin_bin)
        emcc_bin, emcc_ok := resolve_bin("odin_godot/emcc_bin", "EMCC", "emcc")
        if !emcc_ok {
            export_error(
                "odin export: Emscripten `emcc` not found — required for web export. Install " +
                "the Emscripten SDK (emsdk; activate 4.0.20 to match Godot 4.6's web " +
                "templates), then set the `odin_godot/emcc_bin` project setting to its `emcc` " +
                "(absolute path) or put it on the editor's PATH. See docs/exporting.md.",
            )
            return
        }
        defer delete(emcc_bin)

        opt := export_opt_level()
        outwasm := fmt.aprintf("%s/bin/libodin_godot.wasm", proj)
        defer delete(outwasm)
        odin_dir := dir_of(odin_bin)
        emcc_dir := dir_of(emcc_bin)
        // shell_quote every interpolated path (settings are user-editable; see common.odin).
        cmd := fmt.ctprintf(
            "PATH=%s:%s:\"$PATH\" ODIN=%s EMCC=%s ODIN_EXPORT_OPT=%s ODIN_GODOT_ROOT=%s bash %s/build/build_web.sh %s 1>&2",
            shell_quote(odin_dir, context.temp_allocator),
            shell_quote(emcc_dir, context.temp_allocator),
            shell_quote(odin_bin, context.temp_allocator),
            shell_quote(emcc_bin, context.temp_allocator),
            shell_quote(opt, context.temp_allocator),
            shell_quote(root, context.temp_allocator),
            shell_quote(root, context.temp_allocator),
            shell_quote(proj, context.temp_allocator),
        )
        export_log(fmt.tprintf("odin export: building web SIDE_MODULE wasm (-o:%s) -> %s", opt, outwasm))
        rc := libc.system(cmd)
        if rc != 0 {
            export_error(
                fmt.tprintf(
                    "odin export: FAILED to build web wasm (rc=%d). See the compiler/emcc error " +
                    "in the Output above. Reproduce it directly with: ODIN='%s' EMCC='%s' " +
                    "ODIN_GODOT_ROOT='%s' bash '%s/build/build_web.sh' '%s'.",
                    rc,
                    odin_bin,
                    emcc_bin,
                    root,
                    root,
                    proj,
                ),
            )
            return
        }
        if !os.is_file(outwasm) {
            export_error(fmt.tprintf("odin export: web build reported success but %s is missing", outwasm))
            return
        }
        export_log(
            fmt.tprintf(
                "odin export: built web SIDE_MODULE %s (bundled automatically via the .gdextension web.*.wasm32 entry)",
                outwasm,
            ),
        )
        return
    }

    // Resolve the compiler (project setting -> env -> PATH) and prepend its dir to PATH, so
    // desktop export works from an editor launched outside a toolchain shell (Finder/Steam).
    odin_bin, odin_ok := resolve_odin_bin()
    if !odin_ok {
        export_error(
            "odin export: `odin` not found — cannot compile scripts. Set the " +
            "`odin_godot/odin_bin` project setting to your odin binary (absolute path), or " +
            "launch the editor from a shell where `odin` is on PATH.",
        )
        return
    }
    defer delete(odin_bin)
    opt := export_opt_level()

    ext := target_ext(target)
    outdll := fmt.aprintf("%s/.export_build/libodinscripts%s", proj, ext)
    defer delete(outdll)

    // Run the scriptgen + odin build pipeline for the target, OPTIMIZED (ODIN_EXPORT_OPT).
    cmd := fmt.ctprintf(
        "PATH=%s:\"$PATH\" ODIN=%s ODIN_EXPORT_OPT=%s ODIN_GODOT_ROOT=%s bash %s/build/build_export_scripts.sh %s %s %s 1>&2",
        shell_quote(dir_of(odin_bin), context.temp_allocator),
        shell_quote(odin_bin, context.temp_allocator),
        shell_quote(opt, context.temp_allocator),
        shell_quote(root, context.temp_allocator),
        shell_quote(root, context.temp_allocator),
        shell_quote(proj, context.temp_allocator),
        shell_quote(target, context.temp_allocator),
        shell_quote(outdll, context.temp_allocator),
    )
    export_log(fmt.tprintf("odin export: compiling scripts for %s (-o:%s) -> %s", target, opt, outdll))
    rc := libc.system(cmd)
    if rc != 0 {
        export_error(fmt.tprintf("odin export: FAILED to compile scripts dll (rc=%d) — the exported game will have no Odin scripts", rc))
        return
    }
    if !os.is_file(outdll) {
        export_error(fmt.tprintf("odin export: compile reported success but %s is missing", outdll))
        return
    }

    // Bundle the scripts dll beside the executable. Empty tags/target = default location
    // (macOS Contents/Frameworks, sibling of the auto-exported core dll on others).
    self := cast(^OdinExportPlugin)instance
    path := godot.new_string_odin(outdll)
    tags := godot.new_packed_string_array()
    tgt := godot.new_string_cstring("")
    godot.editor_export_plugin_add_shared_object(
        cast(godot.Editor_Export_Plugin)self.object,
        path,
        tags,
        tgt,
    )
    export_log(fmt.tprintf("odin export: bundled %s", outdll))

    // Script MODULES (res://modules/<name>): build_export_scripts.sh (above) also built
    // one dll per module, as libodinscripts_<name><ext> SIBLINGS of the main dll in
    // .export_build/. Bundle each the same way — add_shared_object puts them beside the
    // main scripts dll (macOS: Contents/Frameworks), which is exactly where the exported
    // core's load_extra_modules scans (siblings of the main scripts dll). A module whose
    // dll is missing is an export ERROR naming the module — an exported game must never
    // silently ship without its module classes.
    bundle_export_modules(self, proj, ext)
}

// Enumerate <proj>/modules/* and add_shared_object each module's freshly built export
// dll. Skips (like the build script) module dirs with no .odin sources, and honors the
// same BUILD_MODULES=0 opt-out build_export_scripts.sh honors — with a loud log line,
// since the resulting export intentionally lacks the module classes.
@(private = "file")
bundle_export_modules :: proc(self: ^OdinExportPlugin, proj: string, ext: string) {
    if os.get_env("BUILD_MODULES", context.temp_allocator) == "0" {
        export_log(
            "odin export: BUILD_MODULES=0 — script modules NOT built or bundled; " +
            "the exported game will only have the main res://scripts classes",
        )
        return
    }
    modules_dir := fmt.tprintf("%s/modules", proj)
    if !os.exists(modules_dir) {return}
    fis, derr := os.read_directory_by_path(modules_dir, -1, context.temp_allocator)
    if derr != nil {
        export_error(fmt.tprintf("odin export: couldn't read %s — script modules not bundled", modules_dir))
        return
    }
    names := make([dynamic]string, context.temp_allocator)
    for fi in fis {
        if fi.type != .Directory {continue}
        if !dir_has_odin(fi.fullpath) {continue} // build_export_scripts.sh skipped it too
        append(&names, fi.name)
    }
    slice.sort(names[:]) // deterministic bundle/log order (matches the runtime's sorted load)
    for name in names {
        if strings.contains_rune(name, '.') {
            export_error(
                fmt.tprintf(
                    "odin export: script module '%s' has a dot in its name — the runtime only " +
                    "discovers dot-free libodinscripts_<name>%s dlls, so its classes would be " +
                    "silently absent from the exported game. Rename res://modules/%s.",
                    name, ext, name,
                ),
            )
            continue
        }
        dll := fmt.tprintf("%s/.export_build/libodinscripts_%s%s", proj, name, ext)
        if !os.is_file(dll) {
            export_error(
                fmt.tprintf(
                    "odin export: script module '%s' dll missing (%s) — the exported game " +
                    "would ship WITHOUT this module's classes",
                    name, dll,
                ),
            )
            continue
        }
        path := godot.new_string_odin(dll)
        tags := godot.new_packed_string_array()
        tgt := godot.new_string_cstring("")
        godot.editor_export_plugin_add_shared_object(
            cast(godot.Editor_Export_Plugin)self.object,
            path,
            tags,
            tgt,
        )
        export_log(fmt.tprintf("odin export: bundled module '%s' (%s)", name, dll))
    }
}

@(private = "file")
export_log :: proc(msg: string) {
    os.write_string(os.stderr, msg)
    os.write_string(os.stderr, "\n")
}

// export_error — a failure that must be VISIBLE. The plugin can't hard-abort the export from
// here (Godot 4.6 doesn't expose add_message to an EditorExportPlugin), and returning early
// leaves the export to finish with a broken/missing scripts library — so without this the
// user gets a "successful" export whose first symptom is a cryptic load failure. Push a red
// editor error (Output + Errors panels) in addition to the stderr line.
@(private = "file")
export_error :: proc(msg: string) {
    export_log(msg)
    gmsg := godot.new_string_odin(msg)
    godot.gd_push_error(godot.variant_from_string(&gmsg))
}

// ---- registration (called at .Editor init level) ----

odin_export_register :: proc() {
    gdext.string_name_new_with_latin1_chars(&odin_export_class_name, "OdinExportPlugin", true)
    gdext.string_name_new_with_latin1_chars(&odin_editor_plugin_class_name, "OdinEditorPlugin", true)

    // OdinExportPlugin.
    export_virtuals = make([dynamic]Virtual_Entry, 0, 16)
    append(&export_virtuals, Virtual_Entry{name = "_get_name", fn = ep_get_name})
    append(&export_virtuals, Virtual_Entry{name = "_export_begin", fn = ep_export_begin})

    export_info := gdext.ExtensionClassCreationInfo2 {
        is_virtual                  = false,
        is_abstract                 = false,
        is_exposed                  = true,
        create_instance_func        = export_create_instance,
        free_instance_func          = export_free_instance,
        get_virtual_call_data_func  = export_get_virtual_call_data,
        call_virtual_with_data_func = call_virtual_with_data,
        class_userdata              = nil,
    }
    register_extension_class(
        &odin_export_class_name,
        godot.editor_export_plugin_name_ref(),
        &export_info,
        level = .Editor,
    )

    // OdinEditorPlugin (host that registers the export plugin).
    editor_plugin_virtuals = make([dynamic]Virtual_Entry, 0, 16)
    append(&editor_plugin_virtuals, Virtual_Entry{name = "_enter_tree", fn = pl_enter_tree})
    append(&editor_plugin_virtuals, Virtual_Entry{name = "_exit_tree", fn = pl_exit_tree})
    append(&editor_plugin_virtuals, Virtual_Entry{name = "_process", fn = pl_process})
    append(&editor_plugin_virtuals, Virtual_Entry{name = "_get_plugin_name", fn = pl_get_plugin_name})
    append(&editor_plugin_virtuals, Virtual_Entry{name = "_build", fn = pl_build})

    plugin_info := gdext.ExtensionClassCreationInfo2 {
        is_virtual                  = false,
        is_abstract                 = false,
        is_exposed                  = true,
        create_instance_func        = editor_plugin_create_instance,
        free_instance_func          = editor_plugin_free_instance,
        get_virtual_call_data_func  = editor_plugin_get_virtual_call_data,
        call_virtual_with_data_func = call_virtual_with_data,
        class_userdata              = nil,
    }
    register_extension_class(
        &odin_editor_plugin_class_name,
        godot.editor_plugin_name_ref(),
        &plugin_info,
        level = .Editor,
    )

    // Hand the editor plugin to the editor by class name; Godot instantiates it and
    // (via _enter_tree) it registers the export plugin.
    gdext.editor_add_plugin(&odin_editor_plugin_class_name)
}

odin_export_unregister :: proc() {
    if odin_editor_plugin_class_name != {} {
        gdext.editor_remove_plugin(&odin_editor_plugin_class_name)
    }
}
