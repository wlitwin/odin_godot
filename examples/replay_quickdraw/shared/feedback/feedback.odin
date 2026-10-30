package quickdraw_feedback

import "core:math"
import r "godot:replay"
import v "godot:replay/view"
import game "../duel"

HURT_SECONDS :: f64(0.25)
RING_SECONDS :: f64(0.3)
RING_RADIUS :: f32(26)
RING_LIMIT :: 64
Health :: struct {life:u32,hp:i32,known:bool,left:f64}
Ring :: struct {id:r.Event_Id,position:[2]f32,left:f64}
Feedback :: struct {
 ledger:v.One_Shots,
 health:[game.SEATS]Health,
 rings:[RING_LIMIT]Ring,
 epoch,reset:u64,
 scoped:bool,
 hurt,landed,speculative,canceled,duplicates,dropped:u64,
}
init :: proc(f:^Feedback)->bool {return v.one_shots_init(&f.ledger,1,history=512,per_tick=40)}
clear :: proc(f:^Feedback) {f.health={};f.rings={}}
destroy :: proc(f:^Feedback) {v.one_shots_destroy(&f.ledger);f^={}}
prepare :: proc(f:^Feedback,epoch,baseline,frontier,reset:u64)->bool {
 if len(f.ledger.batches)==0 || epoch==0 || epoch<f.ledger.epoch {return false}
 if !f.scoped || f.epoch!=epoch {
  clear(f)
  if epoch==f.ledger.epoch {if !v.one_shots_retire(&f.ledger,baseline) {return false}} else if !v.one_shots_reset(&f.ledger,epoch,baseline) {return false}
  f.epoch,f.scoped=epoch,true
 }
 if f.reset!=reset {clear(f);f.reset=reset}
 floor:=max(baseline,frontier>256 ? frontier-256 : 0)
 if floor>f.ledger.floor {return v.one_shots_retire(&f.ledger,floor)}
 return true
}
advance :: proc(f:^Feedback,dt:f64) {
 if dt<0 || math.is_nan(dt) || math.is_inf(dt) {return}
 for &health in f.health {health.left=max(health.left-dt,0)}
 for &ring in f.rings {ring.left=max(ring.left-dt,0)}
}
// Observe discrete HP on the chosen authoritative/watched stream. Initial
// observation, changed life, departure and explicit reset seed without flashing.
health :: proc(f:^Feedback,index:int,life:u32,hp:i32,present:bool)->bool {
 if index<0 || index>=game.SEATS {return false}
 h:=&f.health[index]
 if !present || life==0 {h^={};return false}
 if !h.known || h.life!=life {h^={life=life,hp=hp,known=true};return false}
 if hp<h.hp {h.left=HURT_SECONDS;f.hurt+=1}
 h.hp=hp
 return h.left>0
}
// Landing visuals use detached occurrence poses after the projectile is gone.
// Confirmation/update never restart a lifetime. Cancellation stops the active
// ring; its consumed-ID tombstone prevents replaying it later.
change :: proc(f:^Feedback,c:v.Change(game.Event))->bool {
 if !f.scoped || c.occurrence.id.epoch!=f.epoch {return false}
 id:=c.occurrence.id
 if c.kind==.Cancel || (c.kind==.Update && c.occurrence.value.kind!=.Landed) {
  for &ring in f.rings {if ring.left>0 && ring.id==id {ring.left=0;f.canceled+=1}}
  return false
 }
 if c.occurrence.value.kind!=.Landed {return false}
 if c.kind==.Update {
  for &ring in f.rings {if ring.left>0 && ring.id==id {ring.position=c.occurrence.value.position}}
  return false
 }
 if c.kind!=.Begin {return false}
 result:=v.one_shot_note(&f.ledger,id)
 if result==.Duplicate {f.duplicates+=1;return false}
 if result!=.New {f.dropped+=1;return false}
 for &ring in f.rings {if ring.left<=0 {
  ring={id=id,position=c.occurrence.value.position,left=RING_SECONDS};f.landed+=1;if !c.confirmed {f.speculative+=1};return true
 }}
 f.dropped+=1;return false
}
