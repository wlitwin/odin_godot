# Stormcaller feature gate

`REPLAY_STORM_OUT=/absolute/fresh/output nix develop --command bash tests/replay_stormcaller/run.sh`
runs rule/correction/checkpoint/source-49 tests, native/WASM continuation equality,
an isolated Godot build, composed preview/workbench checks and three actual peers.
The peer scenario uses 120 ms latency: one player absorbs the pulse, the other
leaves its radius, then the enemy is defeated and all public hashes must agree.

The standalone WASM fixture uses `-o:speed` and links Emscripten math. A 256 MiB
non-reclaiming test arena accommodates construction of two network owners, codec
metadata and checkpoint temporaries; this is not a proposed game allocation.
Native tracking verifies final live allocations return to zero. An unoptimized
standalone build exceeded the engine's local-variable limit in diagnostic code;
the optimized, linked artifact is the executed acceptance target.

The source-49 checkpoint is immutable and predates the live schema change. The
ordinary Scrapyard suite additionally checks older archives and the save CLI gate
checks preservation of every prior byte after excluding the explicitly added zero
pulse fields and authority stamp. No existing save is silently overwritten.
