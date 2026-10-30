# Method value ownership acceptance

Run `nix develop --command bash tests/method_values/run.sh` for native Godot or
`nix develop --command bash tests/method_values/web_run.sh` for native plus real
Chrome/WASM execution. The browser gate requires the existing `tests/web` Puppeteer
installation and Godot web export templates. Missing dependencies fail the gate.

The fixture verifies both old and explicit contracts:

- A borrowed Array return remains alive through its instance-owned reference.
- A legacy owning argument can still be released by its callee.
- `owned_return` frees temporary Array/Dictionary/Callable references and directly
  returned RefCounted resources after the GDScript result is dropped.
- `borrowed_args` releases argument copies; an accessor that retains an explicit
  copy keeps its resource alive until replaced.
- The same ownership options apply to a public method and its property accessor.
- Empty, Unicode and large Odin strings round-trip through methods. A native
  string getter marshals into a `gd.String` property's Variant correctly.
- Repeated String/packed-array returns retain bounded engine memory. Resource
  lifetime checks use actual ObjectDB IDs, not only WeakRef resurrection.

Godot's native static-memory counter demonstrates the String regression. The
release browser template may return zero from that counter, so the browser gate
is execution/lifetime/UTF-8 evidence, not a browser memory measurement.

Logs are retained at the printed location (override `METHOD_VALUES_LOGS`). See
[the authoring contract](../../docs/authoring-guide.md#method-value-ownership).
