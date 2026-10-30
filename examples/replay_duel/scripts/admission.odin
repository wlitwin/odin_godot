package replay_duel
import "core:fmt"
import gd "godot:godot"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import game "../shared/duel"
// The embedding app supplies only this participant's provisioned credential in
// sessionStorage, never in a join URL. The local gate uses explicitly test keys.
duel_admission_open :: proc(self:^ReplayDuel,url:string)->(rgd.Rtc_Config,bool) {
 if self.online_enabled {return rgd.p2p_party_rtc(&self.online)}
 when gd.IS_WEB {
  self.authenticated=duel_int("RDP_AUTH",0)==1
  if !self.authenticated {return {},true}
  evaluate :: proc(expression:string)->gd.Variant {
   code:=gd.new_string_odin(expression);defer gd.free_string(code)
   return gd.java_script_bridge_eval(gd.singleton_java_script_bridge(),code,true)
  }
  member:=evaluate("globalThis.replayDuelCredential?.member || 0");defer gd.variant_destroy(&member)
  incarnation:=evaluate("globalThis.replayDuelCredential?.incarnation || 0");defer gd.variant_destroy(&incarnation)
  key:=evaluate("globalThis.replayDuelCredential?.key || ''");defer gd.variant_destroy(&key)
  text_value:=gd.variant_to_string(&key);defer gd.free_string(text_value);text:=gd.gd_string_to_odin(text_value)
  m,inc:=gd.variant_to_int(&member),gd.variant_to_int(&incarnation)
  if m!=(self.listening ? 1 : 2) || inc<1 || inc>9007199254740991 || len(text)!=64 {return {},false}
  self.admission.match={session=123,content=game.CONTENT,epoch=1,members={0=1,1=2},count=2}
  self.admission.identity={u64(m),u64(inc)}
  nibble :: proc(b:u8)->(u8,bool) {if b>='0' && b<='9' {return b-'0',true};if b>='a' && b<='f' {return b-'a'+10,true};return 0,false}
  for &byte,i in self.admission.key {a,ok:=nibble(text[2*i]);b,valid:=nibble(text[2*i+1]);if !ok || !valid {return {},false};byte=(a<<4)|b}
  return rgd.rtc_p2p_config(&self.admission,url,self.listening),true
 } else {return {},false}
}
duel_admitted_remote :: proc(self:^ReplayDuel,physical:tr.Peer_Id)->bool {
 if !self.authenticated {return true}
 when !gd.IS_WEB {
  identity,ok:=rgd.p2p_direct_identity(&self.direct)
  if !ok || identity.member!=u64(physical) {return false}
  gd.print_str(fmt.tprintf("RDP_ADMITTED physical=%d member=%d incarnation=%d encrypted=true",self.direct.peer,identity.member,identity.incarnation))
  return true
 } else {
 identity,ok:=rgd.rtc_peer_identity(&self.rtc,physical)
 if !ok || identity.member!=(self.listening ? 2 : 1) {duel_fail(self,"unverified roster binding");return false}
 gd.print_str(fmt.tprintf("RDP_ADMITTED physical=%d member=%d incarnation=%d",physical,identity.member,identity.incarnation))
 return true
 }
}
