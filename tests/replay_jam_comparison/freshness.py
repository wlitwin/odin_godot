"""Describe observed world-progress gaps and fact/snapshot stages; no acceptance gate."""
from pathlib import Path
import argparse
import json
import math


def describe(path):
    data = json.loads(path.read_text())
    trace = data['trace']
    samples = [s for s in trace if s.get('ready', True)]
    assert samples and all(b['us'] >= a['us'] for a, b in zip(samples, samples[1:]))
    boundaries = [0] + [i for i in range(1, len(samples)) if samples[i]['tick'] > samples[i-1]['tick']]
    spans = [(a, b) for a, b in zip(boundaries, boundaries[1:])]
    if boundaries[-1] != len(samples)-1:
        spans.append((boundaries[-1], len(samples)-1))
    gaps = []
    for a, b in spans:
        first, final = samples[a], samples[b]
        before = samples[b-1] if b > a else first
        item = {'duration_ms': (final['us']-first['us'])/1000,
                'start_us': first['us'], 'end_us': final['us'],
                'world_before': first['tick'], 'world_after': final['tick'],
                'facts_start': first['tick']+first.get('facts_ahead', 0),
                'facts_before_advance': before['tick']+before.get('facts_ahead', 0),
                'facts_after': final['tick']+final.get('facts_ahead', 0)}
        for key in ('snapshot_latest', 'snapshot_pending', 'snapshot_complete',
                    'snapshot_part_rx', 'snapshot_part_expired', 'baseline_misses',
                    'fact_repair_requests', 'fact_repairs', 'fact_repair_oversize'):
            if key in first:
                item[key] = {'start': first[key], 'before_advance': before[key], 'end': final[key]}
        gaps.append(item)
    durations = sorted(g['duration_ms'] for g in gaps)
    result = {'source': str(path), 'implementation': data['implementation'], 'role': data['role'],
              'condition': data['condition'], 'samples': len(samples),
              'progress_gap_p95_ms': durations[max(0, math.ceil(len(durations)*.95)-1)],
              'max_progress_gap_ms': max(durations),
              'gaps_over_500_ms': sum(x > 500 for x in durations),
              'resyncs': samples[-1]['resyncs']-samples[0]['resyncs'],
              'prediction_stalls': samples[-1].get('stalls', 0)-samples[0].get('stalls', 0),
              'largest_gaps': sorted(gaps, key=lambda g:g['duration_ms'], reverse=True)[:5]}
    for key in ('fact_repair_requests', 'fact_repairs', 'fact_repair_oversize'):
        if key in samples[0]:
            result[key] = samples[-1][key]-samples[0][key]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('cohort', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    paths = sorted(args.cohort.glob('*/pair-*/*/success-*.json'))
    assert paths, 'no completed runtime receipts'
    report = {'scope': 'Diagnostic progress intervals, not action latency or an acceptance verdict. '
                       'A fact jump at the end of a gap does not mean facts advanced throughout it.',
              'runs': [describe(p) for p in paths]}
    output = json.dumps(report, indent=2)+'\n'
    if args.output:
        args.output.write_text(output)
    else:
        print(output, end='')


if __name__ == '__main__':
    main()
