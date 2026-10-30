# Replay Slopball asset provenance

Reused repository-authored scene geometry from the original Slopball. Original files remain unchanged; no external asset downloads.

| Original | Replay copy | Original SHA-256 | Replay SHA-256 | Changes |
| --- | --- | --- | --- | --- |
| `examples/slopball/ball.tscn` | `examples/replay_slopball/views/ball.tscn` | `6a7682458715a06eb13e41ef51e06d9f9a4b3afcffa7fc1a0155f5b7e09ff245` | `b014dbe09e4068aa643139ff8c084ac4e5b4cad37cb6e8dea4a8e3a050461357` | Removed the Kit script; physics material, shape and layers retained. Skin and dot use immutable meshes with the same vertices, triangles and tint. |
| `examples/slopball/kicker.tscn` | `examples/replay_slopball/views/kicker.tscn` | `35681fb09d8deb0d4b79510d86e9e159a18c3f066e9810df45b837d784a38596` | `3815a38507be26d76d2d310c4c4b1679c63982862bc86964bead020a427ee697` | Removed the Kit script; body, collision and children retained. Skin uses an immutable mesh with the same vertices, triangles and tint. |
| `examples/slopball/slopball.tscn` | `examples/replay_slopball/slopball.tscn` | `68493147e68f40cd47588b0176865d94b6ed1eb469fc3b3158bba284a93118ab` | `74f13396f0391a4b63692782bf6044f09ef2af7645d3ba3bb75e5b81864ae09b` | Separate Replay root script and session/Party UI. Pitch geometry, walls and collision retained; static polygons use immutable meshes. |

Mesh resources under `meshes/` are serialized from these repository-authored
polygons. `tests/replay_slopball_online/convert_views.gd` reproduces the conversion
and checks saved vertex/index readback. No external assets were downloaded.
