package replay_quickdraw

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import lb "godot:replay/lobby"
import game "../shared/duel"

Quickdraw_UI :: struct {
 lobby,score_panel:gd.Control,
 name,address,chat_input,save_path:gd.Line_Edit,
 port:gd.Spin_Box,
 notice,roster,chat_notice,save_notice:gd.Label,
 chat_lines:gd.Rich_Text_Label,
 start,leave,save:gd.Button,
 resume:[2]gd.Button,
 doors:[4]gd.Button,
 cells:[game.SEATS][5]gd.Label,
 revision:u64,
 submitted,was_playing:bool,
}
ui_notice :: proc(self:^ReplayQuickdraw,text:string) {gd.set_string(self.ui[0].notice,"text",fmt.ctprintf("%s",text))}
ui_ready :: proc(self:^ReplayQuickdraw) {
 u:=&self.ui[0]
 u.save_path=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Lobby/Column/Saved/Path")
 u.save_notice=cast(gd.Label)gd.get_node(self.owner,"UI/SaveNotice")
 u.save=cast(gd.Button)gd.get_node(self.owner,"UI/Save")
 gd.connect_to(u.save,"pressed",self.owner,"on_save")
 for label,i in ([2]cstring{"Solo","Host"}) {u.resume[i]=cast(gd.Button)gd.get_node(self.owner,fmt.ctprintf("UI/Lobby/Column/Resume/%s",label))}
 gd.connect_to(u.resume[0],"pressed",self.owner,"on_resume_solo");gd.connect_to(u.resume[1],"pressed",self.owner,"on_resume_host")
 gd.set_string(u.save_path,"text",fmt.ctprintf("%s",gd.IS_WEB ? quickdraw_param("RQ_SAVE_SLOT","duel") : quickdraw_param("RQ_SAVE","user://quickdraw.replay")))
 rgd.bind_key("rq_save",.F5)
 u.lobby=cast(gd.Control)gd.get_node(self.owner,"UI/Lobby")
 u.name=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Lobby/Column/Name/Value")
 u.address=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Lobby/Column/Address/Value")
 u.port=cast(gd.Spin_Box)gd.get_node(self.owner,"UI/Lobby/Column/Address/Port")
 u.notice=cast(gd.Label)gd.get_node(self.owner,"UI/Lobby/Column/Notice")
 u.roster=cast(gd.Label)gd.get_node(self.owner,"UI/Lobby/Column/Roster")
 u.start=cast(gd.Button)gd.get_node(self.owner,"UI/Lobby/Column/Start")
 u.leave=cast(gd.Button)gd.get_node(self.owner,"UI/Leave")
 u.chat_input=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Chat/Column/Input")
 u.chat_lines=cast(gd.Rich_Text_Label)gd.get_node(self.owner,"UI/Chat/Column/Lines")
 u.chat_notice=cast(gd.Label)gd.get_node(self.owner,"UI/Chat/Column/Notice")
 u.score_panel=cast(gd.Control)gd.get_node(self.owner,"UI/Scoreboard")
 grid:=gd.get_node(self.owner,"UI/Scoreboard/Column/Grid")
 for title in ([5]cstring{"PLAYER","KILLS","DEATHS","GOLD","PING"}) {label:=gd.new_label();gd.add_child(grid,label);gd.set_string(label,"text",title)}
 for row in 0..<game.SEATS {for column in 0..<5 {
  label:=gd.new_label();gd.add_child(grid,label);u.cells[row][column]=label
  gd.control_set_custom_minimum_size(label,{column==0 ? 160 : 45,0})
  gd.label_set_clip_text(label,true)
 }}
 for label,i in ([4]cstring{"Solo","Host","Join","Watch"}) {u.doors[i]=cast(gd.Button)gd.get_node(self.owner,fmt.ctprintf("UI/Lobby/Column/Buttons/%s",label))}
 for method,i in ([4]cstring{"on_solo","on_host","on_join","on_watch"}) {gd.connect_to(u.doors[i],"pressed",self.owner,method)}
 gd.connect_to(u.start,"pressed",self.owner,"on_start");gd.connect_to(u.leave,"pressed",self.owner,"on_leave")
 gd.connect_to(u.chat_input,"text_submitted",self.owner,"on_chat")
 rgd.bind_key("rq_chat",.Enter);rgd.bind_key("rq_scores",.Tab)
 profile_ready(self)
 gd.set_string(u.address,"text",fmt.ctprintf("%s",quickdraw_param("RQ_ADDRESS","127.0.0.1")))
 gd.range_set_value(u.port,f64(quickdraw_int("RQ_PORT",49460)))
 gd.rich_text_label_set_use_bbcode(u.chat_lines,false)
 ui_frame(self)
}
@(gd_method)
replay_quickdraw_on_solo :: proc(self:^ReplayQuickdraw) {connect_duel(self,"solo",false)}
@(gd_method)
replay_quickdraw_on_host :: proc(self:^ReplayQuickdraw) {if self.online.enabled {online_begin(self,.Create)} else {connect_duel(self,"host",true)}}
@(gd_method)
replay_quickdraw_on_join :: proc(self:^ReplayQuickdraw) {if self.online.enabled {online_begin(self,.Join)} else {connect_duel(self,"client",true)}}
@(gd_method)
replay_quickdraw_on_watch :: proc(self:^ReplayQuickdraw) {if self.online.enabled {online_begin(self,.Join,true)} else {connect_duel(self,"observer",true)}}
@(gd_method)
replay_quickdraw_on_start :: proc(self:^ReplayQuickdraw) {
 if !self.ready {return}
 _,err:=issue(self,game.Action{start=true});if err!=.None {ui_notice(self,fmt.tprintf("Could not start: %v",err))}
}
@(gd_method)
replay_quickdraw_on_leave :: proc(self:^ReplayQuickdraw) {
 if !self.ready {return}
 when gd.IS_WEB {if !self.room.ready && self.browser_save[0].slot.phase==.Writing {gd.set_string(self.ui[0].save_notice,"text","Saving… wait before leaving.");return}}
 if self.room.ready {rgd.room_close(&self.room)} else {rgd.session_close(self.session)}
 self.session=&self.standalone
 feedback_restart(self)
 co.destroy(&self.comms);dg.destroy(&self.diagnostics);co.init(&self.comms);dg.init(&self.diagnostics)
 self.ready,self.stopping,self.seated,self.name_submitted=false,false,false,false
 self.name_sequence,self.view_epoch,self.painted_epoch,self.last_receipt=0,0,0,0
 self.drawn={};self.beam_time={};self.beam_id={};self.beam_aim={}
 self.local_shots,self.watched_shots,self.local_lobs,self.speculative_lobs=0,0,0,0
 self.last_lob,self.lob_pending_key,self.lob_visible_max_ms,self.lob_visible_count=0,0,0,0
 self.lob_held,self.lob_waiting=false,false;self.recovery_probe={}
 rgd.nodes_clear(&self.gunners);rgd.nodes_clear(&self.drones);rgd.nodes_clear(&self.bullets)
 self.saved_tick,self.saved_hash,self.restored_tick,self.restored_hash=0,0,0,0;self.restored_exact=false
 gd.set_string(self.ui[0].save_notice,"text","")
 self.ui[0].revision=0;self.ui[0].submitted=false;self.ui[0].was_playing=false
 gd.set_string(self.ui[0].chat_lines,"text","");gd.set_string(self.ui[0].chat_notice,"text","");gd.set_string(self.ui[0].chat_input,"text","")
 gd.control_release_focus(self.ui[0].chat_input);gd.canvas_item_set_visible(self.ui[0].score_panel,false)
 ui_notice(self,"Host a duel or join one.");ui_frame(self)
}
@(gd_method)
replay_quickdraw_on_chat :: proc(self:^ReplayQuickdraw,text:string) {
 if self.comms.local.spectator && !self.comms.local.observer_name_allowed {gd.set_string(self.ui[0].chat_notice,"text","Connecting named observer chat…");return}
 result:=co.say(&self.comms,text);self.ui[0].submitted=true
 if result==.None {gd.set_string(self.ui[0].chat_input,"text","");gd.control_release_focus(self.ui[0].chat_input);gd.set_string(self.ui[0].chat_notice,"text","")}
 else {gd.set_string(self.ui[0].chat_notice,"text",fmt.ctprintf("Not sent: %v",result))}
}
ui_input :: proc(self:^ReplayQuickdraw)->bool {
 u:=&self.ui[0]
 if gd.is_action_just_released("rq_scores") {gd.canvas_item_set_visible(u.score_panel,false)}
 if u.submitted {u.submitted=false;return true}
 if gd.control_has_focus(u.chat_input,false) {
  if gd.is_action_just_pressed("ui_cancel") {gd.control_release_focus(u.chat_input)}
  return true
 }
 if self.ready && gd.is_action_just_pressed("rq_save") {replay_quickdraw_on_save(self);return true}
 if self.ready && self.comms.enabled && (!self.comms.local.spectator || self.comms.local.observer_name_allowed) && gd.is_action_just_pressed("rq_chat") {gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/Chat"),true);gd.control_grab_focus(u.chat_input,false);return true}
 if self.ready && gd.is_action_just_pressed("rq_scores") {gd.canvas_item_set_visible(u.score_panel,true)}
 return (self.online.enabled && bool(gd.control_has_focus(self.online.code,false))) || bool(gd.control_has_focus(u.save_path,false)) || bool(gd.control_has_focus(u.name,false)) || bool(gd.control_has_focus(u.address,false)) || bool(gd.control_has_focus(gd.spin_box_get_line_edit(u.port),false))
}
ui_frame :: proc(self:^ReplayQuickdraw) {
 u:=&self.ui[0];if u.lobby==nil {return}
 defer {online_status(self);browser_save_status(self)}
 frame,ok:=rgd.session_authority_state(self.session)
 if ok {u.was_playing=frame.state.started}
 playing:=self.ready && (ok ? frame.state.started : self.room.ready && u.was_playing)
 gd.canvas_item_set_visible(u.lobby,!playing)
 for node in ([3]cstring{"Name","Address","Buttons"}) {gd.canvas_item_set_visible(gd.get_node(self.owner,fmt.ctprintf("UI/Lobby/Column/%s",node)),!self.ready)}
 gd.canvas_item_set_visible(u.leave,self.ready)
 for node in ([2]cstring{"Saved","Resume"}) {gd.canvas_item_set_visible(gd.get_node(self.owner,fmt.ctprintf("UI/Lobby/Column/%s",node)),!self.ready && !gd.IS_WEB)}
 for button in u.resume {gd.base_button_set_disabled(button,self.ready || quickdraw_int("RQ_COORD_PORT",0)!=0)}
 can_save:=self.ready && self.session.ready && self.session.authority && !self.room.ready && !gd.IS_WEB
 gd.canvas_item_set_visible(u.save,can_save);gd.base_button_set_disabled(u.save,!can_save || self.session.fenced)
 gd.canvas_item_set_visible(u.save_notice,self.ready && !self.room.ready)
 gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/Chat"),self.ready && (self.comms.line_count>0 || bool(gd.control_has_focus(u.chat_input,false))))
 for door in u.doors {gd.base_button_set_disabled(door,self.ready || !self.views_ready || !profile_available(self))}
 gd.line_edit_set_editable(u.name,!self.ready);gd.line_edit_set_editable(u.address,!self.ready)
 gd.control_set_mouse_filter(u.port,self.ready ? .Mouse_Filter_Ignore : .Mouse_Filter_Stop)
 leader:=ok ? game.leader(&frame.state) : 0;seat:=rgd.session_seat(self.session)
 gd.canvas_item_set_visible(u.start,self.ready && ok && !playing && seat>0 && seat==leader)
 gd.base_button_set_disabled(u.start,!ok || seat==0 || !self.name_submitted || self.session.fenced || (seat>0 && frame.state.names[seat-1]!=self.display_name))
 if !self.ready {gd.set_string(self.status,"text","Choose Solo, Host, Join or Watch.");gd.set_string(u.roster,"text","");return}
 if !self.room.ready && !self.session.authority && (self.session.client.phase==.Disconnected || self.session.client.phase==.Rejected) {ui_notice(self,"Connection ended — leave to open another duel.")}
 if !ok {
  if self.room.ready && u.was_playing {gd.set_string(self.status,"text","Host changing… reconnecting to the match.")}
  return
 }
 if seat>0 && !self.name_submitted {
  if frame.state.names[seat-1]==self.display_name {self.name_submitted=true} else {
   sequence,err:=issue(self,game.Action{name=self.display_name})
   if err==.None {self.name_submitted=true;self.name_sequence=sequence}
  }
 }
 builder:strings.Builder;defer strings.builder_destroy(&builder)
 for player,i in frame.state.players {if player.connected {
  if strings.builder_len(builder)>0 {strings.write_string(&builder,"\n")}
  fmt.sbprintf(&builder,"%s%s",lb.text(&frame.state.names[i]),i+1==int(leader) ? " (lead)" : "")
 }}
 gd.set_string(u.roster,"text",fmt.ctprintf("%s",strings.to_string(builder)))
}
social_frame :: proc(self:^ReplayQuickdraw) {
 frame,ok:=rgd.session_authority_state(self.session)
 rgd.session_comms_frame(&self.comms,self.session,ok ? frame.state.names[:] : nil,self.display_name)
 rgd.session_diagnostics_frame(&self.diagnostics,self.session)
 u:=&self.ui[0]
 if u.revision!=self.comms.history_serial {
  builder:strings.Builder;defer strings.builder_destroy(&builder)
  for entry,i in self.comms.lines[:self.comms.line_count] {
   e:=entry;if i>0 {strings.write_string(&builder,"\n")}
   if e.value.kind==.System {fmt.sbprintf(&builder,"* %s",string(e.value.text[:e.value.length]))}
   else {fmt.sbprintf(&builder,"%s%s: %s",e.name.length>0 ? lb.text(&e.name) : "Observer",e.seat==0 && e.name.length>0 ? " (observer)" : "",string(e.value.text[:e.value.length]))}
  }
  gd.set_string(u.chat_lines,"text",fmt.ctprintf("%s",strings.to_string(builder)));u.revision=self.comms.history_serial
 }
 for {receipt,found:=co.poll_result(&self.comms);if !found {break};if receipt.result!=.None {gd.set_string(u.chat_notice,"text",fmt.ctprintf("Message not sent: %v",receipt.result))}}
 named_ready:=!self.comms.local.spectator || self.comms.local.observer_name_allowed
 gd.line_edit_set_editable(u.chat_input,self.comms.enabled && named_ready)
 if !ok {return}
 for player,i in frame.state.players {
  for cell in u.cells[i] {gd.canvas_item_set_visible(cell,player.initialized)}
  if !player.initialized {continue}
  gd.set_string(u.cells[i][0],"text",fmt.ctprintf("%s%s",lb.text(&frame.state.names[i]),player.connected ? "" : " (left)"))
  gd.set_string(u.cells[i][1],"text",fmt.ctprintf("%d",player.kills));gd.set_string(u.cells[i][2],"text",fmt.ctprintf("%d",player.deaths));gd.set_string(u.cells[i][3],"text",fmt.ctprintf("%d",player.gold))
  ping:=dg.read(&self.diagnostics,u16(i+1));gd.set_string(u.cells[i][4],"text",ping.known && player.connected ? fmt.ctprintf("%d",ping.round_trip_ms) : "—")
 }
}

@(gd_method)
replay_quickdraw_ui_probe :: proc(self:^ReplayQuickdraw,key:string,wanted:gd.Int=1)->gd.Int {
 if key=="ready" {return gd.Int(self.ready)}
 if key=="chat_ready" {return gd.Int(self.comms.enabled)}
 if key=="chat_lines" {return gd.Int(self.comms.line_count)}
 if key=="named_observer" {return gd.Int(self.comms.local.spectator && self.comms.local.observer_name_allowed)}
 if key=="typing" {return gd.Int(gd.control_has_focus(self.ui[0].chat_input,false))}
 frame,ok:=rgd.session_authority_state(self.session);if key=="state_ready" {return gd.Int(ok)}
 if !ok {return -1}
 switch key {
 case "tick":return gd.Int(frame.tick)
 case "started":return gd.Int(frame.state.started)
 case "seat":return gd.Int(rgd.session_seat(self.session))
 case "players":n:=0;for player in frame.state.players {if player.connected {n+=1}};return gd.Int(n)
 }
 if wanted<1 || wanted>game.SEATS {return -1};p:=frame.state.players[wanted-1]
 switch key {case "connected":return gd.Int(p.connected);case "x":return gd.Int(p.position[0]);case "y":return gd.Int(p.position[1]);case "drone_x":return gd.Int(p.drone[0]);case "shots":return gd.Int(frame.state.shots);case "lobs":return gd.Int(frame.state.lobs);case "gold":return gd.Int(p.gold);case "boots":return gd.Int(p.boots);case "kills":return gd.Int(p.kills);case "deaths":return gd.Int(p.deaths);case "hp":return gd.Int(p.hp);case "dash":return gd.Int(p.dash_cd);case "ping_known":return gd.Int(dg.read(&self.diagnostics,u16(wanted)).known)}
 return -1
}
