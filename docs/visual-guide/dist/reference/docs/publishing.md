# Publishing to the Godot Asset Library

Use this procedure to publish `odin_godot` to the Godot Asset Library or submit
an update. The library downloads a zip of a git commit from the public
GitHub/GitLab repository.

`build/release.sh` assembles an orphan `release` branch from the Nix-built zip.
Its tree contains the installable addon (`addons/odin_godot/**`) plus
README/LICENSE/NOTICE, keeping development files out of the installation dialog.

## One-time setup

1. Configure and push the public GitHub repository if it is not set up yet:

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
   submit the asset (form fields below). First-time submissions are human-reviewed, and the
   process typically takes days to a couple of weeks.

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
| Godot version | `4.7` |
| Asset version | match `version` in `build/dist.nix` (e.g. `0.1.0`) |

Suggested asset description:

> Attach compiled .odin scripts to Godot nodes through ScriptLanguageExtension.
> Scripts support lifecycle procedures, @exports, signals, methods, RPCs, and
> hot reload. The addon includes prebuilt core libraries for macOS, Windows,
> and Linux, an editor build pipeline that reloads after compilation, native
> and HTML5/WASM export, typed engine API access, and a starter template.
> Install the Odin compiler release named in the bundled README. macOS has
> been fully verified; Windows/Linux support is early, and reports are welcome.

## Releasing an update

```sh
# 1. bump `version` in build/dist.nix, commit everything
# 2.
bash build/release.sh --tag
git push origin main release --tags
# 3. Asset Library -> your asset -> "Edit" -> bump version + new download commit.
#    Updates to an accepted asset are reviewed much faster than first submissions.
```

## Consumer-facing notes

- **Browser downloads can trigger macOS quarantine.** In-editor AssetLib
  installs avoid this issue. A browser download can mark prebuilt dylibs with
  `com.apple.quarantine`, causing Gatekeeper to refuse loading them into the
  notarized Godot editor. Users can remove that attribute with
  `xattr -dr com.apple.quarantine addons/odin_godot`. Signing and notarizing
  the dylibs would address distribution directly.
- **`godot --import` exit code**: with any GDExtension, headless `--import` can crash *at
  exit, after a successful import* (an engine bug; see the known-quirk note in
  [distribution.md](distribution.md)). If a user's CI gates on it, point them at that note.
- The addon README names the **tested Odin compiler release**, but compatible releases are
  admitted by the pre-boot core↔scripts ABI fingerprint rather than exact version-string
  lockstep. Recommend the tested release when helping users, especially before Odin 1.0.
