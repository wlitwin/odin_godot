#!/usr/bin/env python3
"""Actual SDK-owned Replay H128 receiver-discard regression in a Godot browser."""
import importlib.util
from pathlib import Path

file = Path(__file__).resolve().parents[1] / 'kit/run.py'
spec = importlib.util.spec_from_file_location('web_adapter_fixture', file)
shared = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shared)

if __name__ == '__main__':
    raise SystemExit(shared.main(source=Path(__file__).with_name('recovery_project'),
        marker='REPLAY_WINDOW_PASS', mode='window',
        scope='Actual browser/Core/Meter/Replay complete physics; public Memory receiver discard causes genuine H128 resync/Welcome. Not WebRTC loss or Internet certification.'))
