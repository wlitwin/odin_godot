package replay_claimball

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import rgd "godot:replay/godot"
import net "godot:replay/net"
import lb "godot:replay/lobby"

// Identity and display name are local preferences, separate from the replicated
// pitch and authority archives. Explicit test tokens do not touch user profiles.
profile_ready :: proc(self:^ReplayClaimball) {
 initial,_:=lb.name("Kicker")
 self.profile_enabled=claimball_param("RCB_TOKEN","")=="" && self.bot=="" && claimball_int("RCB_PERSIST",1)!=0
 when gd.IS_WEB {
  if self.profile_enabled {rgd.browser_identity_open(&self.browser_identity,"replay-claimball")}
  else {self.identity=rgd.session_token(claimball_param("RCB_TOKEN",""));self.profile_identity_ready=rgd.browser_identity_valid(self.identity)}
 } else {self.profile_identity_ready=true}
 path:=claimball_param("RCB_PROFILE","user://replay_claimball_identity")
 if !rgd.name_profile_open(&self.name_profile,fmt.tprintf("%s.name",path),"replay-claimball",self.profile_enabled,initial) {
  ui_notice(self,"Could not read your saved name. Check the profile file before joining.")
 }
 self.profile_name_loaded=self.name_profile.phase!=.Reading
 value:=self.name_profile.value
 if override:=claimball_param("RCB_NAME","");override!="" {if name,ok:=lb.name(override);ok {value=name}}
 gd.set_string(self.ui[0].name,"text",fmt.ctprintf("%s",lb.text(&value)))
}
profile_connect :: proc(self:^ReplayClaimball,name:lb.Name)->(net.Token,bool) {
 if self.name_profile.failed {ui_notice(self,"Could not read or write your saved name. Check the profile file before joining.");return {},false}
 token:net.Token
 when gd.IS_WEB {token=self.identity} else {if self.profile_enabled {
  value,err:=rgd.session_profile(claimball_param("RCB_PROFILE","user://replay_claimball_identity"))
  if err!=.None {ui_notice(self,fmt.tprintf("Could not read or write your player identity: %v",err));return {},false}
  token=value
 } else {token=self.identity}}
 if !rgd.name_profile_set(&self.name_profile,name) {return {},false}
 rgd.name_profile_frame(&self.name_profile)
 if self.name_profile.failed {ui_notice(self,"Could not save your name. Check the profile file before joining.");return {},false}
 return token,true
}

profile_available :: proc(self:^ReplayClaimball)->bool {
 return self.profile_identity_ready && self.profile_name_loaded && !self.name_profile.failed
}
profile_frame :: proc(self:^ReplayClaimball) {
 when gd.IS_WEB {
  if !self.profile_identity_ready && self.browser_identity.phase!=.Closed {
   rgd.browser_identity_frame(&self.browser_identity)
   if token,ok:=rgd.browser_identity_token(&self.browser_identity);ok {self.identity=token;self.profile_identity_ready=true}
  }
  rgd.name_profile_frame(&self.name_profile)
  if !self.profile_name_loaded && self.name_profile.phase!=.Reading {
   self.profile_name_loaded=true;value:=self.name_profile.value
   if override:=claimball_param("RCB_NAME","");override!="" {if name,ok:=lb.name(override);ok {value=name}}
   gd.set_string(self.ui[0].name,"text",fmt.ctprintf("%s",lb.text(&value)))
  }
  if self.name_profile.failed || self.browser_identity.phase==.Failed {
   if self.ready {gd.set_string(self.ui[0].chat_notice,"text","Could not save or load the browser profile.")}
   else {ui_notice(self,"Could not save or load the browser profile. Existing data was kept.")}
  }

 }
}

@(gd_method)
replay_claimball_profile_hash :: proc(self:^ReplayClaimball)->gd.String {
 hash:=net.token_hash(self.identity);hex:="0123456789abcdef";text:[64]u8
 for b,i in hash {text[i*2],text[i*2+1]=hex[b>>4],hex[b&15]}
 return gd.new_string_odin(string(text[:]))
}
