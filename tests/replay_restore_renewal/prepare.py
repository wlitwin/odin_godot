from pathlib import Path
import hashlib,json,re,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_claimball_ui/prepare.py'),str(out)],check=True)
p=out/'project/scripts/claimball.odin';s=p.read_text().replace('import r "godot:replay"','import r "godot:replay"\nimport tr "godot:replay/transport"')
s,n=re.subn(r'(?m)^([ \t]*)view_epoch[ \t]*:[ \t]*u64[ \t]*,',r'\1view_epoch:u64,\n\1restore_base:tr.Transport,\n\1restore_due,restore_deferred:u64,\n\1restore_wrapped,restore_delayed,restore_old_grant,restore_refreshed:bool,',s)
assert n==1,'expected one view_epoch field for the renewal fixture'
p.write_text(s)
p=out/'project/scripts/migration.odin';s=p.read_text().replace('import r "godot:replay"','import r "godot:replay"\nimport tr "godot:replay/transport"\nimport ck "godot:replay/provision/checkpoint"')
needle=(r'(?m)^[ \t]*return\s+self\.room\.ready\s*\?\s*'
        r'rgd\.room_frame\(\s*&self\.room\s*,\s*dt\s*,\s*c\s*\)\s*:\s*'
        r'rgd\.session_frame\(\s*self\.session\s*,\s*dt\s*,\s*c\s*\)\s*$')
s,n=re.subn(needle,''' if !self.room.ready {return rgd.session_frame(self.session,dt,c)}
 if !self.restore_wrapped {
  self.restore_base=self.room.control_wire;self.restore_wrapped=true
  self.room.control_wire={user=self,send=restore_delay_send,
   receive=proc(user:rawptr,dst:[]u8)->tr.Received{return tr.receive(&(cast(^ReplayClaimball)user).restore_base,dst)},
   poll=proc(user:rawptr){tr.poll(&(cast(^ReplayClaimball)user).restore_base)},
   status=proc(user:rawptr)->tr.Status{return tr.status(&(cast(^ReplayClaimball)user).restore_base)},
   connected=proc(user:rawptr,peer:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^ReplayClaimball)user).restore_base,peer)},
   generation=proc(user:rawptr,peer:tr.Peer_Id)->u64{return tr.peer_generation(&(cast(^ReplayClaimball)user).restore_base,peer)},
   close=proc(user:rawptr){tr.close(&(cast(^ReplayClaimball)user).restore_base)}}
 }
 error:=rgd.room_frame(&self.room,dt,c)
 if self.restore_delayed && !self.restore_old_grant && self.room.restore.phase==.Granted && !auth.lease_live(&self.room.lease,self.room.lease.view.epoch) {
  assert(!self.session.ready && self.room.restore.prepared.ready && self.room.restore.renewed_epoch==0)
  self.restore_old_grant=true
  gd.print_str(fmt.tprintf("RESTORE_OLD_GRANT_PARKED epoch=%d head=0 ready=false",self.room.lease.view.epoch))
 }
 if self.restore_old_grant && !self.restore_refreshed && self.room.restore.phase==.Complete {
  assert(error==.None && self.session.ready && self.session.authority && self.session.server.cfg.epoch==2 && self.room.restore.renewed_epoch==2)
  self.restore_refreshed=true
  gd.print_str(fmt.tprintf("RESTORE_RENEWED_INSTALL epoch=2 checkpoint=%d",self.room.recovery.checkpoint_tick))
 }
 return error''',s)
assert n==1,'expected one frame_session call for the renewal fixture'
s+='''
// Test-only backpressure on the Restore request itself. Other protocol messages
// keep flowing, and neither clock nor lease timestamps are altered.
restore_delay_send :: proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
 self:=cast(^ReplayClaimball)user;client:=&self.room.restore.client
 if !self.restore_delayed && client.ready && client.phase==.Requesting && client.lane.request.verb==.Restore && raw_data(bytes)==raw_data(&client.txb) && len(bytes)==client.count {
  now:=gd.time_get_ticks_msec(gd.singleton_time())
  if self.restore_due==0 {self.restore_due=now+2400}
  if now<self.restore_due {self.restore_deferred+=1;return .Backpressure}
  self.restore_delayed=true
  gd.print_str(fmt.tprintf("RESTORE_REQUEST_DELAYED ms=2400 deferred=%d",self.restore_deferred))
 }
 return tr.send(&self.restore_base,to,channel,bytes)
}
''';p.write_text(s)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(out/'project')):sha(p) for p in (out/'project').rglob('*') if p.is_file()},indent=2)+'\n')
