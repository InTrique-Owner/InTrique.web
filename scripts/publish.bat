@echo off
setlocal EnableExtensions EnableDelayedExpansion
title InTrique Release Publisher

:menu
cls
echo.
echo   ==============================================================
echo                     INTRIQUE RELEASE PIPELINE
echo   ==============================================================
echo    Self-contained publishing suite for InTrique Platform
echo.
echo    [1] Publish Client Executable
echo        Build C++ engine, package Inno Setup, and generate release
echo.
echo    [2] Publish Website
echo        Deploy website updates directly to GitHub Pages
echo.
echo    [3] Full Synchronized Release
echo        Build executable, package installer, and deploy website
echo.
echo    [4] Exit
echo   ==============================================================
echo.
set "CHOICE="
set /p "CHOICE=  Select an option [1-4]: "

if "%CHOICE%"=="1" goto publish_executable
if "%CHOICE%"=="2" goto publish_website
if "%CHOICE%"=="3" goto publish_all
if "%CHOICE%"=="4" goto menu_exit

echo.
echo   [!] Invalid choice. Please select 1, 2, 3, or 4.
ping -n 3 127.0.0.1 >nul
goto menu

:publish_executable
cls
echo.
echo   ==============================================================
echo   [*] Launching InTrique Executable Pipeline...
echo   ==============================================================
echo.
call "%~dp0build-release.bat"
echo.
echo   Press any key to return to menu...
pause >nul
goto menu

:publish_website
cls
echo.
echo   ==============================================================
echo   [*] Launching InTrique Website Deployment (GitHub Pages)...
echo   ==============================================================
echo.
call "%~dp0publish-website.bat"
echo.
echo   Press any key to return to menu...
pause >nul
goto menu

:publish_all
cls
echo.
echo   ==============================================================
echo   [1/2] Building and releasing InTrique Client Executable...
echo   ==============================================================
echo.
call "%~dp0build-release.bat" --no-pause
if errorlevel 1 (
    echo.
    echo   [ERROR] Release build failed. The website was not published.
    echo   Press any key to return to menu...
    pause >nul
    goto menu
)
echo.
echo   ==============================================================
echo   [2/2] Publishing Website to GitHub Pages...
echo   ==============================================================
echo.
call "%~dp0publish-website.bat"
echo.
echo   Press any key to return to menu...
pause >nul
goto menu

:menu_exit
cls
echo.
echo   Exiting InTrique Release Pipeline.
echo.
endlocal
exit /b 0
