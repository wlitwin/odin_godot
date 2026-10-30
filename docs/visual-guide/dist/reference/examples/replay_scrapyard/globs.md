# Slime, sparkjar and spit discs

Ability lobs and enemy spit use the original ten-point filled discs at depth 6.
Lobs have radius 7 and use their payload status RGB when its tint is visible;
otherwise they use the original bright-green fallback. Spit has radius 5 and its
original green color. Both pulse uniformly as `1 + sin(phase) * 0.18`, advancing
phase at 14 radians per second of local render time.

The original `Glob_View` follows a straight constant-velocity path from its local
announce time. It has no visual arc or trail; older port-ledger wording was
incorrect on that point. Replay places each disc at the displayed simulation
position. Local lobs use prediction, remote lobs and enemy spit use observed
state. It does not invent a separate path or delay removal after landing, impact,
expiry or correction. This retains Replay's presentation timing difference from
the original; paired feel/timing review remains required.

The bounded view pools have one spit disc per shot slot and separate predicted
and observed lob banks. That avoids sharing a pulse with unrelated ballistic
views and avoids dropping remote lobs when predicted and observed pool occupancy
differ. A pulse resets when hidden, reused, rewound or replaced under a new epoch.
These are local view values and add no simulation or checkpoint fields. Current
game-content compatibility is tracked in [cast paths](cast_paths.md).

```sh
nix develop --command bash examples/replay_scrapyard/glob_view_run.sh
REPLAY_PREBUILT=1 RSY_HEADED_HOST=1 RSY_AUDIO_DRIVER=Dummy \
  RSY_GLOB_CAPTURE=/absolute/existing/output/directory \
  GODOT=/path/to/Godot bash examples/replay_scrapyard/glob_view_run.sh
```

The native gate selects slime/sparkjar before starting the real workbench game,
casts both through the ordinary action path, then spawns a real spitter. It checks
geometry, payload color, pulse, straight movement and removal. Browser acceptance
records these transient views every frame at the owner and both remote peers;
its commands choose the loadout during staging, submit Cast actions and create
one spitter through the existing development action. Migration acceptance checks
that the promoted host draws the restored in-flight lob.

[Area effects](areas.md) now cover nova/buff/reaction/zone presentation.
Remaining cone/spread presentation details, broader browser/device
coverage, audio listening and paired playtests remain requirements. See the
[port ledger](roadmap.md) and [evidence](../../docs/replay/results/scrapyard-globs-2026-09-08/README.md).
