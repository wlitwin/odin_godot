# Publishing to the Godot Asset Library

The Asset Library serves a **zip of a git commit** from a public GitHub/GitLab repo. Our
releases live on an orphan `release` branch whose tree is only the installable addon
(`addons/odin_godot/**` + README/LICENSE/NOTICE), so a user's install dialog shows exactly
the addon — not the dev tree. `build/release.sh` assembles that branch from the nix-built
zip; this page is the end-to-end runbook.

## One-time setup

1. Create the public GitHub repo and push (already done):

   ```sh
   git remote add origin git@github.com:wlitwin/odin_godot.git
   git push -u origin main
   ```

2. Cut the first release branch + tag and push it:

   ```sh
   bash build/release.sh --tag     # builds nix .#release, assembles the 'release' branch
   git push origin release --tags
   ```

3. Make an account at <https://godotengine.org/asset-library/> (GitHub login works) and
   submit the asset (form fields below). First-time submissions are human-reviewed —
   typically days to a couple of weeks.

## The submission form

| Field | Value |
|---|---|
| Asset name | `odin_godot — Odin as a scripting language` |
| Category | `Scripts` |
| License | `Apache-2.0` |
| Repository host | `GitHub` |
| Repository URL | `https://github.com/wlitwin/odin_godot` |
| Issues URL | `https://github.com/wlitwin/odin_godot/issues` |
| Download commit | the `release`-branch commit for the tag (printed by `release.sh`) |
| Icon URL | `https://raw.githubusercontent.com/wlitwin/odin_godot/release/addons/odin_godot/icon.svg` |
| Godot version | `4.6` |
| Asset version | match `version` in `build/dist.nix` (e.g. `0.1.0`) |

Suggested description (edit to taste):

> Write Godot scripts in Odin. A full ScriptLanguageExtension: attach a .odin file to any
> node and its lifecycle, @exports, signals, methods, RPCs and hot reload work like
> GDScript — but compiled, AOT-native code. Ships prebuilt core libraries (macOS / Windows /
> Linux), an in-editor build pipeline (save-to-reload), native + HTML5/WASM export, typed
> access to the whole engine API, and a starter template. Requires the Odin compiler (the
> bundled README names the exact pinned release). macOS is fully verified; Windows/Linux
> are early — reports welcome.

## Releasing an update

```sh
# 1. bump `version` in build/dist.nix, commit everything
# 2.
bash build/release.sh --tag
git push origin main release --tags
# 3. Asset Library -> your asset -> "Edit" -> bump version + new download commit.
#    Updates to an accepted asset are reviewed much faster than first submissions.
```

## Consumer-facing quirks to remember

- **In-editor AssetLib installs are clean on macOS.** But a user who downloads the zip in a
  *browser* gets `com.apple.quarantine` on the prebuilt dylibs, and Gatekeeper will refuse
  to load them into the (notarized) Godot editor. Workaround for those users:
  `xattr -dr com.apple.quarantine addons/odin_godot`. (Long-term: codesign/notarize the
  dylibs.)
- **`godot --import` exit code**: with any GDExtension, headless `--import` can crash *at
  exit, after a successful import* (engine bug — see the known-quirk note in
  [distribution.md](distribution.md)). If a user's CI gates on it, point them at that note.
- The addon's prebuilt core pins the consumer's **Odin compiler release** (the core↔scripts
  ABI handshake); the addon README states the exact version. Expect "which Odin do I
  install" to be the most common first question.
