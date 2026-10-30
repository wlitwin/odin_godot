from pathlib import Path
import json
import os
import re
import statistics
import subprocess
import sys

build=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
extension='dylib' if sys.platform=='darwin' else 'so'
rows=[]
cases=[(1,1),(8,8),(1,1024),(8,1024),(64,64),(512,512),(1024,1024)]
for count,capacity in cases:
    for repetition in range(3):
        modes=['baseline','indexed','cached','typed']
        modes=modes[repetition:]+modes[:repetition]
        for mode in modes:
            project=build/('baseline' if mode=='baseline' else 'current')
            name=f'{count}-{capacity}-{repetition}-{mode}'
            env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{extension}'),'REPLAY_NODES_MODE':'bench','REPLAY_NODES_COUNT':str(count),'REPLAY_NODES_CAPACITY':str(capacity),'REPLAY_NODES_TYPED':'1' if mode=='typed' else '0','REPLAY_NODES_CACHE':'1' if mode in ['cached','typed'] else '0'}
            with (out/f'{name}.log').open('w') as log:
                subprocess.run([os.environ['GODOT'],'--headless','--path',str(project)],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=60)
            text=(out/f'{name}.log').read_text()
            assert 'REPLAY_NODES_OK' in text
            assert not any(x in text for x in ['SCRIPT ERROR','ERROR:','instances were leaked','resources still in use']),name
            times=[int(x) for x in re.findall(r'frames=120 us=(\d+)',text)]
            assert len(times)==5
            row={'count':count,'capacity':capacity,'repetition':repetition,'mode':mode,'batch_us':times,'median_frame_us':statistics.median(times)/120}
            if mode!='baseline':
                ops=re.search(r'REPLAY_NODES_OPS writes=(\d+) skips=(\d+) probes=(\d+)',text);assert ops
                writes,skips,probes=map(int,ops.groups());row.update(writes=writes,skips=skips,probes=probes)
                assert writes==(723 if mode in ['cached','typed'] else 2884)*count
                assert skips==(2161 if mode in ['cached','typed'] else 0)*count
            rows.append(row)
summary=[]
for count,capacity in cases:
    item={'count':count,'capacity':capacity}
    for mode in ['baseline','indexed','cached','typed']:
        item[mode+'_median_frame_us']=statistics.median(row['median_frame_us'] for row in rows if row['count']==count and row['capacity']==capacity and row['mode']==mode)
    summary.append(item)
(out/'result.json').write_text(json.dumps({'pass':True,'workload':'moving x; fixed rotation/scale/color; 120 calls per sample; warm-up plus five samples per process; three rotated process repetitions','scope':'presentation-call wall time; excludes scene construction, rendered frames and GPU work','rows':rows,'summary':summary},indent=2)+'\n')
print(json.dumps(summary,indent=2));print('REPLAY_NODES_BENCHMARK_OK')
