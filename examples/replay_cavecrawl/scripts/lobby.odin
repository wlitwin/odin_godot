package replay_cavecrawl
import "core:fmt"
import "core:strings"
import gd "godot:godot"
import lb "godot:replay/lobby"
import rgd "godot:replay/godot"
import game "../shared/cave"
import co "godot:replay/comms"
import debuggd "godot:replay/godot/debug"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

lobby_ready :: proc(self:^ReplayCave) {
	gd.connect_to(self.lobby_name,"text_submitted",self.owner,"on_name_submit")
	for binding in ([8][2]cstring{{"Solo","on_solo"},{"Host","on_host"},{"Join","on_join"},{"Resume","on_resume"},{"Ready","on_ready_button"},{"Start","on_start"},{"Leave","on_leave"},{"Save","on_save_button"}}) {
		gd.connect_to(gd.get_node(self.owner,fmt.ctprintf("Lobby/Panel/Column/Buttons/%s",binding[0])),"pressed",self.owner,binding[1])
	}
	initial,_:=lb.name(cave_param("REPLAY_CAVE_NAME","Spelunker"))
	if !lb.name_valid(initial,false) {initial=lb.seat_name(1)}
	enabled:=cave_int("REPLAY_CAVE_PERSIST",len(cave_param("REPLAY_CAVE_TOKEN",""))==0 && len(cave_param("REPLAY_CAVE_NAME",""))==0 ? 1 : 0)==1
	storagegd.name_profile_open(&self.name_profile,cave_param("REPLAY_CAVE_NAME_PATH","user://display_name"),cave_param("REPLAY_CAVE_PROFILE_NAMESPACE","replay-cavecrawl"),enabled,initial)
	gd.set_string(self.lobby_address,"text",fmt.ctprintf("%s",cave_param("REPLAY_CAVE_ADDRESS","127.0.0.1")))
	gd.range_set_value(self.lobby_port,f64(cave_int("REPLAY_CAVE_PORT",49422)))
	lobby_frame(self)
}
lobby_pick_name :: proc(self:^ReplayCave)->bool {
	value:=gd.line_edit_get_text(self.lobby_name);defer gd.free_string(value)
	return lobby_update_name(self,gd.gd_string_to_odin(value))
}
lobby_update_name :: proc(self:^ReplayCave,text:string)->bool {
	name,ok:=lb.name(text);if !ok {gd.set_string(self.lobby_status,"text","Enter a valid name.");return false}
	self.profile_name=name
	// Corrupt/conflicting preference storage does not overwrite the old file.
	// A session can still use the explicitly entered display name.
	storagegd.name_profile_set(&self.name_profile,name)
	return true
}
@(gd_method)
replay_cave_on_name_submit :: proc(self:^ReplayCave,text:string) {
	if !lobby_update_name(self,text) {return}
	self.profile_retry=0;self.chat_submitted=true
	gd.control_release_focus(self.lobby_name)
}
lobby_connect :: proc(self:^ReplayCave,role:string,resume:bool=false) {
	if self.online.active {return}
	if !self.name_loaded || !lobby_pick_name(self) {return}
	self.use_lobby,self.menu_launch=true,true
	replay_cave_connect(self,role,resume)
}
@(gd_method)
replay_cave_on_solo :: proc(self:^ReplayCave) {lobby_connect(self,"solo")}
@(gd_method)
replay_cave_on_host :: proc(self:^ReplayCave) {if self.online.enabled {online_begin(self, true)} else {lobby_connect(self,"host")}}
@(gd_method)
replay_cave_on_join :: proc(self:^ReplayCave) {if self.online.enabled {online_begin(self, false)} else {lobby_connect(self,"client")}}
@(gd_method)
replay_cave_on_resume :: proc(self:^ReplayCave) {
	if self.online.enabled && self.room.ready && self.room.restore.phase==.Failed {rgd.room_restore_retry(&self.room);return}
	lobby_connect(self,gd.IS_WEB ? "solo" : "host",true)
}
@(gd_method)
replay_cave_on_save_button :: proc(self:^ReplayCave) {replay_cave_save(self)}
@(gd_method)
replay_cave_on_ready_button :: proc(self:^ReplayCave) {
	if !lobby_pick_name(self) {return}
	frame,ok:=rgd.session_authority_state(self.session);seat:=rgd.session_seat(self.session)
	if !ok || seat==0 {return}
	bit:=u64(1)<<uint(seat-1)
	replay_cave_issue(self,{verb=.Lobby,lobby={verb=.Ready,name=self.profile_name,ready=frame.state.lobby.ready & bit==0}})
}
@(gd_method)
replay_cave_on_start :: proc(self:^ReplayCave) {
	frame,ok:=rgd.session_authority_state(self.session);if !ok {return}
	self.lobby_menu_open=false;replay_cave_show_score(self,false)
	replay_cave_issue(self,{verb=.Lobby,lobby={verb=frame.state.won ? .Restart : .Start}})
}
lobby_waiting :: proc(self:^ReplayCave)->bool {
	frame,ok:=rgd.session_authority_state(self.session)
	return !ok || frame.state.lobby.phase==.Waiting
}
lobby_frame :: proc(self:^ReplayCave) {
	storagegd.name_profile_frame(&self.name_profile)
	if !self.name_loaded && self.name_profile.phase!=.Reading {
		self.profile_name=self.name_profile.value
		if override:=cave_param("REPLAY_CAVE_NAME","");override!="" {if chosen,ok:=lb.name(override);ok {self.profile_name=chosen;storagegd.name_profile_set(&self.name_profile,chosen)}}
		self.name_loaded=true
		gd.set_string(self.lobby_name,"text",fmt.ctprintf("%s",lb.text(&self.profile_name)))
	}
	if self.lobby_panel==nil {return}
	frame,available:=rgd.session_authority_state(self.session)
	playing:=available && frame.state.lobby.phase==.Playing && !frame.state.won
	won:=available && frame.state.won
	gd.set_string(gd.get_node(self.owner,"Lobby/Panel/Column/Title"),"text",won ? "THE CAVE IS CONQUERED" : "GATHER THE PARTY")
	gd.control_set_offset(self.lobby_panel,.Top,won ? 530 : 235)
	gd.canvas_item_set_visible(gd.get_node(self.owner,"Lobby/Panel/Column/NameLabel"),!won)
	gd.canvas_item_set_visible(self.lobby_name,!won);gd.canvas_item_set_visible(self.lobby_roster,!won)
	if won {replay_cave_show_score(self,true)}
	gd.canvas_item_set_visible(self.lobby_panel,!playing || self.lobby_menu_open)
	gd.canvas_item_set_visible(gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Leave"),self.ready)
	gd.canvas_item_set_visible(self.stage,available && frame.state.lobby.phase==.Playing)
	gd.canvas_item_set_visible(self.inventory,available && frame.state.lobby.phase==.Playing)
	gd.canvas_item_set_visible(self.prompt,available && frame.state.lobby.phase==.Playing)
	gd.canvas_item_set_visible(gd.get_node(self.owner,"Help"),available && frame.state.lobby.phase==.Playing)
	gd.canvas_item_set_visible(gd.get_node(self.owner,"Social/Chat"),self.ready)
	configured:=cave_int("REPLAY_CAVE_COORD_PORT",0)>0 || cave_param("REPLAY_CAVE_COORD_URL","")!=""
	for name in ([4]cstring{"Solo","Host","Join","Resume"}) {
		button:=cast(gd.Base_Button)gd.get_node(self.owner,fmt.ctprintf("Lobby/Panel/Column/Buttons/%s",name))
		visible:=!self.ready
		if string(name)=="Resume" {visible=visible && !configured}
		if gd.IS_WEB && (string(name)=="Host" || string(name)=="Join") {visible=visible && configured}
		gd.canvas_item_set_visible(button,visible);gd.base_button_set_disabled(button,!self.name_loaded)
	}
	gd.canvas_item_set_visible(self.lobby_address,!self.ready && !gd.IS_WEB);gd.canvas_item_set_visible(self.lobby_port,!self.ready && !gd.IS_WEB)
	if gd.IS_WEB && !self.ready && !configured {gd.set_string(self.lobby_status,"text","Play solo, or open a room invite to play with friends.")}
	ready_button:=cast(gd.Base_Button)gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Ready")
	start_button:=cast(gd.Button)gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Start")
	gd.canvas_item_set_visible(ready_button,available && frame.state.lobby.phase==.Waiting)
	seat:=rgd.session_seat(self.session)
	leader:=available && seat!=0 && frame.state.lobby.leader==seat
	gd.canvas_item_set_visible(start_button,leader && (frame.state.lobby.phase==.Waiting || frame.state.won))
	gd.base_button_set_disabled(start_button,!leader || (!frame.state.won && !lb.all_ready(&frame.state.lobby)))
	gd.set_string(start_button,"text",available && frame.state.won ? "Another run" : "Start")
	gd.line_edit_set_editable(self.lobby_name,self.name_loaded && (!available || frame.state.lobby.phase==.Waiting))
	if available {
		lobby:=frame.state.lobby
		builder:strings.Builder;defer strings.builder_destroy(&builder)
		for value,i in lobby.names {
			bit:=u64(1)<<uint(i);if lobby.present & bit==0 {continue}
			name:=value;fmt.sbprintf(&builder,"%s%s  —  %s\n",lb.text(&name),lobby.leader==u16(i+1) ? " (party leader)" : "",lobby.ready & bit!=0 ? "Ready" : "Not ready")
		}
		gd.set_string(self.lobby_roster,"text",fmt.ctprintf("%s",strings.to_string(builder)))
		gd.set_string(self.lobby_status,"text",frame.state.won ? "The cave is conquered." : playing ? "Run in progress. Escape returns to the cave." : lobby.automatic ? "The run starts when everyone is ready." : "Ready up. The party leader starts the run.")
		wants_profile:=self.use_lobby || lobby.phase==.Waiting || cave_param("REPLAY_CAVE_NAME","")!=""
		now:=gd.time_get_ticks_msec(gd.singleton_time())
		if self.name_loaded && wants_profile && seat>0 && lobby.names[seat-1]!=self.profile_name && now>=self.profile_retry {
			self.profile_retry=now+1000;replay_cave_issue(self,{verb=.Lobby,lobby={verb=.Profile,name=self.profile_name}})
		}
		gd.base_button_set_disabled(ready_button,seat==0 || (seat>0 && lobby.names[seat-1]!=self.profile_name))
	} else if self.ready {gd.set_string(self.lobby_status,"text","Connecting…")}
	when !gd.IS_WEB {gd.canvas_item_set_visible(gd.get_node(self.owner,"Lobby/Panel/Column/Buttons/Save"),self.ready && self.session.authority && !self.room.ready)}
	browser_cave_status(self)
	online_status(self)
	if self.moderation.removed {gd.set_string(self.lobby_status,"text","You were removed from this party. Rejoining is blocked.")}
	if self.name_profile.failed {gd.set_string(gd.get_node(self.owner,"Lobby/Panel/Column/ProfileStatus"),"text","Name preference could not be loaded or saved. Existing data was kept.")}
}
@(gd_method)
replay_cave_lobby_probe :: proc(self:^ReplayCave,key:string,seat:gd.Int)->gd.Int {
	if key=="profile_ready" {return gd.Int(self.name_loaded)}
	if key=="profile_pending" {return gd.Int(self.name_profile.phase!=.Ready || self.name_profile.dirty)}
	if key=="profile_error" {return gd.Int(self.name_profile.failed)}
	frame,ok:=rgd.session_authority_state(self.session);if !ok {return -1}
	switch key {
	case "phase":return gd.Int(frame.state.lobby.phase)
	case "leader":return gd.Int(frame.state.lobby.leader)
	case "ready":return gd.Int(frame.state.lobby.ready)
	case "run":return gd.Int(frame.state.lobby.run)
	}
	return -1
}

@(gd_method)
replay_cave_on_leave :: proc(self:^ReplayCave) {
	when gd.IS_WEB {if self.browser.save.phase==.Writing {return};rgd.browser_checkpoint_close(&self.browser.save);self.browser.seen_receipt=0}

	cave_feedback_destroy(self)
	if self.room.ready {rgd.room_close(&self.room)} else {rgd.session_close(self.session)}
	rgd.relay_close(&self.online.relay)
	self.session=&self.standalone
	debuggd.session_diagnostics_frame(&self.diagnostics,self.session)
	scenegd.nodes_destroy(&self.players);scenegd.nodes_destroy(&self.chest);scenegd.nodes_destroy(&self.door);scenegd.nodes_destroy(&self.relic)
	scenegd.nodes_destroy(&self.dwellers);scenegd.nodes_destroy(&self.pickups);scenegd.nodes_destroy(&self.rocks)
	if self.scenery!=nil {gd.node_queue_free(self.scenery)};self.scenery=nil;self.scenery_depth,self.scenery_seed=0,0
	for &mark in self.marks {if mark.node!=nil {gd.node_queue_free(mark.node)};mark={}}
	co.destroy(&self.comms);co.init(&self.comms)
	self.ready,self.walking,self.lobby_menu_open,self.score_open=false,false,false,false
	self.moderation.pending=false;self.moderation.roster=0
	gd.canvas_item_set_visible(self.moderation.panel,false)
	self.motion={};self.rock_phase={}
	gd.canvas_item_set_visible(self.score_panel,false);gd.set_string(self.chat_lines,"text","");gd.set_string(self.chat_notice,"text","")
	self.chat_revision,self.profile_retry,self.mark_received=0,0,0
	self.accepted,self.rejected,self.effects,self.last_verdict,self.verdict_epoch=0,0,0,0,0
	gd.set_string(self.lobby_status,"text","Disconnected. Start or join another party.");lobby_frame(self)
}

@(gd_method)
replay_cave_lobby_name :: proc(self:^ReplayCave,seat:gd.Int)->string {
	frame,ok:=rgd.session_authority_state(self.session);if !ok || seat<1 || seat>game.SEATS {return ""}
	return strings.clone(lb.text(&frame.state.lobby.names[seat-1]),context.temp_allocator)
}
