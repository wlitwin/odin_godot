from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent;out=Path(sys.argv[1]).resolve();framework=Path(sys.argv[2]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_mixed_comparison/prepare.py'),str(out/'template')],check=True)
for variant in ('original','owner_preserved'):
 project=out/variant/'project';shutil.copytree(out/'template/kit/project',project)
 p=project/'project.godot';s=p.read_text().replace('replay_baseline_stress_template_kit','replay_movement_audit_'+out.name+'_'+variant);p.write_text(s)
 p=project/'scripts/scrapyard.odin';s=p.read_text()
 needle='events, marks, ticks := kboot.boot_pump(&self.boot, delta, now_s())';assert s.count(needle)==1
 s=s.replace(needle,'audit_position_note(self,0)\n\t'+needle)
 needle='marks_fanout(self, marks)';assert s.count(needle)==1;s=s.replace(needle,'audit_position_note(self,1)\n\t'+needle)
 needle='step_my_runner(self, r, f32(delta))';assert s.count(needle)==1;s=s.replace(needle,'audit_position_note(self,2)\n\t\t\t'+needle+'\n\t\t\taudit_position_note(self,3)')
 p.write_text(s)
 (project/'scripts/owner_audit.odin').write_text('''package scrapyard_scripts
import gd "godot:godot"
import kn "godot:kit/net"
audit_positions:[4][2]f32
audit_pending:[4]i32
audit_position_note :: proc(self:^Scrapyard,index:int) {
 if r,ok:=runner_of(self,self.ses.me);ok {audit_positions[index]={r.x,r.y}}
 audit_pending[index]=i32(kn.pending_count(&self.ses.ctx.pending))
}
@(gd_method)
scrapyard_audit_position :: proc(self:^Scrapyard,index:gd.Int)->gd.Vector2 {return index>=0 && index<4 ? audit_positions[index] : gd.Vector2{}}
@(gd_method)
scrapyard_audit_pending :: proc(self:^Scrapyard,index:gd.Int)->gd.Int {return index>=0 && index<4 ? gd.Int(audit_pending[index]) : -1}
''')
 p=project/'comparison.gd';s=p.read_text().replace('"people":people,','"people":people,"owner_audit":owner_audit(),')
 s+='''
func owner_audit()->Dictionary:
 var positions:=[]
 var pending:=[]
 for i in 4:
  var pos:Vector2=game.audit_position(i);positions.append([pos.x,pos.y]);pending.append(int(game.audit_pending(i)))
 return {"positions":positions,"pending":pending}
''';p.write_text(s)
 shared=json.loads((out/'template/framework-source.json').read_text());shared['root']=str(root if variant=='original' else framework)
 shared['sha256']={name:hashlib.sha256((Path(shared['root'])/name).read_bytes()).hexdigest() for name in shared['sha256']}
 (out/variant/'framework-source.json').write_text(json.dumps(shared,indent=2)+'\n')
 files=[p for p in project.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
 (out/variant/'source-sha256.json').write_text(json.dumps({str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)},indent=2)+'\n')
# Authored gameplay/adapters/content are equal; only the external project namespace differs.
a=json.loads((out/'original/source-sha256.json').read_text());b=json.loads((out/'owner_preserved/source-sha256.json').read_text());assert a==b
(out/'contract.json').write_text(json.dumps({'scenario':'owner_unwind_movement_control','repetitions':3,'base':json.loads((out/'template/contract.json').read_text()),'repair':json.loads((framework/'repair.json').read_text()),'expectations':{'original_client_packet_rewinds_min':20,'control_client_packet_rewinds_max':0,'host_packet_rewinds_max':0}},indent=2)+'\n')
print('REPLAY_MOVEMENT_AUDIT_PREPARED')
