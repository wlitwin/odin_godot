# Scrapyard in the browser

The separate Replay project exports to Godot Web and uses authenticated raw
WebRTC data channels for gameplay. Room's WebSocket control connection handles
authority leases and rendezvous. The value simulation, asset cache, action
admission, checkpoint barrier and migration reducer are shared with native play.

Run the local acceptance gate from the repository root:

```sh
nix develop --command bash examples/replay_scrapyard/web_run.sh
```

It requires the Godot web export template, Chrome, and the same `puppeteer-core`
installation used by `tests/web`. Missing prerequisites and failed assertions
fail the gate. `RSB_LOGS=/absolute/path` retains results at a chosen location;
otherwise the script prints its temporary directory. `RSB_MODES=planned` or
`RSB_MODES=crash` selects one scenario. `REPLAY_PREBUILT=1` reuses native libraries
and the initial WASM build; the export plugin still builds its release module.

The gate starts a local SQLite authority service and three independent Chrome
processes. It exercises staging, ability selection, readiness, arena entry,
an actual file-input PNG upload, and spray placement. The selected successor's
asset consumer pauses deliberately: a checkpoint referencing an unavailable PNG
must remain unprepared. After the image arrives and preparation succeeds, the
host creates an active zone and a lobbed attack. Handoff or process death then
tests exact checkpoint restoration and new combat on the successor.

Before the fault, every peer must be ready in epoch 1 with zero resyncs and zero
fragment rejection; each follower must have received exactly one full bootstrap
snapshot. After recovery, survivors must retain their seats, display the same
44,459-byte image by SHA-256, and observe continued casts, landings and reactions.
At least ten shared authoritative ticks must have identical canonical whole-world
hashes. The collector retains at most 1,024 hashes per browser for 20 seconds;
it never hashes predicted state as authoritative truth. Screenshots, raw logs,
startup counters, hash maps, driver events and `summary.json` remain available.

Normal browser play now persists its identity, confirmed loadout and upgrades
through [IndexedDB profiles](profiles.md). Run `web_profile_run.sh` for the killed-
browser reload, conflict and corruption gate. This is separate from full run saves.

`web_save_run.sh` tests [complete solo run saves](saves.md) and persistent sprays:
two uploads, active combat, a killed browser, exact resume, continued gameplay,
conflicts and invalid-save preservation. F5 waits for a commit receipt. Resume
retains the bundled image even if the separately saved preference changed.

The spray picker uses a browser file input, validates the size before copying
bytes into Godot, and then runs the ordinary PNG validation/cache/admission path.
With persistence enabled it stores the upload after validation and waits for the
commit before adopting it. Native environment options
have lowercase query equivalents (`RSY_NAME` becomes `name`, for example).
Coordinated browser play additionally needs `coord_url`, `coord_key`, `member`,
`incarnation` and the provisioned game token. The gate supplies public fixture
credentials; it is not an account or credential provisioning service.

Current evidence is local Chrome on arm64 macOS with 120 ms receive delay per
participant, direct local ICE and two peers per authority. The driver measures
fault-to-continued-combat separately from Room's narrower recovery timer. These
are individual scenario measurements, not latency percentiles. Public TLS,
STUN/TURN reachability, other browser engines, broader storage/recovery cases,
Steam and the full Scrapyard parity matrix remain roadmap work.

The direct browser Room/coordinator path also reads the shared `replayIceConfig`
before opening RTC, using the same validated ICE configuration as the Party path.
Invalid configuration rejects the session. This permits relay-only direct test
sessions and carries the selected configuration into recovery connections.
