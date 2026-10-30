#!/usr/bin/env python3
"""Summarize driver-observed timing separately from Room's local interruption timer."""
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
results = []
for path in sorted(root.glob('*/events.json')):
    mode = path.parent.name
    events = json.loads(path.read_text())
    def receipt(prefix):
        return next((e for e in events if e.get('line', '').startswith(prefix)), None)
    final = receipt('RCB_GUEST_OK')
    if not final:
        continue
    if mode in ('crash', 'return', 'successor_loss'):
        target = 2 if mode == 'successor_loss' else 1
        trigger = next(e for e in events if e['event'] == 'kill' and e['member'] == target)
    elif mode == 'partition':
        trigger = receipt('RCB_CONTROL_PARTITIONED')
    else:
        trigger = receipt('RCB_DURABLE')
    first = receipt('RCB_GUEST_STAGE') or final
    values = {k: int(v) for k, v in re.findall(r'(\w+)=(\d+)', final['line'])}
    results.append(dict(mode=mode, trigger_to_first_continued_action_ms=first['ms']-trigger['ms'],
                        trigger_to_final_action_ms=final['ms']-trigger['ms'],
                        room_protocol_interruption_ms=values['interruption_ms'],
                        epoch=values['epoch'], migrations=values['migrations'],
                        checkpoint=values['checkpoint'], known_lost_ticks=values['lost']))
output = json.dumps(results, indent=2) + '\n'
(root/'summary.json').write_text(output)
print(output, end='')
