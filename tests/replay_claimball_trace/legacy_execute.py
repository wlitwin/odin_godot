from pathlib import Path
import hashlib,json,os,shlex,subprocess,sys
root=Path(__file__).resolve().parents[2];base=Path(sys.argv[1]).resolve();label=sys.argv[2];out=base/label;out.mkdir();(out/'logs').mkdir();project=base/'project';overlay=base/'collection';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((base/'prepared.json').read_text()).items():assert sha(project/n)==h,n
for n,h in json.loads((base/'overlay.json').read_text()).items():assert sha(overlay/n)==h,n
s=(project/'network_run.sh').read_text().replace('PROJ="$ROOT/examples/replay_claimball"','PROJ='+shlex.quote(str(project))).replace('work="$(mktemp -d)"','work='+shlex.quote(str(out/'logs')))
a=s.index('if [[ "${REPLAY_PREBUILT:-0}"');b=s.index('export RCB_PORT=',a)
s=s[:a]+'''case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
'''+s[b:];(out/'runner.sh').write_text(s)
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(overlay),REPLAY_KEEP_LOGS='1',RCB_PERSIST='0',RCB_CONTEST='1',RCB_TEST_GOALS='3',RCB_REQUIRE_FAULTS='1',RCB_JITTER='20',RCB_LOSS='1000',RCB_DUPLICATE='1000',RCB_TRACE=str(out/'logs/observer.trace'))
with (out/'run.log').open('w') as log:r=subprocess.run(['bash',str(out/'runner.sh')],env=env,stdout=log,stderr=subprocess.STDOUT)
(out/'builds.json').write_text(json.dumps({p.name:sha(p) for p in (project/'bin').glob('*.dylib')},indent=2)+'\n')
print('LEGACY_CLAIMBALL_FAULT',label,r.returncode);sys.exit(r.returncode)
