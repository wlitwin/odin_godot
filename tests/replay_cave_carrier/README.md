# Cavecrawl carrier acceptance

```sh
REPLAY_CAVE_CARRIER_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_carrier/run.sh
```

Runs 33 Cave tests and WASM checking, an isolated Godot game build and coordinator,
fifteen C1–C7 conversion/resume cases, native retained-frame carrier checks,
four carrier migration scenarios and full normal/faulted campaigns. The aggregate
gate is registered in `tests/run_all.sh`.

The two C6 archives contain scripted pre-change dead/disconnected world states.
They were encoded by C6's actual checkpoint API before changing the model. They
exercise conversion and subsequent state advancement, not transport departure.
Their producer, model sources, logs and hashes live under
`tests/replay_cave/fixtures/content6`. Regeneration requires the archived C6 model.

`migrations.py PREPARED [LABEL]` runs real coordinator/host/successor/guest processes
with 120 ms receive delay. Carrier seats 2 and 3 each cross planned and crash
takeovers. The host waits for the carried state to reach both the acknowledged
backup and coordinator-authorized checkpoint. Surviving processes verify unchanged
carrier/version after twenty new-epoch ticks, continued attachment while moving,
and a fresh set-down action. Test probes only read authoritative observations.
Old-host carrier adoption is outside these four scenarios and remains open.

The three-browser variant extends the existing social/RTC gate with a guest's
initial relic grab, authoritative carrier/attachment observations before and after
handoff, and a fresh release seen by all three browsers:

```sh
nix develop --command bash tests/replay_cave_carrier/browser_build.sh /absolute/fresh/native
nix develop --command bash tests/replay_cave_carrier/web.sh /absolute/fresh/native /absolute/fresh/web
```

Prepared source manifests and driver/export/binary hashes accompany the receipts.
The [behavior guide](../../examples/replay_cavecrawl/carrier.md) records lifecycle,
identity replacement and authority-adoption boundaries.

`REPLAY_CAVE_CARRIER_WEB_OUT=/absolute/fresh/output nix develop --command bash tests/replay_cave_carrier/web_run.sh`
combines the browser build/run and is separately registered in `tests/run_all.sh`.

`migrations.py PREPARED LABEL reverse` admits member 3 before member 2, so the
chosen member 2 holds game seat 3. Planned/crash cases verify identity-based
successor resolution and continued carrying without assuming member ID equals seat.
