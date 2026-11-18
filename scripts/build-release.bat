@echo off
setlocal EnableExtensions DisableDelayedExpansion

title InTrique Release Builder

set "ver=0.1.2"

REM ============================================================
REM GITHUB CONFIGURATION
REM ============================================================

set "GITHUB_REPO=InTrique-Owner/InTrique.web"
set "GITHUB_BRANCH=main"
set "GITHUB_TAG=v%ver%"

set "INSTALLER_URL=https://github.com/%GITHUB_REPO%/releases/download/%GITHUB_TAG%/InTrique-Setup.exe"
set "CLIENT_URL=https://github.com/%GITHUB_REPO%/releases/download/%GITHUB_TAG%/InTriqueClient.exe"

REM ============================================================
REM PROJECT CONFIGURATION
REM ============================================================

if defined INTRIQUE_PROJECT (
    set "PROJECT=%INTRIQUE_PROJECT%"
) else (
    set "PROJECT=C:\InTrique"
)

for %%I in ("%~dp0..") do set "WEB=%%~fI"

set "BUILD=%PROJECT%\Build"
set "BIN=%BUILD%\Bin"

set "CLIENT=%BIN%\InTriqueClient.exe"
set "ASSETS=%BIN%\Assets"
set "GAMES=%BIN%\Games"

set "DOWNLOADS=%WEB%\downloads"
set "RELEASE_DIR=%WEB%\release"
set "INSTALLER_DIR=%WEB%\installer"

set "INSTALLER=%DOWNLOADS%\InTrique-Setup.exe"
set "COPIED_CLIENT=%DOWNLOADS%\InTriqueClient.exe"

set "ISS=%INSTALLER_DIR%\InTrique.iss"
set "INDEX_HTML=%WEB%\index.html"
set "DOWNLOAD_HTML=%WEB%\download.html"
set "LATEST_JSON=%RELEASE_DIR%\latest.json"

set "ISCC=%INNO_SETUP_COMPILER%"

REM ============================================================
REM EXECUTION OPTIONS
REM ============================================================

set "PAUSE_AT_END=1"

if /I "%~1"=="--no-pause" set "PAUSE_AT_END=0"
if defined INTRIQUE_UI set "PAUSE_AT_END=0"

set "SHA256="
set "INSTALLER_SIZE="
set "RELEASE_DATE="

REM ============================================================
REM HEADER
REM ============================================================

if not defined INTRIQUE_UI (
    echo.
    echo ============================================================
    echo                  INTRIQUE RELEASE BUILDER
    echo ============================================================
    echo Version       : %ver%
    echo Release tag   : %GITHUB_TAG%
    echo Project       : %PROJECT%
    echo Website       : %WEB%
    echo GitHub        : %GITHUB_REPO%
    echo ============================================================
    echo.
)

REM ============================================================
REM [1/8] VALIDATE VERSION
REM ============================================================

echo.
echo [1/8] Validating version...

powershell.exe -NoProfile -Command ^
    "if ($env:ver -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { exit 1 }"

if errorlevel 1 (
    echo ERROR: Invalid version.
    echo        Required format: MAJOR.MINOR.PATCH
    echo        Example: 0.1.2
    goto :fail
)

echo Version is valid.
echo.

REM ============================================================
REM [2/8] CHECK REQUIRED TOOLS
REM ============================================================

echo [2/8] Checking required tools...

where cmake.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: CMake was not found in PATH.
    goto :fail
)

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Windows PowerShell was not found.
    goto :fail
)

where gh.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI was not found in PATH.
    goto :fail
)

where git.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git was not found in PATH.
    goto :fail
)

if not exist "%PROJECT%\CMakeLists.txt" (
    echo ERROR: CMakeLists.txt was not found:
    echo        %PROJECT%\CMakeLists.txt
    goto :fail
)

if not exist "%ISS%" (
    echo ERROR: Inno Setup script was not found:
    echo        %ISS%
    goto :fail
)

if not exist "%INDEX_HTML%" (
    echo ERROR: index.html was not found:
    echo        %INDEX_HTML%
    goto :fail
)

if not exist "%DOWNLOAD_HTML%" (
    echo ERROR: download.html was not found:
    echo        %DOWNLOAD_HTML%
    goto :fail
)

if not exist "%INSTALLER_DIR%\assets\Welcome.png" (
    echo ERROR: Installer artwork is missing: Welcome.png
    goto :fail
)

if not exist "%INSTALLER_DIR%\assets\Header.png" (
    echo ERROR: Installer artwork is missing: Header.png
    goto :fail
)

REM ============================================================
REM LOCATE INNO SETUP COMPILER
REM ============================================================

set "PF86=%ProgramFiles(x86)%"

if not defined ISCC (
    for /f "delims=" %%I in ('where ISCC.exe 2^>nul') do (
        if not defined ISCC set "ISCC=%%I"
    )
)

if not defined ISCC (
    for %%P in (
        "%LOCALAPPDATA%\Programs\Inno Setup 7\ISCC.exe"
        "%ProgramFiles%\Inno Setup 7\ISCC.exe"
        "%PF86%\Inno Setup 7\ISCC.exe"
        "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
        "%ProgramFiles%\Inno Setup 6\ISCC.exe"
        "%PF86%\Inno Setup 6\ISCC.exe"
    ) do (
        if not defined ISCC if exist "%%~P" set "ISCC=%%~P"
    )
)

if not defined ISCC (
    echo ERROR: Could not locate ISCC.exe.
    echo        Install Inno Setup 6 or 7.
    echo        Or set INNO_SETUP_COMPILER to its full path.
    goto :fail
)

if not exist "%ISCC%" (
    echo ERROR: Configured Inno Setup compiler does not exist:
    echo        %ISCC%
    goto :fail
)

echo CMake       : OK
echo PowerShell  : OK
echo Git         : OK
echo GitHub CLI  : OK
echo Inno Setup  : %ISCC%
echo.

REM ============================================================
REM [3/8] CHECK GITHUB AUTHENTICATION AND REPOSITORY
REM ============================================================

echo [3/8] Checking GitHub authentication...

gh auth status -h github.com >nul 2>&1

if errorlevel 1 (
    echo ERROR: GitHub CLI is not authenticated.
    echo        Run: gh auth login
    goto :fail
)

gh repo view "%GITHUB_REPO%" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Could not access GitHub repository:
    echo        %GITHUB_REPO%
    goto :fail
)

echo GitHub authentication OK.
echo Repository access OK.
echo.

REM ============================================================
REM VERIFY WEBSITE GIT REMOTE
REM ============================================================

echo Checking website Git remote...

git -C "%WEB%" rev-parse --show-toplevel >nul 2>&1

if errorlevel 1 (
    echo ERROR: Website directory is not a Git repository:
    echo        %WEB%
    goto :fail
)

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
    echo ERROR: Website origin does not match configured repository.
    echo        Expected: %GITHUB_REPO%
    echo        Found   : %ORIGIN_URL%
    goto :fail
)

echo Website repository verified.
echo.

REM ============================================================
REM [4/8] CONFIGURE AND BUILD CLIENT
REM ============================================================

echo [4/8] Configuring CMake...

if exist "%BUILD%\CMakeCache.txt" (
    REM Preserve the generator already configured in this build folder.
    cmake -S "%PROJECT%" -B "%BUILD%" -DCMAKE_BUILD_TYPE=Release
    if errorlevel 1 (
        echo ERROR: CMake configuration failed.
        goto :fail
    )
) else (
    REM Use Ninja for a fresh build directory when it is available.
    where ninja.exe >nul 2>&1

    if not errorlevel 1 (
        cmake -S "%PROJECT%" -B "%BUILD%" -G Ninja -DCMAKE_BUILD_TYPE=Release
    ) else (
        cmake -S "%PROJECT%" -B "%BUILD%" -DCMAKE_BUILD_TYPE=Release
    )

    if errorlevel 1 (
        echo ERROR: CMake configuration failed.
        goto :fail
    )
)

echo.
echo Building InTriqueClient...

cmake --build "%BUILD%" --target InTriqueClient --config Release --parallel

if errorlevel 1 (
    echo ERROR: InTriqueClient build failed.
    goto :fail
)

if not exist "%CLIENT%" (
    echo ERROR: Client executable was not generated:
    echo        %CLIENT%
    goto :fail
)

for %%F in ("%CLIENT%") do (
    if %%~zF LEQ 0 (
        echo ERROR: Client executable is empty.
        goto :fail
    )
)

echo Client build successful.
echo.

REM ============================================================
REM [5/8] VERIFY CLIENT ASSETS AND STAGE EXECUTABLE
REM ============================================================

echo [5/8] Verifying client assets...

if not exist "%ASSETS%" (
    echo ERROR: Client Assets directory is missing:
    echo        %ASSETS%
    goto :fail
)

if not exist "%GAMES%" (
    echo ERROR: Client Games directory is missing:
    echo        %GAMES%
    goto :fail
)

if not exist "%ASSETS%\Icon\Icon.ico" (
    echo ERROR: Client icon is missing:
    echo        %ASSETS%\Icon\Icon.ico
    goto :fail
)

if not exist "%DOWNLOADS%" (
    mkdir "%DOWNLOADS%"

    if errorlevel 1 (
        echo ERROR: Could not create downloads directory.
        goto :fail
    )
)

echo Copying client executable...

copy /B /Y "%CLIENT%" "%COPIED_CLIENT%" >nul

if errorlevel 1 (
    echo ERROR: Could not stage client executable.
    goto :fail
)

if not exist "%COPIED_CLIENT%" (
    echo ERROR: Staged client executable is missing.
    goto :fail
)

REM Verify that the staged executable matches the built executable.

fc /B "%CLIENT%" "%COPIED_CLIENT%" >nul

if errorlevel 1 (
    echo ERROR: Staged client does not match the built executable.
    goto :fail
)

echo Client staging verified.
echo.

REM ============================================================
REM [6/8] BUILD INSTALLER
REM ============================================================

echo [6/8] Building InTrique installer...

REM Remove the previous installer before compiling.
REM This prevents an old installer being mistaken for a new one.

if exist "%INSTALLER%" (
    del /F /Q "%INSTALLER%"

    if exist "%INSTALLER%" (
        echo ERROR: Could not remove previous installer.
        echo        Check whether it is currently in use.
        goto :fail
    )
)

"%ISCC%" ^
    "/DMyAppVersion=%ver%" ^
    "/DInTriqueBin=%BIN%" ^
    /O"%DOWNLOADS%" ^
    "%ISS%"

if errorlevel 1 (
    echo ERROR: Inno Setup compilation failed.
    goto :fail
)

if not exist "%INSTALLER%" (
    echo ERROR: Installer output was not created:
    echo        %INSTALLER%
    goto :fail
)

for %%F in ("%INSTALLER%") do (
    if %%~zF LEQ 0 (
        echo ERROR: Installer file is empty.
        goto :fail
    )
)

echo Installer created successfully.
echo.

REM ============================================================
REM [7/8] GENERATE latest.json
REM ============================================================

echo [7/8] Generating release metadata...

if not exist "%RELEASE_DIR%" (
    mkdir "%RELEASE_DIR%"

    if errorlevel 1 (
        echo ERROR: Could not create release directory.
        goto :fail
    )
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$installer=Get-Item -LiteralPath $env:INSTALLER;" ^
    "$client=Get-Item -LiteralPath $env:COPIED_CLIENT;" ^
    "if($installer.Length -le 0){throw 'Installer is empty.'};" ^
    "if($client.Length -le 0){throw 'Client executable is empty.'};" ^
    "$hash=(Get-FileHash -LiteralPath $env:INSTALLER -Algorithm SHA256).Hash.ToLowerInvariant();" ^
    "$released=(Get-Date).ToString('yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);" ^
    "$metadata=[ordered]@{version=$env:ver;released=$released;platform='windows-x64';installer=$env:INSTALLER_URL;client=$env:CLIENT_URL;size=[long]$installer.Length;sha256=$hash};" ^
    "$temporary=$env:LATEST_JSON+'.tmp';" ^
    "$json=$metadata | ConvertTo-Json -Depth 4;" ^
    "[IO.File]::WriteAllText($temporary,$json+[Environment]::NewLine,[System.Text.UTF8Encoding]::new($false));" ^
    "Move-Item -LiteralPath $temporary -Destination $env:LATEST_JSON -Force;"

if errorlevel 1 (
    echo ERROR: Could not generate release/latest.json.
    goto :fail
)

REM Validate the exact metadata format expected by the website.

powershell.exe -NoProfile -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$j=Get-Content -Raw -LiteralPath $env:LATEST_JSON | ConvertFrom-Json;" ^
    "if($j.version -ne $env:ver){throw 'Incorrect version'};" ^
    "if($j.platform -ne 'windows-x64'){throw 'Incorrect platform'};" ^
    "if($j.installer -ne $env:INSTALLER_URL){throw 'Incorrect installer URL'};" ^
    "if($j.client -ne $env:CLIENT_URL){throw 'Incorrect client URL'};" ^
    "if($j.size -le 0){throw 'Invalid installer size'};" ^
    "if($j.sha256 -notmatch '^[0-9a-f]{64}$'){throw 'Invalid SHA-256'}"

if errorlevel 1 (
    echo ERROR: latest.json validation failed.
    goto :fail
)

for /f "usebackq delims=" %%H in (`
    powershell.exe -NoProfile -Command "(Get-Content -Raw -LiteralPath $env:LATEST_JSON | ConvertFrom-Json).sha256"
`) do set "SHA256=%%H"

for /f "usebackq delims=" %%S in (`
    powershell.exe -NoProfile -Command "(Get-Content -Raw -LiteralPath $env:LATEST_JSON | ConvertFrom-Json).size"
`) do set "INSTALLER_SIZE=%%S"

for /f "usebackq delims=" %%D in (`
    powershell.exe -NoProfile -Command "(Get-Content -Raw -LiteralPath $env:LATEST_JSON | ConvertFrom-Json).released"
`) do set "RELEASE_DATE=%%D"

if not defined SHA256 (
    echo ERROR: Could not read SHA-256 from latest.json.
    goto :fail
)

echo Version        : %ver%
echo Release date   : %RELEASE_DATE%
echo Installer size : %INSTALLER_SIZE% bytes
echo SHA-256        : %SHA256%
echo.

REM ============================================================
REM [8/8] CREATE OR OVERWRITE GITHUB RELEASE
REM ============================================================

echo [8/8] Publishing GitHub Release %GITHUB_TAG%...

gh release view "%GITHUB_TAG%" --repo "%GITHUB_REPO%" >nul 2>&1

if errorlevel 1 (

    echo Release does not exist. Creating it...

    gh release create "%GITHUB_TAG%" ^
        "%INSTALLER%" ^
        "%COPIED_CLIENT%" ^
        --repo "%GITHUB_REPO%" ^
        --target "%GITHUB_BRANCH%" ^
        --title "InTrique %ver%" ^
        --generate-notes ^
        --latest

    if errorlevel 1 (
        echo ERROR: Could not create GitHub Release.
        goto :fail
    )

) else (

    echo Existing release found.
    echo Replacing its installer and client assets...

    gh release upload "%GITHUB_TAG%" ^
        "%INSTALLER%" ^
        "%COPIED_CLIENT%" ^
        --repo "%GITHUB_REPO%" ^
        --clobber

    if errorlevel 1 (
        echo ERROR: Could not overwrite GitHub Release assets.
        goto :fail
    )

    gh release edit "%GITHUB_TAG%" ^
        --repo "%GITHUB_REPO%" ^
        --title "InTrique %ver%" ^
        --latest

    if errorlevel 1 (
        echo ERROR: Could not update release information.
        goto :fail
    )
)

REM ============================================================
REM VERIFY RELEASE ASSETS
REM ============================================================

echo.
echo Verifying GitHub release assets...

set "HAS_INSTALLER="
set "HAS_CLIENT="

for /f "usebackq delims=" %%A in (`
    gh release view "%GITHUB_TAG%" --repo "%GITHUB_REPO%" --json assets --jq ".assets[].name"
`) do (
    if /I "%%A"=="InTrique-Setup.exe" set "HAS_INSTALLER=1"
    if /I "%%A"=="InTriqueClient.exe" set "HAS_CLIENT=1"
)

if not defined HAS_INSTALLER (
    echo ERROR: GitHub Release is missing InTrique-Setup.exe.
    goto :fail
)

if not defined HAS_CLIENT (
    echo ERROR: GitHub Release is missing InTriqueClient.exe.
    goto :fail
)

echo GitHub release assets verified.
echo.

REM ============================================================
REM SUCCESS
REM ============================================================

echo ============================================================
echo              RELEASE PUBLISHED SUCCESSFULLY
echo ============================================================
echo.
echo Version        : %ver%
echo Tag            : %GITHUB_TAG%
echo Release        : https://github.com/%GITHUB_REPO%/releases/tag/%GITHUB_TAG%
echo Installer      : %INSTALLER_URL%
echo Client         : %CLIENT_URL%
echo Installer size : %INSTALLER_SIZE% bytes
echo SHA-256        : %SHA256%
echo.
echo Updated locally:
echo   release\latest.json
echo   downloads\InTrique-Setup.exe
echo   downloads\InTriqueClient.exe
echo.
echo NEXT:
echo Publish the website to GitHub Pages using option 2,
echo or use option 3 for a full synchronized release.
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
echo                    RELEASE FAILED
echo ============================================================
echo Review the error messages above.
echo.

if "%PAUSE_AT_END%"=="1" pause

endlocal
exit /b 1