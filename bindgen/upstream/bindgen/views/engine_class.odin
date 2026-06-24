#+feature dynamic-literals
package views

import g "../graph"
import "../names"
import "core:fmt"
import "core:mem"
import "core:strings"

Engine_Class :: struct {
    imports:          map[string]Import,
    self:             string,
    name:             string,
    godot_name:       string,
    snake_name:       string,
    cast_on_new: bool,
    enums:            []Enum,
    bit_fields:       []Bit_Field,
    file_constants:   []File_Constant,
    static_methods:   []Method,
    instance_methods: []Method,
    properties:       []Property,
}

@(private = "file")
default_imports := []Import{{name = "__bindgen_gde", path = "godot:gdext"}}

_constant_constructor :: proc(initializer: g.Initialize_By_Constructor, current_package: string) -> (result: string) {
    sb := strings.builder_make()

    fmt.sbprint(&sb, resolve_qualified_type(initializer.type, current_package))
    fmt.sbprint(&sb, "{ ")
    for arg in initializer.arg_values {
        fmt.sbprint(&sb, arg)
        fmt.sbprint(&sb, ", ")
    }
    fmt.sbprint(&sb, " }")

    result = strings.clone(strings.to_string(sb))
    strings.builder_destroy(&sb)
    return
}

engine_class :: proc(class: ^g.Engine_Class, allocator: mem.Allocator) -> (engine_class: Engine_Class, render: bool) {
    context.allocator = allocator

    static_method_count := 0
    instance_method_count := 0
    for method in class.methods {
        if method.static {
            static_method_count += 1
        } else {
            instance_method_count += 1
        }
    }

    engine_class = Engine_Class {
        name             = names.clone_string(class.odin_name),
        godot_name       = names.clone_string(class.godot_name),
        snake_name       = names.clone_string(class.snake_name),
        cast_on_new = class.refcounted,
        enums            = make([]Enum, len(class.enums)),
        bit_fields       = make([]Bit_Field, len(class.bit_fields)),
        file_constants   = make([]File_Constant, len(class.constants)),
        static_methods   = make([]Method, static_method_count),
        instance_methods = make([]Method, instance_method_count),
    }

    for default_import in default_imports {
        engine_class.imports[default_import.name] = default_import
    }

    package_name := fmt.aprintf("godot:%v/%v", g.to_string(class.api_type), engine_class.snake_name)
    // package_name := fmt.aprintf("godot:%v", g.to_string(class.api_type))
    // engine_class.derives = resolve_qualified_type(class.inherits, package_name)

    ensure_imports(&engine_class.imports, class, package_name)
    engine_class.self = resolve_qualified_type(class, package_name)

    for class_enum, enum_idx in class.enums {
        new_enum := Enum {
            name   = names.clone_string(class_enum.odin_name),
            values = make([]Enum_Value, len(class_enum.values)),
        }

        for value, value_idx in class_enum.values {
            new_enum.values[value_idx] = Enum_Value {
                name  = names.clone_string(value.odin_name),
                value = strings.clone(value.value),
            }
        }
        new_enum.backing = enum_backing(new_enum.values, false)

        engine_class.enums[enum_idx] = new_enum
    }

    for class_bit_field, bit_field_idx in class.bit_fields {
        new_bit_field := Bit_Field {
            name    = names.clone_string(class_bit_field.odin_name),
            backing = "i64",
            values  = make([]Enum_Value, len(class_bit_field.values)),
        }

        for value, value_idx in class_bit_field.values {
            new_bit_field.values[value_idx] = Enum_Value {
                name  = names.clone_string(value.odin_name),
                value = strings.clone(value.value),
            }
        }

        engine_class.bit_fields[bit_field_idx] = new_bit_field
    }

    for constant, constant_idx in class.constants {
        file_constant := File_Constant {
            name = names.clone_string(constant.name),
            type = resolve_qualified_type(constant.type, package_name),
        }

        switch v in constant.initializer {
        case string:
            file_constant.value = strings.clone(v)
        case g.Initialize_By_Constructor:
            // TODO: some types can be file constants, while others require initialization
            file_constant.value = _constant_constructor(v, package_name)
        }

        engine_class.file_constants[constant_idx] = file_constant
    }

    static_method_idx := 0
    instance_method_idx := 0
    for class_method, method_idx in class.methods {
        method := Method {
            name        = strings.clone(class_method.name),
            hash        = class_method.hash,
            args        = make([]Method_Arg, len(class_method.args)),
            vararg      = class_method.vararg,
            return_type = nil,
        }

        if class_method.return_type != nil {
            resolved_return := resolve_qualified_type(class_method.return_type, package_name) // TODO: other package modes
            method.return_type = resolved_return
            method.ret_is_variant = resolved_return == "Variant"
            ensure_imports(&engine_class.imports, class_method.return_type, package_name) // TODO: other package modes
        }

        for class_method_arg, arg_idx in class_method.args {
            method.args[arg_idx] = Method_Arg {
                name = strings.clone(class_method_arg.name),
                type = resolve_qualified_type(class_method_arg.type, package_name), // TODO: other package modes
                // TODO: defaults?
            }

            ensure_imports(&engine_class.imports, class_method_arg.type, package_name) // TODO: other package modes
        }

        if class_method.static {
            engine_class.static_methods[static_method_idx] = method
            static_method_idx += 1
        } else {
            engine_class.instance_methods[instance_method_idx] = method
            instance_method_idx += 1
        }
    }

    // Typed property accessors. We only generate accessors for getter/setter
    // methods that are defined on *this* class (so the delegated proc
    // `<snake>_<method>` exists in this package), and we skip emitting one whose
    // name (`<snake>_get_<prop>` / `<snake>_set_<prop>`) would collide with an
    // existing method proc -- in that collision case the method already serves
    // as the accessor, so `<snake>_get_<prop>` still resolves for consumers.
    methods_by_name := make(map[string]^g.Method)
    defer delete(methods_by_name)
    for &class_method in class.methods {
        methods_by_name[class_method.name] = &class_method
    }

    properties := make([dynamic]Property)
    for property in class.properties {
        getter_method, getter_ok := methods_by_name[property.getter]
        if !getter_ok || getter_method.static || getter_method.return_type == nil {
            // Getter is inherited / static / returns nothing -- can't wrap safely.
            continue
        }

        index, has_index := property.index.?

        prop := Property {
            name      = strings.clone(property.name),
            get_name  = fmt.aprintf("%v_get_%v", engine_class.snake_name, property.name),
            get_call  = fmt.aprintf("%v_%v", engine_class.snake_name, property.getter),
            get_type  = resolve_qualified_type(getter_method.return_type, package_name),
            has_index = has_index,
            index     = index,
        }
        // collision: a method literally named `get_<prop>` already emits `<snake>_get_<prop>`.
        _, get_collides := methods_by_name[fmt.aprintf("get_%v", property.name)]
        prop.emit_get = !get_collides

        if has_index && len(getter_method.args) > 0 {
            prop.index_type = resolve_qualified_type(getter_method.args[0].type, package_name)
        }

        if setter_name, has_setter := property.setter.?; has_setter {
            if setter_method, setter_ok := methods_by_name[setter_name];
               setter_ok && !setter_method.static && len(setter_method.args) > 0 {
                _, set_collides := methods_by_name[fmt.aprintf("set_%v", property.name)]
                prop.set_name = fmt.aprintf("%v_set_%v", engine_class.snake_name, property.name)
                prop.set_call = fmt.aprintf("%v_%v", engine_class.snake_name, setter_name)
                // The value argument is the last parameter (index, if any, is first).
                prop.set_type = resolve_qualified_type(
                    setter_method.args[len(setter_method.args) - 1].type,
                    package_name,
                )
                prop.emit_set = !set_collides
                if has_index && prop.index_type == "" && len(setter_method.args) > 1 {
                    prop.index_type = resolve_qualified_type(setter_method.args[0].type, package_name)
                }
            }
        }

        if prop.emit_get || prop.emit_set {
            append(&properties, prop)
        }
    }
    engine_class.properties = properties[:]

    render = true
    return
}

/*
    Copyright 2025 Dresses Digital

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
