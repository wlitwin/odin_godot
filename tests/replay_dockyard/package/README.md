# Candidate packaging checks

`python3 -B tests/replay_dockyard/package/package_test.py` uses opaque synthetic
bytes to check exact copying, matching runtime-cohort binding, existing-output
preservation, corruption detection and symlink refusal. It runs no Native engine,
browser, compiler or network service and supplies no gameplay qualification.

Actual moved Native/Web candidate execution and original qualification records
are separate evidence. The package manifest always declares `release_admitted`
false; a copied runtime PASS cannot override a rejected qualification or missing
public-network/human-review gates.

`runtime.py --package ABS --out NEW --godot ABS` copies the frozen candidate to a
new location, removes source-root environment variables and runs a real Native
Host/Client pair. It requires full state, terminal acknowledgement, one backend
and typed cleanup. Only exact reload copies belonging to its actor PIDs are
removed before verifying the original and moved package bytes again.

The CLI prints a manifest SHA256. `package.py verify --package ABS
--manifest-sha256 HEX` pins that manifest as well as checking its payload map.
The manifest is an integrity record; it does not establish release admission or
sender authorization.

`python3 -B tests/replay_dockyard/package/itch_test.py` checks the itch ZIP's root
entry point, runtime-byte preservation, license/QA inclusion, reproducible ZIP
bytes, source/output integrity, and the explicit Butler upload option. Node runs
the generated HTML bootstrap against nested URLs with existing query values and
fragments. These synthetic checks do not qualify browser gameplay or itch hosting.

`node tests/replay_dockyard/package/itch_smoke.mjs EXTRACTED_ZIP_DIRECTORY NEW_OUTPUT`
boots the actual packaged game in a separate Chrome profile at a nested URL with
no launch query. It checks isolation, configured menu readiness, applied Room/TURN
defaults and typed backend/full-engine exit. The saved screenshot and console
report cover local startup only; hosted itch embedding and off-network multiplayer
remain separate checks. This fixture uses the installed macOS Chrome executable.
