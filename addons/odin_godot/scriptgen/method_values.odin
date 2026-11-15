package scriptgen

import "core:fmt"
import "core:odin/ast"
import "core:strings"

// A bare method preserves the original boundary: owning Godot builtin argument
// copies go to the callee; Godot returns are borrowed. New code can state a
// different contract without invalidating existing methods returning fields.
method_ownership :: proc(m: ^Method_Info, vd: ^ast.Value_Decl, loc: Loc) -> bool {
    for attr in vd.attributes {
        for elem in attr.elems {
            fv, field := elem.derived.(^ast.Field_Value)

            if !field {
                continue
            }

            ident, named := fv.field.derived.(^ast.Ident)

            if !named || ident.name != "gd_method" {
                continue
            }

            lit, literal := fv.value.derived.(^ast.Basic_Lit)

            if !literal || len(lit.tok.text) < 2 || (lit.tok.text[0] != '"' && lit.tok.text[0] != '`') {
                error_at(loc, "method %s: gd_method options must be a string literal", m.proc_name)
                return false
            }
        }
    }

    config, present := attr_value(vd, "gd_method")

    if !present {
        return true
    }

    for raw in strings.split(config, ",") {
        switch strings.trim_space(raw) {
        case "":
        case "borrowed_args":
            m.borrowed_args = true
        case "owned_return":
            m.owned_return = true
        case:
            error_at(
                loc,
                "method %s: unknown gd_method option %q; use borrowed_args and/or owned_return",
                m.proc_name,
                raw,
            )
            return false
        }
    }

    if !m.owned_return {
        return true
    }

    if m.ret_type != "string" && method_builtin_destructor(m.ret.enum_name) {
        return true
    }

    if m.ret.enum_name == ".Object" {
        name := strings.trim_prefix(strings.trim_prefix(m.ret_type, "gd."), "godot.")
        covers, known := class_handle_covers("RefCounted", name)

        if known && covers {
            m.return_refcounted = true
            return true
        }
    }

    error_at(
        loc,
        "method %s: owned_return requires an owning Godot builtin value or a declared RefCounted subclass; native string returns are already copied",
        m.proc_name,
    )
    return false
}

method_builtin_destructor :: proc(variant: string) -> bool {
    switch variant {
    case ".String",
         ".String_Name",
         ".Node_Path",
         ".Callable",
         ".Signal",
         ".Array",
         ".Dictionary",
         ".Packed_Byte_Array",
         ".Packed_Int32_Array",
         ".Packed_Int64_Array",
         ".Packed_Float32_Array",
         ".Packed_Float64_Array",
         ".Packed_String_Array",
         ".Packed_Vector2_Array",
         ".Packed_Vector3_Array",
         ".Packed_Color_Array",
         ".Packed_Vector4_Array":
        return true
    }

    return false
}

// Emit a cached destructor and a deferred release for exactly one owned copy.
emit_method_release :: proc(b: ^strings.Builder, variant, variable: string) {
    fmt.sbprintf(b, "\t@(static) _destroy%s: gdext.PtrDestructor\n", variable)
    fmt.sbprintf(
        b,
        "\tif _destroy%s == nil {{_destroy%s = gdext.variant_get_ptr_destructor(%s)}}\n",
        variable,
        variable,
        variant,
    )
    fmt.sbprintf(b, "\tdefer _destroy%s(&%s)\n", variable, variable)
}
