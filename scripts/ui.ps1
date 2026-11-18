#requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateRange(0, 4)]
    [int]$Choice = 0,

    [switch]$Snapshot
)

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch {
}

# ============================================================
# PATHS
# ============================================================

$script:ScriptsDir = $PSScriptRoot
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

$script:BuildScript = Join-Path $script:ScriptsDir 'build-release.bat'
$script:WebsiteScript = Join-Path $script:ScriptsDir 'publish-website.bat'

$script:Interactive = ($Choice -eq 0 -and -not $Snapshot)

# ============================================================
# ENABLE WINDOWS TERMINAL ANSI SUPPORT
# ============================================================

function Enable-VirtualTerminal {
    try {
        if (-not ('InTrique.ConsoleMode' -as [type])) {
            Add-Type -Namespace InTrique -Name ConsoleMode -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@ -ErrorAction Stop
        }

        $handle = [InTrique.ConsoleMode]::GetStdHandle(-11)
        $mode = [uint32]0

        if ([InTrique.ConsoleMode]::GetConsoleMode($handle, [ref]$mode)) {
            [void][InTrique.ConsoleMode]::SetConsoleMode(
                $handle,
                ($mode -bor 0x0004)
            )
        }
    } catch {
    }
}

Enable-VirtualTerminal

# ============================================================
# INSTALL / UPDATE CHAKRA PETCH
# ============================================================

function Install-ChakraFont {
    try {
        $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        $registry = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        $source = Join-Path $script:RepoRoot 'assets\fonts'

        if (-not (Test-Path -LiteralPath $source)) {
            return
        }

        if (-not (Test-Path -LiteralPath $fontDir)) {
            New-Item -ItemType Directory -Path $fontDir -Force |
                Out-Null
        }

        if (-not (Test-Path -LiteralPath $registry)) {
            New-Item -Path $registry -Force | Out-Null
        }

        $faces = @(
            @{
                Name = 'Chakra Petch (TrueType)'
                File = 'ChakraPetch-Regular.ttf'
            },
            @{
                Name = 'Chakra Petch Bold (TrueType)'
                File = 'ChakraPetch-Bold.ttf'
            }
        )

        foreach ($face in $faces) {
            $sourceFile = Join-Path $source $face.File

            if (-not (Test-Path -LiteralPath $sourceFile)) {
                continue
            }

            $target = Join-Path $fontDir $face.File
            $copyRequired = $true

            if (Test-Path -LiteralPath $target) {
                $sourceHash = (
                    Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256
                ).Hash

                $targetHash = (
                    Get-FileHash -LiteralPath $target -Algorithm SHA256
                ).Hash

                $copyRequired = ($sourceHash -ne $targetHash)
            }

            if ($copyRequired) {
                Copy-Item -LiteralPath $sourceFile `
                    -Destination $target -Force
            }

            New-ItemProperty `
                -LiteralPath $registry `
                -Name $face.Name `
                -Value $target `
                -PropertyType String `
                -Force | Out-Null
        }

        if (-not ('InTrique.Terminal' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace InTrique.Terminal
{
    [StructLayout(LayoutKind.Sequential)]
    public struct Coord
    {
        public short X;
        public short Y;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct FontInfoEx
    {
        public uint cbSize;
        public uint nFont;
        public Coord dwFontSize;
        public uint FontFamily;
        public uint FontWeight;

        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }

    public static class Native
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetCurrentConsoleFontEx(
            IntPtr h,
            bool max,
            ref FontInfoEx f
        );
    }
}
'@ -ErrorAction Stop
        }

        $info = New-Object InTrique.Terminal.FontInfoEx

        $info.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($info)

        $size = New-Object InTrique.Terminal.Coord
        $size.X = 0
        $size.Y = 16

        $info.dwFontSize = $size
        $info.FontFamily = 0x36
        $info.FontWeight = 400
        $info.FaceName = 'Chakra Petch'

        [void][InTrique.Terminal.Native]::SetCurrentConsoleFontEx(
            [InTrique.Terminal.Native]::GetStdHandle(-11),
            $false,
            [ref]$info
        )
    } catch {
        # Font installation is optional.
    }
}

if (-not $Snapshot) {
    Install-ChakraFont
}

# ============================================================
# THEME
# ============================================================

$script:Esc = [char]27
$script:Reset = "$($script:Esc)[0m"

$script:G = @{
    Full  = [char]0x2588
    Upper = [char]0x2580
    Lower = [char]0x2584
    H     = [char]0x2500
    Dot   = [char]0x25CF
    Ring  = [char]0x25CB
    Up    = [char]0x2191
    Down  = [char]0x2193
    Mid   = [char]0x00B7
}

$script:P = @{
    Canvas = @{ r = 5;   g = 5;   b = 5   }
    Line   = @{ r = 38;  g = 38;  b = 43  }
    White  = @{ r = 255; g = 255; b = 255 }
    Off    = @{ r = 212; g = 212; b = 216 }
    Muted  = @{ r = 138; g = 141; b = 152 }
    Dim    = @{ r = 82;  g = 84;  b = 94  }
    Amber  = @{ r = 227; g = 179; b = 65  }
    Red    = @{ r = 255; g = 107; b = 107 }
}

# ============================================================
# MENU
# ============================================================

$script:Menu = @(
    @{
        N = '1'
        Title = 'BUILD CLIENT RELEASE'
        Desc = 'Build the client, installer and GitHub release.'
    },
    @{
        N = '2'
        Title = 'PUBLISH WEBSITE'
        Desc = 'Commit website changes and push them to GitHub Pages.'
    },
    @{
        N = '3'
        Title = 'FULL SYNCHRONIZED RELEASE'
        Desc = 'Build the release and publish all website changes.'
    },
    @{
        N = '4'
        Title = 'EXIT'
        Desc = 'Close the console.'
    }
)

$script:Width = 80
$script:Height = 32
$script:Rows = @()

# ============================================================
# COLOR HELPERS
# ============================================================

function Get-Fg([hashtable]$Color) {
    return "$($script:Esc)[38;2;$($Color.r);$($Color.g);$($Color.b)m"
}

function Get-Bg([hashtable]$Color) {
    return "$($script:Esc)[48;2;$($Color.r);$($Color.g);$($Color.b)m"
}

function Seg(
    [string]$Text,
    [hashtable]$Fore
) {
    return [pscustomobject]@{
        Text = $Text
        Fg = $Fore
    }
}

function Write-ColoredLine([object]$Line) {
    $text = [string]$Line

    if ($text -match '(?i)\berror\b|\bfailed\b|not found|cannot|rejected') {
        $color = $script:P.Red
    }
    elseif ($text -match '(?i)warning|\[!\]|retry|attention') {
        $color = $script:P.Amber
    }
    elseif ($text -match '(?i)success|published|complete|\[ok\]') {
        $color = $script:P.White
    }
    elseif ([string]::IsNullOrWhiteSpace($text)) {
        $color = $script:P.Dim
    }
    else {
        $color = $script:P.Off
    }

    Write-Host ((Get-Fg $color) + $text + $script:Reset)
}

function Repeat(
    [char]$Char,
    [int]$Count
) {
    if ($Count -le 0) {
        return ''
    }

    return ([string]$Char).PadLeft($Count, $Char)
}

function Limit-Text(
    [string]$Text,
    [int]$Max
) {
    if ($Max -lt 4) {
        return ''
    }

    if ($Text.Length -le $Max) {
        return $Text
    }

    return $Text.Substring(0, $Max - 3) + '...'
}

# ============================================================
# FRAME RENDERING
# ============================================================

function Render-Row([object[]]$Segments) {
    $visible = 0

    foreach ($segment in $Segments) {
        $visible += $segment.Text.Length
    }

    $pad = [Math]::Max(0, $script:Width - $visible)

    $builder = New-Object System.Text.StringBuilder

    [void]$builder.Append((Get-Bg $script:P.Canvas))

    foreach ($segment in $Segments) {
        [void]$builder.Append((Get-Fg $segment.Fg))
        [void]$builder.Append($segment.Text)
    }

    [void]$builder.Append((Get-Fg $script:P.Dim))
    [void]$builder.Append((Repeat ' ' $pad))
    [void]$builder.Append($script:Reset)

    return $builder.ToString()
}

function New-Frame {
    $script:Rows = @()

    for ($i = 0; $i -lt $script:Height; $i++) {
        $script:Rows += (Render-Row @())
    }
}

function Set-Row(
    [int]$Index,
    [object[]]$Segments
) {
    if ($Index -lt 0 -or $Index -ge $script:Height) {
        return
    }

    $script:Rows[$Index] = Render-Row $Segments
}

function Paint {
    $clear = (Get-Bg $script:P.Canvas) +
        "$($script:Esc)[2J$($script:Esc)[H"

    if ($Snapshot) {
        Write-Host $clear

        foreach ($row in $script:Rows) {
            Write-Host $row
        }

        return
    }

    [Console]::Out.Write($clear)

    for ($i = 0; $i -lt $script:Height; $i++) {
        [Console]::Out.Write(
            "$($script:Esc)[$($i + 1);1H$($script:Rows[$i])"
        )
    }

    [Console]::Out.Flush()
}

function Update-Size {
    $width = 80
    $height = 32

    try {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
    } catch {
    }

    $script:Width = [Math]::Max(60, $width - 1)
    $script:Height = [Math]::Max(24, $height)
}

# ============================================================
# SYSTEM CHECKS
# ============================================================

function Test-Command([string]$Name) {
    return ($null -ne (
        Get-Command $Name -ErrorAction SilentlyContinue
    ))
}

function Find-InnoSetup {
    if ($env:INNO_SETUP_COMPILER) {
        $configured = $env:INNO_SETUP_COMPILER.Trim('"')

        if (Test-Path -LiteralPath $configured) {
            return $configured
        }
    }

    $candidates = @()

    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe'
        $candidates += Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'
    }

    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe'
        $candidates += Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'
    }

    if (${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe'
        $candidates += Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue

    if ($command) {
        return $command.Source
    }

    return $null
}

function Invoke-Git {
    param(
        [string[]]$GitArgs
    )

    try {
        $output = & git -C $script:RepoRoot @GitArgs 2>$null
        $code = $LASTEXITCODE

        if ($code -ne 0) {
            return $null
        }

        return (($output | Out-String).Trim())
    } catch {
        return $null
    }
}

function Test-WebsiteRemote([string]$Remote) {
    if ([string]::IsNullOrWhiteSpace($Remote)) {
        return $false
    }

    $repo = $null

    if ($Remote -match '^https?://github\.com/(.+?)(?:\.git)?/?$') {
        $repo = $Matches[1]
    }
    elseif ($Remote -match '^git@github\.com:(.+?)(?:\.git)?$') {
        $repo = $Matches[1]
    }
    elseif ($Remote -match '^ssh://git@github\.com/(.+?)(?:\.git)?$') {
        $repo = $Matches[1]
    }

    if (-not $repo) {
        return $false
    }

    return (
        $repo.TrimEnd('/').ToLowerInvariant() -eq
        'intrique-owner/intrique.web'
    )
}

function Update-Context {
    $metaPath = Join-Path $script:RepoRoot 'release\latest.json'

    $script:Meta = $null

    if (Test-Path -LiteralPath $metaPath) {
        try {
            $script:Meta = Get-Content -LiteralPath $metaPath -Raw |
                ConvertFrom-Json
        } catch {
            $script:Meta = $null
        }
    }

    $branch = Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')
    $remote = Invoke-Git @('remote', 'get-url', 'origin')

    $remoteShort = $remote

    if ($remoteShort) {
        $remoteShort = $remoteShort `
            -replace '^https?://github\.com/', '' `
            -replace '^git@github\.com:', '' `
            -replace '^ssh://git@github\.com/', '' `
            -replace '\.git$', ''
    }

    $project = $env:INTRIQUE_PROJECT

    if (-not $project) {
        $project = 'C:\InTrique'
    }

    $script:Repo = @{
        Branch = if ($branch) { $branch } else { 'unknown' }
        RemoteShort = if ($remoteShort) { $remoteShort } else { 'no remote' }
    }

    $script:Sys = @{
        Git = Test-Command 'git'
        CMake = Test-Command 'cmake'
        Gh = Test-Command 'gh'
        PowerShell = Test-Command 'powershell.exe'
        Inno = Find-InnoSetup
        Project = $project
        ProjectOk = Test-Path -LiteralPath (
            Join-Path $project 'CMakeLists.txt'
        )
        WebsiteRepoOk = (
            $null -ne (Invoke-Git @('rev-parse', '--show-toplevel'))
        )
        ScriptsOk = (
            (Test-Path -LiteralPath $script:BuildScript) -and
            (Test-Path -LiteralPath $script:WebsiteScript)
        )
        CorrectRemote = Test-WebsiteRemote $remote
    }
}

# ============================================================
# HEADER
# ============================================================

function Convert-LogoArt([string]$Art) {
    $value = $Art

    $value = $value.Replace('L', [string]$script:G.Lower)
    $value = $value.Replace('U', [string]$script:G.Upper)
    $value = $value.Replace('F', [string]$script:G.Full)

    return $value
}

function Draw-Header {
    $P = $script:P
    $G = $script:G

    $logo = @(
        '  LLLLLL LLLLLLLL '
        '   UFFFF FFFFUUU  '
        '     LLL LLL      '
        '     FFF FFF      '
        '     FFF FFF      '
        '  LFFFFF UFF      '
        ' UUUUUUU   U      '
    )

    $logoRows = @()

    foreach ($row in $logo) {
        $logoRows += (Convert-LogoArt $row).PadRight(18)
    }

    $ready = (
        $script:Sys.Git -and
        $script:Sys.CMake -and
        $script:Sys.Gh -and
        $script:Sys.PowerShell -and
        [bool]$script:Sys.Inno -and
        $script:Sys.ProjectOk -and
        $script:Sys.WebsiteRepoOk -and
        $script:Sys.ScriptsOk -and
        $script:Sys.CorrectRemote
    )

    $status = if ($ready) { 'READY' } else { 'SETUP REQUIRED' }
    $statusColor = if ($ready) { $P.White } else { $P.Amber }
    $statusDot = if ($ready) { $G.Dot } else { $G.Ring }

    $version = if ($script:Meta) {
        "v$($script:Meta.version)"
    } else {
        'v-'
    }

    $right = @(
        @((Seg 'I N T R I Q U E' $P.White))
        @((Seg 'RELEASE CONSOLE' $P.Muted))
        @((Seg (Repeat $G.H 34) $P.Line))
        @(
            (Seg $version $P.White)
            (Seg "   $($G.Mid)   " $P.Dim)
            (Seg 'windows-x64' $P.Muted)
        )
        @(
            (Seg "$statusDot " $statusColor)
            (Seg $status $statusColor)
        )
        @()
        @()
    )

    $gap = Seg '   ' $P.Dim

    for ($i = 0; $i -lt $logoRows.Count; $i++) {
        $segments = @(
            (Seg $logoRows[$i] $P.White)
            $gap
        )

        if ($right[$i].Count -gt 0) {
            $segments += $right[$i]
        }

        Set-Row ($i + 1) $segments
    }

    Set-Row 8 @(
        (Seg (Repeat $G.H ($script:Width - 4)) $P.Line)
    )
}

# ============================================================
# MENU DISPLAY
# ============================================================

function Draw-Menu([int]$Selected) {
    $P = $script:P

    Set-Row 10 @(
        (Seg '  ACTIONS' $P.Muted)
    )

    for ($i = 0; $i -lt $script:Menu.Count; $i++) {
        $item = $script:Menu[$i]
        $active = ($i -eq $Selected)

        $marker = if ($active) { '>' } else { ' ' }
        $markerColor = if ($active) { $P.White } else { $P.Dim }
        $titleColor = if ($active) { $P.White } else { $P.Off }
        $numberColor = if ($active) { $P.White } else { $P.Dim }

        Set-Row ($i + 12) @(
            (Seg '  ' $P.Dim)
            (Seg "$marker " $markerColor)
            (Seg " $($item.N) " $numberColor)
            (Seg '  ' $P.Dim)
            (Seg $item.Title $titleColor)
        )
    }

    $activeItem = $script:Menu[$Selected]

    Set-Row 17 @(
        (Seg '  ' $P.Dim)
        (Seg " $($activeItem.N)/4 " $P.White)
        (Seg $activeItem.Desc $P.Muted)
    )
}

function Draw-Footer {
    $P = $script:P
    $G = $script:G

    $bottom = $script:Height - 2

    Set-Row $bottom @(
        (Seg '  ' $P.Dim)
        (Seg "$($G.Up)$($G.Down)" $P.White)
        (Seg ' NAVIGATE   ' $P.Muted)
        (Seg 'ENTER' $P.White)
        (Seg ' RUN   ' $P.Muted)
        (Seg '1-4' $P.White)
        (Seg ' JUMP   ' $P.Muted)
        (Seg 'ESC' $P.White)
        (Seg ' EXIT' $P.Muted)
    )

    $path = Limit-Text $script:RepoRoot ($script:Width - 30)

    Set-Row ($bottom + 1) @(
        (Seg '  ' $P.Dim)
        (Seg $path $P.Dim)
        (Seg "   $($G.Mid)   " $P.Dim)
        (Seg (Limit-Text $script:Repo.Branch 18) $P.Dim)
    )
}

function Show-Dashboard([int]$Selected) {
    Update-Size
    New-Frame
    Draw-Header
    Draw-Menu $Selected
    Draw-Footer
    Paint
}

# ============================================================
# ACTION DISPLAY
# ============================================================

function Draw-ActionTop([string]$Title) {
    $P = $script:P

    Set-Row 2 @(
        (Seg '  INTRIQUE' $P.White)
        (Seg '  /  ' $P.Dim)
        (Seg $Title $P.Off)
    )

    Set-Row 3 @(
        (Seg (Repeat $script:G.H ($script:Width - 4)) $P.Line)
    )
}

function Show-ActionHeader([string]$Title) {
    Update-Size
    New-Frame
    Draw-ActionTop $Title
    Paint

    # Keep the action title visible and put logs beneath it.
    [Console]::Out.Write("$($script:Esc)[5;1H")
    [Console]::Out.Flush()
}

function Show-ActionResult(
    [string]$Title,
    [int]$Code
) {
    Update-Size
    New-Frame
    Draw-ActionTop $Title

    $P = $script:P

    if ($Code -eq 0) {
        Set-Row 5 @(
            (Seg '  ' $P.Dim)
            (Seg 'SUCCESS' $P.White)
            (Seg '   Operation completed.' $P.Off)
            (Seg "   exit $Code" $P.Dim)
        )
    } else {
        Set-Row 5 @(
            (Seg '  ' $P.Dim)
            (Seg 'FAILED' $P.Red)
            (Seg '   Review the output above.' $P.Off)
            (Seg "   exit $Code" $P.Dim)
        )
    }

    Paint
}

function Show-Exit {
    Update-Size
    New-Frame

    $P = $script:P

    Set-Row 2 @(
        (Seg '  INTRIQUE' $P.White)
        (Seg '  /  RELEASE CONSOLE' $P.Muted)
    )

    Set-Row 3 @(
        (Seg (Repeat $script:G.H ($script:Width - 4)) $P.Line)
    )

    Set-Row 5 @(
        (Seg '  Session closed.' $P.Dim)
    )

    Paint
}

# ============================================================
# EXECUTE BATCH FILE
# ============================================================

function Invoke-Batch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string[]]$Arguments = @()
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-ColoredLine "ERROR: Missing script: $Path"
        return 1
    }

    $command = $env:ComSpec

    if (-not $command) {
        $command = 'cmd.exe'
    }

    $previousLocation = Get-Location
    $previousPreference = $ErrorActionPreference

    try {
        Set-Location -LiteralPath $script:RepoRoot

        # Native programs such as Git write normal messages to stderr.
        # Do not let PowerShell stop the batch process because of that.
        $ErrorActionPreference = 'Continue'

        $cmdLine = '""' + $Path + '"'

        foreach ($argument in $Arguments) {
            $cmdLine += ' "' + $argument.Replace('"', '""') + '"'
        }

        $cmdLine += '"'

        & $command /d /s /c $cmdLine 2>&1 |
            ForEach-Object {
                Write-ColoredLine $_
            }

        # Capture the native process exit code immediately.
        $code = $LASTEXITCODE

        if ($null -eq $code) {
            $code = 0
        }

        return [int]$code
    }
    catch {
        Write-ColoredLine "ERROR: $($_.Exception.Message)"
        return 1
    }
    finally {
        $ErrorActionPreference = $previousPreference
        Set-Location -LiteralPath $previousLocation
    }
}

# ============================================================
# MENU ACTIONS
# ============================================================

function Invoke-MenuAction([int]$Index) {
    $title = $script:Menu[$Index - 1].Title
    $code = 0

    switch ($Index) {
        1 {
            Show-ActionHeader $title

            $code = Invoke-Batch `
                -Path $script:BuildScript `
                -Arguments @('--no-pause')
        }

        2 {
            Show-ActionHeader $title

            $code = Invoke-Batch `
                -Path $script:WebsiteScript `
                -Arguments @('--no-pause')
        }

        3 {
            Show-ActionHeader $title

            $code = Invoke-Batch `
                -Path $script:BuildScript `
                -Arguments @('--no-pause')

            if ($code -eq 0) {
                Write-ColoredLine ''
                Write-ColoredLine 'Build completed. Publishing website...'
                Write-ColoredLine ''

                $code = Invoke-Batch `
                    -Path $script:WebsiteScript `
                    -Arguments @('--no-pause')
            } else {
                Write-ColoredLine ''
                Write-ColoredLine 'Website publishing skipped because the build failed.'
            }
        }
    }

    if ($Index -ne 4) {
        Show-ActionResult $title $code
        Update-Context

        if ($script:Interactive) {
            Write-Host ''
            Write-Host '  Press any key to return to the dashboard'

            try {
                [void][Console]::ReadKey($true)
            } catch {
            }
        }
    }

    return $code
}

# ============================================================
# MAIN
# ============================================================

$env:INTRIQUE_UI = '1'

Update-Context

if ($Snapshot) {
    Show-Dashboard 0
    exit 0
}

if ($Choice -eq 4) {
    Show-Exit
    exit 0
}

if ($Choice -gt 0) {
    $result = Invoke-MenuAction $Choice
    exit $result
}

$selected = 0

while ($true) {
    Show-Dashboard $selected

    try {
        $key = [Console]::ReadKey($true)
    } catch {
        break
    }

    $activate = $false

    switch ($key.Key) {
        'UpArrow' {
            $selected = ($selected + 3) % 4
        }

        'DownArrow' {
            $selected = ($selected + 1) % 4
        }

        'Enter' {
            $activate = $true
        }

        'Escape' {
            $selected = 3
            $activate = $true
        }

        default {
            $char = $key.KeyChar

            if (
                $char -ge [char]'1' -and
                $char -le [char]'4'
            ) {
                $selected = [int]$char - [int][char]'1'
                $activate = $true
            }
        }
    }

    if (-not $activate) {
        continue
    }

    if ($selected -eq 3) {
        Show-Exit
        break
    }

    [void](Invoke-MenuAction ($selected + 1))
}

exit 0