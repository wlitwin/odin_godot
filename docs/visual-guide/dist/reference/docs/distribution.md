# Distribution — shipping odin_godot as a drop-in addon

Build the distributable addon with `nix build`, install it in a Godot project,
and compile that project's scripts using the bundled sources and build tools.
This page describes the addon layout and the verification available for each
export target. See [exporting.md](exporting.md) for the export procedure.

> **Platform verification status** (this repo is developed on macOS):
>
> | Platform | Cross-BUILD | Runtime |
> |----------|-------------|---------|
> | macOS (arm64/universal) | native | **verified** (full test suite + exported `.app`) |
> | Web / WASM | native (emscripten) | **verified in a real browser** |
> | Linux x86-64 | **cross-build verified** (ELF `.so`, entry symbol exported) | **not run here** (needs a Linux host / CI) |
> | Windows x86-64 | **cross-build verified** (PE `.dll`, entry symbol exported) | **not run here** (needs Windows / CI) |
>
> "Cross-build verified" means `nix build .#dist-cross` (and `build/build_cross.sh`)
> produce a `.so`/`.dll` of the right format/arch that **exports the `odin_godot_init`
> entry** (and the scripts dll exports `odin_scripts_boot`). The C-ABI gdext boundary is
> shared across platforms. This build check does not establish that Linux or Windows
> Godot can load and run the binaries; those runs need a target host. See **Runtime-confirming** below.

## The two-dll model

On native platforms, odin_godot uses two libraries. The addon supplies a
prebuilt core, `libodin_godot.<ext>`, which implements
`ScriptLanguageExtension` through a C ABI with entry `odin_godot_init`. At
runtime it loads `libodinscripts.<ext>`, containing the project's `.odin`
files compiled against the odin_godot Odin collection. Compile this scripts
library for each project. On web, core, binding, and scripts are linked ahead
of time into one Emscripten `SIDE_MODULE` instead.

The addon therefore includes the prebuilt core and the inputs needed to compile
a scripts library: the `godot:` Odin collection, the `scriptgen` code
generator, and build scripts.

## Build the distributable

```sh
# macOS core only (uses the nixpkgs `odin`):
nix build                 # -> ./result/addons/odin_godot/

# macOS + Linux + Windows cores (pulls the pinned cross gcc wrappers from cache.nixos.org):
nix build .#dist-cross    # -> ./result/addons/odin_godot/
```

`nix build` produces `result/addons/odin_godot/`:

```
addons/odin_godot/
  odin_godot.gdextension          multi-platform manifest (macos/linux/windows/web)
  bin/
    macos/libodin_godot.dylib      prebuilt core (always)
    linux/libodin_godot.so         prebuilt core (dist-cross only)
    windows/libodin_godot.dll      prebuilt core (dist-cross only)
  core/  godot/  gdext/  libgd/  runtime/   the Odin `godot:` collection
  kit/  play/  replay/             multiplayer/gameplay source collections
  scriptgen/                       //gd: codegen preprocessor (sources)
  build/                           build_scripts.sh, build_cross.sh, build_web.sh, …
  extension_api.json
  gdextension_interface.h
```

The addon root mirrors the repo's collection layout, so the bundled build scripts resolve
`-collection:godot=$ODIN_GODOT_ROOT` (pointing at the addon) exactly as they do in-repo.

Replay ships as an experimental source collection beside Kit, with a separate
`template/replay/` project and a download-oriented `docs/replay.md` guide. Source
collections are hidden from Godot's scene scanner using `.gdignore`; the Odin
compiler still resolves imports from them. The default Hello starter does not
use Replay.

The [Replay distribution gate](../tests/replay_distribution/README.md) builds an
isolated source snapshot, installs the Nix-produced addon into an external project,
compiles with only that addon's collection path and runs native solo/network and
actual browser acceptance. It includes current untracked implementation files in
the snapshot without modifying the shared Git index. Normal Git-flake release
builds still require all intended files to be committed; this test does not publish,
tag or bypass the release runbook.

## Cross-compiling directly (without nix build)

`nix build .#dist-cross` calls `build/build_cross.sh`. You can also run it
directly:

```sh
# core + scripts for a project, into <project>/bin/<target>/:
nix develop .#cross --command bash -c 'bash build/build_cross.sh linux   tests/phase35'
nix develop .#cross --command bash -c 'bash build/build_cross.sh windows tests/phase35'

# core only (CORE_ONLY=1), into an explicit dir:
nix develop .#cross --command bash -c 'CORE_ONLY=1 bash build/build_cross.sh linux "" out/bin/linux'
```

Odin's linker driver refuses to cross-link a library
(`Linking for cross compilation … not yet supported`). So `build_cross.sh` emits a single
relocatable object with Odin (`-build-mode:obj -use-single-module -target:<t>`) and links it
with a Nix cross **gcc wrapper** (`pkgsCross.gnu64` / `pkgsCross.mingwW64`), which supplies
the target glibc / mingw sysroot. The cross compilers are exposed by the `.#cross` dev shell
as `ODIN_CROSS_LINUX_CC` / `ODIN_CROSS_WINDOWS_CC` (triple-prefixed, kept **off** `PATH` so
the native `cc`/`clang` is never shadowed). If a toolchain is absent the script exits **3**
(a SKIP sentinel), allowing callers to distinguish an unavailable toolchain
from a failed build, as the browser-gated web tests do.

### Build-verification evidence

`nix develop .#cross --command bash tests/cross/run.sh` builds and inspects all four
binaries. Captured evidence (cross-built on this macOS/arm64 host):

```
### Linux  (-target:linux_amd64, linked with pkgsCross.gnu64 gcc)
core  .so: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, not stripped
scr   .so: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, not stripped
  T odin_godot_init               (libodin_godot.so  — dynsym)
  T odin_scripts_boot             (libodinscripts.so — dynsym)
  T odin_scripts_manifest
  T odin_scripts_abi_fingerprint
  T odin_scripts_set_core_api
  NEEDED libdl.so.2 libm.so.6 libpthread.so.0 libgcc_s.so.1 libc.so.6 ld-linux-x86-64.so.2

### Windows  (-target:windows_amd64, linked with pkgsCross.mingwW64 gcc)
core  .dll: PE32+ executable (DLL) x86-64, for MS Windows, 11 sections
scr   .dll: PE32+ executable (DLL) x86-64, for MS Windows, 11 sections
  Export: odin_godot_init          (libodin_godot.dll  — PE export table)
  Export: odin_scripts_boot        (libodinscripts.dll — PE export table)
  Export: odin_scripts_manifest
  Export: odin_scripts_abi_fingerprint
  Export: odin_scripts_set_core_api
  Imports: ADVAPI32.dll KERNEL32.dll bcrypt.dll msvcrt.dll ntdll.dll   (system DLLs only —
           libgcc + mcfgthreads statically linked, so the DLL is self-contained)
```

## Install into a Godot project

1. Copy `addons/odin_godot/` from the build output into your project's `res://addons/`.
2. Godot auto-discovers `res://addons/odin_godot/odin_godot.gdextension` on next open. Your
   `.odin` files are now recognized as scripts.
3. **Compile your scripts dll** (only the scripts, since the core is prebuilt). The core looks
   for `res://bin/libodinscripts.<ext>` (and, in exports, beside the core dll):

   ```sh
   ODIN_GODOT_ROOT=/abs/path/to/your_project/addons/odin_godot \
     SKIP_CORE=1 bash your_project/addons/odin_godot/build/build_scripts.sh your_project
   # -> your_project/bin/libodinscripts.<ext>
   ```

   `SKIP_CORE=1` skips rebuilding the core (you already have the prebuilt one). Re-run this
   whenever you change a script (the editor's reload-on-save does it automatically in-repo).

Compiling scripts requires an `odin` compiler on `PATH`. Use the bundled
release by default. The native loader can accept a different compiler release
when both its semantic ABI generation and complete layout fingerprint match;
it does not decide compatibility from the release-name string alone. See
[Native core ↔ scripts boundary](design/native-boundary.md).

The suite's `splitaddon` test on macOS verifies the split layout: the core is
in `addons/odin_godot/bin/<platform>/` and scripts are in `res://bin/`.
The scripts library is self-contained and can load independently of the core's
directory. If loading fails, the core prints the OS loader's reason
(`odin: loader error: …`) next to the path.

> **Engine issue observed with Godot 4.6–4.7:** a headless `godot --import` of a
> project containing a GDExtension can crash at exit after the import succeeded
> (`EditorHelp::_gen_extensions_docs` is queued as a deferred call; when the quit wins the
> race it flushes during `Main::cleanup`, after `~EditorNode` nulled EditorHelp's `doc`).
> For this failure, the `.godot/` artifacts are complete despite the exit
> error. In CI, verify the artifacts rather than using only `--import`'s exit
> code, or use `--editor --quit-after 30` so frames flush the deferred call
> before editor cleanup.

## Export your game

As described in [exporting.md](exporting.md), the editor's `OdinExportPlugin`
compiles scripts for the target platform and bundles them beside the core.
Cross-target desktop exports, such as a Windows build from macOS, require the
matching cross compiler configured through `ODIN_CROSS_*_CC`, as provided by
the `.#cross` shell. Otherwise, prebuild with `build/build_cross.sh` and bundle
manually.

- **macOS / Web**: fully automated + verified (see exporting.md).
- **Linux / Windows**: the scripts dll cross-compiles (verified); run the export from a host
  with the cross toolchain, or prebuild the scripts dll with `build_cross.sh`.

<a id="runtime-confirming-linux--windows"></a>

## Verify runtime behavior on Linux / Windows

Build verification does not establish runtime behavior on Linux/Windows.
Run the following checks on a target host or in CI:

**Linux** (e.g. GitHub Actions `ubuntu-latest`):
1. Install the matching Godot 4.7.1 **Linux** export templates + editor.
2. `nix build .#dist-cross` (or run `build/build_cross.sh linux` on the Linux host itself,
   where it's a *native* build with no cross needed).
3. Place the addon in a test project; build the scripts dll; run headless:
   `godot --headless --path tests/phase35` and assert the Odin `_ready` sentinel, the same
   assertion `tests/phase35/run.sh` makes on macOS.
4. For an exported game: `godot --headless --export-release "Linux/X11" out/game` then run
   `out/game --headless` and assert the sentinel.

**Windows** (e.g. GitHub Actions `windows-latest`) uses the same procedure: install Godot 4.7.1
and the Windows templates, build the scripts dll (natively with `odin -target:windows_amd64`,
or use the prebuilt cross dll), drop in the addon, and run `godot.exe --headless --path …`.

These checks exercise target-specific linking and library loading in addition
to the shared GDExtension C ABI. The loader uses `dladdr`/sibling-library
lookup on supported native systems and the `LoadLibrary` path in
`core:dynlib` on Windows. Successful macOS and web runs do not replace testing
those target-specific paths.

## Troubleshooting: `failed to load scripts dll` / `No loader found`

Opening or importing a project triggers the editor's reload-on-save coordinator, which
rebuilds the scripts dll. `build/build_scripts.sh` (and `.ps1`) build to a temp file and `mv`
it into place **atomically**, so an interrupted or failed (re)build never removes the
previously-built dll. If scripts fail to load, rebuild the dll once with the bundled
`build_scripts.sh` and reopen.

## Verify (in-repo)

```sh
nix develop --command bash tests/run_all.sh                 # native + web suite (macOS)
nix develop .#cross --command bash tests/cross/run.sh       # cross BUILD smoke -> CROSS_OK
nix develop .#build-parity --command bash tests/build_helpers/run.sh
                                                            # Bash + PowerShell helper contract
nix build                                                   # macOS addon
nix build .#dist-cross                                      # + Linux/Windows cores
```
