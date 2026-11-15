# Replay networking

Choose who settles gameplay, what the client predicts, and how processes connect.
Use [the Session starter](godot.md) before configuring a custom runner.

## Choose authority and history together

| Game model | Runtime | Consequence |
| --- | --- | --- |
| Authoritative host or dedicated server | Session with Host/Server/Client/Observer roles | Authority validates inputs and settles results; clients predict within the chosen scope |
| Trusted cooperative engine physics | Owner observation policy and Body2/Body3 adapters | Replay records accepted outputs; it does not rewind Godot's contact solver |
| Deterministic fixed-roster peers | P2P runner and admitted peer setup | Peers must reproduce the same model from the same inputs |

Content identity, schema, tick rate, and policy must match before admission.
Player identity comes from the authenticated connection-to-seat mapping; a
payload naming another player cannot establish ownership.

## Controls and actions

Continuous controls belong to ticks. The selected policy defines how an absent
sample is held or replaced. A discrete action carries sequence identity and a
settled outcome, so retransmission does not repeat the gameplay operation.

Choose action scheduling deliberately. A shot may need its tick deadline, while
an interaction may be admitted at receipt time. Both still need gameplay
validation and ordering. The [runner reference](https://github.com/wlitwin/odin_godot/blob/main/replay/net/README.md)
documents scheduling, action outcomes, prediction groups, and recipient views.

## Correction and recovery

An accepted authority checkpoint replaces the corresponding state and occurrence
batch, then stages the predicted suffix before committing. Older settled state
cannot be rewritten by ordinary correction. Missing history, baseline loss, or
a long outage requires the explicit resync/recovery path.

The confirmation frontier marks settled simulation. Presentation can select a
different display time and must consume occurrence changes separately. Read
[Presentation](presentation.md) before adding speculative effects.

A recipient-filtered public snapshot does not contain everything needed to
become authority. Keep complete private backups restricted to trusted successors.
Use [Party and Room recovery](recovery.md) when authority can change.

## Transports

Native direct sessions use ENet. Browser sessions use WebRTC, with signaling and
relay configuration supplied by the deployment. A native ENet peer cannot
directly connect to a browser RTC peer; mixed-platform sessions need a common
backend and a native RTC extension.

Plain ENet is unencrypted. Session tokens and checksums do not provide transport
confidentiality. Use the authenticated/confidential transport configuration
appropriate to the chosen network and trust model.

## Keep work bounded

Use the runner's packet, queue, ingress/egress, history, and prediction limits.
Measure World size and full replay cost on the deployment hardware. Application
queues, asset exchange, and persistence need their own bounds.

See [Support](support.md) for the supported configurations and
[the Godot package map](https://github.com/wlitwin/odin_godot/blob/main/replay/godot/README.md)
for optional transport, input, scene, storage, and diagnostic imports.
