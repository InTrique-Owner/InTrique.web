@echo off
setlocal EnableExtensions DisableDelayedExpansion

title InTrique Release Console

if /I "%~1"=="-h" goto :help
if /I "%~1"=="--help" goto :help

set "UI_SCRIPT=%~dp0ui.ps1"

if not exist "%UI_SCRIPT%" (
    echo ERROR: ui.ps1 was not found:
    echo "%UI_SCRIPT%"
    pause
    endlocal
    exit /b 1
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Windows PowerShell was not found.
    pause
    endlocal
    exit /b 1
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%UI_SCRIPT%" %*

set "EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %EXIT_CODE%

:help
echo.
echo ============================================================
echo                 INTRIQUE RELEASE CONSOLE
echo ============================================================
echo.
echo Usage:
echo   UPD                 Open the interactive console
echo   UPD -Snapshot       Render dashboard once
echo   UPD -Choice 1       Build client and publish GitHub release
echo   UPD -Choice 2       Publish website
echo   UPD -Choice 3       Full synchronized release
echo   UPD -Choice 4       Exit
echo   UPD -h              Show this help
echo.
endlocal
exit /b 0