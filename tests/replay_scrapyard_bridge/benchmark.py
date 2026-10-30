from pathlib import Path
import hashlib,json,os,platform,re,statistics,subprocess,sys
work=Path(sys.argv[1]).resolve();out=work/'timings';out.mkdir(exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so';rows=[]
for count in [0,8,32]:
 for repeat in range(3):
  for mode in (['before','after'] if repeat%2==0 else ['after','before']):
   project=work/mode/'project';logpath=out/f'{count}-{repeat}-{mode}.log'
   env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'RSY_PERSIST':'0','RSY_SETTINGS_PATH':str(out/'settings.json'),'SCRAP_BRIDGE_COUNT':str(count)}
   with logpath.open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','bridge_bench.gd'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=40)
   text=logpath.read_text();assert 'unchanged=true' in text and 'SCRAP_BRIDGE_RENDER_OK' in text
   assert not any(s in text for s in ['ERROR:','SCRIPT ERROR','_FAIL','instances were leaked','resources still in use'])
   samples=[int(n) for n in re.findall('frames=120 us=(\\d+)',text)];assert len(samples)==5
   nodes=int(re.search(r'SCRAP_BRIDGE_NODE_COUNT (\d+)',text)[1])
   rows.append({'mode':mode,'count':count,'repeat':repeat,'batch_us':samples,'median_us':statistics.median(samples)/120,'staged_world_nodes':nodes})
summary=[]
for count in [0,8,32]:
 row={'mobs_and_drops_each':count}
 for mode in ['before','after']:row[mode+'_us']=statistics.median(r['median_us'] for r in rows if r['mode']==mode and r['count']==count)
 summary.append(row)
report={'platform':platform.platform(),'build_flags':['-debug'],'script_build_flags':os.environ.get('SCRIPT_BUILD_FLAGS',''),'rows':rows,'summary':summary,'binaries':{mode:hashlib.sha256((work/mode/f'project/bin/libodinscripts.{ext}').read_bytes()).hexdigest() for mode in ['before','after']}}
(out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(summary,indent=2));print('REPLAY_SCRAP_BRIDGE_BENCH_OK')
