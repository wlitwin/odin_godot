"""Qualify contextual generic arguments through input, ABI and composition."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]
flags = [f'-collection:godot={root}', '-custom-attribute:gd_tick',
         '-custom-attribute:gd_sample', '-custom-attribute:gd_input']


def prepare(name):
    project = work / name
    shutil.copytree(root / 'tests/kit_subpackages/generic_fixture', project / 'scripts')
    return project


def generate(project, error=None):
    result = subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'],
                            capture_output=True, text=True, timeout=15)
    (project / 'generate.log').write_text(result.stdout + result.stderr)
    if error:
        assert result.returncode != 0 and error in result.stderr, result.stderr
        assert not list((project / 'scripts').rglob('*.gen.odin'))
        return
    assert result.returncode == 0, result.stderr
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    hashes = re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M)
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S).group(1)
    assert 'items[].axis kind=i32 width=4' in schema, schema
    assert 'native.axis kind=i64 width=8' in schema, schema
    with (project / 'compile.log').open('w') as output:
        subprocess.run([odin, 'test', str(project / 'scripts'), *flags, f'-out:{project / "context.test"}'],
                       stdout=output, stderr=subprocess.STDOUT, check=True)
        subprocess.run([odin, 'check', str(project / 'scripts'), *flags, '-target:freestanding_wasm32', '-no-entry-point'],
                       stdout=output, stderr=subprocess.STDOUT, check=True)
    return hashes, schema


baseline = generate(prepare('original'))
renamed = prepare('renamed')
for path in (renamed / 'scripts').rglob('*.odin'):
    text = path.read_text()
    if path.name == 'actor.odin':
        text = text.replace('import c ', 'import boxes ').replace('c.', 'boxes.')
        text = text.replace('import v ', 'import types ').replace('v.', 'types.')
    elif path.name == 'game.odin':
        text = text.replace('import containers ', 'import templates ').replace('containers.', 'templates.')
        text = text.replace('0x2', '2')
    path.write_text(text)
assert generate(renamed) == baseline, 'alias/literal spelling changed the contract'

counts = prepare('constant_alias')
path = counts / 'scripts/values/types.odin'
path.write_text(path.read_text() + '\nCOUNT :: 0x2\n')
path = counts / 'scripts/actors/actor.odin'
path.write_text(path.read_text().replace('c.Envelope(Local_Type, 2)', 'c.Envelope(Local_Type, v.COUNT,)'))
assert generate(counts) == baseline, 'constant alias or trailing comma changed the contract'

private = prepare('private_alias')
path = private / 'scripts/actors/numeric.odin'
text = path.read_text().replace('import values "../values"', 'import values "../values"\nimport c "../containers"')
text = text.replace('Numeric :: struct', '@(private)\nInternal_Input :: c.Numeric_Input(i16, 2, values.Mode)\nPublic_Input :: Internal_Input\n\nNumeric :: struct')
path.write_text(text.replace('input: values.Sample_Input', 'input: Internal_Input'))
path = private / 'scripts/game.odin'
path.write_text(path.read_text().replace('import values "values"', 'import values "values"\nimport actors "actors"')
                .replace('^containers.Numeric_Input(i16, 2, values.Mode)', '^actors.Public_Input'))
assert generate(private) == baseline, 'public input alias changed the contract'

shared = prepare('external_shared')
common = shared / 'shared/value_types'
common.mkdir(parents=True)
(common / 'types.odin').write_text('package shared_values\nLocal_Type :: struct {axis:i32}\nNumber :: i16\nMode :: enum u16 {First, Second}\n')
path = shared / 'scripts/values/types.odin'
text = path.read_text().replace('import containers "../containers"', 'import containers "../containers"\nimport shared "../../shared/value_types"')
text = text.replace('Local_Type :: struct { axis: i32 }', 'Local_Type :: shared.Local_Type').replace('Number :: i16', 'Number :: shared.Number').replace('Mode :: enum u16 { First, Second }', 'Mode :: shared.Mode')
path.write_text(text)
path = shared / 'scripts/game.odin'
path.write_text(path.read_text().replace('import values "values"', 'import values "values"\nimport shared "../shared/value_types"').replace('values.Local_Type', 'shared.Local_Type'))
assert generate(shared) == baseline, 'external shared vocabulary changed the contract'

distinct = prepare('distinct_instantiations')
path = distinct / 'scripts/actors/numeric.odin'
text = path.read_text().replace('Numeric', 'Wide').replace('numeric_tick', 'wide_tick').replace('value: i16', 'value: i32')
text = text.replace('import values "../values"', 'import values "../values"\nimport c "../containers"').replace('values.Sample_Input', 'c.Numeric_Input(i32, 2, values.Mode)')
(path.parent / 'wide.odin').write_text(text)
path = distinct / 'scripts/game.odin'
path.write_text(path.read_text() + '\n@(gd_sample)\ngame_sample_wide :: proc(self:^Game, tick:u64, input:^containers.Numeric_Input(i32, 2, values.Mode)) {}\n')
path = distinct / 'scripts/context_test.odin'
path.write_text(path.read_text().replace('len(lane.inputs), 3', 'len(lane.inputs), 4'))
different = generate(distinct)
assert different != baseline and 'input.Numeric_Input(i32,2,Mode)' in different[1]

bad = prepare('arity')
path = bad / 'scripts/actors/actor.odin'
path.write_text(path.read_text().replace('c.Envelope(Local_Type, 2)', 'c.Envelope(Local_Type)'))
generate(bad, 'generic argument count')

bad = prepare('recursive')
path = bad / 'scripts/containers/types.odin'
path.write_text(path.read_text().replace('body: Input(T, N)', 'body: Envelope([2]T, N)'))
generate(bad, 'bounded')

bad = prepare('enum')
path = bad / 'scripts/values/types.odin'
path.write_text(path.read_text().replace('Numeric_Input(Number, 2, Mode)', 'Numeric_Input(Number, 2, Local_Type)'))
generate(bad, '`enum` wants a scalar enum')

(work / 'report.json').write_text(json.dumps({'contextual_generics': True,
    'nested_composition': True, 'instantiated_input_rules': True, 'alias_invariance': True,
    'private_alias': True, 'external_shared': True, 'nonwire_backups_and_signals': True,
    'distinct_instantiations': True, 'array_alias_rules': True,
    'constant_aliases': True,
    'arity_refusal': True, 'expansion_bound': True, 'enum_refusal': True,
    'native': True, 'wasm_check': True}, indent=2) + '\n')
print('KIT_GENERIC_CONTEXT_OK')
