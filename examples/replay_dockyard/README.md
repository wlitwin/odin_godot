# Dockyard Duo

Two salvage robots haul awkward cargo onto an escape barge. Odin owns the game
rules, Replay owns prediction/recovery, Box3D owns physics, and Godot owns
editor authoring and presentation.

**Unreleased review candidate.** Actual native/browser multiplayer, full state,
recovery, rendered play and audio work in the recorded local cases. Both final
610-second browser arrangements meet the original normal-frame limits. Firefox
had one 45.92 ms eight-step correction against a 25 ms maximum; qualification remains
rejected. The public Room service is deployed and passed relay/recovery checks
from the reference network. Independent off-network acceptance and two-human
co-op feedback remain open.
See the [current build status](../../tests/replay_dockyard/online/current-handoff-status.json)
and [handoff](../../docs/design/box3d/showcase-candidate.md).
The newer [invite usability update](../../tests/replay_dockyard/online/invite-usability-report.json)
adds short room codes and browser-native copy/paste. Its two-player and native
checks pass; the public spectator terminal audit remains unresolved. The earlier
performance measurements have not been rebound to this newer artifact.

## Run a prepared candidate

Use Godot 4.7.1. The included Native SDK project is macOS ARM64, requiring at least
macOS 14.0. It is not a signed app or universal SDK. From the candidate directory,
open separate terminals:

```sh
python3 native-macos-arm64/launch.py host --project native-macos-arm64 --godot /PATH/TO/GODOT
python3 native-macos-arm64/launch.py client --project native-macos-arm64 --godot /PATH/TO/GODOT
```

`practice` opens one mint-robot window. A compatible native client on another
machine can use `--address HOST_LAN_IP`; both roles use port49791 by default,
changed with `--port`. Native/Web crossplay remains unqualified.

For browser files, run `python3 serve-web.py --port 8080` from the candidate.
Open the served page with a compatible room service:

```text
http://127.0.0.1:8080/index.html?service=ENCODED_COMPATIBLE_WSS_URL&relay=1
```

The local file server supplies the required isolation headers. A room service
and TURN relay are separate processes; the package includes operator templates
and no credentials. Public hosting requires HTTPS/WSS, those headers and actual
remote connectivity checks. See [deployment configuration](deploy/README.md).
The deployed review Room endpoint is
`wss://mc.laserturtle.net:62127/replay-room/dockyard`; use `relay=1` for its
authenticated TURN provider. The package README includes the encoded launch URL.
The service [archives idle disconnected crews](deploy/pi.md#resident-room-lifecycle)
when resident capacity is needed, so completed test/player rooms do not exhaust
the16 active slots. See the [deployment verification](../../tests/replay_dockyard/online/room-retirement-report.json).
Choose a name and **Host** or **Join**, sharing the five-character room code.
The host's copy button displays the code so a crewmate can also type it directly.
On Web, clicking the code field opens a native browser text field: paste with
Cmd/Ctrl+V and choose **Use code**, then **Join**. The copy dialog uses a native
**Copy code** button and also supports Cmd/Ctrl+C. This works inside itch's iframe
without clipboard-read permission. Older complete invitation tickets are still
accepted. Tabs in the same browser can play as separate players. Each live tab
holds its own saved player seat; reloading keeps that tab's seat, and duplicating
a tab chooses another available seat. The first seat preserves existing saved
crews. Refresh all open tabs after updating an older build.
Hidden tabs use timer updates to keep room traffic running, returning to normal
display-synchronized rendering when visible. Browsers may throttle these updates;
a frozen or suspended host still loses its hosting permission.
For same-browser testing in Firefox, load both tabs before hosting. Loading a
second game after hosting can still expire the first tab's lease; this separate
startup limitation is retained in the [two-tab checks](../../tests/replay_dockyard/online/two-tabs-report.json).
**Recent Crew** reuses that seat's membership. **Watch** uses the same short code to enroll a
receive-only observer through its separate invitation.

## Play

| Input | Action |
| --- | --- |
| WASD / arrows | Drive relative to the camera |
| Aim and hold left mouse | Pull eligible cargo within reach |
| Space | Acknowledged boost action with cooldown |
| 1 / 2 / 3 | Select a load for aim height; hold to aim directly at it |
| F2 | Local sound, camera distance and reduced-effects settings |
| Escape | Crew / leave menu while the shared job continues |
| F3 | Actual session diagnostics |

Mint is player1; coral is player2. Pull together up the ramp and match each load
to its bay. Release the magnet and allow two seconds to latch. The long load
benefits from both players. Robots recover after a fall; lost cargo reduces the
payout. Jobs have a150-second deadline, three loads and payouts. At results the
host can retry or select the next of three arrangements through a Replay action.

Host loss or expired hosting permission ends the job and offers **Start a New
Crew** after closing the old runtime. Seamless takeover and full-match replay
are outside this candidate. See [recovery evidence](../../tests/replay_dockyard/recovery/README.md).

### Viewport and high-DPI layout

The HUD uses a 1280×720 design size with Godot's `canvas_items` stretch mode and
`expand` aspect handling. Anchored containers keep status at the top left, crew
controls at the top right and instructions at the bottom left. Settings and
results use centered containers. Text and pointer hit targets share the same
logical viewport coordinates; device pixel ratio does not multiply the UI scale.
The orthographic camera retains the reference dock framing on narrow windows.
See the [layout checks](../../tests/replay_dockyard/presentation/README.md).

## Build from source

Enter `nix develop` at the repository root and use new cache/output directories.
The backend pins Box3D 33626332 from2026-10-28. The driver verifies the complete
source/archive and the small shim adaptation.

```sh
bash build/build_box3d.sh Release /tmp/dockyard-native
python3 examples/replay_dockyard/prepare.py \
  --out /tmp/dockyard-build \
  --native-library /tmp/dockyard-native/build/Release/libogb3.dylib \
  --sqlite-library "$(pkg-config --variable=libdir sqlite3)/libsqlite3.a" --build
python3 examples/replay_dockyard/launch.py host --project /tmp/dockyard-build/project
python3 examples/replay_dockyard/launch.py client --project /tmp/dockyard-build/project
```

The static SQLite input preserves strict Native dependency admission.
`REPLAY_SQLITE_LIBRARY` supplies the same option. Browsers use IndexedDB.
Other native targets need their own backend builds and runtime checks; the
candidate relocation proof covers macOS ARM64.

For Web, build the SIMD archive and use its printed absolute path:

```sh
bash build/build_box3d.sh WebSIMD /tmp/dockyard-web
python3 build/web_rtc_template.py derive \
  --source "$HOME/Library/Application Support/Godot/export_templates/4.7.1.stable/web_dlink_release.zip" \
  --out /tmp/dockyard-rtc-template
REPLAY_SQLITE_LIBRARY="$(pkg-config --variable=libdir sqlite3)/libsqlite3.a" \
BINARYEN_CORES=1 python3 -B tests/box3d_web/replay/export.py \
  --out /tmp/dockyard-export \
  --native-library /tmp/dockyard-native/build/Release/libogb3.dylib \
  --web-archive /ABSOLUTE/PRINTED/PATH/libogb3.a \
  --odin "$(command -v odin)" --godot "$GODOT" --emcc "$(command -v emcc)" \
  --web-template-record /tmp/dockyard-rtc-template/template-record.json
```

This uses the normal SDK/import/Godot exporter. `BINARYEN_CORES=1` is the controlled
optimizer setting used after a retained parallel optimizer crash. It changes no
simulation worker, assertion or floating-point policy. The [browser checks](../../tests/box3d_web/replay/README.md)
exercise separate actual clients. Serve one identical artifact to the browser
cohort; native/Web crossplay remains unqualified. The pinned custom template
changes only the RTC send-copy function in Godot's JavaScript. Its record and
reproduction helper accompany the review package; both official engine Wasm
payloads stay byte-identical.

After checking those exact runtime bytes, create a review package. The runtime
record supplies the compatible room cohort:

```sh
python3 examples/replay_dockyard/package.py collect \
  --export-record /ABSOLUTE/EXPORT/report.json \
  --runtime-report /ABSOLUTE/RUNTIME/report.json \
  --qualification-report tests/replay_dockyard/online/current-handoff-status.json \
  --include-native-sdk --out /tmp/dockyard-candidate
python3 examples/replay_dockyard/package.py verify --package /tmp/dockyard-candidate
```

Packaging starts no compiler, game or external deployment. It verifies ordinary
export bytes, fills the operator cohort from the matching runtime, and retains
qualification rejection. It excludes fixture bridges, profiles, private databases,
credentials and private keys. Editing the frozen Native project needs the source
SDK/tools and a fresh build.

To include Godot's compiled license notices, extract them from the installed
engine with [engine_notices.gd](../../tests/replay_dockyard/package/engine_notices.gd)
and pass that output directory as `--godot-notices` to `collect`. The extractor
records its actual engine version; compiled module inventories can vary by target.

## Create an itch.io ZIP or upload with Butler

From the repository root, point the publishing script at a prepared candidate
(the directory containing `manifest.json`, `web/` and `qa/`, or its review
`.tar.gz` archive):

```sh
bash examples/replay_dockyard/publish.sh --package /PATH/TO/dockyard-candidate
# Or: --package /PATH/TO/Dockyard-Duo-review-public-room-macos-arm64-web.tar.gz
```

The command prints the ZIP path under `examples/replay_dockyard/out/itch-BUILD_ID/`.
It puts `index.html` at the archive root, includes the licenses and QA status,
and configures the deployed Room endpoint from the candidate's QA record with
authenticated TURN enabled. Players can launch without adding URL parameters.
`--service-url wss://HOST/PATH` selects another compatible deployment.
The script changes the copied HTML launch defaults; engine JavaScript, Wasm and
game PCK bytes retain their candidate hashes. The original candidate is preserved.
An identical repeat verifies and reuses the output. `--out /NEW/DIRECTORY` selects
another location. This packages an existing build; source changes require a fresh
export and candidate through the commands above.

Upload the printed ZIP on an itch.io **HTML** project, mark it **playable in the
browser**, and enable **SharedArrayBuffer support** in its embed settings. Choose
a 1280×720 viewport or fullscreen launch. See the
[itch.io HTML5 upload guide](https://itch.io/docs/creators/html5).
For a local preview, serve the printed `web/` directory with isolation headers:

```sh
bash build/serve.sh /PATH/TO/itch-BUILD_ID/web 8080
# Open http://127.0.0.1:8080/
```

For an upload workflow similar to Scrapyard's standalone `publish.sh`, log in
once and add an explicit destination:

```sh
nix run nixpkgs#butler -- login
bash examples/replay_dockyard/publish.sh \
  --package /PATH/TO/dockyard-candidate --push YOUR_ACCOUNT/YOUR_GAME
```

The script uses Butler on `PATH`, falling back to `nix run nixpkgs#butler`, and
uploads the same unpacked ZIP contents to `html5`. `--channel` and `--version`
override those defaults. The upload does not create the itch project or configure
its embed options; set those once on the edit page. See the
[Butler upload guide](https://itch.io/docs/butler/pushing.html).
The existing open qualification and playtest gates stay recorded in the ZIP.

## Code and evidence

The scene has19 bodies/shapes, eight geometries and one hinge, within the35-body/
shape, one-joint and64MiB admission profile. Magnets use Native ray hits, point
impulses and damping. Godot meshes/effects add no physics bodies. Loading draws
visual variants before enrollment; tethers/confetti share one opaque material
style. Web voices use stream playback through suspend/resume. Confirmed
`Cue_Route` changes drive a bounded sound/effect FIFO once.

The checked flat C body-type addition preserves ABI1/POD layouts and requires
current rebuilt libraries. Kit and Replay share the reusable backend.
See [the contributor tour](CONTRIBUTING.md), [round checks](../../tests/replay_dockyard/rounds/README.md),
[presentation checks](../../tests/replay_dockyard/presentation/README.md),
[qualification](../../tests/replay_dockyard/qualification/README.md) and
[packaging checks](../../tests/replay_dockyard/package/README.md).
Earlier reports retain their original build/hardware scopes. Automation,
screenshots and nonzero audio signal do not supply human co-op feedback.
