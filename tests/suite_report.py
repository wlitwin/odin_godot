#!/usr/bin/env python3
"""Write the suite's durable result after each completed check."""
import json
from pathlib import Path
import sys


def write(path, report):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.pending')
    temporary.write_text(json.dumps(report, indent=2) + '\n')
    temporary.replace(path)


def main():
    command, filename, *args = sys.argv[1:]
    path = Path(filename)
    if command == 'init':
        manifest, index, count, skip_web, selected = args
        rows = []
        for line in Path(manifest).read_text().splitlines():
            name, sentinel, script, skip, capability, included = line.split('\t')
            rows.append(dict(name=name, script=script, capability=capability,
                             selected=included == '1'))
        report = dict(schema_version=1, complete=False, success=False,
            selection=dict(manifest_count=len(rows), selected_count=int(selected),
                           omitted_count=len(rows) - int(selected),
                           shard_index=int(index), shard_count=int(count),
                           skip_web=skip_web == '1'),
            manifest=rows, results=[])
    else:
        report = json.loads(path.read_text())
        if command == 'result':
            name, status, exit_code, duration, log, reason, native = args
            report['results'].append(dict(name=name, status=status,
                exit_code=int(exit_code), duration_seconds=int(duration),
                log=log, reason=reason, native_checks_completed=native == '1'))
        elif command == 'finish':
            complete, exit_code = args
            report['complete'] = complete == '1'
            report['exit_code'] = int(exit_code)
        else:
            raise ValueError('unknown report operation: ' + command)
    statuses = ('PASS', 'FAIL', 'SKIP', 'TIMEOUT', 'ABORTED')
    report['counts'] = {status.lower(): sum(row['status'] == status for row in report['results'])
                        for status in statuses}
    report['success'] = (report['complete'] and report.get('exit_code') == 0 and
                         len(report['results']) == report['selection']['selected_count'] and
                         not any(report['counts'][key] for key in ('fail', 'timeout', 'aborted')))
    write(path, report)


if __name__ == '__main__':
    main()
