package godot

import __bindgen_gde "godot:gdext"

Editor_Vcs_Interface_Constants :: enum {
}
Editor_Vcs_Interface_Change_Type :: enum int {
    Change_Type_New = 0,
    Change_Type_Modified = 1,
    Change_Type_Renamed = 2,
    Change_Type_Deleted = 3,
    Change_Type_Typechange = 4,
    Change_Type_Unmerged = 5,
}
Editor_Vcs_Interface_Tree_Area :: enum int {
    Tree_Area_Commit = 0,
    Tree_Area_Staged = 1,
    Tree_Area_Unstaged = 2,
}



editor_vcs_interface_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_vcs_interface_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_vcs_interface :: proc "contextless" () -> Editor_Vcs_Interface {
    return cast(Editor_Vcs_Interface)__bindgen_gde.classdb_construct_object(editor_vcs_interface_name_ref())
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

editor_vcs_interface__initialize :: proc "contextless" (
    self: Editor_Vcs_Interface,
    project_path_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_initialize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2323990056)
    }
    self := self
    project_path_ := project_path_
    args := []__bindgen_gde.TypePtr {
        &project_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__set_credentials :: proc "contextless" (
    self: Editor_Vcs_Interface,
    username_: String,
    password_: String,
    ssh_public_key_path_: String,
    ssh_private_key_path_: String,
    ssh_passphrase_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_credentials", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1336744649)
    }
    self := self
    username_ := username_
    password_ := password_
    ssh_public_key_path_ := ssh_public_key_path_
    ssh_private_key_path_ := ssh_private_key_path_
    ssh_passphrase_ := ssh_passphrase_
    args := []__bindgen_gde.TypePtr {
        &username_,
        &password_,
        &ssh_public_key_path_,
        &ssh_private_key_path_,
        &ssh_passphrase_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__get_modified_files_data :: proc "contextless" (
    self: Editor_Vcs_Interface,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_modified_files_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__stage_file :: proc "contextless" (
    self: Editor_Vcs_Interface,
    file_path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_stage_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    file_path_ := file_path_
    args := []__bindgen_gde.TypePtr {
        &file_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__unstage_file :: proc "contextless" (
    self: Editor_Vcs_Interface,
    file_path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_unstage_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    file_path_ := file_path_
    args := []__bindgen_gde.TypePtr {
        &file_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__discard_file :: proc "contextless" (
    self: Editor_Vcs_Interface,
    file_path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_discard_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    file_path_ := file_path_
    args := []__bindgen_gde.TypePtr {
        &file_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__commit :: proc "contextless" (
    self: Editor_Vcs_Interface,
    msg_: String,
    amend_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_commit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2678287736)
    }
    self := self
    msg_ := msg_
    amend_ := amend_
    args := []__bindgen_gde.TypePtr {
        &msg_,
        &amend_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__allow_amends :: proc "contextless" (
    self: Editor_Vcs_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_allow_amends", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__get_diff :: proc "contextless" (
    self: Editor_Vcs_Interface,
    identifier_: String,
    area_: Int,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_diff", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1366379175)
    }
    self := self
    identifier_ := identifier_
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &identifier_,
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__shut_down :: proc "contextless" (
    self: Editor_Vcs_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_shut_down", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__get_vcs_name :: proc "contextless" (
    self: Editor_Vcs_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_vcs_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2841200299)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__get_previous_commits :: proc "contextless" (
    self: Editor_Vcs_Interface,
    max_commits_: Int,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_previous_commits", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1171824711)
    }
    self := self
    max_commits_ := max_commits_
    args := []__bindgen_gde.TypePtr {
        &max_commits_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__get_branch_list :: proc "contextless" (
    self: Editor_Vcs_Interface,
) -> (ret: Typed_Array(String)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_branch_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__get_remotes :: proc "contextless" (
    self: Editor_Vcs_Interface,
) -> (ret: Typed_Array(String)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_remotes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__create_branch :: proc "contextless" (
    self: Editor_Vcs_Interface,
    branch_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_create_branch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    branch_name_ := branch_name_
    args := []__bindgen_gde.TypePtr {
        &branch_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__remove_branch :: proc "contextless" (
    self: Editor_Vcs_Interface,
    branch_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_remove_branch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    branch_name_ := branch_name_
    args := []__bindgen_gde.TypePtr {
        &branch_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__create_remote :: proc "contextless" (
    self: Editor_Vcs_Interface,
    remote_name_: String,
    remote_url_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_create_remote", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3186203200)
    }
    self := self
    remote_name_ := remote_name_
    remote_url_ := remote_url_
    args := []__bindgen_gde.TypePtr {
        &remote_name_,
        &remote_url_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__remove_remote :: proc "contextless" (
    self: Editor_Vcs_Interface,
    remote_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_remove_remote", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    remote_name_ := remote_name_
    args := []__bindgen_gde.TypePtr {
        &remote_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__get_current_branch_name :: proc "contextless" (
    self: Editor_Vcs_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_current_branch_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2841200299)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__checkout_branch :: proc "contextless" (
    self: Editor_Vcs_Interface,
    branch_name_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_checkout_branch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2323990056)
    }
    self := self
    branch_name_ := branch_name_
    args := []__bindgen_gde.TypePtr {
        &branch_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface__pull :: proc "contextless" (
    self: Editor_Vcs_Interface,
    remote_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_pull", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    remote_ := remote_
    args := []__bindgen_gde.TypePtr {
        &remote_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__push :: proc "contextless" (
    self: Editor_Vcs_Interface,
    remote_: String,
    force_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_push", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2678287736)
    }
    self := self
    remote_ := remote_
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &remote_,
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__fetch :: proc "contextless" (
    self: Editor_Vcs_Interface,
    remote_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_fetch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    remote_ := remote_
    args := []__bindgen_gde.TypePtr {
        &remote_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_vcs_interface__get_line_diff :: proc "contextless" (
    self: Editor_Vcs_Interface,
    file_path_: String,
    text_: String,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_line_diff", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2796572089)
    }
    self := self
    file_path_ := file_path_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &file_path_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface_create_diff_line :: proc "contextless" (
    self: Editor_Vcs_Interface,
    new_line_no_: Int,
    old_line_no_: Int,
    content_: String,
    status_: String,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_diff_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2901184053)
    }
    self := self
    new_line_no_ := new_line_no_
    old_line_no_ := old_line_no_
    content_ := content_
    status_ := status_
    args := []__bindgen_gde.TypePtr {
        &new_line_no_,
        &old_line_no_,
        &content_,
        &status_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface_create_diff_hunk :: proc "contextless" (
    self: Editor_Vcs_Interface,
    old_start_: Int,
    new_start_: Int,
    old_lines_: Int,
    new_lines_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_diff_hunk", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3784842090)
    }
    self := self
    old_start_ := old_start_
    new_start_ := new_start_
    old_lines_ := old_lines_
    new_lines_ := new_lines_
    args := []__bindgen_gde.TypePtr {
        &old_start_,
        &new_start_,
        &old_lines_,
        &new_lines_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface_create_diff_file :: proc "contextless" (
    self: Editor_Vcs_Interface,
    new_file_: String,
    old_file_: String,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_diff_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2723227684)
    }
    self := self
    new_file_ := new_file_
    old_file_ := old_file_
    args := []__bindgen_gde.TypePtr {
        &new_file_,
        &old_file_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface_create_commit :: proc "contextless" (
    self: Editor_Vcs_Interface,
    msg_: String,
    author_: String,
    id_: String,
    unix_timestamp_: Int,
    offset_minutes_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_commit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1075983584)
    }
    self := self
    msg_ := msg_
    author_ := author_
    id_ := id_
    unix_timestamp_ := unix_timestamp_
    offset_minutes_ := offset_minutes_
    args := []__bindgen_gde.TypePtr {
        &msg_,
        &author_,
        &id_,
        &unix_timestamp_,
        &offset_minutes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface_create_status_file :: proc "contextless" (
    self: Editor_Vcs_Interface,
    file_path_: String,
    change_type_: Editor_Vcs_Interface_Change_Type,
    area_: Editor_Vcs_Interface_Tree_Area,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_status_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1083471673)
    }
    self := self
    file_path_ := file_path_
    change_type_ := change_type_
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &file_path_,
        &change_type_,
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface_add_diff_hunks_into_diff_file :: proc "contextless" (
    self: Editor_Vcs_Interface,
    diff_file_: Dictionary,
    diff_hunks_: Typed_Array(Dictionary),
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_diff_hunks_into_diff_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4015243225)
    }
    self := self
    diff_file_ := diff_file_
    diff_hunks_ := diff_hunks_
    args := []__bindgen_gde.TypePtr {
        &diff_file_,
        &diff_hunks_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface_add_line_diffs_into_diff_hunk :: proc "contextless" (
    self: Editor_Vcs_Interface,
    diff_hunk_: Dictionary,
    line_diffs_: Typed_Array(Dictionary),
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_line_diffs_into_diff_hunk", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4015243225)
    }
    self := self
    diff_hunk_ := diff_hunk_
    line_diffs_ := line_diffs_
    args := []__bindgen_gde.TypePtr {
        &diff_hunk_,
        &line_diffs_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_vcs_interface_popup_error :: proc "contextless" (
    self: Editor_Vcs_Interface,
    msg_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_error", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    msg_ := msg_
    args := []__bindgen_gde.TypePtr {
        &msg_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_vcs_interface_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorVCSInterface", true)
}

@(private = "file")
__class_name: String_Name