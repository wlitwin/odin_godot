package replay_slopball3d

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import sc "godot:replay/schema"
import rgd "godot:replay/godot"
import game "../shared/pitch"

Slopball3D_Browser_Save :: struct {
    slot:            rgd.Browser_Checkpoint(game.World, game.Control, game.Action, game.Event, game.SEATS),
    seen_receipt:    u64,
    loading_message: bool,
}

browser_save_frame :: proc(self: ^ReplaySlopball3d) {
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
            rgd.browser_checkpoint_open(slot, "replay-slopball3d", key, game.model(), game.CONTENT, self.identity)
        }

        rgd.browser_checkpoint_frame(slot)

        if slot.receipt_serial != io.seen_receipt {
            io.seen_receipt = slot.receipt_serial

            if slot.last_success {
                self.saved_tick = slot.saved_tick
                self.saved_hash = browser_world_hash(slot.checkpoint.frame)
                gd.set_string(self.ui[0].save_notice, "text", fmt.ctprintf("Saved match at tick %d", slot.saved_tick))
                gd.print_str(
                    fmt.tprintf(
                        "RS3_BROWSER_SAVED tick=%d hash=%d revision=%d",
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
                gd.print_str(fmt.tprintf("RS3_BROWSER_SAVE_REJECTED store=%v error=%v", slot.store_error, slot.error))
            }
        }
    }
}

profile_identity_hex :: proc(self: ^ReplaySlopball3d) -> string {
    text := replay_slopball3d_profile_hash(self)
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

browser_save_submit :: proc(self: ^ReplaySlopball3d) -> bool {
    slot := &self.browser_save[0].slot
    key, valid := browser_save_key(self)

    if !valid || key != slot.key || self.session.role != .Solo || !rgd.browser_checkpoint_save(slot, self.session) {
        gd.set_string(self.ui[0].save_notice, "text", "This slot is unavailable. Choose another slot or reload.")
        return false
    }

    gd.set_string(self.ui[0].save_notice, "text", "Saving…")
    return true
}

browser_save_status :: proc(self: ^ReplaySlopball3d) {
    when gd.IS_WEB {
        if self.online.enabled && self.room.ready {
            return
        }

        io := &self.browser_save[0]
        slot := &io.slot

        if !self.online.enabled {
            if !self.ready {
                gd.set_string(self.status, "text", "Start solo or resume a saved match.")
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
                    slot.has_checkpoint ? "Saved slot ready. Resume whenever you like." : "No saved match in this slot. Start a new solo match.",
                )
            } else if slot.phase == .Failed {
                ui_notice(self, "This saved slot could not be read. Choose another slot or reload.")
            }
        }
    }
}

browser_save_close :: proc(self: ^ReplaySlopball3d) {
    rgd.browser_checkpoint_close(&self.browser_save[0].slot)
}

@(gd_method)
replay_slopball3d_browser_save_probe :: proc(self: ^ReplaySlopball3d, key: string) -> gd.Int {
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

browser_save_key :: proc(self: ^ReplaySlopball3d) -> (string, bool) {
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
