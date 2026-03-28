@echo off
setlocal EnableExtensions

set "MOD_NAME=BetterLootMarkers"
set "ROOT_DIR=%~dp0"

REM ---------------------------------------------------------------------------
REM Deploy target: CET mods folder for this mod.
REM Override by setting BETTERLOOT_DEPLOY_TARGET before running, e.g.:
REM   set BETTERLOOT_DEPLOY_TARGET=C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods\%MOD_NAME%
REM   deploy.bat
REM ---------------------------------------------------------------------------
if not defined BETTERLOOT_DEPLOY_TARGET (
  set "BETTERLOOT_DEPLOY_TARGET=%ProgramFiles(x86)%\GOG Galaxy\Games\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods\%MOD_NAME%"
)

set "DEST=%BETTERLOOT_DEPLOY_TARGET%"

echo.
echo Deploying to:
echo   %DEST%
echo.

if not exist "%DEST%" (
  echo ERROR: Deploy folder does not exist. Create it or set BETTERLOOT_DEPLOY_TARGET.
  echo.
  pause
  exit /b 1
)

echo [1/2] Copying mod files...
copy /y "%ROOT_DIR%init.lua" "%DEST%\" >nul
if errorlevel 1 (
  echo Failed to copy init.lua
  pause
  exit /b 1
)

if not exist "%DEST%\Modules" mkdir "%DEST%\Modules"
copy /y "%ROOT_DIR%Modules\*.lua" "%DEST%\Modules\" >nul
if errorlevel 1 (
  echo Failed to copy Modules\*.lua
  pause
  exit /b 1
)

if exist "%ROOT_DIR%README.md" copy /y "%ROOT_DIR%README.md" "%DEST%\" >nul

if exist "%ROOT_DIR%version.txt" copy /y "%ROOT_DIR%version.txt" "%DEST%\" >nul

echo [2/2] Done.
echo Deploy successful.
echo.
timeout /t 5 /nobreak
exit /b 0
