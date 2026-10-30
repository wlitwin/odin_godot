# Claimball native save acceptance

```sh
REPLAY_CLAIMBALL_SAVE_OUT=/absolute/fresh/output nix develop --command bash tests/replay_claimball_save/run.sh
```

The runner prepares/builds an isolated Claimball and runs the existing UI/profile
and WASM checks. A named host/client pair scores through real gameplay and uses F5
while the ball moves and the kicker's cooldown is active. It verifies a durable
receipt and preservation of the committed archive when the next staging-file open
is deliberately blocked, then kills those exact two processes.

An independent Odin reader validates the complete archive, names, round/score,
ball motion and cooldown. It also creates valid policy-protected and maximum-epoch
archives for negative resume cases. Other cases cover wrong owner, damaged/missing
files, a configured Room path and exact solo restore, while preserving files and
identity/name profiles.

Fresh host/client processes restore/rejoin, execute new spike commands, finish the
saved match, restart into round two and exchange named chat. A negotiated common
retained tick must have the same canonical world hash on both peers; the guest
must still predict one avatar. The resumed host saves again to the same file. A
second independent decode must verify that this successful replacement contains
the new round and epoch, with original identity/name profiles unchanged.

`execute.py OUTPUT LABEL` runs the save cases against an existing prepared build.
`capture.py OUTPUT LABEL` renders its menu and a solo restore, checking menu bounds
and preserving the selected archive/profile bytes. Both copy/hash their actual
GDScript drivers into the result folder. The initial receipt, restore receipt,
resumed-world comparison and successful replacement are separate observations.

Raw checkpoints contain reconnect identities. Keep their decoded observations and
hashes in published evidence; exclude the raw archives and personal profile files.
