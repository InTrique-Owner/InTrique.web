#requires -Version 5.1
<#
    Installs a global UPD command.

    After running this once, typing UPD in cmd.exe or PowerShell launches the
    InTrique release console from any working directory.
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$publisher = Join-Path $repoRoot 'scripts\publish.bat'
if (-not (Test-Path -LiteralPath $publisher)) {
    throw "Release console not found: $publisher"
}

$binDir = Join-Path $env:LOCALAPPDATA 'Intrique\bin'
New-Item -ItemType Directory -Path $binDir -Force | Out-Null

$wrapper = @"
@echo off
call "$publisher" %*
exit /b %ERRORLEVEL%
"@
$wrapperPath = Join-Path $binDir 'UPD.bat'
Set-Content -LiteralPath $wrapperPath -Value $wrapper -Encoding ASCII

$registry = 'HKCU:\Environment'
$userPath = (Get-ItemProperty -LiteralPath $registry -Name Path -ErrorAction SilentlyContinue).Path
if (-not $userPath) { $userPath = '' }

$entries = @($userPath -split ';' | Where-Object { $_ }) 
if ($entries -notcontains $binDir) {
    $entries += $binDir
    $newPath = ($entries -join ';') + ';'
    Set-ItemProperty -LiteralPath $registry -Name Path -Value $newPath
}

if (-not ('Intrique.Updater.Environment' -as [type])) {
    Add-Type -Namespace Intrique.Updater -Name Environment -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam, string lParam, uint flags, uint timeout, out UIntPtr result);
'@
}
$result = [UIntPtr]::Zero
[void][Intrique.Updater.Environment]::SendMessageTimeout(
    [IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'Path', 2, 2000, [ref]$result)

Write-Host "UPD command installed: $wrapperPath"
Write-Host "Path entry: $binDir"
