# Asset provenance

All sources are from the existing odin_godot Cavecrawl example and retain the repository license.

| New asset | Original asset | Original SHA-256 | Transformation |
| --- | --- | --- | --- |
| levels/level_1.tscn | examples/cavecrawl/levels/level_1.tscn | `4027fe50068d4ee904638e905a51e57e2f88c3bd8a33556f61770736f5f058d1` | Byte-for-byte copy |
| levels/level_2.tscn | examples/cavecrawl/levels/level_2.tscn | `9215263b0a86537ff4af632183a6c4dcac720f205842f605d8d0803e39234642` | Byte-for-byte copy |
| views/spelunker.tscn | examples/cavecrawl/entities/spelunker.tscn | `82abd28c49cd216038feb113b81f50cfcadca6eb93761b458b58f00a6f4d3b3a` | Original presentation; old Odin script attachment removed |
| views/chest.tscn | examples/cavecrawl/entities/chest.tscn | `9b729c2f479300c232c987dbc69b160408f7e0ca6c6d7e9d96ebe7fa353d6906` | Original presentation; old Odin script attachment removed |
| views/door.tscn | examples/cavecrawl/entities/door.tscn | `8639a2a18e2dbc07133d1bdb802f6b2984905c53221e78df2b4fc73ff463c38e` | Original presentation; old Odin script attachment removed |
| views/pickup.tscn | examples/cavecrawl/entities/pickup.tscn | `fea4d0af90ee8364b094366644b28870d09207cb717c95a17632262502acbde5` | Original presentation; old Odin script attachment removed |
| views/dweller.tscn | examples/cavecrawl/entities/dweller.tscn | `7cae3d38c2d4ef5a8b4b7defc27ec6ed2d556b8261b342a0200b4ff23dd0b8d2` | Original presentation; old Odin script attachment removed |
| views/relic.tscn | examples/cavecrawl/entities/relic.tscn | `62606313fc4a6b98c66b25c55dcc9a948524f0f5bbc0a9c4bc9d560a8dbd2248` | Original presentation; old Odin script attachment removed |


Browser text rendering additionally bundles unmodified Noto Emoji from
[Google Fonts](https://github.com/google/fonts/tree/main/ofl/notoemoji), licensed
under the SIL Open Font License 1.1. The font, license and pinned source commit
are in `fonts/`. It supplies monochrome fallback glyphs for the existing authored
emoji; native system-font rendering is unchanged. This is a declared presentation
difference from a platform's color-emoji font.


The Replay `levels/level_1.tres` and `level_2.tres` carry the original level stocks
and wave plans, with the script changed to `ReplayCaveLevelDef`, stale UID fields
removed, and an explicit rectangular rift proxy added. The source definition hashes
are:

- `examples/cavecrawl/levels/level_1.tres`: `ca2b83f039a2be63ba64ea6eba2b64b77df27d94b9034d98c9cc40436530f7cc`.
- `examples/cavecrawl/levels/level_2.tres`: `0c56803ac455d65d70459bb8d79de185fc13a4451fb314026ef857c2626f7032`.

Seeded scatter ports the integer recipe from `examples/cavecrawl/scripts/world.odin`;
the regression oracle extracts that original procedure and compares all generated
coordinates with Replay on native and WASM. See [authoring.md](authoring.md).
