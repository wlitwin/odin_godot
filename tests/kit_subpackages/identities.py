"""Resolve identical source spellings by file imports, and ignore alias-only edits."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]
work.mkdir(parents=True, exist_ok=True)


def write(project, relative, text):
    path = project / 'scripts' / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


project = work / 'original'
write(project, 'game.odin', '''//gd:extends Node
package input_game
import gd "godot:godot"
import kboot "godot:kit/boot"
import a "a"
import b "b"
Game :: struct {
    owner: gd.Node,
    boot: kboot.Boot,
    first: gd.Packed_Scene `gd:"entity=a.UnitA:1"`,
    second: gd.Packed_Scene `gd:"entity=b.UnitB:2"`,
}
''')
write(project, 'values/axis.odin', 'package value_types\nAxis :: struct { x: i32 }\n')
for directory, entity in [('a', 'UnitA'), ('b', 'UnitB')]:
    prefix = 'unit_a' if directory == 'a' else 'unit_b'
    write(project, f'{directory}/unit.odin', f'''//gd:extends Node
package units_{directory}
import gd "godot:godot"
import knet "godot:kit/net"
import v "../values"
Input :: struct {{ axis: v.Axis }}
{entity} :: struct {{ owner: gd.Node, net_id: knet.Net_Id, state: v.Axis `gd:"predict"` }}
@(gd_tick)
{prefix}_tick :: proc(self: ^{entity}, input: Input) {{ self.state = input.axis }}
''')
    write(project, f'sample_{directory}.odin', f'''package input_game
import controls "{directory}"
@(gd_sample)
game_sample_{directory} :: proc(self: ^Game, tick: u64, input: ^controls.Input) {{}}
''')


def generate(project, valid=True):
    result = subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'],
                            text=True, capture_output=True)
    (project / 'generate.log').write_text(result.stdout + result.stderr)
    if not valid:
        assert result.returncode != 0 and 'two samples write the same resolved input type' in result.stderr, result.stderr
        assert not list((project / 'scripts').rglob('*.gen.odin'))
        return
    assert result.returncode == 0, result.stderr
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    hashes = re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M)
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S).group(1)
    assert 'input input.Input#1 class=0' in schema and 'input input.Input#2 class=1' in schema, schema
    flags = [f'-collection:godot={root}', '-no-entry-point', '-custom-attribute:gd_tick', '-custom-attribute:gd_sample']
    with (project / 'compile.log').open('w') as output:
        for target in [[], ['-target:freestanding_wasm32']]:
            subprocess.run([odin, 'check', str(project / 'scripts'), *flags, *target],
                           stdout=output, stderr=subprocess.STDOUT, check=True)
    return hashes, schema


baseline = generate(project)
for variant in ['renamed', 'changed', 'duplicate']:
    dest = work / variant
    shutil.copytree(project, dest, ignore=shutil.ignore_patterns('*.gen.odin', '*.log'))
    if variant == 'renamed':
        for directory in ['a', 'b']:
            path = dest / 'scripts' / directory / 'unit.odin'
            path.write_text(path.read_text().replace('import v ', 'import renamed ').replace('v.Axis', 'renamed.Axis'))
        assert generate(dest) == baseline, 'nested alias edit changed wire identity'
    elif variant == 'changed':
        path = dest / 'scripts/values/axis.odin'
        path.write_text(path.read_text().replace('x: i32', 'x: i64'))
        changed = generate(dest)
        assert changed[0] != baseline[0] and changed[1] != baseline[1], 'real layout edit did not change contract'
    else:
        path = dest / 'scripts/sample_b.odin'
        path.write_text(path.read_text().replace('"b"', '"a"'))
        generate(dest, valid=False)
(work / 'report.json').write_text(json.dumps({'file_scoped_input_identity': True,
    'nested_alias_invariance': True, 'layout_change_detected': True, 'duplicate_rejected': True}, indent=2) + '\n')
print('KIT_SUBPACKAGE_IDENTITIES_OK')
