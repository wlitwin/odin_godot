package godot

import __bindgen_gde "godot:gdext"

Worker_Thread_Pool_Constants :: enum {
}



worker_thread_pool_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

worker_thread_pool_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_worker_thread_pool :: proc "contextless" () -> Worker_Thread_Pool {
    return __bindgen_gde.classdb_construct_object(worker_thread_pool_name_ref())
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

worker_thread_pool_add_task :: proc "contextless" (
    self: Worker_Thread_Pool,
    action_: Callable,
    high_priority_: Bool,
    description_: String,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_task", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3745067146)
    }
    self := self
    action_ := action_
    high_priority_ := high_priority_
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &action_,
        &high_priority_,
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

worker_thread_pool_is_task_completed :: proc "contextless" (
    self: Worker_Thread_Pool,
    task_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_task_completed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    task_id_ := task_id_
    args := []__bindgen_gde.TypePtr {
        &task_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

worker_thread_pool_wait_for_task_completion :: proc "contextless" (
    self: Worker_Thread_Pool,
    task_id_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("wait_for_task_completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844576869)
    }
    self := self
    task_id_ := task_id_
    args := []__bindgen_gde.TypePtr {
        &task_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

worker_thread_pool_get_caller_task_id :: proc "contextless" (
    self: Worker_Thread_Pool,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caller_task_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

worker_thread_pool_add_group_task :: proc "contextless" (
    self: Worker_Thread_Pool,
    action_: Callable,
    elements_: Int,
    tasks_needed_: Int,
    high_priority_: Bool,
    description_: String,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_group_task", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1801953219)
    }
    self := self
    action_ := action_
    elements_ := elements_
    tasks_needed_ := tasks_needed_
    high_priority_ := high_priority_
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &action_,
        &elements_,
        &tasks_needed_,
        &high_priority_,
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

worker_thread_pool_is_group_task_completed :: proc "contextless" (
    self: Worker_Thread_Pool,
    group_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_group_task_completed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    group_id_ := group_id_
    args := []__bindgen_gde.TypePtr {
        &group_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

worker_thread_pool_get_group_processed_element_count :: proc "contextless" (
    self: Worker_Thread_Pool,
    group_id_: Int,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_group_processed_element_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    group_id_ := group_id_
    args := []__bindgen_gde.TypePtr {
        &group_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

worker_thread_pool_wait_for_group_task_completion :: proc "contextless" (
    self: Worker_Thread_Pool,
    group_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("wait_for_group_task_completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    group_id_ := group_id_
    args := []__bindgen_gde.TypePtr {
        &group_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

worker_thread_pool_get_caller_group_id :: proc "contextless" (
    self: Worker_Thread_Pool,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caller_group_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
worker_thread_pool_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("WorkerThreadPool", true)
}

@(private = "file")
__class_name: String_Name