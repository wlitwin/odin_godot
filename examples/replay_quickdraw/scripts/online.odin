package replay_quickdraw

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import auth "godot:replay/authority"
import p "godot:replay/provision"
import rgd "godot:replay/godot"
import lb "godot:replay/lobby"
import game "../shared/duel"
import transportgd "godot:replay/godot/transport"

Quickdraw_Online :: struct {
 party:rgd.Party,
 enabled,launch,launching:bool,
 role:rgd.Session_Role,
 native:rawptr,
 tls:gd.Tls_Options,
 code:gd.Line_Edit,
 watch:gd.Base_Button,
 save_seen:u64,
}
online_unref :: proc(object:gd.Ref_Counted) {if object!=nil && gd.ref_counted_unreference(object) {gdext.object_destroy(object)}}
online_error :: proc(self:^ReplayQuickdraw,message:string) {self.online.party.failed=true;ui_notice(self,message)}
online_ready :: proc(self:^ReplayQuickdraw) {
 o:=&self.online
 gd.connect_to(gd.get_node(self.owner,"UI/Handoff"),"pressed",self.owner,"handoff")
 o.code=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Lobby/Column/Party/Code")
 o.watch=cast(gd.Base_Button)gd.get_node(self.owner,"UI/Lobby/Column/Party/Choices/Watch")
 gd.connect_to(gd.get_node(self.owner,"UI/Lobby/Column/Party/Choices/Rejoin"),"pressed",self.owner,"on_rejoin_party")
 gd.connect_to(gd.get_node(self.owner,"UI/Lobby/Column/Party/Choices/Copy"),"pressed",self.owner,"on_copy_party")
 gd.connect_to(gd.get_node(self.owner,"UI/CopyInvite"),"pressed",self.owner,"on_copy_party")
 service:=quickdraw_param("RQ_ROOM_SERVICE","");if service=="" {return};o.enabled=true
 local:=quickdraw_int("RQ_ROOM_LOCAL",0)==1;port:=quickdraw_int("RQ_PORT",49460)
 endpoint,valid:=auth.endpoint(quickdraw_param("RQ_ROOM_ADDRESS","127.0.0.1"),u16(port))
 if !valid || port<1 || port>65535 || !p.service_url_valid(service,local) {online_error(self,"The party service or gameplay address is invalid.");return}
 storage,ok:=online_native_init(self,local)
 ice,ice_error:=transportgd.rtc_ice_settings("RQ_ICE_JSON")
 if ice_error!=.None {online_error(self,"The relay configuration is invalid.");return}
 cfg:=rgd.Party_Config{service=service,namespace="replay-quickdraw-rooms",content=game.CONTENT,endpoint=endpoint,storage=storage,tls=o.tls,
  local_development=local,invite_role=.Trusted_Peer,invite_uses=game.SEATS-1,ice_json=ice,relay_credentials=quickdraw_int("RQ_ROOM_RELAY",0)==1}
 interval:=quickdraw_int("RQ_ROOM_CHECKPOINT_MS",0)
 if interval<0 {online_error(self,"The party save interval is invalid.");return};cfg.checkpoint_interval_ms=u64(interval)
 if !ok || !rgd.party_open(&o.party,cfg) {online_error(self,"Party credentials could not be opened. Existing data was kept.")}
 if !o.party.failed && !self.name_profile.failed {ui_notice(self,"Create a duel party or paste an invite to join.")}
 online_status(self)
}
online_begin :: proc(self:^ReplayQuickdraw,action:rgd.Party_Action,observer:bool=false) {
 o:=&self.online
 if !o.enabled || !o.party.recent_loaded || o.party.active || self.ready || !profile_available(self) {return}
 if self.name_profile.failed {ui_notice(self,"Could not use your saved player profile. Check its files before joining.");return}
 name:=gd.line_edit_get_text(self.ui[0].name);defer gd.free_string(name)
 if _,ok:=lb.name(gd.gd_string_to_odin(name));!ok {ui_notice(self,"Enter a display name.");return}
 ticket:p.Ticket
 if action==.Join {
  value:=gd.line_edit_get_text(o.code);defer gd.free_string(value)
  valid:bool;ticket,valid=p.ticket_parse(gd.gd_string_to_odin(value))
  if !valid {ui_notice(self,"Paste a complete party invite.");return}
 }
 if !rgd.party_begin(&o.party,action,ticket) {ui_notice(self,rgd.party_message(&o.party));return}
 watching:=observer || bool(gd.base_button_is_pressed(o.watch))
 o.role=action==.Create ? .Host : watching ? .Observer : .Client
 o.launching=false
}
online_frame :: proc(self:^ReplayQuickdraw) {
 o:=&self.online;if !o.enabled {return}
 rgd.party_frame(&o.party)
 if !o.party.ready || o.party.failed || o.launching || self.ready {return}
 if o.party.invited {gd.set_string(o.code,"text",fmt.ctprintf("%s",string(o.party.code[:])))}
 o.launch,o.launching=true,true
 o.save_seen=0
 connect_duel(self,o.role==.Host ? "host" : o.role==.Observer ? "observer" : "client",true)
 o.launch=false
}
online_status :: proc(self:^ReplayQuickdraw) {
 o:=&self.online
 handoff:=gd.get_node(self.owner,"UI/Handoff");recovery:=gd.get_node(self.owner,"UI/Recovery")
 gd.canvas_item_set_visible(handoff,self.room.ready && self.session.ready && self.session.authority)
 gd.base_button_set_disabled(cast(gd.Button)handoff,!self.room.ready || self.room.phase!=.Hosting || self.room.options.successor_seat==0)
 gd.canvas_item_set_visible(recovery,self.room.ready)
 if self.room.ready {
  status:=rgd.room_backup_status(&self.room)
  gd.set_string(recovery,"text",fmt.ctprintf("%s",rgd.room_recovery_message(&self.room,status)))
 }
 gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/Lobby/Column/Party"),o.enabled)
 gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/CopyInvite"),o.enabled && self.room.ready && o.party.invited)
 if !o.enabled {return}
 if !self.ready {gd.set_string(self.status,"text","Choose Solo, create a party or join with an invite.")}
 gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/Lobby/Column/Address"),false)
 gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/Lobby/Column/Saved"),false)
 gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/Lobby/Column/Resume"),false)
 gd.canvas_item_set_visible(self.ui[0].doors[3],false)
 gd.set_string(self.ui[0].doors[1],"text","CREATE PARTY");gd.set_string(self.ui[0].doors[2],"text","JOIN PARTY")
 busy:=self.ready || o.party.active || !o.party.recent_loaded || !profile_available(self)
 for button in self.ui[0].doors {gd.base_button_set_disabled(button,busy)}
 gd.line_edit_set_editable(o.code,!busy);gd.base_button_set_disabled(o.watch,busy)
 rejoin:=cast(gd.Base_Button)gd.get_node(self.owner,"UI/Lobby/Column/Party/Choices/Rejoin")
 gd.base_button_set_disabled(rejoin,busy || o.party.recent_room==0)
 copy:=gd.get_node(self.owner,"UI/Lobby/Column/Party/Choices/Copy");gd.canvas_item_set_visible(copy,o.party.invited)
 if message:=rgd.party_message(&o.party);message!="" {ui_notice(self,message)}
 if self.room.ready && !self.session.ready {
  if message:=rgd.room_restore_message(&self.room.restore);message!="" {ui_notice(self,message)}
  if self.room.restore.phase==.Failed {gd.base_button_set_disabled(rejoin,false);gd.set_string(rejoin,"text","Retry party recovery")}
 }
 if self.room.ready && self.session.ready {
  gd.canvas_item_set_visible(self.ui[0].save,self.session.authority)
  gd.base_button_set_disabled(self.ui[0].save,!self.session.authority || self.session.fenced || self.room.save.phase==.Checking || self.room.save.phase==.Uploading)
  gd.canvas_item_set_visible(self.ui[0].save_notice,true)
  if self.room.save.phase==.Checking || self.room.save.phase==.Uploading {gd.set_string(self.ui[0].save_notice,"text","Saving party progress…")}
  else if self.room.save.phase==.Failed || self.room.save.phase==.Interrupted {gd.set_string(self.ui[0].save_notice,"text","Party save status is uncertain. Try saving again.")}
  else if self.room.save.completed>o.save_seen {
   o.save_seen=self.room.save.completed;self.saved_tick=self.room.save.publication.point.archive.tick
   gd.set_string(self.ui[0].save_notice,"text","Party progress saved.")
  }
 }
}
@(gd_method)
replay_quickdraw_on_rejoin_party :: proc(self:^ReplayQuickdraw) {
 if self.room.ready && self.room.restore.phase==.Failed && !self.session.ready {rgd.room_restore_retry(&self.room);return}
 online_begin(self,.Rejoin)
}
@(gd_method)
replay_quickdraw_on_copy_party :: proc(self:^ReplayQuickdraw) {
 if !self.online.party.invited {return}
 value:=gd.new_string_odin(string(self.online.party.code[:]));defer gd.free_string(value)
 gd.display_server_clipboard_set(gd.singleton_display_server(),value)
}
@(gd_method)
replay_quickdraw_party_probe :: proc(self:^ReplayQuickdraw,key:string)->gd.Int {
 switch key {
 case "save_completed":return gd.Int(self.room.save.completed)
 case "save_revision":return gd.Int(self.room.save.publication.revision)
 case "save_tick":return gd.Int(self.room.save.publication.point.archive.tick)
 case "save_epoch":return gd.Int(self.room.save.publication.point.scope.epoch)
 case "save_error":return gd.Int(self.room.save.error)
 case "restore_error":return gd.Int(self.room.restore.error)
 case "restore_tick":return gd.Int(self.room.recovery.checkpoint_tick)
 case "restore_publication":return gd.Int(self.room.recovery.from_publication)
 case "profile_ready":return gd.Int(profile_available(self))
 case "profile_failed":return gd.Int(self.name_profile.failed || self.browser_identity.phase==.Failed)
 case "profile_saved":return gd.Int(!self.name_profile.failed && !self.name_profile.dirty && self.name_profile.phase==.Ready)
 case "relay_revision":return gd.Int(self.online.party.relay.revision)
 case "active":return gd.Int(self.online.party.active)
 case "recent":return gd.Int(self.online.party.recent_loaded)
 case "failed":return gd.Int(self.online.party.failed)
 case "invited":return gd.Int(self.online.party.invited)
 case "incarnation":return gd.Int(self.room.options.identity.incarnation)
 case "member":return gd.Int(self.room.options.identity.member)
 case "separate":return gd.Int(self.session!=nil && self.session.ready && self.session.token!=self.identity)
 case "observer":return gd.Int(self.session!=nil && self.session.ready && !self.session.authority && self.session.client.spectator)
 case "backup":return gd.Int(self.room.options.session.replication.accept_checkpoints)
 }
 return 0
}
online_close :: proc(self:^ReplayQuickdraw) {
 rgd.party_close(&self.online.party);online_native_close(self);online_unref(self.online.tls);self.online={}
}
