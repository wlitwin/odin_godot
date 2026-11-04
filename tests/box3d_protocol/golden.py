#!/usr/bin/env python3
"""Independent LE/SHA256 specification vectors, not an Odin struct decoder."""
import hashlib
import json
from pathlib import Path
import struct
import sys


def sha(data):
    return hashlib.sha256(data).digest()


def signature(parts):
    descriptors = (b"build:arm64:test", b"assets:test", b"solver:v3", b"game:test", b"observations:test", b"inputs:test")
    header = b"OGB3SIG1" + struct.pack("<II", 1, 0)
    identity = struct.pack("<IIIIQ", 3, 1, 1, 1, 1) + b"".join(map(sha, descriptors))
    body = header + identity + struct.pack("<QQ", 7, 42)
    body += b"".join(struct.pack("<Q", len(p)) + sha(p) for p in parts)
    assert len(body) == 448
    return body + sha(body)


def vectors():
    expected = [b"full solver with pending end", b"rng counters mappings", b"side fields", b"completed sensor events", b"occurrences with stable keys"]
    actual = expected.copy()
    actual[1] = b"different game"
    accepted, predicted = b"accepted/input/window", b"held/input/window"
    left, right = signature(expected), signature(actual)
    size = 1040 + 32 + sum(map(len, expected + actual)) + len(accepted) + len(predicted)
    header = b"OGB3TRC1" + struct.pack("<IIQQQQIIQQQ", 1, 0, 35, 42, 22, 77, 8, 0, len(accepted), len(predicted), size)
    body = header + left + right + b"".join(expected + actual) + accepted + predicted
    assert len(header) == 80 and len(body) + 32 == size
    descriptor = b"OGB3DESC1" + struct.pack("<Q", 12) + b"game-profile" + struct.pack("<I", 2)
    for tag, data in [(b"occurrences", b"event-schema"), (b"state", b"state-schema")]:
        descriptor += struct.pack("<I", len(tag)) + tag + struct.pack("<Q", len(data)) + data
    return {"signature.bin": left, "trace.bin": body + sha(body), "descriptor.bin": sha(descriptor)}


if __name__ == "__main__":
    results = {}
    for folder in map(Path, sys.argv[1:]):
        for name, expected in vectors().items():
            actual = (folder / name).read_bytes()
            assert actual == expected, (folder, name, len(actual), len(expected))
            results[str(folder / name)] = {"bytes": len(actual), "sha256": sha(actual).hex()}
    assert results, "pass native or WASM corpus output folders"
    print(json.dumps({"status": "BOX3D_PROTOCOL_GOLDEN_OK", "artifacts": results}, indent=2))
