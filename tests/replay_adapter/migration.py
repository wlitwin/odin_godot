"""Run the existing real crash-takeover fixture against isolated built projects."""
from pathlib import Path
import os,sys
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'replay/testing/tools'))
from peers import Peer,run
project,coordinator,out=map(lambda p:Path(p).resolve(),sys.argv[1:])
out.mkdir(parents=True,exist_ok=False)
# Keep the existing protocol/assertions; substitute only its project/output paths.
source=(root/'examples/replay_scrapyard/migration_run.sh').read_text()
replacements={'PROJ="$ROOT/examples/replay_scrapyard"':'PROJ="$REPLAY_ADAPTER_PROJECT"',
              'COORD="$ROOT/tests/replay_migration"':'COORD="$REPLAY_ADAPTER_COORDINATOR"',
              'work="$(mktemp -d)"':'work="$REPLAY_ADAPTER_MIGRATION_OUT"'}
for old,new in replacements.items():
    assert source.count(old)==1,old
    source=source.replace(old,new)
script=out/'run.sh';script.write_text(source)
env=os.environ|{'ODIN_GODOT_ROOT':str(root),'REPLAY_ADAPTER_PROJECT':str(project),'REPLAY_ADAPTER_COORDINATOR':str(coordinator),
 'REPLAY_ADAPTER_MIGRATION_OUT':str(out),'REPLAY_PREBUILT':'1','REPLAY_KEEP_LOGS':'1','REPLAY_MIGRATION_PHASE':'crash',
 'RSY_PERSIST':'0','RSY_SETTINGS_PATH':str(out/'settings.json'),'RSY_MODS_DIR':str(out/'no-mods')}
run([Peer('receipt',['bash',str(script)],env,('REPLAY_SCRAPYARD_CRASH_OK',))],out,timeout=110,stagger=0)
assert 'REPLAY_SCRAPYARD_CRASH_OK' in (out/'receipt.log').read_text()
print('REPLAY_ADAPTER_CRASH_OK')
