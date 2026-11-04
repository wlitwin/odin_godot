#!/usr/bin/env python3
"""Strict saved-evidence game assessment, separate from the shared pair controller."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('dockyard_sample_helpers', ROOT / 'tests/box3d_samples/run.py')
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)


def check(condition, message):
    if not condition:
        raise RuntimeError(message)


def parse_native(path):
    rows = []
    for line in path.read_text().splitlines():
        if line.startswith('SAMPLE_') and ' ' in line:
            tag, payload = line.split(' ', 1)
            value = json.loads(payload)
            check(isinstance(value, dict) and value.get('event', tag) == tag, 'raw producer event tag')
            rows.append(dict(value, event=tag))
    return rows


def one(rows, tag):
    found = [row for row in rows if row.get('event') == tag]
    check(len(found) == 1, 'one actual ' + tag + ' required')
    return found[0]


def game_evidence(rows, target, game_bytes, retry=False):
    game = one(rows, 'SAMPLE_GAME')
    check(game['tick'] == target and game['game_sha256'] == hashlib.sha256(game_bytes).hexdigest(), 'game bytes bound to producer result')
    if retry:
        check(game['round'] == 2 and game['layout'] == 1, 'actual host next-job action did not reach both players')
    else:
        check(game['round'] == 1 and game['phase'] == 'Results' and game['score'] == 3, 'complete round result required')
        check(game['delivered'] == [True]*3 and game['lost'] == [False]*3 and game['dwell'] == [120]*3, 'three actual settled/latched loads')
        check(game['eligible_delivery_cues'] == 3 and 1200 <= game['payout'] <= 1500 and 0 < game['round_ticks'] <= 9000, 'actual once-only cues, payout and deadline')
    inputs = one(rows, 'SAMPLE_INPUTS')
    check(len(inputs['nonzero_by_seat']) == 2 and all(type(x) is int and x > 0 for x in inputs['nonzero_by_seat']), 'actual authority inputs from both seats')
    return game


def native(case, retry=False):
    report_path = case / 'report.json'
    before = shared.sha(report_path)
    raw = json.loads(report_path.read_text())
    check(raw['result'] == 'PASS' and raw['project_fence'] and raw['cleanup_errors'] == [], 'successful frozen runtime controller required')
    games, parts, signatures = {}, {}, {}
    for actor in raw['actors']:
        role = actor['role']
        check(actor['actual_exit'] == 0 and actor['intake_drained'] and not actor['intake_error'], 'natural successful actor and drained intake')
        log = Path(actor['log'])
        check(shared.sha(log) == actor['log_sha256'], 'raw log hash')
        rows = parse_native(log)
        check(rows == actor['events'], 'derived events must match exact saved producer log')
        manifest, payloads, _ = shared.final_view(case / role, raw['target'])
        signature = case / role / manifest['signature_file']
        check(shared.sha(signature) == manifest['signature_sha256'], 'actual signature file hash')
        signatures[role] = signature.read_bytes()
        result = one(rows, 'SAMPLE_RESULT')
        check(result['ok'] and result['confirmed'] >= raw['target'] and result['final_tick'] == raw['target'] and not result['errors'], 'confirmed successful result')
        clean = result['cleanup']
        check(clean['observed'] and all(clean[key] == 0 for key in ['native','wrapper','meter','owners']) and clean['owners_before'] == clean['owners_after'], 'actual typed teardown and owner baseline')
        check(any(row.get('event') == 'SAMPLE_TAIL' and row.get('signature_match') is True and row.get('tick') == raw['target'] and row.get('stage') == ('final_accepted' if role == 'host' else 'close_accepted') for row in rows), 'actual terminal signature acknowledgement')
        games[role] = game_evidence(rows, raw['target'], payloads['Game'], retry)
        parts[role] = payloads
        if retry:
            check(any(row.get('event') == 'SAMPLE_RETRY_OBSERVED' and row.get('round') == 2 for row in rows), 'actual observed next round')
            if role == 'host':
                check(any(row.get('event') == 'SAMPLE_RETRY_REQUEST' and row.get('actual_button_pressed') is True for row in rows), 'actual next-job button signal')
    check(set(games) == {'host','client'} and all(parts['host'][key] == parts['client'][key] for key in shared.PARTS), 'all five parts byte equal')
    check(signatures['host'] == signatures['client'] and shared.sha(report_path) == before, 'matching signatures and unchanged original report')
    return dict(result='PASS', original_report=str(report_path), original_sha256=before, game=games, all_five_byte_equal=True,
                scope='Saved actual native game/ACK/cleanup evidence; no browser, throughput or human-playtest inference')


def web(case):
    raw = json.loads((case / 'report.json').read_text())
    binding = json.loads((case / 'export-binding.json').read_text())
    check(raw['result'] == 'PASS' and binding['actual_exit'] == 0 and binding['export_unchanged'], 'actual immutable browser pair pass')
    games = {}
    for role in ['host','client']:
        rows = []
        for line in (case / role / 'console.ndjson').read_text().splitlines():
            text = json.loads(line)['text']
            if text.startswith('SAMPLE_') and ' ' in text:
                tag, payload = text.split(' ',1)
                rows.append(dict(json.loads(payload), event=tag))
        for tag in ['SAMPLE_READY','SAMPLE_NETWORK','SAMPLE_RESULT','SAMPLE_WEB_FRAME','SAMPLE_INPUTS']:
            actual = dict(one(rows,tag));actual.pop('event')
            check(actual == raw[role][tag], 'raw browser rows must match saved actor evidence')
        games[role] = game_evidence(rows, raw['ticks'], (case / role / 'Game.bin').read_bytes())
    check(all((case/'host'/(name+'.bin')).read_bytes() == (case/'client'/(name+'.bin')).read_bytes() for name in shared.PARTS), 'actual browser five-part files')
    return dict(result='PASS', game=games, all_five_byte_equal=True, scope=raw['scope'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--web', action='store_true')
    parser.add_argument('--retry', action='store_true')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=False)
    try:
        report = web(args.case) if args.web else native(args.case,args.retry)
    except Exception as error:
        report = dict(result='FAIL', error=repr(error))
    (args.out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(result=report['result'],report=str(args.out/'report.json'),error=report.get('error'))))
    return 0 if report['result'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
