@echo off
setlocal EnableExtensions
title InTrique Release Console

set "UI=%~dp0ui.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" set "PS=powershell.exe"

if /I "%~1"=="-h"     goto :help
if /I "%~1"=="--help" goto :help
if /I "%~1"=="/?"     goto :help

if not exist "%UI%" (
    echo.
    echo   [ERROR] Release console not found:
    echo           %UI%
    echo.
    pause
    exit /b 1
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%UI%" %*
set "CODE=%ERRORLEVEL%"

if not "%CODE%"=="0" if "%~1"=="" (
    echo.
    echo   The release console exited with code %CODE%.
    pause
)

endlocal & exit /b %CODE%

:help
echo.
echo   INTRIQUE RELEASE CONSOLE
echo   ------------------------------------------------------------
echo   Usage:
echo     UPD                  Open the interactive console.
echo     UPD -Choice N        Run one action and exit (N = 1-4).
echo     UPD -Snapshot        Render the console once and exit.
echo     UPD -h               Show this help.
echo.
echo   Actions:
echo     1  Build client executable and package the installer
echo     2  Publish the website to GitHub Pages
echo     3  Full synchronized release (build, then publish)
echo     4  Exit
echo.
echo   Keyboard: up/down to navigate, enter to run, 1-4 to jump, esc to exit.
echo   ------------------------------------------------------------
echo.
exit /b 0
