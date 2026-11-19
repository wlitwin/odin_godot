#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:?usage: install_browser_lobby.sh GAME_PROJECT}/addons/replay_browser"
mkdir -p "$out"
cp "$root/replay/godot/browser_lobby/menu.gd.in" "$out/menu.gd"
# Reuse the browser-native paste/copy dialog and hidden-tab worker qualified
# by Dockyard. Each exported game owns a copy inside its own resource root.
cp "$root/examples/replay_dockyard/web_text_entry.gd" "$root/examples/replay_dockyard/web_runtime.gd" "$out/"
