# Slopball3D Party and browser acceptance

Run `run.sh` inside `nix develop`, with `REPLAY_SLOPBALL3D_ONLINE_OUT` naming a fresh
output directory. Build/execute scripts also accept prepared output directories.
`RS3_ONLINE_MODES=planned` or `crash` selects one browser scenario.

The native prerequisite covers UI/profile behavior and WASM type checking. Native
Party admission retains manual-start, gameplay/input capture, scoreboard/ping,
named observer chat and credential-based rejoin assertions. Every participant
explicitly leaves at the end.

Each browser case creates a host, two players and an observer, rejects an invalid
invite, verifies named chat, starts the match and publishes once. It then starts
the host kicker and requires a complete approved moving/spinning backup. Handoff
or host SIGKILL follows once host and nominee report the same approved spinning
checkpoint while the live ball remains moving in the central pitch. The fixture
rechecks both peers together; an older candidate cannot authorize a newer kickoff
checkpoint. Publication happens before that short physics window.

The successor must restore the exact approved frame and seed its actual solver
with matching position, linear/angular velocity and equivalent quaternion. The
saved angular speed and orientation must be nontrivial. New kicks and a goal,
fresh old-host profile/seat return, observer rejoin, retained/new chat, a common
full-world digest and a second service publication follow. The final publication
is independently decoded. Sixteen RTC observations, graphics traces, viewport
resize, disjoint controls and zero browser-local save slots are checked.

The test-only scene bridge invokes normal game actions and reads actual state;
it does not inject a world or install a checkpoint. Raw databases, browser profiles
and invite files contain credentials and must remain outside published receipts.
These loopback tests do not prove public deployment, solver contact-cache rollback,
cross-device behavior or full-party shutdown recovery.
