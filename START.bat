@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Portable AI USB - Starting...

:: Define ANSI Colors
for /F %%a in ('powershell -NoProfile -Command "[char]27"') do set "ESC=%%a"
set "CYAN=!ESC![36m"
set "GREEN=!ESC![32m"
set "YELLOW=!ESC![33m"
set "RED=!ESC![31m"
set "DIM=!ESC![90m"
set "RESET=!ESC![0m"
set "BOLD=!ESC![1m"

set "USB_ROOT=%~dp0"
set "ENGINE_DIR=%USB_ROOT%engine"
set "DATA_DIR=%USB_ROOT%data"
set "ENV_FILE=%DATA_DIR%\ai_settings.env"
rem Cache is managed by Bun automatically via HOME/USERPROFILE redirection
set "BUN_INSTALL_LOG=%ENGINE_DIR%\openclaude-engine-install.log"
set "BUN_VERSION=1.3.14"
set "BUN_DIR_NAME=bun-windows-x64"
set "BUN_DIR=%ENGINE_DIR%\%BUN_DIR_NAME%"
set "BUN_ARCHIVE=%ENGINE_DIR%\bun.zip"
set "BUN_DOWNLOAD_LOG=%ENGINE_DIR%\bun-download.log"
set "BUN_URL=https://github.com/oven-sh/bun/releases/download/bun-v%BUN_VERSION%/bun-windows-x64.zip"

set "OPENCLAUDE_DIR=%ENGINE_DIR%\node_modules\@gitlawb\openclaude"
set "OC_BIN=%OPENCLAUDE_DIR%\bin\openclaude"
set "OC_CLI=%OPENCLAUDE_DIR%\dist\cli.mjs"

:: 1. Force the portable AI to save logs/memory strictly to the USB
set "CLAUDE_CONFIG_DIR=%DATA_DIR%\openclaude"
set "PORTABLE_HOME=%DATA_DIR%\home"
set "XDG_CONFIG_HOME=%DATA_DIR%\config"
set "XDG_DATA_HOME=%DATA_DIR%\app_data"
set "XDG_CACHE_HOME=%DATA_DIR%\cache"
set "APPDATA=%DATA_DIR%\app_data"
set "LOCALAPPDATA=%DATA_DIR%\local_app_data"
set "HOME=%PORTABLE_HOME%"
set "USERPROFILE=%PORTABLE_HOME%"

if not exist "%CLAUDE_CONFIG_DIR%" mkdir "%CLAUDE_CONFIG_DIR%"
if not exist "%PORTABLE_HOME%" mkdir "%PORTABLE_HOME%"
if not exist "%XDG_CONFIG_HOME%" mkdir "%XDG_CONFIG_HOME%"
if not exist "%XDG_DATA_HOME%" mkdir "%XDG_DATA_HOME%"
if not exist "%XDG_CACHE_HOME%" mkdir "%XDG_CACHE_HOME%"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"

:: Display Banner
echo.
echo !CYAN!    ____            __        __    __        ___    ____!RESET!
echo !CYAN!   / __ \____  ____/ /_____ _/ /_  / /__     /   ^|  /  _/!RESET!
echo !CYAN!  / /_/ / __ \/ __/ __/ __ `/ __ \/ / _ \   / /^| ^|  / /  !RESET!
echo !CYAN! / ____/ /_/ / / / /_/ /_/ / /_/ / /  __/  / ___ ^|_/ /   !RESET!
echo !CYAN!/_/    \____/_/  \__/\__,_/_.___/_/\___/  /_/  ^|_/___/   !RESET!
echo.
echo !CYAN!=========================================================!RESET!
echo   !BOLD!Claude Code - Open Source Multi-Platform!RESET!
echo !CYAN!=========================================================!RESET!
echo.

if not exist "%ENGINE_DIR%" mkdir "%ENGINE_DIR%"

goto after_install_engine_func
:install_engine
set "INSTALL_ACTION=%~1"
if "%INSTALL_ACTION%"=="" set "INSTALL_ACTION=Installing"
echo   !YELLOW![~] !INSTALL_ACTION! OpenClaude Engine...!RESET!
echo   !DIM!    This can take several minutes on slower USB drives or networks.!RESET!
echo   !DIM!    Log: %BUN_INSTALL_LOG%!RESET!
echo   !DIM!    Tip: USB 2.0 drives can look idle while bun writes many small files.!RESET!
powershell -NoProfile -ExecutionPolicy Bypass -File "%USB_ROOT%tools\install-openclaude-engine.ps1" -EngineDir "%ENGINE_DIR%" -BunCmd "%BUN_DIR%\bun.exe" -LogFile "%BUN_INSTALL_LOG%"
set "BUN_STATUS=!ERRORLEVEL!"
if not "!BUN_STATUS!"=="0" (
    echo   !RED![ERROR] OpenClaude Engine install failed ^(bun exit !BUN_STATUS!^).!RESET!
    echo   !DIM!        Check log: %BUN_INSTALL_LOG%!RESET!
    echo   !DIM!        If this only fails on USB, try a USB 3.x port/drive or copy the folder to internal storage for the first install, then copy it back.!RESET!
    pause
    exit /b 1
)
if not exist "%OC_BIN%" goto incomplete_engine
if not exist "%OC_CLI%" goto incomplete_engine
echo   !GREEN![OK] Engine installed!!RESET!
exit /b 0

:incomplete_engine
echo   !RED![ERROR] OpenClaude Engine install is incomplete.!RESET!
echo   !DIM!        Missing expected files under %OPENCLAUDE_DIR%!RESET!
pause
exit /b 1
:after_install_engine_func

:: 2. Check Bun
if not exist "%BUN_DIR%\bun.exe" (
    echo   !YELLOW![~] Bun not found for Windows-x64. Downloading...!RESET!
    echo   !DIM!    Version: v%BUN_VERSION%!RESET!
    echo   !DIM!    Download log: %BUN_DOWNLOAD_LOG%!RESET!
    if exist "%BUN_ARCHIVE%" del "%BUN_ARCHIVE%" >nul 2>&1
    if exist "%BUN_DOWNLOAD_LOG%" del "%BUN_DOWNLOAD_LOG%" >nul 2>&1
    call :download_bun
    if errorlevel 1 goto bun_download_failed
    echo   !YELLOW![~] Extracting Bun...!RESET!
    if exist "%BUN_DIR%" rmdir /s /q "%BUN_DIR%"
    mkdir "%BUN_DIR%"
    powershell -NoProfile -Command "Expand-Archive -Path '%BUN_ARCHIVE%' -DestinationPath '%BUN_DIR%' -Force"
    if errorlevel 1 (
        echo   !RED![ERROR] Failed to extract Bun!!RESET!
        del "%BUN_ARCHIVE%" >nul 2>&1
        pause
        exit /b 1
    )
    del "%BUN_ARCHIVE%"
    echo   !GREEN![OK] Bun installed to %BUN_DIR%!RESET!
)

set "PATH=%BUN_DIR%;%PATH%"

if not exist "%OC_BIN%" goto repair_engine
if not exist "%OC_CLI%" goto repair_engine
goto engine_ready
:repair_engine
if exist "%OPENCLAUDE_DIR%" (
    echo   !YELLOW![~] Incomplete OpenClaude Engine detected. Reinstalling...!RESET!
    rmdir /s /q "%OPENCLAUDE_DIR%"
)
call :install_engine "Installing"
if errorlevel 1 exit /b 1
:engine_ready

goto after_bun_download_helpers

:download_bun
echo   !YELLOW![~] Downloading Bun v%BUN_VERSION%...!RESET!
echo [%DATE% %TIME%] Downloading: %BUN_URL%>>"%BUN_DOWNLOAD_LOG%"
curl.exe --fail --location --retry 3 --retry-delay 3 --connect-timeout 20 "%BUN_URL%" --output "%BUN_ARCHIVE%" >>"%BUN_DOWNLOAD_LOG%" 2>&1
if errorlevel 1 (
    echo [%DATE% %TIME%] Bun download failed>>"%BUN_DOWNLOAD_LOG%"
    if exist "%BUN_ARCHIVE%" del "%BUN_ARCHIVE%" >nul 2>&1
    exit /b 1
)
if not exist "%BUN_ARCHIVE%" (
    echo [%DATE% %TIME%] Download finished but archive is missing>>"%BUN_DOWNLOAD_LOG%"
    exit /b 1
)
for %%A in ("%BUN_ARCHIVE%") do set "BUN_ARCHIVE_SIZE=%%~zA"
if "!BUN_ARCHIVE_SIZE!"=="0" (
    echo [%DATE% %TIME%] Downloaded archive is empty>>"%BUN_DOWNLOAD_LOG%"
    del "%BUN_ARCHIVE%" >nul 2>&1
    exit /b 1
)
echo [%DATE% %TIME%] Downloaded !BUN_ARCHIVE_SIZE! bytes>>"%BUN_DOWNLOAD_LOG%"
exit /b 0

:bun_download_failed
echo.
echo   !RED![ERROR] Automatic Bun download failed.!RESET!
echo.
echo   Please download Bun manually from:
echo   !CYAN!https://bun.sh!RESET!
echo.
echo   After installing Bun, restart OpenClaude Portable.
echo   Download log: !BUN_DOWNLOAD_LOG!
pause
exit /b 1

:after_bun_download_helpers

:: 3. Check for flags (--offline, --quick)
set "SKIP_UPDATE=0"
set "QUICK_MODE=0"
for %%A in (%*) do (
    if /I "%%A"=="--offline" set "SKIP_UPDATE=1"
    if /I "%%A"=="--quick" set "QUICK_MODE=1"
)

if !SKIP_UPDATE!==1 (
    echo   !DIM![~] Offline mode - skipping update check!RESET!
)
echo.

:: 4. Check for settings file
if exist "%ENV_FILE%" (
    findstr /C:"AI_PROVIDER=" "%ENV_FILE%" >nul
    if errorlevel 1 (
        echo   !YELLOW![INFO] Legacy configuration detected. Upgrading format...!RESET!
        del "%ENV_FILE%"
    ) else (
        goto load_settings
    )
)

:: ---------------------------------------------------------
::   PROVIDER SELECTION MENU
:: ---------------------------------------------------------
echo !CYAN!=========================================================!RESET!
echo   !BOLD!AI PROVIDER SELECTION!RESET!
echo !CYAN!=========================================================!RESET!
echo.
echo   !CYAN!1)!RESET! !BOLD!OpenRouter!RESET!   !DIM!- 200+ Free and Paid Models!RESET!  !GREEN![RECOMMENDED]!RESET!
echo   !CYAN!2)!RESET! !BOLD!NVIDIA NIM!RESET!   !DIM!- High-Speed GPU Free Tier!RESET!   !GREEN![RECOMMENDED]!RESET!
echo   !CYAN!3)!RESET! !BOLD!DeepSeek!RESET!     !DIM!- DeepSeek API (OpenAI-compatible)!RESET!
echo   !CYAN!4)!RESET! !BOLD!Gemini!RESET!       !DIM!- Google AI API!RESET!
echo   !CYAN!5)!RESET! !BOLD!Claude!RESET!       !DIM!- Anthropic API!RESET!
echo   !CYAN!6)!RESET! !BOLD!OpenAI!RESET!       !DIM!- GPT / Codex API!RESET!
echo   !CYAN!7)!RESET! !BOLD!Ollama!RESET!       !DIM!- Local Offline AI (No internet)!RESET!
echo   !CYAN!8)!RESET! !BOLD!LM Studio!RESET!    !DIM!- Local OpenAI-compatible server!RESET!
echo   !CYAN!9)!RESET! !BOLD!Custom API!RESET!    !DIM!- Any OpenAI-compatible provider!RESET!
echo.
:prompt_provider
set "PROVIDER_SEL="
set /p "PROVIDER_SEL=  Select your provider !CYAN!(1-9)!RESET!: "

if "!PROVIDER_SEL!"=="1" goto setup_openrouter
if "!PROVIDER_SEL!"=="2" goto setup_nvidia
if "!PROVIDER_SEL!"=="3" goto setup_deepseek
if "!PROVIDER_SEL!"=="4" goto setup_gemini
if "!PROVIDER_SEL!"=="5" goto setup_claude
if "!PROVIDER_SEL!"=="6" goto setup_openai
if "!PROVIDER_SEL!"=="7" goto setup_ollama
if "!PROVIDER_SEL!"=="8" goto setup_lmstudio
if "!PROVIDER_SEL!"=="9" goto setup_custom_openai
echo   !RED![ERROR] Invalid selection. Please choose 1-9.!RESET!
goto prompt_provider

:: ---------------------------------------------------------
::   OPENROUTER SETUP
:: ---------------------------------------------------------
:setup_openrouter
echo.
echo   !CYAN!--- OPENROUTER SETUP ---!RESET!
echo.
set /p "USER_API_KEY=  Enter your OpenRouter API Key: "
if "!USER_API_KEY!"=="" (
    echo   !RED![ERROR] API Key cannot be empty!!RESET!
    goto setup_openrouter
)
set "USER_API_KEY=!USER_API_KEY: =!"
:: Mask key for display
set "KEY_MASK=!USER_API_KEY:~0,6!****!USER_API_KEY:~-4!"
echo   !DIM!Key: !KEY_MASK!!RESET!
echo.
echo   !YELLOW![~] Verifying API Key... Please wait...!RESET!
powershell -NoProfile -Command "$headers = @{ 'Authorization' = 'Bearer !USER_API_KEY!' }; try { $response = Invoke-RestMethod -Uri 'https://openrouter.ai/api/v1/auth/key' -Headers $headers -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo   !RED![ERROR] Invalid or expired OpenRouter API Key!!RESET!
    goto setup_openrouter
)
echo   !GREEN![OK] Key Verified!!RESET!
echo.
echo   Do you want to use !GREEN!Free!RESET! or !YELLOW!Paid!RESET! models?
echo   !CYAN!1)!RESET! Free Models
echo   !CYAN!2)!RESET! Paid Models
:prompt_tier
set "MODEL_TIER="
set /p "MODEL_TIER=  Select category !CYAN!(1 or 2)!RESET!: "

if "!MODEL_TIER!"=="1" goto setup_free
if "!MODEL_TIER!"=="2" goto setup_paid
echo   !RED![ERROR] Invalid selection. Please choose 1 or 2.!RESET!
goto prompt_tier

:setup_free
echo.
echo   !CYAN!--- FREE MODELS ---!RESET! !DIM!(Live Fetching...)!RESET!
set "idx=1"
for /f "delims=" %%I in ('powershell -NoProfile -Command "$d = (Invoke-RestMethod 'https://openrouter.ai/api/v1/models').data; $free = $d | Where-Object { $_.id -match ':free$' } | Select-Object -First 20 -ExpandProperty id; $free"') do (
    set "FREE_MODEL_!idx!=%%I"
    echo   !CYAN!!idx!^)!RESET! %%I
    set /a "idx+=1"
)
if "!idx!"=="1" (
    echo   !YELLOW![API Error] Could not fetch models, using fallback...!RESET!
    set "FREE_MODEL_1=qwen/qwen-2.5-coder-32b-instruct:free"
    echo   !CYAN!1^)!RESET! qwen/qwen-2.5-coder-32b-instruct:free
    set /a "idx=2"
)
set "FREE_MAX=!idx!"
echo   !CYAN!!FREE_MAX!^)!RESET! !DIM!Custom Free Model...!RESET!
echo.
:prompt_free_sel
set "FREE_SEL="
set /p "FREE_SEL=  Choose a model !CYAN!(1-!FREE_MAX!)!RESET!: "
if defined FREE_SEL (
    if "!FREE_SEL!"=="!FREE_MAX!" (
        set /p "USER_MODEL=  Enter custom model string: "
    ) else (
        for %%V in (!FREE_SEL!) do set "USER_MODEL=!FREE_MODEL_%%V!"
    )
)
if "!USER_MODEL!"=="" (
    echo   !RED![ERROR] Invalid selection. Please choose 1 to !FREE_MAX!.!RESET!
    goto prompt_free_sel
)
goto save_settings_openrouter

:setup_paid
echo.
echo   !CYAN!--- PAID MODELS ---!RESET! !DIM!(Live Fetching...)!RESET!
set "idx=1"
for /f "delims=" %%I in ('powershell -NoProfile -Command "$d = (Invoke-RestMethod 'https://openrouter.ai/api/v1/models').data; $paid = $d | Where-Object { $_.id -notmatch ':free$' } | Select-Object -First 20 -ExpandProperty id; $paid"') do (
    set "PAID_MODEL_!idx!=%%I"
    echo   !CYAN!!idx!^)!RESET! %%I
    set /a "idx+=1"
)
if "!idx!"=="1" (
    echo   !YELLOW![API Error] Could not fetch models, using fallback...!RESET!
    set "PAID_MODEL_1=anthropic/claude-3.5-sonnet"
    echo   !CYAN!1^)!RESET! anthropic/claude-3.5-sonnet
    set /a "idx=2"
)
set "PAID_MAX=!idx!"
echo   !CYAN!!PAID_MAX!^)!RESET! !DIM!Custom Paid Model...!RESET!
echo.
:prompt_paid_sel
set "PAID_SEL="
set /p "PAID_SEL=  Choose a model !CYAN!(1-!PAID_MAX!)!RESET!: "
if defined PAID_SEL (
    if "!PAID_SEL!"=="!PAID_MAX!" (
        set /p "USER_MODEL=  Enter custom model string: "
    ) else (
        for %%V in (!PAID_SEL!) do set "USER_MODEL=!PAID_MODEL_%%V!"
    )
)
if "!USER_MODEL!"=="" (
    echo   !RED![ERROR] Invalid selection. Please choose 1 to !PAID_MAX!.!RESET!
    goto prompt_paid_sel
)
goto save_settings_openrouter

:save_settings_openrouter
(
    echo # ========================================================
    echo # Portable AI - Master Switchboard
    echo # ========================================================
    echo AI_PROVIDER=openai
    echo CLAUDE_CODE_USE_OPENAI=1
    echo OPENAI_API_KEY=%USER_API_KEY%
    echo OPENAI_BASE_URL=https://openrouter.ai/api/v1
    echo OPENAI_API_FORMAT=chat_completions
    echo OPENAI_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:: ---------------------------------------------------------
::   NVIDIA NIM SETUP
:: ---------------------------------------------------------
:setup_nvidia
echo.
echo   !CYAN!--- NVIDIA NIM SETUP ---!RESET!
echo.
set /p "USER_API_KEY=  Enter your NVIDIA API Key: "
if "!USER_API_KEY!"=="" (
    echo   !RED![ERROR] API Key cannot be empty!!RESET!
    goto setup_nvidia
)
set "USER_API_KEY=!USER_API_KEY: =!"
set "KEY_MASK=!USER_API_KEY:~0,6!****!USER_API_KEY:~-4!"
echo   !DIM!Key: !KEY_MASK!!RESET!
echo.
echo   !YELLOW![~] Verifying API Key... Please wait...!RESET!
powershell -NoProfile -Command "$headers = @{ 'Authorization' = 'Bearer !USER_API_KEY!' }; try { $response = Invoke-RestMethod -Uri 'https://integrate.api.nvidia.com/v1/models' -Headers $headers -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo   !RED![ERROR] Invalid or expired NVIDIA API Key!!RESET!
    goto setup_nvidia
)
echo   !GREEN![OK] Key Verified!!RESET!
echo.
echo   !CYAN!--- NVIDIA MODELS ---!RESET! !DIM!(Live + Curated)!RESET!
set "idx=1"
for %%M in (
    "moonshotai/kimi-k2-instruct" "moonshotai/kimi-k2-thinking" "z-ai/glm4.7"
    "deepseek-ai/deepseek-v3.2" "deepseek-ai/deepseek-v3.1-terminus" "stepfun-ai/step-3.5-flash"
    "mistralai/mistral-large-3-675b-instruct-2512" "qwen/qwen3-coder-480b-a35b-instruct"
    "mistralai/mistral-nemotron" "bytedance/seed-oss-36b-instruct" "mistralai/mamba-codestral-7b-v0.1"
    "google/gemma-7b" "tiiuae/falcon3-7b-instruct" "minimaxai/minimax-m2.7"
) do (
    set "NVIDIA_MODEL_!idx!=%%~M"
    echo   !CYAN!!idx!^)!RESET! %%~M
    set /a "idx+=1"
)
for /f "delims=" %%I in ('powershell -NoProfile -Command "$headers = @{ 'Authorization' = 'Bearer !USER_API_KEY!' }; try { $d = (Invoke-RestMethod -Uri 'https://integrate.api.nvidia.com/v1/models' -Headers $headers).data; $d | Select-Object -ExpandProperty id | Select-Object -First 40 } catch { }"') do (
    set "EXISTS=0"
    for /L %%K in (1,1,14) do (
        if "%%I"=="!NVIDIA_MODEL_%%K!" set "EXISTS=1"
    )
    if !EXISTS!==0 (
        set "NVIDIA_MODEL_!idx!=%%I"
        echo   !CYAN!!idx!^)!RESET! %%I
        set /a "idx+=1"
    )
)
if "!idx!"=="1" (
    echo   !YELLOW![API Error] Could not fetch models, using fallback...!RESET!
    set "NVIDIA_MODEL_1=meta/llama-3.1-70b-instruct"
    echo   !CYAN!1^)!RESET! meta/llama-3.1-70b-instruct
    set /a "idx=2"
)
set "MAX_IDX=!idx!"
echo   !CYAN!!MAX_IDX!^)!RESET! !DIM!Custom NVIDIA Model...!RESET!
echo.
:prompt_nvidia_sel
set "MODEL_SEL="
set /p "MODEL_SEL=  Choose a model !CYAN!(1-!MAX_IDX!)!RESET!: "
if defined MODEL_SEL (
    if "!MODEL_SEL!"=="!MAX_IDX!" (
        set /p "USER_MODEL=  Enter custom model string: "
    ) else (
        for %%V in (!MODEL_SEL!) do set "USER_MODEL=!NVIDIA_MODEL_%%V!"
    )
)
if "!USER_MODEL!"=="" (
    echo   !RED![ERROR] Invalid selection. Please choose 1 to !MAX_IDX!.!RESET!
    goto prompt_nvidia_sel
)

:save_settings_nvidia
(
    echo AI_PROVIDER=openai
    echo CLAUDE_CODE_USE_OPENAI=1
    echo OPENAI_API_KEY=%USER_API_KEY%
    echo OPENAI_BASE_URL=https://integrate.api.nvidia.com/v1
    echo OPENAI_API_FORMAT=chat_completions
    echo OPENAI_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:: ---------------------------------------------------------
::   DEEPSEEK SETUP
:: ---------------------------------------------------------
:setup_deepseek
echo.
echo   !CYAN!--- DEEPSEEK SETUP ---!RESET!
echo.
set /p "USER_API_KEY=  Enter your DeepSeek API Key: "
if "!USER_API_KEY!"=="" (
    echo   !RED![ERROR] API Key cannot be empty!!RESET!
    goto setup_deepseek
)
set "USER_API_KEY=!USER_API_KEY: =!"
set "KEY_MASK=!USER_API_KEY:~0,6!****!USER_API_KEY:~-4!"
echo   !DIM!Key: !KEY_MASK!!RESET!
echo.
echo   !YELLOW![~] Verifying API Key... Please wait...!RESET!
powershell -NoProfile -Command "$headers = @{ 'Authorization' = 'Bearer !USER_API_KEY!' }; try { $response = Invoke-RestMethod -Uri 'https://api.deepseek.com/models' -Headers $headers -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo   !RED![ERROR] Invalid or expired DeepSeek API Key!!RESET!
    goto setup_deepseek
)
echo   !GREEN![OK] Key Verified!!RESET!
echo.
echo   !CYAN!--- DEEPSEEK MODELS ---!RESET! !DIM!(Live Fetching...)!RESET!
set "idx=1"
for /f "delims=" %%I in ('powershell -NoProfile -Command "$headers = @{ 'Authorization' = 'Bearer !USER_API_KEY!' }; try { $d = (Invoke-RestMethod -Uri 'https://api.deepseek.com/models' -Headers $headers).data; $d | Select-Object -ExpandProperty id } catch { }"') do (
    set "DEEPSEEK_MODEL_!idx!=%%I"
    echo   !CYAN!!idx!^)!RESET! %%I
    set /a "idx+=1"
)
if "!idx!"=="1" (
    echo   !YELLOW![API Error] Could not fetch models, using fallback...!RESET!
    set "DEEPSEEK_MODEL_1=deepseek-v4-flash"
    echo   !CYAN!1^)!RESET! deepseek-v4-flash
    set "DEEPSEEK_MODEL_2=deepseek-v4-pro"
    echo   !CYAN!2^)!RESET! deepseek-v4-pro
    set /a "idx=3"
)
set "MAX_IDX=!idx!"
echo   !CYAN!!MAX_IDX!^)!RESET! !DIM!Custom DeepSeek Model...!RESET!
echo.
:prompt_deepseek_sel
set "MODEL_SEL="
set /p "MODEL_SEL=  Choose a model !CYAN!(1-!MAX_IDX!)!RESET! [Enter for 1]: "
if not defined MODEL_SEL set "MODEL_SEL=1"
if "!MODEL_SEL!"=="" set "MODEL_SEL=1"
if "!MODEL_SEL!"=="!MAX_IDX!" (
    set /p "USER_MODEL=  Enter custom model string: "
) else (
    for %%V in (!MODEL_SEL!) do set "USER_MODEL=!DEEPSEEK_MODEL_%%V!"
)
if "!USER_MODEL!"=="" (
    echo   !RED![ERROR] Invalid selection.!RESET!
    goto prompt_deepseek_sel
)
(
    echo AI_PROVIDER=openai
    echo CLAUDE_CODE_USE_OPENAI=1
    echo OPENAI_API_KEY=%USER_API_KEY%
    echo OPENAI_BASE_URL=https://api.deepseek.com
    echo OPENAI_API_FORMAT=chat_completions
    echo OPENAI_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:: ---------------------------------------------------------
::   GEMINI SETUP
:: ---------------------------------------------------------
:setup_gemini
echo.
echo   !CYAN!--- GEMINI SETUP ---!RESET!
echo.
set /p "USER_API_KEY=  Enter your Gemini API Key: "
if "!USER_API_KEY!"=="" (
    echo   !RED![ERROR] API Key cannot be empty!!RESET!
    goto setup_gemini
)
set "USER_API_KEY=!USER_API_KEY: =!"
set "KEY_MASK=!USER_API_KEY:~0,6!****!USER_API_KEY:~-4!"
echo   !DIM!Key: !KEY_MASK!!RESET!
echo.
echo   !YELLOW![~] Verifying API Key... Please wait...!RESET!
powershell -NoProfile -Command "try { $response = Invoke-RestMethod -Uri 'https://generativelanguage.googleapis.com/v1beta/models?key=!USER_API_KEY!' -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo   !RED![ERROR] Invalid or expired Gemini API Key!!RESET!
    goto setup_gemini
)
echo   !GREEN![OK] Key Verified!!RESET!
echo.
echo   !CYAN!--- GEMINI MODELS ---!RESET! !DIM!(Live Fetching...)!RESET!
set "idx=1"
    set "FETCH_CMD=$d = (Invoke-RestMethod 'https://generativelanguage.googleapis.com/v1alpha/models?key=!USER_API_KEY!').models; if ($null -ne $d) { $d | Where-Object { $_.supportedGenerationMethods -contains 'generateContent' -and $_.name -notmatch 'vision|embedding|banana|lyria|robot|research|computer' } | Select-Object -ExpandProperty name | ForEach-Object { $_.Replace('models/', '') } | Select-Object -First 40 }"
for /f "delims=" %%I in ('powershell -NoProfile -Command "!FETCH_CMD!"') do (
    set "GEMINI_MODEL_!idx!=%%I"
    echo   !CYAN!!idx!^)!RESET! %%I
    set /a "idx+=1"
)
if "!idx!"=="1" (
    echo   !YELLOW![API Error] Could not fetch models, using fallback...!RESET!
    set "GEMINI_MODEL_1=gemini-2.5-pro"
    echo   !CYAN!1^)!RESET! gemini-2.5-pro
    set /a "idx=2"
)
set "MAX_IDX=!idx!"
echo   !CYAN!!MAX_IDX!^)!RESET! !DIM!Custom Gemini Model...!RESET!
echo.
:prompt_gemini_sel
set "MODEL_SEL="
set /p "MODEL_SEL=  Choose a model !CYAN!(1-!MAX_IDX!)!RESET! [Enter for 1]: "
if not defined MODEL_SEL set "MODEL_SEL=1"
if "!MODEL_SEL!"=="" set "MODEL_SEL=1"
if "!MODEL_SEL!"=="!MAX_IDX!" (
    set /p "USER_MODEL=  Enter custom model string: "
) else (
    for %%V in (!MODEL_SEL!) do set "USER_MODEL=!GEMINI_MODEL_%%V!"
)
if "!USER_MODEL!"=="" (
    echo   !RED![ERROR] Invalid selection.!RESET!
    goto prompt_gemini_sel
)
(
    echo AI_PROVIDER=gemini
    echo CLAUDE_CODE_USE_GEMINI=1
    echo GEMINI_API_KEY=%USER_API_KEY%
    echo GEMINI_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:: ---------------------------------------------------------
::   CLAUDE SETUP
:: ---------------------------------------------------------
:setup_claude
echo.
echo   !CYAN!--- CLAUDE SETUP ---!RESET!
echo.
set /p "USER_API_KEY=  Enter your Anthropic API Key: "
if "!USER_API_KEY!"=="" (
    echo   !RED![ERROR] API Key cannot be empty!!RESET!
    goto setup_claude
)
set "USER_API_KEY=!USER_API_KEY: =!"
set "KEY_MASK=!USER_API_KEY:~0,6!****!USER_API_KEY:~-4!"
echo   !DIM!Key: !KEY_MASK!!RESET!
echo.
echo   !YELLOW![~] Verifying API Key... Please wait...!RESET!
powershell -NoProfile -Command "$headers = @{ 'x-api-key' = '!USER_API_KEY!'; 'anthropic-version' = '2023-06-01' }; try { $response = Invoke-RestMethod -Uri 'https://api.anthropic.com/v1/models' -Headers $headers -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo   !RED![ERROR] Invalid or expired Anthropic API Key!!RESET!
    goto setup_claude
)
echo   !GREEN![OK] Key Verified!!RESET!
echo.
set /p "USER_MODEL=  Enter Model !DIM!(Enter for claude-3-7-sonnet-20250219)!RESET!: "
if "%USER_MODEL%"=="" set "USER_MODEL=claude-3-7-sonnet-20250219"
(
    echo AI_PROVIDER=anthropic
    echo ANTHROPIC_API_KEY=%USER_API_KEY%
    echo ANTHROPIC_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:: ---------------------------------------------------------
::   OLLAMA SETUP
:: ---------------------------------------------------------
:setup_ollama
echo.
echo   !CYAN!--- OLLAMA LOCAL SETUP ---!RESET!
echo.
set /p "USER_MODEL=  Enter local model !DIM!(Enter for llama3.2:3b)!RESET!: "
if "%USER_MODEL%"=="" set "USER_MODEL=llama3.2:3b"
(
    echo AI_PROVIDER=ollama
    echo CLAUDE_CODE_USE_OPENAI=1
    echo OPENAI_API_KEY=ollama
    echo OPENAI_BASE_URL=http://localhost:11434/v1
    echo OPENAI_API_FORMAT=chat_completions
    echo OPENAI_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:: ---------------------------------------------------------
::   LM STUDIO SETUP
:: ---------------------------------------------------------
:setup_lmstudio
echo.
echo   !CYAN!--- LM STUDIO LOCAL SETUP ---!RESET!
echo.
echo   Start LM Studio first, load a model, then open !BOLD!Developer ^> Local Server!RESET!.
echo   Turn the server on and keep the default OpenAI-compatible URL:
echo   !GREEN!http://localhost:1234/v1!RESET!
echo.
set "USER_API_KEY=lm-studio"
set /p "LM_BASE_URL=  Base URL [http://localhost:1234/v1]: "
if "!LM_BASE_URL!"=="" set "LM_BASE_URL=http://localhost:1234/v1"
if "!LM_BASE_URL:~-1!"=="/" set "LM_BASE_URL=!LM_BASE_URL:~0,-1!"
echo.
echo   !YELLOW![~] Checking LM Studio server...!RESET!
powershell -NoProfile -Command "try { Invoke-RestMethod -Uri '!LM_BASE_URL!/models' -Headers @{ 'Authorization' = 'Bearer lm-studio' } -ErrorAction Stop | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo   !YELLOW![WARN] Could not reach LM Studio at !LM_BASE_URL!/models.!RESET!
    echo   Make sure LM Studio is open, a model is loaded, and the local server is running.
    set /p "SAVE_ANYWAY=  Continue with manual model entry? (y/N): "
    if /I not "!SAVE_ANYWAY!"=="Y" goto setup_lmstudio
)
echo.
echo   !CYAN!--- LM STUDIO MODELS ---!RESET! !DIM!(Loaded models from /v1/models)!RESET!
set "idx=1"
for /f "delims=" %%I in ('powershell -NoProfile -Command "try { $d = (Invoke-RestMethod -Uri '!LM_BASE_URL!/models' -Headers @{ 'Authorization' = 'Bearer lm-studio' }).data; $d | Select-Object -ExpandProperty id } catch { }"') do (
    set "LM_MODEL_!idx!=%%I"
    echo   !CYAN!!idx!^)!RESET! %%I
    set /a "idx+=1"
)
set "MAX_IDX=!idx!"
echo   !CYAN!!MAX_IDX!^)!RESET! !DIM!Manual model name...!RESET!
echo.
:prompt_lmstudio_sel
set "MODEL_SEL="
set /p "MODEL_SEL=  Choose a model !CYAN!(1-!MAX_IDX!)!RESET! [Enter for 1]: "
if not defined MODEL_SEL set "MODEL_SEL=1"
if "!MODEL_SEL!"=="" set "MODEL_SEL=1"
if "!MODEL_SEL!"=="!MAX_IDX!" (
    set /p "USER_MODEL=  Enter model identifier shown in LM Studio: "
) else (
    for %%V in (!MODEL_SEL!) do set "USER_MODEL=!LM_MODEL_%%V!"
)
if "!USER_MODEL!"=="" (
    echo   !RED![ERROR] Model cannot be empty.!RESET!
    goto prompt_lmstudio_sel
)
(
    echo AI_PROVIDER=openai
    echo CLAUDE_CODE_USE_OPENAI=1
    echo OPENAI_API_KEY=%USER_API_KEY%
    echo OPENAI_BASE_URL=%LM_BASE_URL%
    echo OPENAI_API_FORMAT=chat_completions
    echo OPENAI_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:: ---------------------------------------------------------
::   CUSTOM OPENAI-COMPATIBLE SETUP
:: ---------------------------------------------------------
:setup_custom_openai
echo.
echo   !CYAN!--- CUSTOM OPENAI-COMPATIBLE SETUP ---!RESET!
echo.
echo   Use this for providers that expose OpenAI-style endpoints like /v1/models and /v1/chat/completions.
set /p "CUSTOM_BASE_URL=  Base URL (example: https://provider.example.com/v1): "
if "!CUSTOM_BASE_URL!"=="" (
    echo   !RED![ERROR] Base URL cannot be empty!!RESET!
    goto setup_custom_openai
)
if "!CUSTOM_BASE_URL:~-1!"=="/" set "CUSTOM_BASE_URL=!CUSTOM_BASE_URL:~0,-1!"
set /p "USER_API_KEY=  API Key (Enter for none/local): "
if "!USER_API_KEY!"=="" set "USER_API_KEY=not-needed"
set "USER_API_KEY=!USER_API_KEY: =!"
echo.
echo   !YELLOW![~] Checking /models endpoint...!RESET!
powershell -NoProfile -Command "$headers = @{ 'Authorization' = 'Bearer !USER_API_KEY!' }; try { Invoke-RestMethod -Uri '!CUSTOM_BASE_URL!/models' -Headers $headers -ErrorAction Stop | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo   !YELLOW![WARN] Could not verify !CUSTOM_BASE_URL!/models.!RESET!
    set /p "SAVE_ANYWAY=  Continue with manual model entry? (y/N): "
    if /I not "!SAVE_ANYWAY!"=="Y" goto setup_custom_openai
)
echo.
echo   !CYAN!--- CUSTOM MODELS ---!RESET! !DIM!(Live Fetching...)!RESET!
set "idx=1"
for /f "delims=" %%I in ('powershell -NoProfile -Command "$headers = @{ 'Authorization' = 'Bearer !USER_API_KEY!' }; try { $d = (Invoke-RestMethod -Uri '!CUSTOM_BASE_URL!/models' -Headers $headers).data; $d | Select-Object -ExpandProperty id } catch { }"') do (
    set "CUSTOM_MODEL_!idx!=%%I"
    echo   !CYAN!!idx!^)!RESET! %%I
    set /a "idx+=1"
)
set "MAX_IDX=!idx!"
echo   !CYAN!!MAX_IDX!^)!RESET! !DIM!Manual model name...!RESET!
echo.
:prompt_custom_openai_sel
set "MODEL_SEL="
set /p "MODEL_SEL=  Choose a model !CYAN!(1-!MAX_IDX!)!RESET! [Enter for manual]: "
if not defined MODEL_SEL set "MODEL_SEL=!MAX_IDX!"
if "!MODEL_SEL!"=="" set "MODEL_SEL=!MAX_IDX!"
if "!MODEL_SEL!"=="!MAX_IDX!" (
    set /p "USER_MODEL=  Enter model string: "
) else (
    for %%V in (!MODEL_SEL!) do set "USER_MODEL=!CUSTOM_MODEL_%%V!"
)
if "!USER_MODEL!"=="" (
    echo   !RED![ERROR] Model cannot be empty.!RESET!
    goto prompt_custom_openai_sel
)
(
    echo AI_PROVIDER=openai
    echo CLAUDE_CODE_USE_OPENAI=1
    echo OPENAI_API_KEY=%USER_API_KEY%
    echo OPENAI_BASE_URL=%CUSTOM_BASE_URL%
    echo OPENAI_API_FORMAT=chat_completions
    echo OPENAI_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:: ---------------------------------------------------------
::   OPENAI SETUP
:: ---------------------------------------------------------
:setup_openai
echo.
echo   !CYAN!--- OPENAI / CODEX SETUP ---!RESET!
echo.
set /p "USER_API_KEY=  Enter your OpenAI API Key: "
if "!USER_API_KEY!"=="" (
    echo   !RED![ERROR] API Key cannot be empty!!RESET!
    goto setup_openai
)
set "USER_API_KEY=!USER_API_KEY: =!"
set "KEY_MASK=!USER_API_KEY:~0,6!****!USER_API_KEY:~-4!"
echo   !DIM!Key: !KEY_MASK!!RESET!
echo.
echo   !YELLOW![~] Verifying API Key... Please wait...!RESET!
powershell -NoProfile -Command "$headers = @{ 'Authorization' = 'Bearer !USER_API_KEY!' }; try { $response = Invoke-RestMethod -Uri 'https://api.openai.com/v1/models' -Headers $headers -ErrorAction Stop; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo   !RED![ERROR] Invalid or expired OpenAI API Key!!RESET!
    goto setup_openai
)
echo   !GREEN![OK] Key Verified!!RESET!
echo.
set /p "USER_MODEL=  Enter Model !DIM!(Enter for gpt-4o)!RESET!: "
if "%USER_MODEL%"=="" set "USER_MODEL=gpt-4o"
(
    echo AI_PROVIDER=openai
    echo CLAUDE_CODE_USE_OPENAI=1
    echo OPENAI_API_KEY=%USER_API_KEY%
    echo OPENAI_BASE_URL=https://api.openai.com/v1
    echo OPENAI_API_FORMAT=chat_completions
    echo OPENAI_MODEL=%USER_MODEL%
    echo AI_DISPLAY_MODEL=%USER_MODEL%
) > "%ENV_FILE%"
goto finish_setup

:finish_setup
echo.
echo   !GREEN![OK] Settings saved!!RESET!
echo.

:: ---------------------------------------------------------
::   LOAD SETTINGS + WELCOME BACK SCREEN
:: ---------------------------------------------------------
:load_settings
:: Load the settings from ai_settings.env
for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    set "%%A=%%~B"
)

if not "!AI_PROVIDER!"=="anthropic" (
    set "ANTHROPIC_API_KEY="
)
if /I "!AI_PROVIDER!"=="openai" (
    if defined OPENAI_BASE_URL (
        if not defined OPENAI_API_FORMAT set "OPENAI_API_FORMAT=chat_completions"
    )
)
set "CLAUDE_CODE_PROVIDER_PROFILE_ENV_APPLIED=1"
set "CLAUDE_CODE_PROVIDER_PROFILE_ENV_APPLIED_ID=portable-env"

:: Friendly provider name
set "PROVIDER_NAME=!AI_PROVIDER!"
if "!AI_PROVIDER!"=="openai" (
    if defined OPENAI_BASE_URL (
        echo !OPENAI_BASE_URL! | findstr /C:"openrouter" >nul && set "PROVIDER_NAME=OpenRouter"
        echo !OPENAI_BASE_URL! | findstr /C:"integrate.api.nvidia.com" >nul && set "PROVIDER_NAME=NVIDIA NIM"
        echo !OPENAI_BASE_URL! | findstr /C:"api.deepseek.com" >nul && set "PROVIDER_NAME=DeepSeek"
        echo !OPENAI_BASE_URL! | findstr /C:"api.openai.com" >nul && set "PROVIDER_NAME=OpenAI"
        echo !OPENAI_BASE_URL! | findstr /C:"localhost:11434" >nul && set "PROVIDER_NAME=Ollama"
        echo !OPENAI_BASE_URL! | findstr /C:"localhost:1234" >nul && set "PROVIDER_NAME=LM Studio"
        if "!PROVIDER_NAME!"=="openai" set "PROVIDER_NAME=Custom OpenAI-Compatible"
    )
)
if "!AI_PROVIDER!"=="gemini" set "PROVIDER_NAME=Google Gemini"
if "!AI_PROVIDER!"=="anthropic" set "PROVIDER_NAME=Anthropic Claude"
if "!AI_PROVIDER!"=="ollama" set "PROVIDER_NAME=Ollama (Local)"

title Portable AI USB - !PROVIDER_NAME! - !AI_DISPLAY_MODEL!

echo !CYAN!=========================================================!RESET!
echo   !BOLD!Claude Code - Ready (Multi-Platform)!RESET!
echo !CYAN!=========================================================!RESET!
echo.
echo   !BOLD!Provider!RESET! : !GREEN!!PROVIDER_NAME!!RESET!
echo   !BOLD!Model!RESET!    : !GREEN!!AI_DISPLAY_MODEL!!RESET!
echo   !BOLD!Data!RESET!     : !DIM!Portable Mode (No PC Leaks)!RESET!
echo.
echo !CYAN!=========================================================!RESET!
echo.

:prompt_launch_mode
:: Quick mode: skip menu, go straight to limitless
if !QUICK_MODE!==1 (
    echo   !RED!!BOLD!QUICK LAUNCH - Limitless Mode!RESET!
    goto launch_limitless
)
echo   !BOLD!Select Action:!RESET!
echo   🚀 !CYAN!1)!RESET! !GREEN!OpenClaude!RESET!    !DIM!- AI coding agent (Normal / Limitless)!RESET!
echo   🔧 !CYAN!2)!RESET! !BOLD!Kilo CLI!RESET!        !DIM!- AI coding agent!RESET!
echo   !DIM!─────────────────────────────────────────────────────────!RESET!
echo   📊 !CYAN!3)!RESET! !BOLD!Open Dashboard!RESET!  !DIM!- Web UI at http://localhost:3000!RESET!
echo   ⚙️  !CYAN!4)!RESET! !BOLD!Change Provider!RESET! !DIM!- Switch AI provider or API Key!RESET!
echo.
echo   !DIM!  Auto-launching in 10 seconds... press a key to choose.!RESET!
echo.
set /p "=  Select action (1-4): " <nul
choice /c 1234 /n /t 10 /d 1
set "LAUNCH_MODE=!ERRORLEVEL!"
:menu_done
echo.

if "!LAUNCH_MODE!"=="1" goto launch_openclaude
if "!LAUNCH_MODE!"=="2" goto launch_kilo
if "!LAUNCH_MODE!"=="3" (
    echo.
    call "%USB_ROOT%tools\Open_Dashboard.bat"
    exit /b
)
if "!LAUNCH_MODE!"=="4" (
    echo.
    call "%USB_ROOT%tools\Change_Provider.bat"
    exit /b
)
echo   !RED![ERROR] Invalid selection.!RESET!
echo.
goto prompt_launch_mode

:launch_kilo
echo.
pushd "%ENGINE_DIR%"
if not exist "node_modules\@kilocode\cli" (
    echo   !YELLOW![~] Installing Kilo CLI via bun...!RESET!
    "%BUN_DIR%\bun.exe" install @kilocode/cli
    if errorlevel 1 (
        echo   !RED![ERROR] Kilo CLI install failed.!RESET!
        popd
        pause
        goto prompt_launch_mode
    )
    echo   !GREEN![OK] Kilo CLI installed!RESET!
) else (
    echo.
    echo   !GREEN![OK] Kilo CLI already installed.!RESET!
    echo   !CYAN!1^)!RESET! Launch
    echo   !CYAN!2^)!RESET! Update
    choice /c 12 /n /t 10 /d 1
    if errorlevel 2 (
        echo   !YELLOW![~] Updating Kilo CLI...!RESET!
        "%BUN_DIR%\bun.exe" install @kilocode/cli
        if errorlevel 1 (
            echo   !RED![ERROR] Kilo CLI update failed.!RESET!
            popd
            pause
            goto prompt_launch_mode
        )
        echo   !GREEN![OK] Kilo CLI updated!RESET!
    )
)
set "XDG_CONFIG_HOME=%DATA_DIR%\config"
"%BUN_DIR%\bun.exe" x kilo
popd
exit /b

:launch_openclaude
echo.
echo   !GREEN![OK] OpenClaude selected.!RESET!
if not exist "%OC_BIN%" (
    echo   !YELLOW![~] OpenClaude Engine not found. Installing...!RESET!
    call :install_engine "Installing"
    if errorlevel 1 (
        pause
        goto prompt_launch_mode
    )
) else (
    echo.
    echo   !CYAN!1^)!RESET! Normal Mode
    echo   !CYAN!2^)!RESET! Limitless Mode
    echo   !CYAN!3^)!RESET! Update Engine
    choice /c 123 /n /t 15 /d 1
    set "OC_ACTION=!ERRORLEVEL!"
    if "!OC_ACTION!"=="3" (
        echo   !YELLOW![~] Updating OpenClaude Engine...!RESET!
        call :install_engine "Updating"
        if errorlevel 1 (
            pause
            goto prompt_launch_mode
        )
        echo   !GREEN![OK] Engine updated!RESET!
    )
    if "!OC_ACTION!"=="2" (
        set "CMD_ARGS=--dangerously-skip-permissions"
        goto do_launch
    )
    set "CMD_ARGS="
    goto do_launch
)
set "CMD_ARGS="
goto do_launch

:do_launch
if not "!AI_PROVIDER!"=="ollama" goto skip_ollama_start
if not exist "%DATA_DIR%\ollama\ollama.exe" goto skip_ollama_start

echo   !CYAN![~] Starting Local Ollama Server...!RESET!
set "OLLAMA_MODELS=%DATA_DIR%\ollama\data"
start "Ollama Portable" /B /MIN "%DATA_DIR%\ollama\ollama.exe" serve >nul 2>&1
timeout /t 3 /nobreak >nul
echo   !GREEN![OK] Ollama running!RESET!

:skip_ollama_start


echo   !CYAN![~] Starting AI Engine...!RESET!
echo.

set "PROVIDER_ARGS="
if /I "!AI_PROVIDER!"=="anthropic" set "PROVIDER_ARGS=--provider anthropic"
if /I "!AI_PROVIDER!"=="gemini" set "PROVIDER_ARGS=--provider gemini"
if /I "!AI_PROVIDER!"=="ollama" set "PROVIDER_ARGS=--provider ollama"
if /I "!AI_PROVIDER!"=="openai" (
    echo !OPENAI_BASE_URL! | findstr /C:"integrate.api.nvidia.com" >nul && set "PROVIDER_ARGS=--provider nvidia-nim"
)
set "MODEL_ARGS="
if defined OPENAI_MODEL set "MODEL_ARGS=--model !OPENAI_MODEL!"
if defined GEMINI_MODEL set "MODEL_ARGS=--model !GEMINI_MODEL!"
if defined ANTHROPIC_MODEL set "MODEL_ARGS=--model !ANTHROPIC_MODEL!"
set "SETTINGS_ARGS=--setting-sources local"

pushd "%ENGINE_DIR%"
if exist "%OC_BIN%" goto use_oc_bin
echo   !RED![ERROR] OpenClaude Engine is missing. Restart START.bat to repair the install.!RESET!
goto engine_done
:use_oc_bin
call "%BUN_DIR%\bun.exe" "%OC_BIN%" !SETTINGS_ARGS! !PROVIDER_ARGS! !MODEL_ARGS! !CMD_ARGS!
:engine_done
popd

if not "!AI_PROVIDER!"=="ollama" goto skip_ollama_stop
if not exist "%DATA_DIR%\ollama\ollama.exe" goto skip_ollama_stop
echo.
echo   !CYAN![~] Stopping Local Ollama Server...!RESET!
taskkill /F /IM ollama.exe >nul 2>&1
:skip_ollama_stop

goto :eof
