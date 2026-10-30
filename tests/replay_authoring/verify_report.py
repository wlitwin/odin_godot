"""Reject incomplete or tampered reports using disposable metadata/receipt copies."""
from pathlib import Path
import json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();here=Path(__file__).resolve().parent

def clone(root):
    for name in ('run-plan.json','contract.json','build.json'):shutil.copy2(source/name,root/name)
    shutil.copytree(source/'runs',root/'runs')
    for impl in ('kit','replay'):
        (root/impl).mkdir();shutil.copy2(source/impl/'source.json',root/impl/'source.json')
        shutil.copytree(source/impl/'feature',root/impl/'feature')
        (root/impl/'project').symlink_to(source/impl/'project',target_is_directory=True)

def change(path,mutate):
    value=json.loads(path.read_text());mutate(value);path.write_text(json.dumps(value))

def mutate(root,case):
    peer=root/'runs/1/local/funded/kit/success-guest.json'
    if case=='valid':return
    if case=='missing_peer':peer.unlink()
    elif case=='wrong_seat':change(peer,lambda v:v.update(seat=3))
    elif case=='wallet':change(peer,lambda v:v.update(cash=[3,4,0]))
    elif case=='repeat_charge':change(peer,lambda v:next(x for x in v['trace'] if x['phase']=='continued_hold')['cash'].__setitem__(1,6))
    elif case=='partial_plan':change(root/'run-plan.json',lambda v:v.update(cases=['funded']))
    elif case=='feature_counts':change(root/'kit/feature/changes.json',lambda v:v['files'][0].update(added_nonblank=0))
    elif case=='omitted_file':change(root/'kit/feature/changes.json',lambda v:v['files'].pop())
    elif case=='forged_patch':
        p=root/'kit/feature/feature.patch';p.write_text(p.read_text()+'forged\n')
    elif case=='binary':change(root/'build.json',lambda v:v['binaries'].update({next(iter(v['binaries'])):'0'*64}))
    elif case=='authority_trace':change(peer.parent/'success-host.json',lambda v:next(x for x in v['trace'] if x['phase']=='result')['cash'].__setitem__(0,99))
    elif case=='changed_contract':change(root/'contract.json',lambda v:v.update(cost=2))
    elif case=='missing_quiescence':(peer.parent/'quiesced-guest.json').unlink()
    else:raise AssertionError(case)

cases=['valid','missing_peer','wrong_seat','wallet','repeat_charge','partial_plan','feature_counts','omitted_file','forged_patch','binary','missing_quiescence','changed_contract','authority_trace']
results=[]
for case in cases:
    with tempfile.TemporaryDirectory(prefix='authoring-report-') as name:
        root=Path(name);clone(root);mutate(root,case)
        result=subprocess.run([sys.executable,str(here/'report.py'),str(root)],capture_output=True,text=True)
        assert (result.returncode==0)==(case=='valid'),(case,result.stdout,result.stderr)
        assert (root/'summary.json').exists()==(case=='valid'),case
        results.append({'case':case,'accepted':result.returncode==0})
(source/'report-validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('REPLAY_AUTHORING_REPORT_VALIDATION_OK cases='+str(len(results)))
