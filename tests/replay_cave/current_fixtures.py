"""Stage immutable current-contract checkpoints for isolated game tests."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("fixtures") / "current/manifest.json"
CASES = {row["id"]: row for row in json.loads(MANIFEST.read_text())}


def stage(case_id: str, destination: Path) -> dict:
    row = CASES[case_id]
    data = (ROOT / row["path"]).read_bytes()
    if hashlib.sha256(data).hexdigest() != row["sha256"]:
        raise ValueError("Fixture changed: " + case_id)
    destination = Path(destination)
    metadata = Path(str(destination) + ".json")
    if destination.exists() or metadata.exists():
        raise FileExistsError(destination)
    with destination.open("xb") as output:
        output.write(data)
    try:
        with metadata.open("x") as output:
            # Strings preserve all 64 digest bits through Godot's JSON reader.
            json.dump({"tick": row["tick"], "hash": row["frame_hash"]}, output)
            output.write("\n")
    except BaseException:
        destination.unlink()
        raise
    return dict(row)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", choices=CASES)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(json.dumps(stage(args.case, args.destination)))
