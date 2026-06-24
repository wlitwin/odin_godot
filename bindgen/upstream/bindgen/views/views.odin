package views

import "core:strconv"

Import :: struct {
    name: string,
    path: string,
}

Enum :: struct {
    name:    string,
    // Odin enum backing type, e.g. "int" or "i64". Widened to "i64" for
    // bitfields and any enum with a value outside the signed-32-bit range, so
    // the generated code compiles where `int` is 32-bit (wasm32).
    backing: string,
    values:  []Enum_Value,
}

Enum_Value :: struct {
    name:  string,
    value: string,
}

Bit_Field :: struct {
    name:    string,
    backing: string,
    values:  []Enum_Value,
}

// Picks the enum backing type. `force_wide` is set for bitfields (flag enums
// whose combined values can need the high bits). Otherwise an enum is widened
// only if one of its declared values falls outside the i32 range.
enum_backing :: proc(values: []Enum_Value, force_wide: bool) -> string {
    if force_wide {
        return "i64"
    }
    for v in values {
        n, ok := strconv.parse_i64(v.value)
        if ok && (n > 0x7fff_ffff || n < -0x8000_0000) {
            return "i64"
        }
    }
    return "int"
}

File_Constant :: struct {
    name:  string,
    type:  string,
    value: string,
}

Init_Constant :: struct {
    name:        string,
    type:        string,
    constructor: string,
    args:        []string,
}

Method :: struct {
    name:        string,
    vararg:      bool,
    hash:        i64,
    return_type: Maybe(string),
    // For vararg methods (which go through object_method_bind_call and return a
    // Variant): true when the declared return type is itself `Variant` (pass it
    // straight through), false when it must be converted (e.g. `Error`).
    ret_is_variant: bool,
    args:        []Method_Arg,
}

Method_Arg :: struct {
    name: string,
    type: string,
}

// A typed property accessor generated from a class `properties` entry. The
// getter/setter delegate to the already-generated getter/setter method procs
// (`get_call`/`set_call`), forwarding the (optional) index argument. `emit_get`
// / `emit_set` are false when an identically-named method proc already exists
// (so `<class>_get_<prop>` / `<class>_set_<prop>` is never defined twice).
Property :: struct {
    name:       string,
    emit_get:   bool,
    get_name:   string, // proc to define, e.g. node2d_get_position / node_get_visible
    get_call:   string, // proc to call,   e.g. node2d_get_position / node_is_visible
    get_type:   string, // getter return type (resolved)
    emit_set:   bool,
    set_name:   string,
    set_call:   string,
    set_type:   string, // setter value-argument type (resolved)
    has_index:  bool,
    index:      i64,
    index_type: string, // resolved type of the leading index argument (often an enum)
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
