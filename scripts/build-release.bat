
@echo off
setlocal EnableExtensions DisableDelayedExpansion

title InTrique Release Publisher

REM ============================================================
REM CONFIGURATION
REM ============================================================

set "VERSION=0.1.1"
set "GITHUB_REPO=InTrique-Owner/InTrique.web"
set "GITHUB_BRANCH=main"
set "GITHUB_TAG=v%VERSION%"
set "STABLE_INSTALLER_URL=Downloads/InTrique-Setup.exe"

REM Override this with INTRIQUE_PROJECT if the engine is elsewhere.
if defined INTRIQUE_PROJECT (
    set "PROJECT=%INTRIQUE_PROJECT%"
) else (
    set "PROJECT=C:\InTrique"
)

for %%I in ("%~dp0..") do set "WEB=%%~fI"

set "BUILD=%PROJECT%\Build"
set "BIN=%BUILD%\Bin"
set "DOWNLOADS=%WEB%\Downloads"
set "RELEASE_DIR=%WEB%\release"
set "INSTALLER_DIR=%WEB%\Installer"

set "CLIENT=%BIN%\InTriqueClient.exe"
set "ASSETS=%BIN%\Assets"
set "GAMES=%BIN%\Games"
set "ISS=%INSTALLER_DIR%\InTrique.iss"
set "INDEX_HTML=%WEB%\index.html"
set "LATEST_JSON=%RELEASE_DIR%\latest.json"
set "COPIED_CLIENT=%DOWNLOADS%\InTriqueClient.exe"
set "INSTALLER=%DOWNLOADS%\InTrique-Setup.exe"

set "ISCC=%INNO_SETUP_COMPILER%"
set "PAUSE_AT_END=1"
if /I "%~1"=="--no-pause" set "PAUSE_AT_END=0"

set "SHA256="
set "INSTALLER_SIZE_TEXT="
set "RELEASE_DATE_DISPLAY="

echo.
echo ============================================================
echo                 InTrique Release Build
echo ============================================================
echo Version       : %VERSION%
echo Project       : %PROJECT%
echo Website       : %WEB%
echo GitHub        : %GITHUB_REPO%
echo Release tag   : %GITHUB_TAG%
echo.

REM ============================================================
REM [1/7] VALIDATE TOOLS AND PROJECT FILES
REM ============================================================

echo [1/7] Checking tools and project files...

where cmake >nul 2>&1
if errorlevel 1 (
    echo ERROR: CMake was not found in PATH.
    goto :fail
)

where powershell >nul 2>&1
if errorlevel 1 (
    echo ERROR: Windows PowerShell was not found.
    goto :fail
)

where gh >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI (gh) was not found in PATH.
    goto :fail
)

if not exist "%PROJECT%\CMakeLists.txt" (
    echo ERROR: CMakeLists.txt was not found at:
    echo        %PROJECT%\CMakeLists.txt
    goto :fail
)

if not exist "%ISS%" (
    echo ERROR: Inno Setup script was not found:
    echo        %ISS%
    goto :fail
)

if not exist "%INDEX_HTML%" (
    echo ERROR: Website entry file was not found:
    echo        %INDEX_HTML%
    goto :fail
)

if not exist "%INSTALLER_DIR%\Assets\Welcome.png" (
    echo ERROR: Installer artwork is missing: Welcome.png
    goto :fail
)

if not exist "%INSTALLER_DIR%\Assets\Header.png" (
    echo ERROR: Installer artwork is missing: Header.png
    goto :fail
)

if not exist "%ASSETS%\Icon\Icon.ico" (
    echo ERROR: Client icon is missing:
    echo        %ASSETS%\Icon\Icon.ico
    goto :fail
)

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

REM Locate ISCC.exe without depending on one Windows username.
if not defined ISCC (
    for /f "delims=" %%I in ('where ISCC.exe 2^>nul') do if not defined ISCC set "ISCC=%%I"
)

if not defined ISCC (
    for %%P in (
        "%LOCALAPPDATA%\Programs\Inno Setup 7\ISCC.exe"
        "%ProgramFiles%\Inno Setup 7\ISCC.exe"
        "%ProgramFiles(x86)%\Inno Setup 7\ISCC.exe"
        "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
        "%ProgramFiles%\Inno Setup 6\ISCC.exe"
        "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    ) do (
        if not defined ISCC if exist "%%~P" set "ISCC=%%~P"
    )
)

if not defined ISCC (
    echo ERROR: Could not locate ISCC.exe.
    echo        Install Inno Setup 7 or set INNO_SETUP_COMPILER to its full path.
    goto :fail
)

if not exist "%ISCC%" (
    echo ERROR: The configured Inno Setup compiler does not exist:
    echo        %ISCC%
    goto :fail
)

echo Tools and project files found.
echo Inno Setup : %ISCC%
echo.

REM ============================================================
REM [2/7] VALIDATE GITHUB AUTHENTICATION
REM ============================================================

echo [2/7] Checking GitHub authentication...

gh auth status -h github.com >nul 2>&1
if errorlevel 1 (
    echo ERROR: GitHub CLI is not authenticated.
    echo        Run: gh auth login
    goto :fail
)

echo GitHub authentication OK.
echo.

REM ============================================================
REM [3/7] CONFIGURE AND BUILD THE CLIENT
REM ============================================================

echo [3/7] Configuring the CMake release build...

if exist "%BUILD%\CMakeCache.txt" (
    REM Reuse the existing generator; this avoids a generator mismatch.
    cmake -S "%PROJECT%" -B "%BUILD%" -DCMAKE_BUILD_TYPE=Release
) else (
    where ninja >nul 2>&1
    if errorlevel 1 (
        echo ERROR: Ninja is required for a fresh build directory.
        echo        Install Ninja and add it to PATH, or configure the build directory first.
        goto :fail
    )
    cmake -S "%PROJECT%" -B "%BUILD%" -G Ninja -DCMAKE_BUILD_TYPE=Release
)

if errorlevel 1 (
    echo ERROR: CMake configuration failed.
    goto :fail
)

echo.
echo Building InTriqueClient in Release configuration...
cmake --build "%BUILD%" --target InTriqueClient --config Release --parallel
if errorlevel 1 (
    echo ERROR: InTriqueClient build failed.
    goto :fail
)

if not exist "%CLIENT%" (
    echo ERROR: Build completed but the client executable was not found:
    echo        %CLIENT%
    goto :fail
)

for %%F in ("%CLIENT%") do if %%~zF LEQ 0 (
    echo ERROR: The generated client executable is empty.
    goto :fail
)

echo Client build successful.
echo.

REM ============================================================
REM [4/7] STAGE CLIENT AND BUILD INSTALLER
REM ============================================================

echo [4/7] Preparing release files...

if not exist "%DOWNLOADS%" mkdir "%DOWNLOADS%"
if errorlevel 1 (
    echo ERROR: Could not create Downloads directory.
    goto :fail
)

copy /B /Y "%CLIENT%" "%COPIED_CLIENT%" >nul
if errorlevel 1 (
    echo ERROR: Could not copy InTriqueClient.exe to Downloads.
    goto :fail
)

if not exist "%COPIED_CLIENT%" (
    echo ERROR: Staged client executable was not created.
    goto :fail
)

REM Remove the prior installer so a failed compile cannot pass validation
REM merely because an older installer is still present.
if exist "%INSTALLER%" del /F /Q "%INSTALLER%"
if exist "%INSTALLER%" (
    echo ERROR: Could not remove the previous installer. Check whether it is in use.
    goto :fail
)

echo Compiling InTrique-Setup.exe...
"%ISCC%" "/DMyAppVersion='%VERSION%'" "/DInTriqueBin='%BIN%'" /O"%DOWNLOADS%" "%ISS%"
if errorlevel 1 (
    echo ERROR: Inno Setup compilation failed.
    goto :fail
)

if not exist "%INSTALLER%" (
    echo ERROR: Installer compilation returned success but output is missing:
    echo        %INSTALLER%
    goto :fail
)

for %%F in ("%INSTALLER%") do if %%~zF LEQ 0 (
    echo ERROR: The generated installer is empty.
    goto :fail
)

echo Installer created successfully.
echo.

REM ============================================================
REM [5/7] GENERATE AND VALIDATE RELEASE METADATA
REM ============================================================

echo [5/7] Generating release metadata...

if not exist "%RELEASE_DIR%" mkdir "%RELEASE_DIR%"
if errorlevel 1 (
    echo ERROR: Could not create release directory.
    goto :fail
)

REM latest.json is generated from the actual installer, not a manually
REM maintained size or checksum. UTF-8 is written without a BOM.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$file = Get-Item -LiteralPath $env:INSTALLER;" ^
  "if ($file.Length -le 0) { throw 'Installer file is empty.' };" ^
  "$hash = (Get-FileHash -LiteralPath $env:INSTALLER -Algorithm SHA256).Hash.ToLowerInvariant();" ^
  "$released = (Get-Date).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture);" ^
  "$sizeDisplay = if ($file.Length -ge 1MB) { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:N2} MB', ($file.Length / 1MB)) } elseif ($file.Length -ge 1KB) { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:N0} KB', ($file.Length / 1KB)) } else { '{0} B' -f $file.Length };" ^
  "$metadata = [ordered]@{ version = $env:VERSION; tag = $env:GITHUB_TAG; released = $released; platform = 'windows-x64'; installer = 'InTrique-Setup.exe'; client = 'InTriqueClient.exe'; url = $env:STABLE_INSTALLER_URL; size = [long]$file.Length; size_display = $sizeDisplay; sha256 = $hash };" ^
  "$temporary = $env:LATEST_JSON + '.tmp';" ^
  "$json = $metadata | ConvertTo-Json -Depth 4;" ^
  "[IO.File]::WriteAllText($temporary, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)));" ^
  "Move-Item -LiteralPath $temporary -Destination $env:LATEST_JSON -Force;"

if errorlevel 1 (
    echo ERROR: Could not generate release/latest.json.
    goto :fail
)

REM Read the generated values back from JSON and validate the schema.
for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "$j=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($env:LATEST_JSON)); $j.sha256"`) do set "SHA256=%%H"
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "$j=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($env:LATEST_JSON)); $j.size_display"`) do set "INSTALLER_SIZE_TEXT=%%S"
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "$j=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($env:LATEST_JSON)); [datetime]::ParseExact($j.released,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture).ToString('MMMM d, yyyy',[Globalization.CultureInfo]::InvariantCulture)"`) do set "RELEASE_DATE_DISPLAY=%%D"

if not defined SHA256 (
    echo ERROR: Could not read SHA-256 from latest.json.
    goto :fail
)

if not defined INSTALLER_SIZE_TEXT (
    echo ERROR: Could not read installer display size from latest.json.
    goto :fail
)

if not defined RELEASE_DATE_DISPLAY (
    echo ERROR: Could not read release date from latest.json.
    goto :fail
)

powershell -NoProfile -Command "$j=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($env:LATEST_JSON)); if($j.version -ne $env:VERSION -or $j.platform -ne 'windows-x64' -or $j.installer -ne 'InTrique-Setup.exe' -or $j.sha256 -notmatch '^[0-9a-f]{64}$' -or $j.size -le 0){exit 1}"
if errorlevel 1 (
    echo ERROR: latest.json failed validation.
    goto :fail
)

echo Version       : %VERSION%
echo Release date  : %RELEASE_DATE_DISPLAY%
echo Installer size: %INSTALLER_SIZE_TEXT%
echo SHA-256       : %SHA256%
echo.

REM ============================================================
REM UPDATE WEBSITE RELEASE CONFIGURATION
REM ============================================================

echo Updating the website release configuration...

REM The current index.html contains a RELEASE JavaScript object. Keep it
REM compatible while taking all values from the generated latest.json.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$q = [char]34;" ^
  "$path = $env:INDEX_HTML;" ^
  "$html = [IO.File]::ReadAllText($path);" ^
  "$meta = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($env:LATEST_JSON));" ^
  "$releasedDisplay = [datetime]::ParseExact($meta.released, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).ToString('MMMM d, yyyy', [Globalization.CultureInfo]::InvariantCulture);" ^
  "$values = [ordered]@{ version = $meta.version; released = $releasedDisplay; url = $meta.url; file = $meta.installer; size = $meta.size_display; sha256 = $meta.sha256 };" ^
  "foreach ($key in $values.Keys) { $pattern = '(?m)^([ \t]*' + [regex]::Escape($key) + '[ \t]*:[ \t]*)' + $q + '[^' + $q + ']*' + $q; if (-not [regex]::IsMatch($html, $pattern)) { throw ('Required RELEASE field not found in index.html: ' + $key) }; $value = [string]$values[$key]; $html = [regex]::Replace($html, $pattern, ('$1' + $q + $value + $q), 1) };" ^
  "$hrefPattern = 'href[ \t]*=[ \t]*' + $q + '[^' + $q + ']*InTrique-Setup(?:-[0-9]+\.[0-9]+\.[0-9]+)?\.exe' + $q;" ^
  "$html = [regex]::Replace($html, $hrefPattern, ('href=' + $q + $meta.url + $q));" ^
  "$temporary = $path + '.tmp';" ^
  "[IO.File]::WriteAllText($temporary, $html, (New-Object Text.UTF8Encoding($false)));" ^
  "Move-Item -LiteralPath $temporary -Destination $path -Force;"

if errorlevel 1 (
    echo ERROR: Failed to synchronise index.html with latest.json.
    goto :fail
)

echo Website release configuration updated locally.
echo.

REM ============================================================
REM [6/7] CREATE OR UPDATE THE GITHUB RELEASE
REM ============================================================

echo [6/7] Publishing GitHub Release %GITHUB_TAG%...

gh release view "%GITHUB_TAG%" --repo "%GITHUB_REPO%" >nul 2>&1
if errorlevel 1 (
    echo Release does not exist. Creating it...
    gh release create "%GITHUB_TAG%" ^
        "%INSTALLER%" ^
        "%COPIED_CLIENT%" ^
        --repo "%GITHUB_REPO%" ^
        --target "%GITHUB_BRANCH%" ^
        --title "InTrique %VERSION%" ^
        --generate-notes ^
        --latest
    if errorlevel 1 (
        echo ERROR: Could not create GitHub Release.
        goto :fail
    )
) else (
    echo Release already exists. Replacing its release assets...
    gh release upload "%GITHUB_TAG%" ^
        "%INSTALLER%" ^
        "%COPIED_CLIENT%" ^
        --repo "%GITHUB_REPO%" ^
        --clobber
    if errorlevel 1 (
        echo ERROR: Could not upload GitHub Release assets.
        goto :fail
    )

    gh release edit "%GITHUB_TAG%" ^
        --repo "%GITHUB_REPO%" ^
        --title "InTrique %VERSION%" ^
        --latest
    if errorlevel 1 (
        echo ERROR: Assets were uploaded, but GitHub Release metadata could not be updated.
        goto :fail
    )
)

echo GitHub Release assets published.
echo.

REM ============================================================
REM [7/7] PUBLISH WEBSITE AND RELEASE METADATA TO GITHUB PAGES
REM ============================================================

echo [7/7] Publishing website and latest.json...

set "LOCAL_FILE=%INDEX_HTML%"
set "REMOTE_PATH=index.html"
set "COMMIT_MESSAGE=Release InTrique %VERSION% - update website"
call :PublishFile
if errorlevel 1 goto :fail

set "LOCAL_FILE=%LATEST_JSON%"
set "REMOTE_PATH=release/latest.json"
set "COMMIT_MESSAGE=Release InTrique %VERSION% - update release metadata"
call :PublishFile
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo                 RELEASE PUBLISHED SUCCESSFULLY
echo ============================================================
echo Version       : %VERSION%
echo GitHub Release: https://github.com/%GITHUB_REPO%/releases/tag/%GITHUB_TAG%
echo Installer     : %INSTALLER%
echo SHA-256       : %SHA256%
echo Download URL  : %STABLE_INSTALLER_URL%
echo Website       : https://intrique-owner.github.io/InTrique.web/
echo.

goto :success

REM ============================================================
REM FUNCTION: PUBLISH ONE FILE THROUGH THE GITHUB CONTENTS API
REM ============================================================

:PublishFile
set "REMOTE_SHA="
set "PAYLOAD=%TEMP%\intrique-publish-%RANDOM%-%RANDOM%.json"

for /f "usebackq delims=" %%S in (`gh api "repos/%GITHUB_REPO%/contents/%REMOTE_PATH%?ref=%GITHUB_BRANCH%" --jq ".sha" 2^>nul`) do set "REMOTE_SHA=%%S"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$payload = [ordered]@{ message = $env:COMMIT_MESSAGE; content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($env:LOCAL_FILE)); branch = $env:GITHUB_BRANCH };" ^
  "if ($env:REMOTE_SHA) { $payload.sha = $env:REMOTE_SHA };" ^
  "$json = $payload | ConvertTo-Json -Compress;" ^
  "[IO.File]::WriteAllText($env:PAYLOAD, $json, (New-Object Text.UTF8Encoding($false)));"

if errorlevel 1 (
    echo ERROR: Could not prepare GitHub payload for %REMOTE_PATH%.
    exit /b 1
)

if not exist "%PAYLOAD%" (
    echo ERROR: GitHub payload was not created for %REMOTE_PATH%.
    exit /b 1
)

gh api --method PUT "repos/%GITHUB_REPO%/contents/%REMOTE_PATH%" --input "%PAYLOAD%" --header "Accept: application/vnd.github+json" >nul
set "PUBLISH_EXIT=%ERRORLEVEL%"

del /Q "%PAYLOAD%" >nul 2>&1

if not "%PUBLISH_EXIT%"=="0" (
    echo ERROR: GitHub rejected the update for %REMOTE_PATH%.
    exit /b 1
)

echo Published %REMOTE_PATH%.
exit /b 0

REM ============================================================
REM EXIT HANDLERS
REM ============================================================

:success
if "%PAUSE_AT_END%"=="1" pause
endlocal & exit /b 0

:fail
echo.
echo ============================================================
echo                    RELEASE FAILED
echo ============================================================
echo No success status has been reported. Review the error above.
echo.
if "%PAUSE_AT_END%"=="1" pause
endlocal & exit /b 1