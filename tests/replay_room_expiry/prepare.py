from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_claimball_ui/prepare.py'),str(out)],check=True)
p=out/'project/scripts/claimball.odin';s=p.read_text().replace('view_epoch:u64,','view_epoch:u64,\n expiry_base:auth.Clock_Source,\n expiry_offset:u64,\n expiry_reads:int,\n expiry_installed,expiry_fired:bool,')
s=s.replace('import r "godot:replay"','import r "godot:replay"\nimport auth "godot:replay/authority"');p.write_text(s)
p=out/'project/scripts/migration.odin';s=p.read_text();needle=' return self.room.ready ? rgd.room_frame(&self.room,dt,c) : rgd.session_frame(self.session,dt,c)';assert needle in s
s=s.replace(needle,''' if !self.room.ready {return rgd.session_frame(self.session,dt,c)}
 if !self.expiry_installed {
  self.expiry_base=self.room.clock;self.expiry_installed=true
  self.room.clock={user=self,read=expiry_room_clock}
  self.room.lease.clock={user=self,read=expiry_lease_clock}
 }
 fired:=self.expiry_fired
 old_epoch:=self.session.ready ? (self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch) : 0
 old_head:=self.session.authority ? self.session.server.timeline.head : self.session.client.timeline.head
 err:=rgd.room_frame(&self.room,dt,c)
 if self.expiry_fired && !fired {
  new_epoch:=self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
  new_head:=self.session.authority ? self.session.server.timeline.head : self.session.client.timeline.head
  assert(err==.None && self.room.phase!=.Failed && self.session.fenced && !self.room.lease.poisoned)
  assert(self.session.ready && old_epoch==new_epoch && old_head==new_head)
  gd.print_str(fmt.tprintf("ROOM_EXPIRY_PRESERVED member=%d epoch=%d head=%d phase=%v",self.room.options.identity.member,old_epoch,old_head,self.room.phase))
 }
 return err''')
s+='''
// Test-only monotonic forward jump between the outer and inner lease checks.
// The Room and Lease keep the same time domain afterward. No deadline is extended.
expiry_room_clock :: proc(user:rawptr)->(u64,bool) {
 self:=cast(^ReplayClaimball)user;now,ok:=self.expiry_base.read(self.expiry_base.user)
 return now+self.expiry_offset,ok
}
expiry_lease_clock :: proc(user:rawptr)->(u64,bool) {
 self:=cast(^ReplayClaimball)user;now,ok:=expiry_room_clock(user);if !ok {return now,false}
 epoch:=self.session.ready ? (self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch) : 0
 if !self.expiry_fired && epoch==1 && self.room.lease.view.epoch==2 {
  self.expiry_reads+=1
  if self.expiry_reads==2 {
   if self.room.lease.deadline>now {self.expiry_offset+=self.room.lease.deadline-now;now=self.room.lease.deadline}
   self.expiry_fired=true
   gd.print_str(fmt.tprintf("ROOM_EXPIRY_INJECTED member=%d deadline=%d",self.room.options.identity.member,self.room.lease.deadline))
  }
 }
 return now,true
}
''';p.write_text(s)
manifest=json.loads((out/'prepared.json').read_text())
for n in ['scripts/claimball.odin','scripts/migration.odin']:manifest[n]=hashlib.sha256((out/'project'/n).read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')
