package replay_quickdraw

import gd "godot:godot"
import flow "../shared/feedback"
import scenegd "godot:replay/godot/scene"

feedback_prepare :: proc(self: ^ReplayQuickdraw, dt: f64) {
    f := &self.feedback[0]
    flow.advance(f, dt)

    if !self.session.ready {
        flow.clear(f)
        return
    }

    epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
    baseline := self.session.authority ? self.session.server.timeline.head : self.session.client.journal.baseline

    if self.session.authority {
        for c in self.session.changes[:self.session.change_count] {
            if c.kind == .Begin && c.occurrence.id.epoch == epoch && c.occurrence.id.tick > 0 {
                baseline = min(baseline, c.occurrence.id.tick - 1)
            }
        }
    }

    // Authority's advancing head is not a new baseline every frame.
    if f.scoped && f.epoch == epoch && self.session.authority {
        baseline = f.ledger.floor
    }

    frontier :=
        self.session.authority ? self.session.server.timeline.head : min(self.session.client.journal.confirmed, self.session.client.journal.watch_tick)
    reset := self.session.authority ? u64(0) : self.session.client.view_reset

    if !flow.prepare(f, epoch, baseline, frontier, reset) {
        flow.clear(f)
    }
}

feedback_rings :: proc(self: ^ReplayQuickdraw) {
    colors := [4]gd.Color{{0.35, 0.65, 1, 1}, {1, 0.62, 0.2, 1}, {0.5, 0.9, 0.4, 1}, {0.9, 0.45, 0.9, 1}}

    for player, i in self.drawn {
        if node, present := scenegd.nodes_get(&self.gunners, u64(i + 1)); present {
            h := self.feedback[0].health[i]
            flashing := h.left > 0 && h.life == player.life
            color := flashing ? gd.Color{1, 0.25, 0.2, 1} : player.hp > 0 ? colors[i] : gd.Color{0.35, 0.32, 0.3, 0.55}
            gd.canvas_item_set_self_modulate(cast(gd.Canvas_Item)gd.get_node(node, "Skin"), color)
        }
    }

    instances: [flow.RING_LIMIT]scenegd.Instance2
    n := 0

    for ring, i in self.feedback[0].rings {
        if ring.left > 0 {
            instances[n] = {
                key = u64(i + 1),
                pose = {position = ring.position},
                scale = {1, 1},
                color = {1, 0.82, 0.32, f32(ring.left / flow.RING_SECONDS)},
            }
            n += 1
        }
    }

    scenegd.nodes_present(&self.rings, instances[:n])
}

feedback_restart :: proc(self: ^ReplayQuickdraw) {
    flow.destroy(&self.feedback[0])
    flow.init(&self.feedback[0])
    scenegd.nodes_clear(&self.rings)
}

@(gd_method)
replay_quickdraw_feedback_probe :: proc(self: ^ReplayQuickdraw, key: string, seat: gd.Int = 1) -> gd.Float {
    f := &self.feedback[0]

    switch key {
    case "hurt":
        return gd.Float(f.hurt)
    case "landed":
        return gd.Float(f.landed)
    case "speculative":
        return gd.Float(f.speculative)
    case "canceled":
        return gd.Float(f.canceled)
    case "duplicates":
        return gd.Float(f.duplicates)
    case "dropped":
        return gd.Float(f.dropped)
    case "rings":
        return gd.Float(self.rings.count)
    }

    if seat < 1 || seat > len(f.health) {
        return -1
    }

    switch key {
    case "left":
        return gd.Float(f.health[seat - 1].left)
    case "hp":
        return gd.Float(f.health[seat - 1].hp)
    case "life":
        return gd.Float(f.health[seat - 1].life)
    }

    return -1
}

@(gd_method)
replay_quickdraw_feedback_view :: proc(self: ^ReplayQuickdraw, kind: string, key: gd.Int) -> gd.Node2d {
    if key < 1 {
        return nil
    }

    if kind == "gunner" {
        node, _ := scenegd.nodes_get(&self.gunners, u64(key))
        return node
    }

    if kind == "ring" {
        node, _ := scenegd.nodes_get(&self.rings, u64(key))
        return node
    }

    return nil
}
