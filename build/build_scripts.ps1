# build_scripts.ps1 — Windows: compile the odin_godot CORE dll + a project's SCRIPTS dll(s) natively.
#
# The Windows counterpart of build/build_scripts.sh (bash, hardcodes .dylib). Building NATIVELY on
# Windows with the MSVC toolchain (Visual Studio Build Tools) is the SUPPORTED Odin Windows path and
# avoids the cross-compile stack-probe (__chkstk) ABI mismatch the macOS-cross prebuilt dll hit. By
# default it builds:
#   - the CORE  -> <Root>\bin\windows\libodin_godot.dll   (the GDExtension; the .gdextension points here)
#   - scriptgen -> the codegen preprocessor
#   - the SCRIPTS dll -> <Project>\bin\libodinscripts.dll (core loads this at res://bin/libodinscripts.dll)
#   - one dll per script MODULE: <Project>\modules\<name> -> <Project>\bin\libodinscripts_<name>.dll
#     (KEEP IN SYNC with build/build_scripts.sh — dll_leaf_for_dir / check_module_isolation /
#     the modules/* loop; -SkipModules is the ps1 spelling of its BUILD_MODULES=0 opt-out)
# Pass -SkipCore to build only the scripts; -ScriptsDir to build ONE specific scripts dir (the
# per-module reload rebuild passes a single modules\<name> dir here, plus -SkipModules).
#
# NOTE: the multi-module path below is SYNTAX-REVIEWED but UNVERIFIED on Windows — a best-effort
# port, the same convention this script was introduced under (this repo is developed on
# macOS/Linux, where PowerShell isn't available to even parse it). The logic mirrors the
# exercised bash counterpart (tests/modules_spike drives build_scripts.sh) step for step.
#
# SPACES IN PATHS: Odin's argument parser splits a path at spaces (e.g. a "...\Downloads\foo (1)\..."
# download folder breaks `-out:`). We sidestep that by running everything FROM the project directory and
# passing only RELATIVE paths to odin — a project's internal paths (addons\odin_godot, scripts, bin) have
# no spaces even when the parent folder does. (Still: a space-free project path is the most reliable.)
#
# Requirements: odin.exe (on PATH or -Odin) AND a working Odin link toolchain — run this from a
# "x64 Native Tools Command Prompt for VS" so link.exe + the Windows SDK are set up. See SETUP-WINDOWS.md.
#
# Usage (from that prompt, in the project folder):
#   powershell -ExecutionPolicy Bypass -File addons\odin_godot\build\build_scripts.ps1 `
#       -Root addons\odin_godot -Project . -Odin C:\odin\odin.exe
#
# Both dlls are built WITH debug info (-debug) so a crash yields a real backtrace.

param(
    [Parameter(Mandatory = $true)][string]$Root,     # addons\odin_godot (collection root + core/ source)
    [Parameter(Mandatory = $true)][string]$Project,  # the Godot project (must contain scripts\)
    [string]$Odin = "odin",                           # odin.exe, or an absolute path to it
    [switch]$SkipCore,
    # The ONE scripts dir to build (default: the project's main scripts\). The per-module
    # reload rebuild (core/reload.odin) passes a single modules\<name> dir here.
    [string]$ScriptsDir = "scripts",
    # Don't chain the modules\* loop after the main build — the BUILD_MODULES=0 equivalent
    # of build_scripts.sh (KEEP IN SYNC). reload.odin passes this so each of its per-module
    # invocations stays scoped to exactly the one -ScriptsDir it names.
    [switch]$SkipModules
)

$ErrorActionPreference = "Stop"

# Resolve to absolute, then work FROM the project dir using RELATIVE paths for everything handed to odin
# (relative paths under the project contain no spaces, which odin's arg parser can't handle).
$projAbs = (Resolve-Path $Project).Path
$rootAbs = (Resolve-Path $Root).Path
Set-Location -LiteralPath $projAbs

$RootRel = (Resolve-Path -LiteralPath $rootAbs -Relative)   # e.g. .\addons\odin_godot  (space-free inside)
$Bin     = "bin"
$WinBin  = Join-Path $RootRel "bin\windows"
New-Item -ItemType Directory -Force -Path $Bin    | Out-Null
New-Item -ItemType Directory -Force -Path $WinBin | Out-Null

# The requested scripts dir, RELATIVE to the project cwd (reload.odin passes it absolute;
# a project-internal relative path is space-free even when the project's parent isn't).
$Scripts = $ScriptsDir
if (Test-Path -LiteralPath $Scripts) {
    $Scripts = (Resolve-Path -LiteralPath $Scripts -Relative)
}

if (-not (Test-Path $Scripts) -or -not (Get-ChildItem -Path $Scripts -Filter *.odin -ErrorAction SilentlyContinue)) {
    throw @"
no Odin scripts found at '$Scripts' (project: $projAbs).
odin_godot ships the engine core; your .odin scripts are yours and go in a 'scripts'
folder. A scripts package also needs a boot.odin (required boilerplate). Quick start:
copy the bundled template, then re-run:
  Copy-Item -Recurse "$RootRel\template\scripts" "$projAbs\scripts"
(the template lives at addons\odin_godot\template\ — see its README.md)
"@
}
if ($projAbs -match ' ') {
    Write-Host "WARNING: the project path contains a space ($projAbs)."
    Write-Host "         Using relative paths to work around it; if odin still errors, move the project"
    Write-Host "         to a space-free path like C:\odin_survivors and re-run."
}

function Run([string]$exe, [string[]]$argv) {
    Write-Host "> $exe $($argv -join ' ')"
    & $exe @argv
    if ($LASTEXITCODE -ne 0) { throw "command failed (exit $LASTEXITCODE): $exe $($argv -join ' ')" }
}

# Build a dll to a TEMP path, then atomically move it into place — mirrors atomic_odin_dll
# in build/common.sh (KEEP IN SYNC — the bash builds all publish through that one helper).
# `odin build -out:X` truncates X up front and writes over several seconds;
# if THIS build is interrupted or fails (e.g. the editor reload-on-save coordinator in
# core/reload.odin kicks it on a worker thread and the editor quits mid-build), publishing
# via Move means the previously-built dll is never left missing/half-written — which on
# macOS deterministically caused "failed to load scripts dll" / "No loader found". PE has no
# two-level namespace, but the atomic-publish invariant is identical, so keep them in sync.
function BuildDll([string]$pkg, [string]$finalOut, [string[]]$extra) {
    $dir  = Split-Path -Parent $finalOut
    $leaf = Split-Path -Leaf   $finalOut
    $tmp  = Join-Path $dir (".${leaf}.tmp.dll")
    $tmpPdb = [System.IO.Path]::ChangeExtension($tmp, ".pdb")
    Remove-Item -Force -ErrorAction SilentlyContinue $tmp, $tmpPdb
    Run $Odin (@("build", $pkg, "-collection:godot=$RootRel", "-build-mode:dll", "-out:$tmp", "-debug") + $extra)
    # Reached only on success (Run throws on a non-zero exit). Publish the dll + its .pdb.
    $finalPdb = [System.IO.Path]::ChangeExtension($finalOut, ".pdb")
    if (Test-Path $tmpPdb) { Move-Item -Force $tmpPdb $finalPdb }
    Move-Item -Force $tmp $finalOut
}

# 1. CORE GDExtension dll (native MSVC build — the path that avoids the cross-compile crash).
if (-not $SkipCore) {
    $core = Join-Path $WinBin "libodin_godot.dll"
    BuildDll (Join-Path $RootRel "core") $core @()
}

# 2. scriptgen preprocessor — build to a writable TEMP dir, NOT into the addon (which may be
#    read-only when installed under res://addons/ and shouldn't collect build artifacts).
#    KEEP IN SYNC with build/common.sh (build_scriptgen) — the bash builds share one helper;
#    this is its Windows-native mirror.
$scriptgenDir = Join-Path ([System.IO.Path]::GetTempPath()) ("odin_godot_sgen_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $scriptgenDir | Out-Null
$scriptgenExe = Join-Path $scriptgenDir "scriptgen.exe"
Run $Odin @("build", (Join-Path $RootRel "scriptgen"), "-collection:godot=$RootRel", "-out:$scriptgenExe", "-debug")

# ---------------------------------------------------------------------------
# Multi-module support — the Windows mirror of build/build_scripts.sh (KEEP IN SYNC):
#   scripts          -> bin\libodinscripts.dll            (the MAIN module)
#   modules\<name>   -> bin\libodinscripts_<name>.dll     (one dll per module)
# Each module is its OWN Odin package compiled STANDALONE. A project without a
# modules\ dir behaves exactly as before.
# ---------------------------------------------------------------------------

# Map a scripts dir to its output dll leaf name (mirror of dll_leaf_for_dir).
function DllLeafForDir([string]$dir) {
    $abs    = (Resolve-Path -LiteralPath $dir).Path
    $name   = Split-Path -Leaf $abs
    $parent = Split-Path -Leaf (Split-Path -Parent $abs)
    if ($parent -eq "modules") { return "libodinscripts_$name.dll" }
    return "libodinscripts.dll"
}

# HARD RULE: no imports between script modules (mirror of check_module_isolation in
# build/build_scripts.sh — KEEP IN SYNC, including the regex). Odin happily compiles a
# relative `import "../other_module"` — but a package imported by two script dlls
# duplicates its package GLOBALS per dll (the shared blackboard would silently fork).
# So any `..` relative import in a script module is rejected here, at build time.
# Cross-module communication goes through the ENGINE: signals, methods, autoloads.
function CheckModuleIsolation([string]$dir) {
    $pattern = '^\s*(@\(require\)\s*)?import\s+([A-Za-z_][A-Za-z0-9_]*\s+)?"\.\.'
    $hits = Get-ChildItem -Path $dir -Filter *.odin -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike "*.gen.odin" } |
        Select-String -Pattern $pattern
    if ($hits) {
        $lines = ($hits | ForEach-Object { "  $($_.Path):$($_.LineNumber): $($_.Line.Trim())" }) -join "`n"
        throw @"
ILLEGAL cross-module import in '$dir':
$lines
  Script modules are ISOLATED packages: a package imported by two script dlls
  duplicates its globals per dll (shared state would silently fork). Talk to
  other modules through the engine (signals / methods / autoloads) instead,
  or move the shared state into exactly one module.
"@
    }
}

# scriptgen + odin build one scripts dir into its dll (atomic temp+move publish — see
# BuildDll). The three -custom-attribute flags: KEEP IN SYNC with build/common.sh
# (ODIN_GD_ATTRS) — every scripts build (bash native/web/cross + this Windows-native
# one) must pass the same set, or @(gd_method)/@(gd_connect)/@(gd_rpc) fail to compile.
# (No return value: a PowerShell function's output stream would also capture the odin/
# scriptgen stdout `& $exe` emits inside Run — the built path is tracked via $builtDlls.)
$builtDlls = @()
function BuildOneScriptsDir([string]$dir) {
    CheckModuleIsolation $dir
    Run $scriptgenExe @($dir)
    $out = Join-Path $Bin (DllLeafForDir $dir)
    BuildDll $dir $out @("-custom-attribute:gd_method", "-custom-attribute:gd_connect", "-custom-attribute:gd_rpc")
    $script:builtDlls += $out
}

# 3+4. Build the requested scripts dir; when it is the MAIN one, also build each
#      modules\<name> (-SkipModules opts out — the per-module reload rebuild passes
#      exactly one dir per invocation and must not chain the others).
BuildOneScriptsDir $Scripts
$scriptsParent = Split-Path -Leaf (Split-Path -Parent (Resolve-Path -LiteralPath $Scripts).Path)
$isModuleDir = ($scriptsParent -eq "modules")
if (-not $SkipModules -and -not $isModuleDir -and (Test-Path "modules")) {
    foreach ($mdir in Get-ChildItem -Path "modules" -Directory) {
        $mrel = Resolve-Path -LiteralPath $mdir.FullName -Relative
        if (-not (Get-ChildItem -Path $mrel -Filter *.odin -File -ErrorAction SilentlyContinue)) {
            Write-Host "build_scripts: skipping module '$($mdir.Name)' (no .odin sources)"
            continue
        }
        BuildOneScriptsDir $mrel
    }
}

Write-Host ""
if (-not $SkipCore) { Write-Host "Built core:    $(Join-Path $WinBin 'libodin_godot.dll')" }
foreach ($d in $builtDlls) { Write-Host "Built scripts: $d" }
Write-Host "Open the project in Godot and press Play."
