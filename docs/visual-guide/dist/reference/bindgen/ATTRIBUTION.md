# Attribution

Portions of this project (the binding generator under `bindgen/`, and the runtime packages
`godot/`, `gdext/`, `libgd/`) originated from **dresswithpockets/odin-godot**
(<https://github.com/dresswithpockets/odin-godot>), licensed under **Apache-2.0**
(see `LICENSE`). Original provenance is recorded in `UPSTREAM.txt`.

**We have adopted this code as our own.** odin_godot diverges substantially (a full
`ScriptLanguageExtension`, native + WASM compilation, our own generator fixes), so we no
longer track upstream or maintain a vendor/patch boundary — these files are edited in place
like any other source in the repo. We retain this NOTICE and the Apache-2.0 `LICENSE` to
comply with the license's attribution requirements; modifications are likewise Apache-2.0.
