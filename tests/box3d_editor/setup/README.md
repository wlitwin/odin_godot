# Packaged Box3D setup acceptance

The suite entry `box3dsetup` builds the SDK and runs this gate. To use an already
built SDK, run:

```sh
nix develop --command python3 tests/box3d_editor/setup/run.py --sdk /path/to/sdk-output
```

The build deliberately selects a nonexistent native archive while keeping the
normal DLL domain-admission requirement; pure editor tools must not link it.

The runner copies both packaged addons into an isolated project and uses the
actual editor's setup buttons and Core build coordinator. It does not copy the
frontend from the checkout or run a separate fixture build command.

Coverage includes tracked install/update/removal, hidden/generated/user-file
preservation, local edits/deletions, invalid records, manual merge adoption,
missing compiler recovery, loaded-source freshness, module-only periodic
reconciliation, customized tool builds, concise/expanded Inspector results, and
plugin disable/re-enable, deferred artifact import/retry, and collision rejection
followed by unrelated rebuild and repair without restarting. Removing a previously built main scripts directory
must keep failing across two build attempts; restoring it must recover. Only the
exact expected diagnostics inside marked failure checks are accepted.
All other script/runtime errors and resource-leak diagnostics fail the gate.

Logs and a step report are retained in the printed evidence directory. This
checks real headless editor behavior; it does not claim a manual visual review.
