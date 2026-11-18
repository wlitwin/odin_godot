package replay_godot_scene

import a "godot:authoring"
import gd "godot:godot"
import d "godot:replay/definitions"

// Shared authoring ownership, adapted to Replay's definition diagnostics.
Resource_Batch :: a.Resource_Batch
resource_batch_destroy :: a.resource_batch_destroy

resource_batch_load :: proc(
    batch: ^Resource_Batch,
    directory: string,
    capacity: int,
    allocator := context.allocator,
) -> d.Report {
    return authoring_report(a.resource_batch_load(batch, directory, capacity, allocator))
}

resource_script :: proc(resource: gd.Resource, $Script: typeid, path: string) -> (^Script, d.Report) {
    script, report := a.resource_script(resource, Script, path)
    return script, authoring_report(report)
}

authoring_report :: proc(report: a.Report) -> d.Report {
    if report.error == .None {return {}}
    report := report
    error: d.Error = .Invalid
    if report.error == .Missing {error = .Missing}
    if report.error == .Capacity {error = .Capacity}
    return d.problem(error, a.report_path(&report), a.report_message(&report))
}

bake_fields :: proc(
    ctx: ^Bake_Context,
    source: ^$Source,
    destination: ^$Destination,
    fields: []a.Field,
    path: string,
) {
    if ctx.report.error != .None {return}
    ctx.report = authoring_report(a.map_fields(source, destination, fields, path))
}
