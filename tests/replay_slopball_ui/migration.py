from pathlib import Path
import os,sys,shlex,subprocess,json,hashlib
root=Path(__file__).resolve().parents[2];app=Path(sys.argv[1]).resolve();coord=Path(sys.argv[2]).resolve();out=Path(sys.argv[3]).resolve();out.mkdir();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for base in [app,coord]:
 for name,digest in json.loads((base/'prepared.json').read_text()).items():assert sha(base/'project'/name)==digest,name
s=(root/'examples/replay_slopball/migration_run.sh').read_text().replace('PROJ="$ROOT/examples/replay_slopball"','PROJ='+shlex.quote(str(app/'project'))).replace('COORD="$ROOT/tests/replay_migration"','COORD='+shlex.quote(str(coord/'project'))).replace('work="$(mktemp -d)"','work='+shlex.quote(str(out/'logs')));(out/'logs').mkdir()
a=s.index('if [[ "${REPLAY_PREBUILT:-0}"');b=s.index('export REPLAY_MIGRATION_GAME=',a)
s=s[:a]+'''case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
'''+s[b:];(out/'runner.sh').write_text(s)
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(root),REPLAY_KEEP_LOGS='1',RSL_PERSIST='0')
with (out/'run.log').open('w') as log:result=subprocess.run(['bash',str(out/'runner.sh')],env=env,stdout=log,stderr=subprocess.STDOUT)
print('SLOPBALL_MIGRATION_REGRESSION',result.returncode);sys.exit(result.returncode)
