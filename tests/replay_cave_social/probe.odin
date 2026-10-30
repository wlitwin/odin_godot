package replay_cavecrawl

import gd "godot:godot"
import dg "godot:replay/telemetry"

// Test-only observability. This file is copied into the isolated project.
@(gd_method)
replay_cave_social_metrics :: proc(self:^ReplayCave,key:string,seat:gd.Int)->gd.Int {
 if key=="compact_facts_sent" {return self.session.authority ? gd.Int(self.session.server.stats.compact_recent_facts) : 0}
 if key=="compact_sent" {return self.session.authority ? 0 : gd.Int(self.session.client.stats.compact_observations)}
 if key=="compact_authority" {return gd.Int(self.session.authority)}
 if key=="epoch" {return gd.Int(self.diagnostics.scope.epoch)}
 if key=="enabled" {return gd.Int(self.diagnostics.enabled)}
 if key=="mark_ttl" {
  now:=gd.time_get_ticks_msec(gd.singleton_time());remaining:=u64(0)
  for mark in self.marks {if mark.node!=nil && mark.expires>now {remaining=max(remaining,mark.expires-now)}}
  return gd.Int(remaining)
 }
 if seat<1 || seat>4 {return -1}
 row:=dg.read(&self.diagnostics,u16(seat))
 switch key {case "known":return gd.Int(row.known);case "ms":return gd.Int(row.round_trip_ms);case "age":return gd.Int(row.age_ms)}
 return -1
}
