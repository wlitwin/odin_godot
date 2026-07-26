# Distribution — shipping odin_godot as a drop-in addon

This page covers **building the distributable addon** (`nix build`), **what's in it**, and
**how a user installs it** into a Godot project, compiles their scripts, and exports for
all platforms. For the export pipeline internals see [exporting.md](exporting.md).

> **Honesty about platform status** (this repo is developed on macOS):
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
> identical across platforms, so there is high confidence, but a Linux/Windows Godot has
> not loaded these binaries on this macOS host. See **Runtime-confirming** below.

## The two-dll model

odin_godot is a **stable CORE dll** (`libodin_godot.<ext>`, a pure-C-ABI
`ScriptLanguageExtension`, entry `odin_godot_init`) that at runtime loads a **SCRIPTS dll**
(`libodinscripts.<ext>`) containing your `.odin` files compiled against the odin_godot Odin
collection. The core is shipped prebuilt in the addon; **you compile the scripts dll** for
each project, because they are your code. (On web, core + binding + scripts are AOT-linked
into one Emscripten `SIDE_MODULE` instead.)

So the addon must contain both the prebuilt core **and** everything needed to compile a
scripts dll: the `godot:` Odin collection, the `scriptgen` codegen preprocessor, and the
build scripts.

## Build the distributable

```sh
# macOS core only (always works with the nixpkgs `odin`):
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
  scriptgen/                       //gd: codegen preprocessor (sources)
  build/                           build_scripts.sh, build_cross.sh, build_web.sh, …
  extension_api.json
  gdextension_interface.h
```

The addon root mirrors the repo's collection layout, so the bundled build scripts resolve
`-collection:godot=$ODIN_GODOT_ROOT` (pointing at the addon) exactly as they do in-repo.

## Cross-compiling directly (without nix build)

`build/build_cross.sh` is the engine `nix build .#dist-cross` uses. It works standalone:

```sh
# core + scripts for a project, into <project>/bin/<target>/:
nix develop .#cross --command bash -c 'bash build/build_cross.sh linux   tests/phase35'
nix develop .#cross --command bash -c 'bash build/build_cross.sh windows tests/phase35'

# core only (CORE_ONLY=1), into an explicit dir:
nix develop .#cross --command bash -c 'CORE_ONLY=1 bash build/build_cross.sh linux "" out/bin/linux'
```

**How it works.** Odin's own linker driver refuses to *cross-link* a dll
(`Linking for cross compilation … not yet supported`). So `build_cross.sh` emits a single
relocatable object with Odin (`-build-mode:obj -use-single-module -target:<t>`) and links it
with a Nix cross **gcc wrapper** (`pkgsCross.gnu64` / `pkgsCross.mingwW64`), which supplies
the target glibc / mingw sysroot. The cross compilers are exposed by the `.#cross` dev shell
as `ODIN_CROSS_LINUX_CC` / `ODIN_CROSS_WINDOWS_CC` (triple-prefixed, kept **off** `PATH` so
the native `cc`/`clang` is never shadowed). If a toolchain is absent the script exits **3**
(a SKIP sentinel), so callers gate on it like the browser-gated web tests.

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
  T odin_scripts_set_core_api
  NEEDED libdl.so.2 libm.so.6 libpthread.so.0 libgcc_s.so.1 libc.so.6 ld-linux-x86-64.so.2

### Windows  (-target:windows_amd64, linked with pkgsCross.mingwW64 gcc)
core  .dll: PE32+ executable (DLL) x86-64, for MS Windows, 11 sections
scr   .dll: PE32+ executable (DLL) x86-64, for MS Windows, 11 sections
  Export: odin_godot_init          (libodin_godot.dll  — PE export table)
  Export: odin_scripts_boot        (libodinscripts.dll — PE export table)
  Export: odin_scripts_manifest
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

You need an `odin` compiler on `PATH` to compile scripts. That is the one host tool a
consumer project needs.

This **split layout** (core dll inside `addons/odin_godot/bin/<platform>/`, scripts dll at
`res://bin/`) is exactly what the suite's `splitaddon` test pins (macOS, where dlopen
semantics are strictest: the scripts dll is self-contained, so the core's location doesn't
matter). If a scripts-dll load fails, the core prints the OS loader's own
reason (`odin: loader error: …`) next to the path.

> **Known engine quirk (Godot 4.6–4.7, still on master):** a headless `godot --import` of a
> project containing *any* GDExtension can crash **at exit, after the import succeeded**
> (`EditorHelp::_gen_extensions_docs` is queued as a deferred call; when the quit wins the
> race it flushes during `Main::cleanup`, after `~EditorNode` nulled EditorHelp's `doc`).
> Harmless but scary: the `.godot/` artifacts are complete. In CI, don't gate on
> `--import`'s exit code. Check for the artifacts, or use `--editor --quit-after 30`
> instead (frames flush the deferred while everything is alive).

## Export your game

Exporting is unchanged from [exporting.md](exporting.md): the editor's `OdinExportPlugin`
compiles the scripts dll for the **target** platform at export and bundles it beside the
core. For **cross-target desktop exports** (e.g. a Windows build from macOS) the export host
needs the matching cross toolchain on `PATH` (the same `ODIN_CROSS_*_CC` the `.#cross`
shell provides); otherwise prebuild with `build/build_cross.sh` and bundle manually.

- **macOS / Web**: fully automated + verified (see exporting.md).
- **Linux / Windows**: the scripts dll cross-compiles (verified); run the export from a host
  with the cross toolchain, or prebuild the scripts dll with `build_cross.sh`.

## Runtime-confirming Linux / Windows

The binaries are build-verified here but **not run** on Linux/Windows. To close the gap on a
real host or in CI:

**Linux** (e.g. GitHub Actions `ubuntu-latest`):
1. Install the matching Godot 4.7.1 **Linux** export templates + editor.
2. `nix build .#dist-cross` (or run `build/build_cross.sh linux` on the Linux host itself,
   where it's a *native* build with no cross needed).
3. Place the addon in a test project; build the scripts dll; run headless:
   `godot --headless --path tests/phase35` and assert the Odin `_ready` sentinel, the same
   assertion `tests/phase35/run.sh` makes on macOS.
4. For an exported game: `godot --headless --export-release "Linux/X11" out/game` then run
   `out/game --headless` and assert the sentinel.

**Windows** (e.g. GitHub Actions `windows-latest`) follows the same shape: install Godot 4.7.1
and the Windows templates, build the scripts dll (natively with `odin -target:windows_amd64`,
or use the prebuilt cross dll), drop in the addon, and run `godot.exe --headless --path …`.

Because the gdext C-ABI boundary and the loader logic (`dladdr`/sibling-dll lookup, with the
`LoadLibrary` path already present for Windows in `core:dynlib`) are platform-generic and the
macOS + web runtimes are verified, the residual risk is platform-specific link/loader detail,
not the extension design.

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
nix build                                                   # macOS addon
nix build .#dist-cross                                      # + Linux/Windows cores
```
