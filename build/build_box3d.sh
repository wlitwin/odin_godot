#!/usr/bin/env bash
# Usage: bash build/build_box3d.sh [Debug|Release] [CACHE]
# Output: CACHE/build/CONFIG/libogb3.a plus libogb3.{dylib,so}, tests and
# build-manifest.json. Native C only. CC/CMAKE_GENERATOR and CMAKE_ARGS are
# honored; CMAKE_ARGS must be a JSON array (no shell evaluation).
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
CONFIG=${1:-Debug}
CACHE=${2:-"$REPO/.box3d-cache"}
case "$CONFIG" in WebScalar|WebSIMD) exec python3 "$REPO/build/build_box3d_web.py" "$CONFIG" "$CACHE";; Debug|Release) ;; *) echo 'configuration must be Debug, Release, WebScalar or WebSIMD' >&2; exit 2;; esac
mkdir -p "$CACHE"
CACHE=$(cd "$CACHE" && pwd)
export OGB3_REPO="$REPO" OGB3_CACHE="$CACHE" OGB3_CONFIG="$CONFIG"
python3 - <<'PY'
import fcntl,hashlib,json,os,pathlib,platform,shlex,shutil,subprocess,tarfile,tempfile
repo=pathlib.Path(os.environ['OGB3_REPO']);cache=pathlib.Path(os.environ['OGB3_CACHE']);config=os.environ['OGB3_CONFIG']
manifest_bytes=(repo/'box3d/dependency.json').read_bytes()
manifest=json.loads(manifest_bytes)
# Debug and Release may share a cache. Serialize fetch/extract/patch publication,
# then release the lock before independent per-configuration compilation.
import sys
sys.path.insert(0,str(repo/'build'))
from box3d_source import prepare_source
source=prepare_source(repo,cache,manifest)
def run(*args,**kw): return subprocess.run(args,check=True,**kw)
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def native_inputs():
    paths=[p for p in (repo/'box3d/native').rglob('*') if p.is_file()]
    paths += [repo/'box3d/dependency.json',repo/'build/build_box3d.sh',repo/'build/box3d_source.py']
    for test in sorted((repo/'tests/box3d_soak/native_observe').rglob('*')):
        if test.is_file() and test.suffix in ('.c','.h'): paths.append(test)
    for directory in ['tests/box3d_native','tests/box3d_recovery','tests/box3d_modules/native','tests/box3d_authoring/native','tests/box3d_motion/native','tests/box3d_upgrade']:
        for test in sorted((repo/directory).rglob('*')):
            if test.is_file() and (test.suffix in ('.c','.h','.py') or test.name=='fields.json'): paths.append(test)
    return {str(p.relative_to(repo)):digest(p) for p in sorted(paths)}
if digest(repo/'box3d/dependency.json')!=hashlib.sha256(manifest_bytes).hexdigest(): raise SystemExit('dependency manifest changed during source preparation; rerun')
inputs_before=native_inputs()
build=cache/'build'/config
extra=json.loads(os.environ.get('CMAKE_ARGS','[]'))
if not isinstance(extra,list) or not all(isinstance(s,str) for s in extra): raise SystemExit('CMAKE_ARGS must be JSON string array')
if any(arg in ['-S','-B','--build','--install'] or arg.startswith(('-S','-B')) for arg in extra):
    raise SystemExit('CMAKE_ARGS may not override driver source/output paths')
# Required provenance/configuration options follow user options so accidental
# duplicate -D values cannot select an unverified engine source tree.
run('cmake','-S',str(repo/'box3d/native'),'-B',str(build),*extra,
    '-DCMAKE_BUILD_TYPE='+config,'-DOGB3_ENGINE_SOURCE='+str(source),'-DCMAKE_EXPORT_COMPILE_COMMANDS=ON')
commands=json.loads((build/'compile_commands.json').read_text())
# Verify effective commands retain FP and assertions; extra flags cannot silently
# weaken these requirements. CMake policy appends its flags after user C flags.
for c in commands:
    flags=shlex.split(c['command'])
    if '-ffast-math' in flags or '-Ofast' in flags or '-ffp-contract=fast' in flags: raise SystemExit('forbidden FP flags')
    if '-UNDEBUG' not in flags or flags.index('-UNDEBUG') < max((i for i,f in enumerate(flags) if f=='-DNDEBUG'),default=-1): raise SystemExit('assertion policy mismatch')
    if '-fno-fast-math' not in flags or '-ffp-contract=off' not in flags: raise SystemExit('FP policy mismatch')
# Record the compiler-resolved SIMD/precision/word-size macros using the same
# engine compile flags, rather than inferring SIMD from the host architecture.
engine_command=next(c for c in commands if '/src/aabb.c' in c['file'])
preprocess=[];words=shlex.split(engine_command['command']);i=0
while i<len(words):
    if words[i]=='-o': i+=2;continue
    if words[i]=='-c': i+=1;continue
    preprocess.append(words[i]);i+=1
macro_text=subprocess.check_output([*preprocess,'-dM','-E'],cwd=engine_command['directory'],text=True)
resolved={}
for line in macro_text.splitlines():
    bits=line.split(maxsplit=2)
    if len(bits)>=2 and (bits[1].startswith('B3_SIMD_') or bits[1] in ['BOX3D_DOUBLE_PRECISION','BOX3D_DISABLE_SIMD','BOX3D_VALIDATE','B3_ENABLE_ASSERT','__FLT_EVAL_METHOD__','__STDC_VERSION__','__SIZEOF_POINTER__','__BYTE_ORDER__']):
        resolved[bits[1]]=bits[2] if len(bits)==3 else ''
run('cmake','--build',str(build),'--parallel',os.environ.get('JOBS','6'))
test_names=[t['name'] for t in json.loads(subprocess.check_output(['ctest','--test-dir',str(build),'--show-only=json-v1'],text=True))['tests']]
if test_names: run('ctest','--test-dir',str(build),'--output-on-failure')
if native_inputs()!=inputs_before: raise SystemExit('native inputs changed during build; rerun for coherent evidence')
metadata={'schema_version':1,'host':platform.platform(),'machine':platform.machine(),'configuration':config,
    'native_observation_enabled': 'OGB3_NATIVE_OBSERVATION:BOOL=ON' in (build/'CMakeCache.txt').read_text().splitlines(),
    'dependency_manifest':manifest,'resolved_simulation_macros':resolved,'dependency_manifest_sha256':digest(repo/'box3d/dependency.json'),
    'compiler_version':subprocess.check_output([shlex.split(commands[0]['command'])[0],'--version'],text=True).strip(),
    'cmake_version':subprocess.check_output(['cmake','--version'],text=True).splitlines()[0],
    'commands':commands,'native_sources':inputs_before,
    'archive_sha256':digest(build/'libogb3.a'),'ctest':'passed' if test_names else 'no_tests_configured','test_names':test_names,'cmake_args':extra}
(build/'build-manifest.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('ogb3 archive: '+str(build/'libogb3.a'))
print('ogb3 evidence: '+str(build/'build-manifest.json'))
PY
