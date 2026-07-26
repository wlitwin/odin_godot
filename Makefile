# odin_godot — top-level convenience targets. All real work happens inside the Nix dev
# shell (toolchain: odin, emcc, godot). These targets wrap `nix develop --command`.

.PHONY: test showcase web bindings api-dump help

help:
	@echo "odin_godot targets:"
	@echo "  make test      - run the full headless E2E suite (all phases + showcase + web)"
	@echo "  make showcase  - build + run the pure-Odin coin-collector showcase (headless)"
	@echo "  make web       - build + web-export + (if a browser is present) browser-verify"
	@echo "  make bindings  - regenerate the godot/ binding from extension_api.json"
	@echo "  make api-dump  - dump extension_api.json + gdextension_interface.h from \$$GODOT"

# Full suite. One command, everything green (web is browser-gated — see tests/run_all.sh).
test:
	nix develop --command bash tests/run_all.sh

# Headline deliverable: the playable pure-Odin showcase, headless-verified (SHOWCASE_OK).
showcase:
	nix develop --command bash tests/showcase/run.sh

web:
	nix develop --command bash tests/web/run.sh

bindings:
	nix develop --command make -C bindgen generate

# Regenerate the raw engine inputs in the repo root: extension_api.json +
# gdextension_interface.h. Both are GITIGNORED, so a fresh clone must run this once
# (with a Godot 4.7.1 binary) before `make bindings`. GODOT comes from the dev shell's
# default (macOS app bundle) or the caller's env: `GODOT=/path/to/godot make api-dump`.
api-dump:
	nix develop --command bash -c '"$$GODOT" --headless --dump-extension-api --dump-gdextension-interface'
