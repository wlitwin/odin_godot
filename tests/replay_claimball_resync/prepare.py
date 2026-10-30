from pathlib import Path
import hashlib, json, shutil, subprocess, sys

root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve()
subprocess.run([sys.executable,str(root/'tests/replay_claimball_trace/prepare.py'),str(out)],check=True)
p=out/'project/scripts/observer_trace.odin';s=p.read_text()
s=s.replace('ready,paused:bool','ready,paused,requested:bool')
s=s.replace(' pause:=gd.env_int("RCB_TRACE_PAUSE_MS",0)',' trace_maybe_refresh(self)\n pause:=gd.env_int("RCB_TRACE_PAUSE_MS",0)')
s=s.replace(' data,error:=tape.encode(&t.log);',' if gd.env_int("RCB_TRACE_REFRESH",0)==1 {assert(t.requested)}\n data,error:=tape.encode(&t.log);')
s+='''
trace_maybe_refresh :: proc(self:^ReplayClaimball) {
 t:=&self.observer_trace[0];c:=&self.session.client
 if t.requested || gd.env_int("RCB_TRACE_REFRESH",0)!=1 || c.phase!=.Running {return}
 for batch in c.journal.batches {
  if !batch.valid || batch.tick>c.journal.confirmed {continue}
  for item in batch.items[:batch.count] {
   e:=item.occurrence.value
   if item.begun || e.kind!=.Gameplay || e.value.kind!=.Kick {continue}
   t.requested=true
   gd.print_str(fmt.tprintf("RCB_TRACE_REFRESH target=%d seat=%d serial=%d confirmed=%d watched=%d",batch.tick,e.seat,c.serial,c.journal.confirmed,c.journal.watch_tick))
   tape.mark(&t.log,3,batch.tick)
   trace.request_refresh(c)
   return
  }
 }
}
'''
s=s.replace('import gd "godot:godot"','import gd "godot:godot"\nimport net "godot:replay/net"');p.write_text(s)
manifest=json.loads((out/'prepared.json').read_text());manifest['scripts/observer_trace.odin']=hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')
shutil.copy2(root/'tests/replay_claimball_resync/prepare.py',out/'prepare-resync.py')
