`motion` is a Native CTest. It constructs each of the eight public joint kinds
separately within the selected capacity profile, steps the actual constraint,
compares full solver dumps after same/scratch restore and canonical format-3
decode/re-encode, then checks continuation after source/catalog release. Typed
settings, body references, frames, malformed DTOs, version mismatch, and staged
allocation-failure cleanup have explicit controls.

Query controls use actual worlds for complete capacity behavior, stable key ties,
filters/sensors, self-exclusion, capsule overlap/cast, and scratch-world parity.
The character controls use the pinned capsule mover/plane solver for wall sliding,
floor/slope classification, zero step and invalid inputs, and unchanged solver
state. They do not install a tick owner or mutate bodies. A full per-shape native
64-plane batch is conservatively Capacity because that public callback has no
overflow bit. No result is published from an incomplete plane collection.

The historical 12-test matrix passed in macOS arm64 Debug, Release and
ASan/UBSan matrices, including the default Distance tick-0/tick-1 regression.
The original inverted-range failure remains retained. Current primitive and authored constructors share format 3; tests require
identical identities/bytes and reject format-1/2 headers. See [report.json](../report.json)
for the exact artifacts, source fences and validation scope.
