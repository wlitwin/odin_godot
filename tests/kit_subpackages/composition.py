"""A local gameplay block can move or change import spelling without wire drift."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]


def contract(project):
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    hashes = re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M)
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S)
    assert len(hashes) == 2 and schema is not None
    return hashes, schema.group(1)


baseline = contract(work)
results = []
for variant in ['renamed', 'bare', 'flat']:
    project = work / variant
    shutil.copytree(root / 'tests/kit_subpackages/bindings', project / 'scripts')
    actor = project / 'scripts/actor.odin'
    text = actor.read_text()
    if variant == 'renamed':
        text = text.replace('import meter "blocks"', 'import renamed "blocks"').replace('meter.Counter', 'renamed.Counter')
    elif variant == 'bare':
        text = text.replace('import meter "blocks"', 'import "blocks"').replace('meter.Counter', 'blocks.Counter')
    else:
        text = text.replace('import meter "blocks"\n', '').replace('meter.Counter', 'Counter')
        block = project / 'scripts/blocks/counter.odin'
        (project / 'scripts/counter.odin').write_text(block.read_text().replace('package local_counter', 'package binding_test'))
        shutil.rmtree(block.parent)
    actor.write_text(text)
    with (project / 'check.log').open('w') as log:
        subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'], stdout=log, stderr=subprocess.STDOUT, check=True)
        assert contract(project) == baseline, variant
        flags = [f'-collection:godot={root}', '-custom-attribute:gd_command', '-custom-attribute:gd_half', '-custom-attribute:gd_method']
        subprocess.run([odin, 'test', str(project / 'scripts'), *flags, f'-out:{project / "bindings.test"}'], stdout=log, stderr=subprocess.STDOUT, check=True)
        subprocess.run([odin, 'check', str(project / 'scripts'), *flags, '-target:freestanding_wasm32', '-no-entry-point'], stdout=log, stderr=subprocess.STDOUT, check=True)
    results.append({'variant': variant, 'same_wire_contract': True, 'native': True, 'wasm_check': True})
(work / 'composition.json').write_text(json.dumps(results, indent=2) + '\n')
print('KIT_LOCAL_COMPOSITION_OK relocation=true alias=true bare_import=true')
