package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import r "godot:replay"
import a "godot:replay/assets"
import auth "godot:replay/authority"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/game"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

Spray_Local :: struct {
    ref: a.Ref,
    loaded: bool,
    last_declare: u64,
    notice_until: u64,
    error: bool,
    web: Browser_Spray,
}

Spray_Dependencies :: struct {
    point: auth.Point,
    refs: [game.SEATS]a.Ref,
    valid: bool,
}

Spray_Rig :: struct {
    sprite: gd.Sprite2d,
    marker: gd.Line2d,
    ref: a.Ref,
    texture: gd.Texture2d,
}

spray_open :: proc(self: ^ReplayScrapyard) -> bool {
    if rgd.session_assets_init(&self.assets[0], validator = scenegd.asset_png_valid) != .None {
        return false
    }

    for &rig, i in self.spray_rigs {
        rig.sprite = gd.new_sprite2d()
        gd.add_child(self.world_node, rig.sprite)
        gd.canvas_item_set_z_index(rig.sprite, 1)
        name := gd.new_string_name(fmt.tprintf("Spray%d", i + 1))
        gd.node_set_name(rig.sprite, name)
        gd.free_string_name(name)
        gd.canvas_item_set_modulate(rig.sprite, {1, 1, 1, 0.85})
        gd.canvas_item_set_visible(rig.sprite, false)
        rig.marker = gd.new_line2d()
        gd.add_child(self.world_node, rig.marker)
        gd.canvas_item_set_z_index(rig.marker, 1)
        gd.line2d_set_width(rig.marker, 1.5)
        gd.line2d_set_default_color(rig.marker, {0.7, 0.8, 1, 0.7})

        for point in ([5][2]f32{{0, -9}, {9, 0}, {0, 9}, {-9, 0}, {0, -9}}) {
            gd.line2d_add_point(rig.marker, point, -1)
        }

        gd.canvas_item_set_visible(rig.marker, false)
    }

    return true
}

spray_adopt :: proc(self: ^ReplayScrapyard, bytes: []u8, persist: bool) -> bool {
    local := &self.spray_local[0]
    local.notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 3000

    if !scenegd.asset_png_valid(nil, {}, bytes) {
        local.error = true
        gd.print_str("RSY_SPRAY_BAD image")
        return false
    }

    ref, err := a.cache_put(&self.assets[0].cache, bytes)

    if err != .None {
        local.error = true
        gd.print_str(fmt.tprintf("RSY_SPRAY_BAD cache=%v", err))
        return false
    }

    if persist {
        if err := storagegd.storage_write(scrap_param("RSY_SPRAY_STORE", "user://spray.png"), bytes, game.SPRAY_MAX);
           err != .None {
            local.error = true
            gd.print_str(fmt.tprintf("RSY_SPRAY_BAD write=%v", err))
            return false
        }
    }

    if ref != local.ref {
        if a.cache_pin(&self.assets[0].cache, ref) != .None {
            local.error = true
            return false
        }

        if local.ref != (a.Ref{}) {
            a.cache_unpin(&self.assets[0].cache, local.ref)
        }
    }

    local.ref, local.loaded, local.error, local.last_declare = ref, true, false, 0
    gd.print_str(fmt.tprintf("RSY_SPRAY_ADOPTED bytes=%d", ref.bytes))
    return true
}

spray_load :: proc(self: ^ReplayScrapyard, path: string, persist: bool) -> bool {
    bytes, err := storagegd.storage_read(path, game.SPRAY_MAX)
    defer delete(bytes)

    if err != .None {
        gd.print_str(fmt.tprintf("RSY_SPRAY_BAD read=%v", err))
        return false
    }

    return spray_adopt(self, bytes, persist)
}

spray_frame :: proc(self: ^ReplayScrapyard, truth: r.Frame(game.World)) {
    local := &self.spray_local[0]
    seat := rgd.session_seat(self.session)

    if seat > 0 && truth.state.players[seat - 1].in_yard {
        if !local.loaded {
            local.loaded = true

            when gd.IS_WEB {
                if self.local_profile[0].enabled {
                    web_spray_load(self)
                }
            } else {
                path := scrap_param("RSY_SPRAY", "")

                if len(path) == 0 && (len(scrap_param("RSY_TOKEN", "")) == 0 || scrap_int("RSY_PERSIST", 0) != 0) {
                    path = scrap_param("RSY_SPRAY_STORE", "user://spray.png")
                }

                if len(path) > 0 {
                    gpath := gd.new_string_odin(path)
                    exists := gd.file_access_file_exists(gpath)
                    gd.free_string(gpath)

                    if exists {
                        spray_load(self, path, false)
                    }
                }
            }
        }

        now := gd.time_get_ticks_msec(gd.singleton_time())

        if local.ref != (a.Ref{}) &&
           truth.state.players[seat - 1].spray.image != local.ref &&
           (local.last_declare == 0 || now - local.last_declare >= 500) {
            if issue(self, game.Action{kind = .Set_Spray, image = local.ref}) {
                local.last_declare = now
            }
        }
    }

    refs: [game.SEATS * 3 + 1]a.Ref

    for player, i in truth.state.players {
        refs[i] = player.spray.image
    }

    refs[game.SEATS] = local.ref

    if self.room.candidate.ready {
        for ref, i in self.spray_dependencies[0].refs {
            refs[game.SEATS + 1 + i] = ref
        }
    }

    if self.recovery_probe[0].point == self.room.prepared.point {
        for player, i in self.recovery_probe[0].frame.state.players {
            refs[game.SEATS * 2 + 1 + i] = player.spray.image
        }
    }

    local_refs := [1]a.Ref{local.ref}

    if !self.assets_paused {
        if err := rgd.session_assets_frame(&self.assets[0], self.session, refs[:], local_refs[:]); err != .None {
            fail(self, fmt.tprintf("assets %v", err))
            return
        }
    }

    for &rig, i in self.spray_rigs {
        spray := truth.state.players[i].spray

        if spray.image != rig.ref && a.cache_has(&self.assets[0].cache, spray.image) {
            bytes, err := a.cache_copy(&self.assets[0].cache, spray.image)

            if err == .None {
                image, ok := scenegd.asset_png_image(bytes)

                if ok {
                    texture := cast(gd.Texture2d)gd.image_texture_create_from_image(image)

                    if texture != nil {
                        gd.sprite2d_set_texture(rig.sprite, texture)
                        release(rig.texture)
                        rig.texture, rig.ref = texture, spray.image
                        scale := f32(26) / f32(gd.texture2d_get_width(texture))
                        gd.node2d_set_scale(rig.sprite, {scale, scale})
                        gd.print_str(fmt.tprintf("RSY_SPRAY_TEXTURE seat=%d bytes=%d", i + 1, spray.image.bytes))
                    }

                    if gd.ref_counted_unreference(image) {
                        gdext.object_destroy(image)
                    }
                }
            }

            delete(bytes)
        }

        active := spray.stamp != 0 && spray.floor == truth.state.floor
        textured := rig.texture != nil && rig.ref == spray.image
        gd.node2d_set_position(rig.sprite, spray.position)
        gd.node2d_set_position(rig.marker, spray.position)
        gd.canvas_item_set_visible(rig.sprite, active && textured)
        gd.canvas_item_set_visible(rig.marker, active && !textured)
    }

    if gd.time_get_ticks_msec(gd.singleton_time()) < local.notice_until && local.error {
        gd.set_string(self.status, "text", "Could not load the spray. Choose a PNG up to 128 KB.")
    }

    if local.web.phase == .Checking || local.web.phase == .Writing {
        gd.set_string(self.status, "text", "Saving spray…")
    }
}

@(gd_method)
replay_scrapyard_stamp :: proc(self: ^ReplayScrapyard) -> bool {
    return issue(self, game.Action{kind = .Stamp})
}

@(gd_method)
replay_scrapyard_on_spray_file :: proc(self: ^ReplayScrapyard, path: string) {
    spray_load(self, path, true)
}

@(gd_method)
replay_scrapyard_on_spray_pick :: proc(self: ^ReplayScrapyard) {
    when gd.IS_WEB {
        if self.spray_local[0].web.phase != .Idle {
            gd.set_string(self.status, "text", "The spray is still loading or saving.")
            return
        }

        web_spray_pick()
        return
    }

    if self.spray_dialog == nil {
        self.spray_dialog = gd.new_file_dialog()
        gd.add_child(self.owner, self.spray_dialog)
        gd.file_dialog_set_access(self.spray_dialog, .Access_Filesystem)
        gd.file_dialog_set_file_mode(self.spray_dialog, .File_Mode_Open_File)
        filter := gd.new_string_cstring("*.png")
        description := gd.new_string_cstring("PNG images")
        mime := gd.new_string_cstring("image/png")
        gd.file_dialog_add_filter(self.spray_dialog, filter, description, mime)
        gd.free_string(filter)
        gd.free_string(description)
        gd.free_string(mime)
        gd.connect_to(self.spray_dialog, "file_selected", self.owner, "on_spray_file")
    }

    gd.window_popup_centered(self.spray_dialog, {700, 460})
}

spray_close :: proc(self: ^ReplayScrapyard) {
    storagegd.browser_store_close(&self.spray_local[0].web.op)
    delete(self.spray_local[0].web.bytes)

    if self.spray_local[0].web.pinned != (a.Ref{}) {
        a.cache_unpin(&self.assets[0].cache, self.spray_local[0].web.pinned)
    }

    for &rig in self.spray_rigs {
        release(rig.texture)
        rig.texture = nil
    }

    rgd.session_assets_destroy(&self.assets[0])
}

@(gd_method = "owned_return")
replay_scrapyard_spray_id :: proc(self: ^ReplayScrapyard, wanted: gd.Int) -> gd.String {
    frame, ok := rgd.session_authority_state(self.session)

    if !ok || wanted < 1 || wanted > game.SEATS {
        return gd.new_string_odin("")
    }

    text := ""

    for b in frame.state.players[wanted - 1].spray.image.id {
        text = fmt.tprintf("%s%02x", text, b)
    }

    return gd.new_string_odin(text)
}

// An approved point includes its external image dependencies. Decode each candidate
// only once; the ordinary asset frame requests/pins the resulting references.
spray_preparation_ready :: proc(user: rawptr, point: auth.Point, bytes: []u8) -> bool {
    self := cast(^ReplayScrapyard)user
    deps := &self.spray_dependencies[0]

    if deps.point != point {
        deps^ = {
            point = point,
        }
        cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
        defer net.checkpoint_destroy(&cp)
        codec := &self.session.link.incoming.archive_codec

        if !codec.ready {
            codec = nil
        }

        if net.checkpoint_decode(&cp, bytes, game.model(), game.CONTENT, codec = codec) != .None {
            return false
        }

        for player, i in cp.frame.state.players {
            deps.refs[i] = player.spray.image
        }

        deps.valid = true
    }

    if !deps.valid {
        return false
    }

    for ref in deps.refs {
        if ref != (a.Ref{}) && !a.cache_has(&self.assets[0].cache, ref) {
            return false
        }
    }

    return true
}

// Cache availability is an authority admission decision, captured in the runner's
// verdict ledger. Prediction/replay continue to use the pure game reducer.
session_model :: proc(
    self: ^ReplayScrapyard,
) -> net.Model(game.World, game.Control, game.Action, game.Event, game.SEATS) {
    model := game.model()
    model.action_admission_user = self
    model.action_admit = proc(user: rawptr, seat: u16, action: game.Action) -> bool {
        self := cast(^ReplayScrapyard)user
        return(
            game.development_allowed(
                self.development,
                self.session.authority ? rgd.session_seat(self.session) : 0,
                seat,
                action,
            ) &&
            (action.kind != .Set_Spray ||
                    action.image == (a.Ref{}) ||
                    a.cache_has(&self.assets[0].cache, action.image)) \
        )
    }
    return model
}

@(gd_method)
replay_scrapyard_dev_asset_pause :: proc(self: ^ReplayScrapyard, paused: bool) {
    self.assets_paused = paused
}
