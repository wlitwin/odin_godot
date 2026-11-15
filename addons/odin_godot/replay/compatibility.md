# Replay compatibility policy

Replay is experimental. Pin the repository revision and toolchain used to build
all participants. Source API/ABI stability and arbitrary old-save compatibility
are not promised. A version check refusing a peer/file is expected behavior, not
permission to remove the check or guess a conversion.

## Independent identities

| Identity | What changes it | Rule |
| --- | --- | --- |
| Application content/policy ID | Gameplay semantics, immutable assets, scheduling, ownership/authority policy or projection meaning | The application increments it and supplies explicit conversion when appropriate. Code addresses are not a gameplay version. |
| Schema fingerprint | Canonical logical fields, types, unions, variants, policy-defined representations | Normal decode requires an exact schema. Native struct padding is not wire data. |
| Protocol version | Incompatible packet/handshake semantics | Peers negotiate/validate it. Optional compatible encodings use declared feature bits and fallback paths. |
| Archive format version | Layout/meaning of stored sections | A loader validates it before installing state. Conversion is a separate operation. |
| Authority epoch | A newly authorized authority tenure | Only the authority policy/coordinator grants it. Incrementing a counter does not establish leadership. |
| Process incarnation / connection generation | A new registered process / physical connection | Retires previous bindings and queued traffic. Neither replaces content or protocol identity. |

An invitation identifies enrollment scope, not a simulation checkpoint. A player
profile credential, authoritative checkpoint, participant P2P archive, public
snapshot and diagnostic recording are distinct objects with different disclosure
and restore rules.

## Current format map

These are source constants, not a single library release number:

| Format or protocol | Current constant |
| --- | --- |
| Canonical RPLY envelope | `schema.FORMAT_VERSION = 1`, 52-byte header |
| Authority gameplay protocol | `net.PROTOCOL_VERSION = 7` |
| Complete authority checkpoint | `net.CHECKPOINT_VERSION = 4` |
| Durable authority record / control RPC | `authority.VERSION = 3` / `RPC_VERSION = 2` |
| Enrollment bundle / create-join protocol / client journal | `provision.VERSION = 1` / `PROTOCOL = 1` / `ENROLLMENT_VERSION = 1` |
| Deterministic P2P input protocol | `p2p.VERSION = 2` |
| P2P participant archive / spectator stream | `ARCHIVE_VERSION = 1` / `WATCH_VERSION = 1` |
| Fixed-roster provisioning / pair-key RPC / native link | `VERSION = 1` / `PAIR_VERSION = 1` / link `VERSION = 1` |
| Local diagnostic recording | `diagnostic.RECORDING_VERSION = 1` |

Matching version numbers alone are insufficient. Content, schema, model policy,
seat counts, timing and scope checks still apply. The shared envelope checksum
detects corruption; it does not authenticate the sender. TLS, authenticated control
or the admitted gameplay transport supplies the applicable identity protection.

## Saves and migrations

1. Preserve the original bytes and inspect/decode them under their source contract.
2. Choose a named converter for the exact source version/model. Validate input and
   produce a separate owned candidate; do not rewrite the original on failure.
3. Verify the converted frame/ledger and every referenced immutable asset before
   publishing it. A field rename or schema match does not prove semantic parity.
4. Restore only after the relevant identity, lease, history and policy checks.
   Conversion itself grants no authority and does not advance an epoch.

`checkpoint_upgrade_v6` bridges compatible protocol-6/layout-4 authority archives
to protocol 7. State, policy, control/action/event and game-content changes require
the applicable explicit conversion callbacks/types. The game-specific converters
in the ports demonstrate that workflow; they are not universal loaders. See
[checkpoint conversion](net/checkpoint_upgrade.md).

Recordings retain the model decisions needed to reproduce their historical run.
Changing gameplay events can require executing the old model, even when a world
can be converted to a new save. A replay divergence must not be hidden by swapping
the recorded expected outcome. P2P return also needs compatible retained input and
checksum history; a frame-only save cannot supply missing protocol history.

## Upgrade and support workflow

Run `tests/replay_framework/run.sh` after a library/toolchain update. Then run the
focused real-process gate for the transport/recovery profile your game uses.
Core smoke success is not public-network, all-platform or game-parity acceptance.

The pinned Odin dev-2026-04 arm64 optimizer has a reproduced fixture-factory
miscompile, retained in the [framework audit](../docs/replay/results/framework-audit-2026-09-20/README.md).
The test factory uses a narrow no-inline workaround; normal runner APIs remain
unchanged. Reevaluate that workaround when changing toolchains, while retaining
default/optimized native/WASM comparisons.

List API/format changes and available converters with each future library release.
Keep supported platform/backend combinations and unverified integrations explicit.
Do not treat a successful local test as a blanket compatibility or security claim.
