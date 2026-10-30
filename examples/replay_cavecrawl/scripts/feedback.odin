package replay_cavecrawl

import gd "godot:godot"
import v "godot:replay/view"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/cave"

Cave_Cue :: struct {position:[2]f32,color:[4]f32,seat:u16,flash:bool,target_key:u64}
Cave_Feedback :: struct {
 cues:v.Cues(Cave_Cue),
 nodes:rgd.Nodes2,
 ready:bool,
 floor_tick:u64,
 depth:u8,
 run:u32,
 died,slain,hits,dweller_hits,started:u64,
}

cave_feedback_destroy :: proc(self:^ReplayCave) {
 rgd.nodes_destroy(&self.feedback.nodes);v.cues_destroy(&self.feedback.cues);self.feedback={}
}
cave_feedback_prepare :: proc(self:^ReplayCave,dt:f64) {
 if !self.session.ready {return}
 f:=&self.feedback
 epoch:=self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
 frontier:=self.session.authority ? self.session.server.timeline.head : min(self.session.client.journal.confirmed,self.session.client.journal.watch_tick)
 baseline:=self.session.authority ? self.session.server.timeline.head : self.session.client.journal.baseline
 // Queued confirmed effects can predate a same-epoch snapshot rebase. Keep their
 // IDs admissible until this frame consumes the actual journal output.
 oldest:=max(u64)
 for change in self.session.changes[:self.session.change_count] {
  if change.kind==.Begin && change.occurrence.id.epoch==epoch && change.occurrence.id.tick>0 {oldest=min(oldest,change.occurrence.id.tick)}
 }
 if oldest!=max(u64) {baseline=min(baseline,oldest-1)}
 if !f.ready {
  if !v.cues_init(&f.cues,epoch,baseline) {return}
  if !rgd.nodes_load(&f.nodes,self.stage,"res://views/burst.tscn",128) {v.cues_destroy(&f.cues);return}
  f.ready=true
 } else if epoch!=f.cues.ledger.epoch {
  if !v.cues_epoch(&f.cues,epoch,baseline) {return}
  rgd.nodes_clear(&f.nodes);f.depth,f.run,f.floor_tick=0,0,0
 }
 v.cues_advance(&f.cues,dt)
 through:=frontier>256 ? frontier-256 : 0
 if oldest!=max(u64) {through=min(through,oldest-1)}
 if through>f.cues.ledger.floor {v.one_shots_retire(&f.cues.ledger,through)}
 frame,ok:=rgd.session_authority_state(self.session)
 if ok {
  if f.depth!=0 && (f.depth!=frame.state.depth || f.run!=frame.state.lobby.run) {
   v.cues_clear(&f.cues);rgd.nodes_clear(&f.nodes);f.floor_tick=frame.tick
  }
  f.depth,f.run=frame.state.depth,frame.state.lobby.run
 }
}
cave_feedback_change :: proc(self:^ReplayCave,change:v.Change(net.Net_Event(game.Event))) {
 f:=&self.feedback;if !f.ready {return}
 event:=change.occurrence.value.value
 value:=Cave_Cue{position=event.position,seat=event.seat}
 wanted:=change.occurrence.value.kind==.Gameplay
 #partial switch event.kind {
 case .Died:value.color={1,.3,.2,1}
 case .Slain:value.color={.8,.4,1,1}
 case .Hit:value.color={1,.9,.4,1};value.flash=true
  if event.seat==0 {value.target_key=change.occurrence.id.key}
 case: wanted=false
 }
 kind:=change.kind
 if kind==.Update && !wanted {kind=.Cancel}
 if kind!=.Cancel && (!wanted || change.occurrence.id.tick<f.floor_tick) {return}
 mapped:=v.Change(Cave_Cue){kind=kind,occurrence={id=change.occurrence.id,value=value},confirmed=change.confirmed}
 if v.cues_change(&f.cues,mapped,.8) {
  #partial switch event.kind {case .Died:f.died+=1;case .Slain:f.slain+=1;case .Hit:if event.seat==0 {f.dweller_hits+=1} else {f.hits+=1};case:}
 }
}
cave_feedback_paint :: proc(self:^ReplayCave) {
 f:=&self.feedback;if !f.ready {return}
 instances:[128]rgd.Instance2;count:=0
 starts:[128]u64;start_count:=0
 flash:[game.SEATS]f32
 dweller_flash:[16]struct{key:u64,amount:f32}
 for cue in f.cues.slots {if cue.active {
  instances[count]={key=cue.key,pose={position=cue.value.position},scale={1,1},color={1,1,1,1}};count+=1
  if _,exists:=rgd.nodes_get(&f.nodes,cue.key);!exists {starts[start_count]=cue.key;start_count+=1}
  if cue.value.flash && cue.value.target_key!=0 && cue.age<.3 {
   index:=int(u32(cue.value.target_key))-1
   if index>=0 && index<len(dweller_flash) {
    amount:=f32(1-cue.age/.3)
    // A replaced generation is a different body, even within one effect lifetime.
    if cue.value.target_key>dweller_flash[index].key {dweller_flash[index]={cue.value.target_key,amount}}
    else if cue.value.target_key==dweller_flash[index].key {dweller_flash[index].amount=max(dweller_flash[index].amount,amount)}
   }
  }
  if cue.value.flash && cue.value.seat>0 && cue.value.seat<=game.SEATS && cue.age<.3 {
   index:=int(cue.value.seat)-1;flash[index]=max(flash[index],f32(1-cue.age/.3))
  }
 }}
 if !rgd.nodes_present(&f.nodes,instances[:count]) {return}
 for cue in f.cues.slots {if cue.active {
  node,exists:=rgd.nodes_get(&f.nodes,cue.key);if !exists {continue}
  emitter:=cast(gd.Cpu_Particles2d)gd.get_node(node,"Particles")
  gd.cpu_particles2d_set_color(emitter,gd.Color(cue.value.color))
  for key in starts[:start_count] {if key==cue.key {gd.cpu_particles2d_restart(emitter,false);f.started+=1;break}}
 }}
 for entry in self.dwellers.entries {if entry.node!=nil {
  amount:=f32(0)
  for item in dweller_flash {if item.key==entry.key {amount=item.amount;break}}
  gd.canvas_item_set_modulate(entry.node,{1,1-.65*amount,1-.65*amount,1})
 }}
 for amount,index in flash {
  node,exists:=rgd.nodes_get(&self.players,u64(index+1));if !exists {continue}
  gd.canvas_item_set_modulate(node,{1,1-.65*amount,1-.65*amount,1})
 }
}
