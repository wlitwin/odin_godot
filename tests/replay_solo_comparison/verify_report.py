"""Ensure acceptance cannot be obtained by omitting or altering key evidence."""
from copy import deepcopy
from pathlib import Path
import json
import sys
from report import check

out = Path(sys.argv[1])
label = sys.argv[2] if len(sys.argv) > 2 else "run"
cases = []
for impl in ('kit', 'replay'):
    folder = out / impl / label
    original = json.loads((folder / 'result.json').read_text())
    shutdown = json.loads((folder / 'shutdown.json').read_text())
    log = (folder / 'game.log').read_text()
    check(original, shutdown, log)
    cases.append(impl + ': original accepted')

    def reject(name, change):
        data, end, output = deepcopy(original), deepcopy(shutdown), log
        output = change(data, end, output)
        try:
            check(data, end, output)
        except (AssertionError, StopIteration):
            cases.append(impl + ': ' + name + ' rejected')
        else:
            raise AssertionError(name + ' was accepted')

    def field(key, value, predicate=lambda r: True):
        def mutate(data, end, output):
            next(r for r in data['trace'] if predicate(r))[key] = value
            return output
        return mutate

    reject('wipe', field('hp', 0))
    reject('unexpected weapon', field('mag', 8))
    reject('census mismatch', field('living', 99))
    reject('missing wave', lambda d, e, o: (d.update(trace=[r for r in d['trace'] if r['wave'] != 2]), o)[1])
    reject('short rest', field('rest_until', 1, lambda r: r['wave'] == 1 and r['pending'] == r['alive'] == 0 and r['rest_until'] > 0))
    reject('missing directed spawn', field('spawned', 12, lambda r: r['stage'] == 2))
    reject('missing reward', field('cores', 0, lambda r: r['stage'] == 2))
    reject('missing barrel admission', field('props', 1, lambda r: r['phase'] == 'barrels'))
    reject('missing blast', lambda d, e, o: (d['trace'][-1].update(booms=1), o)[1])
    if original.get('finale_mode')=='navigate':
        reject('changed cover', lambda d,e,o:(d['covers'][0].__setitem__(0,d['covers'][0][0]+1),o)[1])
        reject('changed barrel offset',lambda d,e,o:(d['barrel_receipt']['props'][0].__setitem__(0,d['barrel_receipt']['props'][0][0]+40),o)[1])
        reject('unbounded planner',lambda d,e,o:(d['navigation'].append({'found':True,'nodes':999,'path':[]}),o)[1])
        reject('teleport',lambda d,e,o:(d['trace'][5].update(position=[-1000,-1000]),o)[1])
        if any(p['path'] for p in original['navigation']):
            reject('path through cover',lambda d,e,o:(next(p for p in d['navigation'] if p['path'])['path'].__setitem__(0,[d['covers'][0][0]+5,d['covers'][0][1]+5]),o)[1])
        if original['forced_obstruction']:
            reject('blocked damage',lambda d,e,o:(d['blocked_proof']['health_after'].__setitem__(0,0),o)[1])
            reject('missing blocked shots',lambda d,e,o:(d['blocked_proof'].update(shots=0),o)[1])
            reject('short blocked interval',lambda d,e,o:(d['blocked_proof'].update(ms=0),o)[1])
    reject('resource leak', lambda d, e, o: o + '\nWARNING: resources still in use at exit\n')
    reject('engine error', lambda d, e, o: o + '\nERROR: injected\n')
(out / (label + "-report-verification.json")).write_text(json.dumps(cases, indent=2) + '\n')
print('SOLO_REPORT_VERIFIED', len(cases))
