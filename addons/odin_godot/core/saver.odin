#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"
import "core:os"
import "core:strings"

// ----------------------------------------------------------------------------
// OdinResourceFormatSaver — lets the editor SAVE a `.odin` script (Ctrl+S, and the
// Create-Script wizard). Extends `ResourceFormatSaver`.
//
// Without a saver, ResourceSaver.save() has no handler for our `.odin` script resource
// and returns ERR_FILE_UNRECOGNIZED — i.e. "failed to save script to the filesystem".
// We write the script's current source text to disk: read it via Script.get_source_code()
// (which routes to OdinScript._get_source_code — always a valid String, even for a
// freshly-created/empty script), globalize the res:// path to an OS path, and write it.
// Scoped to `.odin` via _get_recognized_extensions, so it is only chosen for our scripts.
//
// Mirrors miniml_godot's MMLSaver. The loader (core/loader.odin) handles READ; this is WRITE.
// ----------------------------------------------------------------------------

@(private = "file")
odin_saver_class_name: godot.String_Name

@(private = "file")
saver_virtuals: [dynamic]Virtual_Entry

@(private = "file")
odin_saver_object: gdext.ObjectPtr

OdinResourceFormatSaver :: struct {
    object: gdext.ObjectPtr,
}

@(private = "file")
odin_saver_binding_callbacks := gdext.InstanceBindingCallbacks {
    create    = nil,
    free      = nil,
    reference = nil,
}

@(private = "file")
saver_create_instance :: proc "c" (class_user_data: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()
    object := gdext.classdb_construct_object(godot.resource_format_saver_name_ref())
    self := new(OdinResourceFormatSaver)
    self.object = object
    gdext.object_set_instance(object, &odin_saver_class_name, self)
    gdext.object_set_instance_binding(object, gdext.library, self, &odin_saver_binding_callbacks)
    return object
}

@(private = "file")
saver_free_instance :: proc "c" (class_user_data: rawptr, instance: gdext.ExtensionClassInstancePtr) {
    context = gdext.godot_context()
    if instance == nil {
        return
    }
    free(cast(^OdinResourceFormatSaver)instance)
}

@(private = "file")
saver_get_virtual_call_data :: proc "c" (class_user_data: rawptr, name: gdext.StringNamePtr) -> rawptr {
    context = gdext.godot_context()
    return lookup_virtual(saver_virtuals[:], name)
}

// ---- virtuals ----

// True iff `resource` is actually an OdinScript. The extension scoping is NOT enough on its
// own: if the user saves a *scene* (or any resource) to a `.odin` path, ResourceSaver still
// consults us, and saving a non-Script here means calling Script.get_source_code() on a
// non-Script object — which crashes the editor. is_class is a plain Object method, safe to
// call on any resource.
@(private = "file")
resource_is_odin_script :: proc(resource: gdext.ObjectPtr) -> bool {
    if resource == nil {
        return false
    }
    name := godot.new_string_cstring("OdinScript")
    return bool(godot.object_is_class(cast(godot.Object)resource, name))
}

// `_recognize(resource) -> bool`: only ACTUAL Odin scripts. Returning false for e.g. a scene
// saved to a `.odin` path makes that save fail gracefully instead of crashing in sv_save.
@(private = "file")
sv_recognize :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    resource := (cast(^gdext.ObjectPtr)args[0])^
    ret_bool(ret, resource_is_odin_script(resource))
}

@(private = "file")
sv_recognize_path :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    path := (cast(^godot.String)args[1])^
    odin_path := string_to_odin(path)
    defer delete(odin_path)
    ret_bool(ret, strings.has_suffix(odin_path, ".odin"))
}

@(private = "file")
sv_get_recognized_extensions :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_psa(ret, make_psa("odin"))
}

// `_set_uid(path, uid) -> Error`: OK (0). We don't maintain a UID side-file.
@(private = "file")
sv_set_uid :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    ret_int(ret, 0)
}

// `_save(resource, path, flags) -> Error`. Write the script's source to the globalized path.
@(private = "file")
sv_save :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()

    resource := (cast(^gdext.ObjectPtr)args[0])^
    path := (cast(^godot.String)args[1])^

    // Defensive: never call Script.get_source_code() on a non-Script (e.g. a scene the user
    // mistakenly saved to a `.odin` path) — that crashes. _recognize already rejects these, but
    // guard here too in case ResourceSaver reaches _save another way.
    if !resource_is_odin_script(resource) {
        ret_int(ret, 15) // ERR_FILE_UNRECOGNIZED
        return
    }

    // Current source via Script.get_source_code() (routes to OdinScript._get_source_code).
    src := godot.script_get_source_code(cast(godot.Script)resource)
    odin_src := string_to_odin(src)
    defer delete(odin_src)

    // res:// -> OS path.
    global := godot.project_settings_globalize_path(godot.singleton_project_settings(), path)
    os_path := string_to_odin(global)
    defer delete(os_path)

    if os_path == "" {
        ret_int(ret, 15) // ERR_FILE_UNRECOGNIZED
        return
    }

    // TEMPLATE PACKAGE FIXUP: the Create-Script dialog builds its template
    // before a path exists, so a fresh script lands with `package scripts` —
    // and saved into a directory whose siblings declare another package, that
    // is a guaranteed build break one step later ("Different package name").
    // The SAVE is the first moment both the text and the destination are
    // known, so fix the line up here. Only the template's default is ever
    // rewritten; user-authored package names are never touched.
    fixed_src := template_package_fixup(os_path, odin_src)
    if raw_data(fixed_src) != raw_data(odin_src) {
        fs := godot.new_string_odin(fixed_src)
        godot.script_set_source_code(cast(godot.Script)resource, fs)
        format_sync_editor_buffer(path, fixed_src)
    }
    defer if raw_data(fixed_src) != raw_data(odin_src) {delete(fixed_src)}

    // Format on save (core/format.odin): odinfmt the text hitting disk, keep the resource
    // + the open editor buffer in sync. Falls back to the original bytes on any problem
    // (no odinfmt, mid-edit syntax errors) — saving must never fail because of formatting.
    final_src := format_for_save(cast(godot.Script)resource, path, fixed_src)
    defer if raw_data(final_src) != raw_data(fixed_src) {delete(final_src)}

    if werr := os.write_entire_file(os_path, transmute([]u8)final_src); werr != nil {
        ret_int(ret, 12) // ERR_FILE_CANT_WRITE
        return
    }

    // Saving a script changed it — kick the background rebuild HERE so the change goes live
    // without a manual "Build Odin Scripts". We don't rely on the editor calling
    // OdinScript._reload after a save: a built-in-editor Ctrl+S doesn't trigger it reliably,
    // and when it does it can run BEFORE these bytes reach disk (so the sources look unchanged
    // and the build is skipped). Doing it right after the write guarantees the rebuild sees the
    // new content. reload_request is editor-gated + non-blocking, and hash-deduped if _reload
    // also fires.
    reload_request()

    ret_int(ret, 0) // OK
}

// If `source` declares the template's default `package scripts` and a sibling
// `.odin` file next to `os_path` declares something else, return a copy with
// the package line rewritten; otherwise return `source` unchanged (callers
// compare raw_data to know). Reads at most one sibling: any package mismatch
// among siblings is already a build error the fixup cannot save anyone from.
@(private = "file")
template_package_fixup :: proc(os_path: string, source: string) -> string {
    NEEDLE :: "\npackage scripts\n"
    at := strings.index(source, NEEDLE)
    if at < 0 {
        if !strings.has_prefix(source, "package scripts\n") {
            return source
        }
        at = -1 // package line first (no leading marker comments)
    }
    dir := os_path
    if i := strings.last_index_byte(dir, '/'); i >= 0 {
        dir = dir[:i]
    }
    sibling_pkg := ""
    if fd, err := os.open(dir); err == nil {
        defer os.close(fd)
        if entries, rerr := os.read_dir(fd, -1, context.temp_allocator); rerr == nil {
            for e in entries {
                if !strings.has_suffix(e.name, ".odin") || strings.has_suffix(e.name, ".gen.odin") {
                    continue
                }
                if e.fullpath == os_path {
                    continue
                }
                data, rerr2 := os.read_entire_file(e.fullpath, context.temp_allocator)
                if rerr2 != nil {
                    continue
                }
                text := string(data)
                for line in strings.split_lines_iterator(&text) {
                    t := strings.trim_space(line)
                    if strings.has_prefix(t, "package ") {
                        sibling_pkg = strings.trim_space(t[len("package "):])
                        break
                    }
                }
                if sibling_pkg != "" {
                    break
                }
            }
        }
    }
    if sibling_pkg == "" || sibling_pkg == "scripts" {
        return source
    }
    b := strings.builder_make()
    if at < 0 {
        strings.write_string(&b, "package ")
        strings.write_string(&b, sibling_pkg)
        strings.write_string(&b, source[len("package scripts"):])
    } else {
        strings.write_string(&b, source[:at])
        strings.write_string(&b, "\npackage ")
        strings.write_string(&b, sibling_pkg)
        strings.write_string(&b, "\n")
        strings.write_string(&b, source[at + len(NEEDLE):])
    }
    return strings.to_string(b)
}

odin_saver_register :: proc() {
    gdext.string_name_new_with_latin1_chars(&odin_saver_class_name, "OdinResourceFormatSaver", true)

    saver_virtuals = make([dynamic]Virtual_Entry, 0, 16) // reserve: gdext allocator .Resize is broken
    add := proc(name: string, fn: gdext.ExtensionClassCallVirtual) {
        append(&saver_virtuals, Virtual_Entry{name = name, fn = fn})
    }
    add("_save", sv_save)
    add("_recognize", sv_recognize)
    add("_recognize_path", sv_recognize_path)
    add("_get_recognized_extensions", sv_get_recognized_extensions)
    add("_set_uid", sv_set_uid)

    class_info := gdext.ExtensionClassCreationInfo2 {
        is_virtual                  = false,
        is_abstract                 = false,
        is_exposed                  = true,
        create_instance_func        = saver_create_instance,
        free_instance_func          = saver_free_instance,
        get_virtual_call_data_func  = saver_get_virtual_call_data,
        call_virtual_with_data_func = call_virtual_with_data,
        class_userdata              = nil,
    }

    register_extension_class(&odin_saver_class_name, godot.resource_format_saver_name_ref(), &class_info)

    odin_saver_object = gdext.classdb_construct_object(&odin_saver_class_name)
    godot.resource_saver_add_resource_format_saver(
        godot.singleton_resource_saver(),
        cast(godot.Resource_Format_Saver)odin_saver_object,
        true,
    )
}
