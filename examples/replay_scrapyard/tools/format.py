"""Format Replay Scrapyard's handwritten Odin, or check it with --check."""

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def sources():
    for directory in ("scripts", "shared", "tools"):
        for path in sorted((ROOT / directory).rglob("*.odin")):
            if ".gen." in path.name or "revisions" in path.relative_to(ROOT).parts:
                continue
            yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    formatter = shutil.which("odinfmt")
    if formatter is None:
        parser.error("odinfmt is required; run this command inside nix develop")

    changed = []
    paths = list(sources())
    with tempfile.TemporaryDirectory(prefix="scrapyard-format-") as temporary:
        for path in paths:
            target = path
            if args.check:
                target = Path(temporary) / path.name
                shutil.copyfile(path, target)
            subprocess.run(
                [formatter, "-w", "-config:" + str(ROOT / "odinfmt.json"), str(target)],
                check=True,
            )
            if args.check and path.read_bytes() != target.read_bytes():
                changed.append(path.relative_to(ROOT))

    if changed:
        for path in changed:
            print("Needs formatting:", path)
        raise SystemExit(1)
    print(f"Scrapyard Odin {'checked' if args.check else 'formatted'}: {len(paths)} files")


if __name__ == "__main__":
    main()
