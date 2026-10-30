from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_slopball_ui/prepare.py'),str(out)],check=True)
p=out/'project/scripts/slopball.odin';s=p.read_text().replace('owner: gd.Node2d,','owner: gd.Node2d,\n test_prepare_allowed:bool,',1);p.write_text(s)
p=out/'project/scripts/migration.odin';s=p.read_text();needle='opts.session.discover_epoch=false';s=s.replace(needle,needle+'''
  opts.preparation_user=self
  opts.preparation_ready=proc(user:rawptr,point:auth.Point,bytes:[]u8)->bool {return (cast(^ReplaySlopball)user).test_prepare_allowed}
''',1);s+='''
@(gd_method)
replay_slopball_allow_backup :: proc(self:^ReplaySlopball,allow:bool) {self.test_prepare_allowed=allow}
@(gd_method)
replay_slopball_backup_probe :: proc(self:^ReplaySlopball,key:string)->gd.Int {
 if key=="pending" {return gd.Int(self.room.rpc.pending)}
 if key=="raw_prepared" {return gd.Int(self.room.rpc.reply.prepared)}
 status:=rgd.room_backup_status(&self.room)
 switch key {case "phase":return gd.Int(status.phase);case "age":return gd.Int(status.age_ticks);case "limit":return gd.Int(status.rollback_limit);case "tick":return gd.Int(status.point.archive.tick);case "epoch":return gd.Int(status.epoch)}
 return -1
}
''';p.write_text(s)
m=json.loads((out/'prepared.json').read_text())
for n in ['scripts/slopball.odin','scripts/migration.odin']:m[n]=hashlib.sha256((out/'project'/n).read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps(m,indent=2)+'\n')
