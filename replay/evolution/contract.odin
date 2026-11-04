package replay_evolution
import "core:encoding/json"
import "core:fmt"
import "core:strings"
import sc "godot:replay/schema"
import d "godot:replay/definitions"

Contract_Field :: struct {
    path:                        string,
    kind:                        sc.Kind,
    width, wire_offset:          int,
    bit_mask:                    u64,
    enum_names:                  []string,
    enum_values:                 []i64,
    enum_signed, authority_only: bool,
}

Contract :: struct {
    format:           u32,
    semantic, schema: u64,
    wire_bytes:       int,
    canonical:        string,
    fields:           []Contract_Field,
}

// Caller owns the returned JSON bytes. Compiler-owned enum names are consumed
// synchronously; no reflected/native offsets appear in the revision contract.
contract :: proc(t: typeid, semantic: u64) -> ([]u8, d.Report) {
    schema: sc.Schema
    defer sc.destroy(&schema)

    if report := sc.init(&schema, t); report.error != .None {
        return nil, d.problem(.Invalid, report.path, "unsupported revision schema")
    }

    if semantic == 0 || len(schema.unions) > 0 {
        return nil, d.problem(
            .Invalid,
            "$",
            "semantic contract required; unions require an authored revision manifest",
        )
    }

    fields := make([]Contract_Field, len(schema.fields))
    defer delete(fields)

    defer for field in fields {
        delete(field.enum_values)
    }

    for field, i in schema.fields {
        values := make([]i64, len(field.enum_values))

        for value, j in field.enum_values {
            values[j] = i64(value)
        }

        fields[i] = {
            field.path,
            field.kind,
            field.width,
            field.wire_offset,
            field.bit_mask,
            field.enum_names,
            values,
            field.enum_signed,
            field.authority_only,
        }
    }

    bytes, error := json.marshal(
        Contract{1, semantic, schema.fingerprint, schema.wire_size, string(schema.canonical[:]), fields},
    )

    if error != nil {
        delete(bytes)
        return nil, d.problem(.Invalid, "$", "could not serialize revision contract")
    }

    return bytes, {}
}

// Review scaffold: deliberately returns failure until the author supplies target
// defaults and changes the review flag. Output references frozen types generated
// beside it; no live game type dependency can silently alter the old schema.
scaffold :: proc(old, new: typeid, package_name, old_name, new_name: string) -> (string, d.Report) {
    if !identifier(package_name) || !identifier(old_name) || !identifier(new_name) {
        return "", d.problem(.Invalid, "$", "invalid generated identifier")
    }

    a, b: sc.Schema
    defer sc.destroy(&a)
    defer sc.destroy(&b)

    if sc.init(&a, old).error != .None ||
       sc.init(&b, new).error != .None ||
       !additive_shape(type_info_of(old), 0) ||
       !additive_shape(type_info_of(new), 0) {
        return "", d.problem(.Invalid, "$", "unsupported conversion schemas")
    }

    for field in a.fields {
        dest, found := find(&b, field.path)

        if !found || !compatible(field, dest) {
            return "", d.problem(.Invalid, field.path, "changed/removed field needs custom conversion code")
        }
    }

    out: strings.Builder
    defer strings.builder_destroy(&out)
    fmt.sbprintf(
        &out,
        "package %s\nimport e \"godot:replay/evolution\"\n\nconvert :: proc(old:%s)->(%s,bool)",
        package_name,
        old_name,
        new_name,
    )
    strings.write_string(
        &out,
        " {\n    // TODO: choose and review every new default below.\n    defaults_reviewed := false\n    if !defaults_reviewed {return {},false}\n",
    )
    fmt.sbprintf(&out, "    defaults:%s\n", new_name)
    strings.write_string(&out, "    added:=[]string{\n")

    for field in b.fields {
        if _, found := find(&a, field.path); !found {
            fmt.sbprintf(&out, "        %q, // TODO: defaults%s\n", field.path, strings.trim_prefix(field.path, "$"))
        }
    }

    strings.write_string(
        &out,
        "    }\n    value,report:=e.copy_preserved(old,defaults,added)\n    return value,report.error==.None\n}\n",
    )
    return strings.clone(strings.to_string(out)), {}
}
