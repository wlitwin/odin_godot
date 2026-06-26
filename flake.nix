{
  description = "odin_godot — Odin as a first-class Godot scripting language (GDExtension)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Cross toolchains for the distributable desktop targets. Odin's OWN linker driver
        # refuses to cross-LINK a dll ("Linking for cross compilation … not yet supported"),
        # so we emit a single relocatable object with Odin (`-build-mode:obj
        # -use-single-module -target:<t>`) and hand it to one of these gcc wrappers, which
        # knows the target glibc / mingw sysroot. We expose ONLY the triple-prefixed
        # compiler as an env var (NOT on PATH) so the unprefixed native `cc`/`clang` used by
        # the macOS + wasm builds is never shadowed. build/build_cross.sh consumes these.
        #
        # NOTE: with this pinned nixpkgs the cross gcc wrappers (gcc-15.2.0) come straight
        # from cache.nixos.org — `nix develop .#cross` / `nix build .#dist-cross` fetch, not
        # build, them. They live in a SEPARATE `devShells.cross` (below) rather than the
        # default shell so a plain `nix develop` pulls nothing extra.
        # build/build_cross.sh reads these from ODIN_CROSS_{LINUX,WINDOWS}_CC.
        crossLinuxCC   = "${pkgs.pkgsCross.gnu64.stdenv.cc}/bin/x86_64-unknown-linux-gnu-gcc";
        crossWindowsCC = "${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-gcc";
        # mingw's default `mcf` thread model auto-pulls -lmcfgthread; we static-link it for a
        # self-contained DLL, so build_cross.sh needs its lib dir (-L) at link time.
        crossWindowsLibdirs = "${pkgs.pkgsCross.mingwW64.windows.mcfgthreads}/lib";

        # Toolchain. Godot itself is NOT pinned here: we target 4.6.2 stable to match the
        # installed /Applications/Godot.app (nixpkgs currently ships 4.5.1), so headless
        # tests + interface dumps use $GODOT (default below), overridable.
        #
        # emscripten: Godot 4.6.2 stable's web templates were built with emscripten
        # 4.0.20 (AUTHORITATIVE — the installed web_dlink template's godot.js does
        # `allocString("4.0.20")`). This nixpkgs rev ships 5.0.6.
        #
        # RESOLVED (docs/phase-web.md): the FULL extension (core+binding+scripts) links to
        # an Emscripten SIDE_MODULE and an Odin script VERIFIABLY RUNS in a real browser
        # against the 4.6.2 (4.0.20-built) engine — built with the dev shell's 5.0.6 AND,
        # separately, with a manual emsdk 4.0.20 install. So the version match is NOT a
        # hard requirement here: with `-sSUPPORT_LONGJMP=wasm` the longjmp ABI is
        # self-contained in the wasm and the dylink format is cross-compatible. The earlier
        # "must relink under 4.0.20" worry was a red herring; the actual web blocker was a
        # binding ABI bug (gdext Variant_Type was `enum u64`, must be `enum c.int` to match
        # the C `int` on wasm's strict call_indirect — now fixed).
        #
        # To pin the exact engine version anyway: `EMCC=/path/to/emsdk/.../emcc
        # bash build/build_web.sh`. An emsdk install (`./emsdk install 4.0.20`) fetches the
        # matching prebuilt LLVM; a pure-nix emsdk-4.0.20 derivation remains a rabbit hole
        # (nixpkgs couples emscripten to a bundled LLVM) and is unnecessary given the above.
        toolchain = with pkgs; [
          odin
          ols           # Odin language server — backs editor autocomplete (_complete_code)
          llvm
          lld
          clang
          binutils      # objcopy / ld for native link + symbol steps
          emscripten    # 5.0.6; produces a browser-loadable SIDE_MODULE (EMCC= to pin 4.0.20)
          gnumake
          nodejs        # web milestone: COOP/COEP serve.sh + headless-browser drive.mjs
        ];

        godotPath = "/Applications/Godot.app/Contents/MacOS/Godot";
      in
      {
        devShells.default = pkgs.mkShell {
          name = "odin_godot-dev";
          packages = toolchain;

          # Default GODOT to the installed 4.6.2 app; override with `GODOT=… nix develop`.
          GODOT = godotPath;

          shellHook = ''
            echo "odin_godot dev shell  (target: Godot 4.6.2 stable)"
            echo "  odin:  $(command -v odin)  $(odin version 2>/dev/null | head -1)"
            echo "  emcc:  $(command -v emcc)"
            echo "  godot: $GODOT"
          '';
        };

        # Cross-compile shell: the default toolchain PLUS the Linux/Windows cross C
        # compilers, exposed as env vars (NOT on PATH — they keep their triple prefix so
        # they never shadow the native `cc`/`clang`). Enter with:
        #   nix develop .#cross --command bash -c 'bash build/build_cross.sh linux'
        # The pinned cross gcc wrappers are fetched from cache.nixos.org (see note above).
        devShells.cross = pkgs.mkShell {
          name = "odin_godot-cross";
          packages = toolchain;
          GODOT = godotPath;
          ODIN_CROSS_LINUX_CC = crossLinuxCC;
          ODIN_CROSS_WINDOWS_CC = crossWindowsCC;
          ODIN_CROSS_WINDOWS_LIBDIRS = crossWindowsLibdirs;
          shellHook = ''
            echo "odin_godot CROSS shell"
            echo "  linux  CC: $ODIN_CROSS_LINUX_CC"
            echo "  windows CC: $ODIN_CROSS_WINDOWS_CC"
          '';
        };

        # ----------------------------------------------------------------------
        # `nix build` → the reproducible drop-in addon `addons/odin_godot/`.
        #
        # Contents (see docs/distribution.md):
        #   odin_godot.gdextension     multi-platform [libraries] (macos/linux/windows/web)
        #   bin/<platform>/libodin_godot.<ext>   prebuilt CORE dll(s)
        #   core/ godot/ gdext/ libgd/ runtime/   the Odin `godot:` collection a consumer
        #                                         compiles its scripts against
        #   scriptgen/                 the //gd: codegen preprocessor (sources)
        #   build/                     build_scripts.sh etc. — the consumer compiles ITS
        #                              OWN scripts dll with these
        #   extension_api.json, gdextension_interface.h
        #
        # `packages.default` builds the macOS core dll natively (always works with the
        # nixpkgs `odin`). The Linux/Windows core dlls are added by `packages.dist-cross`,
        # which pulls in the heavy cross toolchains — kept as a SEPARATE package so the
        # default `nix build` does not drag in a from-source glibc/gcc.
        # ----------------------------------------------------------------------
        packages.default = pkgs.callPackage ./build/dist.nix {
          inherit (pkgs) odin;
          src = self;
          crossLinuxCC = null;
          crossWindowsCC = null;
        };

        packages.dist-cross = pkgs.callPackage ./build/dist.nix {
          inherit (pkgs) odin;
          src = self;
          crossLinuxCC = pkgs.pkgsCross.gnu64.stdenv.cc;
          crossWindowsCC = pkgs.pkgsCross.mingwW64.stdenv.cc;
          crossWindowsLibdirs = "${pkgs.pkgsCross.mingwW64.windows.mcfgthreads}/lib";
        };

        # `nix build .#release` → ONE publishable archive in ./result/:
        #   odin_godot-<version>.zip   + SHA256SUMS
        #
        # This is the "ship an update" command. It wraps the FULL cross addon
        # (packages.dist-cross: macOS + Linux + Windows prebuilt cores, the Odin `godot:`
        # collection, scriptgen, and the build scripts) into a single zip a consumer
        # downloads and extracts into their project's `res://addons/`. Web has no prebuilt
        # core by design (core+scripts AOT-link into one Emscripten SIDE_MODULE per project),
        # so the addon ships `build/build_web.sh` for consumers to build web themselves.
        #
        # Release a new version: bump `version` in build/dist.nix, then
        #   nix build .#release && ls -l result/
        # and attach result/odin_godot-<version>.zip to the published release.
        packages.release =
          let addon = self.packages.${system}.dist-cross;
          in pkgs.runCommand "odin_godot-release-${addon.version}"
            { nativeBuildInputs = [ pkgs.zip pkgs.coreutils ]; }
            ''
              mkdir -p $out
              # `addons/` at the archive root so it extracts straight into a project's res://.
              ( cd ${addon} && zip -rX "$out/odin_godot-${addon.version}.zip" addons )
              ( cd $out && sha256sum ./*.zip > SHA256SUMS )
            '';
      });
}
