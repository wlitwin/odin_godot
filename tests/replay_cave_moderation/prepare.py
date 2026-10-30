from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
subprocess.run([sys.executable,str(root/'tests/replay_cave_feedback/prepare.py'),str(out)],check=True)
project=out/'project';shutil.copy2(root/'tests/replay_cave_moderation/probe.odin',project/'scripts/moderation_probe.odin')
p=project/'scripts/cave.odin';s=p.read_text().replace('options.session.replication.accept_checkpoints = member <= 2','options.automatic_successor=true\n\t\toptions.session.replication.accept_checkpoints = true');p.write_text(s)

shutil.copytree(root/'tests/replay_migration',out/'coordinator',ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid','__pycache__'))
p=out/'coordinator/scripts/coordinator.odin';s=p.read_text().replace('can_host = i < 2, trusted_authority = i < 2','can_host = true, trusted_authority = true')
s=s.replace('import tr "godot:replay/transport"','import tr "godot:replay/transport"\nimport sc "godot:replay/schema"')
s=s.replace('if auth.service_pump(&self.service) != .None','''if gd.env_int("MODERATION_IGNORE",0)==1 {
 buffer:[tr.MAX_PACKET_BYTES]u8;tr.poll(&self.wire)
 for _ in 0..<32 {
  packet:=tr.receive(&self.wire,buffer[:]);if packet.state!=.Received {break}
  meta,_,report:=sc.inspect(buffer[:packet.count-32])
  if report.error==.None && meta.kind==auth.RPC_REMOVE_REQUEST {continue}
  auth.service_receive(&self.service,packet.from,buffer[:packet.count])
 }
} else if auth.service_pump(&self.service) != .None''')
s=s.replace('if auth.service_init(&self.service, record, db.commit, &self.store, auth.native_clock(), self.wire, keys[:]) != .None','''control_wire:=self.wire
 if gd.env_int("MODERATION_DROP_REPLY",0)==1 {
  control_wire.user=self
  control_wire.send=proc(raw:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
   self:=cast(^ReplayMigrationCoordinator)raw
   meta,_,report:=sc.inspect(bytes[:len(bytes)-32])
   if report.error==.None && meta.kind==auth.RPC_REMOVE_REPLY {gd.print_str("MODERATION_REPLY_DROPPED");return .Sent}
   return tr.send(&self.wire,to,channel,bytes)
  }
  control_wire.receive=proc(raw:rawptr,dst:[]u8)->tr.Received {return tr.receive(&(cast(^ReplayMigrationCoordinator)raw).wire,dst)}
  control_wire.poll=proc(raw:rawptr){tr.poll(&(cast(^ReplayMigrationCoordinator)raw).wire)}
  control_wire.status=proc(raw:rawptr)->tr.Status{return tr.status(&(cast(^ReplayMigrationCoordinator)raw).wire)}
  control_wire.connected=proc(raw:rawptr,id:tr.Peer_Id)->bool{return tr.peer_connected(&(cast(^ReplayMigrationCoordinator)raw).wire,id)}
  control_wire.generation=proc(raw:rawptr,id:tr.Peer_Id)->u64{return tr.peer_generation(&(cast(^ReplayMigrationCoordinator)raw).wire,id)}
  control_wire.close=nil
 }
 if auth.service_init(&self.service, record, db.commit, &self.store, auth.native_clock(), control_wire, keys[:]) != .None''')
p.write_text(s)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
(out/'coordinator.json').write_text(json.dumps({str(p.relative_to(out/'coordinator')):sha(p) for p in (out/'coordinator').rglob('*') if p.is_file()},indent=2)+'\n')
