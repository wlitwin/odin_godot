Frozen pre-block schema implementation, captured before this optimization. Used
as an independent encode/decode/error-path oracle. Do not update it to mirror
optimized behavior; sha256.json identifies the captured source.

The package declaration alone is renamed to schema_block_reference because Odin
requires globally unique package names. sha256.json describes the captured source;
compiled-sha256.json describes this namespace-only adaptation.
