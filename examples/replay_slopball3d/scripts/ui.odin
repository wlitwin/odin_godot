package replay_slopball3d

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import co "godot:replay/comms"
import dg "godot:replay/telemetry"
import lb "godot:replay/lobby"
import net "godot:replay/net"
import own "godot:replay/owned"
import game "../shared/pitch"
import debuggd "godot:replay/godot/debug"
import inputgd "godot:replay/godot/input"
import scenegd "godot:replay/godot/scene"

Slopball3D_UI :: struct {
 lobby,score_panel:gd.Control,
 viewport_size:gd.Vector2,
 name,address,chat_input,save_path:gd.Line_Edit,
 port:gd.Spin_Box,
 notice,roster,chat_notice,save_notice:gd.Label,
 chat_lines:gd.Rich_Text_Label,
 start,leave,save,again:gd.Button,
 doors:[4]gd.Button,
 resume:[2]gd.Button,
 cells:[game.SEATS][3]gd.Label,
 revision,epoch:u64,
 round_seen:u32,
 submitted,was_playing:bool,
}
ui_notice :: proc(self:^ReplaySlopball3d,text:string) {gd.set_string(self.ui[0].notice,"text",fmt.ctprintf("%s",text))}
ui_ready :: proc(self:^ReplaySlopball3d) {
 u:=&self.ui[0]
 u.lobby=cast(gd.Control)gd.get_node(self.owner,"UI/Lobby")
 u.save_path=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Lobby/Column/Saved/Path")
 u.save_notice=cast(gd.Label)gd.get_node(self.owner,"UI/SaveNotice")
 u.save=cast(gd.Button)gd.get_node(self.owner,"UI/Save")
 gd.connect_to(u.save,"pressed",self.owner,"on_save")
 gd.connect_to(gd.get_node(self.owner,"UI/Handoff"),"pressed",self.owner,"handoff")
 for label,i in ([2]cstring{"Solo","Host"}) {u.resume[i]=cast(gd.Button)gd.get_node(self.owner,fmt.ctprintf("UI/Lobby/Column/Resume/%s",label))}
 gd.connect_to(u.resume[0],"pressed",self.owner,"on_resume_solo");gd.connect_to(u.resume[1],"pressed",self.owner,"on_resume_host")
 gd.set_string(u.save_path,"text",fmt.ctprintf("%s",gd.IS_WEB ? slopball3d_param("RS3_SAVE_SLOT","pitch") : slopball3d_param("RS3_SAVE","user://slopball3d.replay")))
 inputgd.bind_key("rsl_save",.F5)
 u.name=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Lobby/Column/Name/Value")
 u.address=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Lobby/Column/Address/Value")
 u.port=cast(gd.Spin_Box)gd.get_node(self.owner,"UI/Lobby/Column/Address/Port")
 u.notice=cast(gd.Label)gd.get_node(self.owner,"UI/Lobby/Column/Notice")
 u.roster=cast(gd.Label)gd.get_node(self.owner,"UI/Lobby/Column/Roster")
 u.start=cast(gd.Button)gd.get_node(self.owner,"UI/Lobby/Column/Start")
 u.leave=cast(gd.Button)gd.get_node(self.owner,"UI/Leave")
 u.again=cast(gd.Button)gd.get_node(self.owner,"UI/Again");gd.connect_to(u.again,"pressed",self.owner,"on_again")
 u.chat_input=cast(gd.Line_Edit)gd.get_node(self.owner,"UI/Chat/Column/Input")
 u.chat_lines=cast(gd.Rich_Text_Label)gd.get_node(self.owner,"UI/Chat/Column/Lines")
 u.chat_notice=cast(gd.Label)gd.get_node(self.owner,"UI/Chat/Column/Notice")
 u.score_panel=cast(gd.Control)gd.get_node(self.owner,"UI/Scoreboard")
 grid:=gd.get_node(self.owner,"UI/Scoreboard/Column/Grid")
 for title in ([3]cstring{"PLAYER","TEAM","PING"}) {label:=gd.new_label();gd.add_child(grid,label);gd.set_string(label,"text",title)}
 for row in 0..<game.SEATS {for column in 0..<3 {
  label:=gd.new_label();gd.add_child(grid,label);u.cells[row][column]=label
  gd.control_set_custom_minimum_size(label,{column==0 ? 160 : 70,0})
  gd.label_set_clip_text(label,true)
 }}
 for label,i in ([4]cstring{"Solo","Host","Join","Watch"}) {u.doors[i]=cast(gd.Button)gd.get_node(self.owner,fmt.ctprintf("UI/Lobby/Column/Buttons/%s",label))}
 for method,i in ([4]cstring{"on_solo","on_host","on_join","on_watch"}) {gd.connect_to(u.doors[i],"pressed",self.owner,method)}
 gd.connect_to(u.start,"pressed",self.owner,"on_start");gd.connect_to(u.leave,"pressed",self.owner,"on_leave")
 gd.connect_to(u.chat_input,"text_submitted",self.owner,"on_chat")
 inputgd.bind_key("rsl_chat",.Enter);inputgd.bind_key("rsl_scores",.Tab)
 profile_ready(self)
 gd.set_string(u.address,"text",fmt.ctprintf("%s",slopball3d_param("RS3_ADDRESS","127.0.0.1")))
 gd.range_set_value(u.port,f64(slopball3d_int("RS3_PORT",49580)))
 gd.rich_text_label_set_use_bbcode(u.chat_lines,false)
 ui_frame(self)
}
@(gd_method)
replay_slopball3d_on_solo :: proc(self:^ReplaySlopball3d) {connect_pitch(self,"solo",false)}
@(gd_method)
replay_slopball3d_on_host :: proc(self:^ReplaySlopball3d) {if self.online.enabled {online_begin(self,.Create)} else {connect_pitch(self,"host",true)}}
@(gd_method)
replay_slopball3d_on_join :: proc(self:^ReplaySlopball3d) {if self.online.enabled {online_begin(self,.Join)} else {connect_pitch(self,"client",true)}}
@(gd_method)
replay_slopball3d_on_watch :: proc(self:^ReplaySlopball3d) {if self.online.enabled {online_begin(self,.Join,true)} else {connect_pitch(self,"observer",true)}}
@(gd_method)
replay_slopball3d_on_start :: proc(self:^ReplaySlopball3d) {
 if !self.ready {return}
 _,err:=issue(self,game.Action{start=true});if err!=.None {ui_notice(self,fmt.tprintf("Could not start: %v",err))}
}
@(gd_method)
replay_slopball3d_on_again :: proc(self:^ReplaySlopball3d) {
 if !self.ready {return};frame,ok:=rgd.session_authority_state(self.session);if !ok {return}
 _,err:=issue(self,game.Action{restart_round=frame.state.round})
 if err!=.None {ui_notice(self,fmt.tprintf("Could not restart: %v",err))}
}
@(gd_method)
replay_slopball3d_on_leave :: proc(self:^ReplaySlopball3d) {
 when gd.IS_WEB {if !self.room.ready && self.browser_save[0].slot.phase==.Writing {gd.set_string(self.ui[0].save_notice,"text","Saving… wait before leaving.");return}}
 if !self.ready {return}
 if self.room.ready {rgd.room_close(&self.room)} else {rgd.session_close(self.session)}
 self.session=&self.standalone
 co.destroy(&self.comms);dg.destroy(&self.diagnostics);co.init(&self.comms);dg.init(&self.diagnostics)
 self.ready,self.have_world,self.reported,self.name_submitted=false,false,false,false
 self.peak_y,self.peak_spin=0,0
 self.saved_tick,self.saved_hash,self.restored_tick,self.restored_hash=0,0,0,0;self.restored_exact,self.save_seeded,self.save_seed_checked=false,false,false;self.restored_ball={};self.save_seed={}
 gd.set_string(self.ui[0].save_notice,"text","")
 self.world[0]={};self.intent={};self.buttons={};self.kick_left=0
 self.started_ms,self.finished_ms,self.last_revision,self.name_sequence=0,0,0,0
 self.kicks,self.previews,self.goals_seen=0,0,0;self.recovery_probe={}
 self.ui[0].revision,self.ui[0].epoch=0,0;self.ui[0].round_seen=0;self.view_round=0;self.ui[0].submitted=false;self.ui[0].was_playing=false
 reset_bodies(self)
 gd.set_string(self.ui[0].chat_lines,"text","");gd.set_string(self.ui[0].chat_notice,"text","");gd.set_string(self.ui[0].chat_input,"text","")
 gd.control_release_focus(self.ui[0].chat_input);gd.canvas_item_set_visible(self.ui[0].score_panel,false)
 ui_notice(self,"Host a pitch or join one.");ui_frame(self)
}
@(gd_method)
replay_slopball3d_on_chat :: proc(self:^ReplaySlopball3d,text:string) {
 if self.comms.local.spectator && !self.comms.local.observer_name_allowed {gd.set_string(self.ui[0].chat_notice,"text","Connecting named observer chat…");return}
 result:=co.say(&self.comms,text);self.ui[0].submitted=true
 if result==.None {gd.set_string(self.ui[0].chat_input,"text","");gd.control_release_focus(self.ui[0].chat_input);gd.set_string(self.ui[0].chat_notice,"text","")}
 else {gd.set_string(self.ui[0].chat_notice,"text",fmt.ctprintf("Not sent: %v",result))}
}
ui_input :: proc(self:^ReplaySlopball3d)->bool {
 u:=&self.ui[0]
 if gd.is_action_just_released("rsl_scores") {gd.canvas_item_set_visible(u.score_panel,false)}
 if u.submitted {u.submitted=false;return true}
 if gd.control_has_focus(u.chat_input,false) {
  if gd.is_action_just_pressed("ui_cancel") {gd.control_release_focus(u.chat_input)}
  return true
 }
 if self.ready && self.comms.enabled && (!self.comms.local.spectator || self.comms.local.observer_name_allowed) && gd.is_action_just_pressed("rsl_chat") {gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/Chat"),true);gd.control_grab_focus(u.chat_input,false);return true}
 if self.ready && gd.is_action_just_pressed("rsl_save") {replay_slopball3d_on_save(self);return true}
 if self.ready && gd.is_action_just_pressed("rsl_scores") {gd.canvas_item_set_visible(u.score_panel,true)}
 return (self.online.enabled && bool(gd.control_has_focus(self.online.code,false))) || bool(gd.control_has_focus(u.save_path,false)) || bool(gd.control_has_focus(u.name,false)) || bool(gd.control_has_focus(u.address,false)) || bool(gd.control_has_focus(gd.spin_box_get_line_edit(u.port),false))
}
ui_frame :: proc(self:^ReplaySlopball3d) {
 u:=&self.ui[0];if u.lobby==nil {return};defer {room_ui(self);online_status(self);browser_save_status(self)}
 size:=gd.viewport_get_visible_rect(gd.node_get_viewport(self.owner)).size
 if size!=u.viewport_size && size.x>0 && size.y>0 {
  u.viewport_size=size;scale:=min(size.x/640,size.y/360)
  for path in ([2]cstring{"UI","HUD"}) {
   layer:=cast(gd.Canvas_Layer)gd.get_node(self.owner,path)
   gd.canvas_layer_set_scale(layer,{scale,scale})
   gd.canvas_layer_set_offset(layer,{(size.x-640*scale)/2,(size.y-360*scale)/2})
  }
 }
 frame,ok:=rgd.session_authority_state(self.session)
 if ok {
  epoch:=self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
  if u.epoch!=epoch {u.epoch=epoch;self.name_submitted=false;self.name_sequence=0}
  u.was_playing=frame.state.started
 }
 playing:=self.ready && (ok ? frame.state.started : self.room.ready && u.was_playing)
 gd.canvas_item_set_visible(u.lobby,!playing)
 for node in ([3]cstring{"Name","Address","Buttons"}) {gd.canvas_item_set_visible(gd.get_node(self.owner,fmt.ctprintf("UI/Lobby/Column/%s",node)),!self.ready)}
 gd.canvas_item_set_visible(u.leave,self.ready)
 for name in ([2]cstring{"Saved","Resume"}) {gd.canvas_item_set_visible(gd.get_node(self.owner,fmt.ctprintf("UI/Lobby/Column/%s",name)),!self.ready && !gd.IS_WEB)}
 for button in u.resume {gd.base_button_set_disabled(button,self.ready || !self.views_ready || slopball3d_int("RS3_COORD_PORT",0)!=0)}
 can_save:=self.ready && self.session.ready && self.session.authority && !self.room.ready && !gd.IS_WEB
 gd.canvas_item_set_visible(u.save,can_save);gd.base_button_set_disabled(u.save,!can_save || self.session.fenced)
 gd.canvas_item_set_visible(u.save_notice,self.ready && !self.room.ready && !gd.IS_WEB)
 gd.canvas_item_set_visible(gd.get_node(self.owner,"UI/Chat"),self.ready && (self.comms.line_count>0 || bool(gd.control_has_focus(u.chat_input,false))))
 for door in u.doors {gd.base_button_set_disabled(door,self.ready || !self.views_ready || !profile_available(self))}
 gd.line_edit_set_editable(u.name,!self.ready);gd.line_edit_set_editable(u.address,!self.ready)
 gd.control_set_mouse_filter(u.port,self.ready ? .Mouse_Filter_Ignore : .Mouse_Filter_Stop)
 leader:=ok ? game.leader(&frame.state) : 0;seat:=rgd.session_seat(self.session)
 gd.canvas_item_set_visible(u.start,self.ready && ok && !playing && seat>0 && seat==leader)
 count:=0;if ok {for player in frame.state.players {if player.connected {count+=1}}}
 gd.canvas_item_set_visible(u.again,self.ready && ok && frame.state.won!=0 && seat>0 && seat==leader)
 gd.base_button_set_disabled(u.again,!ok || count<int(frame.state.minimum) || self.session.fenced)
 gd.base_button_set_disabled(u.start,!ok || seat==0 || count<int(frame.state.minimum) || !self.name_submitted || self.session.fenced || (seat>0 && frame.state.names[seat-1]!=self.display_name))
 if !self.ready {gd.set_string(self.status,"text","Choose Solo, Host, Join or Watch.");gd.set_string(u.roster,"text","");return}
 if !self.room.ready && !self.session.authority && (self.session.client.phase==.Disconnected || self.session.client.phase==.Rejected) {ui_notice(self,"Connection ended — leave to open another pitch.")}
 if !ok {if self.room.ready && u.was_playing {gd.set_string(self.status,"text","Host changing… reconnecting to the match.")};return}
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
social_frame :: proc(self:^ReplaySlopball3d) {
 frame,ok:=rgd.session_authority_state(self.session)
 rgd.session_comms_frame(&self.comms,self.session,ok ? frame.state.names[:] : nil,self.display_name)
 debuggd.session_diagnostics_frame(&self.diagnostics,self.session)
 u:=&self.ui[0]
 if ok && self.session.authority && self.comms.enabled && u.round_seen!=frame.state.round {
  if u.round_seen!=0 {co.system(&self.comms,fmt.tprintf("Match %d starts",frame.state.round))}
  u.round_seen=frame.state.round
 }
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
 score:=frame.state
 gd.set_string(gd.get_node(self.owner,"UI/Scoreboard/Column/Score"),"text",fmt.ctprintf("LEFT %d — %d RIGHT",score.left,score.right))
 for player,i in frame.state.players {
  for cell in u.cells[i] {gd.canvas_item_set_visible(cell,player.initialized)}
  if !player.initialized {continue}
  gd.set_string(u.cells[i][0],"text",fmt.ctprintf("%s%s",lb.text(&frame.state.names[i]),player.connected ? "" : " (left)"))
  gd.set_string(u.cells[i][1],"text",game.team(u16(i+1))==1 ? "LEFT" : "RIGHT")
  ping:=dg.read(&self.diagnostics,u16(i+1));gd.set_string(u.cells[i][2],"text",ping.known && player.connected ? fmt.ctprintf("%d",ping.round_trip_ms) : "—")
 }
}

@(gd_method)
replay_slopball3d_ui_probe :: proc(self:^ReplaySlopball3d,key:string,wanted:gd.Int=1)->gd.Int {
 if key=="ready" {return gd.Int(self.ready)}
 if key=="ball_solver" {return gd.Int(scenegd.body3_simulating(&self.bodies[game.SEATS]))}
 if key=="chat_ready" {return gd.Int(self.comms.enabled)}
 if key=="named_observer" {return gd.Int(self.comms.local.spectator && self.comms.local.observer_name_allowed)}
 if key=="typing" {return gd.Int(gd.control_has_focus(self.ui[0].chat_input,false))}
 if key=="kicks" {return gd.Int(self.kicks)}
 frame,ok:=rgd.session_authority_state(self.session);if key=="state_ready" {return gd.Int(ok)};if !ok {return -1}
 w:=frame.state
 if key=="restart_seeded" {
  if w.round<2 || w.tick>=w.kickoff_until {return 0}
  for &body,i in self.bodies {
   if i<game.SEATS && !w.players[i].connected {continue}
   state:=i==game.SEATS ? w.ball : w.players[i].body
   expected:=i==game.SEATS ? own.Pose3{position={8,0.2,4.5},rotation={0,0,0,1}} : game.spawn(u16(i+1))
   actual:=scenegd.body3_read(&body)
   if body.driver.scope!=own.scope(state) || body.preview {return 0}
   for value,axis in actual.position {if abs(value-expected.position[axis])>0.001 {return 0}}
   for value in actual.linear {if abs(value)>0.001 {return 0}}
  }
  return 1
 }
 switch key {
 case "round":return gd.Int(w.round)
 case "handoffs":return gd.Int(w.handoffs)
 case "tick":return gd.Int(frame.tick)
 case "started":return gd.Int(w.started)
 case "seat":return gd.Int(rgd.session_seat(self.session))
 case "left":return gd.Int(w.left)
 case "right":return gd.Int(w.right)
 case "winner":return gd.Int(w.won)
 case "owner":return gd.Int(w.ball.owner)
 case "players":count:=0;for player in w.players {if player.connected {count+=1}};return gd.Int(count)
 }
 if wanted<1 || wanted>game.SEATS {return -1};player:=w.players[wanted-1]
 switch key {case "connected":return gd.Int(player.connected);case "named":return gd.Int(player.named);case "team":return gd.Int(game.team(u16(wanted)));case "x_mm":return gd.Int(player.body.value.position[0]*1000);case "z_mm":return gd.Int(player.body.value.position[2]*1000);case "ping_known":return gd.Int(dg.read(&self.diagnostics,u16(wanted)).known)}
 return -1
}
issue :: proc(self:^ReplaySlopball3d,a:game.Action)->(u64,net.Error) {if self.room.ready {return rgd.room_issue(&self.room,a)};return rgd.session_issue(self.session,a)}

reset_bodies :: proc(self:^ReplaySlopball3d) {
 for &body in self.bodies {
  if !body.ready {continue}
  node,kind,skin,origin,angle:=body.body,body.kind,body.skin,body.skin_origin,body.skin_rotation
  scenegd.body3_suspend(&body)
  if skin!=nil {gd.node3d_set_position(skin,origin);gd.node3d_set_quaternion(skin,angle)}
  scenegd.body3_destroy(&body)
  assert(scenegd.body3_attach(&body,node,kind,skin));scenegd.body3_suspend(&body)
  gd.node3d_set_visible(cast(gd.Node3d)node,false)
  gd.collision_object3d_set_collision_layer(cast(gd.Collision_Object3d)node,0)
  gd.collision_object3d_set_collision_mask(cast(gd.Collision_Object3d)node,0)
  if kind==.Character {gd.character_body3d_set_velocity(cast(gd.Character_Body3d)node,{})}
 }
}
