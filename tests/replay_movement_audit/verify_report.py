from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();report=Path(__file__).with_name('report.py');checks=[]
cases=['valid','missing_pair','different_authored_source','wrong_framework','changed_binary','missing_pending','control_rewind','movement_reversal','missing_casts','missing_status','bad_final','runtime_error']
for case in cases:
 with tempfile.TemporaryDirectory(prefix='owner-audit-report-') as directory:
  root=Path(directory)
  for name in ['contract.json','build.json']:shutil.copy2(source/name,root/name)
  for variant in ('original','owner_preserved'):
   folder=root/variant;folder.mkdir()
   for name in ['source-sha256.json','framework-source.json']:shutil.copy2(source/variant/name,folder/name)
   (folder/'project').symlink_to(source/variant/'project',target_is_directory=True)
  for pair in source.glob('pair-*'):shutil.copytree(pair,root/pair.name)
  path=root/'pair-1/original/success-client.json';data=json.loads(path.read_text())
  if case=='missing_pair':shutil.rmtree(root/'pair-3')
  if case=='different_authored_source':
   p=root/'owner_preserved/source-sha256.json';m=json.loads(p.read_text());m[next(iter(m))]='0'*64;p.write_text(json.dumps(m))
  if case=='wrong_framework':
   p=root/'owner_preserved/framework-source.json';m=json.loads(p.read_text());m['sha256']['kit/net/registry.odin']='0'*64;p.write_text(json.dumps(m))
  if case=='changed_binary':
   p=root/'build.json';m=json.loads(p.read_text());m['binaries'][next(iter(m['binaries']))]='0'*64;p.write_text(json.dumps(m))
  if case=='missing_pending':
   for s in data['trace']:s['owner_audit']['pending']=[0,0,0,0]
  if case=='movement_reversal':
   s=next(s for s in data['trace'] if 400000<s['us']<700000);s['owner_audit']['positions'][3][1]=s['owner_audit']['positions'][2][1]-10
  if case=='control_rewind':
   p=root/'pair-1/owner_preserved/success-client.json';m=json.loads(p.read_text());s=next(s for s in m['trace'] if 400000<s['us']<700000);s['owner_audit']['positions'][1][1]=s['owner_audit']['positions'][0][1]-10;p.write_text(json.dumps(m))
  if case=='missing_casts':data['cast_sent']=[0,0]
  if case=='missing_status':
   for s in data['trace']:s['chilled']=0
  if case=='bad_final':data['final']['damage'][0]+=1
  if case=='runtime_error':
   p=root/'pair-1/original/client.log';p.write_text(p.read_text()+'\nERROR: injected\n')
  path.write_text(json.dumps(data))
  run=subprocess.run([sys.executable,str(report),str(root)],capture_output=True,text=True,timeout=30)
  accepted=case=='valid';assert (run.returncode==0)==accepted,(case,run.stderr)
  assert (root/'summary.json').exists()==accepted
  if not accepted:assert 'AssertionError' in run.stderr,(case,run.stderr)
  checks.append({'case':case,'accepted':accepted})
(source/'report-validation.json').write_text(json.dumps({'report_sha256':hashlib.sha256(report.read_bytes()).hexdigest(),'cases':checks},indent=2)+'\n')
print('REPLAY_MOVEMENT_AUDIT_VALIDATION_OK cases='+str(len(checks)))
