from pathlib import Path
import json,os,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];prepared=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
shutil.copy2(root/'tests/replay_cave_comparison/contract.json',out/'contract.json')
orders=[['kit','server','owner'],['server','owner','kit'],['owner','kit','server']]
(out/'order.json').write_text(json.dumps(orders,indent=2)+'\n')
for repetition,order in enumerate(orders,1):
 for variant in order:
  run=out/f'run-{repetition}-{variant}'
  with (out/f'run-{repetition}-{variant}.log').open('w') as log:
   subprocess.run([sys.executable,str(root/'tests/replay_cave_comparison/execute.py'),str(prepared),variant,str(run)],stdout=log,stderr=subprocess.STDOUT,check=True)
  print('CAVE_COMPARISON_WINDOW_OK',repetition,variant,flush=True)
subprocess.run([sys.executable,str(root/'tests/replay_cave_comparison/report.py'),str(out)],check=True)
