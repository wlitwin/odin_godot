package godot

import __bindgen_gde "godot:gdext"

Editor_Undo_Redo_Manager_Constants :: enum {
}
Editor_Undo_Redo_Manager_Special_History :: enum int {
    Global_History = 0,
    Remote_History = -9,
    Invalid_History = -99,
}



editor_undo_redo_manager_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_undo_redo_manager_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_undo_redo_manager :: proc "contextless" () -> Editor_Undo_Redo_Manager {
    return __bindgen_gde.classdb_construct_object(editor_undo_redo_manager_name_ref())
}

// methods
//
// Method binds are resolved LAZILY on first call (the `@(static) __ptr` guard),
// NOT eagerly in `_init`. Many engine classes (Node, Control, the *Server
// singletons, ...) are only registered with ClassDB at later initialization
// levels (Servers/Scene), while `godot.init()` runs at the extension entry
// (Core level). Eagerly fetching every bind there returned null for ~91% of
// methods (a 16k-line `mb is null` flood). Resolving on first call defers the
// fetch to a point where the owning class is registered, mirroring how the
// builtin/variant methods already work. A genuinely unresolvable bind stays
// nil and the following ptrcall surfaces it at the call site.
//
// VARARG methods (`is_vararg` in extension_api.json) cannot use ptrcall — Godot
// aborts with "ptrcall can't be used with vararg methods". They instead go
// through `object_method_bind_call`: the fixed declared args are marshalled to
// Variants, the variadic `extra: ..Variant` are appended, and the returned
// Variant is converted to the declared return type (Variant passed through,
// `Error`/ints via variant_to_int, void ignored).

editor_undo_redo_manager_create_action :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    name_: String,
    merge_mode_: Undo_Redo_Merge_Mode,
    custom_context_: Object,
    backward_undo_ops_: Bool,
    mark_unsaved_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 796197507)
    }
    self := self
    name_ := name_
    merge_mode_ := merge_mode_
    custom_context_ := custom_context_
    backward_undo_ops_ := backward_undo_ops_
    mark_unsaved_ := mark_unsaved_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &merge_mode_,
        &custom_context_,
        &backward_undo_ops_,
        &mark_unsaved_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_undo_redo_manager_commit_action :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    execute_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("commit_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3216645846)
    }
    self := self
    execute_ := execute_
    args := []__bindgen_gde.TypePtr {
        &execute_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_undo_redo_manager_is_committing_action :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_committing_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_undo_redo_manager_force_fixed_history :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_fixed_history", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_undo_redo_manager_add_do_method :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    object_: Object,
    method_: String_Name,
    extra: ..Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_do_method", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1517810467)
    }
    self := self
    object_ := object_
    __fv_object := variant_from(&object_)
    method_ := method_
    __fv_method := variant_from(&method_)
    __argv: [64]__bindgen_gde.VariantPtr
    __n := 0
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_object
    __n += 1
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_method
    __n += 1
    for __i in 0 ..< len(extra) {
        if __n >= 64 do break
        __argv[__n] = cast(__bindgen_gde.VariantPtr)&extra[__i]
        __n += 1
    }
    __ret: Variant
    __bindgen_gde.object_method_bind_call(__ptr, self, &__argv[0], i64(__n), cast(__bindgen_gde.VariantPtr)&__ret, nil)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__ret)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_object)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_method)
    return
}

editor_undo_redo_manager_add_undo_method :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    object_: Object,
    method_: String_Name,
    extra: ..Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_undo_method", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1517810467)
    }
    self := self
    object_ := object_
    __fv_object := variant_from(&object_)
    method_ := method_
    __fv_method := variant_from(&method_)
    __argv: [64]__bindgen_gde.VariantPtr
    __n := 0
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_object
    __n += 1
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_method
    __n += 1
    for __i in 0 ..< len(extra) {
        if __n >= 64 do break
        __argv[__n] = cast(__bindgen_gde.VariantPtr)&extra[__i]
        __n += 1
    }
    __ret: Variant
    __bindgen_gde.object_method_bind_call(__ptr, self, &__argv[0], i64(__n), cast(__bindgen_gde.VariantPtr)&__ret, nil)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__ret)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_object)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_method)
    return
}

editor_undo_redo_manager_add_do_property :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    object_: Object,
    property_: String_Name,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_do_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1017172818)
    }
    self := self
    object_ := object_
    property_ := property_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &property_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_undo_redo_manager_add_undo_property :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    object_: Object,
    property_: String_Name,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_undo_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1017172818)
    }
    self := self
    object_ := object_
    property_ := property_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &property_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_undo_redo_manager_add_do_reference :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    object_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_do_reference", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_undo_redo_manager_add_undo_reference :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    object_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_undo_reference", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_undo_redo_manager_get_object_history_id :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    object_: Object,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_object_history_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1107568780)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_undo_redo_manager_get_history_undo_redo :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    id_: Int,
) -> (ret: Undo_Redo) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_history_undo_redo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2417974513)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_undo_redo_manager_clear_history :: proc "contextless" (
    self: Editor_Undo_Redo_Manager,
    id_: Int,
    increase_version_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_history", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2020603371)
    }
    self := self
    id_ := id_
    increase_version_ := increase_version_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &increase_version_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_undo_redo_manager_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorUndoRedoManager", true)
}

@(private = "file")
__class_name: String_Name