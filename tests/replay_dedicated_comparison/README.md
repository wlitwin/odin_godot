# Dedicated Scrapyard comparison

`build.sh OUTPUT` creates separate old/new projects, preserving the sibling
Scrapyard checkout. `execute.py OUTPUT LABEL` runs a dedicated authority and two
clients in each build; `report.py OUTPUT LABEL` validates the paired receipts.

The scenario follows the original `server` act: clients join and Ready, clear a
six-enemy wave, receive their core, and regroup to advance to floor two without
an authority avatar or a player-host Start command. Both implementations use the
same circle-strafe/autofire and south-lane controller. The original launcher’s
one-wave/no-barrel, 255-magazine/no-jam overrides are retained; both clients
explicitly choose the bolter. Receive delay is 120 ms per process and simulation
runs at 60 Hz. No HP, position, damage, kill or progression state is edited.

The baseline copy uses the existing declared ownership-cleanup overlay. Gameplay
sources and the original launcher are preserved. Prepared file hashes, framework
hashes, binary identities, actual driver, environment and actor traces accompany
results. Original `run.sh` is not executed because it deletes baseline profiles.

This gate proves that the named dedicated-server act works in both implementations.
It does not establish matching movement streams, damage distribution, elapsed
combat times, broader mode parity or a performance advantage. Kit's client player
IDs are 2/3 because its authority identity is reserved; Replay's playable seats
are 1/2. Those IDs also affect authored spawn positions. The comparison records
these boundaries rather than treating one run as full gameplay equivalence.
