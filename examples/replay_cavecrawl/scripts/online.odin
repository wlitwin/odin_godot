package replay_cavecrawl

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import prov "godot:replay/provision"
import rgd "godot:replay/godot"
import game "../shared/cave"
import transportgd "godot:replay/godot/transport"

Cave_Online :: struct {
    using party: rgd.Party,
    enabled, launch: bool,
    native: rawptr,
    tls: gd.Tls_Options,
    notice: string,
}
online_unref :: proc(object: gd.Ref_Counted) {if object != nil && gd.ref_counted_unreference(object) {gdext.object_destroy(object)}}
online_notice :: proc(self: ^ReplayCave, text: string) {delete(self.online.notice); self.online.notice = strings.clone(text)}
online_fail :: proc(self: ^ReplayCave, text: string) {self.online.failed = true; self.online.active = false; online_notice(self, text)}
online_ready :: proc(self: ^ReplayCave) {
    for binding in ([2][2]cstring{{"Rejoin", "on_rejoin_party"}, {"CopyInvite", "on_copy_invite"}}) {
        gd.connect_to(gd.get_node(self.owner, fmt.ctprintf("Lobby/Panel/Column/Buttons/%s", binding[0])), "pressed", self.owner, binding[1])
    }
    service := cave_param("REPLAY_CAVE_ROOM_SERVICE", ""); if service == "" {return}
    self.online.enabled = true
    local := cave_int("REPLAY_CAVE_ROOM_LOCAL", 0) == 1
    if !prov.service_url_valid(service, local) {online_fail(self, "The party service address is invalid."); return}
    port := cave_int("REPLAY_CAVE_PORT", 49422)
    endpoint, valid := auth.endpoint(cave_param("REPLAY_CAVE_ROOM_ADDRESS", "127.0.0.1"), u16(port))
    if !valid || port < 1 || port > 65535 {online_fail(self, "The gameplay address is invalid."); return}
    storage, ok := online_native_init(self, local)
    ice, ice_error := transportgd.rtc_ice_settings("REPLAY_CAVE_ICE_JSON")
    if ice_error != .None {online_fail(self, "The relay configuration is invalid."); return}
    cfg := rgd.Party_Config{service = service, namespace = "replay-cavecrawl-rooms", content = game.CONTENT, endpoint = endpoint,
                            invite_role = .Trusted_Peer, invite_uses = game.SEATS - 1, local_development = local, tls = self.online.tls, storage = storage, ice_json = ice,
                            relay_credentials = cave_int("REPLAY_CAVE_ROOM_RELAY", 0) == 1}
	interval:=cave_int("REPLAY_CAVE_ROOM_CHECKPOINT_MS",0)
	if interval<0 {online_fail(self,"The party checkpoint interval is invalid.");return}
	cfg.checkpoint_interval_ms=u64(interval)
    if !ok || !rgd.party_open(&self.online.party, cfg) {online_fail(self, "Party credentials could not be opened. Existing data was kept.")}
}
online_begin :: proc(self: ^ReplayCave, create: bool, rejoin: bool = false) {
    o := &self.online
    if !o.enabled || !o.recent_loaded || o.active || self.ready || !self.name_loaded || !lobby_pick_name(self) {return}
    ticket: prov.Ticket
    if !create && !rejoin {
        text := gd.line_edit_get_text(self.online_code); defer gd.free_string(text)
        valid: bool; ticket, valid = prov.ticket_parse(gd.gd_string_to_odin(text))
        if !valid {online_notice(self, "Paste a complete party invite."); return}
    }
    if !rgd.party_begin(&o.party, rejoin ? .Rejoin : create ? .Create : .Join, ticket) {online_notice(self, rgd.party_message(&o.party)); return}
    self.use_lobby, self.menu_launch = true, true
    online_notice(self, rejoin ? "Rejoining the recent party…" : create ? "Creating a party…" : "Joining the party…")
}
online_frame :: proc(self: ^ReplayCave) {
    o := &self.online; if !o.enabled {return}
    was_active := o.active
    rgd.party_frame(&o.party)
    if o.failed {message := rgd.party_message(&o.party); if message != "" {online_notice(self, message)}; return}
    if !was_active || !o.party.ready {return}
    if o.invited {gd.set_string(self.online_code, "text", fmt.ctprintf("%s", string(o.code[:])))}
    o.launch = true
    replay_cave_connect(self, o.grant.identity.member == 1 ? "host" : "client", false)
    o.launch = false
    if self.ready {online_notice(self, "Party joined. Friends with the invite can keep it running if you disconnect.")}
}
online_status :: proc(self: ^ReplayCave) {
	o := &self.online
	if o.enabled && self.ready && self.room.ready && !self.room.session.ready {
		message:=rgd.room_restore_message(&self.room.restore)
		if message!="" {gd.set_string(self.lobby_status,"text",fmt.ctprintf("%s",message))}
	}
	if o.enabled && self.ready && self.room.ready {
		button:=cast(gd.Base_Button)gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Save")
		gd.canvas_item_set_visible(button,self.session.authority)
		gd.set_string(button,"text","Store party checkpoint")
		gd.base_button_set_disabled(button,self.room.save.phase==.Checking || self.room.save.phase==.Uploading)
		if self.room.save.phase==.Checking || self.room.save.phase==.Uploading {gd.set_text(cast(gd.Object)self.prompt,"Storing party checkpoint…")}
		else if self.room.save.phase==.Failed || self.room.save.phase==.Interrupted {gd.set_text(cast(gd.Object)self.prompt,"Checkpoint status is uncertain. Try storing it again.")}
	}
	gd.canvas_item_set_visible(self.online_code, o.enabled)
	gd.line_edit_set_editable(self.online_code, !self.ready && !o.active)
	gd.canvas_item_set_visible(gd.get_node(self.owner, "Lobby/Panel/Column/PartyHint"), o.enabled)
	gd.set_string(gd.get_node(self.owner, "Lobby/Panel/Column/PartyHint"), "text", o.invite_error != .None ? "The invitation is unavailable. Existing members can still rejoin." : "Friends with the invite can keep the party running if you disconnect.")
	gd.canvas_item_set_visible(gd.get_node(self.owner, "Lobby/Panel/Column/Buttons/Rejoin"), o.enabled && !self.ready && o.recent_room != 0)
	gd.canvas_item_set_visible(gd.get_node(self.owner, "Lobby/Panel/Column/Buttons/CopyInvite"), o.enabled && o.invited)
	if o.enabled {
		gd.canvas_item_set_visible(self.lobby_address, false); gd.canvas_item_set_visible(self.lobby_port, false)
		for name in ([5]cstring{"Solo", "Host", "Resume", "Join", "Rejoin"}) {
			button := cast(gd.Base_Button)gd.get_node(self.owner, fmt.ctprintf("Lobby/Panel/Column/Buttons/%s", name))
			gd.canvas_item_set_visible(button, !self.ready && (string(name) != "Rejoin" || o.recent_room != 0))
			gd.base_button_set_disabled(button, o.active || !o.recent_loaded || !self.name_loaded)
		}
		gd.set_string(gd.get_node(self.owner, "Lobby/Panel/Column/Buttons/Host"), "text", "Create party")
		gd.set_string(gd.get_node(self.owner, "Lobby/Panel/Column/Buttons/Join"), "text", "Join party")
		if (o.active || o.failed || !self.ready) && o.notice != "" {gd.set_string(self.lobby_status, "text", fmt.ctprintf("%s", o.notice))}
		if self.ready && self.room.restore.phase==.Failed && !self.room.session.ready {
			button:=cast(gd.Base_Button)gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Resume")
			gd.canvas_item_set_visible(button,true);gd.base_button_set_disabled(button,false);gd.set_string(button,"text","Retry party recovery")
		}
	}
}
@(gd_method)
replay_cave_on_rejoin_party :: proc(self: ^ReplayCave) {online_begin(self, false, true)}
@(gd_method)
replay_cave_on_copy_invite :: proc(self: ^ReplayCave) {
	if !self.online.invited {return}
	text := gd.new_string_odin(string(self.online.code[:])); defer gd.free_string(text)
	gd.display_server_clipboard_set(gd.singleton_display_server(), text)
}
@(gd_method)
replay_cave_online_probe :: proc(self: ^ReplayCave, key: string) -> gd.Int {
	if key=="authority" {return gd.Int(self.room.session.ready && self.room.session.authority)}
	if key=="restore_candidate_tick" {return gd.Int(self.room.restore.prepared.point.archive.tick)}
	if key=="restore_phase" {return gd.Int(self.room.restore.phase)}
	if key=="restore_error" {return gd.Int(self.room.restore.error)}
	if key=="restore_authority_error" {return gd.Int(self.room.restore.authority_error)}
	if key=="restore_publication" {return gd.Int(self.room.recovery.from_publication)}
	if key=="restore_tick" {return gd.Int(self.room.recovery.checkpoint_tick)}
	if key=="restore_known_tick" {return gd.Int(self.room.recovery.service_known_tick)}
	if key=="save_phase" {return gd.Int(self.room.save.phase)}
	if key=="save_completed" {return gd.Int(self.room.save.completed)}
	if key=="save_revision" {return gd.Int(self.room.save.publication.revision)}
	if key=="save_epoch" {return gd.Int(self.room.save.publication.point.scope.epoch)}
	if key=="save_tick" {return gd.Int(self.room.save.publication.point.archive.tick)}
	if key=="save_error" {return gd.Int(self.room.save.error)}
	if key=="save_uncertain" {return gd.Int(self.room.save.uncertain)}
	if key == "relay_revision" {return gd.Int(self.online.relay.revision)}
	if key == "relay_error" {return gd.Int(self.online.relay.error)}
	switch key {case "enabled": return gd.Int(self.online.enabled); case "recent": return gd.Int(self.online.recent_loaded); case "profile": return gd.Int(self.online.profile.value.phase); case "failed": return gd.Int(self.online.failed); case "invited": return gd.Int(self.online.invited)}
	return 0
}
online_close :: proc(self: ^ReplayCave) {
    rgd.party_close(&self.online.party); online_native_close(self); online_unref(self.online.tls)
    delete(self.online.notice); self.online = {}
}
