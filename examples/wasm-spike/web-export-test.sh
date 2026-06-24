#!/usr/bin/env bash
# Spike W, step 4 — prove Godot 4.6.2's web exporter ACCEPTS an Odin wasm
# SIDE_MODULE as a GDExtension `web.release.wasm32` entry and bundles it using
# the dlink (GDExtension-capable) web runtime template.
#
# Requires: examples/wasm-spike/spike.wasm (run build.sh first) and the 4.6.2
# web export templates already installed at
#   ~/Library/Application Support/Godot/export_templates/4.6.2.stable/
# (web_dlink_release.zip etc — confirmed present on this machine).
#
# Builds a throwaway Godot project in a temp dir and headless-exports it for Web.
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPIKE="$HERE/spike.wasm"
[ -f "$SPIKE" ] || { echo "build spike.wasm first: bash build.sh"; exit 1; }

PROJ="$(mktemp -d)/webexp"
mkdir -p "$PROJ/bin" "$PROJ/out"
cp "$SPIKE" "$PROJ/bin/spike.wasm"

cat > "$PROJ/project.godot" <<EOF
config_version=5
[application]
config/name="WasmSpikeWebExport"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.6")
[headless]
EOF

cat > "$PROJ/main.tscn" <<EOF
[gd_scene format=3 uid="uid://b1spike0000a"]
[node name="Main" type="Node"]
EOF

# GDExtension with web-only entries pointing at the Odin side module.
cat > "$PROJ/spike.gdextension" <<EOF
[configuration]
entry_symbol = "odin_spike_init"
compatibility_minimum = "4.6"
[libraries]
web.debug.wasm32 = "res://bin/spike.wasm"
web.release.wasm32 = "res://bin/spike.wasm"
EOF

# extensions_support=true forces Godot to use the dlink web template.
cat > "$PROJ/export_presets.cfg" <<EOF
[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
export_path="out/index.html"
[preset.0.options]
variant/extensions_support=true
EOF

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJ" --export-release "Web" 2>&1 | tail -6 || true

echo "=== export output ==="
ls -la "$PROJ/out"
echo
echo "PASS if you see: spike.wasm (our Odin module, bundled) AND index.side.wasm (dlink template)."
