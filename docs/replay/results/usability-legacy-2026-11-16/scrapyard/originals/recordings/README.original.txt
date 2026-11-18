# Historical network recording fixtures

These three recordings were captured from Scrapyard on 2026-09-14, before network
batches gained authority observations. They retain the content-48 identity and
the original input schema. The host and client files came from the delayed native
network scenario; the browser file came from an actual exported solo session.

`manifest.json` records the uncompressed byte count, SHA-256, capture date, and
original scenario path. Gzip compression keeps the exact historical bytes while
reducing the checked-in payload from 12.8 MB to 326 KB. These are regression
fixtures; do not replace them with recordings emitted by the current encoder.

`upgrade.sh` expands each file in its output directory. It requires the current
verifier to reject the historical schema, upgrades explicitly, verifies the
result in native and WASM, rejects checksum corruption and forged state/input,
and checks that both source files and existing destinations are preserved.
