package replay_quickdraw

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import sc "godot:replay/schema"
import rgd "godot:replay/godot"
import game "../shared/duel"

Quickdraw_Browser_Save :: struct {
    slot:            rgd.Browser_Checkpoint(game.World, game.Controls, game.Action, game.Event, game.SEATS),
    seen_receipt:    u64,
    loading_message: bool,
}

browser_save_frame :: proc(self: ^ReplayQuickdraw) {
    when gd.IS_WEB {
        if !profile_available(self) {
            return
        }

        if self.ready && self.session.role != .Solo {
            return
        }

        io := &self.browser_save[0]
        slot := &io.slot
        key, valid := browser_save_key(self)

        if !valid {
            if !self.ready && slot.phase != .Writing {
                rgd.browser_checkpoint_close(slot)
            }

            return
        }

        if slot.phase == .Closed || (!self.ready && slot.phase != .Writing && key != slot.key) {
            rgd.browser_checkpoint_close(slot)
            io.seen_receipt = 0
            rgd.browser_checkpoint_open(slot, "replay-quickdraw", key, game.model(), game.CONTENT, self.identity)
        }

        rgd.browser_checkpoint_frame(slot)

        if slot.receipt_serial != io.seen_receipt {
            io.seen_receipt = slot.receipt_serial

            if slot.last_success {
                self.saved_tick = slot.saved_tick
                self.saved_hash = browser_world_hash(slot.checkpoint.frame)
                gd.set_string(self.ui[0].save_notice, "text", fmt.ctprintf("Saved duel at tick %d", slot.saved_tick))
                gd.print_str(
                    fmt.tprintf(
                        "RQ_BROWSER_SAVED tick=%d hash=%d revision=%d",
                        self.saved_tick,
                        self.saved_hash,
                        slot.revision,
                    ),
                )
            } else {
                gd.set_string(
                    self.ui[0].save_notice,
                    "text",
                    slot.store_error == .Conflict ? "Another tab changed this slot. Reload before saving again." : "Could not save. The previous slot was kept.",
                )
                gd.print_str(fmt.tprintf("RQ_BROWSER_SAVE_REJECTED store=%v error=%v", slot.store_error, slot.error))
            }
        }
    }
}

profile_identity_hex :: proc(self: ^ReplayQuickdraw) -> string {
    text := replay_quickdraw_profile_hash(self)
    defer gd.free_string(text)
    return fmt.tprintf("%s", gd.gd_string_to_odin(text))
}

browser_world_hash :: proc(frame: r.Frame(game.World)) -> u64 {
    codec: sc.Schema
    defer sc.destroy(&codec)
    options := sc.DEFAULT_OPTIONS
    options.projection = .Public

    if sc.init(&codec, game.World, options).error != .None {
        return 0
    }

    bytes := make([]u8, codec.wire_size, context.temp_allocator)

    if sc.encode(&codec, frame.state, bytes).error != .None {
        return 0
    }

    return sc.digest(bytes) & 0x7fff_ffff_ffff_ffff
}

browser_save_submit :: proc(self: ^ReplayQuickdraw) -> bool {
    slot := &self.browser_save[0].slot
    key, valid := browser_save_key(self)

    if !valid || key != slot.key || self.session.role != .Solo || !rgd.browser_checkpoint_save(slot, self.session) {
        gd.set_string(self.ui[0].save_notice, "text", "This slot is unavailable. Choose another slot or reload.")
        return false
    }

    gd.set_string(self.ui[0].save_notice, "text", "Saving…")
    return true
}

browser_save_status :: proc(self: ^ReplayQuickdraw) {
    when gd.IS_WEB {
        if self.online.enabled && self.room.ready {
            return
        }

        io := &self.browser_save[0]
        slot := &io.slot

        if !self.online.enabled {
            if !self.ready {
                gd.set_string(self.status, "text", "Start solo or resume a saved duel.")
            }

            gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Column/Address"), false)
            gd.line_edit_set_max_length(self.ui[0].save_path, 48)
            gd.set_string(gd.get_node(self.owner, "UI/Lobby/Column/Saved/Label"), "text", "SAVE SLOT")
            gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Column/Saved"), !self.ready)
            gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Column/Resume"), !self.ready)
            gd.canvas_item_set_visible(self.ui[0].resume[1], false)
            gd.base_button_set_disabled(
                self.ui[0].resume[0],
                self.ready || !profile_available(self) || slot.phase != .Ready || !slot.has_checkpoint,
            )
        }

        gd.base_button_set_disabled(self.ui[0].leave, self.ready && slot.phase == .Writing)
        can_save := self.ready && self.session.ready && self.session.role == .Solo
        gd.canvas_item_set_visible(self.ui[0].save, can_save)
        gd.canvas_item_set_visible(self.ui[0].save_notice, self.ready && self.session.role == .Solo)
        gd.base_button_set_disabled(self.ui[0].save, !can_save || slot.phase != .Ready || self.session.fenced)

        if !self.online.enabled {
            for button in self.ui[0].doors[1:] {
                gd.canvas_item_set_visible(button, false)
            }
        }

        if !self.ready && !self.online.enabled && profile_available(self) {
            if _, valid := browser_save_key(self); !valid {
                ui_notice(self, "Use 1–48 letters, numbers, dots, dashes or underscores for the slot.")
                return
            }

            if slot.phase == .Reading {
                io.loading_message = true
                ui_notice(self, "Loading the saved slot…")
            } else if slot.phase == .Ready && io.loading_message {
                io.loading_message = false
                ui_notice(
                    self,
                    slot.has_checkpoint ? "Saved slot ready. Resume whenever you like." : "No saved duel in this slot. Start a new solo duel.",
                )
            } else if slot.phase == .Failed {
                ui_notice(self, "This saved slot could not be read. Choose another slot or reload.")
            }
        }
    }
}

browser_save_close :: proc(self: ^ReplayQuickdraw) {
    rgd.browser_checkpoint_close(&self.browser_save[0].slot)
}

@(gd_method)
replay_quickdraw_browser_save_probe :: proc(self: ^ReplayQuickdraw, key: string) -> gd.Int {
    slot := &self.browser_save[0].slot

    switch key {
    case "phase":
        return gd.Int(slot.phase)
    case "has":
        return gd.Int(slot.has_checkpoint)
    case "revision":
        return gd.Int(slot.revision)
    case "receipt":
        return gd.Int(slot.receipt_serial)
    case "success":
        return gd.Int(slot.last_success)
    case "error":
        return gd.Int(slot.error)
    case "store_error":
        return gd.Int(slot.store_error)
    }

    return -1
}

browser_save_key :: proc(self: ^ReplayQuickdraw) -> (string, bool) {
    label := save_path(self)

    if len(label) < 1 || len(label) > 48 {
        return "", false
    }

    for c in label {
        if !((c >= 'a' && c <= 'z') ||
               (c >= 'A' && c <= 'Z') ||
               (c >= '0' && c <= '9') ||
               c == '.' ||
               c == '-' ||
               c == '_') {
            return "", false
        }
    }

    return fmt.tprintf("save/%s/%s", profile_identity_hex(self), label), true
}

// A resume deep link must wait for both identity and the selected slot read.
// Never consume the launch intent merely because profile loading finished first.
browser_launch_frame :: proc(self: ^ReplayQuickdraw) {
    when gd.IS_WEB {
        if self.browser_launch == "" || !profile_available(self) {
            return
        }

        resume := quickdraw_int("RQ_RESUME", 0) == 1
        phase := self.browser_save[0].slot.phase

        if resume && (phase == .Closed || phase == .Reading || phase == .Writing) {
            return
        }

        role := self.browser_launch
        self.browser_launch = ""
        defer delete(role)
        connect_duel(self, role, false, resume)
    }
}
