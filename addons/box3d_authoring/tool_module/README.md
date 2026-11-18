The editor setup panel installs and tracks `tools.odin` as
`res://modules/box3d_authoring_tools/tools.odin`, then run the project's ordinary
Core/scripts generator/build. Core discovers script modules under `res://modules/`;
the source template is hidden from Godot scanning by `.gdignore`. Do not copy
that marker to the installed module. Editor setup uses Core's ordinary build
coordinator; it never invokes a separate compiler process.

Create a Node and attach the installed tools.odin OdinScript. It is a `//gd:tool`
AuthoringTools script, so the editor gets a real callable instance. Destroy the
Node when disabling the plugin. The module has no cache, callbacks, retained
Resource/Node/bake or native world, and no process/physics callback.

The `source_hash()` method returns the SHA-256 of the source compiled into the
loaded tool module, so stale builds cannot be mistaken for ready tools.

Methods returning an owned Godot JSON String:

- `inspect_definition_json(definition_json)` validates/bakes once and returns
  metadata plus bounded SHAPE-only authored preview lines `{a,b,color}`. It has
  no frame/stamp; character/joint editor anchors are separate authored overlays.
- `validate_definition_json(definition_json)` performs strict validation without
  generating preview geometry.
- `preview_shapes_json(request_json)` produces bounded partial editor previews;
  this output is not a bake artifact.
- `bake_definition_json(definition_json, source_uri, source_revision)` returns
  metadata and `artifact_base64`. Decode with Godot's existing Marshalls to save
  binary artifact bytes. An unavailable revision is the empty string, not a guess.
- `inspect_artifact_base64(artifact_base64)` checks canonical base64, exact
  envelope lengths/versions/hashes and rebakes through the one shared baker.

Top-level result: `version`, `ok`, `diagnostic`, `metadata`, `artifact_base64`,
`preview`. All durable u64 IDs are 16-character lowercase hex strings; catalog
IDs are 8-character hex. Never convert them through a Godot float. Hashes are
64-character lowercase SHA256. `metadata.counts` reports the six array counts.
Preview failure is explicit (`available=false`, `error`, `required`), never
silently drawn as a partial success. These hashes detect corruption/identity;
they do not authenticate an untrusted publisher.
