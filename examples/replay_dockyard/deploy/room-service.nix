{ lib, stdenv, stdenvNoCC, fetchurl, autoPatchelfHook, unzip, odin, clang, lld
, cmake, gnumake, python3, git, ripgrep, sqlite, zlib, libGL, libxkbcommon
, alsa-lib, libpulseaudio, fontconfig, xorg, procps
}:
let
  nativeSource = lib.fileset.toSource {
    root = ../../..;
    fileset = lib.fileset.unions [
      ../../../box3d ../../../vendor/box3d.tar
      ../../../build/build_box3d.sh ../../../build/box3d_source.py
      ../../../tests/box3d_native ../../../tests/box3d_recovery
      ../../../tests/box3d_modules ../../../tests/box3d_authoring
      ../../../tests/box3d_motion ../../../tests/box3d_upgrade
      ../../../tests/box3d_soak/native_observe
    ];
  };
  # Core/SDK packaging fixes do not rebuild an unchanged physics engine.
  nativeBackend = stdenv.mkDerivation {
    pname = "dockyard-room-native-backend";
    version = "1";
    src = nativeSource;
    nativeBuildInputs = [ cmake gnumake python3 git ];
    dontConfigure = true;
    dontStrip = true;
    dontPatchELF = true;
    enableParallelBuilding = false;
    buildPhase = ''
      mkdir native-cache
      cp vendor/box3d.tar native-cache/box3d.tar
      JOBS=1 bash build/build_box3d.sh Release "$PWD/native-cache"
    '';
    installPhase = ''
      mkdir -p $out/lib
      cp native-cache/build/Release/libogb3.a native-cache/build/Release/libogb3.so \
        native-cache/build/Release/build-manifest.json \
        native-cache/build/Release/native-domain-identity.txt $out/lib/
      mkdir -p $out/share/native-tests
      cp native-cache/build/Release/Testing/Temporary/LastTest.log $out/share/native-tests/
    '';
  };
  # Same engine version as the validated client; this daemon runs no gameplay.
  godot = stdenvNoCC.mkDerivation {
    pname = "godot-room-runtime";
    version = "4.7.1";
    src = fetchurl {
      url = "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.arm64.zip";
      sha256 = "8f527179cd4ae58b402fa265fe817dc505e5b6b14574f309efe57113be562ac1";
    };
    nativeBuildInputs = [ unzip autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib zlib libGL libxkbcommon alsa-lib
      libpulseaudio fontconfig xorg.libX11 xorg.libXcursor xorg.libXrandr
      xorg.libXinerama xorg.libXi xorg.libXext xorg.libXrender ];
    # Godot loads fontconfig dynamically, so ELF DT_NEEDED discovery misses it.
    runtimeDependencies = [ (lib.getLib fontconfig) ];
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p unpacked $out/bin
      unzip -q "$src" -d unpacked
      install -m755 unpacked/Godot_v4.7.1-stable_linux.arm64 $out/bin/godot
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/godot --headless --version | grep '^4\.7\.1\.stable'
    '';
    meta = { license = lib.licenses.mit; platforms = [ "aarch64-linux" ]; };
  };
in stdenv.mkDerivation {
  pname = "dockyard-replay-room";
  version = "1";
  src = ../../..;
  nativeBuildInputs = [ odin clang lld cmake gnumake python3 git ripgrep procps ];
  buildInputs = [ sqlite ];
  dontConfigure = true;
  # Sealed SDK hashes must describe the installed binaries too.
  dontStrip = true;
  dontPatchELF = true;
  enableParallelBuilding = false;
  buildPhase = ''
    runHook preBuild
    export XDG_CONFIG_HOME="$TMPDIR/godot-config"
    export XDG_CACHE_HOME="$TMPDIR/godot-cache"
    export XDG_DATA_HOME="$TMPDIR/godot-data"
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
    export JOBS=1 ODIN=odin GODOT=${godot}/bin/godot
    export ODIN_GODOT_ROOT="$PWD"
    export BOX3D_NATIVE_LIBRARY="${nativeBackend}/lib/libogb3.so"
    # The pinned, cached SQLite output already includes its static archive.
    test -f ${lib.getLib sqlite}/lib/libsqlite3.a
    export SCRIPT_BUILD_FLAGS="-define:REPLAY_SQLITE_LIBRARY=system:libsqlite3.a"
    export NIX_LDFLAGS="''${NIX_LDFLAGS:-} -L${lib.getLib sqlite}/lib"
    project="$PWD/examples/replay_room_service"
    bash build/build_scripts.sh "$project"
    # Retain exact dependency names before the production admission parser runs.
    readelf -d "$project/bin/libodinscripts.so" | grep NEEDED
    "$GODOT" --headless --editor --path "$project" --quit-after 120 > service-import.log 2>&1
    if rg -n 'SCRIPT ERROR|ERROR:|CONTRACT_REJECTED' service-import.log; then exit 1; fi
    python3 tests/replay_comparison/wait_builds.py "$project" build-wait.json
    bash build/build_scripts.sh "$project"
    mkdir -p engine-notices
    "$GODOT" --headless --path "$PWD/engine-notices" \
      --script "$PWD/tests/replay_dockyard/package/engine_notices.gd" -- "$PWD/engine-notices"
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    project="$PWD/examples/replay_room_service"
    dest="$out/share/replay-room/project"
    mkdir -p "$dest/bin" "$dest/scripts" "$dest/.godot" "$out/bin" "$out/share/replay-room/provenance"
    cp "$project/project.godot" "$project/odin_godot.gdextension" "$project/service.tscn" "$dest/"
    cp "$project/scripts/"*.odin "$dest/scripts/"
    cp "$project/bin/libodin_godot.so" "$project/bin/libodinscripts.so" \
      "$project/bin/libogb3.so" "$project/bin/box3d-runtime.json" "$dest/bin/"
    for name in extension_list.cfg global_script_class_cache.cfg uid_cache.bin .gdignore; do
      if [ -f "$project/.godot/$name" ]; then cp "$project/.godot/$name" "$dest/.godot/"; fi
    done
    if [ -d "$project/.godot/imported" ]; then cp -r "$project/.godot/imported" "$dest/.godot/"; fi
    cp LICENSE NOTICE box3d/native/THIRD_PARTY_NOTICES.txt engine-notices/* "$out/share/replay-room/provenance/"
    cp source-manifest.json ${nativeBackend}/lib/build-manifest.json \
      service-import.log build-wait.json "$out/share/replay-room/provenance/"
    cat > "$out/bin/replay-room-service" <<EOF
    #!${stdenv.shell}
    set -eu
    umask 077
    runtime=\''${RUNTIME_DIRECTORY:-\''${TMPDIR:-/tmp}}
    project=\$(mktemp -d "\$runtime/room-project.XXXXXXXX")
    cp -R "$dest/." "\$project/"
    chmod -R u+w "\$project"
    export ODIN_SCRIPTS_DLL="\$project/bin/libodinscripts.so"
    export LD_LIBRARY_PATH="\$project/bin:${lib.makeLibraryPath [ stdenv.cc.cc.lib stdenv.cc.libc ]}"
    exec ${godot}/bin/godot --headless --max-fps 120 --path "\$project" "\$@"
    EOF
    chmod +x "$out/bin/replay-room-service"
    runHook postInstall
  '';
  meta = { license = lib.licenses.asl20; platforms = [ "aarch64-linux" ]; };
}
