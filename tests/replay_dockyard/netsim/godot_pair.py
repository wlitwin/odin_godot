#!/usr/bin/env python3
"""Run a scripted native Dockyard host + client over real ENet with simulated
network conditions, then summarize both sides' runner statistics.

Each process delays what it receives (DOCKYARD_LATENCY), so the round trip is
twice --latency. Both robots are driven by Dockyard's own carry controller.

  python3 godot_pair.py --project /abs/prepared/project --latency 50 --jitter 5 --loss 100 --ticks 3600
"""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def rows(text, tag):
    out = []
    for line in text.splitlines():
        if line.startswith(tag + ' '):
            try:
                out.append(json.loads(line[len(tag) + 1:]))
            except json.JSONDecodeError:
                pass
    return out


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--project', type=Path, required=True)
    p.add_argument('--godot', default=os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot'))
    p.add_argument('--latency', type=int, default=0)
    p.add_argument('--jitter', type=int, default=0)
    p.add_argument('--loss', type=int, default=0)
    p.add_argument('--input-delay', type=int, default=0)
    p.add_argument('--ticks', type=int, default=3600)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    project = a.project.resolve(strict=True)
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    port = free_port()
    procs = {}
    for role in ['host', 'client']:
        folder = out / role
        folder.mkdir()
        env = os.environ.copy()
        env.update(BOX3D_SAMPLE_ROLE=role, BOX3D_SAMPLE_SCRIPTED='1', BOX3D_SAMPLE_TICKS=str(a.ticks),
                   BOX3D_SAMPLE_PORT=str(port), DOCKYARD_HOST='127.0.0.1', BOX3D_SAMPLE_OUTPUT=str(folder),
                   ODIN_SCRIPTS_DLL=str(project / 'bin/libodinscripts.dylib'),
                   DOCKYARD_LATENCY=str(a.latency), DOCKYARD_JITTER=str(a.jitter), DOCKYARD_LOSS=str(a.loss),
                   DOCKYARD_INPUT_DELAY=str(a.input_delay))
        log = (folder / 'stdout.log').open('wb')
        procs[role] = (subprocess.Popen([a.godot, '--headless', '--max-fps', '60', '--path', str(project)],
                                        env=env, stdout=log, stderr=subprocess.STDOUT), log, folder)
        time.sleep(1.0 if role == 'host' else 0)
    deadline = time.monotonic() + a.ticks / 60 * 3 + 120
    for role, (proc, log, _) in procs.items():
        try:
            proc.wait(timeout=max(1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            proc.kill()
        log.close()
    summary = dict(latency_ms=a.latency, rtt_ms=2 * a.latency, jitter_ms=a.jitter, loss=a.loss,
                   input_delay=a.input_delay, ticks=a.ticks)
    finals = {}
    for role, (proc, _, folder) in procs.items():
        text = (folder / 'stdout.log').read_text(errors='replace')
        result = rows(text, 'SAMPLE_RESULT')
        network = rows(text, 'SAMPLE_NETWORK')
        final = rows(text, 'SAMPLE_FINAL')
        s = dict(exit=proc.returncode, ok=bool(result and result[-1].get('ok')),
                 errors=(result[-1].get('errors') if result else 'no SAMPLE_RESULT'))
        if network:
            n = network[-1]
            st = n['stats']
            s.update(max_prediction_ahead=n.get('max_prediction_ahead'), controls_consumed=n.get('controls_consumed'),
                     held_inputs=st['held_inputs'], corrections=st['corrections'], replayed_ticks=st['replayed_ticks'],
                     reused_ticks=st['reused_correction_ticks'], stalls=st['stalls'], resyncs=st['resyncs'],
                     tx_kbps=round(st['tx_bytes'] * 8 / 1000 / (a.ticks / 60), 1),
                     rx_kbps=round(st['rx_bytes'] * 8 / 1000 / (a.ticks / 60), 1))
        if final:
            finals[role] = final[-1]
        summary[role] = s
    if len(finals) == 2:
        h, c = finals['host'], finals['client']
        # Both sides stop at the same target tick; their complete signatures must agree.
        summary['final_tick'] = [h.get('tick'), c.get('tick')]
        summary['final_equal'] = h.get('tick') == c.get('tick') and h.get('complete') == c.get('complete')
    print(json.dumps(summary, indent=1))
    (out / 'summary.json').write_text(json.dumps(dict(summary=summary, finals=finals), indent=1))
    return 0 if all(summary[r]['ok'] for r in ('host', 'client')) and summary.get('final_equal') else 1


if __name__ == '__main__':
    sys.exit(main())
