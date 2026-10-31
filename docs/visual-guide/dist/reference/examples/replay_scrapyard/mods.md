# Host-owned JSON mods

Fresh Solo, Host and Server sessions load `user://mods/*.json` in filename order.
`RSY_MODS_DIR` overrides the folder. Room followers and clients never read local
overlays; they receive the authority's complete value catalog. A resumed game keeps
the catalog in its checkpoint. Explicit fixture identities do not implicitly load
user mods unless persistence is enabled or a mod directory is specified.

The reader accepts the original JSON5 authoring vocabulary: `guns`, `mobs`, `status`,
`combos` and `abilities`. Rows replace the entire corresponding entry, so include
all gameplay fields. Combination rows append after existing rules; first-match
precedence is preserved. Later files replace earlier rows. Each file is validated
and committed atomically; malformed or invalid files are reported and skipped.

Example:

```json
{"guns":[{"id":0,"name":"junkcannon","kind":"bolt","cooldown":20,
"dmg":9,"mag":8,"reload_ticks":72,"jam_per_mille":12,"jam_taps":3,
"speed":16,"ttl":40,"sprite_pos":[32,48],"sprite_size":[32,16]}],
"mobs":[{"id":1,"hp":30,"speed":52,"bite":2,"body_r":26,"scale":2.0}]}
```

Gun kinds are bolt/rivet/nade/lance/mend; unknown words retain the original bolt
fallback. Ability families are lob/cone/nova/buff/zone, with the original lob
fallback. Reactions are detonate/transmute/spread, with the original detonate
fallback. The original positive minima and damage/jam clamps are retained where
compatible with the validated catalog. Values outside Replay's existing simulation
bounds are rejected instead of narrowing with integer wraparound.

The current catalog supports 16 gun slots, 8 mob slots, 16 status slots, 16 ability
slots and 32 combination rows. Status/ability slot zero is reserved. Sparse IDs are
supported: empty holes must be completely zero, references to them are rejected,
and the loadout/workshop cycles skip them. Saved preferences for unavailable mod
content fall back to available choices while keeping the rest of the profile.
New mob IDs use the existing default melee behavior; mods change data, not executable
brains or scripts. Existing mob display names remain; additional rows receive a
stable generated name.

Parsing is bounded by 256 KiB/file, 32 files, nesting depth 32 and a 4 MiB temporary
arena per file. Counts, finite numeric values, integer conversion, references and
final catalog validity are checked before commit. Those are declared limits beyond
the original unconstrained dynamic tables. Network payloads contain validated
catalog values, not filesystem paths or JSON that clients execute.

`mod_run.sh` gives only the host an ordered overlay set and gives clients decoy
files they must ignore. It selects sparse gun/ability IDs through the ordinary
buttons, fights with them, compares full worlds, saves, and resumes with no mod
reload. `mod_migration_run.sh` checks the host's altered gun/mob data through planned
and crash combat takeover. Native tests also execute the original chain, doubled
nova and hostile zone data through the ordinary simulation rules.

```sh
RSY_ROLE=host RSY_MODS_DIR=/path/to/mods nix develop --command bash examples/replay_scrapyard/play.sh
nix develop --command bash examples/replay_scrapyard/mod_run.sh
RSY_JITTER=20 RSY_LOSS=1000 RSY_DUPLICATE=1000 nix develop --command bash examples/replay_scrapyard/mod_run.sh
nix develop --command bash examples/replay_scrapyard/mod_migration_run.sh
```

Sparse selection and profile validation introduced game content ID
`0x5253435241503040`. The catalog's logical layout and stock data fingerprint remain
unchanged. Full matched original-act playtests, broader mod-driven network effect
scenarios, schema migration and deployment remain roadmap work.
