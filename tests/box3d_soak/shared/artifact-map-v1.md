# Analyzer artifact map v1

Pass `audit/analyze.py records.jsonl --out NEW --artifact-map MAP.json
--source-root REPO`. Functional-only parsing can omit a map, but that is explicit
unverified provenance and never CPU acceptance. No timings are launched here.

MAP.json (paths may be absolute):

```json
{
  "source_manifest":"/artifact/source-manifest.json",
  "core_binary":"/artifact/project/bin/libodin_godot.dylib",
  "script_binary":"/artifact/project/bin/libodinscripts.dylib",
  "native_binary":"/artifact/project/bin/libogb3.dylib",
  "compiled_build_record":"/artifact/compiled-build.json",
  "runtime_observations":"/artifact/runtime-observations.json"
}
```

The source manifest is the actual path->SHA256 map whose BYTES hash is in META.
Every boundary source_ref must match that manifest and the supplied source root.
Binary files are hashed and must match META. Loaded-image/controller observations
are needed;64hex caller labels alone do not pass.

`compiled-build.json` requires `exit_code:0`, `source_fence_unchanged:true`,
`source_manifest_sha256`, `core_binary_sha256`, `script_binary_sha256`, and
`native_binary_sha256`, all matching META/current artifact files. Include exact
argv/flags and separate Odin/Native configurations as further provenance.
The first measured baseline is BOTH Core/scripts `-o:speed -debug`, existing
single-module/check/FP flags preserved, verified Native Release. Label e.g.
`Odin speed+debug / Native Release`; old ordinary functional builds are historical.

`runtime-observations.json` requires `execution` matching META's observed mode,
ownership, linkage, transport and actual image count, plus `identity` matching
OS/arch/configuration/Godot/actual native build+target digests, and
`image_census_observed:true`. Retain actual PID/image paths/cookie/contract and
controller observations too. A boolean label is not a replacement for source
and raw census evidence; Root audits that producer/controller code.

No cross-clock or physical-unmapping claim is inferred from these records.
The analyzer binds artifacts/records and reports their hashes; actual measured
boundary semantics and observation authenticity still require source review.
