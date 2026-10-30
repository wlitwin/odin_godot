"""Exercise actual Godot exports from an isolated built/imported project."""
from pathlib import Path
import importlib.util
import json
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
project, out = map(lambda p: Path(p).resolve(), sys.argv[1:])
out.mkdir(parents=True, exist_ok=False)
spec = importlib.util.spec_from_file_location('stock', root/'examples/replay_scrapyard/tools/stock.py')
stock = importlib.util.module_from_spec(spec); spec.loader.exec_module(stock)
stock.ROOT = project

def invoke(*args):
    sys.argv = ['stock.py', *args]
    stock.main()

invoke('--check')
artifact = project / stock.ARTIFACT
manifest = project / stock.RECEIPT
before, receipt = artifact.read_bytes(), manifest.read_bytes()
source = project/'data/attacks/storm_pulse.tres'
original = source.read_text()
try:
    source.write_text(original.replace('radius = 140.0', 'radius = 160.0').replace('radius = 140\n', 'radius = 160\n'))
    assert source.read_text()!=original, 'fixture radius spelling changed'
    try:
        invoke('--check')
    except (ValueError, SystemExit):
        pass
    else:
        raise AssertionError('stale nested Resource accepted')
    invoke('--project', str(project))
    invoke('--check')
    changed = artifact.read_bytes()
    assert changed[52:]!=before[52:], 'nested Resource did not affect canonical output'
    assert json.loads(manifest.read_text())['schema']==json.loads(receipt)['schema']
    # Invalid nested definition must not replace the last valid artifact/receipt.
    prior_artifact, prior_receipt = changed, manifest.read_bytes()
    source.write_text(source.read_text().replace('radius = 160.0', 'radius = -1.0').replace('radius = 160\n','radius = -1\n'))
    try:
        invoke('--project', str(project))
    except SystemExit as error:
        (out/'invalid-export.log').write_text(str(error))
    else:
        raise AssertionError('invalid nested Resource exported')
    assert artifact.read_bytes()==prior_artifact and manifest.read_bytes()==prior_receipt
finally:
    source.write_text(original)
    artifact.write_bytes(before);manifest.write_bytes(receipt)
invoke('--check')
for relative, message in [('scripts/content.odin','Stale generated bindings'), ('shared/content/content.odin','Compiled extractor differs')]:
    code=project/relative
    original_code=code.read_text()
    try:
        code.write_text(original_code+'\n// Deliberately stale build provenance test.\n')
        try:
            invoke('--project',str(project))
        except SystemExit as error:
            assert message in str(error),str(error)
            (out/(code.name+'.stale.log')).write_text(str(error))
        else:
            raise AssertionError('stale compiled authoring code accepted')
        assert artifact.read_bytes()==before and manifest.read_bytes()==receipt
    finally:
        code.write_text(original_code)
invoke('--check')
(out/'result.json').write_text(json.dumps({'pass':True,'nested_edit':True,'stale_rejected':True,'invalid_atomic':True,'restored':True,'stale_bindings_rejected':True,'stale_binary_rejected':True},indent=2)+'\n')
print('REPLAY_AUTHORING_ARTIFACT_OK')
