#!/usr/bin/env bash
# Kit documentation integrity: local links resolve, removed vocabulary stays
# absent, and introductory/gameplay pages keep generated APIs as the normal path.
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
DOCS="$ROOT/docs/kit"
fail() { echo "KITDOCS_FAIL: $1"; exit 1; }

while IFS= read -r doc; do
	while IFS= read -r target; do
		# Ignore external URLs and same-page anchors. Strip an optional title,
		# angle brackets, and the destination anchor before checking the file.
		case "$target" in
			http://*|https://*|mailto:*|\#*) continue ;;
		esac
		target="${target%% \"*}"
		target="${target#<}"
		target="${target%>}"
		file_part="${target%%#*}"
		[[ -z "$file_part" ]] && continue
		[[ -e "$(dirname "$doc")/$file_part" ]] \
			|| fail "broken relative link in ${doc#$ROOT/}: $target"
	done < <(perl -ne 'while (/\[[^]]*\]\(([^)]+)\)/g) { print "$1\n" }' "$doc")
done < <(find "$DOCS" -maxdepth 1 -type f -name '*.md' -print | sort)

if rg -n 'gd_cue|gd_fact|gd:"owner,interp(?:,|"|`)|command_issue_checked|command_execute_reason|command_result_write_reason|registry_host_command_checked|lane_command_checked|Command_Access|\b[a-z][a-z0-9_]*_ids\b' \
	"$DOCS" --glob '*.md'; then
	fail "retired author-surface vocabulary remains in Kit documentation"
fi

# These are the tutorial/gameplay pages where a raw lifecycle operation would
# compete directly with the generated typed door. Reference pages may still
# document the raw layer under an Advanced heading.
if rg -n 'session_(spawn_make|despawn|teleport)\b' \
	"$DOCS/ai.md" "$DOCS/play.md" "$DOCS/build-a-game-in-a-day.md" \
	"$DOCS/quickstart.md" "$DOCS/quickstart-sim.md"; then
	fail "a normal-path Kit guide teaches raw session lifecycle"
fi

if rg -n 'frame\s*:=\s*[a-z][a-z0-9_]*_net_pump|before `<game>_net_pump`' "$DOCS" --glob '*.md'; then
	fail "a normal frame example bypasses generated <game>_net_frame"
fi

for required in \
	'<game>_net_frame' \
	'session_action_receipt' \
	'@(gd_event)' \
	'<type>_all' \
	'<type>_despawn' \
; do
	rg -qF "$required" "$DOCS/index.md" \
		|| fail "Kit index is missing canonical-surface entry: $required"
done

echo "KITDOCS_OK"
