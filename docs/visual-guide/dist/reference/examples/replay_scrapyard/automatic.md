# Automatic loadout preferences

Each staging picker now includes an automatic choice alongside loaded explicit
choices. Skin and iron display **By seat**; Q/E display **Auto**. New profiles use
all four automatic choices. Both directions traverse the automatic entry and skip
catalog holes. Choosing any entry still clears readiness.

An automatic skin resolves from the current seat modulo the three skins. An
automatic iron resolves from the seat's position in the current gun catalog,
skipping an absent entry. Automatic abilities use the classic Q/E defaults (1/2),
falling back to the first loaded ability if needed. Explicit choices remain fixed.
Resolution happens before declaring a profile, so remote peers and the simulation
receive ordinary concrete, validated IDs. No automatic sentinel enters gameplay.

The local profile codec now writes version-2 content `0x52535950524f4632`. It adds
four automatic-choice bits to the identity-bound record. The strict version-1
reader maps older records to explicit choices, preserving their stored profile,
identity and epoch/tick. Merely decoding an old record does not modify its bytes;
subsequent successful saving uses version 2. Undefined bits, corrupt envelopes and
wrong identities are rejected. Automatic choices add no world/action/event or
run-checkpoint fields; gameplay content changes are tracked separately.

Native atomic-file writes and browser revision-checked IndexedDB writes retain
the existing durability rules. The mode is saved only when its resolved choices
match authority, preventing an older acknowledgement from persisting a different
explicit choice. The last confirmed mode supplies the recovery baseline. Initial UI baselines wait
for the opening profile claim, and a generation change recognizes choices that
were accepted in the same tick before applying that baseline. Choosing
auto survives a fresh process and resolves again if that process gets another
seat; choosing explicit then persists those IDs on later seats. With persistence
disabled the modes apply only to the current session.

```sh
nix develop --command bash examples/replay_scrapyard/automatic_run.sh
nix develop --command bash examples/replay_scrapyard/automatic_web_run.sh
```

[Evidence](../../docs/replay/results/scrapyard-automatic-2026-09-08/README.md) covers
model resolution/cycling, a frozen version-1 record, native/browser fresh-process
and changed-seat checks, and profile corruption/write-conflict regressions. The
browser fixture also verifies that another peer receives the resolved choices.
The ability pickers now offer an explicit return to Auto; the original ability
cycler only used its automatic fallback when it could not find a loaded row.
Remaining presentation/platform work, playtests and full comparison remain open.
