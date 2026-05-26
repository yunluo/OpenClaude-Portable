#Requires -Version 7
<#
.SYNOPSIS
    Portable AI USB Entry Point (PowerShell 7 version)
.DESCRIPTION
    Cross-platform AI coding environment that runs from USB or any folder.
    Replaces START.bat with native PowerShell 7 execution.
.PARAMETER Offline
    Skip update checks (offline mode).
.PARAMETER Quick
    Skip launch menu, go directly to OpenClaude Limitless Mode.
#>
[CmdletBinding()]
param(
    [switch]$Offline,
    [switch]$Quick
)

#===============================================================================
# CONFIGURATION
#===============================================================================
$USB_ROOT    = Split-Path -Parent $MyInvocation.MyCommand.Path
$ENGINE_DIR  = Join-Path $USB_ROOT "engine"
$DATA_DIR    = Join-Path $USB_ROOT "data"
$TOOLS_DIR   = Join-Path $USB_ROOT "tools"
$ENV_FILE    = Join-Path $DATA_DIR "ai_settings.env"

$BUN_VERSION      = "1.3.14"
$BUN_DIR_NAME     = "bun-windows-x64"
$BUN_DIR          = Join-Path $ENGINE_DIR $BUN_DIR_NAME
$BUN_EXE          = Join-Path $BUN_DIR "bun.exe"
$BUN_ARCHIVE      = Join-Path $ENGINE_DIR "bun.zip"
$BUN_DOWNLOAD_LOG = Join-Path $ENGINE_DIR "bun-download.log"
$BUN_INSTALL_LOG  = Join-Path $ENGINE_DIR "openclaude-engine-install.log"
$BUN_URL          = "https://github.com/oven-sh/bun/releases/download/bun-v$BUN_VERSION/bun-windows-x64.zip"

$OPENCLAUDE_DIR   = Join-Path $ENGINE_DIR "node_modules\@gitlawb\openclaude"
$OC_BIN           = Join-Path $OPENCLAUDE_DIR "bin\openclaude"
$OC_CLI           = Join-Path $OPENCLAUDE_DIR "dist\cli.mjs"

#===============================================================================
# ANSI COLOR DEFINITIONS
#===============================================================================
$_e = [char]0x1B
$C_RESET = "$_e[0m"
$C_BOLD  = "$_e[1m"
$C_DIM   = "$_e[90m"
$C_RED   = "$_e[31m"
$C_GREEN = "$_e[32m"
$C_YELLOW= "$_e[33m"
$C_CYAN  = "$_e[36m"

#===============================================================================
# PORTABLE ENVIRONMENT SETUP
#===============================================================================
$env:CLAUDE_CONFIG_DIR = Join-Path $DATA_DIR "openclaude"
$env:XDG_CONFIG_HOME   = Join-Path $DATA_DIR "config"
$env:XDG_DATA_HOME     = Join-Path $DATA_DIR "app_data"
$env:XDG_CACHE_HOME    = Join-Path $DATA_DIR "cache"
$env:APPDATA           = Join-Path $DATA_DIR "app_data"
$env:LOCALAPPDATA      = Join-Path $DATA_DIR "local_app_data"
$env:HOME              = Join-Path $DATA_DIR "home"
$env:USERPROFILE       = $env:HOME

# Always set, regardless of provider (Kiloconfig needs this for config)
$env:CLAUDE_CODE_PROVIDER_PROFILE_ENV_APPLIED    = "1"
$env:CLAUDE_CODE_PROVIDER_PROFILE_ENV_APPLIED_ID = "portable-env"

# Create required directories
$dirs = @(
    $ENGINE_DIR,
    $DATA_DIR,
    $env:CLAUDE_CONFIG_DIR,
    $env:HOME,
    $env:XDG_CONFIG_HOME,
    $env:XDG_DATA_HOME,
    $env:XDG_CACHE_HOME,
    $env:APPDATA,
    $env:LOCALAPPDATA
)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

function Write-Banner {
    Write-Host ""
    Write-Host "$C_CYAN    ____            __        __    __        ___    ____$C_RESET"
    Write-Host "$C_CYAN   / __ \____  ____/ /_____ _/ /_  / /__     /   |  /  _/$C_RESET"
    Write-Host "$C_CYAN  / /_/ / __ \/ __/ __/ __ ` + "`" + " / __ \/ / _ \   / /| |  / /  $C_RESET"
    Write-Host "$C_CYAN / ____/ /_/ / / / /_/ /_/ / /_/ / /  __/  / ___ |_/ /   $C_RESET"
    Write-Host "$C_CYAN/_/    \____/_/  \__/\__,_/_.___/_/\___/  /_/  |_/___/   $C_RESET"
    Write-Host ""
    Write-Host "$C_CYAN=========================================================$C_RESET"
    Write-Host "  $C_BOLD Claude Code - Open Source Multi-Platform$C_RESET"
    Write-Host "$C_CYAN=========================================================$C_RESET"
    Write-Host ""
}

function Install-Engine {
    param([string]$Action = "Installing")

    Write-Host "  $C_YELLOW[~] $Action OpenClaude Engine...$C_RESET"
    Write-Host "  $C_DIM    This can take several minutes on slower USB drives or networks.$C_RESET"
    Write-Host "  $C_DIM    Log: $BUN_INSTALL_LOG$C_RESET"
    Write-Host "  $C_DIM    Tip: USB 2.0 drives can look idle while bun writes many small files.$C_RESET"

    $installer = Join-Path $TOOLS_DIR "install-openclaude-engine.ps1"
    & $installer -EngineDir $ENGINE_DIR -BunCmd $BUN_EXE -LogFile $BUN_INSTALL_LOG
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  $C_RED[ERROR] OpenClaude Engine install failed (bun exit $LASTEXITCODE).$C_RESET"
        Write-Host "  $C_DIM        Check log: $BUN_INSTALL_LOG$C_RESET"
        Write-Host "  $C_DIM        If this only fails on USB, try a USB 3.x port/drive or copy the folder to internal storage for the first install, then copy it back.$C_RESET"
        Pause-AndExit 1
    }
    if (-not (Test-Path $OC_BIN) -or -not (Test-Path $OC_CLI)) {
        Write-Host "  $C_RED[ERROR] OpenClaude Engine install is incomplete.$C_RESET"
        Write-Host "  $C_DIM        Missing expected files under $OPENCLAUDE_DIR$C_RESET"
        Pause-AndExit 1
    }
    Write-Host "  $C_GREEN[OK] Engine installed!$C_RESET"
}

function Download-AndExtractBun {
    Write-Host "  $C_YELLOW[~] Bun not found for Windows-x64. Downloading...$C_RESET"
    Write-Host "  $C_DIM    Version: v$BUN_VERSION$C_RESET"
    Write-Host "  $C_DIM    Download log: $BUN_DOWNLOAD_LOG$C_RESET"

    # Clean up previous attempts
    if (Test-Path $BUN_ARCHIVE)  { Remove-Item $BUN_ARCHIVE -Force }
    if (Test-Path $BUN_DOWNLOAD_LOG) { Remove-Item $BUN_DOWNLOAD_LOG -Force }

    Write-Host "  $C_YELLOW[~] Downloading Bun v$BUN_VERSION...$C_RESET"
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Downloading: $BUN_URL" | Add-Content -Path $BUN_DOWNLOAD_LOG

    try {
        curl.exe --fail --location --retry 3 --retry-delay 3 --connect-timeout 20 `
            $BUN_URL --output $BUN_ARCHIVE 2>&1 | Add-Content -Path $BUN_DOWNLOAD_LOG
        if ($LASTEXITCODE -ne 0) { throw "curl exited non-zero" }
    }
    catch {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Bun download failed" | Add-Content -Path $BUN_DOWNLOAD_LOG
        if (Test-Path $BUN_ARCHIVE) { Remove-Item $BUN_ARCHIVE -Force }
        Show-BunDownloadError
    }

    if (-not (Test-Path $BUN_ARCHIVE) -or (Get-Item $BUN_ARCHIVE).Length -eq 0) {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Downloaded archive is missing or empty" | Add-Content -Path $BUN_DOWNLOAD_LOG
        if (Test-Path $BUN_ARCHIVE) { Remove-Item $BUN_ARCHIVE -Force }
        Show-BunDownloadError
    }

    $size = (Get-Item $BUN_ARCHIVE).Length
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Downloaded $size bytes" | Add-Content -Path $BUN_DOWNLOAD_LOG

    Write-Host "  $C_YELLOW[~] Extracting Bun...$C_RESET"
    if (Test-Path $BUN_DIR) { Remove-Item $BUN_DIR -Recurse -Force }
    New-Item -ItemType Directory -Path $BUN_DIR -Force | Out-Null

    try {
        Expand-Archive -Path $BUN_ARCHIVE -DestinationPath $BUN_DIR -Force
        Remove-Item $BUN_ARCHIVE -Force
        Write-Host "  $C_GREEN[OK] Bun installed to $BUN_DIR$C_RESET"
    }
    catch {
        Write-Host "  $C_RED[ERROR] Failed to extract Bun!$C_RESET"
        Remove-Item $BUN_ARCHIVE -Force -ErrorAction SilentlyContinue
        Pause-AndExit 1
    }
}

function Show-BunDownloadError {
    Write-Host ""
    Write-Host "  $C_RED[ERROR] Automatic Bun download failed.$C_RESET"
    Write-Host ""
    Write-Host "  Please download Bun manually from:"
    Write-Host "  $C_CYAN https://bun.sh$C_RESET"
    Write-Host ""
    Write-Host "  After installing Bun, restart OpenClaude Portable."
    Write-Host "  Download log: $BUN_DOWNLOAD_LOG"
    Pause-AndExit 1
}

function Pause-AndExit {
    param([int]$Code = 0)
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit $Code
}

function Mask-Key {
    param([string]$Key)
    if ($Key.Length -le 10) { return "$($Key.Substring(0, [Math]::Min(3, $Key.Length)))***" }
    return "$($Key.Substring(0, 6))****$($Key.Substring($Key.Length - 4))"
}

function Load-Settings {
    if (-not (Test-Path $ENV_FILE)) { return $false }
    $lines = Get-Content $ENV_FILE
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\s*#' -or $trimmed -notmatch '=') { continue }
        $parts = $trimmed -split '=', 2
        $key = $parts[0].Trim()
        $value = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "" }
        Set-Variable -Name $key -Value $value -Scope Script -Force
        [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
    return $true
}

function Save-Settings {
    param(
        [string]$Model,
        [string]$ApiKey,
        [string]$BaseUrl
    )

    $lines = @(
        "# ========================================================",
        "# Portable AI - Master Switchboard",
        "# ========================================================"
    )

    # All providers use OpenAI-compatible protocol
    $lines += "AI_PROVIDER=openai"
    $lines += "CLAUDE_CODE_USE_OPENAI=1"
    $lines += "OPENAI_API_KEY=$ApiKey"
    $lines += "OPENAI_BASE_URL=$BaseUrl"
    $lines += "OPENAI_API_FORMAT=chat_completions"
    $lines += "OPENAI_MODEL=$Model"
    $lines += "AI_DISPLAY_MODEL=$Model"
    $lines | Set-Content -Path $ENV_FILE -Encoding UTF8
}

function Get-FriendlyProviderName {
    param([string]$BaseUrl)

    if ($BaseUrl -match "openrouter")             { return "OpenRouter" }
    if ($BaseUrl -match "integrate\.api\.nvidia") { return "NVIDIA NIM" }
    if ($BaseUrl -match "api\.deepseek")          { return "DeepSeek" }
    if ($BaseUrl -match "api\.openai")            { return "OpenAI" }
    if ($BaseUrl -match "localhost:1234")         { return "LM Studio" }
    return "Custom OpenAI-Compatible"
}

#===============================================================================
# PROVIDER SETUP FUNCTIONS
#===============================================================================

function Setup-CustomOpenAI {
    Write-Host ""
    Write-Host "  $C_CYAN--- CUSTOM OPENAI-COMPATIBLE SETUP ---$C_RESET"
    Write-Host ""
    Write-Host "  Use this for providers that expose OpenAI-style endpoints like /v1/models and /v1/chat/completions."

    do {
        $baseUrl = Read-HostPrompt "Base URL (example: https://provider.example.com/v1)"
        $baseUrl = $baseUrl.TrimEnd('/')
        $apiKey = Read-HostPrompt "API Key (Enter for none/local)"
        if (-not $apiKey) { $apiKey = "not-needed" }
        $apiKey = $apiKey.Trim()

        Write-Host ""
        Write-Host "  $C_YELLOW[~] Checking /models endpoint...$C_RESET"
        $reachable = Test-APIKey -Url "$baseUrl/models" -Key $apiKey -AuthType Bearer
        if (-not $reachable) {
            Write-Host "  $C_YELLOW[WARN] Could not verify $baseUrl/models.$C_RESET"
            $saveAnyway = Read-HostPrompt "Continue with manual model entry? (y/N)" -Default "n"
            if ($saveAnyway -ne "y") { continue }
        }
        break
    } while ($true)

    Write-Host ""
    Write-Host "  $C_CYAN--- CUSTOM MODELS ---$C_RESET $C_DIM(Live Fetching...)$C_RESET"
    $models = @()
    try {
        $headers = @{ Authorization = "Bearer $apiKey" }
        $resp = Invoke-RestMethod -Uri "$baseUrl/models" -Headers $headers -ErrorAction Stop
        if ($resp.data) { $models = @($resp.data | Select-Object -ExpandProperty id) }
    } catch { }
    $model = Select-FromList -Items $models -Prompt "Choose a model" -Default "manual" -CustomPrompt "Enter model string"
    Save-Settings -Model $model -ApiKey $apiKey -BaseUrl $baseUrl
}

#===============================================================================
# MODEL SELECTION HELPERS
#===============================================================================

function Test-APIKey {
    param([string]$Url, [string]$Key, [ValidateSet("Bearer", "x-api-key")][string]$AuthType = "Bearer")
    try {
        $headers = @{}
        switch ($AuthType) {
            "Bearer"     { $headers.Authorization = "Bearer $Key" }
            "x-api-key"  { $headers["x-api-key"] = $Key }
        }
        Invoke-RestMethod -Uri $Url -Headers $headers -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Select-FromList {
    param(
        [string[]]$Items,
        [string]$Prompt,
        [object]$Default = $null,
        [string]$CustomPrompt = "Enter custom model string"
    )
    $count = $Items.Count
    for ($i = 0; $i -lt $count; $i++) {
        Write-Host "  ${C_CYAN}$($i+1))$C_RESET $($Items[$i])"
    }
    # Custom option
    Write-Host "  ${C_CYAN}$($count+1))$C_RESET $C_DIM $CustomPrompt...$C_RESET"
    Write-Host ""

    while ($true) {
        $defaultStr = if ($Default -ne $null) { "[Enter for $Default]" } else { "" }
        $sel = Read-HostPrompt "$Prompt ${C_CYAN}(1-$($count+1))$C_RESET $defaultStr"

        if (-not $sel -and $Default -ne $null) {
            if ($Default -is [int] -and $Default -ge 1 -and $Default -le $count) {
                return $Items[$Default - 1]
            }
            return $Default.ToString()
        }

        $num = 0
        if ([int]::TryParse($sel, [ref]$num) -and $num -ge 1 -and $num -le $count) {
            return $Items[$num - 1]
        }
        elseif ($num -eq $count + 1) {
            $custom = Read-HostPrompt "$CustomPrompt"
            if ($custom) { return $custom.Trim() }
            continue
        }
    }
}

function Read-HostPrompt {
    param([string]$Prompt, [string]$Default = "")
    if ($Default) {
        $result = Read-Host "  $Prompt [$Default]"
        if ([string]::IsNullOrWhiteSpace($result)) { return $Default }
        return $result.Trim()
    }
    else {
        $result = Read-Host "  $Prompt"
        # Re-prompt if truly empty (for required fields)
        return $result.Trim()
    }
}

#===============================================================================
# PROVIDER SELECTION FLOW
#===============================================================================

#===============================================================================
# LAUNCH FUNCTIONS
#===============================================================================

function Invoke-Kilo {
    Write-Host ""
    Push-Location $ENGINE_DIR
    try {
        if (-not (Test-Path "node_modules\@kilocode\cli")) {
            Write-Host "  $C_YELLOW[~] Installing Kilo CLI via bun...$C_RESET"
            & $BUN_EXE install @kilocode/cli
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  $C_RED[ERROR] Kilo CLI install failed.$C_RESET"
                Pause-AndExit 1
            }
            Write-Host "  $C_GREEN[OK] Kilo CLI installed!$C_RESET"
        }
        else {
            Write-Host ""
            Write-Host "  $C_GREEN[OK] Kilo CLI already installed.$C_RESET"
            Write-Host "  ${C_CYAN}1)$C_RESET Launch"
            Write-Host "  ${C_CYAN}2)$C_RESET Update"

            $choice = Read-Choice "12" -Default 1 -Timeout 10
            if ($choice -eq 2) {
                Write-Host "  $C_YELLOW[~] Updating Kilo CLI...$C_RESET"
                & $BUN_EXE install @kilocode/cli
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  $C_RED[ERROR] Kilo CLI update failed.$C_RESET"
                    Pause-AndExit 1
                }
                Write-Host "  $C_GREEN[OK] Kilo CLI updated!$C_RESET"
            }
        }

        $env:XDG_CONFIG_HOME = Join-Path $DATA_DIR "config"
        & $BUN_EXE x kilo
    }
    finally {
        Pop-Location
    }
}

function Invoke-OpenClaude {
    param([int]$Mode = 1, [bool]$Update = $false)

    Write-Host ""
    Write-Host "  $C_GREEN[OK] OpenClaude selected.$C_RESET"

    if ($Update) {
        Write-Host "  $C_YELLOW[~] Updating OpenClaude Engine...$C_RESET"
        Install-Engine -Action "Updating"
        Write-Host "  $C_GREEN[OK] Engine updated!$C_RESET"
    }
    elseif (-not (Test-Path $OC_BIN)) {
        Write-Host "  $C_YELLOW[~] OpenClaude Engine not found. Installing...$C_RESET"
        Install-Engine -Action "Installing"
    }

    $cmdArgs = @()
    if ($Mode -eq 2) {
        $cmdArgs += "--dangerously-skip-permissions"
    }

    # Provider args (all providers use OpenAI-compatible protocol)
    $baseUrl   = $script:OPENAI_BASE_URL
    $modelName = $script:OPENAI_MODEL

    if ($baseUrl -match "integrate\.api\.nvidia") { $cmdArgs += "--provider", "nvidia-nim" }

    # Model args
    if ($modelName) { $cmdArgs += "--model", $modelName }

    $cmdArgs += "--setting-sources", "local"

    if (-not (Test-Path $OC_BIN)) {
        Write-Host "  $C_RED[ERROR] OpenClaude Engine is missing. Restart start.ps1 to repair the install.$C_RESET"
        return
    }

    Push-Location $ENGINE_DIR
    try {
        & $BUN_EXE $OC_BIN @cmdArgs
    }
    finally {
        Pop-Location
    }
}

function Read-Choice {
    param(
        [string]$ValidChars,
        [int]$Default = 1,
        [int]$Timeout = 0
    )
    # If timeout is 0, just wait indefinitely
    if ($Timeout -gt 0) {
        Write-Host "  $C_DIM  Auto-selecting option $Default in ${Timeout}s... press a key to choose.$C_RESET"
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                $idx = $ValidChars.IndexOf($key.KeyChar)
                if ($idx -ge 0) {
                    Write-Host ""
                    return $idx + 1
                }
            }
            Start-Sleep -Milliseconds 50
        }
        Write-Host ""
        return $Default
    }
    else {
        while ($true) {
            $key = [Console]::ReadKey($true)
            $idx = $ValidChars.IndexOf($key.KeyChar)
            if ($idx -ge 0) { return $idx + 1 }
        }
    }
}

#===============================================================================
# MAIN ENTRY POINT
#===============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$host.UI.RawUI.WindowTitle = "Portable AI USB - Starting..."

Write-Banner

# ---- 1. Bun check/download ----
if (-not (Test-Path $BUN_EXE)) {
    Download-AndExtractBun
}
$env:PATH = "$BUN_DIR;$env:PATH"

# ---- 2. Engine check/repair/install ----
if (-not (Test-Path $OC_BIN) -or -not (Test-Path $OC_CLI)) {
    if (Test-Path $OPENCLAUDE_DIR) {
        Write-Host "  $C_YELLOW[~] Incomplete OpenClaude Engine detected. Reinstalling...$C_RESET"
        Remove-Item $OPENCLAUDE_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
    Install-Engine -Action "Installing"
}

# ---- 3. Flags ----
if ($Offline) {
    Write-Host "  $C_DIM[~] Offline mode - skipping update check$C_RESET"
}
Write-Host ""

# ---- 4. Settings check / Provider selection ----
$hasSettings = Load-Settings

if (-not $hasSettings) {
    # Legacy config check
    $legacyExists = $false
    if (Test-Path $ENV_FILE) {
        $content = Get-Content $ENV_FILE -Raw
        if ($content -notmatch 'AI_PROVIDER=') {
            Write-Host "  $C_YELLOW[INFO] Legacy configuration detected. Upgrading format...$C_RESET"
            Remove-Item $ENV_FILE -Force
        } else {
            $legacyExists = $true
            $hasSettings = Load-Settings
        }
    }

    if (-not $hasSettings) {
        Setup-CustomOpenAI
        Write-Host ""
        Write-Host "  $C_GREEN[OK] Settings saved!$C_RESET"
        Write-Host ""
        $hasSettings = Load-Settings
    }
}

# ---- 5. Show current config ----
$providerName = Get-FriendlyProviderName -BaseUrl $script:OPENAI_BASE_URL
$displayModel = if ($script:AI_DISPLAY_MODEL) { $script:AI_DISPLAY_MODEL } else { "unknown" }
$host.UI.RawUI.WindowTitle = "Portable AI USB - $providerName - $displayModel"

Write-Host "$C_CYAN=========================================================$C_RESET"
Write-Host "  $C_BOLD Claude Code - Ready (Multi-Platform)$C_RESET"
Write-Host "$C_CYAN=========================================================$C_RESET"
Write-Host ""
Write-Host "  $C_BOLD Provider$C_RESET : $C_GREEN $providerName$C_RESET"
Write-Host "  $C_BOLD Model$C_RESET    : $C_GREEN $displayModel$C_RESET"
Write-Host "  $C_BOLD Data$C_RESET     : $C_DIM Portable Mode (No PC Leaks)$C_RESET"
Write-Host ""
Write-Host "$C_CYAN=========================================================$C_RESET"
Write-Host ""

# ---- 6. Quick mode: skip menu ----
if ($Quick) {
    Write-Host "  $C_RED$C_BOLD QUICK LAUNCH - Limitless Mode$C_RESET"
    Invoke-OpenClaude -Mode 2
    exit 0
}

# ---- 7. Launch menu ----
Write-Host "  $C_BOLD Select Action:$C_RESET"
Write-Host "  🚀 ${C_CYAN}1)$C_RESET $C_GREEN OpenClaude$C_RESET    $C_DIM- AI coding agent (Normal / Limitless)$C_RESET"
Write-Host "  🔧 ${C_CYAN}2)$C_RESET $C_BOLD Kilo CLI$C_RESET        $C_DIM- AI coding agent$C_RESET"
Write-Host "  $C_DIM─────────────────────────────────────────────────────────$C_RESET"
Write-Host "  📊 ${C_CYAN}3)$C_RESET $C_BOLD Open Dashboard$C_RESET  $C_DIM- Web UI at http://localhost:3000$C_RESET"
Write-Host "  ⚙️  ${C_CYAN}4)$C_RESET $C_BOLD Change Provider$C_RESET $C_DIM- Switch AI provider or API Key$C_RESET"
Write-Host ""
Write-Host "  $C_DIM  Auto-launching in 10 seconds... press a key to choose.$C_RESET"
Write-Host ""

$mode = Read-Choice "1234" -Default 1 -Timeout 10
Write-Host ""

switch ($mode) {
    1 {
        # OpenClaude: sub-menu for Normal/Limitless/Update
        Write-Host "  ${C_CYAN}1)$C_RESET Normal Mode"
        Write-Host "  ${C_CYAN}2)$C_RESET Limitless Mode"
        Write-Host "  ${C_CYAN}3)$C_RESET Update Engine"
        $ocMode = Read-Choice "123" -Default 1 -Timeout 15

        if ($ocMode -eq 3) {
            Invoke-OpenClaude -Update
        }
        else {
            Invoke-OpenClaude -Mode $ocMode
        }
    }
    2 {
        # Kilo CLI
        Invoke-Kilo
    }
    3 {
        # Open Dashboard
        Write-Host ""
        $dashboardBat = Join-Path $TOOLS_DIR "Open_Dashboard.bat"
        & $dashboardBat
    }
    4 {
        # Change Provider
        Write-Host ""
        $changeBat = Join-Path $TOOLS_DIR "Change_Provider.bat"
        & $changeBat
    }
    default {
        Write-Host "  $C_RED[ERROR] Invalid selection.$C_RESET"
        Write-Host ""
        # re-show menu (simplified: exit)
        exit 0
    }
}
