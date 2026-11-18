"""Imported schema references use declaration context and semantic values."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]


def prepare(name):
    project = work / name
    shutil.copytree(root / 'tests/kit_subpackages/schema_fixture', project / 'scripts')
    return project


def check(project, error=None):
    result = subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'], capture_output=True, text=True)
    (project / 'generate.log').write_text(result.stdout + result.stderr)
    if error:
        assert result.returncode != 0 and error in result.stderr, result.stderr
        assert not list((project / 'scripts').rglob('*.gen.odin'))
        return
    assert result.returncode == 0, result.stderr
    text = (project / 'scripts/odin_godot_guard.gen.odin').read_text()
    schema = re.search(r'NET_SCHEMA_CANONICAL :: `(.*?)`', text, re.S).group(1)
    assert 'profile profile.Row encoding=raw width=4' in schema, schema
    assert 'message message.Game.ping tag=' in schema, schema
    assert 'custom:SIGNED_V1' in schema, schema
    with (project / 'compile.log').open('w') as log:
        flags = [f'-collection:godot={root}', '-custom-attribute:gd_message']
        subprocess.run([odin, 'test', str(project / 'scripts'), *flags, f'-out:{project / "schema.test"}'], stdout=log, stderr=subprocess.STDOUT, check=True)
        subprocess.run([odin, 'check', str(project / 'scripts'), *flags, '-target:freestanding_wasm32', '-no-entry-point'], stdout=log, stderr=subprocess.STDOUT, check=True)
    return re.findall(r'^NET_(?:ABI_)?FINGERPRINT :: .*$', text, re.M), schema


baseline = check(prepare('original'))
renamed = prepare('renamed')
for filename in ['game.odin', 'messages.odin', 'blocks/block.odin']:
    path = renamed / 'scripts' / filename
    text = path.read_text().replace('import rows ', 'import profiles ').replace('rows.Row', 'profiles.Row')
    if filename == 'messages.odin':
        text = text.replace('import data ', 'import payloads ').replace('data.Payload', 'payloads.Payload')
        text = text.replace('import routes ', 'import codes ').replace('routes.PING', 'codes.PING')
    elif filename == 'blocks/block.odin':
        text = text.replace('import values ', 'import encodings ').replace('values.SIGNED_V1', 'encodings.SIGNED_V1')
    path.write_text(text)
assert check(renamed) == baseline

moved = prepare('moved_codec')
(moved / 'scripts/wireformats').rename(moved / 'scripts/encodings')
path = moved / 'scripts/blocks/block.odin'
path.write_text(path.read_text().replace('"../wireformats"', '"../encodings"'))
assert check(moved) == baseline

for name, filename, old, new in [('profile', 'profiles/row.odin', 'u32', 'f32'),
                                ('payload', 'packets/payload.odin', 'u32', 'f32'),
                                ('tag', 'tags/tags.odin', 'u8(4)', 'u8(5)'),
                                ('codec', 'wireformats/codec.odin', 'size = 4', 'size = 8')]:
    changed = prepare(name)
    path = changed / 'scripts' / filename
    path.write_text(path.read_text().replace(old, new))
    result = check(changed)
    assert result[0] != baseline[0] and result[1] != baseline[1], name

duplicate = prepare('duplicate')
path = duplicate / 'scripts/messages.odin'
path.write_text(path.read_text() + '\n@(gd_message="4")\ngame_again :: proc(self:^Game, from:knet.Player_Id, msg:data.Payload) {}\n')
check(duplicate, 'tag 4 is already used')

ambiguous = prepare('ambiguous_codec')
path = ambiguous / 'scripts/game.odin'
path.write_text(path.read_text().replace('block: blocks.Block(i32),', 'block: blocks.Block(i32),\n    other:i32 `gd:"replicate,wire=values.SIGNED_V1"`,'))
check(ambiguous, 'codec identity SIGNED_V1 also names')
(work / 'report.json').write_text(json.dumps({'profile_install': True, 'message_scope': True,
    'per_instance_routes': True, 'exact_payload_bounds': True, 'alias_invariance': True,
    'same_size_layout_changes_detected': True, 'tag_change_detected': True,
    'duplicate_tag_refused': True, 'private_codec_and_blend': True, 'codec_move_invariance': True, 'codec_width_change_detected': True, 'ambiguous_codec_refused': True, 'native': True, 'wasm_check': True}, indent=2) + '\n')
print('KIT_SCHEMA_REFERENCES_OK')
