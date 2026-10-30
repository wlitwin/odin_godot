package replay_godot

import auth "godot:replay/authority"

// Keep this owner alive at a stable address while its RTC connection is open.
// Obtain view from the authenticated control client. The relay independently
// verifies current authority, membership and process incarnation.
Rtc_Grant_Auth :: struct {view:auth.View,identity:auth.Identity,key:auth.Key}
rtc_grant_config :: proc(a:^Rtc_Grant_Auth,url:string,create:bool)->Rtc_Config {
 code:=auth.rendezvous_code(a.view)
 room:=make([]u8,len(code),context.temp_allocator);copy(room,code[:])
 return {url=url,room=string(room),host=create,resume_signaling=true,authorization_user=a,authorize=rtc_grant_authorize}
}
@(private)
rtc_grant_authorize :: proc(user:rawptr,challenge,room:string,create:bool)->string {
 a:=cast(^Rtc_Grant_Auth)user;nonce:auth.Nonce
 if !rtc_unhex(nonce[:],challenge) {return ""}
 code:=auth.rendezvous_code(a.view);if room!=string(code[:]) {return ""}
 proof:=auth.rendezvous_proof(a.view,a.identity,a.key,nonce,create)
 return rtc_hex(proof[:])
}
@(private)
rtc_hex :: proc(bytes:[]u8)->string {
 out:=make([]u8,len(bytes)*2,context.temp_allocator);alphabet:="0123456789abcdef"
 for byte,i in bytes {out[2*i]=alphabet[byte>>4];out[2*i+1]=alphabet[byte&15]}
 return string(out)
}
@(private)
rtc_unhex :: proc(dst:[]u8,src:string)->bool {
 if len(src)!=2*len(dst) {return false}
 nibble :: proc(b:u8)->(u8,bool) {
  if b>='0' && b<='9' {return b-'0',true};if b>='a' && b<='f' {return b-'a'+10,true};return 0,false
 }
 for &byte,i in dst {a,ok:=nibble(src[2*i]);b,valid:=nibble(src[2*i+1]);if !ok || !valid {return false};byte=(a<<4)|b}
 return true
}
