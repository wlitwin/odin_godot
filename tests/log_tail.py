"""Print bounded failure evidence from a retained test output directory."""
from pathlib import Path
import sys


def print_logs(root):
    remaining = 32768
    paths = sorted(root.rglob('*.log'), key=lambda p: p.stat().st_mtime, reverse=True)[:12]
    for path in paths:
        if remaining <= 0:
            break
        with path.open('rb') as stream:
            head = stream.read(4096).decode(errors='replace').splitlines()[:8]
            stream.seek(max(0, path.stat().st_size - 8192))
            tail = stream.read(8192).decode(errors='replace').splitlines()[-52:]
        excerpt = ('----- ' + str(path.relative_to(root)) + ' -----\n' + '\n'.join(head + tail) + '\n').encode()
        chunk = excerpt[:remaining]
        sys.stdout.buffer.write(chunk)
        remaining -= len(chunk)


if __name__ == '__main__':
    print_logs(Path(sys.argv[1]))
