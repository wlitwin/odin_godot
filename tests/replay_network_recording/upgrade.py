from pathlib import Path
import gzip
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
out = Path(sys.argv[1]).resolve()
run = out / 'upgraded'
run.mkdir(exist_ok=False)
sources = out / 'sources'
sources.mkdir(exist_ok=False)
fixtures = root / 'tests/replay_network_recording/fixtures/authority-before-observation'
manifest = json.loads((fixtures / 'manifest.json').read_text())
files = ['host.rplrec.gz', 'client.rplrec.gz', 'browser.rplrec.gz']
assert set(manifest) == set(files), 'historical recording fixture inventory changed'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
results = []

for index, name in enumerate(files):
    fixture = fixtures / name
    fixture_before = sha(fixture)
    data = gzip.decompress(fixture.read_bytes())
    expected = manifest[name]
    assert len(data) == expected['bytes'], name
    assert hashlib.sha256(data).hexdigest() == expected['sha256'], name
    source = sources / name.removesuffix('.gz')
    source.write_bytes(data)
    before = sha(source)
    target = run / f'{index}.rplrec'

    rejected = subprocess.run(
        [str(out / 'verify_recording'), str(source), '--content48'],
        capture_output=True, text=True, timeout=30,
    )
    assert rejected.returncode == 2, rejected.stdout + rejected.stderr
    converted = subprocess.run(
        [str(out / 'upgrade_recording'), str(source), str(target)],
        capture_output=True, text=True, timeout=30,
    )
    (run / f'{index}-convert.log').write_text(converted.stdout + converted.stderr)
    assert converted.returncode == 0, converted.stdout + converted.stderr
    verified = subprocess.run(
        [str(out / 'verify_recording'), str(target), '--content48'],
        capture_output=True, text=True, timeout=30,
    )
    (run / f'{index}-verify.log').write_text(verified.stdout + verified.stderr)
    assert verified.returncode == 0, verified.stdout + verified.stderr

    after = sha(target)
    refused = subprocess.run(
        [str(out / 'upgrade_recording'), str(source), str(target)],
        capture_output=True, text=True, timeout=30,
    )
    assert refused.returncode == 1 and sha(target) == after
    assert sha(source) == before and sha(fixture) == fixture_before
    results.append({
        'source': str(fixture.relative_to(root)),
        'source_sha256': before,
        'converted_sha256': after,
        'verifier': verified.stdout.strip(),
        'source_preserved': True,
        'existing_destination_preserved': True,
    })
    print(verified.stdout.strip(), flush=True)

(run / 'result.json').write_text(json.dumps(results, indent=2) + '\n')
print('REPLAY_NETWORK_RECORDING_UPGRADE_OK')
