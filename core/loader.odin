package core

import "godot:gdext"
import "godot:godot"
import "core:strings"

// ----------------------------------------------------------------------------
// OdinResourceFormatLoader — teaches ResourceLoader to turn a `.odin` file into an
// OdinScript resource. Extends `ResourceFormatLoader`.
//
// Phase 1: read the file text via FileAccess, build an OdinScript, store the source.
// No execution. The loader may run off the main thread, so it only touches the
// resource it is constructing.
// ----------------------------------------------------------------------------

@(private = "file")
odin_loader_class_name: godot.String_Name

@(private = "file")
loader_virtuals: [dynamic]Virtual_Entry

// Kept alive for the lifetime of the extension.
@(private = "file")
odin_loader_object: gdext.ObjectPtr

@(private = "file")
odin_loader_instance: ^OdinResourceFormatLoader

// The ResourceLoader singleton resolved by-name (the generated
// `singleton_resource_loader` looks up the wrong name "Resource_Loader").
@(private = "file")
get_resource_loader :: proc "contextless" () -> godot.Resource_Loader {
    @(static) ptr: gdext.ObjectPtr
    if ptr == nil {
        name := godot.new_string_name_cstring("ResourceLoader", true)
        ptr = gdext.global_get_singleton(&name)
    }
    return cast(godot.Resource_Loader)ptr
}

OdinResourceFormatLoader :: struct {
    object: gdext.ObjectPtr,
}

@(private = "file")
odin_loader_binding_callbacks := gdext.InstanceBindingCallbacks {
    create    = nil,
    free      = nil,
    reference = nil,
}

@(private = "file")
loader_create_instance :: proc "c" (class_user_data: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()
    object := gdext.classdb_construct_object(godot.resource_format_loader_name_ref())
    self := new(OdinResourceFormatLoader)
    self.object = object
    gdext.object_set_instance(object, &odin_loader_class_name, self)
    gdext.object_set_instance_binding(object, gdext.library, self, &odin_loader_binding_callbacks)
    return object
}

@(private = "file")
loader_free_instance :: proc "c" (class_user_data: rawptr, instance: gdext.ExtensionClassInstancePtr) {
    context = gdext.godot_context()
    if instance == nil {
        return
    }
    free(cast(^OdinResourceFormatLoader)instance)
}

@(private = "file")
loader_get_virtual_call_data :: proc "c" (class_user_data: rawptr, name: gdext.StringNamePtr) -> rawptr {
    context = gdext.godot_context()
    return lookup_virtual(loader_virtuals[:], name)
}

// ---- virtuals ----

@(private = "file")
ld_get_recognized_extensions :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    ret_psa(ret, make_psa("odin"))
}

@(private = "file")
ld_handles_type :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    type := string_name_to_odin(cast(gdext.StringNamePtr)args[0])
    defer delete(type)
    handled := type == "Script" || type == "OdinScript" || type == "Resource"
    ret_bool(ret, handled)
}

@(private = "file")
ld_get_resource_type :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    path := (cast(^godot.String)args[0])^
    odin_path := string_to_odin(path)
    defer delete(odin_path)
    // `*.gen.odin` are scriptgen build artifacts that sit beside authored sources in
    // res://. They end in `.odin` but must NOT be treated as attachable scripts.
    if strings.has_suffix(odin_path, ".odin") && !strings.has_suffix(odin_path, ".gen.odin") {
        ret_string(ret, godot.new_string_cstring("OdinScript"))
    } else {
        ret_string(ret, godot.new_string_cstring(""))
    }
}

@(private = "file")
ld_recognize_path :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    path := (cast(^godot.String)args[0])^
    odin_path := string_to_odin(path)
    defer delete(odin_path)
    // Authored `.odin` is recognized; scriptgen's `*.gen.odin` artifacts are not.
    recognized := strings.has_suffix(odin_path, ".odin") && !strings.has_suffix(odin_path, ".gen.odin")
    ret_bool(ret, recognized)
}

@(private = "file")
ld_load :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()

    path := (cast(^godot.String)args[0])^
    // Use the STATIC FileAccess.get_file_as_string (instance == nil). The generated
    // instance-method wrappers pass `&self` as the object pointer, which is wrong for
    // Ref-typed receivers like File_Access and crashes; static methods avoid that.
    text := godot.file_access_get_file_as_string(path)

    // An unreadable path must return the ERROR int, not a valid empty script — a broken
    // res:// reference would otherwise "load" fine and only fail later at instance time.
    // get_file_as_string returns "" for both an empty file and a failure; get_open_error
    // (static, set by the underlying open) disambiguates.
    if open_err := godot.file_access_get_open_error(); open_err != .Ok {
        err_code := i64(godot.Error.Err_File_Cant_Open)
        err_v := godot.variant_from_int(&err_code)
        ret_variant(ret, err_v)
        return
    }

    object, self := odin_script_construct()
    odin_script_set_source(self, text)

    v := godot.variant_from_object(cast(^godot.Object)&object)
    ret_variant(ret, v)
}

odin_loader_register :: proc() {
    gdext.string_name_new_with_latin1_chars(&odin_loader_class_name, "OdinResourceFormatLoader", true)

    loader_virtuals = make([dynamic]Virtual_Entry, 0, 64) // reserve: gdext allocator .Resize is broken (drops data)
    add := proc(name: string, fn: gdext.ExtensionClassCallVirtual) {
        append(&loader_virtuals, Virtual_Entry{name = name, fn = fn})
    }
    add("_get_recognized_extensions", ld_get_recognized_extensions)
    add("_handles_type", ld_handles_type)
    add("_get_resource_type", ld_get_resource_type)
    add("_recognize_path", ld_recognize_path)
    add("_load", ld_load)

    class_info := gdext.ExtensionClassCreationInfo2 {
        is_virtual                  = false,
        is_abstract                 = false,
        is_exposed                  = true,
        create_instance_func        = loader_create_instance,
        free_instance_func          = loader_free_instance,
        get_virtual_call_data_func  = loader_get_virtual_call_data,
        call_virtual_with_data_func = call_virtual_with_data,
        class_userdata              = nil,
    }

    register_extension_class(&odin_loader_class_name, godot.resource_format_loader_name_ref(), &class_info)

    // Construct the loader and register it (at front so it wins for `.odin`).
    odin_loader_object = gdext.classdb_construct_object(&odin_loader_class_name)
    odin_loader_instance = cast(^OdinResourceFormatLoader)gdext.object_get_instance_binding(
        odin_loader_object,
        gdext.library,
        &odin_loader_binding_callbacks,
    )
    godot.resource_loader_add_resource_format_loader(
        get_resource_loader(),
        cast(godot.Resource_Format_Loader)odin_loader_object,
        true,
    )
}

odin_loader_unregister :: proc() {
    if odin_loader_object != nil {
        godot.resource_loader_remove_resource_format_loader(
            get_resource_loader(),
            cast(godot.Resource_Format_Loader)odin_loader_object,
        )
    }
}
