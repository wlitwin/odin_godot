package replay_godot

import gd "godot:godot"
import auth "godot:replay/authority"

Browser_Lease_Clock :: struct {paired:auth.Paired_Clock}
browser_lease_clock :: proc(c:^Browser_Lease_Clock)->auth.Clock_Source {
 return {user=c,read=proc(user:rawptr)->(u64,bool) {
  clock:=cast(^Browser_Lease_Clock)user
  wall:=gd.time_get_unix_time_from_system(gd.singleton_time())*1000
  if !(wall>=0 && wall<=9007199254740991) {clock.paired.poisoned=true;return 0,false}
  return auth.paired_clock_sample(&clock.paired,u64(wall),gd.time_get_ticks_msec(gd.singleton_time()))
 }}
}
