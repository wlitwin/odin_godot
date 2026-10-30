def apply(source,browser=False):
 s=source.replace('checked_epoch,diagnostic_at,durable_after:u64,','checked_epoch,diagnostic_at,durable_after:u64,\n profile_sent,continued:bool,cast_due,combat_sample,restored_shots,restored_casts,restored_kills:u64,peak:u32,')
 s=s.replace('game.initial(dedicated=true,encounter_count=0)','combat_initial()').replace('>40000 {fail(self,"timeout")','>120000 {fail(self,"timeout")').replace('rgd.room_frame(&self.room,dt,game.Control{})','rgd.room_frame(&self.room,dt,combat_input(self))')
 start=s.index('  if !self.ready_sent && frame.state.players[seat-1].connected');end=s.index('\n }',start);s=s[:start]+'  combat_actions(self,&frame.state,seat,epoch)'+s[end:]
 s=s.replace(' avatars:=0;', ' combat_observe(self,&frame.state,epoch)\n avatars:=0;',1)
 s=s.replace('  self.expected,self.point,self.expected_ready=cp.frame,self.room.prepared.point,true','  mem.copy_non_overlapping(&self.expected,&cp.frame,size_of(cp.frame))\n  self.point,self.expected_ready=self.room.prepared.point,true')
 s=s.replace('  self.checked_epoch=epoch','  if !combat_active(&restored.state) {fail(self,"checkpoint was not active combat");RETURN}\n  self.restored_shots,self.restored_casts,self.restored_kills,_=combat_counts(&restored.state)\n  gd.print_str(fmt.tprintf("DEDICATED_COMBAT_RESTORED epoch=%d tick=%d shots=%d casts=%d kills=%d living=%d projectiles=%d lobs=%d zones=%d",epoch,restored.tick,self.restored_shots,self.restored_casts,self.restored_kills,game.living_enemies(&restored.state),restored.state.shots.count,restored.state.lobs.count,restored.state.zones.count))\n  self.checked_epoch=epoch')
 s=s.replace('&& self.room.backup_observation.point.archive.tick>=self.durable_after {','&& self.room.backup_observation.point.archive.tick>=self.durable_after && self.peak>=30 && combat_checkpoint(self,self.room.backup_observation.point.archive.tick) {')
 s=s.replace('&& rgd.room_backup_status(&self.room).phase==.Ready {','&& rgd.room_backup_status(&self.room).phase==.Ready && seen(self,"combat-continued") {')
 s=s.replace("RETURN", "return false" if browser else "return")
 if 'import "core:mem"' not in s:s=s.replace('import "core:reflect"','import "core:reflect"\nimport "core:mem"')
 return s
