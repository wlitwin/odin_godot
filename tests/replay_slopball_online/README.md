# Slopball Party and browser acceptance

Run `run.sh` inside `nix develop`; set `REPLAY_SLOPBALL_ONLINE_OUT` to a fresh
output directory. It prepares the native UI/profile gate, typed service and speed
Web export, runs planned/crash browser migration, independently decodes published
checkpoints, then runs native Party UI. Build and execute scripts can run separately.
`RSL_ONLINE_MODES=planned` or `crash` selects one browser scenario.

Each browser scenario creates a host, two players and an observer, rejects a bad
invite, starts play and obtains a complete approved moving-ball backup. It publishes,
hands off or SIGKILLs the host, checks exact checkpoint restoration and the first
eligible momentum seed, then requires new kicks and a goal by the successor.
The observer remains seat zero with its solver frozen and no succession archive.
Observer rejoin and a fresh old-host browser recover credentials, names and seats.
Old/new named chat, common full-world digests, publication in both epochs, actual
RTC bytes, viewport resize, control rectangles and graphics traces are checked.
Party publication must create no browser-local game-save slot.

The test-only GDScript bridge observes the real game and invokes its UI actions;
it does not replace the model or inject recovered worlds. `native.py` adapts the
existing UI fixture to Party invitation/rejoin and explicitly leaves each member.
It retains gameplay, score, input-capture, observer chat and identity checks.

`convert_views.gd SOURCE_PROJECT OUTPUT_PROJECT` reproduces the authored immutable
mesh conversion from the prior Polygon2D scenes, checking serialized geometry
readback. It preserves hierarchy, points, tint and physics; it is a source utility,
not startup behavior. Existing output scene directories must exist.

Raw SQLite databases, invite files and browser profiles contain credentials.
Keep them private; publish source hashes, redacted events, logs and screenshots.
Local RTC acceptance does not establish Internet reachability, solver rollback,
full-party shutdown recovery or cross-device rendering parity.
