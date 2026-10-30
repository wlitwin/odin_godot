"""Validate real-game receipts; a failed survival trajectory remains a failure."""
from pathlib import Path
import json
import re
import sys
from navigation_report import check as check_navigation


def check_waves(data):
    rows = data['trace']
    assert len(rows) >= 30 and rows[0]['phase'] == 'waves', 'trace coverage'
    first, last = rows[0], rows[-1]
    assert first['hp'] == 10 and first['cores'] == 0, 'fresh solo profile'
    assert all(r['floor'] == 1 and r['run'] == first['run'] and 0 < r['hp'] <= 10 for r in rows), 'survival/scope'
    assert all((r['mag'], r['jam'], r['iron']) == (255, 0, 0) for r in rows), 'weapon contract'
    assert all(a['ms'] <= b['ms'] and a['tick'] <= b['tick'] for a, b in zip(rows, rows[1:])), 'monotonic trace'
    assert all(r['alive'] == r['living'] for r in rows), 'director census'
    waves = []
    rests = []
    for wave, count in enumerate([4, 4, 5], 1):
        group = [r for r in rows if r['wave'] == wave and r['phase'] == 'waves']
        assert group and group[0]['pending'] + group[0]['alive'] == count, 'wave population'
        settled = [r for r in group if r['pending'] == 0 and r['alive'] == 0 and r['rest_until'] > 0]
        assert settled, 'missing wave clear'
        clear = settled[0]
        # The frame observer can be one simulation tick past the death edge.
        assert 298 <= clear['rest_until'] - clear['tick'] <= 300, 'full 300-tick rest'
        after = next((r for r in rows if r['wave'] > wave or r['done']), None)
        assert after and after['tick'] >= clear['rest_until'], 'rest skipped'
        waves.append({'wave': wave, 'count': count, 'began_ms': group[0]['ms'], 'cleared_ms': clear['ms'], 'hp': clear['hp'], 'shots': clear['shots'], 'kills': clear['kills']})
        rests.append({'wave': wave, 'observed_clear_tick': clear['tick'], 'until': clear['rest_until'], 'next_tick': after['tick']})
    clear = next(r for r in rows if r['stage'] == 2)
    assert clear['done'] == 1 and clear['wave'] == 3 and clear['spawned'] == 13 and clear['living'] == 0, 'floor clear'
    assert clear['cores'] == 1 and last['cores'] == 1, 'single clear reward'
    assert clear['ms'] <= 180000, 'wave deadline'
    commands = data['inputs']
    assert len(commands) >= 4 and all(len(c['command']) == 3 for c in commands), 'input coverage'
    return {'clear_ms': clear['ms'], 'clear_tick': clear['tick'], 'minimum_hp': min(r['hp'] for r in rows),
            'clear_hp': clear['hp'], 'shots_at_clear': clear['shots'], 'kills_at_clear': clear['kills'],
            'scrap_at_clear': clear['scrap'], 'waves': waves, 'rests': rests}


def check(data, shutdown, log):
    assert data['pass'] and data['phase'] == 'complete', data['reason']
    assert isinstance(shutdown['resources_remaining'], int), 'missing resource observation'
    # Global Resource_COUNT includes stable engine caches; exit leak reports gate acceptance.
    assert not re.search(r'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use|SOLO_COMPARE_FAIL', log), 'engine/runtime error'
    result = check_waves(data)
    rows = data['trace']; last = rows[-1]
    assert last['phase'] == 'complete', 'trace completion'
    finale = next(r for r in rows if r['phase'] == 'barrels')
    assert finale['props'] == 2 and last['props'] == 0 and last['booms'] - finale['booms'] >= 2, 'barrel finale'
    assert last['ms'] - finale['ms'] <= 25000, 'barrel deadline'
    navigation=check_navigation(data)
    return {**result, 'navigation':navigation,'waves_pass': True, 'finale_ms': last['ms'] - finale['ms'],
            'finale_blasts': last['booms'] - finale['booms'], 'resources_after_scene': shutdown['resources_remaining']}


def report(out, label="run"):
    results = {}
    for impl in ('kit', 'replay'):
        folder = out / impl / label
        data = {'trace': []}
        try:
            data = json.loads((folder / 'result.json').read_text())
            plan=json.loads((out/(label+'-run-plan.json')).read_text())
            if 'finale_mode' in plan:assert data['finale_mode']==plan['finale_mode'] and data['forced_obstruction']==plan['forced_obstruction'],'requested controller/obstruction'
            exits = json.loads((out / (label + '-exit-codes.json')).read_text())
            assert exits[impl] == 0, 'process exit: ' + str(exits[impl])
            results[impl] = {'pass': True, **check(data, json.loads((folder / 'shutdown.json').read_text()), (folder / 'game.log').read_text())}
        except (AssertionError, StopIteration, FileNotFoundError, KeyError) as error:
            results[impl] = {'pass': False, 'reason': data.get('reason', str(error)), 'failure_gate': str(error), 'last': data['trace'][-1] if data['trace'] else None}
            try:
                results[impl].update(check_waves(data), waves_pass=True)
            except (AssertionError, StopIteration):
                results[impl]['waves_pass'] = False
    result = {'pass': all(v['pass'] for v in results.values()), 'implementations': results}
    (out / (label + "-report.json")).write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    sys.exit(0 if report(Path(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else "run")['pass'] else 1)
