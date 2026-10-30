package replay_claimball

import "core:strings"
import "core:strconv"
import gd "godot:godot"

claimball_param :: proc(key:cstring,fallback:string="")->string {
 name:=string(key);query:=strings.to_lower(name[len("RCB_"):],context.temp_allocator)
 return gd.launch_param(key,query,fallback)
}
claimball_int :: proc(key:cstring,fallback:int)->int {
 text:=claimball_param(key,"");if text=="" {return fallback}
 value,ok:=strconv.parse_int(text);return ok ? value : -1
}

// A resume deep link must wait for both identity and the selected slot read.
// Never consume the launch intent merely because profile loading finished first.
browser_launch_frame :: proc(self:^ReplayClaimball) {
 when gd.IS_WEB {
  if self.browser_launch=="" || !profile_available(self) {return}
  resume:=claimball_int("RCB_RESUME",0)==1
  phase:=self.browser_save[0].slot.phase
  if resume && (phase==.Closed || phase==.Reading || phase==.Writing) {return}
  role:=self.browser_launch;self.browser_launch="";defer delete(role)
  connect_pitch(self,role,false,resume)
 }
}
