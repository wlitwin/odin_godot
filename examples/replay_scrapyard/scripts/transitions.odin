//gd:extends Control
//gd:class ReplayScrapyardTransitions
package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import game "../shared/game"
import flow "../shared/flow"

ReplayScrapyardTransitions :: struct {
    owner: gd.Control,
    wave: gd.Nine_Patch_Rect `gd:"onready=Wave"`,
    wave_text: gd.Label `gd:"onready=Wave/Text"`,
    depart: gd.Label `gd:"onready=Depart"`,
    over: gd.Nine_Patch_Rect `gd:"onready=Over"`,
    over_text: gd.Label `gd:"onready=Over/Text"`,
    recovery: gd.Nine_Patch_Rect `gd:"onready=Recovery"`,
    recovery_text: gd.Label `gd:"onready=Recovery/Text"`,
}

transitions_paint :: proc(self: ^ReplayScrapyardTransitions, view: flow.View) {
    gd.canvas_item_set_visible(self.wave, view.kind != .None && view.kind != .Depart && view.kind != .Over)
    gd.canvas_item_set_visible(self.depart, view.kind == .Depart)
    gd.canvas_item_set_visible(self.over, view.kind == .Over)
    text: cstring

    switch view.kind {
    case .Wave:
        text = fmt.ctprintf(
            "WAVE %d OF %d · %d incoming · %d alive",
            view.wave,
            view.total,
            view.pending,
            view.alive,
        )
    case .Rest:
        text = fmt.ctprintf("WAVE %d OF %d IN %ds", view.wave, view.total, view.seconds)
    case .Securing:
        text = fmt.ctprintf("SECURING FLOOR %d · %ds", view.floor, view.seconds)
    case .Remaining:
        text = fmt.ctprintf("CLEAR THE REMAINING ENEMIES · %d alive", view.alive)
    case .Clear:
        text = fmt.ctprintf("FLOOR %d CLEAR · regroup at the east gate", view.floor)
    case .Depart:
        gd.set_string(self.depart, "text", fmt.ctprintf("DESCENDING  %d", view.seconds))
        fraction := f32(u32(view.depart_left) % game.HZ) / f32(game.HZ)
        gd.canvas_item_set_modulate(
            self.depart,
            {1, 0.7 + 0.25 * fraction, 0.4 + 0.2 * fraction, 0.6 + 0.4 * fraction},
        )
    case .Over:
        if view.personal {
            gd.set_string(
                self.over_text,
                "text",
                fmt.ctprintf(
                    "T H E   Y A R D   T A K E S   Y O U\n\nfloor reached  %d\nkills  %d      scrap lost  %d\ncores kept  %d\n\n...dragged back to the surface",
                    view.floor,
                    view.kills,
                    view.scrap,
                    view.cores,
                ),
            )
        } else {
            gd.set_string(
                self.over_text,
                "text",
                fmt.ctprintf(
                    "T H E   Y A R D   T A K E S   T H E M\n\nfloor reached  %d\nthe crew has fallen\n\n...dragged back to the surface",
                    view.floor,
                ),
            )
        }
    case .None:
    }

    if text != nil {
        gd.set_string(self.wave_text, "text", text)
    }
}

// Runs even while no gameplay frame is available. A transient local toast
// cannot accidentally outlive or conceal the actual Room recovery phase.
transitions_recovery :: proc(self: ^ReplayScrapyard) {
    if self.transitions == nil {
        return
    }

    text: cstring

    if self.room.ready {
        switch self.room.phase {
        case .Connecting:
            text = "Connecting to the yard…"
        case .Freezing, .Releasing:
            text = "Passing the run to a teammate…"
        case .Claiming:
            text = "Host lost — finding the next keeper…"
        case .Recovering:
            text = "Restoring the run…"
        case .Failed:
            text = "The room could not recover."
        case .Following:
            if !self.session.ready || self.session.client.phase != .Running {
                text = "Waiting for the host…"
            }
        case .Hosting:
        }
    }

    gd.canvas_item_set_visible(self.transitions.recovery, text != nil)

    if text != nil {
        gd.set_string(self.transitions.recovery_text, "text", text)
        gd.canvas_item_set_visible(self.transitions.wave, false)
        gd.canvas_item_set_visible(self.transitions.depart, false)
    }
}
