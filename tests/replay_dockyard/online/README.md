# Dockyard online checks

The reusable Party/Room path owns one complete-physics Session. Native gameplay
uses ENet; browsers use authenticated RTC signaling. Both use the existing room
service, challenged registration and authority leases. Complete-mode Room retains
the actual initial checkpoint, codec and callback owners and cooperatively closes
its resources. Automatic host takeover and durable publication are disabled.

`run.py --production-ui` runs the **ordinary production export** with real canvas
mouse/keyboard input and safe console observations. There is no test autoload in
that export. It waits for actual storage/menu readiness, hosts, copies an invite
through the real clipboard, rejects a malformed invite, joins a second independent
browser and validates 1,200 confirmed ticks, both input seats, all five state parts,
terminal acknowledgement and typed cleanup/engine shutdown. Input uses a real
focus frame and human typing cadence. Saved screenshots document the 1280×720
widgets. Clipboard contents are restored and never included in reports.

The earlier `prepare.py` fixture adds a source-bound GDScript autoload to a copied
project for narrow public-method/widget checks. **Do not ship that fixture.** It
never writes private simulation fields or fabricates a network message. Both
paths use normal SDK/import/export helpers, one backend domain and original
complete-physics/codecs. `native.py` exercises actual Native menu enrollment and
the complete ENet pair, reusing the standard sample actor/intake and five-part
verification helpers.

The local runner serves immutable export bytes and starts only its owned room
service and optional Coturn. It preserves raw actor logs, export hashes, actual
process arguments, selected ICE candidate types and traffic. A private local TLS
case pins only its supplied fixture certificate in Chrome; it does not alter the
system trust store or qualify public TLS. Forced relay cases do not use the
direct-loopback mDNS discovery override. `--provider` exercises the existing
authenticated expiring credential service with a server-only secret, rather than
shipping relay credentials. Secrets, databases and browser profiles remain in the
private output directory and must not be published.

```sh
nix develop --command python3 -B tests/replay_dockyard/online/run.py \
  --production-ui --export-record /ABS/ordinary-export/report.json \
  --service-record /ABS/prepared-service/report.json \
  --out /ABS/NEW-output --godot /ABS/Godot
```

The service record is produced by `prepare.py` and includes its exact prepared
service and static SQLite archive. Add `--turnserver ABS` to require actual relay
candidates and transferred bytes. Add `--provider` for authenticated issuance.
The paired `--certificate`, `--key` and `--certificate-spki` arguments select the
private local HTTPS/WSS fixture. `--case bad-turn` uses deliberately wrong private
credentials and requires real ICE refusal, no selected pair/GO and checked close.
`--case no-isolation` removes hosting headers and requires explicit startup refusal
before any game instance is admitted. These are expected-refusal proofs, not
successful gameplay results.

`schema_metadata/pool_test.odin` is a pure allocated-memory regression: the actual
authority record, provision bundle, enrollment record and RPC schema types must
coexist under a 4,096-slot allocator, retain their canonical bytes/fingerprints and
release all memory. It reproduces the original slot-exhaustion failure. It is not
a Native engine or SDK runtime test. The general schema suite and exhaustive
allocation-failure checks validate the allocator-backed path-block implementation
separately from the real native/browser room checks.

Local functional results do not qualify Internet reachability, browser rendering
budgets, long recovery or human playability. Public endpoint selection is still
required for actual remote acceptance. The later lifecycle/performance/release
cards remain separate on the [roadmap](../../../docs/design/box3d/web-showcase-roadmap.md).
