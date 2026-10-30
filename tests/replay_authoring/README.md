# Paid-revive authoring comparison

Run `REPLAY_AUTHORING_OUT=/absolute/fresh/directory nix develop --command bash tests/replay_authoring/run.sh`.

This creates independently runnable Kit and Replay game copies, installs the same
paid-revive feature, builds both, and runs three players through the shared
contract. The originals and main Replay game remain untouched. The preserved
feature patches are applied before test adapters; ownership cleanup of the Kit
copy is recorded separately. To open a prepared game directly, build its `project`
directory and run its normal `main.tscn`; its usual menu and revive controls work.
Use the matching built extension through `ODIN_SCRIPTS_DLL` when needed.

The feature costs the rescuer three scrap, pays those three to the revived player,
and restores the existing four HP. It uses the existing two-second channel and
56-pixel reach. Funds and recipient capacity gate the channel/consequence; the
recipient's alive state prevents a second rescuer or continued input from charging
again. Each variant has an explicit experiment compatibility identifier.

The full matrix has three cases (funded, funding while held, contended), no-delay
and 120-ms receive-delay conditions, and two repetitions with alternating
implementation order. That is 24 three-process runs / 72 peer receipts. The delay
is per process, not a measured 120-ms RTT; no loss/jitter/duplication is injected.
`REPLAY_AUTHORING_SMOKE=1` runs one funded local pair and produces a distinct
smoke marker; the report rejects incomplete plans unless explicitly invoked with
`--allow-partial`.

Test setup uses existing development methods to grant funds and down a teammate.
Input uses each game's existing held-revive driver. The adapter only reads state
or forwards those operations. The gameplay feature remains in the actual revive
path, never in the driver. Authority conservation is checked every driver frame;
all peers must converge, and another 2.5 seconds of held input must leave the result
unchanged. A missing-funds case verifies three seconds of refusal before funding
arrives while the input remains held. Either contending rescuer may win.

`feature/feature.patch`, before/after snapshots and `changes.json` identify the
feature alone. Counts include added/removed physical and nonblank lines, split by
file responsibility. Source formatting and pre-existing helpers influence these
numbers. They are not human authoring time, productivity, debugging effort or a
whole-framework verdict. Generated code, content, test adapters, copied assets
and baseline ownership cleanup are excluded from feature counts but preserved in
source/build manifests or separate evidence.

Important boundaries: Kit uses owner-time channels, host consequences and a
replicated stat registry; Replay uses scheduled controls and a value reducer for
prediction and authority. Wallet/health updates can arrive separately on Kit
clients; convergence is required, while conservation is enforced on the host.
The u32 receiver-capacity checks are present in both patches; this process matrix
uses small wallets. Save/migration acceptance for this experimental rule, broader
faults, other authoring changes and human/timed studies remain work.

After all successful receipts, peers stop application and engine networking at a
shared barrier before freeing their scenes. An earlier simultaneous-close run
hit an ENet send error after its results were written; that partial run is retained
separately and does not count as a completed matrix. This teardown is test-only
and is not a graceful-disconnect or migration acceptance claim.

The report recomputes line counts and net added library API occurrences (subtracting retained calls on changed lines) from actual
before/after files, verifies the displayed patch, checks source/binary hashes,
and requires every planned receipt plus the teardown barrier. Run
`python3 tests/replay_authoring/verify_report.py OUTPUT_DIRECTORY` to exercise
its rejection cases. The original and primary Replay game files are never test
mutation targets.
