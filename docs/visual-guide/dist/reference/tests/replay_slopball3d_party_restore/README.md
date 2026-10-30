# Slopball3D browser published-party restore

```sh
REPLAY_SLOPBALL3D_PARTY_RESTORE_OUT=/absolute/fresh/output \
  nix develop --command bash tests/replay_slopball3d_party_restore/run.sh
```

The runner covers restoration by the original creator and by the trusted player
in seat two. Both cases start three named players plus an observer and publish a
scored, moving/spinning world. Every source browser and the service are SIGKILLed;
exit signals/codes are checked. The service reopens its database with creation
disabled. An independent reader validates the complete checkpoint, tick/digest,
body scopes/frontiers, score/names and ball position/quaternion/velocity vectors.

The observer registers first and cannot become authority. The selected trusted
member restores the exact saved world in epoch two. Its first actual solver seed
must match the independent checkpoint within 0.0001 for position/velocities and a
quaternion dot magnitude above 0.99999. Nonzero horizontal speed, angular speed and
nontrivial orientation are required in the source checkpoint.

The creator returns only after restoration when seat two hosts. All original seats
and names return. The new authority must make another kick and score for its team,
then publish revision two; the independent decoder checks the new authority seat
and publisher as well as the complete continued world. Guest publication is refused.
Named observer chat, common world hashes, RTC traffic, graphics traces, control
layout and absence of browser-local save slots are checked.

`RS3_RESTORE_OWNER=host` or `striker` selects one case when using
`execute.py WEB_BUILD SERVICE_BUILD FRESH_OUTPUT`. The injected observer invokes
normal actions and reads the real game; it does not inject a checkpoint or world.
Raw browser profiles, databases and credentials are private test state. Retain
redacted events, logs, source hashes and decoded receipts when sharing results.
Public deployment, arbitrary failure sequences and solver contact-cache rollback
remain outside this local acceptance gate.
