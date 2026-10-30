from pathlib import Path
import os,sys,shlex,subprocess,json,hashlib
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();mode=sys.argv[2];label=sys.argv[3] if len(sys.argv)>3 else mode;folder=out/label;folder.mkdir(exist_ok=False);project=out/'project'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
s=(root/'examples/replay_claimball/network_run.sh').read_text().replace('PROJ="$ROOT/examples/replay_claimball"','PROJ='+shlex.quote(str(project))).replace('work="$(mktemp -d)"','work='+shlex.quote(str(folder/'logs')));(folder/'logs').mkdir()
start=s.index('if [[ "${REPLAY_PREBUILT:-0}"');end=s.index('export RCB_PORT=',start)
s=s[:start]+'''case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
'''+s[end:];(folder/'runner.sh').write_text(s)
(folder/'binaries.json').write_text(json.dumps({p.name:sha(p) for p in (project/'bin').glob('*.dylib' if sys.platform=='darwin' else '*.so')},indent=2)+'\n')
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(root),REPLAY_KEEP_LOGS='1',RCB_PERSIST='0')
if mode in ('compete','fault'):env.update(RCB_CONTEST='1',RCB_TEST_GOALS='3')
if mode=='fault':env.update(RCB_REQUIRE_FAULTS='1',RCB_JITTER='20',RCB_LOSS='1000',RCB_DUPLICATE='1000')
if mode=='stall':env['RCB_STALL_MS']='800'
with (folder/'run.log').open('w') as log:result=subprocess.run(['bash',str(folder/'runner.sh')],env=env,stdout=log,stderr=subprocess.STDOUT)
print('CLAIMBALL_REGRESSION',mode,result.returncode);sys.exit(result.returncode)
