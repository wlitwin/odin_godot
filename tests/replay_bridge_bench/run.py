from pathlib import Path
import hashlib,json,platform,re,statistics,subprocess,sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
binary=out/'core-bench'
subprocess.run(['odin','build',str(root/'tests/replay_bridge_bench'),f'-collection:godot={root}','-o:speed',f'-out:{binary}'],check=True)
rows=[];shapes={};finals={}
for repeat in range(3):
 log=subprocess.check_output([str(binary)],text=True);(out/f'core-{repeat}.log').write_text(log)
 assert 'REPLAY_BRIDGE_BENCH_OK' in log
 for line in log.splitlines():
  if line.startswith('SHAPE '):
   record=dict(piece.split('=',1) for piece in line.split()[1:]);name=record.pop('name');record={k:int(v) for k,v in record.items()}
   assert name not in shapes or shapes[name]==record;shapes[name]=record
  if line.startswith('COST '):
   record=dict(piece.split('=',1) for piece in line.split()[1:]);name=record.pop('name');record={k:int(v) for k,v in record.items()};rows.append({'name':name,'repeat':repeat,**record,'ns_per_call':record['ns']/record['iterations']})
  if line.startswith('FINAL '):
   record=dict(piece.split('=',1) for piece in line.split()[1:]);name=record.pop('name');assert name not in finals or finals[name]==record;finals[name]=record
assert len(rows)==270, len(rows)
names=['read_then_project','project','encode_authority','hash_canonical','advance','replay_16','materialized_read','encode_public','hash_public']
summary={name:{mode:statistics.median(r['ns_per_call'] for r in rows if r['name']==name and r['mode']==i) for i,mode in enumerate(names)} for name in shapes}
report={'platform':platform.platform(),'odin':subprocess.check_output(['odin','version'],text=True).strip(),'flags':['-o:speed'],'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'shapes':shapes,'finals':finals,'rows':rows,'median_ns':summary}
(out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'shapes':shapes,'median_ns':summary},indent=2));print('REPLAY_BRIDGE_BENCH_OK')
