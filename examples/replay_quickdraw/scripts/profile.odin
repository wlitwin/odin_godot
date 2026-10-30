package replay_quickdraw

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import net "godot:replay/net"
import lb "godot:replay/lobby"
import storagegd "godot:replay/godot/storage"

// Identity and display name are local preferences, separate from the replicated
// pitch and authority archives. Explicit test tokens do not touch user profiles.
profile_ready :: proc(self:^ReplayQuickdraw) {
 initial,_:=lb.name("Gunner")
 self.profile_enabled=quickdraw_param("RQ_TOKEN","")=="" && self.bot=="" && quickdraw_int("RQ_PERSIST",1)!=0
 when gd.IS_WEB {
  if self.profile_enabled {storagegd.browser_identity_open(&self.browser_identity,"replay-quickdraw")}
  else {self.identity=storagegd.session_token(quickdraw_param("RQ_TOKEN",""));self.profile_identity_ready=storagegd.browser_identity_valid(self.identity)}
 } else {self.profile_identity_ready=true}
 path:=quickdraw_param("RQ_PROFILE","user://replay_quickdraw_identity")
 if !storagegd.name_profile_open(&self.name_profile,fmt.tprintf("%s.name",path),"replay-quickdraw",self.profile_enabled,initial) {
  ui_notice(self,"Could not read your saved name. Check the profile file before joining.")
 }
 self.profile_name_loaded=self.name_profile.phase!=.Reading
 value:=self.name_profile.value
 if override:=quickdraw_param("RQ_NAME","");override!="" {if name,ok:=lb.name(override);ok {value=name}}
 gd.set_string(self.ui[0].name,"text",fmt.ctprintf("%s",lb.text(&value)))
}
profile_connect :: proc(self:^ReplayQuickdraw,name:lb.Name)->(net.Token,bool) {
 if self.name_profile.failed {ui_notice(self,"Could not read or write your saved name. Check the profile file before joining.");return {},false}
 token:net.Token
 when gd.IS_WEB {token=self.identity} else {if self.profile_enabled {
  value,err:=storagegd.session_profile(quickdraw_param("RQ_PROFILE","user://replay_quickdraw_identity"))
  if err!=.None {ui_notice(self,fmt.tprintf("Could not read or write your player identity: %v",err));return {},false}
  token=value
 } else {token=self.identity}}
 if !storagegd.name_profile_set(&self.name_profile,name) {return {},false}
 storagegd.name_profile_frame(&self.name_profile)
 if self.name_profile.failed {ui_notice(self,"Could not save your name. Check the profile file before joining.");return {},false}
 return token,true
}

profile_available :: proc(self:^ReplayQuickdraw)->bool {
 return self.profile_identity_ready && self.profile_name_loaded && !self.name_profile.failed
}
profile_frame :: proc(self:^ReplayQuickdraw) {
 when gd.IS_WEB {
  if !self.profile_identity_ready && self.browser_identity.phase!=.Closed {
   storagegd.browser_identity_frame(&self.browser_identity)
   if token,ok:=storagegd.browser_identity_token(&self.browser_identity);ok {self.identity=token;self.profile_identity_ready=true}
  }
  storagegd.name_profile_frame(&self.name_profile)
  if !self.profile_name_loaded && self.name_profile.phase!=.Reading {
   self.profile_name_loaded=true;value:=self.name_profile.value
   if override:=quickdraw_param("RQ_NAME","");override!="" {if name,ok:=lb.name(override);ok {value=name}}
   gd.set_string(self.ui[0].name,"text",fmt.ctprintf("%s",lb.text(&value)))
  }
  if self.name_profile.failed || self.browser_identity.phase==.Failed {
   if self.ready {gd.set_string(self.ui[0].chat_notice,"text","Could not save or load the browser profile.")}
   else {ui_notice(self,"Could not save or load the browser profile. Existing data was kept.")}
  }

 }
}

@(gd_method)
replay_quickdraw_profile_hash :: proc(self:^ReplayQuickdraw)->gd.String {
 hash:=net.token_hash(self.identity);hex:="0123456789abcdef";text:[64]u8
 for b,i in hash {text[i*2],text[i*2+1]=hex[b>>4],hex[b&15]}
 return gd.new_string_odin(string(text[:]))
}
