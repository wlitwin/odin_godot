package hello

import "godot:gdext"
import "godot:godot"
import "godot:libgd/classdb"

// Static String_Names for our class, signal, and the Object::emit_signal bind.
@(private = "file")
hello_class_name: godot.String_Name
@(private = "file")
value_changed_name := godot.String_Name{}
@(private = "file")
emit_signal_name := godot.String_Name{}

// The Odin-authored class. Extends RefCounted so GDScript owns the lifetime
// (no manual free) and node-tree setup is unnecessary.
OdinHello :: struct {
    value:  godot.Int,
    object: ^godot.Object,
}

// ---- Bound custom method: GDScript `obj.add(2, 3)` -> 5 ----
add :: proc "contextless" (self: ^OdinHello, a: godot.Int, b: godot.Int) -> godot.Int {
    return a + b
}

// ---- Property get/set (round-trips through GDScript) ----
get_value :: proc "contextless" (self: ^OdinHello) -> godot.Int {
    return self.value
}

set_value :: proc "contextless" (self: ^OdinHello, value: godot.Int) {
    self.value = value
    // Emit the signal whenever the property changes so GDScript can observe it.
    emit_value_changed(self, value)
}

// ---- Signal emission via the Object::emit_signal method bind ----
emit_value_changed :: proc "contextless" (self: ^OdinHello, value: godot.Int) {
    object_emit_signal := gdext.classdb_get_method_bind(
        godot.object_name_ref(),
        &emit_signal_name,
        4047867050,
    )

    value := value
    signal_name_argument := godot.variant_from(&value_changed_name)
    value_argument := godot.variant_from(&value)

    args := [2]gdext.VariantPtr{&signal_name_argument, &value_argument}
    ret := godot.Variant{}
    gdext.object_method_bind_call(object_emit_signal, self.object, &args[0], len(args), &ret, nil)
    gdext.variant_destroy(&ret)
}

// ---- Instance create / free ----
hello_binding_callbacks := gdext.InstanceBindingCallbacks {
    create    = nil,
    free      = nil,
    reference = nil,
}

create_instance :: proc "c" (class_user_data: rawptr) -> gdext.ObjectPtr {
    context = gdext.godot_context()

    object := gdext.classdb_construct_object(godot.ref_counted_name_ref())

    self := new_clone(OdinHello{object = cast(^godot.Object)object, value = 0})

    gdext.object_set_instance(object, &hello_class_name, self)
    gdext.object_set_instance_binding(object, gdext.library, self, &hello_binding_callbacks)

    return object
}

free_instance :: proc "c" (class_user_data: rawptr, instance: gdext.ExtensionClassInstancePtr) {
    context = gdext.godot_context()

    if instance == nil {
        return
    }

    self := cast(^OdinHello)instance
    free(self)
}

// ---- Class + member registration ----
hello_class_register :: proc() {
    gdext.string_name_new_with_latin1_chars(&hello_class_name, "OdinHello", true)
    gdext.string_name_new_with_latin1_chars(&value_changed_name, "value_changed", true)
    gdext.string_name_new_with_latin1_chars(&emit_signal_name, "emit_signal", true)

    class_info := gdext.ExtensionClassCreationInfo2 {
        is_virtual                  = false,
        is_abstract                 = false,
        is_exposed                  = true,
        create_instance_func        = create_instance,
        free_instance_func          = free_instance,
        class_userdata              = nil,
    }

    gdext.classdb_register_extension_class2(
        gdext.library,
        &hello_class_name,
        godot.ref_counted_name_ref(),
        &class_info,
    )

    // Custom callable method: add(a, b) -> int
    add_name := godot.new_string_name_cstring("add", true)
    a_name := godot.new_string_name_cstring("a", true)
    b_name := godot.new_string_name_cstring("b", true)
    classdb.bind_returning_method_2_args(&hello_class_name, &add_name, add, &a_name, &b_name)

    // Property "value" with get_value / set_value
    value_name := godot.new_string_name_cstring("value", true)
    get_value_name := godot.new_string_name_cstring("get_value", true)
    set_value_name := godot.new_string_name_cstring("set_value", true)
    classdb.bind_property_and_methods(
        &hello_class_name,
        &value_name,
        &get_value_name,
        &set_value_name,
        get_value,
        set_value,
    )

    // Signal "value_changed(value: int)"
    classdb.bind_signal(
        &hello_class_name,
        &value_changed_name,
        classdb.Signal_Arg{name = &value_changed_name, type = .Int},
    )
}
