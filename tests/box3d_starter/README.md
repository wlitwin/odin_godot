# Offline starter acceptance

Run `nix develop --command bash tests/run_all.sh box3dstarter`. An explicit
`BOX3D_NATIVE_LIBRARY` selects an existing matching backend; otherwise the
wrapper builds the default backend in `.box3d-cache`. `BOX3D_STARTER_SDK` can
select an already-built Nix SDK output containing `addons/`.

For a rendered viewport capture and ordinary macOS export:

```sh
nix develop --command bash tests/box3d_starter/run.sh --visual --export
```

The runner copies the packaged starter and SDK into a fresh project. A separate
test-only Odin probe and GDScript autoload check falling/contact, input impulses,
repeated reset, tree exit/re-entry, script removal outside the tree, node deletion,
tracked allocation cleanup, transformed/plain-Node parents, nested bodies with
reversed key order, nested World exclusion, preserved Mesh offsets/scales,
World-frame movement, timing mismatch, changed ancestry, invalid authoring,
stale onready pointers, and synchronous script removal during pose publication.
The shipped game contains no allocation/census/qualification instrumentation.

Export uses the supplied preset through Godot's normal exporter. The exported
app repeats the same checks. Both export and exported execution remove explicit
compiler/backend environment selections and use a minimal system PATH: export
must recover its remembered tools, and the game must need no compiler.

Reports, logs and the optional `starter.png` are retained in the printed evidence
directory. Any script/runtime error or leaked-resource diagnostic fails the gate.
The export branch currently qualifies macOS arm64 only; this does not claim
Windows, Linux or browser runtime evidence.
