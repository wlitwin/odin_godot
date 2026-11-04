`motion` is a Native CTest. It constructs each of the eight public joint kinds
separately within the unchanged one-joint profile, steps the actual constraint,
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

All 12 registered tests passed in the current macOS arm64 Debug, Release and
ASan/UBSan matrices, including the default Distance tick-0/tick-1 regression.
The original inverted-range failure remains retained. Format-1 primitive and
format-2 authored tests remain registered independently. See [report.json](../report.json)
for the exact artifacts, source fences and validation scope.
