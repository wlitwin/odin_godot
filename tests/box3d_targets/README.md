# Prospective target evaluation

This is an evaluation, not a browser or mobile platform port. See the
[decision and remaining proof](../../docs/design/box3d/web-mobile-evaluation.md)
and [bound observations](report.json). Existing desktop results retain their own
scope.

`public_abi_probe.c` emits compiler constants for the **public C headers only**.
It links no Box3D implementation, calls no Native function and produces no solver
or snapshot measurement. Its LLVM output distinguishes pointer widths from fixed
handle widths; matching constants do not establish foreign-call compatibility.
For example, with an explicitly selected installed compiler and a new output:

```sh
emcc -std=c17 -fno-fast-math -ffp-contract=off -Ibox3d/native \
  -S -emit-llvm tests/box3d_targets/public_abi_probe.c -o "$NEW_OUT/wasm32.ll"
clang -target aarch64-linux-android -ffreestanding -std=c17 \
  -fno-fast-math -ffp-contract=off -Ibox3d/native -S -emit-llvm \
  tests/box3d_targets/public_abi_probe.c -o "$NEW_OUT/android-arm64.ll"
```

The Android command is a freestanding C frontend check, not an NDK build. The
actual Odin Android authoring check stopped with `ODIN_ANDROID_NDK not set`.
The iOS check used the explicitly selected Apple developer directory and actual
iPhoneOS18.2 SDK; the Nix development shell's failed SDK lookup remains recorded
separately. Exact compiler paths, flags, commands, exits, source hashes and logs
are in the observation reports. No target backend was linked or deployed.

The existing native-free protocol check is reproducible with:

```sh
nix develop --command bash tests/box3d_protocol/run.sh "$NEW_PROTOCOL_OUT" All
```

It executes an import-free WebAssembly utility and compares synthetic signature,
Trace and descriptor bytes against native/Python vectors. Its 480/1325/32-byte
outputs are not physics snapshot sizes. A successful frontend check or vector
comparison cannot substitute for actual Native full-state roundtrip, source-free
continuation, owner cleanup, both adapters' exported recovery or per-target
snapshot cost/determinism results. Those measurements remain unavailable here.
