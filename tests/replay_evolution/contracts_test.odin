package evolution_test
import "core:testing"
import "core:bytes"
import "core:strings"
import e "godot:replay/evolution"
import f "generated"
import old "../../examples/replay_scrapyard/shared/revisions/content49"
import content "../../examples/replay_scrapyard/shared/content"
import frozen50 "../../examples/replay_scrapyard/shared/revisions/content50"
import upgrade "../../examples/replay_scrapyard/shared/upgrade"

@(test)
frozen_contracts_and_generated_scaffold_are_reviewable :: proc(t: ^testing.T) {
    contract, report := e.contract(old.Catalog_49, upgrade.CONTENT_49)
    defer delete(contract)
    testing.expect(
        t,
        report.error == .None &&
        bytes.equal(contract, #load("../../examples/replay_scrapyard/shared/revisions/content49/contract.json", []u8)),
    )
    current, result := e.contract(frozen50.Catalog_50, upgrade.CONTENT_49 + 1)
    defer delete(current)
    testing.expect(t, result.error == .None && bytes.equal(current, #load("generated/contract50.json", []u8)))
    frozen, ok := e.contract(f.Catalog_50, upgrade.CONTENT_49 + 1)
    defer delete(frozen)
    testing.expect(t, ok.error == .None && bytes.equal(frozen, current))
    _, converted := f.convert(f.Catalog_49{})
    testing.expect(t, !converted, "generated conversion must fail until defaults are reviewed")
    source, generated := e.freeze(old.Catalog_49, "frozen", "Catalog_49")
    defer delete(source)
    testing.expect(
        t,
        generated.error == .None &&
        source == #load("../../examples/replay_scrapyard/shared/revisions/content49/catalog.odin", string),
    )
    scaffold, generated_report := e.scaffold(
        old.Catalog_49,
        frozen50.Catalog_50,
        "scrapyard_revision_fixture",
        "Catalog_49",
        "Catalog_50",
    )
    defer delete(scaffold)
    testing.expect(
        t,
        generated_report.error == .None &&
        strings.contains(scaffold, "$.mobs[7].pulse.damage") &&
        scaffold == #load("generated/conversion.odin", string),
    )
}

@(test)
actual_old_catalog_conversion_preserves_every_old_leaf :: proc(t: ^testing.T) {
    source := upgrade.stock_49()
    current := upgrade.catalog_current(source)
    paths := upgrade.pulse_additions()
    testing.expect(t, e.verify_preserved(source, upgrade.catalog_50(current), paths[:]).error == .None)

    for mob in current.mobs {
        testing.expect_value(t, mob.pulse, content.Pulse_Def{})
    }

    current.guns[0].damage += 1
    testing.expect(t, e.verify_preserved(source, upgrade.catalog_50(current), paths[:]).error != .None)
}
