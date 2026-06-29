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

stdenvNoCC.mkDerivation {
  pname = "odin_godot-addon";
  version = "0.1.0";
  inherit src;

  nativeBuildInputs = [ odin ]
    ++ lib.optional (crossLinuxCC != null) crossLinuxCC
    ++ lib.optional (crossWindowsCC != null) crossWindowsCC;

  # IMPURE build. The macOS core link is the reason: Odin shells out to the host `xcrun` +
  # the Xcode macOS SDK (libSystem/-lm live there), which the hermetic nix sandbox does not
  # carry. A pure Apple-SDK toolchain for an arbitrary tool that calls `xcrun` directly is a
  # known nixpkgs-Darwin rabbit hole, so we mirror what the dev shell already does: reach the
  # host toolchain. `__noChroot` lets the build see /usr/bin/xcrun + the system SDK, and
  # NIX_ENFORCE_PURITY=0 stops the cc-wrapper rejecting the Xcode SDK path in the link.
  # NOTE: this makes the macOS dll depend on the host's Xcode (not bit-reproducible). The
  # Linux/Windows CROSS cores, by contrast, build fully HERMETICALLY (self-contained nix
  # cross gcc, no xcrun) — they are the reproducible part of this artifact.
  __noChroot = true;
  NIX_ENFORCE_PURITY = 0;

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    export ODIN_GODOT_ROOT=$PWD
    export NIX_ENFORCE_PURITY=0
    export PATH=$PATH:/usr/bin:/usr/sbin:/bin   # host xcrun/ld for the macOS link

    echo "dist: building macOS core dll (native, via host Xcode toolchain)"
    mkdir -p out/bin/macos
    odin build core \
      -collection:godot=$PWD \
      -build-mode:dll \
      -out:out/bin/macos/libodin_godot.dylib

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

    # Prebuilt core dll(s).
    cp -r out/bin $A/bin

    # The addon root mirrors the repo's COLLECTION layout so the bundled build scripts
    # resolve `-collection:godot=$ODIN_GODOT_ROOT` (with ODIN_GODOT_ROOT pointing here)
    # exactly as in-repo: `godot:godot` -> $A/godot, `godot:gdext` -> $A/gdext, etc.
    # `core` + `scriptgen` are bundled too — `core` so the WEB build can pull it into the
    # scripts module, scriptgen for the //gd: codegen the build scripts run.
    cp -r core godot gdext libgd runtime $A/
    cp -r scriptgen $A/scriptgen
    # Only the CONSUMER-facing build scripts — not the repo's dev/test builders
    # (build_phase*.sh) or the nix package def (dist.nix), which a consumer never runs.
    mkdir -p $A/build
    cp build/build_scripts.sh build/build_scripts.ps1 build/build_export_scripts.sh \
       build/build_web.sh build/build_cross.sh build/serve.sh $A/build/

    # Copy-paste starter for the consumer's res://scripts/ — the REQUIRED boot.odin (which
    # a user can't be expected to write from scratch) + a minimal Hello example + a README.
    # A fresh addon otherwise ships no scripts, so there is nothing to build or learn from.
    cp -r build/template $A/template

    # Onboarding docs for someone who DOWNLOADED the addon (vs. cloned the repo): the
    # addon-root README is their entry point, and a curated docs/ set gives the full
    # reference. The bundled getting-started/index are the DOWNLOAD-oriented rewrites
    # (build/addon-docs/) — bring-your-own-odin, no Nix/repo assumptions; the reference
    # pages (authoring/workflow/exporting/debugging) are content-oriented and copied as-is.
    cp dist/addons/odin_godot/README.md $A/README.md
    # Default editor icon for `.odin` scripts that set no `//gd:icon` (script.odin
    # resolved_default_icon -> res://addons/odin_godot/icon.svg).
    cp dist/addons/odin_godot/icon.svg $A/icon.svg
    mkdir -p $A/docs
    cp build/addon-docs/getting-started.md build/addon-docs/index.md $A/docs/
    cp docs/authoring-guide.md docs/workflow.md docs/exporting.md docs/debugging.md $A/docs/

    # CRITICAL: Godot's filesystem scanner claims EVERY .odin file as a script. The addon
    # bundles the Odin collection SOURCE (so a consumer can compile scripts) + a template —
    # those are build inputs resolved by odin's `-collection:` PATH, not res:// scripts.
    # Without this, Godot scans them all as project scripts and registers the template's
    # `//gd:class Hello` as a PHANTOM global class with no compiled impl, which crashes/
    # destabilizes the editor. A `.gdignore` makes Godot skip a dir (odin's path-based
    # collection resolution is unaffected). The addon root stays scannable so Godot still
    # discovers odin_godot.gdextension.
    for d in core godot gdext libgd runtime scriptgen template build docs; do
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
}
