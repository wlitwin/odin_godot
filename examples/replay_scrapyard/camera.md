<a id="borrowed-eyes"></a>

# Following a teammate while downed

A downed player's camera follows a living teammate and returns to their own
character, called a runner, on
revival or when nobody eligible remains. A small “Watching …” label identifies
the borrowed view; health, ammunition, controls and action ownership still belong
to the local player. Dedicated observers retain the existing overview camera.

Eligibility comes from the confirmed roster/health. The camera keeps its current
living, connected target; if that target disappears, it chooses the first eligible
seat. A generation number distinguishes a new body in a reused seat. Keeping
an eligible target makes selection stable; filtering disconnected bodies
prevents following a departed player.

The camera follows the displayed rig position, including remote interpolation and
local correction smoothing. Ordinary target changes use the authored Camera2D
smoothing. A rendered floor warp or body replacement resets camera smoothing so
it does not sweep across the arena. The camera's lifetime stays with the game
root, so deleting a watched runner cannot delete the camera. No simulation fields,
network messages or checkpoint format changes are needed.

The small, dim nameplate scale and placement also match the original
`fx/nameplate.tscn`. Those are presentation settings, independent of player identity.

```sh
RSY_HEADED_ROLE=client RSY_AUDIO_DRIVER=Dummy \
  RSY_SCREENSHOT=/absolute/output/downed.png \
  nix develop --command bash examples/replay_scrapyard/revive_run.sh

RSY_CAMERA_MIGRATION=1 RSY_DEV=1 \
  nix develop --command bash examples/replay_scrapyard/migration_run.sh
```

The revive test checks actual camera/rig positions before and after revival,
preserved zoom/bounds/smoothing, the personal HUD and the watching label. The run test checks camera center after floor warps. The optional migration fixture downs
member 3 with an admitted development action, confirms it is watching the original
host, then kills that host and requires it to follow the surviving teammate after
checkpoint recovery. The ordinary planned-handoff case still runs.

[Evidence](../../docs/replay/results/scrapyard-camera-2026-09-07/README.md) records
native/headless checks and captures. Dummy audio does not establish hardware
listening parity; WASM is compile-checked for this slice. Browser interaction,
remaining actor/menu presentation and full comparison
remain requirements.

[Chat/history](chat.md) uses a separate communications service.
