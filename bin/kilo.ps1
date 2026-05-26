#Requires -Version 7
<#
.SYNOPSIS
    Direct Kilo CLI launcher — skip the interactive menu.
.DESCRIPTION
    Reads data/ai_settings.env, sets up the portable environment,
    installs/updates Kilo CLI via Bun if needed, then launches it.
.PARAMETER Update
    Reinstall Kilo CLI before launching.
#>
[CmdletBinding()]
param(
    [switch]$Update
)

# ---- Locate project root ----
$BIN_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT    = Split-Path -Parent $BIN_DIR

$ENGINE_DIR = Join-Path $ROOT "engine"
$DATA_DIR   = Join-Path $ROOT "data"
$ENV_FILE   = Join-Path $DATA_DIR "ai_settings.env"
$BUN_EXE    = Join-Path $ENGINE_DIR "bun-windows-x64\bun.exe"
$KILO_DIR   = Join-Path $ENGINE_DIR "node_modules\@kilocode\cli"

# ---- Check prerequisites ----
if (-not (Test-Path $BUN_EXE)) {
    Write-Host "ERROR: Bun not found at $BUN_EXE" -ForegroundColor Red
    Write-Host "Run start.ps1 first to download Bun." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $ENV_FILE)) {
    Write-Host "ERROR: No settings file found at $ENV_FILE" -ForegroundColor Red
    Write-Host "Run start.ps1 first to configure your AI provider." -ForegroundColor Yellow
    exit 1
}

# ---- Set up portable environment ----
$env:CLAUDE_CONFIG_DIR                      = Join-Path $DATA_DIR "openclaude"
$env:XDG_CONFIG_HOME                        = Join-Path $DATA_DIR "config"
$env:XDG_DATA_HOME                          = Join-Path $DATA_DIR "app_data"
$env:XDG_CACHE_HOME                         = Join-Path $DATA_DIR "cache"
$env:APPDATA                                = Join-Path $DATA_DIR "app_data"
$env:LOCALAPPDATA                           = Join-Path $DATA_DIR "local_app_data"
$env:HOME                                   = Join-Path $DATA_DIR "home"
$env:USERPROFILE                            = $env:HOME
$env:CLAUDE_CODE_PROVIDER_PROFILE_ENV_APPLIED    = "1"
$env:CLAUDE_CODE_PROVIDER_PROFILE_ENV_APPLIED_ID = "portable-env"
$env:PATH = (Split-Path -Parent $BUN_EXE) + ";" + $env:PATH

# Create required directories
$dirs = @($ENGINE_DIR, $DATA_DIR, $env:CLAUDE_CONFIG_DIR, $env:HOME, $env:XDG_CONFIG_HOME, $env:XDG_DATA_HOME, $env:XDG_CACHE_HOME, $env:APPDATA, $env:LOCALAPPDATA)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# ---- Load settings ----
$lines = Get-Content $ENV_FILE
foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^\s*#' -or $trimmed -notmatch '=') { continue }
    $parts = $trimmed -split '=', 2
    $key   = $parts[0].Trim()
    $value = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "" }
    [Environment]::SetEnvironmentVariable($key, $value, 'Process')
}

# ---- Install / Update Kilo CLI ----
Push-Location $ENGINE_DIR
try {
    if ($Update -or -not (Test-Path $KILO_DIR)) {
        $action = if ($Update -and (Test-Path $KILO_DIR)) { "Updating" } else { "Installing" }
        Write-Host "$action Kilo CLI via Bun..." -ForegroundColor Yellow
        & $BUN_EXE install @kilocode/cli
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Kilo CLI install failed (exit $LASTEXITCODE)." -ForegroundColor Red
            Pop-Location
            exit 1
        }
        Write-Host "Kilo CLI ready." -ForegroundColor Green
    }

    & $BUN_EXE x kilo
}
finally {
    Pop-Location
}
