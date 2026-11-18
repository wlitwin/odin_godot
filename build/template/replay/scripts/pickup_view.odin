//gd:extends Node2D
//gd:class PickupView
package scripts

import gd "godot:godot"
import d "godot:replay/definitions"
import game "../shared/game"

PickupView :: struct {
    owner: gd.Node2d,
    definition: ^gd.Resource `gd:"export,resource=PickupDef"`,
    show_reach: bool `gd:"export"`,
    guide: gd.Polygon2d `gd:"onready=Reach"`,
    rules: game.Pickup_Rules,
    report: d.Report,
    has_valid: bool,
}

pickup_view_ready :: proc(self: ^PickupView) {_ = pickup_view_refresh(self)}

@(gd_method)
pickup_view_refresh :: proc(self: ^PickupView) -> bool {
    if self.guide == nil {
        self.report = d.problem(.Invalid, "Reach", "Pickup scene requires a Reach Polygon2D child.")
        return false
    }
    rules, report := pickup_rules(cast(gd.Resource)self.definition)
    self.report = report
    if report.error == .None {
        self.rules = rules
        self.has_valid = true
        gd.node2d_set_scale(self.guide, {f32(rules.reach), 1})
    }
    gd.canvas_item_set_visible(self.guide, self.show_reach && self.has_valid)
    return report.error == .None
}

@(gd_method)
pickup_view_validation_issue :: proc(self: ^PickupView) -> string {return d.report_message(&self.report)}

@(gd_method)
pickup_view_validation_path :: proc(self: ^PickupView) -> string {return d.report_path(&self.report)}

@(gd_method)
pickup_view_validation_source :: proc(self: ^PickupView) -> string {
    if d.report_path(&self.report) == "Reach" {return "res://entities/pickup.tscn"}
    if self.definition == nil {return "res://entities/pickup.tscn"}
    path := gd.resource_get_path(cast(gd.Resource)self.definition)
    defer gd.free_string(path)
    return gd.gd_string_to_odin(path)
}

@(gd_method)
pickup_view_preview_reach :: proc(self: ^PickupView) -> gd.Int {return gd.Int(self.rules.reach)}
