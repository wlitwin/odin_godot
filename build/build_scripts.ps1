# build_scripts.ps1 — Windows: compile the odin_godot CORE dll + a project's SCRIPTS dll natively.
#
# The Windows counterpart of build/build_scripts.sh (bash, hardcodes .dylib). Building NATIVELY on
# Windows with the MSVC toolchain (Visual Studio Build Tools) is the SUPPORTED Odin Windows path and
# avoids the cross-compile stack-probe (__chkstk) ABI mismatch the macOS-cross prebuilt dll hit. By
# default it builds BOTH:
#   - the CORE  -> <Root>\bin\windows\libodin_godot.dll   (the GDExtension; the .gdextension points here)
#   - scriptgen -> the codegen preprocessor
#   - the SCRIPTS dll -> <Project>\bin\libodinscripts.dll (core loads this at res://bin/libodinscripts.dll)
# Pass -SkipCore to build only the scripts.
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
    [switch]$SkipCore
)

$ErrorActionPreference = "Stop"

# Resolve to absolute, then work FROM the project dir using RELATIVE paths for everything handed to odin
# (relative paths under the project contain no spaces, which odin's arg parser can't handle).
$projAbs = (Resolve-Path $Project).Path
$rootAbs = (Resolve-Path $Root).Path
Set-Location -LiteralPath $projAbs

$RootRel = (Resolve-Path -LiteralPath $rootAbs -Relative)   # e.g. .\addons\odin_godot  (space-free inside)
$Scripts = "scripts"
$Bin     = "bin"
$WinBin  = Join-Path $RootRel "bin\windows"
New-Item -ItemType Directory -Force -Path $Bin    | Out-Null
New-Item -ItemType Directory -Force -Path $WinBin | Out-Null

if (-not (Test-Path $Scripts)) { throw "no 'scripts' folder in project: $projAbs" }
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

# Build a dll to a TEMP path, then atomically move it into place — mirrors the temp+mv in
# build_scripts.sh. `odin build -out:X` truncates X up front and writes over several seconds;
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

# 2. scriptgen preprocessor.
$scriptgenExe = Join-Path $RootRel "scriptgen\scriptgen.exe"
Run $Odin @("build", (Join-Path $RootRel "scriptgen"), "-collection:godot=$RootRel", "-out:$scriptgenExe", "-debug")

# 3. Generate the *.gen.odin siblings.
Run $scriptgenExe @($Scripts)

# 4. Scripts dll (what the core loads at res://bin/libodinscripts.dll). Atomic publish (see
#    BuildDll above) so an interrupted reload-on-save rebuild never deletes the live dll.
$out = Join-Path $Bin "libodinscripts.dll"
BuildDll $Scripts $out @("-custom-attribute:gd_method", "-custom-attribute:gd_connect", "-custom-attribute:gd_rpc")

Write-Host ""
if (-not $SkipCore) { Write-Host "Built core:    $(Join-Path $WinBin 'libodin_godot.dll')" }
Write-Host "Built scripts: $out"
Write-Host "Open the project in Godot and press Play."
