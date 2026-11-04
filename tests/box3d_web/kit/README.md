# Kit compatibility with the shared Web backend

`run.py` builds a small ordinary SDK project, imports it, exports with the official
Web template and checks it in Chrome. It uses Kit's actual provider, World2 input
sampling and complete checkpoint codec over the same selected Box3D archive as
Replay. It is a local authority fixture with an explicit packet sink, rather than
a second game or a Kit browser networking claim.

```sh
python3 -B tests/box3d_web/kit/run.py \
  --out "$NEW_OUTPUT" --native-library "$NATIVE_LIBRARY" \
  --web-archive "$WEB_ARCHIVE" --odin "$ODIN" --godot "$GODOT" --emcc "$EMCC" --execute
```

Choose absolute paths and a fresh output outside the repository. Without
`--execute`, the command writes a plan and starts no processes.

The case executes sixteen actual input/physics steps, signs five canonical parts,
retains a complete checkpoint across Lane/provider/world/catalog destruction and
compares the owned solver bytes afterward. Typed teardown must restore the actual
owner baseline and leave zero Native/wrapper bytes. The browser independently
requires the result, isolation and actual Core shutdown. Explicit GDScript checks
execute in release exports. Normal engine frames precede the short synchronous
case so the fixture does not quit during asynchronous Web audio initialization.

The runner also stages the independent Replay H128 fixture; each keeps its own
model, provider, assertions and transport scope. No Kit/Replay adapter is replaced.
