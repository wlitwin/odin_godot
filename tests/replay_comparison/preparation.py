"""Select fixture implementations without changing their workload overlays.

Comparative benchmarks prepare both games. Browser stress uses the same Replay
workload without requiring the optional companion Kit game or its assets.
"""
import os


def implementations():
    selected = os.environ.get('REPLAY_COMPARISON_IMPLEMENTATIONS', 'kit,replay')
    if selected not in ('kit,replay', 'replay'):
        raise ValueError('Unknown comparison implementations: ' + selected)
    return tuple(selected.split(','))
