package main

import "core:fmt"
import "core:os"
import e "godot:replay/evolution"
import d "godot:replay/definitions"
import game "../../shared/game"
import content "../../shared/content"

main :: proc() {
    if len(os.args) != 2 {
        fmt.eprintln("usage: revision OUTPUT_DIRECTORY (must already exist)")
        os.exit(1)
    }

    directory := os.args[1]

    names := [4]string{"Catalog", "World", "Control", "Action"}
    stems := [4]string{"catalog", "world", "control", "action"}
    for t, i in ([4]typeid{content.Catalog, game.World, game.Control, game.Action}) {
        source, report := e.freeze(t, "scrapyard_current_contract", names[i])
        if report.error != .None {fail(report)}
        defer delete(source)
        manifest, result := e.contract(t, i == 0 ? content.SEMANTIC : game.CONTENT)
        if result.error != .None {fail(result)}
        defer delete(manifest)
        if os.write_entire_file(fmt.tprintf("%s/%s.odin", directory, stems[i]), transmute([]u8)source) != nil ||
           os.write_entire_file(fmt.tprintf("%s/%s.json", directory, stems[i]), manifest) != nil {
            panic("write current contract")
        }
    }

    fmt.println("SCRAPYARD_REVISIONS_OK")
}

fail :: proc(report: d.Report) {
    report := report
    fmt.eprintln(d.report_path(&report), d.report_message(&report))
    os.exit(1)
}
