from pathlib import Path
import json,os,subprocess,sys
root=Path(__file__).resolve().parents[2]
project=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)

def command(name,action,inputs=None,ok=True):
 result=out/name/'result.json';result.parent.mkdir()
 request=result.with_suffix('.request.json');request.write_text(json.dumps({'action':action,'inputs':inputs or {}}))
 with (result.parent/'driver.log').open('w') as log:
  done=subprocess.run([sys.executable,str(root/'replay/editor/worker.py'),'--project',str(project),'--framework',str(root),'--godot',os.environ['GODOT'],'--result',str(result),'--request',str(request)],stdout=log,stderr=subprocess.STDOUT,timeout=300)
 report=json.loads(result.read_text())
 assert report['ok']==ok and (done.returncode==0)==ok,report
 return report
command('ability','scaffold',{'name':'healing_patch','draft_kind':'ability'})
command('actor','scaffold',{'name':'copper_relay','draft_kind':'actor'})
command('duplicate','scaffold',{'name':'copper_relay','draft_kind':'actor'},ok=False)
draft_result=out/'draft/result.json';draft_result.parent.mkdir()
with (draft_result.parent/'driver.log').open('w') as log:
 subprocess.run([sys.executable,str(project/'scripts/drafts/healing_patch/scenario.py'),'--framework',str(root),'--godot',os.environ['GODOT'],'--result',str(draft_result)],stdout=log,stderr=subprocess.STDOUT,timeout=300,check=True)
assert json.loads(draft_result.read_text())['ok']
command('takeover','takeover')
command('network','network',{'latency':150})
(out/'result.json').write_text(json.dumps({'pass':True,'draft_creation':True,'draft_build_preview':True,'duplicate_rejected':True,'draft_correction':True,'takeover':True,'network':True},indent=2)+'\n')
print('REPLAY_WORKFLOW_COMMANDS_OK')
