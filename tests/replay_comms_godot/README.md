# Godot communications adapter regression

Run `nix develop --command bash tests/replay_comms_godot/run.sh`.

The real Godot adapter pumps a reliable in-memory connection and recovery-router
application lane. The fixture supplies valid admitted client metadata, then changes
the gameplay phase from Running to Resyncing and back. It verifies that an already
queued request, incoming host line, ordered sender echo and subsequent request all
survive the resync. Fenced, rejected and unadmitted clients remain disabled. The runner also checks
the fixture package for WASM compilation.

This isolates the adapter from gameplay scheduling: it supplies phase metadata
instead of manufacturing a full gameplay-history overflow. Before the fix,
Resyncing disabled Comms, rejected an incoming delivery and retired the queued
request with Scope_Changed. The source packet protocol, scope and generation are
unchanged by the fix. Session replacement/fencing retains its separate semantics.
