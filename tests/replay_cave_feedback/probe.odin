package replay_cavecrawl
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import net "godot:replay/net"
import game "../shared/cave"

// Only the isolated fixture exposes synthetic presentation events. Gameplay
// acceptance uses ordinary campaign actions and reads the same counters below.
@(gd_method)
replay_cave_feedback_inject :: proc(self:^ReplayCave,phase:gd.Int,kind:gd.Int,x:gd.Float,y:gd.Float) {
 epoch:=self.feedback.cues.ledger.epoch
 event:=game.Event{position={f32(x),f32(y)},seat=1};event.kind=type_of(event.kind)(kind)
 change:=v.Change(net.Net_Event(game.Event)){kind=v.Change_Kind(phase),
  occurrence={id={epoch,100000,900000,1},value={kind=.Gameplay,value=event}}}
 cave_feedback_change(self,change);cave_feedback_paint(self)
}
@(gd_method)
replay_cave_feedback_probe :: proc(self:^ReplayCave,key:string)->gd.Int {
 f:=&self.feedback
 switch key {
 case "ready":return gd.Int(f.ready)
 case "begun":return gd.Int(f.cues.stats.begun)
 case "canceled":return gd.Int(f.cues.stats.canceled)
 case "duplicates":return gd.Int(f.cues.stats.duplicates)
 case "dropped":return gd.Int(f.cues.stats.dropped)
 case "died":return gd.Int(f.died)
 case "slain":return gd.Int(f.slain)
 case "hits":return gd.Int(f.hits)
 case "dweller_hits":return gd.Int(f.dweller_hits)
 case "started":return gd.Int(f.started)
 case "nodes":return gd.Int(f.nodes.count)
 }
 return -1
}
@(gd_method)
replay_cave_feedback_node :: proc(self:^ReplayCave)->gd.Node2d {
 for cue in self.feedback.cues.slots {if cue.active {node,_:=rgd.nodes_get(&self.feedback.nodes,cue.key);return node}}
 return nil
}

@(gd_method)
replay_cave_feedback_stage_dweller :: proc(self:^ReplayCave,key:gd.Int)->gd.Node2d {
 instance:=[1]rgd.Instance2{{key=u64(key),pose={position={320,100}},scale={1,1},color={1,1,1,1}}}
 assert(rgd.nodes_present(&self.dwellers,instance[:]))
 node,_:=rgd.nodes_get(&self.dwellers,u64(key));return node
}
@(gd_method)
replay_cave_feedback_dweller_inject :: proc(self:^ReplayCave,phase:gd.Int,key:gd.Int) {
 change:=v.Change(net.Net_Event(game.Event)){kind=v.Change_Kind(phase),
  occurrence={id={self.feedback.cues.ledger.epoch,100001,900001,u64(key)},value={kind=.Gameplay,value={kind=.Hit,position={320,100},seat=0,amount=35}}}}
 cave_feedback_change(self,change);cave_feedback_paint(self)
}

// Read-only proof of the actual accepted heal transition, including damage in
// that tick. The campaign leaves hostile AI enabled between revive and heal.
@(gd_method)
replay_cave_feedback_heal_proof :: proc(self:^ReplayCave,key:string)->gd.Int {
 if !self.session.ready || !self.session.authority {return -1}
 server:=&self.session.server
 for offset in u64(0)..<min(server.timeline.head,u64(server.cfg.history-1)) {
  tick:=server.timeline.head-offset
  events:[net.WIRE_EVENTS]r.Occurrence(net.Net_Event(game.Event))
  count,error:=r.copy_events(&server.timeline,tick,events[:]);if error!=.None {continue}
  healed,accepted:=false,false;damage:=i32(0);sequence:=u64(0)
  for e in events[:count] {
   if e.value.kind==.Action_Result && e.value.seat==2 && e.value.applied {accepted=true;sequence=e.value.sequence}
   if e.value.kind!=.Gameplay {continue}
   value:=e.value.value
   if value.kind==.Revived && value.seat==2 && value.amount==25 && e.id.source==2 {healed=true}
   if value.kind==.Hit && value.seat==2 {damage+=value.amount}
  }
  if !healed || !accepted {continue}
  before,a:=r.read(&server.timeline,tick-1);after,b:=r.read(&server.timeline,tick);if !a || !b {return -2}
  old,new:=before.state.players[1],after.state.players[1]
  stamina:=min(old.stamina+(tick%game.HZ==0 ? i32(1) : 0),10)
  if old.hp<=0 || old.hp>30 || damage>=old.hp || new.hp!=old.hp-damage+25 || new.stamina!=stamina-5 || new.heal_cd!=60 {return -2}
  switch key {
  case "tick":return gd.Int(tick)
  case "before":return gd.Int(old.hp)
  case "damage":return gd.Int(damage)
  case "after":return gd.Int(new.hp)
  case "stamina":return gd.Int(new.stamina)
  case "cooldown":return gd.Int(new.heal_cd)
  case "sequence":return gd.Int(sequence)
  }
 }
 return -1
}
