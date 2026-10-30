"""Run the existing gameplay/migration gates against an isolated verified build."""
from pathlib import Path
import os,sys,shlex,subprocess,shutil,json,hashlib
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();kind=sys.argv[2];folder=out/kind;folder.mkdir(exist_ok=False);project=out/'project';coord=Path(sys.argv[3]).resolve() if len(sys.argv)>3 else None
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
original=(root/'examples/replay_quickdraw'/(kind+'_run.sh')).read_text()
s=original.replace('PROJ="$ROOT/examples/replay_quickdraw"','PROJ='+shlex.quote(str(project))).replace('work="$(mktemp -d)"','work='+shlex.quote(str(folder/'logs')))
(folder/'logs').mkdir()
start=s.index('if [[ "${REPLAY_PREBUILT:-0}"');end=s.index('phases=(rewound live lobs)' if kind=='network' else 'export REPLAY_MIGRATION_GAME=quickdraw',start)
s=s[:start]+'''case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
'''+s[end:]
if kind=='migration':
 assert coord is not None;s=s.replace('COORD="$ROOT/tests/replay_migration"','COORD='+shlex.quote(str(coord)))
 shutil.copy2(root/'tests/replay_quickdraw_ui/migration_social.gd',project/'migration_social_test.gd')
 s=s.replace('--script migration_test.gd','--script migration_social_test.gd')
 s=s.replace('RQ_MEMBER="$member" RQ_INCARNATION=', 'RQ_NAME="Member $member" RQ_MEMBER="$member" RQ_INCARNATION=')
for name in ('RQ_UI_ROLE','RQ_BOT','RQ_ROLE','RQ_NAME','RQ_COORD_PORT','RQ_TEST_SECONDS','RQ_MANUAL_START'):
 if name in os.environ:raise SystemExit('Do not inherit workload override '+name)
(folder/'runner.sh').write_text(s);(folder/'original-runner.sh').write_text(original)
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(root),REPLAY_KEEP_LOGS='1',RQ_PERSIST='0')
with (folder/'run.log').open('w') as log:
 result=subprocess.run(['bash',str(folder/'runner.sh')],env=env,stdout=log,stderr=subprocess.STDOUT)
print('QUICKDRAW_REGRESSION',kind,result.returncode);sys.exit(result.returncode)
