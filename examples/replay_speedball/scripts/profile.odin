package replay_speedball

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import net "godot:replay/net"
import lb "godot:replay/lobby"

// Identity and display name are local preferences, separate from the replicated
// pitch and authority archives. Explicit test tokens do not touch user profiles.
profile_ready :: proc(self:^ReplaySpeedball) {
 initial,_:=lb.name("Kicker")
 self.profile_enabled=speedball_param("RSB_TOKEN","")=="" && speedball_int("RSB_PERSIST",1)!=0
 when gd.IS_WEB {
  if self.profile_enabled {rgd.browser_identity_open(&self.browser_identity,"replay-speedball")}
  else {self.profile_token=rgd.session_token(speedball_param("RSB_TOKEN",""));self.profile_identity_ready=rgd.browser_identity_valid(self.profile_token)}
 } else {self.profile_identity_ready=true}
 path:=speedball_param("RSB_PROFILE","user://replay_speedball_identity")
 if !rgd.name_profile_open(&self.name_profile,fmt.tprintf("%s.name",path),"replay-speedball",self.profile_enabled,initial) {
  ui_notice(self,"Could not read your saved name. Check the profile file before joining.")
 }
 self.profile_name_loaded=self.name_profile.phase!=.Reading
 value:=self.name_profile.value
 if override:=speedball_param("RSB_NAME","");override!="" {if name,ok:=lb.name(override);ok {value=name}}
 gd.set_string(self.ui[0].name,"text",fmt.ctprintf("%s",lb.text(&value)))
}
profile_connect :: proc(self:^ReplaySpeedball,name:lb.Name)->(net.Token,bool) {
 if self.name_profile.failed {ui_notice(self,"Could not read or write your saved name. Check the profile file before joining.");return {},false}
 token:net.Token
 when gd.IS_WEB {token=self.profile_token} else {if self.profile_enabled {
  value,err:=rgd.session_profile(speedball_param("RSB_PROFILE","user://replay_speedball_identity"))
  if err!=.None {ui_notice(self,fmt.tprintf("Could not read or write your player identity: %v",err));return {},false}
  token=value
 } else {token=rgd.session_token(speedball_param("RSB_TOKEN",""))}}
 if !rgd.name_profile_set(&self.name_profile,name) {return {},false}
 rgd.name_profile_frame(&self.name_profile)
 if self.name_profile.failed {ui_notice(self,"Could not save your name. Check the profile file before joining.");return {},false}
 return token,true
}

observe_round :: proc(self:^ReplaySpeedball) {
 frame,ok:=rgd.session_authority_state(self.session)
 if !ok || self.view_round==frame.state.round {return}
 self.view_round=frame.state.round
 self.done,self.spiked,self.spike_visible,self.spike_node_start,self.own_spike_seen=false,false,false,false,false
 self.goal_seen=0;self.spike_first_sequence=0;self.flash_left=0;self.flash_id={}
 self.local_kicks,self.remote_kicks,self.speculative_kicks,self.local_canceled,self.remote_canceled=0,0,0,0,0
 self.spike_applied,self.spike_rejected=0,0
}

profile_available :: proc(self:^ReplaySpeedball)->bool {
 return self.profile_identity_ready && self.profile_name_loaded && !self.name_profile.failed
}
profile_frame :: proc(self:^ReplaySpeedball) {
 when gd.IS_WEB {
  if !self.profile_identity_ready && self.browser_identity.phase!=.Closed {
   rgd.browser_identity_frame(&self.browser_identity)
   if token,ok:=rgd.browser_identity_token(&self.browser_identity);ok {self.profile_token=token;self.profile_identity_ready=true}
  }
  rgd.name_profile_frame(&self.name_profile)
  if !self.profile_name_loaded && self.name_profile.phase!=.Reading {
   self.profile_name_loaded=true;value:=self.name_profile.value
   if override:=speedball_param("RSB_NAME","");override!="" {if name,ok:=lb.name(override);ok {value=name}}
   gd.set_string(self.ui[0].name,"text",fmt.ctprintf("%s",lb.text(&value)))
  }
  if self.name_profile.failed || self.browser_identity.phase==.Failed {
   if self.ready {gd.set_string(self.ui[0].chat_notice,"text","Could not save or load the browser profile.")}
   else {ui_notice(self,"Could not save or load the browser profile. Existing data was kept.")}
  }
  if self.browser_launch!="" && profile_available(self) {
   role:=self.browser_launch;self.browser_launch="";defer delete(role)
   connect_pitch(self,role,false,speedball_int("RSB_RESUME",0)==1)
  }
 }
}

@(gd_method)
replay_speedball_profile_hash :: proc(self:^ReplaySpeedball)->gd.String {
 hash:=net.token_hash(self.profile_token);hex:="0123456789abcdef";text:[64]u8
 for b,i in hash {text[i*2],text[i*2+1]=hex[b>>4],hex[b&15]}
 return gd.new_string_odin(string(text[:]))
}
