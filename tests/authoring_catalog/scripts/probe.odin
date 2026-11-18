//gd:extends Node
//gd:class CatalogProbe
package catalog_probe

import "core:strings"
import "core:fmt"
import a "godot:authoring"
import gd "godot:godot"

CatalogProbe :: struct {
    owner: gd.Node,
}

catalog_probe_ready :: proc(self: ^CatalogProbe) {
    defer gd.scene_tree_quit(gd.get_tree(self.owner), 0)
    good: a.Catalog(CatalogEntry)
    defer a.catalog_destroy(&good)
    report := a.catalog_load(&good, "res://good", 6)
    assert(report.error == .None, a.report_message(&report))
    assert(len(good.entries) == 2 && good.high_water == 6)
    assert(good.entries[0].id == 2 && good.entries[1].id == 5)
    assert(good.entries[0].script.id == 2 && good.entries[1].script.id == 5)
    assert(good.entries[0].path == "res://good/a.tres")
    assert(good.entries[1].path == "res://good/a.tres.extra.tres")
    // Refuse accidental reinitialization without losing the admitted batch.
    report = a.catalog_load(&good, "res://duplicate", 6)
    assert(report.error == .Invalid && len(good.entries) == 2 && good.entries[1].script.id == 5)

    ordered: a.Catalog(CatalogEntry)
    defer a.catalog_destroy(&ordered)
    report = a.catalog_load(&ordered, "res://ordered", 2, id_field = "")
    assert(report.error == .None, a.report_message(&report))
    assert(ordered.high_water == 2 && ordered.entries[0].script.id == 2 && ordered.entries[1].script.id == 5)
    assert(ordered.entries[0].id == 0 && ordered.entries[1].id == 1)

    cases := []struct {
        directory:         string,
        capacity, minimum: int,
        error:             a.Error,
    } {
        {"duplicate", 6, 0, .Duplicate},
        {"wrong", 6, 0, .Invalid},
        {"negative", 6, 0, .Invalid},
        {"reserved", 6, 1, .Invalid},
        {"good", 2, 0, .Invalid}, // Valid file count, out-of-range stable ID.
        {"good", 1, 0, .Capacity},
        {"missing", 6, 0, .Missing},
    }
    for check in cases {
        candidate: a.Catalog(CatalogEntry)
        report = a.catalog_load(&candidate, fmt.tprintf("res://%s", check.directory), check.capacity, check.minimum)
        assert(report.error == check.error, a.report_message(&report))
        assert(len(candidate.entries) == 0 && len(candidate.batch.resources) == 0)
        a.catalog_destroy(&candidate)
        assert(len(a.report_path(&report)) > 0 && len(a.report_message(&report)) > 0)
        if check.error == .Duplicate {
            assert(strings.contains(a.report_message(&report), "first.tres"))
            assert(strings.contains(a.report_message(&report), "second.tres"))
        }
    }
    gd.print_str("AUTHORING_CATALOG_OK")
}
