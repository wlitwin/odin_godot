//gd:extends Line2D
//gd:class ScrapTelegraphView
package scrap_views

import gd "godot:godot"

// Reusable child scene: points, width, color and offset belong to its .tscn.
ScrapTelegraphView :: struct {
    owner: gd.Line2d,
    authored_scale: gd.Vector2,
    ready: bool,
}

scrap_telegraph_view_ready :: proc(self: ^ScrapTelegraphView) {
    self.authored_scale = gd.node2d_get_scale(self.owner)
    self.ready = true
}

telegraph_present :: proc(self: ^ScrapTelegraphView, active: bool, fraction: f32, radius: f32 = 180) {
    if self == nil || !self.ready {
        return
    }

    gd.canvas_item_set_visible(self.owner, active)
    gd.node2d_set_scale(self.owner, self.authored_scale * max(fraction, .02) * (radius / 180))
}
