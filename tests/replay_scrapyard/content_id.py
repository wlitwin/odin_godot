"""Use the game's authored identity for generic room/checkpoint test services."""
from pathlib import Path
import re
import sys


def content_id(project):
    text = (project / 'shared/game/game.odin').read_text()
    match = re.search(r'^CONTENT\s*::\s*u64\((0x[0-9a-fA-F]+)\)\s*$', text, re.M)
    if match is None:
        raise ValueError('Missing literal game CONTENT declaration: ' + str(project))
    value = int(match[1], 16)
    if value <= 0 or value >= 1 << 64:
        raise ValueError('Invalid game CONTENT declaration: ' + str(project))
    return f'0x{value:016x}'


if __name__ == '__main__':
    print(content_id(Path(sys.argv[1])))
