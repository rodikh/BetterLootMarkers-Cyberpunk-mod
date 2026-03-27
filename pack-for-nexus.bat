@echo off
setlocal EnableExtensions

set "MOD_NAME=BetterLootMarkers"
set "ROOT_DIR=%~dp0"
set "DIST_DIR=%ROOT_DIR%dist"
set "BUILD_DIR=%ROOT_DIR%_build\package"
set "MOD_STAGE_DIR=%BUILD_DIR%\bin\x64\plugins\cyber_engine_tweaks\mods\%MOD_NAME%"
set "VERSION_FILE=%ROOT_DIR%version.txt"

set "VERSION=%~1"
if "%VERSION%"=="" if exist "%VERSION_FILE%" set /p VERSION=<"%VERSION_FILE%"
if "%VERSION%"=="" set "VERSION=dev"

set "ZIP_PATH=%DIST_DIR%\%MOD_NAME%-%VERSION%.zip"

echo.
echo [1/5] Preparing folders...
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
mkdir "%MOD_STAGE_DIR%\Modules"

echo [2/5] Copying mod files...
copy /y "%ROOT_DIR%init.lua" "%MOD_STAGE_DIR%\" >nul
copy /y "%ROOT_DIR%Modules\*.lua" "%MOD_STAGE_DIR%\Modules\" >nul
if exist "%ROOT_DIR%README.md" copy /y "%ROOT_DIR%README.md" "%MOD_STAGE_DIR%\" >nul
if exist "%VERSION_FILE%" copy /y "%VERSION_FILE%" "%MOD_STAGE_DIR%\" >nul

echo [3/5] Creating zip...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Compress-Archive -Path '%BUILD_DIR%\*' -DestinationPath '%ZIP_PATH%' -Force"
if errorlevel 1 (
  echo Failed to create zip archive.
  exit /b 1
)

echo [4/5] Cleaning temp files...
rmdir /s /q "%BUILD_DIR%"

echo [5/5] Done.
echo Created: %ZIP_PATH%
echo.
echo Usage:
echo   pack-for-nexus.bat 1.2.0
echo   pack-for-nexus.bat   ^(uses version.txt^)
echo.
exit /b 0
