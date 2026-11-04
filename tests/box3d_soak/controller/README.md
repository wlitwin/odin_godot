# Gate B process controller

This controller runs the existing Kit or Replay scene in two independent Godot
processes. It has no simulation, authority, clock, input, or transport
implementation. Gate B remains unmet: a functional soak does not establish the
separate normal and correction CPU ceilings.

The default invocation writes a plan without launching processes. The primary
candidate declares32 initial dynamics,36,000 ticks after admission, a shared
stop at36,600, seed17,10ms local receive latency and1ms jitter, no modeled loss,
and at least600 observed seconds from both GO records until the first endpoint
reaches the target. Lifecycle and deeper recovery cases remain separately
required. A4-body option is explicitly a controller smoke, never a32-body soak
substitute.

`build.py` uses the standard project/Core build and prepared-import helpers. It
records the production source graph, generated bindings, actual Odin argv,
explicit speed/debug flags, imported project tree and binary hashes. `run.py`
requires that exact build record and rejects a frozen binary tree attributed to
a different current production source graph. Driver and library artifacts must
be kept separately; no build/import result is invented for reused binaries.

For example, after the native candidate and shared sources are frozen:

```sh
python3 tests/box3d_soak/controller/build.py --framework kit \
  --native /absolute/verified/libogb3.dylib --odin /absolute/odin \
  --out /new/build-evidence
python3 tests/box3d_soak/controller/run.py --framework kit \
  --project /new/build-evidence/project \
  --build-record /new/build-evidence/build-record.json --out /new/plan-evidence
```

Execution requires a new output directory and `--execute`. Each build/run
selects one sibling. CPU measurements require their own exclusive grant and are
not part of this launcher.

Every actual follower confirmed export requires a full five-part byte match.
Authority exports are explicitly retained as reference-only until requested;
unpaired reference counts are reported rather than called comparisons. The
default strict policy in the shared store is unchanged. Baseline frames are
comparable inclusively; delivery decisions start strictly after the actual
admission baseline. Later missing decisions/effects fail; this controller adds
no recovery exclusions. Existing pair intent, predicate, provenance and effect
checks run after streaming storage checks.

Full bytes enter durable bounded storage before producer-file copies are
removed. A first mismatch retains both five-part states, signatures, a bounded
actual authority input window, actual issued requests and an immutable
observation-archive prefix. Unknown used prediction history and correction
sequence/depth remain explicit. Global effect IDs remain on disk across hot
history retirement.

Limits include256 pending/unsealed follower frames,65,536 comparison metadata
keys per role,32,768 action/effect audit rows per role,1MiB lines,1,024 queued
records and128MiB logs per actor. Defaults reserve1,536MiB for the shared store
and256MiB for observation database/staging. These are controller overhead,
separate from the unchanged64MiB requested native/wrapper/Host quota. Exceeding
a bound fails or holds evidence; it never truncates a passing stream.

`check_saved.py` exercises the frontend on immutable saved actual cases without
launching Godot or manufacturing cross-process timing. `test_controller.py`
contains synthetic failure controls for source binding, cleanup containment and
actionable first-mismatch context. Neither is a new physics or soak result.
