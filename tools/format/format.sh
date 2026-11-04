#!/usr/bin/env bash
# tools/format/format.sh — format the repo's hand-written Odin code.
#
#   make format                                  # whole repo
#   nix develop --command bash tools/format/format.sh [--check] [PATH...]
#
# PATHs (files or directories) limit the run; with none, the whole repo is formatted.
# --check writes nothing: it lists the files that would change and exits 1 if any would.
#
# Style comes from odinfmt.json: the nearest one above each file wins, as in the editor.
# Every file goes through three steps on a scratch copy:
#   1. prep split   each statement on its own line: non-empty one-line blocks are opened,
#                   `do` bodies become braced blocks, `;`-joined statements are split, and
#                   a blank line sets off each if/for/switch/when/block and each procedure
#                   or type declaration from its neighbours.
#                   (odinfmt keeps single-line blocks as written, so it can't do this.)
#   2. odinfmt -w   indentation, spacing, wrapping (twice: one pass doesn't always settle).
#   3. prep verify  the result must have the original's tokens, comments and AST shape.
# Only verified files are copied back; a file that fails is left as it was and reported.
#
# Skipped: *.gen.odin (generated: the godot/ bindings and scriptgen's build output),
# docs/visual-guide/dist/ (source snapshots — docs/visual-guide/prepare.mjs regenerates
# them) and bindgen/upstream/ (vendored). Untracked files are included unless gitignored.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ODIN="${ODIN:-odin}"
ODINFMT="${ODINFMT:-odinfmt}"

check=0
paths=()
for arg in "$@"; do
    case "$arg" in
        --check) check=1 ;;
        -h|--help) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
        -*) echo "format.sh: unknown flag $arg (see --help)" >&2; exit 2 ;;
        *) paths+=("$arg") ;;
    esac
done

for tool in "$ODIN" "$ODINFMT"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "format.sh: '$tool' not found — run inside the dev shell: nix develop --command bash $0" >&2
        exit 2
    fi
done

# The helper binary is cached outside the repo and rebuilt when its source changes.
cache="${TMPDIR:-/tmp}/odin_godot-format-${UID:-user}"
prep="$cache/prep"
if [[ ! -x "$prep" || "$ROOT/tools/format/prep.odin" -nt "$prep" ]]; then
    mkdir -p "$cache"
    "$ODIN" build "$ROOT/tools/format" -out:"$prep" >&2
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/odin_godot-format.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# Repo-relative paths of the files to format. Explicit PATHs resolve against the caller's
# directory; --full-name makes git print them relative to the repo root either way.
if [[ ${#paths[@]} -eq 0 ]]; then
    (cd "$ROOT" && git ls-files -co --exclude-standard --full-name -- '*.odin')
else
    git ls-files -co --exclude-standard --full-name -- "${paths[@]}"
fi | grep '\.odin$' | grep -v -e '\.gen\.odin$' -e '^bindgen/upstream/' -e '^docs/visual-guide/dist/' | sort -u |
    while IFS= read -r rel; do
        if [[ -f "$ROOT/$rel" ]]; then # -c also lists files deleted from the working tree
            echo "$rel"
        fi
    done > "$work/files" || true

total=$(wc -l < "$work/files" | tr -d ' ')
if [[ "$total" -eq 0 ]]; then
    echo "format.sh: no Odin files to format" >&2
    exit 0
fi

# Mirror the files, plus every odinfmt.json so odinfmt's upward config lookup still works.
(cd "$ROOT" && git ls-files -co --exclude-standard -- 'odinfmt.json' '*/odinfmt.json') > "$work/configs"
mkdir -p "$work/tree"
cat "$work/files" "$work/configs" | (cd "$ROOT" && tar -cf - -T -) | (cd "$work/tree" && tar -xf -)

sed "s|^|$work/tree/|" "$work/files" > "$work/copies"
paste "$work/files" "$work/copies" | sed "s|^|$ROOT/|" > "$work/pairs"

# Each step prints PATH<TAB>REASON for the files it rejects.
"$prep" split "$work/copies" > "$work/split.out" || true
# odinfmt twice: a first pass that expands a struct with a trailing comment leaves the
# comment misaligned, and only a second pass settles it.
jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
for _ in 1 2; do
    tr '\n' '\0' < "$work/copies" |
        xargs -0 -n 1 -P "$jobs" sh -c '"$0" -w "$1" > /dev/null 2>&1 || printf "%s\todinfmt failed\n" "$1"' "$ODINFMT" \
        >> "$work/odinfmt.out" || true
done
"$prep" verify "$work/pairs" > "$work/verify.out" || true

# One reason per rejected file, repo-relative; the first step to object names it.
cat "$work/verify.out" "$work/split.out" "$work/odinfmt.out" | sed "s|^$ROOT/||; s|^$work/tree/||" |
    awk -F'\t' '!seen[$1]++' > "$work/rejected"
cut -f1 "$work/rejected" > "$work/rejected.paths"

changed=()
while IFS= read -r rel; do
    if cmp -s "$ROOT/$rel" "$work/tree/$rel"; then
        continue
    fi
    if grep -qxF "$rel" "$work/rejected.paths"; then
        continue
    fi
    changed+=("$rel")
    if [[ $check -eq 0 ]]; then
        cat "$work/tree/$rel" > "$ROOT/$rel" # keeps the original's permissions
    fi
done < "$work/files"

if [[ -s "$work/rejected" ]]; then
    echo "left as they were:"
    awk -F'\t' '{print "  " $1 ": " $2}' "$work/rejected"
fi

n=${#changed[@]}
if [[ $check -eq 1 ]]; then
    for rel in ${changed[@]+"${changed[@]}"}; do
        echo "would format: $rel"
    done
    echo "$n of $total files would change"
    [[ $n -eq 0 ]]
else
    echo "formatted $n of $total files"
fi
