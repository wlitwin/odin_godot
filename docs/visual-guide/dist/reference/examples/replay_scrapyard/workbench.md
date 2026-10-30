# Editor workbench

Open `dev/workbench.tscn`, choose preview options in the inspector and press F6.
`ReplayWorkbench` boots the actual `main.tscn` game in solo mode, waits for its
normal identity/loadout/ready/start path, then submits development actions. The
world, director, statuses, deaths, shops and renderer use the game's normal code.
The original sibling game's workbench remains independent.

| Inspector option | Preview behavior |
| --- | --- |
| `open_shop` | One short wave; repeatedly damage ordinary enemies through the normal death/credit/drop rules; grant 500 scrap and 20 cores |
| `boss` | Spawn a Titan near the runner; it remains alive and holds the room in combat even when `open_shop` is selected |
| `statuses` | Apply rally and chill, refreshing through the status/reaction rules every two seconds |
| `hurt` | Apply half of the runner's maximum health as damage |
| `jam` | Put the equipped gun into a valid jammed state with its configured clearing taps |
| `kegs` | Spawn 0–12 props near the runner using the existing pool/action path |
| `menu` | Open the Esc menu |
| `wipe` | Down the solo runner and let the normal wipe/reset transition run |
| `note` | Show the narrator notice |
| `tally` | Open the live tally |

The preview uses seed 1337, one wave, no automatic barrels and a 30-tick rest.
`open_shop` selects three normal enemies; otherwise there are six. Timers keep
running. The workbench is playable and a wipe eventually resets normally.

The vitals line remains visible during clear/shop states and shows health,
ammunition, jam/reload state and active statuses. Tab opens the live per-player
kill/damage/mend/scrap/core tally; releasing Tab closes it. Esc opens a menu with return,
run-save, PNG selection and Quit controls in a dimmed, scrolling [menu](menu.md). The menu blocks local gameplay input while
the session continues to simulate and receive traffic. A Room/client cannot use
its save button to write an authority archive.

## Development boundary

The default game model refuses `Dev_Spawn` and `Dev_Edit`. A tool session must
explicitly enable development, and the authority admits edits only from its own
local playable seat. The scene supplies that opt-in. Setting the same flag in a
remote client does not authorize its commands. A dedicated server without a local
seat cannot issue these through the player-facing path.

`Dev_Edit` has a named `Development` payload: kind, target seat, amount and status.
Godot helpers return a submitted action sequence, not an authority verdict:
`dev_hurt`, `dev_jam`, `dev_status`, `dev_grant_scrap`, `dev_grant_cores` and
`dev_smite`. Accepted actions use the existing action ledger, replay and archive
machinery. Smite preserves bosses and props and uses ordinary damage/death rules;
it does not assign the stage directly. Invalid quantities or targets fail before
mutation, and counter overflow aborts the simulation transaction.

The scene disables profile persistence. Its save and spray paths are the separate
`user://workbench-run.replay` and `user://workbench-spray.png`. Both the spray load
path and its separate write destination are scoped to the workbench. Launch environment
values are retained and restored when the workbench exits. Ordinary run/profile
files are not preview output paths. The scene is intended for native editor F6;
its code passes WASM checking, but browser workbench execution is not claimed.

## Checks and current scope

```sh
nix develop --command bash examples/replay_scrapyard/workbench_run.sh
nix develop --command bash tests/replay_scrapyard/development_run.sh
```

The first gate exercises the panels/status/jam preview, a boss that prevents clear,
and a normal wipe. It checks action confirmation, UI content, key transitions,
continued simulation with blocked movement, status refresh, environment restoration
and clean shutdown. A rendered capture is retained in the
[workbench evidence](../../docs/replay/results/workbench-2026-09-07/README.md).
The second gate rejects all six edits from a real client, accepts the host's grants
to that client and compares both complete world hashes afterward.

These additions advance editor/UI parity. The [audio/settings layer](audio.md) now supplies volume, shake, fullscreen and
spray-preview controls. Full visual/listening parity and paired human review remain
required work. This is not a claim of full Scrapyard feature parity.

The action extension introduced content `...3043`; audio event details advance the
version to `...3044`; [cast paths](cast_paths.md) advanced it to `...3046`, followed by [dash actions](controls.md) at `...3047`. Gameplay protocol 7 and checkpoint layout 4 are
unchanged. The explicit [save importer](saves.md#converting-a-protocol-6-run) maps
content-42/43/44/45 archives, including pending accepted/refused requests, while preserving
the complete world and image payloads.
