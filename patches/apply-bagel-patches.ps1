<#
.SYNOPSIS
    Re-apply local bagel plugin patches after a plugin upgrade.

.DESCRIPTION
    The plugin market replaces plugins/bagel on startup. This script checks that
    the installed plugin is still the version the patch was written for, applies
    the diff in patches/bagel-<version>/, and byte-compiles the result with the
    instance virtualenv. No change is made when the version does not match.
#>
[CmdletBinding()]
param(
    [string]$Instance,
    [string]$PluginDir,
    [switch]$Check
)

$ErrorActionPreference = 'Continue'
# plugins/ is gitignored, git apply silently skips it, so use GNU patch instead.
# Prefer patch.exe on PATH (Git for Windows, MSYS2, ...), fall back to the usual Git install.
$patchCmd = Get-Command patch.exe -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($patchCmd) {
    $patchExe = $patchCmd.Source
}
elseif (Test-Path 'D:\Git\usr\bin\patch.exe') {
    $patchExe = 'D:\Git\usr\bin\patch.exe'
}
else {
    throw 'GNU patch not found: install Git for Windows (patch.exe under usr\bin) or put patch.exe on PATH'
}

# $scriptRoot is not reliable inside param defaults on PowerShell 5.1, so resolve it here.
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Instance) {
    $Instance = Split-Path -Parent $scriptRoot
}
if (-not $Instance) {
    $Instance = 'D:\MIHOYO\01ZZZ'
}
if (-not $PluginDir) {
    $PluginDir = Join-Path $Instance 'plugins\bagel'
}

Write-Host "instance : $Instance"
Write-Host "plugin   : $PluginDir"

if (-not (Test-Path $PluginDir)) {
    throw "plugin directory not found: $PluginDir"
}

$manifest = Join-Path $PluginDir 'plugin.json'
if (-not (Test-Path $manifest)) {
    throw "plugin.json not found: $manifest"
}
$pluginVersion = (Get-Content $manifest -Raw -Encoding UTF8 | ConvertFrom-Json).version

$patchRoot = Join-Path $scriptRoot "bagel-$pluginVersion"
if (-not (Test-Path $patchRoot)) {
    Write-Host "no patch directory for bagel $pluginVersion - patches need to be rebuilt"
    exit 2
}

$patches = Get-ChildItem $patchRoot -Filter *.patch | Sort-Object Name
if ($patches.Count -eq 0) {
    Write-Host "no patch files in $patchRoot"
    exit 2
}

Push-Location $PluginDir
try {
    foreach ($p in $patches) {
        & $patchExe -p1 --dry-run --reverse --input=$($p.FullName) 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "already applied: $($p.Name)"
            continue
        }

        & $patchExe -p1 --dry-run --input=$($p.FullName) 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "cannot apply cleanly: $($p.Name) - rebuild the patch"
            exit 3
        }

        if ($Check) {
            Write-Host "would apply: $($p.Name)"
            continue
        }

        & $patchExe -p1 --input=$($p.FullName) | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "apply failed: $($p.Name)"
            exit 4
        }
        Write-Host "applied: $($p.Name)"
    }
}
finally {
    Pop-Location
}

if ($Check) {
    Write-Host 'check only, nothing written'
    exit 0
}

$python = Join-Path $Instance '.venv\Scripts\python.exe'
if (Test-Path $python) {
    # Compile every plugin module: a broken decorator inside operation\*.py only shows up
    # at runtime otherwise.
    $targets = Get-ChildItem -LiteralPath $PluginDir -Recurse -Filter *.py -File |
        ForEach-Object { $_.FullName }
    & $python -X utf8 -c "import py_compile,sys; [py_compile.compile(p, doraise=True) for p in sys.argv[1:]]; print('compile ok')" @targets
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'compile failed'
        exit 5
    }
}
else {
    Write-Host "python not found, skipped compile: $python"
}

Write-Host 'done'
exit 0
