#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Assemble the `release` branch — the Asset-Library-facing shape of this repo.
#
# The Godot Asset Library serves a zip of a git COMMIT; whatever that commit
# contains is what every user downloads into their project. So releases live on
# an orphan branch whose tree is ONLY the installable addon:
#
#   addons/odin_godot/**      (the nix-built addon: prebuilt core dlls, docs,
#                              build scripts, template, LICENSE, NOTICE)
#   README.md                 (the addon's download-oriented README)
#   LICENSE / NOTICE          (repo-root copies for the GitHub landing page)
#
# Flow:  bump `version` in build/dist.nix  ->  bash build/release.sh --tag
#        ->  push (commands printed at the end)  ->  point the AssetLib entry
#        at the new tag's commit.  See docs/publishing.md for the full runbook.
#
# The script never touches your checkout: the branch is built in a temporary
# `git worktree`, and nothing is pushed.
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TAG=0
[[ "${1:-}" == "--tag" ]] && TAG=1

VERSION="$(sed -nE 's/^ *version = "([^"]+)";/\1/p' build/dist.nix | head -1)"
[[ -n "$VERSION" ]] || { echo "release.sh: couldn't parse version from build/dist.nix" >&2; exit 1; }
MAIN_SHA="$(git rev-parse --short HEAD)"

# The flake builds from the GIT state of the worktree: dirty tracked files are
# included as-is, but UNTRACKED files are INVISIBLE to nix (a recurring gotcha).
# A release must come from a clean, committed tree so the zip is reproducible.
if [[ -n "$(git status --porcelain)" && "${RELEASE_ALLOW_DIRTY:-0}" != "1" ]]; then
    echo "release.sh: the worktree is dirty — commit (or stash) first; a release must" >&2
    echo "            be built from a committed state so the addon matches the tag." >&2
    echo "            (RELEASE_ALLOW_DIRTY=1 overrides, for testing the assembly only.)" >&2
    exit 1
fi

echo "release.sh: building the addon zip (nix build .#release) for v$VERSION ..."
nix build .#release
ZIP="result/odin_godot-$VERSION.zip"
[[ -f "$ZIP" ]] || { echo "release.sh: expected $ZIP after nix build" >&2; exit 1; }

WORK="$(mktemp -d)"
WT="$WORK/release-wt"
trap 'git worktree remove --force "$WT" 2>/dev/null || true; rm -rf "$WORK"' EXIT

if git show-ref --verify --quiet refs/heads/release; then
    git worktree add "$WT" release
else
    git worktree add --detach "$WT"
    git -C "$WT" switch --orphan release
fi

# Replace the branch content wholesale with this version's addon.
git -C "$WT" rm -rfq . 2>/dev/null || true
find "$WT" -mindepth 1 -maxdepth 1 -not -name .git -exec rm -rf {} +
unzip -q "$ZIP" -d "$WT"
chmod -R u+w "$WT/addons" # nix-store zips extract read-only
cp "$WT/addons/odin_godot/README.md" "$WT/README.md"
cp "$WT/addons/odin_godot/LICENSE" "$WT/LICENSE"
cp "$WT/addons/odin_godot/NOTICE" "$WT/NOTICE"

git -C "$WT" add -A
if git -C "$WT" diff --cached --quiet; then
    echo "release.sh: release branch already matches v$VERSION — nothing to commit."
else
    git -C "$WT" commit -q -m "release v$VERSION (from main $MAIN_SHA)"
    echo "release.sh: committed v$VERSION on 'release' ($(git rev-parse --short release))"
fi

if [[ "$TAG" == "1" ]]; then
    git tag -f "v$VERSION" release
    echo "release.sh: tagged v$VERSION"
fi

echo
echo "Next (nothing has been pushed):"
echo "  git push origin main release --tags"
echo "  # then set the Asset Library entry's download commit to:"
git rev-parse release
