# build_scripts.ps1 — Windows: compile a Godot project's Odin scripts into bin\libodinscripts.dll.
#
# The Windows counterpart of build/build_scripts.sh (which is macOS/Linux + hardcodes .dylib).
# It does NOT build the core dll — that ships prebuilt in the addon (addons\odin_godot\bin\windows).
# It (1) builds the scriptgen codegen preprocessor, (2) runs it over the project's scripts\ dir to
# emit the *.gen.odin build artifacts, (3) compiles the scripts package into bin\libodinscripts.dll
# (which the core looks for at res://bin/libodinscripts.dll on Windows).
#
# Requirements: the Odin compiler (odin.exe) on PATH or passed via -Odin, and a working Odin
# Windows link toolchain (Visual Studio Build Tools / Windows SDK — Odin links DLLs via the MSVC
# linker by default). See SETUP-WINDOWS.md.
#
# Usage (from a PowerShell prompt, in the project folder):
#   powershell -ExecutionPolicy Bypass -File addons\odin_godot\build\build_scripts.ps1 `
#       -Root  (Resolve-Path addons\odin_godot) `
#       -Project (Get-Location)
#
# NOTE: This script has NOT yet been validated on a real Windows machine — it is a best-effort
# port. If a step fails, the error + the exact command it ran are printed; please report them.

param(
    [Parameter(Mandatory = $true)][string]$Root,     # path to addons\odin_godot (the collection root)
    [Parameter(Mandatory = $true)][string]$Project,  # path to the Godot project (must contain scripts\)
    [string]$Odin = "odin"                            # odin.exe, or an absolute path to it
)

$ErrorActionPreference = "Stop"
$Root    = (Resolve-Path $Root).Path
$Project = (Resolve-Path $Project).Path
$Scripts = Join-Path $Project "scripts"
$Bin     = Join-Path $Project "bin"
New-Item -ItemType Directory -Force -Path $Bin | Out-Null

if (-not (Test-Path $Scripts)) { throw "no scripts\ folder in project: $Scripts" }

function Run([string]$exe, [string[]]$argv) {
    Write-Host "> $exe $($argv -join ' ')"
    & $exe @argv
    if ($LASTEXITCODE -ne 0) { throw "command failed (exit $LASTEXITCODE): $exe $($argv -join ' ')" }
}

# 1. Build the scriptgen preprocessor.
$scriptgenExe = Join-Path $Root "scriptgen\scriptgen.exe"
Run $Odin @("build", (Join-Path $Root "scriptgen"), "-collection:godot=$Root", "-out:$scriptgenExe", "-debug")

# 2. Generate the *.gen.odin siblings beside the authored sources.
Run $scriptgenExe @($Scripts)

# 3. Compile the scripts package into the DLL the core loads (res://bin/libodinscripts.dll).
$out = Join-Path $Bin "libodinscripts.dll"
Remove-Item -Force -ErrorAction SilentlyContinue $out
Run $Odin @("build", $Scripts, "-collection:godot=$Root", "-build-mode:dll",
            "-custom-attribute:gd_method", "-custom-attribute:gd_connect", "-custom-attribute:gd_rpc",
            "-out:$out", "-debug")

Write-Host ""
Write-Host "Built: $out"
Write-Host "Open the project in Godot and press Play."
