# Browser UDP TURN fault gate

This fixture runs the existing Slopball browser party scenario with native Chrome
WebRTC, relay-only ICE, Coturn, and a loopback UDP proxy between each browser and
Coturn's listening socket. It keeps a distinct upstream socket for every browser
UDP source tuple, including the new connections made during migration and rejoin.
Application-level delay/loss/duplication are zero. The shared browser scenario still
checks complete moving backups, exact restored state and solver seeding, continued
kicks and scoring, observer restrictions/rejoin, original host identity/seat rejoin,
retained/new chat, publication by the successor, and a common world hash.

Faults activate after all four browsers have selected relay pairs and play has
started. They remain active during host loss, recovery and new connections. Delay
is `latency_ms + uniform(0, jitter_ms)` per traversed proxy direction; loss and
copy duplication are sampled independently per direction after the loss test.
Both endpoints are relayed: a game datagram normally traverses one `up` and one
`down` direction. Configured percentages are **per traversal**, not measured
end-to-end loss rates. Jitter can reorder datagrams. Seeds determine per-flow PRNG
sequences; OS/browser timing and packet arrival order are not deterministic.

The proxy forwards unchanged encrypted bytes. Its diagnostic classifier recognizes
a [TURN ChannelData header](https://www.rfc-editor.org/rfc/rfc8656.html#section-12.4)
and contained [DTLS 1.0/1.2 application record headers](https://www.rfc-editor.org/rfc/rfc6347.html#section-4.1)
or [DTLS 1.3 ciphertext headers](https://www.rfc-editor.org/rfc/rfc9147.html#section-4.1).
This establishes loss of encrypted DTLS records, beyond STUN allocation or consent
traffic. DTLS 1.3 encrypts the content type, so its classifier deliberately reports
`dtls13_ciphertext`, not application data. It cannot identify individual game
messages, reliable/unreliable channels, SCTP acknowledgments or retransmissions
inside the ciphertext. The
[DTLS encapsulation of SCTP](https://www.rfc-editor.org/rfc/rfc8261.html#section-5)
remains the browser's own implementation. No SCTP behavior is mocked.

## Run

First prepare the normal Slopball native/Web and typed Room service builds using
`tests/replay_slopball_online/run.sh`, or its documented component build scripts.
Use `ODIN_EXPORT_OPT=speed`. Supply a Coturn executable; the existing
`tests/replay_turn/build_coturn.sh` can build pinned source without installation.
For Homebrew dependencies use `COTURN_PREFIX=/opt/homebrew`.

```sh
python3 -m unittest discover -s tests/replay_turn_faults -p test_proxy.py -v
python3 tests/replay_turn_faults/run.py \
  --out /absolute/fresh/output \
  --turnserver /absolute/path/to/turnserver \
  --web /absolute/prepared/web \
  --service /absolute/prepared/service
```

The default profile is 5–10 ms delay, 0.5% loss and 0.2% duplication per direction,
seed 901, crash migration. Choose `--mode planned` for explicit handoff. A transparent
baseline uses `--loss 0 --duplicate 0 --latency-ms 0 --jitter-ms 0`. Set `--godot`
and `CHROME` if their paths differ from the macOS defaults. Run serially with other
TURN fixtures: Coturn's local relay range is 53000–53100. This does not require
system-wide network changes or alter original Kit/game projects.

## Evidence and bounds

`report.py OUTPUT` independently reconciles per-datagram receive/schedule/drop/
forward events with the shutdown counters, requires actual encrypted DTLS
record loss for nonzero-loss runs, and checks native `getStats` relay pairs and
Coturn allocation/channel-bind activity alongside the game receipt. Forward delay
statistics measure time inside the proxy; they are not gameplay latency percentiles.

Each direction has at most 1,024 queued packets / 1 MiB in this runner. The proxy
supports at most 32 source tuples, refuses excess tuples, and never evicts an
existing mapping. Each mapping has two directions; the total bound is therefore
64 MiB of queued payload. A successful gate requires zero cap drops, refused flows
and socket errors. Shutdown explicitly accounts for queued packets it discards.
The runner has a 420-second game deadline and cleans up its process groups. The
JSONL event log is streamed to disk; diagnostic reconstruction uses memory
proportional to this bounded-duration recording.

The output directory is private. Temporary TURN credentials/config are removed
on normal or handled-error exits. Browser profiles, the Room database and raw
console/service logs remain private local diagnostics; do not archive them.
Packet records contain byte counts, timestamps, classifications and hashes, not
payloads. Archive only an explicit reviewed file list. A successful local gate
does not establish public deployment/NAT coverage, burst-loss tolerance, larger
Scrapyard checkpoint behavior, mobile/browser parity or general latency limits.

## Loaded Scrapyard

Use `--game loaded --web /absolute/loaded/build` to run the sustained forty-mob
Scrapyard migration fixture. `--service` is omitted because this build contains
its own isolated coordinator. The loaded report preserves its gameplay,
freshness, memory, recovery and state-equality requirements; six relay observations
cover both peers before faults, before migration and after recovery. See the
[loaded fixture](../replay_loaded_migration/README.md) for build and report commands.
