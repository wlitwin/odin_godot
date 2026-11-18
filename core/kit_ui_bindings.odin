package core

import "godot:gdext"
import gd "godot:godot"
import ui "godot:kit/ui/bindings"
import "core:strings"

@(private)
UI_Bindings :: struct {
    object:          gdext.ObjectPtr,
    kind:            i64,
    paths:           [ui.Field]gd.Node_Path,
    tree:            gd.Scene_Tree,
    changed:         gd.Callable,
    warning_changed: gd.Callable,
    last_warning:    string,
}

@(private)
ui_empty_name: gd.String_Name
@(private)
ui_bindings_name: gd.String_Name
@(private)
ui_properties: [ui.Kind][dynamic]gdext.PropertyInfo
@(private)
ui_property_names: [11]gd.String_Name
@(private)
ui_property_hints: [11]gd.String
@(private)
ui_binding_callbacks := gdext.InstanceBindingCallbacks{}

@(private)
ui_bindings_create :: proc "c" (_: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()
    self := new(UI_Bindings)
    self.object = gdext.classdb_construct_object(gd.node_name_ref())

    for spec, field in ui.SPECS {
        self.paths[field] = gd.new_node_path_cstring(spec.default_path)
    }

    gdext.object_set_instance(self.object, &ui_bindings_name, self)
    gdext.object_set_instance_binding(self.object, gdext.library, self, &ui_binding_callbacks)
    return self.object
}

@(private)
ui_bindings_disconnect :: proc(self: ^UI_Bindings) {
    if self.tree != nil {
        gd.object_disconnect(cast(gd.Object)self.tree, gd.sname("tree_changed"), self.changed)
        gd.object_disconnect(
            cast(gd.Object)self.tree,
            gd.sname("node_configuration_warning_changed"),
            self.warning_changed,
        )
        gd.free_callable(self.warning_changed)
        gd.free_callable(self.changed)
        self.tree = nil
        self.changed = {}
        self.warning_changed = {}
    }
}

@(private)
ui_bindings_free :: proc "c" (_: rawptr, instance: rawptr) {
    context = gdext.godot_context()
    self := cast(^UI_Bindings)instance

    if self == nil {
        return
    }

    ui_bindings_disconnect(self)

    for path in self.paths {
        gd.free_node_path(path)
    }

    delete(self.last_warning)
    free(self)
}

@(private)
ui_bindings_report :: proc(self: ^UI_Bindings) -> ui.Report {
    if !ui.kind_valid(self.kind) {
        report: ui.Report
        ui.problem(&report, "Kit UI: select Lobby, Chat or Scoreboard in Widget.")
        return report
    }

    node := cast(gd.Node)self.object
    root := gd.node_get_owner(node)

    if root == nil {
        root = gd.node_get_parent(node)
    }

    for root != nil {
        path := gd.node_get_scene_file_path(root)
        named := gd.string_length(&path) > 0
        gd.free_string(path)
        owner := gd.node_get_owner(root)

        if named || owner == nil {
            break
        }

        root = owner
    }

    result := ui.resolve(root, ui.Kind(self.kind))
    return result.report
}

@(private)
ui_bindings_refresh :: proc(self: ^UI_Bindings) {
    if self.tree == nil {
        return
    }

    report := ui_bindings_report(self)
    value := ui.text(&report)

    if value != self.last_warning {
        delete(self.last_warning)
        self.last_warning = strings.clone(value)
        gd.node_update_configuration_warnings(cast(gd.Node)self.object)
    }
}

@(private)
ui_bindings_set :: proc "c" (instance: rawptr, name: gdext.StringNamePtr, value: gdext.VariantPtr) -> bool {
    context = gdext.godot_context()
    self := cast(^UI_Bindings)instance
    key := string_name_to_odin(name)
    defer delete(key)
    v := cast(^gd.Variant)value

    if key == "widget" {
        if gdext.variant_get_type(cast(gdext.VariantPtr)v) != .Int {
            return false
        }

        self.kind = gd.variant_to_int(v)
        gd.object_notify_property_list_changed(cast(gd.Object)self.object)
        ui_bindings_refresh(self)
        return true
    }

    for spec, field in ui.SPECS {
        if key == string(spec.property) {
            if gdext.variant_get_type(cast(gdext.VariantPtr)v) != .Node_Path {
                return false
            }

            path := gd.variant_to_node_path(v)
            gd.free_node_path(self.paths[field])
            self.paths[field] = path
            ui_bindings_refresh(self)
            return true
        }
    }

    return false
}

@(private)
ui_bindings_get :: proc "c" (instance: rawptr, name: gdext.StringNamePtr, ret: gdext.VariantPtr) -> bool {
    context = gdext.godot_context()
    self := cast(^UI_Bindings)instance
    key := string_name_to_odin(name)
    defer delete(key)

    if key == "widget" {
        gdext.get_variant_from_type_constructor(.Int)(ret, &self.kind)
        return true
    }

    for spec, field in ui.SPECS {
        if key == string(spec.property) {
            gdext.get_variant_from_type_constructor(.Node_Path)(ret, &self.paths[field])
            return true
        }
    }

    return false
}

@(private)
ui_bindings_properties :: proc "c" (instance: rawptr, count: ^u32) -> [^]gdext.PropertyInfo {
    context = gdext.godot_context()
    self := cast(^UI_Bindings)instance
    kind := ui.kind_valid(self.kind) ? ui.Kind(self.kind) : ui.Kind.Lobby
    count^ = u32(len(ui_properties[kind]))
    return raw_data(ui_properties[kind])
}

@(private)
ui_bindings_properties_free :: proc "c" (_: rawptr, _: ^gdext.PropertyInfo) {}

@(private)
ui_bindings_warnings :: proc "c" (instance: rawptr, _: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    report := ui_bindings_report(cast(^UI_Bindings)instance)
    result := gd.new_packed_string_array()

    if report.count > 0 {
        message := gd.new_string_odin(ui.text(&report))
        gd.packed_string_array_append(&result, message)
        gd.free_string(message)
    }

    ret_psa(ret, result)
}

@(private)
ui_bindings_virtual :: proc "c" (_: rawptr, name: gdext.StringNamePtr) -> rawptr {
    context = gdext.godot_context()
    return lookup_virtual([]Virtual_Entry{{"_get_configuration_warnings", ui_bindings_warnings}}, name)
}

// Callable copies may outlive the node or the signal's emission snapshot.
// Their state owns only a generation-checked ObjectID, never a native instance.
@(private)
UI_Changed_State :: struct {
    id: u64,
}

@(private)
ui_changed_instance :: proc(state: ^UI_Changed_State) -> ^UI_Bindings {
    object := gdext.object_get_instance_from_id(state.id)

    if object == nil {
        return nil
    }

    return cast(^UI_Bindings)gdext.object_get_instance_binding(object, gdext.library, &ui_binding_callbacks)
}

@(private)
ui_changed_free :: proc "c" (userdata: rawptr) {
    context = gdext.godot_context()
    free(cast(^UI_Changed_State)userdata)
}

@(private)
ui_changed_valid :: proc "c" (userdata: rawptr) -> bool {
    context = gdext.godot_context()
    return ui_changed_instance(cast(^UI_Changed_State)userdata) != nil
}

@(private)
ui_changed_argc :: proc "c" (_: rawptr, valid: ^bool) -> i64 {
    valid^ = true
    return 0
}

@(private)
ui_changed_call :: proc "c" (
    userdata: rawptr,
    _: [^]gdext.VariantPtr,
    argc: i64,
    ret: gdext.VariantPtr,
    error: ^gdext.CallError,
) {
    context = gdext.godot_context()

    if ret != nil {
        gdext.variant_new_nil(ret)
    }

    if error != nil {
        error^ = {}
    }

    self := ui_changed_instance(cast(^UI_Changed_State)userdata)

    if self == nil {
        if error != nil {
            error.error = .Instance_Is_Null
        }

        return
    }

    if argc != 0 {
        if error != nil {
            error.error = .Too_Many_Arguments
        }

        return
    }

    ui_bindings_refresh(self)
}

@(private)
ui_bindings_notification :: proc "c" (instance: rawptr, what: i32, _: bool) {
    context = gdext.godot_context()
    self := cast(^UI_Bindings)instance

    if what == 11 {
        ui_bindings_disconnect(self)
        return
    } // EXIT_TREE

    if what != 10 || !gd.engine_is_editor_hint(gd.singleton_engine()) {
        return
    } // ENTER_TREE

    self.tree = gd.node_get_tree(cast(gd.Node)self.object)
    state := new(UI_Changed_State)
    state.id = u64(gd.object_get_instance_id(cast(gd.Object)self.object))
    info := gdext.ExtensionCallableCustomInfo2 {
        callable_userdata       = state,
        free_func               = ui_changed_free,
        token                   = gdext.library,
        object_id               = u64(gd.object_get_instance_id(cast(gd.Object)self.object)),
        call_func               = ui_changed_call,
        is_valid_func           = ui_changed_valid,
        get_argument_count_func = ui_changed_argc,
    }
    gdext.callable_custom_create2(cast(gdext.TypePtr)&self.changed, &info)
    _ = gd.object_connect(cast(gd.Object)self.tree, gd.sname("tree_changed"), self.changed, 0)
    self.warning_changed = gd.callable_unbind(&self.changed, 1)
    _ = gd.object_connect(
        cast(gd.Object)self.tree,
        gd.sname("node_configuration_warning_changed"),
        self.warning_changed,
        0,
    )
    ui_bindings_refresh(self)
}

ui_bindings_register :: proc() {
    ui_bindings_name = gd.sname(ui.CLASS_NAME)
    ui_empty_name = gd.new_string_name_cstring("", false)
    ui_property_names[0] = gd.new_string_name_cstring("widget", false)
    ui_property_hints[0] = gd.new_string_cstring("Lobby,Chat,Scoreboard")

    for spec, field in ui.SPECS {
        index := int(field) + 1
        ui_property_names[index] = gd.new_string_name_cstring(spec.property, false)
        ui_property_hints[index] = gd.new_string_cstring(spec.class_name)
    }

    for kind in ui.Kind {
        append(
            &ui_properties[kind],
            gdext.PropertyInfo {
                class_name = &ui_empty_name,
                type = .Int,
                name = &ui_property_names[0],
                hint = 2,
                hint_string = &ui_property_hints[0],
                usage = 6,
            },
        )

        for spec, field in ui.SPECS {
            if spec.kind != kind {
                continue
            }

            index := int(field) + 1
            append(
                &ui_properties[kind],
                gdext.PropertyInfo {
                    class_name = &ui_empty_name,
                    type = .Node_Path,
                    name = &ui_property_names[index],
                    hint = 26,
                    hint_string = &ui_property_hints[index],
                    usage = 6,
                },
            )
        }
    }

    info := gdext.ExtensionClassCreationInfo2 {
        is_exposed                  = true,
        create_instance_func        = ui_bindings_create,
        free_instance_func          = ui_bindings_free,
        set_func                    = ui_bindings_set,
        get_func                    = ui_bindings_get,
        get_property_list_func      = ui_bindings_properties,
        free_property_list_func     = ui_bindings_properties_free,
        notification_func           = ui_bindings_notification,
        get_virtual_call_data_func  = ui_bindings_virtual,
        call_virtual_with_data_func = call_virtual_with_data,
    }
    register_extension_class(&ui_bindings_name, gd.node_name_ref(), &info)
}

ui_bindings_unregister :: proc() {
    for &properties in ui_properties {
        delete(properties)
    }

    for hint in ui_property_hints {
        gd.free_string(hint)
    }

    for name in ui_property_names {
        gd.free_string_name(name)
    }

    gd.free_string_name(ui_empty_name)
}
