#!/usr/bin/env python3
"""Run the Dockyard netsim harness over a condition matrix and print a table.

  python3 matrix.py /abs/netsim-binary-dir out.jsonl [extra key=value ...]
"""
import json, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

CONDITIONS = [
    dict(label='lan', rtt=0),
    dict(label='rtt50', rtt=50, jitter=5, loss=50),
    dict(label='rtt100', rtt=100, jitter=10, loss=100),
    dict(label='rtt150', rtt=150, jitter=15, loss=100),
    dict(label='rtt200', rtt=200, jitter=20, loss=100),
    dict(label='rtt100-10mbit', rtt=100, jitter=10, loss=100, kbps=10000),
    dict(label='rtt100-5mbit', rtt=100, jitter=10, loss=100, kbps=5000),
]
COLUMNS = ['label', 'host_held_pct', 'client_stalls', 'frozen_frame_pct', 'client_resyncs', 'depth_p95',
           'local_err_p95_m', 'local_err_max_m', 'remote_err_p95_m', 'big_snaps_per_min', 'host_big_snaps_per_min',
           'client_cpu_p95_ms', 'client_cpu_max_ms', 'host_tx_kbps', 'unequal_checks', 'client_phase']


def run(binary_dir, condition, extra):
    argv = [f'{binary_dir}/netsim'] + [f'{k}={v}' for k, v in condition.items()] + extra
    out = subprocess.run(argv, capture_output=True, text=True, timeout=1800, cwd=binary_dir)
    line = [l for l in out.stdout.splitlines() if l.startswith('{')]
    if not line:
        return dict(label=condition['label'], error=' '.join((out.stderr or out.stdout).split())[-300:])
    return json.loads(line[-1])


def main():
    binary_dir, output = sys.argv[1], sys.argv[2]
    extra = sys.argv[3:]
    with ThreadPoolExecutor(4) as pool:
        rows = list(pool.map(lambda c: run(binary_dir, c, extra), CONDITIONS))
    with open(output, 'a') as stream:
        for row in rows:
            stream.write(json.dumps(row) + '\n')
    print(' | '.join(COLUMNS))
    for row in rows:
        print(' | '.join(str(row.get(c, row.get('error', '?'))) for c in COLUMNS))


if __name__ == '__main__':
    main()
