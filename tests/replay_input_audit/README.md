# Short-input audit

Current Scrapyard uses dash actions. Preparation automatically selects a sequence
audit: request, queue admission, transport sends, authority arrival/admission,
committed result and the driver's observed result. The same bounded numeric buffer
is dumped after gameplay. The analyzer still understands archived control-bit
audits from older source snapshots; those diagnose a different input path.

This fixture copies Replay and the endurance game before adding diagnostic records.
It follows dash requests, attempted input steps, successful captures, accepted
transport sends, authority arrivals/acceptance and model execution. Production
code is not instrumented. A fixed 16,384-entry numeric buffer is dumped when the
game exits; overflow invalidates interpretation. Results are diagnostic and must
not be pooled with normal performance measurements.

```sh
REPLAY_INPUT_AUDIT_OUT=/absolute/fresh/directory \
  nix develop --command bash tests/replay_input_audit/run.sh
python3 tests/replay_input_audit/analyze.py /absolute/fresh/directory
```

The launcher uses the endurance profile's participant tokens and disables ordinary
action tracing. `REPLAY_INPUT_AUDIT_PAIRS` selects repeated runs, default three.
`REPLAY_INPUT_AUDIT_REUSE` reuses an existing diagnostic build at its original path
only after source, instrumentation and binary checks. Original framework/game
sources and user data remain separate. The capture marker is not workload
acceptance: inspect each press's diagnostic path and the normal endurance gate.

`REPLAY_INPUT_AUDIT_PROFILE=jam` uses the separate jam-clearing workload with the
same diagnostic records. The default remains `endurance`; build reuse checks the
selected profile as well as source and binary hashes.

`REPLAY_INPUT_AUDIT_SHOTS=1` additionally records ballistic births and terminal
causes in the copied game. Run `shot_analyze.py OUTPUT` to reconcile every fired
shot with an enemy impact, cover impact or expiry/bounds miss. Enemy HP differences
must exactly match the authority's damage and kill counters. This is a diagnostic
of the bolter workload, not a way to bypass the comparison's minimum kill count.
Build reuse also checks whether shot instrumentation was requested.

The recorded pre-fix run reproduced a lost press: it remained latched through a
450 ms prediction stall, was captured for tick 869, and arrived after authority
tick 904. A small old correction had freed one input step immediately before a
newer snapshot advanced the client. Fresh input must wait while validated
authority progress already exceeds its proposed tick. Packet-driven timeline
movement must also be distinguished from actual control consumption.
