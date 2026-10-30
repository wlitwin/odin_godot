# Replay Slopball3D assets

Reused repository-authored scenes. Original files remain intact; no external assets were downloaded.

| Original | Replay | Original SHA-256 | Replay SHA-256 | Changes |
| --- | --- | --- | --- | --- |
| `examples/slopball3d/ball.tscn` | `examples/replay_slopball3d/views/ball.tscn` | `d6ebe50dd4cce2c7fc3bac1864b119b03097b745069be87efb4d98703d0505ef` | `37174da45ca22e78d82073590f5f189f92e308c4ea3e92fe69ca6026ece574af` | Kit script removed; geometry/material/physics properties retained. |
| `examples/slopball3d/kicker.tscn` | `examples/replay_slopball3d/views/kicker.tscn` | `afdb1121ddbc97c24908ddd481849985899634840d107469990231cfe5d82bb7` | `8f34007bd065835111f1c061af6aa62f8d05beb94c3b6b414f920200cd559c06` | Kit script removed; capsule, visual children and collision properties retained. |
| `examples/slopball3d/slopball3d.tscn` | `examples/replay_slopball3d/slopball3d.tscn` | `36f8343d82f61088c85f4396aa73aa1a4349123a41ed79d00a67455fbbbafeae` | `497a7d38f67f9ae08bba20ae674324bad6a0ab02329b39421b6d1cfef32a851f` | Separate Replay root script and session/Party UI; pitch, camera, mesh geometry, materials and collisions retained. |
