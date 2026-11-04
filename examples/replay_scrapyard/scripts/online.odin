package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import rgd "godot:replay/godot"
import game "../shared/game"
import transportgd "godot:replay/godot/transport"

Scrap_Online :: struct {
    party: rgd.Party,
    enabled, launch, launching: bool,
    role: rgd.Session_Role,
    native: rawptr,
    tls: gd.Tls_Options,
}

online_unref :: proc(object: gd.Ref_Counted) {
    if object != nil && gd.ref_counted_unreference(object) {
        gdext.object_destroy(object)
    }
}

online_ready :: proc(self: ^ReplayScrapyard) {
    gd.connect_to(
        gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Doors/Rejoin"),
        "pressed",
        self.owner,
        "on_rejoin_party",
    )
    gd.connect_to(
        gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/CopyInvite"),
        "pressed",
        self.owner,
        "on_copy_party",
    )
    gd.connect_to(gd.get_node(self.owner, "UI/Menu/Scroll/Column/CopyParty"), "pressed", self.owner, "on_copy_party")
    service := scrap_param("RSY_ROOM_SERVICE", "")

    if service == "" {
        return
    }

    self.online.enabled = true
    local := scrap_int("RSY_ROOM_LOCAL", 0) == 1
    port := scrap_int("RSY_PORT", 49610)
    endpoint, valid := auth.endpoint(scrap_param("RSY_ROOM_ADDRESS", "127.0.0.1"), u16(port))

    if !valid || port < 1 || port > 65535 || !p.service_url_valid(service, local) {
        online_error(self, "The party service or gameplay address is invalid.")
        return
    }

    storage, ok := online_native_init(self, local)
    ice, ice_error := transportgd.rtc_ice_settings("RSY_ICE_JSON")

    if ice_error != .None {
        online_error(self, "The relay configuration is invalid.")
        return
    }

    cfg := rgd.Party_Config {
        service = service,
        namespace = "replay-scrapyard-rooms",
        content = game.CONTENT,
        endpoint = endpoint,
        invite_role = .Trusted_Peer,
        invite_uses = game.SEATS - 1,
        local_development = local,
        tls = self.online.tls,
        storage = storage,
        ice_json = ice,
        relay_credentials = scrap_int("RSY_ROOM_RELAY", 0) == 1,
    }

    if !ok || !rgd.party_open(&self.online.party, cfg) {
        online_error(self, "Party credentials could not be opened. Existing data was kept.")
    }

    online_status(self)
}

online_error :: proc(self: ^ReplayScrapyard, message: string) {
    self.online.party.failed = true
    gd.set_string(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/Notice"), "text", fmt.ctprintf("%s", message))
}

online_begin :: proc(self: ^ReplayScrapyard, action: rgd.Party_Action, observer: bool = false) {
    o := &self.online

    if !o.enabled ||
       !o.party.recent_loaded ||
       o.party.active ||
       self.session.ready ||
       self.room.ready ||
       self.pending_open {
        return
    }

    ticket: p.Ticket

    if action == .Join {
        value := gd.line_edit_get_text(cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/Code"))
        defer gd.free_string(value)
        valid: bool
        ticket, valid = p.ticket_parse(gd.gd_string_to_odin(value))

        if !valid {
            gd.set_string(
                gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/Notice"),
                "text",
                "Paste a complete party invite.",
            )
            return
        }
    }

    if !rgd.party_begin(&o.party, action, ticket) {
        online_status(self)
        return
    }

    o.role = observer ? .Observer : action == .Create ? .Host : .Client
    o.launching = false
    self.resume_requested = false
}

online_frame :: proc(self: ^ReplayScrapyard) {
    o := &self.online

    if !o.enabled {
        return
    }

    rgd.party_frame(&o.party)

    if !o.party.ready || o.party.failed || o.launching || self.session.ready || self.room.ready {
        return
    }

    if o.party.invited {
        gd.set_string(
            gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/Code"),
            "text",
            fmt.ctprintf("%s", string(o.party.code[:])),
        )
    }

    o.launch, o.launching = true, true
    open_new(self, o.role)
}

online_status :: proc(self: ^ReplayScrapyard) {
    o := &self.online
    gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party"), o.enabled)
    gd.canvas_item_set_visible(
        gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Doors/Rejoin"),
        o.enabled && !self.room.ready && !self.session.ready && o.party.recent_room != 0,
    )
    gd.canvas_item_set_visible(
        gd.get_node(self.owner, "UI/Menu/Scroll/Column/CopyParty"),
        o.enabled && o.party.invited,
    )

    if !o.enabled {
        return
    }

    connected := self.session.ready || self.room.ready

    for name in ([6]cstring{"Solo", "Host", "Resume", "Join", "Watch", "Rejoin"}) {
        button := cast(gd.Base_Button)gd.get_node(self.owner, fmt.ctprintf("UI/Lobby/Scroll/Layout/Doors/%s", name))
        gd.base_button_set_disabled(button, connected || o.party.active || !o.party.recent_loaded || self.pending_open)
    }

    gd.set_string(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Doors/Host"), "text", "Create party")
    gd.set_string(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Doors/Join"), "text", "Join party")
    gd.line_edit_set_editable(
        cast(gd.Line_Edit)gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/Code"),
        !connected && !o.party.active,
    )
    gd.canvas_item_set_visible(gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/CopyInvite"), o.party.invited)
    message := rgd.party_message(&o.party)

    if message != "" {
        gd.set_string(
            gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/Notice"),
            "text",
            fmt.ctprintf("%s", message),
        )
    } else if connected {
        gd.set_string(
            gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/Notice"),
            "text",
            "Party connected. Ready up to enter the yard.",
        )
    }

    if self.room.ready && !self.session.ready {
        message = rgd.room_restore_message(&self.room.restore)

        if message != "" {
            gd.set_string(
                gd.get_node(self.owner, "UI/Lobby/Scroll/Layout/Party/Notice"),
                "text",
                fmt.ctprintf("%s", message),
            )
        }
    }
}

@(gd_method)
replay_scrapyard_on_rejoin_party :: proc(self: ^ReplayScrapyard) {
    online_begin(self, .Rejoin)
}

@(gd_method)
replay_scrapyard_on_copy_party :: proc(self: ^ReplayScrapyard) {
    if !self.online.party.invited {
        return
    }

    value := gd.new_string_odin(string(self.online.party.code[:]))
    defer gd.free_string(value)
    gd.display_server_clipboard_set(gd.singleton_display_server(), value)
}

@(gd_method)
replay_scrapyard_party_probe :: proc(self: ^ReplayScrapyard, key: string) -> gd.Int {
    switch key {
    case "save_completed":
        return gd.Int(self.room.save.completed)
    case "save_revision":
        return gd.Int(self.room.save.publication.revision)
    case "save_tick":
        return gd.Int(self.room.save.publication.point.archive.tick)
    case "save_error":
        return gd.Int(self.room.save.error)
    case "save_phase":
        return gd.Int(self.room.save.phase)
    case "room_phase":
        return gd.Int(self.room.phase)
    case "control_error":
        return gd.Int(self.room.control_error)
    case "lease_remaining":
        return(
            self.room.lease.deadline > self.room.lease.now ? gd.Int(self.room.lease.deadline - self.room.lease.now) : 0 \
        )
    case "rpc_pending":
        return gd.Int(self.room.rpc.pending)
    case "lease_pending":
        return gd.Int(self.room.lease.pending)
    case "rpc_verb":
        return gd.Int(self.room.rpc.request.command.verb)
    case "rpc_result":
        return gd.Int(self.room.rpc.reply.result)
    case "rpc_sequence":
        return gd.Int(self.room.rpc.request.sequence)
    case "restore_refresh_after":
        return gd.Int(self.room.restore.refresh_after)
    case "restore_renewed":
        return gd.Int(self.room.restore.renewed_epoch)
    case "restore_phase":
        return gd.Int(self.room.restore.phase)
    case "restore_error":
        return gd.Int(self.room.restore.error)
    case "restore_tick":
        return gd.Int(self.room.recovery.checkpoint_tick)
    case "restore_publication":
        return gd.Int(self.room.recovery.from_publication)
    case "asset_bytes":
        return gd.Int(self.assets[0].cache.bytes)
    case "recent":
        return gd.Int(self.online.party.recent_loaded)
    case "failed":
        return gd.Int(self.online.party.failed)
    case "invited":
        return gd.Int(self.online.party.invited)
    case "relay_revision":
        return gd.Int(self.online.party.relay.revision)
    case "incarnation":
        return gd.Int(self.room.options.identity.incarnation)
    case "steady":
        return gd.Int(
            self.session.ready &&
            !self.session.fenced &&
            (self.session.authority || self.session.client.phase == .Running),
        )
    case "identity_separate":
        return gd.Int(self.session.ready && self.session.token != self.local_profile[0].token)
    }

    return 0
}

online_close :: proc(self: ^ReplayScrapyard) {
    rgd.party_close(&self.online.party)
    online_native_close(self)
    online_unref(self.online.tls)
    self.online = {}
}
