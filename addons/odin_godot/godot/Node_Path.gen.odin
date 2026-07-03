package godot

import __bindgen_gde "godot:gdext"


new_node_path :: proc {
    new_node_path_default,
    new_node_path_node_path,
    new_node_path_string,
}

new_node_path_default :: proc "contextless" (
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Node_Path, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_node_path_node_path :: proc "contextless" (
    from_: Node_Path,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Node_Path, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_node_path_string :: proc "contextless" (
    from_: String,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Node_Path, 2)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_node_path :: proc "contextless" (self: Node_Path) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.Node_Path)
    }

    self := self
    __ptr(&self)
}

// members


node_path_is_absolute :: proc "contextless" (
    self: ^Node_Path,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_absolute", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_get_name_count :: proc "contextless" (
    self: ^Node_Path,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_name_count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_get_name :: proc "contextless" (
    self: ^Node_Path,
    idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_name", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 2948586938)
    }
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_get_subname_count :: proc "contextless" (
    self: ^Node_Path,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_subname_count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_hash :: proc "contextless" (
    self: ^Node_Path,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hash", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_get_subname :: proc "contextless" (
    self: ^Node_Path,
    idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_subname", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 2948586938)
    }
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_get_concatenated_names :: proc "contextless" (
    self: ^Node_Path,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_concatenated_names", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 1825232092)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_get_concatenated_subnames :: proc "contextless" (
    self: ^Node_Path,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_concatenated_subnames", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 1825232092)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_slice :: proc "contextless" (
    self: ^Node_Path,
    begin_: Int,
    end_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slice", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 421628484)
    }
    begin_ := begin_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &begin_,
        &end_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_get_as_property_path :: proc "contextless" (
    self: ^Node_Path,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_as_property_path", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 1598598043)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
node_path_is_empty :: proc "contextless" (
    self: ^Node_Path,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Node_Path, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

node_path_equal_variant :: proc "contextless" (self: Node_Path, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Node_Path, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
node_path_equal_node_path :: proc "contextless" (self: Node_Path, other: Node_Path) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Node_Path, .Node_Path)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

node_path_equal :: proc {
    node_path_equal_variant,
    node_path_equal_node_path,
}
node_path_not_equal_variant :: proc "contextless" (self: Node_Path, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Node_Path, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
node_path_not_equal_node_path :: proc "contextless" (self: Node_Path, other: Node_Path) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Node_Path, .Node_Path)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

node_path_not_equal :: proc {
    node_path_not_equal_variant,
    node_path_not_equal_node_path,
}
node_path_not_default :: proc "contextless" (self: Node_Path) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Node_Path, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

node_path_not :: proc {
    node_path_not_default,
}
node_path_in_dictionary :: proc "contextless" (self: Node_Path, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Node_Path, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
node_path_in_array :: proc "contextless" (self: Node_Path, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Node_Path, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

node_path_in :: proc {
    node_path_in_dictionary,
    node_path_in_array,
}

