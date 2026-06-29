#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"

import "base:runtime"
import "core:c/libc"
import "core:fmt"
import "core:os"
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
@(private = "file")
pl_enter_tree :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    self := cast(^OdinEditorPlugin)instance
    ep_object := gdext.classdb_construct_object(&odin_export_class_name)
    godot.editor_plugin_add_export_plugin(
        cast(godot.Editor_Plugin)self.object,
        cast(godot.Editor_Export_Plugin)ep_object,
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

// The odin_godot repo root (collection path for the compile). Hardcoded like every
// other build script here, overridable via env for a relocated checkout.
@(private = "file")
godot_root :: proc(allocator := context.allocator) -> string {
    if v, ok := os.lookup_env("ODIN_GODOT_ROOT", allocator); ok && v != "" {
        return v
    }
    return strings.clone("/Users/walter/data/code/odin/odin_godot", allocator)
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
    root := godot_root()
    defer delete(root)

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
        cmd := fmt.ctprintf(
            "PATH='%s':'%s':\"$PATH\" ODIN='%s' EMCC='%s' ODIN_EXPORT_OPT='%s' ODIN_GODOT_ROOT='%s' bash '%s/build/build_web.sh' '%s' 1>&2",
            odin_dir,
            emcc_dir,
            odin_bin,
            emcc_bin,
            opt,
            root,
            root,
            proj,
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
        "PATH='%s':\"$PATH\" ODIN='%s' ODIN_EXPORT_OPT='%s' ODIN_GODOT_ROOT='%s' bash '%s/build/build_export_scripts.sh' '%s' '%s' '%s' 1>&2",
        dir_of(odin_bin),
        odin_bin,
        opt,
        root,
        root,
        proj,
        target,
        outdll,
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
    gdext.classdb_register_extension_class2(
        gdext.library,
        &odin_export_class_name,
        godot.editor_export_plugin_name_ref(),
        &export_info,
    )

    // OdinEditorPlugin (host that registers the export plugin).
    editor_plugin_virtuals = make([dynamic]Virtual_Entry, 0, 16)
    append(&editor_plugin_virtuals, Virtual_Entry{name = "_enter_tree", fn = pl_enter_tree})
    append(&editor_plugin_virtuals, Virtual_Entry{name = "_get_plugin_name", fn = pl_get_plugin_name})

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
    gdext.classdb_register_extension_class2(
        gdext.library,
        &odin_editor_plugin_class_name,
        godot.editor_plugin_name_ref(),
        &plugin_info,
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
