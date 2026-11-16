@echo off
setlocal EnableExtensions EnableDelayedExpansion
title InTrique Website Publisher

set "REPO_URL=https://github.com/InTrique-Owner/InTrique.web.git"
set "BRANCH=main"

echo.
echo   ==============================================================
echo            PUBLISHING INTRIQUE WEBSITE TO GITHUB PAGES
echo   ==============================================================
echo.

where git >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] Git was not found in PATH.
    pause
    exit /b 1
)

pushd "%~dp0.."

if not exist ".git" (
    echo   [*] Initializing Git repository on branch %BRANCH%
    git init -b %BRANCH%
    git remote add origin %REPO_URL% 2>nul
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    git remote add origin %REPO_URL%
)

echo   [*] Staging website updates
git add -A

git diff --cached --quiet
if errorlevel 1 (
    echo   [*] Committing website changes
    git commit -m "Update website: %date% %time%"
    if errorlevel 1 (
        echo.
        echo   [ERROR] Commit failed. Check your Git user name and email settings.
        popd
        exit /b 1
    )
    echo   [*] Pushing changes to GitHub
    git push -u origin %BRANCH%
    if errorlevel 1 (
        echo.
        echo   [!] Normal push failed. Retrying with force-with-lease
        git push origin %BRANCH% --force-with-lease
        if errorlevel 1 (
            echo.
            echo   [ERROR] Push failed. Check your GitHub credentials and try again.
            popd
            exit /b 1
        )
    )
) else (
    echo   [OK] No new website changes detected to commit.
)

popd
echo.
echo   ==============================================================
echo   [SUCCESS] InTrique Website published to GitHub Pages.
echo   ==============================================================
echo.
exit /b 0
