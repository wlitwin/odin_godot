# Hello input acceptance

```sh
REPLAY_HELLO_INPUT_OUT=/absolute/fresh/output nix develop --command bash tests/replay_hello_input/run.sh
```

Real Godot pause tests run at 30/60/120/144 FPS. They require no simulation progress
while paused, no deferred shot from a paused tap, no movement/fire from controls
held across resume, and one new shot after release and a fresh press.

A test-only method feeds explicit frame durations into the production process
function, after disabling automatic processing once the node is ready. Its device
sampler, fixed clock, shared reducer, journal and renderer remain the real code.
One second at each rate produces exactly 60 ticks, five held-fire shots and the
same movement. A press/release before any tick survives until one tick consumes it;
a ten-second stall produces only eight steps, and pause/resume leaves no backlog.

The full existing native/rendered/Chrome history, field editing, recording export,
loaded playback and branching suite follows. A separate Chrome keyboard test uses
the real pause API through the existing bridge and checks the same tap/held/fresh
press rules. Test copies and output paths preserve original projects and profiles.
