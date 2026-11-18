"""Imported backup containers round-trip and survive package-only edits."""
from pathlib import Path
import json
import re
import shutil
import subprocess
import sys

root, work = map(Path, sys.argv[1:3])
sgen, odin = sys.argv[3:5]
project = work / 'original'
scripts = project / 'scripts'
(scripts / 'blocks').mkdir(parents=True)
(scripts / 'blocks/state.odin').write_text('''package backup_blocks
@(private)
Key :: enum u32 {First, Second}
@(private)
Payload :: struct {value:i32}
State :: struct {
    entries:[dynamic]Payload `gd:"backup"`,
    lookup:map[Key]Payload `gd:"backup"`,
}
''')
(scripts / 'game.odin').write_text('''//gd:extends Node
package backup_game
import gd "godot:godot"
import blocks "blocks"
// Deliberately different from the imported block's private types.
Payload :: struct {value:i64}
Key :: u64
Game :: struct {owner:gd.Node, state:blocks.State}
''')
(scripts / 'backup_test.odin').write_text('''#+build !freestanding
package backup_game
import "core:testing"
import "core:os"
import "base:intrinsics"
import knet "godot:kit/net"
@(test)
backup_roundtrip :: proc(t:^testing.T) {
    source,target:Game
    defer {
        delete(source.state.entries);delete(source.state.lookup)
        delete(target.state.entries);delete(target.state.lookup)
    }
    Value :: intrinsics.type_elem_type(type_of(Game{}.state.entries))
    append(&source.state.entries,Value{value=7},Value{value=-13})
    source.state.lookup[.Second]={value=91}
    writer:=knet.writer_make()
    defer knet.writer_destroy(&writer)
    game_backup_write(&source,&writer)
    WRITE :: #config(BACKUP_WRITE, "")
    when WRITE!="" {testing.expect(t,os.write_entire_file(WRITE,knet.writer_bytes(&writer))==nil)}
    reader:=knet.reader_make(knet.writer_bytes(&writer))
    READ :: #config(BACKUP_READ, "")
    when READ!="" {reader=knet.reader_make(#load(READ))}
    append(&target.state.entries,Value{value=99})
    target.state.lookup[.First]={value=99}
    testing.expect(t,game_backup_read(&target,&reader))
    testing.expect_value(t,len(target.state.entries),2)
    testing.expect_value(t,target.state.entries[0].value,i32(7))
    testing.expect_value(t,target.state.entries[1].value,i32(-13))
    testing.expect_value(t,len(target.state.lookup),1)
    testing.expect_value(t,target.state.lookup[.Second].value,i32(91))
    testing.expect_value(t,len(knet.reader_remaining(&reader)),0)
}
''')


def check(project, original=False):
    result = subprocess.run([sgen, str(project / 'scripts'), f'-godot:{root}', f'-project:{project}'], capture_output=True, text=True)
    (project / 'generate.log').write_text(result.stdout + result.stderr)
    assert result.returncode == 0, result.stderr
    flags = [f'-collection:godot={root}']
    define = f'-define:BACKUP_{"WRITE" if original else "READ"}={work / "saved.bin"}'
    with (project / 'compile.log').open('w') as output:
        subprocess.run([odin, 'test', str(project / 'scripts'), *flags, define, f'-out:{project / "backups.test"}'], stdout=output, stderr=subprocess.STDOUT, check=True)
        subprocess.run([odin, 'check', str(project / 'scripts'), *flags, '-no-entry-point', '-target:freestanding_wasm32'], stdout=output, stderr=subprocess.STDOUT, check=True)
    text = (project / 'scripts/odin_godot_scripts.gen.odin').read_text()
    return re.search(r'^GAME_BACKUP_VERSION :: .*$', text, re.M).group(0)


baseline = check(project, original=True)
for name in ['renamed', 'root_move']:
    dest = work / name
    shutil.copytree(project, dest, ignore=shutil.ignore_patterns('*.gen.odin', '*.log', '*.test'))
    game = dest / 'scripts/game.odin'
    if name == 'renamed':
        (dest / 'scripts/blocks').rename(dest / 'scripts/inventory')
        game.write_text(game.read_text().replace('import blocks "blocks"', 'import saved "inventory"').replace('blocks.State', 'saved.State'))
    else:
        source = dest / 'scripts/blocks/state.odin'
        (dest / 'scripts/state.odin').write_text(source.read_text().replace('package backup_blocks', 'package backup_game'))
        shutil.rmtree(source.parent)
        game.write_text(game.read_text().replace('import blocks "blocks"\n', '').replace('blocks.State', 'State')
                        .replace('Payload :: struct {value:i64}\n', '').replace('Key :: u64\n', ''))
    assert check(dest) == baseline, f'{name} changed the backup version'
(work / 'report.json').write_text(json.dumps({'native': True, 'wasm_check': True,
    'private_imported_container_types': True, 'roundtrip': True,
    'cross_read_original_bytes': True, 'alias_and_move_version_invariance': True}, indent=2) + '\n')
print('KIT_QUALIFIED_BACKUPS_OK')
