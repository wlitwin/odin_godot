"""Exercise the real protocol-6 fixtures, CLI publication, then fresh Godot resume."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, struct, subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--converter', required=True, type=Path)
parser.add_argument('--work', required=True, type=Path)
parser.add_argument('--project', required=True, type=Path)
parser.add_argument('--godot', required=True)
parser.add_argument('--cli-only', action='store_true')
args = parser.parse_args()
work = args.work.resolve(); work.mkdir(parents=True, exist_ok=True)
fixtures = Path(__file__).parent / 'fixtures/protocol6'
manifest = json.loads((fixtures / 'manifest.json').read_text())
label = manifest['test_token_label']
fixture_paths={name:fixtures/(name+'.replay') for name in manifest['fixtures']}
protocol7=fixtures.parent/'content42_protocol7'
receipt7=json.loads((protocol7/'manifest.json').read_text())
assert receipt7['test_token_label']==label
manifest['fixtures']['protocol7']=receipt7
fixture_paths['protocol7']=protocol7/'run.replay'
content43=fixtures.parent/'content43'
manifest['fixtures']['content43']=json.loads((content43/'manifest.json').read_text())
fixture_paths['content43']=content43/'run.replay' 

content44=fixtures.parent/'content44'
manifest['fixtures']['content44']=json.loads((content44/'manifest.json').read_text())
fixture_paths['content44']=content44/'run.replay'

content45=fixtures.parent/'content45'
manifest['fixtures']['content45']=json.loads((content45/'manifest.json').read_text())
fixture_paths['content45']=content45/'run.replay'

content46=fixtures.parent/'content46'
manifest['fixtures']['content46']=json.loads((content46/'manifest.json').read_text())
fixture_paths['content46']=content46/'run.replay'

content47=fixtures.parent/'content47'
manifest['fixtures']['content47']=json.loads((content47/'manifest.json').read_text())
fixture_paths['content47']=content47/'run.replay'

identity = work / 'identity.bin'
identity.write_bytes(hashlib.sha256(label.encode()).digest()[:16])

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def root(data):
    size = struct.unpack_from('<I', data, 56)[0]
    return data[96:96 + size], data[96 + size:]

def convert(name, source, dest, *, ok=True, identity_option=None, error=None):
    before = digest(source)
    present = dest.exists() or dest.is_symlink()
    previous = digest(dest) if present else None
    cmd = [str(args.converter), str(source), str(dest)] + (identity_option or ['--token', label])
    result = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    (work / (name + '.log')).write_text(result.stdout)
    assert (result.returncode == 0) == ok, (name, result.stdout)
    assert ('REPLAY_SCRAPYARD_UPGRADE_OK' in result.stdout) == ok, (name, result.stdout)
    if error: assert error in result.stdout, (name, result.stdout)
    assert digest(source) == before, f'{name}: source changed'
    if not ok:
        if present: assert digest(dest) == previous, f'{name}: destination changed'
        else: assert not dest.exists() and not dest.is_symlink(), f'{name}: partial destination'
    assert not list(dest.parent.glob('.replay-upgrade-*')), f'{name}: staged file leaked'
    return result.stdout

converted = {}; public_hashes = {}
for name, receipt in manifest['fixtures'].items():
    source = fixture_paths[name]
    assert digest(source) == receipt['sha256'], 'historical fixture changed'
    dest = work / (name + '.replay')
    output=convert(name, source, dest, identity_option=['--identity-file', str(identity)])
    hashes=re.search(r'UPGRADE_STATE_DIGESTS authority=(\d+) public=(\d+)',output);assert hashes,output
    legacy=re.search(r'UPGRADE_LEGACY_STATE authority=(\d+) bytes=(\d+) epoch=(\d+)',output)
    assert legacy and legacy[1]==str(receipt['hash']),output
    public_hashes[name]=hashes[2]
    old_root, old_assets = root(source.read_bytes()); new_root, new_assets = root(dest.read_bytes())
    assert old_assets == new_assets
    assert struct.unpack_from('<Q', old_root, 54)[0] == receipt.get('protocol',6)
    assert struct.unpack_from('<Q', new_root, 54)[0] == 7
    # Remove only the new, independently checked epoch field. Every prior
    # canonical world byte, member, pending frontier and asset must be unchanged.
    field=re.search(r'UPGRADE_EPOCH_FIELD offset=(\d+) bytes=8',output);assert field,output
    offset=int(field[1]);assert struct.unpack_from('<Q',new_root,offset)[0]==int(legacy[3])
    additions=[(int(at),int(size)) for at,size in re.findall(r'UPGRADE_ZERO_FIELD offset=(\d+) bytes=(\d+)',output)]
    assert len(additions)==249  # pulse defaults + turret definitions + empty turret pool
    additions += [(int(at),int(size)) for at,size in re.findall(r'UPGRADE_ZERO_ACTION offset=(\d+) bytes=(\d+)',output)]
    for at,size in additions:assert new_root[at:at+size]==bytes(size)
    extra=8+sum(size for _,size in additions)
    assert len(new_root)==len(old_root)+extra
    without_epoch=new_root
    for at,size in sorted(additions+[(offset,8)],reverse=True):without_epoch=without_epoch[:at]+without_epoch[at+size:]
    assert struct.unpack_from('<I',new_root,40)[0]==struct.unpack_from('<I',old_root,40)[0]+extra
    for start, end in [(0, 24), (52, 54), (70, 78), (86, len(old_root))]:
        assert old_root[start:end] == without_epoch[start:end], (name, start, end)
    assert struct.unpack_from('<Q',new_root,32)[0] == 0x525343524150304b
    assert struct.unpack_from('<Q',new_root,62)[0] == 0x525343524150304b
    converted[name] = dest

plain = fixtures / 'plain.replay'
spray = fixtures / 'spray.replay'
convert('existing', plain, converted['plain'], ok=False, error='publish=Exist')
copy = work / 'same-path.replay'; shutil.copyfile(plain, copy)
convert('same-path', copy, copy, ok=False, error='publish=Exist')
link = work / 'symlink.replay'; link.symlink_to(converted['plain'])
convert('symlink', plain, link, ok=False, error='publish=Exist')
assert link.is_symlink()
convert('wrong-identity', plain, work / 'wrong.replay', ok=False,
        identity_option=['--token', 'unrelated-owner'], error='identity is not')
for name, payload in [('short', b'one'), ('long', b'x' * 17), ('zero', bytes(16))]:
    path = work / (name + '.identity'); path.write_bytes(payload)
    convert(name + '-identity', plain, work / (name + '-identity.replay'), ok=False,
            identity_option=['--identity-file', str(path)])
convert('already-current', converted['plain'], work / 'current.replay', ok=False, error='bundle=Content')
corrupt = work / 'corrupt-source.replay'; data = bytearray(spray.read_bytes()); data[-1] ^= 1; corrupt.write_bytes(data)
convert('corrupt', corrupt, work / 'corrupt.replay', ok=False, error='bundle=Integrity')
raw = work / 'raw-source.replay'; raw.write_bytes(root(plain.read_bytes())[0])
convert('raw', raw, work / 'raw.replay')
missing = work / 'missing-source.replay'; missing.write_bytes(root(spray.read_bytes())[0])
convert('missing', missing, work / 'missing.replay', ok=False, error='missing spray asset')
large = work / 'large-source.replay'
with large.open('wb') as f: f.truncate(16 * 1024 * 1024 + 1)
convert('size', large, work / 'large.replay', ok=False, error='file size outside bounds')

# Valid checksums isolate metadata/content failures from generic corruption.
def recheck_header(data):
    value = 0xcbf29ce484222325
    for byte in data[:44] + data[52:96]:
        value = ((value ^ byte) * 0x100000001b3) & ((1 << 64) - 1)
    struct.pack_into('<Q', data, 44, value)
for name, offset, value, reason in [('metadata', 16, 999, 'container metadata mismatch'),
                                     ('content', 32, 42, 'bundle=Content')]:
    data = bytearray(plain.read_bytes()); struct.pack_into('<Q', data, offset, value); recheck_header(data)
    path = work / (name + '-source.replay'); path.write_bytes(data)
    convert(name, path, work / (name + '.replay'), ok=False, error=reason)
# Two independent writers race to publish different complete runs. One wins;
# the losing publication must neither replace it nor leave staging files behind.
race = work / 'race.replay'
writers = [subprocess.Popen([str(args.converter), str(source), str(race), '--token', label],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
           for source in (plain, spray)]
results = [writer.communicate(timeout=30)[0] for writer in writers]
assert sorted(writer.returncode for writer in writers) == [0, 1], results
for index, result in enumerate(results): (work / f'race-{index}.log').write_text(result)
winner = writers[0].returncode == 0
assert race.read_bytes() == converted['plain' if winner else 'spray'].read_bytes()
assert not list(work.glob('.replay-upgrade-*'))
print('REPLAY_UPGRADE_CLI_OK')
if args.cli_only: raise SystemExit(0)

project = args.project.resolve()
library = Path(os.environ['ODIN_SCRIPTS_DLL']).resolve()
binary_hash = digest(library)
receipts = {'fixtures': manifest, 'binary': {'path': str(library), 'sha256': binary_hash}, 'resumed': {}}
for name in ('plain', 'spray', 'raw', 'protocol7', 'content43', 'content44', 'content45', 'content46', 'content47'):
    directory = work / ('resume-' + name); directory.mkdir()
    expected = dict(manifest['fixtures']['plain' if name == 'raw' else name])
    expected['hash']=public_hashes['plain' if name=='raw' else name]
    (directory / 'saved.json').write_text(json.dumps({'tick': expected['tick'], 'hash': expected['hash']}))
    env = os.environ.copy()
    # Avoid inherited controls changing this deliberately isolated scenario.
    for key in tuple(env):
        if key.startswith('RSY_') or key.startswith('REPLAY_AUTO_'): del env[key]
    env.update(RSY_ROLE='solo', RSY_TOKEN=label, RSY_PERSIST='0', RSY_SAVE=str(work / (name + '.replay')),
               RSY_RESULT_DIR=str(directory), RSY_RUN='0', RSY_ENCOUNTER='migration',
               RSY_SPRAY=str(directory / 'absent.png'), RSY_RESUME='1')
    with (directory / 'game.log').open('w') as log:
        result = subprocess.run([args.godot, '--headless', '--path', str(project), '--script', 'save_test.gd'],
                                env=env, stdout=log, stderr=subprocess.STDOUT, timeout=55)
    text = (directory / 'game.log').read_text()
    assert result.returncode == 0 and 'RSY_SAVE_RESUME_OK' in text, text
    assert not re.search(r'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked|REPLAY_SCRAPYARD_FAIL', text), text
    assert f"RSY_RUN_RESTORED tick={expected['tick']} epoch=2 hash={expected['hash']}" in text
    count = 1 if name == 'spray' else 0; size = 44459 if count else 0
    assert f'RSY_RUN_ASSETS_RESTORED count={count} bytes={size}' in text
    receipts['resumed'][name] = {'tick': expected['tick'], 'hash': expected['hash'], 'assets': count, 'bytes': size}
assert digest(library) == binary_hash, 'game binary changed during gate'
(work / 'receipts.json').write_text(json.dumps(receipts, indent=2) + '\n')
print('REPLAY_SCRAPYARD_UPGRADE_OK')
