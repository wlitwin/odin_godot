# Presentation evidence

`run.py` reuses the bounded online runner and actual production menu inputs. It
opens two headed Chrome processes with rendering enabled and without software-GL
fallback flags, records the actual WebGL renderer/viewport/DPR, captures play and
settings screenshots and uses Puppeteer's real page recorder with installed
FFmpeg. The WebM recorder outputs 30 FPS; this is not a measurement of game FPS.
The complete state, acknowledgement and typed teardown checks still run.

The page initializer inserts a pass-through WebAudio analyser in the real
destination graph. It records output RMS and context state; it does not inject
test audio. Nonzero signal proves rendered audio output, not a human hearing or
usability judgment. The sound samples are original deterministic synthesis from
`make_audio.py`, with provenance beside the generated assets.

```sh
nix develop --command python3 -B tests/replay_dockyard/presentation/run.py \
  --production-ui --ticks 6000 \
  --export-record /ABS/ordinary-export/report.json \
  --service-record /ABS/prepared-service/report.json \
  --out /ABS/NEW-render-case --godot /ABS/Godot
```

The caller-selected 6,000-tick/360-second capture bounds do not change the shared
runner's shorter functional defaults. No backend, model, controller, round rule
or collision-profile change is needed for audio/particles. Confirmed boost and
delivery/latch cues populate a 16-entry local presentation FIFO; the view consumes
each sequence once. The latch thud/score chime is not a claim of a newly exposed
Native collision-contact stream.

`serve.py` starts a private, local-only interactive server from an actual accepted
production export and binds it to the accepted cohort. The existing room service
issues authenticated expiring relay credentials to the ordinary browser. Private
keys, databases, TURN configuration and browser profiles must not be published.
It emits `INTERACTIVE_ONLY_NO_GAME_VERDICT`, never a human-gameplay PASS.
Use distinct browser profiles for separate memberships; the URL is local to the
reference machine. Real two-person co-op feedback remains separate and required.

Actual presentation captures do not qualify the final hardware time/memory/load
contract. Q1 measures those boundaries on the final frozen candidate, retaining
all raw samples, failures and outliers.

## Viewport and DPI checks

`layout.gd` loads the actual prepared SDK scene and checks seven window sizes:
corner margins, panel bounds, centered modals, camera fit and pointer projection.
The fixture observes real Controls and changes their visibility only for modal
geometry checks; it supplies no simulation or networking verdict.

```sh
DOCKYARD_LAYOUT_OUTPUT=/NEW/layout.json GODOT --headless --path /ABS/SDK/PROJECT \
  --script /ABS/REPO/tests/replay_dockyard/presentation/layout.gd
node tests/replay_dockyard/presentation/layout.mjs /ABS/EXPORTED_WEB_DIR /NEW/OUTPUT
```

The browser check runs the ordinary Web export through eight CSS-size/DPR
arrangements, including normal and 2× DPI, small landscape, ultrawide and portrait.
It checks actual corner placement, centered settings, field hit targets, the
native room-code dialog, matching CSS geometry across DPR values, screenshots
and full engine exit. Software WebGL is allowed for this layout check; these are
not GPU performance or mobile-support results.

The read-only `ui_layout=1` query (or native `DOCKYARD_LAYOUT_PROBE=1`) emits
settled Control rectangles on layout/focus changes. It is disabled by default
and contains no field text or invitation codes. The online UI harness uses those
logical rectangles and the canvas's CSS bounds to target controls after resize.
