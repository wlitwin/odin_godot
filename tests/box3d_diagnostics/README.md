# Offline diagnostic bundle tool

`tools/box3d_diagnostics.py` copies only explicitly selected files and runs the
existing trusted inspector as `INSPECTOR TRACE_FILE`. It implements no Trace
parser, physics replay, recovery or simulation. The inspector must be supplied
as an absolute executable path plus its independently trusted lowercase SHA256.

```sh
python3 tools/box3d_diagnostics.py collect --framework kit \
  --trace /absolute/first-divergence.trace \
  --inspector /absolute/inspect-trace --inspector-sha256 EXACT_SHA256 \
  --attachment report:case=/absolute/original-case-result.json \
  --attachment report:retained-failure=/absolute/separate-failed-case.json \
  --attachment log:host=/absolute/host.log \
  --attachment build:runtime=/absolute/build-record.json \
  --attachment source:inputs=/absolute/source-manifest.json \
  --out /absolute/NEW-bundle
python3 tools/box3d_diagnostics.py verify --bundle /absolute/NEW-bundle \
  --manifest-sha256 MANIFEST_SHA256
python3 tools/box3d_diagnostics.py inspect --bundle /absolute/NEW-bundle \
  --manifest-sha256 MANIFEST_SHA256 \
  --inspector /absolute/local-inspect-trace --inspector-sha256 LOCAL_SHA256
```

Framework is exactly `kit` or `replay`. Repeat `--attachment KIND:LABEL=ABS` for
`log|build|source|report|other`; labels are unique per kind,1..64 safe ASCII
characters. No environment dump, repository discovery, download or implicit
attachment selection occurs. No action is implicit: omitted action/required
arguments give usage/exit2. No shell is used for the inspector subprocess.

Collection publishes a new directory containing:

- `manifest.json`: schema1, framework, original `collect_inspector` identity and
  actual argv/exit, exact file paths/kinds/labels/byte counts/SHA256, and
  `run_verdict:"NOT_INFERRED"`.
- `trace.bin`: the complete unmodified Trace bytes.
- `attachments/<kind>-<label>`: complete exact copies of selected files.
- `inspector.stdout` and `inspector.stderr`: complete bounded raw tool output.

The original report is opaque bytes. A successful intentional-divergence case
may have `success:true`; a separately labelled historical FAIL remains FAIL.
Neither is normalized, parsed into a substitute verdict or requalified. Labels
identify provenance chosen by the caller; integrity hashes do not authenticate
the sender, certify the report's claims or establish build compatibility.

Fixed bounds are32 total files including the manifest,16MiB per file,64MiB
aggregate including all files, Trace<=9MiB, manifest<=256KiB and each inspector
output<=64KiB. Thus at most28 attachments fit. Inspector executable reads are
separately bounded to64MiB; inspector wall timeout is30seconds. These are offline
tool bounds, not Native/Meter memory quotas or physics timing measurements.

The tool rejects source/bundle symlinks, traversal, duplicate labels/source
identities/member paths, malformed/corrupt/missing/unlisted members, oversized
inputs and observed input/tool changes. Explicit parent aliases such as macOS
`/tmp` are canonicalized; selected leaf symlinks and every bundle-member symlink
are rejected. Source files must be regular; FIFOs/devices are not read. Original
source bytes/stat identities are rechecked before publication. Staging is beside
the destination; exclusive atomic directory rename on macOS/Linux cannot replace
even an empty raced destination. Failed collection removes its own staging only.
Other platforms without that primitive explicitly reject collection.

`verify` reads only the bundle and starts no process; original sources and the
collection executable need not still exist. Optional `--manifest-sha256` pins the
manifest to a separately retained identity. `inspect` verifies first, copies only
the Trace into temporary storage, runs the explicit compatible local inspector,
and re-verifies afterward. It does not modify the bundle. A Linux inspector may
have different bytes/SHA from a macOS collection tool: both pins remain separately
reported as `collect_inspector` and `local_inspector`; unknown hashes are never
accepted automatically. Tool pinning is not a claim of physics/source compatibility.

Success JSON is `BUNDLE_COLLECTED`, `BUNDLE_VALID` or `TRACE_INSPECTED`, exit0.
Rejection JSON is `REJECTED` with error/message (bounded subprocess details when
applicable), exit2. Every result has `run_verdict:"NOT_INFERRED"`. The actual
inspector's exit0 and `BOX3D_TRACE_INSPECT_OK` indicate its retained Trace
decode/exact-reencode result; bundle validity is never a gameplay/run PASS.
Inspection of a historical mismatch is not current-build gameplay reproduction.

Run only the focused Python checks with:

```sh
python3 -B tests/box3d_diagnostics/bundle_test.py -v
```

These eight groups use tiny opaque byte fixtures and synthetic Python child
executables. They test copying, opaque verdict preservation, local-tool pin
separation, bounds, atomic/path/corruption/change rejection, child/output limits
and read-only verification. They are **not** actual Trace decoding, Native,
Godot, SDK or cross-target execution evidence. Root owns real inspector builds,
Kit/Replay runtime-generated traces, target checks and `report.json` here.
