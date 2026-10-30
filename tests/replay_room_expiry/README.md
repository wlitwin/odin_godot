# Room transition expiry regression

```sh
REPLAY_ROOM_EXPIRY_OUT=/absolute/fresh/output nix develop --command bash tests/replay_room_expiry/run.sh
```

`prepare.py` creates an isolated Claimball build with a test-only clock wrapper.
The wrapper moves a peer's clock forward to its existing lease deadline between
Room's outer check and the transition operation's own check. Room and Lease then
continue in the same shifted time domain. It never extends a deadline, grants
permission, changes the coordinator clock or changes the system clock.

The existing planned/crash migration scenario must still pass. Every surviving
peer must report exactly one injected expiry and one preservation receipt. At that
point its old epoch and simulation head are unchanged, its runtime remains ready,
and gameplay is fenced. Fresh authenticated control progress must permit eventual
migration, exact checkpoint restoration, new actions and common-world agreement.
The injection is absent from the shipping game and library.

Companion deterministic tests in `tests/replay_provision_godot_core/room_expiry_test.odin`
cover redirect, old-owner rejoin and published-restore preflight. A valid clock
reaching the deadline pauses; an invalid clock sample still fails. Prepared
publication data is retained and simulation does not advance on the failed attempt.

`execute.py APP_BUILD COORDINATOR_BUILD FRESH_RESULTS` reuses prepared builds.
Raw coordinator/checkpoint/profile state must be excluded from published receipts.
This reproduces a specific transition-expiry failure; it does not establish the
cause of the older intermittent Claimball browser Fenced error.
