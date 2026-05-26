#Requires -Version 7
<#
.SYNOPSIS
    Direct OpenClaude launcher — skip the interactive menu.
.DESCRIPTION
    Reads data/ai_settings.env, sets up the portable environment,
    and launches OpenClaude via Bun.
.PARAMETER Limitless
    Launch with --dangerously-skip-permissions (auto-execute mode).
.PARAMETER Update
    Reinstall the OpenClaude engine before launching.
#>
[CmdletBinding()]
param(
    [switch]$Limitless,
    [switch]$Update
)

# ---- Locate project root ----
$BIN_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT    = Split-Path -Parent $BIN_DIR

$ENGINE_DIR = Join-Path $ROOT "engine"
$DATA_DIR   = Join-Path $ROOT "data"
$ENV_FILE   = Join-Path $DATA_DIR "ai_settings.env"
$BUN_EXE    = Join-Path $ENGINE_DIR "bun-windows-x64\bun.exe"
$OC_BIN     = Join-Path $ENGINE_DIR "node_modules\@gitlawb\openclaude\bin\openclaude"
$OC_CLI     = Join-Path $ENGINE_DIR "node_modules\@gitlawb\openclaude\dist\cli.mjs"
$TOOLS_DIR  = Join-Path $ROOT "tools"

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

# ---- Update engine if requested ----
if ($Update) {
    Write-Host "Updating OpenClaude Engine..." -ForegroundColor Yellow
    $installer = Join-Path $TOOLS_DIR "install-openclaude-engine.ps1"
    if (-not (Test-Path $installer)) {
        Write-Host "ERROR: Installer not found at $installer" -ForegroundColor Red
        exit 1
    }
    & $installer -EngineDir $ENGINE_DIR -BunCmd $BUN_EXE -LogFile (Join-Path $ENGINE_DIR "openclaude-engine-install.log")
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Engine update failed (exit $LASTEXITCODE)." -ForegroundColor Red
        exit 1
    }
    Write-Host "Engine updated." -ForegroundColor Green
}

# ---- Build launch arguments ----
$cmdArgs = @("--setting-sources", "local")

if ($Limitless) {
    $cmdArgs += "--dangerously-skip-permissions"
}

# Provider args
$baseUrl = $env:OPENAI_BASE_URL
if ($baseUrl -match "integrate\.api\.nvidia") {
    $cmdArgs += "--provider", "nvidia-nim"
}

# Model args
$model = $env:OPENAI_MODEL
if ($model) { $cmdArgs += "--model", $model }

# ---- Launch ----
if (-not (Test-Path $OC_BIN) -or -not (Test-Path $OC_CLI)) {
    Write-Host "OpenClaude engine not found. Run start.ps1 to install it." -ForegroundColor Red
    exit 1
}

Push-Location $ENGINE_DIR
try {
    & $BUN_EXE $OC_BIN @cmdArgs
}
finally {
    Pop-Location
}
