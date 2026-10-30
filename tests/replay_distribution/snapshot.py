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
trees=['core','godot','gdext','libgd','runtime','decl','flow','flowgd','events','kit','play','replay','scriptgen','build','dist/addons/odin_godot']
suffixes={'.odin','.sh','.ps1','.py','.nix','.md','.svg','.cfg','.gd','.tscn','.godot','.gdextension'}
files=[]
for tree in trees:
    for path in sorted((root/tree).rglob('*')):
        if not path.is_file():continue
        relative=path.relative_to(root)
        if any(part in ['bin','.godot','node_modules','out','.git','__pycache__'] or part.endswith('.dSYM') for part in relative.parts):continue
        if path.name.startswith('odin_godot_') and path.name.endswith('.gen.odin'):continue
        if path.suffix not in suffixes and path.name not in ['.gdignore','LICENSE','NOTICE']:continue
        files.append(path)
for name in ['flake.nix','flake.lock','LICENSE','NOTICE']:
    files.append(root/name)
for name in ['authoring-guide.md','workflow.md','exporting.md','debugging.md','modules.md','events.md','recipes.md','design/native-boundary.md']:
    files.append(root/'docs'/name)
files.extend(p for p in (root/'docs/kit').rglob('*') if p.is_file() and p.suffix in ['.md','.svg','.png'])
manifest=[]
for source in sorted(set(files)):
    relative=source.relative_to(root)
    target=destination/relative
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
    manifest.append({'path':str(relative),'bytes':source.stat().st_size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(destination.parent/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'REPLAY_DISTRIBUTION_SNAPSHOT files={len(manifest)}')
