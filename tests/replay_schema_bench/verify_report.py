from pathlib import Path
import json,re,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();script=Path(__file__).with_name('report.py')
cases=['valid','missing_file','extra_file','missing_trial','wrong_hash','zero_duration','missing_dense','wrong_binary']
results=[]
for case in cases:
 with tempfile.TemporaryDirectory(prefix='schema-report-') as directory:
  root=Path(directory);shutil.copy2(source/'build.json',root/'build.json')
  for p in source.glob('[123]-*.log'):shutil.copy2(p,root/p.name)
  for name in json.loads((root/'build.json').read_text())['binaries']:(root/name).symlink_to(source/name)
  p=root/'1-current.log';text=p.read_text()
  if case=='missing_file':p.unlink()
  elif case=='extra_file':shutil.copy2(p,root/'4-current.log')
  elif case=='missing_trial':p.write_text('\n'.join(x for x in text.splitlines() if not x.startswith('SCHEMA_TIMING trial=0 ')))
  elif case=='wrong_hash':p.write_text(re.sub(r'(SCHEMA_TIMING trial=0 .*?hash=)\d+',r'\g<1>1',text,count=1))
  elif case=='zero_duration':p.write_text(re.sub(r'encode_ns_per_call=\d+','encode_ns_per_call=0',text,count=1))
  elif case=='missing_dense':p.write_text('\n'.join(x for x in text.splitlines() if 'case=dense ' not in x))
  elif case=='wrong_binary':
   value=json.loads((root/'build.json').read_text());value['binaries']['current']='0'*64;(root/'build.json').write_text(json.dumps(value))
  run=subprocess.run([sys.executable,str(script),str(root)],capture_output=True,text=True)
  assert (run.returncode==0)==(case=='valid'),(case,run.stdout,run.stderr)
  assert (root/'summary.json').exists()==(case=='valid'),case
  results.append({'case':case,'accepted':run.returncode==0})
(source/'report-validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('REPLAY_SCHEMA_BENCH_REPORT_VALIDATION_OK cases='+str(len(results)))
