@echo off
setlocal enabledelayedexpansion

:: Locate project root (parent of bin\)
set "BIN_DIR=%~dp0"
set "ROOT=%BIN_DIR%..\"
set "ENGINE_DIR=%ROOT%engine"
set "DATA_DIR=%ROOT%data"

:: Check Bun
set "BUN_EXE=%ENGINE_DIR%\bun-windows-x64\bun.exe"
if not exist "%BUN_EXE%" (
    echo [ERROR] Bun not found at %BUN_EXE%
    echo Run START.bat first to download Bun.
    pause
    exit /b 1
)

:: Set up portable environment
set "CLAUDE_CONFIG_DIR=%DATA_DIR%\openclaude"
set "XDG_CONFIG_HOME=%DATA_DIR%\config"
set "XDG_DATA_HOME=%DATA_DIR%\app_data"
set "XDG_CACHE_HOME=%DATA_DIR%\cache"
set "APPDATA=%DATA_DIR%\app_data"
set "LOCALAPPDATA=%DATA_DIR%\local_app_data"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%HOME%"
set "CLAUDE_CODE_PROVIDER_PROFILE_ENV_APPLIED=1"
set "CLAUDE_CODE_PROVIDER_PROFILE_ENV_APPLIED_ID=portable-env"
set "PATH=%ENGINE_DIR%\bun-windows-x64;%PATH%"

:: Load settings from ai_settings.env
set "ENV_FILE=%DATA_DIR%\ai_settings.env"
if not exist "%ENV_FILE%" (
    echo [ERROR] No settings file found at %ENV_FILE%
    echo Run START.bat first to configure your AI provider.
    pause
    exit /b 1
)
for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    set "%%A=%%B"
)

:: Check OpenClaude engine
set "OC_BIN=%ENGINE_DIR%\node_modules\@gitlawb\openclaude\bin\openclaude"
if not exist "%OC_BIN%" (
    echo [ERROR] OpenClaude engine not found.
    echo Run START.bat to install it.
    pause
    exit /b 1
)

:: Build launch arguments
set "ARGS=--setting-sources local"
if not "%OPENAI_MODEL%"=="" set "ARGS=%ARGS% --model %OPENAI_MODEL%"
echo %OPENAI_BASE_URL% | findstr /C:"integrate.api.nvidia.com" >nul && set "ARGS=%ARGS% --provider nvidia-nim"

:: Pass through user arguments
set "ARGS=%ARGS% %*"

:: Launch
pushd "%ENGINE_DIR%"
call "%BUN_EXE%" "%OC_BIN%" %ARGS%
popd
exit /b %ERRORLEVEL%
