# Godot communications adapter regression

Run `nix develop --command bash tests/replay_comms_godot/run.sh`.

The fixture runs the Godot adapter over a reliable in-memory connection and a
recovery-router application lane. It supplies valid admitted-client metadata,
then changes gameplay phase from Running to Resyncing and back. The checks
require a queued request, incoming host line, ordered sender echo, and subsequent
request to survive the resync. Fenced, rejected, and unadmitted clients remain
disabled. The runner also compiles the fixture package for WASM.

This isolates the adapter from gameplay scheduling: it supplies phase metadata
instead of manufacturing a full gameplay-history overflow. Before the fix,
Resyncing disabled Comms, rejected an incoming delivery and retired the queued
request with Scope_Changed. The source packet protocol, scope and generation are
unchanged by the fix. Session replacement/fencing retains its separate semantics.
