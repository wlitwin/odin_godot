from pathlib import Path
import json,os,subprocess,sys
root=Path(__file__).resolve().parents[2]
project=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)

def command(name,action,*extra,ok=True):
 result=out/name/'result.json';result.parent.mkdir()
 with (result.parent/'driver.log').open('w') as log:
  done=subprocess.run([sys.executable,str(project/'tools/authoring.py'),'--project',str(project),'--framework',str(root),'--godot',os.environ['GODOT'],'--result',str(result),action,*extra],stdout=log,stderr=subprocess.STDOUT,timeout=300)
 report=json.loads(result.read_text())
 assert report['ok']==ok and (done.returncode==0)==ok,report
 return report
command('ability','scaffold','--name','healing_patch','--kind','ability')
command('actor','scaffold','--name','copper_relay','--kind','actor')
command('duplicate','scaffold','--name','copper_relay','--kind','actor',ok=False)
command('draft','correction','--selection','res://scripts/drafts/healing_patch/definition.tres')
command('takeover','takeover')
command('network','network','--latency','150')
(out/'result.json').write_text(json.dumps({'pass':True,'draft_creation':True,'draft_build_preview':True,'duplicate_rejected':True,'draft_correction':True,'takeover':True,'network':True},indent=2)+'\n')
print('REPLAY_WORKFLOW_COMMANDS_OK')
