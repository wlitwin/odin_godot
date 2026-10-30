# Claimball native UI acceptance

```sh
nix develop --command bash tests/replay_claimball_ui/run.sh
```

Set `REPLAY_CLAIMBALL_UI_OUT` to a fresh directory to retain the prepared project,
source hashes, build/import logs and process receipts. The test drives real Godot
buttons and inputs through host, client and named observer sessions. It checks
manual leader start, neutral waiting/typing input, player names/teams, measured
ping, literal chat, a scored goal, one predicted avatar, leave/rejoin and retained
score. Fresh-process profile checks cover write/read and preserved corrupt data.
The script also checks the app for WASM; this is not browser acceptance.

Against an already built output, run additional receipts with unique labels:

```sh
RCB_UI_RENDERED=1 nix develop --command python3 tests/replay_claimball_ui/execute.py OUTPUT rendered
nix develop --command python3 tests/replay_claimball_ui/regression.py OUTPUT network
nix develop --command python3 tests/replay_claimball_ui/regression.py OUTPUT compete
nix develop --command python3 tests/replay_claimball_ui/regression.py OUTPUT fault fault-attempt-1
nix develop --command python3 tests/replay_claimball_ui/regression.py OUTPUT stall
```

The adapted runner retains the existing game checker assertions. The fault run
requires loss/duplication and complete local/remote effect reconciliation, including
the observer. A clean rerun does not resolve an earlier missed-effect failure.

For opt-in snapshot diagnostics, first use `prepare.py OUTPUT`, then
`diagnostic.py OUTPUT`, before the initial build. Run `build/build_scripts.sh
OUTPUT/project`, then `build.sh OUTPUT` for import/wait/final build. Launch a
regression with `RCB_DIAGNOSTIC=1`. This instruments only the prepared app, adding
one-second receive/confirmation/baseline counters; it does not change the shipping
app or networking implementation. Prepared hashes identify this different source.
Wall-clock ENet scheduling can vary even with the delay adapter's fixed seed.

## Two-match acceptance

`round_run.sh` prepares/builds a fresh app, runs the existing UI/profile/WASM gate,
then plays two complete matches through Play again. `execute.py OUTPUT LABEL rounds`
runs just the two-match fixture against an existing prepared build. Its driver is
composed from `drive.gd` helpers and `rounds.gd`; the exact result is copied and
hashed in the output folder. `RCB_UI_RENDERED=1` renders the host and captures its
winner screen before restart.

The test rejects guest/observer restart, checks cleared totals, retained chat/names
and seats, actual kickoff/avatar node positions without cross-round smoothing,
one predicted avatar for the guest and zero for the observer, second-match
completion and post-restart chat. Three JSON results must agree on the second
match's score/winner/kick/spike totals.

The same round gate also runs a dedicated authority with two clients and an
observer. `execute.py OUTPUT LABEL rounds-dedicated` selects that case separately.
The match leader is a client, so its restart passes through local projection and
authority correction. Both clients must retain exactly one predicted avatar, the
observer zero, and the dedicated authority must agree on the second-match result.
The server is an owned fourth process and exits through its fixture after peers
reach the completion barrier.
