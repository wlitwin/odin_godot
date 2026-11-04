package main

import "core:fmt"
import "core:os"
import e "godot:replay/evolution"
import d "godot:replay/definitions"
import frozen50 "../../shared/revisions/content50"
import upgrade "../../shared/upgrade"

main :: proc() {
    if len(os.args) != 2 {
        fmt.eprintln("usage: revision OUTPUT_DIRECTORY (must already exist)")
        os.exit(1)
    }

    directory := os.args[1]

    for t, i in ([2]typeid{upgrade.Catalog_49, frozen50.Catalog_50}) {
        name := fmt.tprintf("Catalog_%d", 49 + i)
        source, report := e.freeze(t, "scrapyard_revision_fixture", name)

        if report.error != .None {
            fail(report)
        }

        defer delete(source)
        manifest: []u8
        manifest, report = e.contract(t, upgrade.CONTENT_49 + u64(i))

        if report.error != .None {
            fail(report)
        }

        defer delete(manifest)

        if os.write_entire_file(fmt.tprintf("%s/catalog%d.odin", directory, 49 + i), transmute([]u8)source) != nil ||
           os.write_entire_file(fmt.tprintf("%s/catalog%d.json", directory, 49 + i), manifest) != nil {
            panic("write revision output")
        }
    }

    source, report := e.scaffold(
        upgrade.Catalog_49,
        frozen50.Catalog_50,
        "scrapyard_revision_fixture",
        "Catalog_49",
        "Catalog_50",
    )

    if report.error != .None {
        fail(report)
    }

    defer delete(source)

    if os.write_entire_file(fmt.tprintf("%s/conversion.odin", directory), transmute([]u8)source) != nil {
        panic("write conversion scaffold")
    }

    fmt.println("SCRAPYARD_REVISIONS_OK")
}

fail :: proc(report: d.Report) {
    report := report
    fmt.eprintln(d.report_path(&report), d.report_message(&report))
    os.exit(1)
}
