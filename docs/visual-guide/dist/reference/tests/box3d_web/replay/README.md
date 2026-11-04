# Replay browser physics

`export.py` runs the ordinary Dockyard SDK build, editor import and official Web
export. `browser.py` serves that immutable export with isolation headers and runs
two independent Chrome processes against the existing local RTC signalling
fixture. The relay carries SDP/ICE and room membership; game traffic uses real
WebRTC data channels and the existing Replay Session, complete codec and Timeline.

```sh
python3 -B tests/box3d_web/replay/export.py \
  --out "$NEW_EXPORT" --native-library "$NATIVE_LIBRARY" \
  --web-archive "$WEB_ARCHIVE" --odin "$ODIN" --godot "$GODOT" --emcc "$EMCC"
python3 -B tests/box3d_web/replay/browser.py \
  --export-record "$NEW_EXPORT/report.json" --out "$NEW_PAIR" --ticks 120
```

Use absolute tool/library paths and fresh output directories. Build the selected
Web archive with `build/build_box3d.sh WebSIMD CACHE`. Existing web Node dependencies
must be available. These commands execute local builds and browsers.

The optional `godot4.7.1-web-dlink-rtc-scratch-v1` profile derives a custom
template from the exact pinned official `web_dlink_release.zip`. It changes
only the binary RTC send bridge in `godot.js`: one 64 KiB buffer per engine
JavaScript module replaces fresh packet backing buffers and byte-at-a-time
copies. Text, oversized, invalid-range and nested sends retain the original
path. Both engine Wasm files and every other template entry stay byte-identical.

```sh
python3 -B build/web_rtc_template.py derive \
  --source "$GODOT_WEB_TEMPLATE" --out "$NEW_TEMPLATE"
python3 -B tests/box3d_web/replay/export.py \
  --out "$NEW_EXPORT" --native-library "$NATIVE_LIBRARY" \
  --web-archive "$WEB_ARCHIVE" --odin "$ODIN" --godot "$GODOT" --emcc "$EMCC" \
  --web-template-record "$NEW_TEMPLATE/template-record.json"
```

Derivation creates a new ZIP and provenance record. Selection happens before
ordinary import/export through Godot's custom-template setting. The helper
verifies the pinned source, transformation and all payloads; it preserves
installed templates and existing outputs. Without the explicit record argument,
the export command uses its existing template settings. Template byte checks
and isolated RTC copy tests are separate from actual game frame qualification.

The pair requires actual nonzero committed controls from both seats, one accepted
boost action and applied outcome per seat, two confirmed boost effects per browser,
signature-checked correction, byte equality of Solver/Game/Side/Observations/
Occurrences, the application's actual terminal signature acknowledgement, measured
SDK cleanup and the real Core shutdown marker. Replay Side is legitimately empty.
Large keys and pointers stay in typed Odin/C values; the final frame crosses the
console as exact base64 bytes with hexadecimal hashes.

This is a functional software-GL check: `render=0` disables 3D drawing while the
same input, physics, copied presentation and network callbacks run. Chrome uses
the existing RTC harness's local-IP discovery flag. It establishes neither a
rendering budget nor default-browser Internet connectivity. The original rendered
software-GL remote-input failure and mDNS connection failures remain retained.
Foreground rendering, Internet/TURN and other browsers have separate roadmap work.

`SAMPLE_NETWORK` reports actual committed action counts, outcomes and cue delivery.
Its latest planned/executed physics repair and live configured limit are separate
from `Stats.replay_max_depth`: that legacy timing field is not populated by the
complete physics path, so its zero is not a maximum-depth measurement. Final-frame
bytes, raw console rows, process arguments and export hashes are retained.

`recovery.py` reuses the small adapter fixture runner for a separate browser test:

```sh
python3 -B tests/box3d_web/replay/recovery.py \
  --out "$NEW_RECOVERY" --native-library "$NATIVE_LIBRARY" \
  --web-archive "$WEB_ARCHIVE" --odin "$ODIN" --godot "$GODOT" --emcc "$EMCC" --execute
```

Its real Core/Meter-owned Server and Client use the public Memory transport.
The receiver consumes and discards actual packets while the authority progresses
beyond H128, then resumes normal delivery. The oracle requires an actual recovery
notice, newer validated Welcome scope/baseline, complete five-part equality,
continued Native work and checked cleanup. Original world/catalog creators are
destroyed before the recovery. This receiver-discard test does not model SCTP,
WebRTC reliable loss or an Internet outage. Without `--execute` it writes a plan.

Current scoped evidence is in [report.json](report.json). Native/web cross-play,
room authorization, rejoin/observer UX and match-length performance are not
qualified by this report.
