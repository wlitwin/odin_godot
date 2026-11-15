# Release archive consumer check

Run this against the actual release ZIP, inside the development shell:

```sh
python3 tests/addon_distribution/run.py \
  --archive result/odin_godot-0.4.0.zip --out /tmp/odin-addon-consumer \
  --godot "$GODOT" --web-build
```

The output directory must be new. The check installs the archive outside the
checkout, executes the packaged Python helpers, compiles a native-free
Kit/Replay/capacity consumer, builds the bundled Hello starter using the packaged
SDK, and runs it against the prebuilt core in Godot. `--web-build` also links the
packaged core and starter into a WebAssembly side module. It retains logs and a
report; the web build is separate from browser runtime validation.

Box3D backends and the current Replay Session starter require the source-checkout
setup documented in the archive. This check does not substitute a backend or
claim their native adapter is self-contained in the downloaded addon.
