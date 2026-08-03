# Regenerate the typed `godot` Odin binding package from extension_api.json.
#
# ALL commands must run inside the project's Nix dev shell, e.g. from the repo root:
#
#     nix develop --command make -C bindgen
#
# or, for an individual target:
#
#     nix develop --command make -C bindgen check
#
# Pipeline (see PATCHES.md for the full story):
#   1. build temple_cli (template transpiler)
#   2. transpile templates/*.temple.twig -> bindgen/templates.odin
#   3. build the bindgen generator
#   4. run bindgen on ../extension_api.json (Godot 4.6.2) -> upstream/godot/*.gen.odin
#   5. copy the generated `godot` package to ../godot
#
# NOTE: the `gdext`/`libgd` runtimes are NOT regenerated — they are owned, hand-edited
# source in the repo top level. The generator only produces the `godot` package, so
# `generate` must NOT copy over ../gdext (doing so clobbered hand fixes like the
# allocator .Resize bug). Edit ../gdext in place.
#
# CONTRACT: `generate` only writes `*.gen.odin` files into ../godot. The hand-written
# files in ../godot (Strings.odin, Variant.odin, Ergonomics*.odin — see HAND_WRITTEN
# below) are the single source of truth, live ONLY in ../godot, and are never copied,
# overwritten, or deleted by any target here. The generator itself emits only
# `*.gen.odin`, and the publish step below copies only `*.gen.odin`.
#
# HAND_WRITTEN (owned in ../godot, NOT touched by regen):
#   Strings.odin Variant.odin Ergonomics.odin Ergonomics_Debug.odin
#   Ergonomics_Gameplay.odin Ergonomics_Input.odin Ergonomics_Multiplayer.odin
#   Ergonomics_Nodes.odin Ergonomics_Project.odin Ergonomics_Properties.odin
#   Ergonomics_Scenes.odin Ergonomics_Signals.odin Ergonomics_WebRtc.odin

UPSTREAM   := upstream
API        := $(abspath ../extension_api.json)
GODOT_OUT  := ../godot
JOBS       := 1

TEMPLE_CLI := $(UPSTREAM)/bin/temple_cli
BINDGEN    := $(UPSTREAM)/bin/bindgen

.PHONY: all generate temple templates bindgen check clean

all: generate

# 1. temple_cli
temple $(TEMPLE_CLI):
	cd $(UPSTREAM) && mkdir -p bin && odin build temple/cli/ -o:speed -out:bin/temple_cli

# 2. templates.odin (package name must be `bindgen`)
# Depends on the .twig sources: without them a template edit is silently ignored
# and `generate` reuses the stale transpiled templates.odin.
TEMPLATE_SRC := $(wildcard $(UPSTREAM)/templates/*.temple.twig)
templates $(UPSTREAM)/bindgen/templates.odin: $(TEMPLE_CLI) $(TEMPLATE_SRC)
	cd $(UPSTREAM) && ./bin/temple_cli bindgen bindgen bindgen

# 3. bindgen generator
# Depend on every hand-written bindgen source (not just templates.odin) so edits
# to the generator logic — e.g. graph/graph.odin — actually relink the binary.
# Without this, a logic-only change is silently ignored and `generate` reuses a
# stale bin/bindgen. templates.odin is listed separately because it is generated
# (and may not exist yet on a clean build) and carries its own recipe.
BINDGEN_SRC := $(filter-out $(UPSTREAM)/bindgen/templates.odin,$(shell find $(UPSTREAM)/bindgen -name '*.odin'))
bindgen $(BINDGEN): $(UPSTREAM)/bindgen/templates.odin $(BINDGEN_SRC)
	cd $(UPSTREAM) && odin build bindgen/ -o:speed -out:bin/bindgen

# 4 + 5. run the generator and publish the package to the repo top level
generate: $(BINDGEN)
	cd $(UPSTREAM) && rm -f godot/*.gen.odin && ./bin/bindgen $(API) -jobs:$(JOBS)
	mkdir -p $(GODOT_OUT)
	rm -f $(GODOT_OUT)/*.gen.odin
	cp $(UPSTREAM)/godot/*.gen.odin $(GODOT_OUT)/
	@echo "Generated $$(ls $(GODOT_OUT)/*.gen.odin | wc -l) files into $(GODOT_OUT)"
	@echo "NOTE: only *.gen.odin published; hand-written godot/*.odin are owned in $(GODOT_OUT)."
	@echo "NOTE: ../gdext and ../libgd are owned runtime (not regenerated/copied)."

# Type-check the published package (collection `godot` = repo root).
check:
	odin check $(GODOT_OUT) -no-entry-point -collection:godot=.. -define:REAL_PRECISION=single

clean:
	rm -f $(UPSTREAM)/bin/temple_cli $(UPSTREAM)/bin/bindgen
	rm -f $(UPSTREAM)/bindgen/templates.odin
	rm -f $(UPSTREAM)/godot/*.gen.odin
