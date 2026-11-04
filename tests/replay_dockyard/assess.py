#!/usr/bin/env python3
"""Assess saved native Dockyard evidence without rerunning or rewriting it."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/box3d_samples'))
from run import final_view


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assess(case):
    if not __debug__:
        raise RuntimeError("assessment requires assertions enabled; omit Python -O")
    path = case / 'report.json'
    original_sha = sha(path)
    raw = json.loads(path.read_text())
    # The historical sample assumed every local row was nonzero. Dockyard stops
    # driving after delivery. Actual committed per-seat counters prove movement.
    if raw['result'] != 'PASS':
        assert raw['error'] == "RuntimeError('Replay authority did not observe nonzero remote controls')"
    assert raw['project_fence'] is True and raw['cleanup_errors'] == []
    assert sha(Path(raw['build_record'])) == raw['build_sha256']
    assert sha(Path(raw['controller_source'])) == raw['controller_sha256']
    assert sha(Path(raw['argv'][0])) == raw['godot_sha256']
    build = json.loads(Path(raw['build_record']).read_text())
    assert build['result'] == 'PASS' and build['source_fence_unchanged'] and build['native_fence_unchanged']
    assert raw['framework'] == 'replay'
    target = raw['target']
    games, tails, inputs = {}, {}, {}
    for actor in raw['actors']:
        role = actor['role']
        assert actor['actual_exit'] == 0 and actor['intake_drained'] and not actor['intake_error']
        assert sha(Path(actor['log'])) == actor['log_sha256']
        rows = actor['events']
        actual_rows = []
        for line in Path(actor['log']).read_bytes().splitlines():
            text = line.decode('utf-8', errors='replace').strip()
            if text.startswith('SAMPLE_') and ' ' in text:
                tag, payload = text.split(' ', 1)
                value = json.loads(payload)
                assert isinstance(value, dict) and value.get('event', tag) == tag
                actual_rows.append(dict(value, event=tag))
        assert actual_rows == rows, 'derived events differ from saved producer log'
        def one(kind):
            selected = [r for r in rows if r['event'] == kind]
            assert len(selected) == 1, (role, kind)
            return selected[0]
        ready, result = one('SAMPLE_READY'), one('SAMPLE_RESULT')
        assert ready['native_images'] == 1 and result['ok'] and result['errors'] == []
        assert result['target'] == target == result['confirmed'] == result['final_tick']
        clean = result['cleanup']
        assert all(clean[k] == 0 for k in ['native', 'wrapper', 'meter', 'owners'])
        assert clean['observed'] and clean['owners_before'] == clean['owners_after']
        data = one('SAMPLE_INPUTS')
        assert all(type(n) is int and n > 0 for n in data['nonzero_by_seat'])
        assert len(data['nonzero_by_seat']) == 2 and data['coverage_complete']
        game = one('SAMPLE_GAME')
        assert game['tick'] == target and game['score'] == 1
        assert game['delivered'] == [True, False, False] and game['inside'][0]
        assert game['dwell'][0] == 120 and game['eligible_delivery_cues'] == 1
        x, y, z = game['cargo_positions'][0]
        assert 4.5 < x < 7.5 and 1.1 < y < 1.4 and -.05 < z < 2.05
        tail = one('SAMPLE_TAIL')
        assert tail['tick'] == target and tail['signature_match'] is True
        assert tail['stage'] == ('final_accepted' if role == 'host' else 'close_accepted')
        games[role], inputs[role], tails[role] = game, data, tail
    assert set(games) == {'host', 'client'}
    host, hp, href = final_view(case / 'host', target)
    client, cp, cref = final_view(case / 'client', target)
    assert host['epoch'] == client['epoch'] == tails['host']['epoch'] == tails['client']['epoch']
    assert all(hp[p] == cp[p] for p in hp) and set(hp) == {'Solver', 'Game', 'Side', 'Observations', 'Occurrences'}
    assert games['host']['game_sha256'] == games['client']['game_sha256'] == hashlib.sha256(hp['Game']).hexdigest()
    assert sha(path) == original_sha
    return dict(result='DOCKYARD_PROTOTYPE_ACCEPTANCE_PASS', target=target,
        original_result=raw['result'], original_error=raw.get('error'),
        original_report=dict(path=str(path), sha256=original_sha), original_bytes_unchanged=True, assessor_sha256=sha(Path(__file__).resolve()),
        correction='Direct committed nonzero_by_seat proof replaces nonzero-total > all-local-row-count inference; stopping after delivery is allowed.',
        game=games, actual_terminal=tails, actual_inputs=inputs,
        host_complete=href, client_complete=cref, all_five_byte_equal=True,
        human_playtest='NOT_OBSERVED', scope='Saved native first-cargo co-op prototype, actual two-seat input/score/confirmed cue/ACK/typed cleanup; no final game or browser qualification')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    try:
        report = assess(args.case.resolve(strict=True))
    except Exception as exc:
        report = dict(result='FAIL', error=repr(exc))
    (args.out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(result=report['result'], report=str(args.out / 'report.json'), error=report.get('error'))))
    return 0 if report['result'] == 'DOCKYARD_PROTOTYPE_ACCEPTANCE_PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
