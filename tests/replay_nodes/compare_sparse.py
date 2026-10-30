from pathlib import Path
import json,os,re,statistics,subprocess,sys
before,after,out=map(lambda p:Path(p).resolve(),sys.argv[1:]);out.mkdir(parents=True,exist_ok=False)
extension='dylib' if sys.platform=='darwin' else 'so'
rows=[];cases=[(1,1),(8,8),(1,1024),(8,1024),(64,64),(512,512),(1024,1024)]
for count,capacity in cases:
 for repeat in range(3):
  modes=[(version,kind) for version in ['before','after'] for kind in ['indexed','cached','typed']]
  modes=modes[repeat:]+modes[:repeat]
  for version,kind in modes:
   project=(before if version=='before' else after)/'current'
   env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{extension}'),'REPLAY_NODES_MODE':'bench','REPLAY_NODES_COUNT':str(count),'REPLAY_NODES_CAPACITY':str(capacity),'REPLAY_NODES_CACHE':'0' if kind=='indexed' else '1','REPLAY_NODES_TYPED':'1' if kind=='typed' else '0'}
   name=f'{count}-{capacity}-{repeat}-{version}-{kind}';path=out/f'{name}.log'
   with path.open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--path',str(project)],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
   text=path.read_text();assert 'REPLAY_NODES_OK' in text and not any(x in text for x in ['ERROR:','SCRIPT ERROR','instances were leaked','resources still in use'])
   batches=[int(x) for x in re.findall(r'frames=120 us=(\d+)',text)];assert len(batches)==5
   writes,skips,probes=map(int,re.search(r'REPLAY_NODES_OPS writes=(\d+) skips=(\d+) probes=(\d+)',text).groups())
   assert writes==(2884 if kind=='indexed' else 723)*count and skips==(0 if kind=='indexed' else 2161)*count
   if kind=='typed':
    paints,skipped=map(int,re.search(r'REPLAY_TYPED_OPS paints=(\d+) skips=(\d+)',text).groups());assert paints==count and skipped==720*count
   rows.append({'count':count,'capacity':capacity,'repeat':repeat,'version':version,'kind':kind,'batch_us':batches,'median_us':statistics.median(batches)/120,'writes':writes,'skips':skips,'probes':probes})
summary=[]
for count,capacity in cases:
 row={'count':count,'capacity':capacity}
 for version in ['before','after']:
  for kind in ['indexed','cached','typed']:row[version+'_'+kind]=statistics.median(r['median_us'] for r in rows if r['count']==count and r['capacity']==capacity and r['kind']==kind and r['version']==version)
 summary.append(row)
(out/'result.json').write_text(json.dumps({'pass':True,'rows':rows,'summary':summary},indent=2)+'\n');print(json.dumps(summary,indent=2));print('REPLAY_SPARSE_COMPARE_OK')
