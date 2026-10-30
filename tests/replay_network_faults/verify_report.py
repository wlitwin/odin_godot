from pathlib import Path
import hashlib,json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();report=Path(__file__).with_name('report.py');checks=[]
cases=['valid','wrong_plan','changed_binary','changed_source','unavailable_final','wrong_final','no_churn','no_client_shots','negative_timing','wrong_input','fake_proxy_counts','missing_packet_event','wrong_queue_peak']
for case in cases:
 with tempfile.TemporaryDirectory(prefix='network-fault-report-') as temporary:
  root=Path(temporary)
  for name in ['contract.json','run-plan.json','build-manifest.json','source-sha256.txt','framework-source.json']:shutil.copy2(source/name,root/name)
  for line in (source/'source-sha256.txt').read_text().splitlines():
   _,name=line.split('  ',1);p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.symlink_to(source/name)
  for name in json.loads((root/'build-manifest.json').read_text())['binaries']:
   p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.symlink_to(source/name)
  for p in source.glob('pair-*'):shutil.copytree(p,root/p.name)
  folder=root/'pair-1/lossy';path=folder/'success-host.json';data=json.loads(path.read_text())
  if case=='wrong_plan':(root/'run-plan.json').write_text('{"repetitions":1,"conditions":["lossy"]}')
  if case=='changed_binary':
   p=root/'build-manifest.json';v=json.loads(p.read_text());v['binaries'][next(iter(v['binaries']))]='0'*64;p.write_text(json.dumps(v))
  if case=='changed_source':
   p=root/'source-sha256.txt';v=p.read_text();p.write_text('0'*64+v[64:])
  if case=='unavailable_final':data['final']['ready']=False
  if case=='wrong_final':data['final']['damage'][0]+=1
  if case=='no_churn':data['trace'][-1]['kills']=[0,0]
  if case=='no_client_shots':data['trace'][-1]['spent'][1]=0
  if case=='negative_timing':data['frame_us'][0]=-1
  if case=='wrong_input':data['inputs'][0]['fire']=False
  if case in ('fake_proxy_counts','wrong_queue_peak'):
   p=folder/'proxy/receipt.json';v=json.loads(p.read_text());key='forwarded_packets' if case=='fake_proxy_counts' else 'max_queued_bytes';v['directions']['down'][key]+=1;p.write_text(json.dumps(v))
  if case=='missing_packet_event':
   p=folder/'proxy/packets.jsonl';lines=p.read_text().splitlines();at=next(i for i,s in enumerate(lines) if json.loads(s)['event']=='schedule');lines.pop(at);p.write_text('\n'.join(lines)+'\n')
  path.write_text(json.dumps(data))
  run=subprocess.run([sys.executable,str(report),str(root)],text=True,capture_output=True,timeout=40);valid=case=='valid'
  assert (run.returncode==0)==valid,(case,run.stderr);assert (root/'summary.json').exists()==valid,case
  if not valid:assert 'AssertionError' in run.stderr,(case,run.stderr)
  checks.append({'case':case,'accepted':valid})
(source/'report-validation.json').write_text(json.dumps({'report_sha256':hashlib.sha256(report.read_bytes()).hexdigest(),'proxy_verifier_sha256':hashlib.sha256(report.with_name('proxy_report.py').read_bytes()).hexdigest(),'cases':checks},indent=2)+'\n');print('NETWORK_FAULT_REPORT_VALIDATION_OK cases='+str(len(checks)))
