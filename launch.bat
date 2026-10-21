@echo off
rem OpenClaude Portable - Windows launcher.
rem Usage:  launch.bat [openclaude args]      launch.bat --portable-update
setlocal
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "P=%ROOT%\profile"
set "APP=%ROOT%\app\win"
set "NODE_DIR=%ROOT%\runtime\win\node"
set "RG_DIR=%ROOT%\runtime\win\rg"
set "GIT_DIR=%ROOT%\runtime\win\git"

rem --- Redirect everything the app might write onto the drive (this process only) ---
set "USERPROFILE=%P%\home"
set "HOME=%P%\home"
set "APPDATA=%P%\appdata"
set "LOCALAPPDATA=%P%\localappdata"
set "XDG_CONFIG_HOME=%P%\config"
set "XDG_DATA_HOME=%P%\data"
set "XDG_CACHE_HOME=%ROOT%\cache"
set "TEMP=%ROOT%\temp"
set "TMP=%ROOT%\temp"
set "npm_config_cache=%ROOT%\cache\npm"
set "npm_config_userconfig=%P%\home\.npmrc"
set "npm_config_update_notifier=false"
set "OPENCLAUDE_CONFIG_DIR=%P%\openclaude"
set "CLAUDE_CONFIG_DIR=%P%\openclaude"
set "CLAUDE_CODE_GIT_BASH_PATH=%GIT_DIR%\bin\bash.exe"

rem --- No auto-update / telemetry (an auto-update could install outside the drive) ---
set "DISABLE_AUTOUPDATER=1"
set "DISABLE_TELEMETRY=1"
set "DISABLE_ERROR_REPORTING=1"
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"

set "PATH=%NODE_DIR%;%RG_DIR%;%GIT_DIR%\cmd;%PATH%"

for %%D in ("%USERPROFILE%" "%APPDATA%" "%LOCALAPPDATA%" "%XDG_CONFIG_HOME%" "%XDG_DATA_HOME%" "%XDG_CACHE_HOME%" "%TEMP%" "%npm_config_cache%" "%OPENCLAUDE_CONFIG_DIR%" "%ROOT%\workspace" "%APP%") do if not exist %%D mkdir %%D

set "NEED="
set "OC_UPDATE="
if /i "%~1"=="--portable-update" set "OC_UPDATE=1"
if defined OC_UPDATE set "NEED=1"
if not exist "%APP%\entry.txt" set "NEED=1"
if not exist "%GIT_DIR%\bin\bash.exe" set "NEED=1"

if defined NEED (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\setup.ps1"
  if errorlevel 1 (
    echo.
    echo Setup failed. See the messages above.
    pause
    exit /b 1
  )
)

if defined OC_UPDATE (
  echo Update complete.
  call :cleanup
  exit /b 0
)

set /p ENTRY=<"%APP%\entry.txt"
cd /d "%ROOT%\workspace"
"%NODE_DIR%\node.exe" "%APP%\%ENTRY%" %*
set "RC=%errorlevel%"
call :cleanup
exit /b %RC%

:cleanup
cd /d "%ROOT%"
rd /s /q "%TEMP%" >nul 2>&1
mkdir "%TEMP%" >nul 2>&1
exit /b 0
