@echo off
setlocal EnableExtensions DisableDelayedExpansion

title InTrique Website Publisher

REM ============================================================
REM CONFIGURATION
REM ============================================================

set "GITHUB_REPO=InTrique-Owner/InTrique.web"
set "GITHUB_BRANCH=main"

for %%I in ("%~dp0..") do set "WEB=%%~fI"

set "DOWNLOADS=%WEB%\downloads"
set "RELEASE_DIR=%WEB%\release"

set "INSTALLER=%DOWNLOADS%\InTrique-Setup.exe"
set "CLIENT=%DOWNLOADS%\InTriqueClient.exe"
set "LATEST_JSON=%RELEASE_DIR%\latest.json"

set "PAUSE_AT_END=1"

if /I "%~1"=="--no-pause" set "PAUSE_AT_END=0"
if defined INTRIQUE_UI set "PAUSE_AT_END=0"

REM ============================================================
REM HEADER
REM ============================================================

if not defined INTRIQUE_UI (
    echo.
    echo ============================================================
    echo                INTRIQUE WEBSITE PUBLISHER
    echo ============================================================
    echo Website : %WEB%
    echo GitHub  : %GITHUB_REPO%
    echo Branch  : %GITHUB_BRANCH%
    echo ============================================================
    echo.
)

REM ============================================================
REM [1/7] CHECK GIT
REM ============================================================

echo [1/7] Checking Git...

where git.exe >nul 2>&1

if errorlevel 1 (
    echo ERROR: Git was not found in PATH.
    goto :fail
)

git -C "%WEB%" rev-parse --show-toplevel >nul 2>&1

if errorlevel 1 (
    echo ERROR: Website directory is not a Git repository:
    echo        %WEB%
    goto :fail
)

echo Git repository found.
echo.

REM ============================================================
REM [2/7] VERIFY REPOSITORY ROOT
REM ============================================================

echo [2/7] Verifying repository root...

set "GIT_ROOT="
set "WEB_ROOT=%WEB%"

for /f "delims=" %%R in ('
    git -C "%WEB%" rev-parse --show-toplevel 2^>nul
') do (
    set "GIT_ROOT=%%R"
)

if not defined GIT_ROOT (
    echo ERROR: Could not resolve Git repository root.
    goto :fail
)

for %%I in ("%WEB_ROOT%") do set "WEB_ROOT=%%~fI"

powershell.exe -NoProfile -Command ^
    "$a=[IO.Path]::GetFullPath($env:WEB_ROOT).TrimEnd([char[]]@('\','/'));" ^
    "$b=[IO.Path]::GetFullPath($env:GIT_ROOT).TrimEnd([char[]]@('\','/'));" ^
    "if(-not [string]::Equals($a,$b,[StringComparison]::OrdinalIgnoreCase)){exit 1}"

if errorlevel 1 (
    echo ERROR: Website directory is not the Git repository root.
    echo        Expected: %WEB_ROOT%
    echo        Actual  : %GIT_ROOT%
    goto :fail
)

echo Repository root verified.
echo.

REM ============================================================
REM [3/7] VERIFY GITHUB REMOTE
REM ============================================================

echo [3/7] Verifying GitHub remote...

set "ORIGIN_URL="

for /f "delims=" %%U in ('
    git -C "%WEB%" remote get-url origin 2^>nul
') do (
    set "ORIGIN_URL=%%U"
)

if not defined ORIGIN_URL (
    echo ERROR: Git remote origin is missing.
    goto :fail
)

powershell.exe -NoProfile -Command ^
    "$u=$env:ORIGIN_URL;" ^
    "$r=$null;" ^
    "if($u -match '^https?://github\.com/(.+?)(?:\.git)?/?$'){$r=$Matches[1]}" ^
    "elseif($u -match '^git@github\.com:(.+?)(?:\.git)?$'){$r=$Matches[1]}" ^
    "elseif($u -match '^ssh://git@github\.com/(.+?)(?:\.git)?$'){$r=$Matches[1]}" ^
    "if(!$r -or $r.TrimEnd('/').ToLowerInvariant() -ne $env:GITHUB_REPO.ToLowerInvariant()){exit 1}"

if errorlevel 1 (
    echo ERROR: Git remote origin points to the wrong repository.
    echo        Expected: %GITHUB_REPO%
    echo        Found   : %ORIGIN_URL%
    goto :fail
)

echo GitHub remote verified.
echo.

REM ============================================================
REM [4/7] VERIFY BRANCH AND REQUIRED RELEASE FILES
REM ============================================================

echo [4/7] Checking branch and release files...

set "CURRENT_BRANCH="

for /f "delims=" %%B in ('
    git -C "%WEB%" rev-parse --abbrev-ref HEAD 2^>nul
') do (
    set "CURRENT_BRANCH=%%B"
)

if /I not "%CURRENT_BRANCH%"=="%GITHUB_BRANCH%" (
    echo ERROR: You are not currently on %GITHUB_BRANCH%.
    echo        Current branch: %CURRENT_BRANCH%
    goto :fail
)

if not exist "%LATEST_JSON%" (
    echo ERROR: release/latest.json is missing.
    echo        Run the release builder first.
    goto :fail
)

if not exist "%INSTALLER%" (
    echo ERROR: downloads\InTrique-Setup.exe is missing.
    echo        Run the release builder first.
    goto :fail
)

if not exist "%CLIENT%" (
    echo ERROR: downloads\InTriqueClient.exe is missing.
    echo        Run the release builder first.
    goto :fail
)

echo Branch verified: %CURRENT_BRANCH%
echo Release metadata found.
echo Installer found.
echo Client executable found.
echo.

REM ============================================================
REM [5/7] FETCH AND CHECK REMOTE CHANGES
REM ============================================================

echo [5/7] Fetching latest GitHub changes...

git -C "%WEB%" fetch --prune origin "%GITHUB_BRANCH%"

if errorlevel 1 (
    echo ERROR: Could not fetch from GitHub.
    goto :fail
)

git -C "%WEB%" show-ref --verify --quiet "refs/remotes/origin/%GITHUB_BRANCH%"

if errorlevel 1 (
    echo ERROR: Remote branch origin/%GITHUB_BRANCH% was not found.
    goto :fail
)

set "AHEAD="
set "BEHIND="

for /f "tokens=1,2" %%A in ('
    git -C "%WEB%" rev-list --left-right --count HEAD...origin/%GITHUB_BRANCH% 2^>nul
') do (
    set "AHEAD=%%A"
    set "BEHIND=%%B"
)

if not defined AHEAD (
    echo ERROR: Could not compare local and remote branches.
    goto :fail
)

if not defined BEHIND (
    echo ERROR: Could not determine remote branch status.
    goto :fail
)

if not "%BEHIND%"=="0" (
    echo [!] Remote branch has %BEHIND% newer commits.
    echo [*] Auto-synchronizing with GitHub before publishing...
    git -C "%WEB%" pull --rebase origin "%GITHUB_BRANCH%"
    if errorlevel 1 (
        echo ERROR: Automatic rebase encountered conflicts.
        goto :fail
    )
    echo [*] Successfully synchronized with remote branch.
)

echo Local branch is synchronized with GitHub.
echo Local commits ahead: %AHEAD%
echo.

REM ============================================================
REM [6/7] STAGE WEBSITE AND RELEASE FILES
REM ============================================================

echo [6/7] Staging website changes...

git -C "%WEB%" add -A

if errorlevel 1 (
    echo ERROR: Could not stage website changes.
    goto :fail
)

REM Force-add the live release files in case .gitignore excludes EXE files.

git -C "%WEB%" add -f -- ^
    "release/latest.json" ^
    "downloads/InTrique-Setup.exe" ^
    "downloads/InTriqueClient.exe"

if errorlevel 1 (
    echo ERROR: Could not stage release metadata or download files.
    goto :fail
)

REM Check whether there are staged changes.

git -C "%WEB%" diff --cached --quiet

if errorlevel 1 (
    echo Changes found.
    echo Creating website commit...

    git -C "%WEB%" commit -m "Publish InTrique website and release"

    if errorlevel 1 (
        echo ERROR: Git commit failed.
        echo        Check your Git username and email settings.
        goto :fail
    )

    echo Website commit created.
) else (
    echo No new changes to commit.
)

echo.

REM ============================================================
REM [7/7] PUSH AND VERIFY GITHUB
REM ============================================================

echo [7/7] Publishing to GitHub...

git -C "%WEB%" push origin "%GITHUB_BRANCH%"

if errorlevel 1 (
    echo ERROR: Git push failed.
    echo.
    echo The remote may have changed after the fetch.
    echo Fetch and review the changes before retrying.
    echo No force-push will be attempted.
    goto :fail
)

REM ------------------------------------------------------------
REM VERIFY LOCAL AND REMOTE COMMIT IDS
REM ------------------------------------------------------------

set "LOCAL_HEAD="
set "REMOTE_HEAD="

for /f "delims=" %%H in ('
    git -C "%WEB%" rev-parse HEAD 2^>nul
') do (
    set "LOCAL_HEAD=%%H"
)

for /f "tokens=1" %%H in ('
    git -C "%WEB%" ls-remote origin refs/heads/%GITHUB_BRANCH% 2^>nul
') do (
    set "REMOTE_HEAD=%%H"
)

if not defined LOCAL_HEAD (
    echo ERROR: Could not read local commit ID.
    goto :fail
)

if not defined REMOTE_HEAD (
    echo ERROR: Could not verify remote commit ID.
    goto :fail
)

if /I not "%LOCAL_HEAD%"=="%REMOTE_HEAD%" (
    echo ERROR: Local and remote commit IDs do not match.
    goto :fail
)

REM ============================================================
REM SUCCESS
REM ============================================================

echo.
echo ============================================================
echo              WEBSITE PUBLISHED SUCCESSFULLY
echo ============================================================
echo.
echo Repository : %GITHUB_REPO%
echo Branch     : %GITHUB_BRANCH%
echo Commit     : %LOCAL_HEAD%
echo.
echo Published:
echo   Website files
echo   release/latest.json
echo   downloads/InTrique-Setup.exe
echo   downloads/InTriqueClient.exe
echo.
echo Website:
echo https://intrique-owner.github.io/InTrique.web/
echo.
echo ============================================================

goto :success

REM ============================================================
REM EXIT HANDLERS
REM ============================================================

:success

if "%PAUSE_AT_END%"=="1" pause

endlocal
exit /b 0

:fail

echo.
echo ============================================================
echo                  WEBSITE PUBLISH FAILED
echo ============================================================
echo Review the errors above.
echo No force-push was attempted.
echo.

if "%PAUSE_AT_END%"=="1" pause

endlocal
exit /b 1