#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
"${ODIN:-odin}" test "$ROOT/tests/authoring" -collection:godot="$ROOT" -out:"$work/authoring-tests"
echo AUTHORING_MAPPING_OK
