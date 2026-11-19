# Reproducible drop-in addon for odin_godot. Produced by `nix build` (see flake.nix).
#
# Output: $out/addons/odin_godot/ — copy that folder into a Godot project.
#
# Builds the CORE dll for macOS natively with the nixpkgs `odin`. If `crossLinuxCC` /
# `crossWindowsCC` (gcc cross wrappers) are passed (the `dist-cross` package), it ALSO
# emits the Linux `.so` / Windows `.dll` core via build/build_cross.sh in CORE_ONLY mode.
# Everything a consumer needs to compile ITS OWN scripts dll (the `godot:` Odin
# collection, scriptgen, the build scripts) is bundled alongside the prebuilt cores.
{ lib
, stdenvNoCC
, odin
, src
, crossLinuxCC ? null
, crossWindowsCC ? null
, crossWindowsLibdirs ? null   # mcfgthreads/lib — needed to self-contain the Windows DLL
}:

let
  isDarwin = stdenvNoCC.hostPlatform.isDarwin;
  # Where the NATIVE core dll lands (the cross cores pick their own dirs below).
  nativePlatformDir = if isDarwin then "macos" else "linux";
  nativeDllExt      = if isDarwin then "dylib" else "so";
in
stdenvNoCC.mkDerivation ({
  pname = "odin_godot-addon";
  version = "0.4.0";
  inherit src;

  nativeBuildInputs = [ odin ]
    ++ lib.optional (crossLinuxCC != null) crossLinuxCC
    ++ lib.optional (crossWindowsCC != null) crossWindowsCC;

  buildPhase = ''
    runHook preBuild
    export ODIN_GODOT_ROOT=$PWD
    ${lib.optionalString isDarwin ''
      # darwin-only impurity — see the __noChroot / NIX_ENFORCE_PURITY note below.
      export NIX_ENFORCE_PURITY=0
      export PATH=$PATH:/usr/bin:/usr/sbin:/bin   # host xcrun/ld for the macOS link
    ''}

    echo "dist: building native core dll"
    mkdir -p out/bin/${nativePlatformDir}
    odin build core \
      -collection:godot=$PWD \
      -build-mode:dll \
      -out:out/bin/${nativePlatformDir}/libodin_godot.${nativeDllExt}

    ${lib.optionalString (crossLinuxCC != null) ''
      echo "dist: cross-building Linux core .so"
      ODIN_CROSS_LINUX_CC=${crossLinuxCC}/bin/x86_64-unknown-linux-gnu-gcc \
        CORE_ONLY=1 bash build/build_cross.sh linux "" "$PWD/out/bin/linux"
    ''}
    ${lib.optionalString (crossWindowsCC != null) ''
      echo "dist: cross-building Windows core .dll"
      ODIN_CROSS_WINDOWS_CC=${crossWindowsCC}/bin/x86_64-w64-mingw32-gcc \
        ODIN_CROSS_WINDOWS_LIBDIRS=${crossWindowsLibdirs} \
        CORE_ONLY=1 bash build/build_cross.sh windows "" "$PWD/out/bin/windows"
    ''}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    A=$out/addons/odin_godot
    mkdir -p $A
    # One active copy at the canonical resource path. The optional plugin is
    # enabled in Project Settings; its Odin source template stays unscanned.
    cp -r addons/box3d_authoring $out/addons/box3d_authoring
    # The collection itself is ignored by Godot. Ship the render-frame helper
    # at its importable resource path for script consumers and HTML5 exports.
    mkdir -p $out/addons/replay_presentation
    cp replay/godot/scene/activation_preview.gd $out/addons/replay_presentation/

    # Prebuilt core dll(s).
    cp -r out/bin $A/bin

    # The addon root mirrors the repo's COLLECTION layout so the bundled build scripts
    # resolve `-collection:godot=$ODIN_GODOT_ROOT` (with ODIN_GODOT_ROOT pointing here)
    # exactly as in-repo: `godot:godot` -> $A/godot, `godot:gdext` -> $A/gdext, etc.
    # `core` + `scriptgen` are bundled too — `core` so the WEB build can pull it into the
    # scripts module, scriptgen for the //gd: codegen the build scripts run. flow/flowgd
    # (the sequencer) and events (the pure-Odin observer) are documented script-facing
    # collections — a consumer following the authoring docs imports them. `play` is the
    # OPT-IN companion layer (edge/pace/fsm — higher-level game-structure helpers built ON
    # kit's replication model; a game imports it only if it wants them). `decl` is the
    # declaration schema — the gd: tag vocabulary and the id-hash law — and it is NOT
    # optional: `runtime` and `scriptgen` both import it, so a bundle without it fails to
    # compile at the consumer's first build.
    # Kit/Replay's native-free diagnostics and capacity types also belong to the
    # Box3D collection; consumers need these sources even without a backend.
    cp -r core godot gdext libgd runtime decl flow flowgd events kit play replay box3d authoring $A/
    cp -r scriptgen $A/scriptgen
    # Only the CONSUMER-facing build scripts — not the repo's dev/test builders
    # (build_phase*.sh) or the nix package def (dist.nix), which a consumer never runs.
    # common.sh is the shared helper library every one of them sources.
    mkdir -p $A/build
    cp build/common.sh \
       build/build_scripts.sh build/build_scripts.ps1 build/build_export_scripts.sh \
       build/build_web.sh build/build_cross.sh build/serve.sh build/import_project.sh $A/build/
    # The editor's Project > Tools debugger items shell out to debug_game.sh, which
    # auto-imports the godot_lldb.py pretty-printers from beside itself. The .py is not
    # a `source`d .sh, so the self-guard below can't catch a miss — keep the pair here.
    cp build/debug_game.sh build/godot_lldb.py $A/build/
    cp build/box3d_profile.py build/box3d_capacity.py build/box3d_web_link.py build/toolchain.py build/web_memory.py $A/build/
    mkdir -p $A/build/patches
    cp build/patches/odin-polymorphic-probes.patch $A/build/patches/

    # A selected backend's receipt verifies these exact native producer/test
    # inputs against the SDK. Keep the checks intact in installed projects.
    cp build/box3d_source.py build/build_box3d.sh build/build_box3d_web.py $A/build/
    for directory in tests/box3d_capacity/native tests/box3d_native tests/box3d_recovery \
                     tests/box3d_modules/native tests/box3d_authoring/native \
                     tests/box3d_motion/native tests/box3d_upgrade tests/box3d_soak/native_observe; do
      while IFS= read -r -d "" input; do
        mkdir -p "$A/$(dirname "$input")"
        cp "$input" "$A/$input"
      done < <(find "$directory" -type f '(' -name '*.c' -o -name '*.h' -o -name '*.py' -o -name 'fields.json' ')' -print0)
    done
    # Canonical generated default for backend-source checks. The active sibling
    # frontend can carry a project's selected capacity profile independently.
    mkdir -p $A/addons/box3d_authoring
    cp addons/box3d_authoring/capacity_defaults.gd $A/addons/box3d_authoring/
    touch $A/addons/.gdignore $A/tests/.gdignore

    # Self-guard: every `source .../<file>` in a shipped script must resolve inside the
    # addon — a helper added to build/ but forgotten here should fail THIS build, not a
    # consumer's Project > Tools > Build Odin Scripts.
    # (The source lines nest quotes inside $(...) — match greedily to the trailing
    # /<name>.sh", don't try to bound the quoted string.)
    for s in $A/build/*.sh; do
      for dep in $(grep -oE 'source ".*/[A-Za-z0-9_.-]+\.sh"' "$s" | sed -E 's/.*\/([A-Za-z0-9_.-]+\.sh)"/\1/' | sort -u); do
        if [ ! -f "$A/build/$dep" ]; then
          echo "dist.nix: $s sources $dep, which is not packaged into the addon" >&2
          exit 1
        fi
      done
    done

    # Copy-paste starter for the consumer's res://scripts/ — the REQUIRED boot.odin (which
    # a user can't be expected to write from scratch) + a minimal Hello example + a README.
    # A fresh addon otherwise ships no scripts, so there is nothing to build or learn from.
    cp -r build/template $A/template
    # The first editor open precedes gameplay compilation. Include the declared
    # dock immediately so Godot does not remove a missing plugin from settings.
    mkdir -p $A/template/replay/addons/replay_authoring
    cp replay/editor/plugin.cfg replay/editor/plugin.gd replay/editor/preview_controls.gd \
       replay/editor/saved_data.gd $A/template/replay/addons/replay_authoring/
    mkdir -p $A/template/box3d
    cp examples/box3d_starter/README.md examples/box3d_starter/project.godot \
       examples/box3d_starter/main.tscn examples/box3d_starter/export_presets.cfg $A/template/box3d/
    cp -r examples/box3d_starter/scripts examples/box3d_starter/content $A/template/box3d/

    # Onboarding docs for someone who DOWNLOADED the addon (vs. cloned the repo): the
    # addon-root README is their entry point, and a curated docs/ set gives the full
    # reference. The bundled getting-started/index are the DOWNLOAD-oriented rewrites
    # (build/addon-docs/) — bring-your-own-odin, no Nix/repo assumptions; the reference
    # pages (authoring/workflow/exporting/debugging) are content-oriented and copied as-is.
    cp dist/addons/odin_godot/README.md $A/README.md
    # License + attribution travel WITH the addon (Apache-2.0 requires the NOTICE to
    # accompany redistribution, and Asset Library reviewers look for a license in-tree).
    cp LICENSE NOTICE $A/
    # Default editor icon for `.odin` scripts that set no `//gd:icon` (script.odin
    # resolved_default_icon -> res://addons/odin_godot/icon.svg).
    cp dist/addons/odin_godot/icon.svg $A/icon.svg
    mkdir -p $A/docs
    cp docs/*.md $A/docs/
    for section in scripting kit replay box3d libraries examples multiplayer learn contributing onboarding; do
      # Preserve nested learning paths without packaging contributor run records.
      while IFS= read -r -d "" page; do
        case "$page" in docs/replay/results/*) continue ;; esac
        mkdir -p "$A/$(dirname "$page")"
        cp "$page" "$A/$page"
      done < <(find "docs/$section" -type f '(' -name '*.md' -o -name '*.svg' -o -name '*.png' ')' -print0)
    done
    cp -r docs/img $A/docs/img
    cp build/addon-docs/getting-started.md build/addon-docs/index.md $A/docs/
    cp build/addon-docs/replay.md $A/docs/replay.md
    mkdir -p $A/docs/api/generated
    cp build/addon-docs/api.md $A/docs/api/index.md
    cp build/addon-docs/api-packages.md $A/docs/api/generated/index.md
    # Generated API pages belong to the website. Bundled Markdown links to that
    # reference without requiring the parser tool or generated files in the addon.
    find $A/docs -name '*.md' -type f -exec sed -i -E \
      's|\]\((\.\./)*api/generated/([^#)]+)\.md([^)]*)\)|](https://wlitwin.github.io/odin_godot/api/generated/\2.html\3)|g' {} +

    # Stamp the TESTED Odin release used to build the bundled core into the docs'
    # @ODIN_VERSION@ placeholders. Compatible releases may pass the complete native ABI
    # fingerprint, but naming the tested toolchain gives consumers a known-good default and
    # must not rot on a toolchain bump. Guard: an unstamped placeholder or failed version
    # probe must fail THIS build, not confuse a consumer.
    ODIN_VER="$(odin version | awk '{print $NF}')"
    if [ -z "$ODIN_VER" ]; then
      echo "dist.nix: could not determine the odin version for the doc stamp" >&2
      exit 1
    fi
    for f in $A/README.md $A/docs/getting-started.md; do
      sed -i "s/@ODIN_VERSION@/$ODIN_VER/g" "$f"
      if grep -q "@ODIN_VERSION@" "$f"; then
        echo "dist.nix: unstamped @ODIN_VERSION@ placeholder left in $f" >&2
        exit 1
      fi
    done

    # CRITICAL: Godot's filesystem scanner claims EVERY .odin file as a script. The addon
    # bundles the Odin collection SOURCE (so a consumer can compile scripts) + a template —
    # those are build inputs resolved by odin's `-collection:` PATH, not res:// scripts.
    # Without this, Godot scans them all as project scripts and registers the template's
    # `//gd:class Hello` as a PHANTOM global class with no compiled impl, which crashes/
    # destabilizes the editor. A `.gdignore` makes Godot skip a dir (odin's path-based
    # collection resolution is unaffected). The addon root stays scannable so Godot still
    # discovers odin_godot.gdextension.
    for d in core godot gdext libgd runtime decl flow flowgd events kit play replay box3d authoring scriptgen template build docs; do
      touch "$A/$d/.gdignore"
    done
    # The raw engine inputs are gitignored (regenerated from the pinned Godot) and are NOT
    # needed to compile scripts (the godot/ binding is already generated from them) — copy
    # only if present so `nix build` works from a clean (gitignore-filtered) source.
    for f in extension_api.json gdextension_interface.h; do
      [ -e "$f" ] && cp "$f" $A/ || true
    done

    # The multi-platform addon manifest (points at bin/<platform>/...).
    cp dist/addons/odin_godot/odin_godot.gdextension $A/odin_godot.gdextension

    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "odin_godot drop-in GDExtension addon (core dlls + Odin collection + build scripts)";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
} // lib.optionalAttrs isDarwin {
  # IMPURE build — DARWIN ONLY. The macOS core link is the reason: Odin shells out to the
  # host `xcrun` + the Xcode macOS SDK (libSystem/-lm live there), which the hermetic nix
  # sandbox does not carry. A pure Apple-SDK toolchain for an arbitrary tool that calls
  # `xcrun` directly is a known nixpkgs-Darwin rabbit hole, so we mirror what the dev shell
  # already does: reach the host toolchain. `__noChroot` lets the build see /usr/bin/xcrun +
  # the system SDK, and NIX_ENFORCE_PURITY=0 stops the cc-wrapper rejecting the Xcode SDK
  # path in the link. NOTE: `__noChroot` is only honored when the nix daemon runs with
  # `sandbox = relaxed` (nix.conf) — the nix-darwin/macOS default; a `sandbox = true` daemon
  # refuses the build.
  # This makes the macOS dll depend on the host's Xcode (not bit-reproducible). The LINUX
  # native build and the Linux/Windows CROSS cores stay fully HERMETIC (self-contained nix
  # toolchains, no xcrun, none of these attrs) — they are the reproducible part.
  __noChroot = true;
  NIX_ENFORCE_PURITY = 0;
})
