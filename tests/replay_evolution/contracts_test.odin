package evolution_test

import "core:testing"
import "core:bytes"
import "core:strings"
import e "godot:replay/evolution"
import schema "schema_fixture"
import f "generated"

@(test)
frozen_contracts_and_unreviewed_scaffold_are_independent_and_exact :: proc(t: ^testing.T) {
    for tpe, index in ([2]typeid{schema.Source, schema.Target}) {
        expected := index == 0 ? #load("generated/source.json", []u8) : #load("generated/target.json", []u8)
        contract, report := e.contract(tpe, index == 0 ? schema.SOURCE_CONTENT : schema.TARGET_CONTENT)
        testing.expect(t, report.error == .None && bytes.equal(contract, expected))
        delete(contract)
    }
    for tpe, index in ([2]typeid{f.Source_Record, f.Target_Record}) {
        expected := index == 0 ? #load("generated/source.json", []u8) : #load("generated/target.json", []u8)
        contract, report := e.contract(tpe, index == 0 ? schema.SOURCE_CONTENT : schema.TARGET_CONTENT)
        testing.expect(t, report.error == .None && bytes.equal(contract, expected))
        delete(contract)
    }
    frozen, report := e.freeze(schema.Source, "evolution_generated_fixture", "Source_Record")
    defer delete(frozen)
    testing.expect(t, report.error == .None && frozen == #load("generated/source.odin", string))
    scaffold, generated := e.scaffold(
        schema.Source,
        schema.Target,
        "evolution_generated_fixture",
        "Source_Record",
        "Target_Record",
    )
    defer delete(scaffold)
    testing.expect(t, generated.error == .None && scaffold == #load("generated/conversion.odin", string))
    testing.expect(t, strings.contains(scaffold, "$.items[1].boost") && strings.contains(scaffold, "$.limit"))
    _, converted := f.convert(f.Source_Record{})
    testing.expect(t, !converted, "an unreviewed conversion must not silently invent defaults")
}

@(test)
reviewed_defaults_preserve_old_leaves_and_detect_accidental_changes :: proc(t: ^testing.T) {
    source := schema.Source {
        clock = 99,
        items = {{id = 1, hp = 10}, {id = 2, hp = 20}},
    }
    defaults := schema.Target {
        items = {{boost = 8}, {boost = 6}},
        limit = 9,
    }
    added := schema.ADDED
    current, report := e.copy_preserved(source, defaults, added[:])
    testing.expect(t, report.error == .None && e.verify_preserved(source, current, added[:]).error == .None)
    testing.expect(t, current.clock == 99 && current.items[0].id == 1 && current.items[1].hp == 20)
    testing.expect(t, current.items[0].boost == 8 && current.items[1].boost == 6 && current.limit == 9)
    current.items[0].hp += 1
    testing.expect(t, e.verify_preserved(source, current, added[:]).error != .None)
}
