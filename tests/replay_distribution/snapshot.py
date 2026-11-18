"""Freeze only addon build inputs, including unstaged Replay sources, for Nix.

The shared worktree/index is never changed. Generated binaries, caches, examples,
test results and private runtime data are not inputs to the addon package.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys

root=Path(sys.argv[1]).resolve()
destination=Path(sys.argv[2]).resolve()
destination.mkdir(parents=True,exist_ok=False)
trees=['core','godot','gdext','libgd','runtime','decl','flow','flowgd','events','kit','play','replay','box3d','authoring','scriptgen','build','dist/addons/odin_godot',
       'addons/box3d_authoring','examples/box3d_starter',
       'tests/box3d_capacity/native','tests/box3d_native','tests/box3d_recovery',
       'tests/box3d_modules/native','tests/box3d_authoring/native','tests/box3d_motion/native',
       'tests/box3d_upgrade','tests/box3d_soak/native_observe']
suffixes={'.odin','.sh','.ps1','.py','.nix','.md','.svg','.cfg','.gd','.tscn','.tres','.godot','.gdextension','.wav','.patch'}
files=[]
for tree in trees:
    for path in sorted((root/tree).rglob('*')):
        if not path.is_file():continue
        relative=path.relative_to(root)
        if any(part in ['bin','.godot','node_modules','out','.git','__pycache__'] or part.endswith('.dSYM') for part in relative.parts):continue
        if path.name.startswith('odin_godot_') and path.name.endswith('.gen.odin'):continue
        backend_input=(tree=='box3d' or tree.startswith('tests/box3d')) and (path.suffix in ['.json','.c','.h','.patch'] or path.name in ['CMakeLists.txt','THIRD_PARTY_NOTICES.txt'])
        template_manifest=relative.parts[:2]==('build','template') and path.suffix=='.json'
        if path.suffix not in suffixes and path.name not in ['.gdignore','LICENSE','NOTICE'] and not backend_input and not template_manifest:continue
        files.append(path)
for name in ['flake.nix','flake.lock','LICENSE','NOTICE']:
    files.append(root/name)
files.extend((root/'docs').glob('*.md'))
for section in ['scripting','kit','replay','box3d','libraries','examples','multiplayer','learn','contributing','onboarding','img']:
    files.extend(p for p in (root/'docs'/section).rglob('*')
                 if p.is_file() and 'results' not in p.relative_to(root/'docs').parts
                 and p.suffix in ['.md','.svg','.png'])
manifest=[]
for source in sorted(set(files)):
    relative=source.relative_to(root)
    target=destination/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
    manifest.append({'path':str(relative),'bytes':source.stat().st_size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(destination.parent/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'REPLAY_DISTRIBUTION_SNAPSHOT files={len(manifest)}')
