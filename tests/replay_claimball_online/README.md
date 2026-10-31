# Claimball Party and browser acceptance

`run.sh` prepares a native game and typed Room service, builds/exports Web with
speed optimization, runs the browser cases, independently reads the service's
publications, and exercises native Party UI. Set `REPLAY_CLAIMBALL_ONLINE_OUT` to
a fresh output directory. The native UI/profile test is a prerequisite.

For separate runs, use the build/execute scripts in this directory with prepared
output paths. `RCB_ONLINE_MODES=planned` or `crash` selects one browser case.
Each run uses isolated ports, service data, browser profiles and credentials.

The browser case creates one host, two players and an observer from an invite;
rejects a malformed invite; starts real play; waits for a complete moving/scored
backup; publishes; hands off or SIGKILLs the host; and verifies exact promotion.
It issues two new spikes, rejoins the observer, opens a fresh host browser with its
retained profile, rejoins seat one, checks old/new named chat and common full-world
hashes, and publishes revision two. Actual RTC byte counters and graphics-buffer
traces are checked. Both clients retain one predicted avatar, the observer zero.
Party publication must not create browser-local game-save slots.

`native.py` adapts the existing UI flow to visible Party controls and stored-credential
rejoin. It checks scoring, typing capture, named observer chat and identity
separation, then explicitly leaves every participant. The standalone test's
"host exit disconnects everyone" assertion is inapplicable to a recoverable Party;
owner-loss continuation has its own browser acceptance case.

The initial scene-wiring and shutdown-fixture failures, plus an unexplained browser
Fenced failure, are retained in the result record. Later diagnostic runs do not
establish that first fencing failure's cause. No runtime recovery rule was relaxed.

Raw service/Party databases, browser profile directories and invite files contain
credentials. Retain hashes and redacted observations in published receipts, not
those raw files. The injected `online_test.gd` bridge is a test-only export addition;
it does not grant authority or install synthetic game worlds.
