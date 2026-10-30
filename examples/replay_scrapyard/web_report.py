#!/usr/bin/env python3
"""Summarize retained browser receipts; all durations use the Node driver clock."""
import json
import re
import sys
from pathlib import Path


def summarize(root):
    result = {}
    for mode in ("planned", "crash"):
        folder = root / mode
        if not folder.exists():
            continue
        events = json.loads((folder / "events.json").read_text())
        trigger = next(e["ms"] for e in events if e["event"] == "trigger")
        recovered = {}
        for event in events:
            line = event.get("line", "")
            if not line.startswith("RSB_RECOVERED "):
                continue
            values = {key: int(value) for key, value in re.findall(r"(\w+)=(\d+)", line)}
            values["fault_to_continued_combat_ms"] = event["ms"] - trigger
            recovered[str(values.pop("member"))] = values
        hashes = json.loads((folder / "hashes.json").read_text())
        common = hashes["common"]
        assert len(common) >= 10, "insufficient shared world frames"
        for tick in common:
            assert len({peer[str(tick)] for peer in hashes["peers"]}) == 1, "world mismatch"
        assert set(recovered) == ({"1", "2", "3"} if mode == "planned" else {"2", "3"})
        result[mode] = {
            "start_to_fault_ms": trigger,
            "startup": json.loads((folder / "startup.json").read_text()),
            "recovered": recovered,
            "shared_world_samples": len(common),
            "first_tick": min(common),
            "last_tick": max(common),
        }
    assert result, "no completed migration scenarios"
    return result


if __name__ == "__main__":
    root = Path(sys.argv[1])
    report = summarize(root)
    (root / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
