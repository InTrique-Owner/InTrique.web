#requires -Version 5.1
<#
    InTrique Release Console
    Branded terminal dashboard for the InTrique publishing pipeline.

    Usage:
        scripts\publish.bat                 interactive console
        scripts\publish.bat -Choice 1       run one action, then exit
        scripts\publish.bat -Snapshot       render the dashboard once and exit
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 4)][int]$Choice = 0,
    [switch]$Snapshot
)

$ErrorActionPreference = 'Stop'

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
try { $OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

function Enable-VirtualTerminal {
    # Turn on ANSI/truecolor processing so the palette renders in conhost too.
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
            [void][InTrique.ConsoleMode]::SetConsoleMode($handle, ($mode -bor 0x0004))
        }
    } catch { }
}

Enable-VirtualTerminal

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:BuildScript = Join-Path $PSScriptRoot 'build-release.bat'
$script:WebsiteScript = Join-Path $PSScriptRoot 'publish-website.bat'
$script:Interactive = ($Choice -eq 0 -and -not $Snapshot)

# ---------------------------------------------------------------- glyphs ----
$script:Esc = [char]27
$script:Reset = "$($script:Esc)[0m"
$script:Bold = "$($script:Esc)[1m"

$script:G = @{
    Full  = [char]0x2588
    Upper = [char]0x2580
    Lower = [char]0x2584
    H     = [char]0x2500
    V     = [char]0x2502
    Dot   = [char]0x25CF
    Ring  = [char]0x25CB
    Up    = [char]0x2191
    Down  = [char]0x2193
    Mid   = [char]0x00B7
    Ell   = [char]0x2026
}

# --------------------------------------------------------------- palette ----
# Mirrors the website theme: near-black canvas, graphite panels, white type.
$script:P = @{
    Canvas = @{ r = 5;   g = 5;   b = 5   }
    Panel  = @{ r = 10;  g = 10;  b = 12  }
    Line   = @{ r = 38;  g = 38;  b = 43  }
    Card1  = @{ r = 12;  g = 13;  b = 17  }
    Card2  = @{ r = 13;  g = 12;  b = 16  }
    Card3  = @{ r = 16;  g = 14;  b = 18  }
    Card4  = @{ r = 11;  g = 11;  b = 13  }
    Select = @{ r = 24;  g = 24;  b = 30  }
    White  = @{ r = 255; g = 255; b = 255 }
    Off    = @{ r = 212; g = 212; b = 216 }
    Muted  = @{ r = 138; g = 141; b = 152 }
    Dim    = @{ r = 70;  g = 72;  b = 82  }
    Ink    = @{ r = 5;   g = 5;   b = 5   }
    Amber  = @{ r = 227; g = 179; b = 65  }
    Red    = @{ r = 255; g = 107; b = 107 }
}

$script:Menu = @(
    @{ N = '1'; Title = 'BUILD CLIENT EXECUTABLE'; Tag = 'RELEASE';      Card = $script:P.Card1
       Desc = 'Compile the engine, package the installer, and generate metadata.' }
    @{ N = '2'; Title = 'PUBLISH WEBSITE';         Tag = 'GITHUB PAGES'; Card = $script:P.Card2
       Desc = 'Commit the current site and push it to main for GitHub Pages.' }
    @{ N = '3'; Title = 'FULL SYNCHRONIZED RELEASE'; Tag = 'RECOMMENDED'; Card = $script:P.Card3
       Desc = 'Build the client, then deploy the website if the build succeeds.' }
    @{ N = '4'; Title = 'EXIT PIPELINE';           Tag = 'ESC';          Card = $script:P.Card4
       Desc = 'Close the console. No files or releases are changed.' }
)

$script:Width = 80

# -------------------------------------------------------------- helpers ----
function Get-Fg([hashtable]$Color) {
    return "$($script:Esc)[38;2;$($Color.r);$($Color.g);$($Color.b)m"
}

function Get-Bg([hashtable]$Color) {
    return "$($script:Esc)[48;2;$($Color.r);$($Color.g);$($Color.b)m"
}

function Seg([string]$Text, [hashtable]$Fore, [hashtable]$Back) {
    return [pscustomobject]@{ Text = $Text; Fg = $Fore; Bg = $Back }
}

function Repeat([char]$Char, [int]$Count) {
    if ($Count -le 0) { return '' }
    return ([string]$Char).PadLeft($Count, $Char)
}

function Limit-Text([string]$Text, [int]$Max) {
    if ($Max -lt 4) { return '' }
    if ($Text.Length -le $Max) { return $Text }
    return $Text.Substring(0, $Max - 3) + '...'
}

function Write-Line {
    param(
        [object[]]$Segments = @(),
        [hashtable]$Fill = $null,
        [string]$Indent = ''
    )

    if (-not $Fill) { $Fill = $script:P.Canvas }
    $visible = 0
    foreach ($segment in $Segments) { $visible += $segment.Text.Length }
    $pad = $script:Width - $Indent.Length - $visible
    if ($pad -lt 0) { $pad = 0 }

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append($Indent)
    foreach ($segment in $Segments) {
        [void]$builder.Append((Get-Bg $segment.Bg))
        [void]$builder.Append((Get-Fg $segment.Fg))
        [void]$builder.Append($segment.Text)
    }
    [void]$builder.Append((Get-Bg $Fill))
    [void]$builder.Append((Repeat ' ' $pad))
    [void]$builder.Append($script:Reset)
    Write-Host $builder.ToString()
}

function Convert-LogoArt([string]$Art) {
    $value = $Art
    $value = $value.Replace('L', [string]$script:G.Lower)
    $value = $value.Replace('U', [string]$script:G.Upper)
    $value = $value.Replace('F', [string]$script:G.Full)
    return $value
}

function Set-ConsoleSize {
    try {
        $raw = $Host.UI.RawUI
        $buffer = $raw.BufferSize
        if ($buffer.Width -lt 100) {
            $buffer.Width = 100
            $raw.BufferSize = $buffer
        }
        $window = $raw.WindowSize
        if ($window.Width -lt 90) {
            $window.Width = 90
            $raw.WindowSize = $window
        }
        if ($window.Height -lt 34) {
            $window.Height = 34
            $raw.WindowSize = $window
        }
    } catch { }
}

function Update-Width {
    $width = 0
    try { $width = $Host.UI.RawUI.WindowSize.Width } catch { $width = 80 }
    if ($width -lt 40) { $width = 80 }
    $script:Width = [Math]::Min(96, [Math]::Max(80, $width - 1))
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Find-InnoSetup {
    if ($env:INNO_SETUP_COMPILER) {
        $configured = $env:INNO_SETUP_COMPILER.Trim('"')
        if (Test-Path -LiteralPath $configured) { return $configured }
    }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 7\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 7\ISCC.exe')
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe')
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $command = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Invoke-Git {
    param([string[]]$GitArgs)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & git -C $script:RepoRoot @GitArgs 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return (($output | Out-String).Trim())
    } finally {
        $ErrorActionPreference = $previous
    }
}

function Update-Context {
    $metaPath = Join-Path $script:RepoRoot 'release\latest.json'
    $script:Meta = $null
    if (Test-Path -LiteralPath $metaPath) {
        try { $script:Meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json } catch { }
    }

    $branch = Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')
    $remote = Invoke-Git @('remote', 'get-url', 'origin')
    $changes = Invoke-Git @('status', '--porcelain')
    $remoteShort = $remote
    if ($remoteShort) {
        $remoteShort = $remoteShort -replace '^https?://github\.com/', '' -replace '\.git$', ''
    }

    $script:Repo = @{
        Branch      = if ($branch) { $branch } else { 'unknown' }
        RemoteShort = if ($remoteShort) { $remoteShort } else { 'no remote' }
        State       = if ($changes) { 'modified' } else { 'clean' }
    }

    $project = $env:INTRIQUE_PROJECT
    if (-not $project) { $project = 'C:\InTrique' }

    $script:Sys = @{
        Git       = (Test-Command 'git')
        Node      = (Test-Command 'node')
        CMake     = (Test-Command 'cmake')
        Gh        = (Test-Command 'gh')
        Inno      = (Find-InnoSetup)
        Project   = $project
        ProjectOk = (Test-Path -LiteralPath (Join-Path $project 'CMakeLists.txt'))
    }
}

# --------------------------------------------------------------- render ----
function Show-Header {
    $P = $script:P
    $G = $script:G

    $logo = @(
        '  LLLLLL LLLLLLLL ',
        '   UFFFF FFFFUUU  ',
        '     LLL LLL      ',
        '     FFF FFF      ',
        '     FFF FFF      ',
        '  LFFFFF UFF      ',
        ' UUUUUUU   U      '
    )
    $shades = @($P.White, $P.Off, $P.Dim, $P.Off, $P.Off, $P.Muted, $P.Dim)
    $logoWidth = 18
    $logoRows = @()
    for ($i = 0; $i -lt $logo.Count; $i++) {
        $logoRows += (Convert-LogoArt $logo[$i]).PadRight($logoWidth)
    }

    $ready = (
        $script:Sys.Git -and $script:Sys.Node -and $script:Sys.CMake -and
        $script:Sys.Inno -and $script:Sys.ProjectOk
    )
    $statusText = if ($ready) { 'READY FOR RELEASE' } else { 'ATTENTION REQUIRED' }
    $statusColor = if ($ready) { $P.White } else { $P.Amber }
    $statusDot = if ($ready) { $G.Dot } else { $G.Ring }
    $clock = [DateTime]::Now.ToString('HH:mm')
    $versionLabel = if ($script:Meta) { "v$($script:Meta.version)" } else { 'v-' }
    $metaLine = "WINDOWS x64  $($G.Mid)  $versionLabel  $($G.Mid)  GITHUB PAGES"

    $right = @(
        @((Seg 'I N T R I Q U E' $P.White $P.Canvas)),
        @((Seg 'R E L E A S E   P I P E L I N E' $P.Muted $P.Canvas)),
        @((Seg (Repeat $G.H 32) $P.Line $P.Canvas)),
        @((Seg $metaLine $P.Dim $P.Canvas)),
        @(
            (Seg "$statusDot " $statusColor $P.Canvas),
            (Seg $statusText $P.Off $P.Canvas),
            (Seg "   $($G.Mid)   " $P.Line $P.Canvas),
            (Seg $clock $P.Muted $P.Canvas)
        ),
        @((Seg 'intrique-owner.github.io/InTrique.web' $P.Dim $P.Canvas)),
        @((Seg 'release console  /  windows x64' $P.Dim $P.Canvas))
    )

    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '

    $gap = Seg '   ' $P.Muted $P.Canvas
    for ($i = 0; $i -lt $logoRows.Count; $i++) {
        $segments = @((Seg $logoRows[$i] $shades[$i] $P.Canvas), $gap)
        if ($right[$i].Count -gt 0) { $segments += $right[$i] }
        Write-Line $segments -Fill $P.Canvas
    }

    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '
}

function Show-SystemPanel {
    $P = $script:P
    $G = $script:G
    $sys = $script:Sys

    $segments = @()
    $segments += (Seg ('  SYSTEM').PadRight(14) $P.Muted $P.Panel)
    $tools = @(
        @{ Name = 'GIT';    Ok = $sys.Git },
        @{ Name = 'NODE';   Ok = $sys.Node },
        @{ Name = 'CMAKE';  Ok = $sys.CMake },
        @{ Name = 'INNO 7'; Ok = [bool]$sys.Inno },
        @{ Name = 'GH CLI'; Ok = $sys.Gh }
    )
    foreach ($tool in $tools) {
        $dot = if ($tool.Ok) { $G.Dot } else { $G.Ring }
        $dotColor = if ($tool.Ok) { $P.White } else { $P.Amber }
        $segments += (Seg "$dot " $dotColor $P.Panel)
        $segments += (Seg $tool.Name $P.Off $P.Panel)
        $segments += (Seg '    ' $P.Muted $P.Panel)
    }
    Write-Line $segments -Fill $P.Panel

    $projectColor = if ($sys.ProjectOk) { $P.White } else { $P.Amber }
    $projectDot = if ($sys.ProjectOk) { $G.Dot } else { $G.Ring }
    $projectState = if ($sys.ProjectOk) { 'CMakeLists.txt found' } else { 'CMakeLists.txt missing' }
    Write-Line @(
        (Seg ('  PROJECT').PadRight(14) $P.Muted $P.Panel),
        (Seg (Limit-Text $sys.Project 44) $P.Off $P.Panel),
        (Seg '   ' $P.Muted $P.Panel),
        (Seg "$projectDot " $projectColor $P.Panel),
        (Seg $projectState $projectColor $P.Panel)
    ) -Fill $P.Panel

    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Panel)) -Indent '  '

    $meta = $script:Meta
    $version = if ($meta) { "v$($meta.version)" } else { 'unavailable' }
    $released = if ($meta) { [string]$meta.released } else { '-' }
    $size = if ($meta) { [string]$meta.size_display } else { '-' }
    $sha = '-'
    if ($meta -and $meta.sha256) {
        $sha = $meta.sha256.Substring(0, [Math]::Min(12, $meta.sha256.Length))
    }
    Write-Line @(
        (Seg ('  RELEASE').PadRight(14) $P.Muted $P.Panel),
        (Seg $version $P.White $P.Panel),
        (Seg "   $($G.Mid)   " $P.Line $P.Panel),
        (Seg $released $P.Off $P.Panel),
        (Seg "   $($G.Mid)   " $P.Line $P.Panel),
        (Seg $size $P.Off $P.Panel),
        (Seg "   $($G.Mid)   sha " $P.Line $P.Panel),
        (Seg $sha $P.Muted $P.Panel)
    ) -Fill $P.Panel

    Write-Line @(
        (Seg ('  REPO').PadRight(14) $P.Muted $P.Panel),
        (Seg (Limit-Text $script:Repo.RemoteShort 40) $P.Off $P.Panel),
        (Seg "   $($G.Mid)   " $P.Line $P.Panel),
        (Seg $script:Repo.Branch $P.White $P.Panel),
        (Seg "   $($G.Mid)   " $P.Line $P.Panel),
        (Seg $script:Repo.State $P.Muted $P.Panel)
    ) -Fill $P.Panel

    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Panel)) -Indent '  '
}

function Show-Menu([int]$Selected) {
    $P = $script:P

    for ($i = 0; $i -lt $script:Menu.Count; $i++) {
        $item = $script:Menu[$i]
        $isSelected = ($i -eq $Selected)
        $card = if ($isSelected) { $P.Select } else { $item.Card }
        $accent = if ($isSelected) { $P.White } else { $P.Line }
        $titleColor = if ($isSelected) { $P.White } else { $P.Off }
        $descColor = if ($isSelected) { $P.Muted } else { $P.Dim }
        $chipBack = if ($isSelected) { $P.White } else { $P.Dim }
        $chipFore = if ($isSelected) { $P.Ink } else { $P.Off }
        $tagBack = if ($isSelected) { $P.White } else { $P.Panel }
        $tagFore = if ($isSelected) { $P.Ink } else { $P.Muted }

        $tagText = " $($item.Tag) "
        $used = 2 + 2 + 3 + 2 + $item.Title.Length + $tagText.Length + 2
        $spacer = $script:Width - $used
        if ($spacer -lt 2) { $spacer = 2 }

        Write-Line @(
            (Seg '  ' $titleColor $accent),
            (Seg '  ' $titleColor $card),
            (Seg " $($item.N) " $chipFore $chipBack),
            (Seg '  ' $titleColor $card),
            (Seg $item.Title $titleColor $card),
            (Seg (Repeat ' ' $spacer) $titleColor $card),
            (Seg $tagText $tagFore $tagBack),
            (Seg '  ' $titleColor $card)
        ) -Fill $card

        $descIndent = 9
        $desc = Limit-Text $item.Desc ($script:Width - $descIndent - 4)
        Write-Line @(
            (Seg '  ' $descColor $accent),
            (Seg (Repeat ' ' ($descIndent - 2)) $descColor $card),
            (Seg $desc $descColor $card)
        ) -Fill $card

        if ($i -lt $script:Menu.Count - 1) { Write-Line }
    }
}

function Show-Footer {
    $P = $script:P
    $G = $script:G

    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '
    Write-Line @(
        (Seg '  ' $P.Muted $P.Canvas),
        (Seg " $($G.Up)$($G.Down) " $P.Ink $P.White),
        (Seg '  NAVIGATE     ' $P.Muted $P.Canvas),
        (Seg ' ENTER ' $P.Ink $P.White),
        (Seg '  RUN     ' $P.Muted $P.Canvas),
        (Seg ' 1-4 ' $P.Ink $P.White),
        (Seg '  JUMP     ' $P.Muted $P.Canvas),
        (Seg ' ESC ' $P.Ink $P.White),
        (Seg '  EXIT' $P.Muted $P.Canvas)
    ) -Fill $P.Canvas
    Write-Line @(
        (Seg '  ' $P.Dim $P.Canvas),
        (Seg $script:RepoRoot $P.Dim $P.Canvas),
        (Seg "   $($G.Mid)   " $P.Dim $P.Canvas),
        (Seg $script:Repo.RemoteShort $P.Dim $P.Canvas)
    ) -Fill $P.Canvas
}

function Show-Dashboard([int]$Selected) {
    Update-Width
    try { Clear-Host } catch { }
    Show-Header
    Write-Line
    Show-SystemPanel
    Write-Line
    Write-Line @(
        (Seg '  ACTIONS' $P.Muted $P.Canvas),
        (Seg '   choose a pipeline stage' $P.Dim $P.Canvas)
    ) -Fill $P.Canvas
    Show-Menu $Selected
    Write-Line
    Show-Footer
}

function Show-ActionHeader([string]$Title, [string]$Subtitle) {
    Update-Width
    try { Clear-Host } catch { }
    $P = $script:P
    $G = $script:G
    Write-Line
    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '
    Write-Line @(
        (Seg '  ' $P.White $P.Canvas),
        (Seg 'INTRIQUE' $P.White $P.Canvas),
        (Seg '  /  ' $P.Dim $P.Canvas),
        (Seg $Title $P.Off $P.Canvas)
    ) -Fill $P.Canvas
    Write-Line @(
        (Seg '  ' $P.Muted $P.Canvas),
        (Seg $Subtitle $P.Dim $P.Canvas)
    ) -Fill $P.Canvas
    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '
    Write-Line
}

function Show-ActionResult([int]$Code) {
    Update-Width
    $P = $script:P
    $G = $script:G
    Write-Line
    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '
    if ($Code -eq 0) {
        $chip = Seg ' SUCCESS ' $P.Ink $P.White
        $message = 'Pipeline completed.'
    } else {
        $chip = Seg ' FAILED ' $P.White $P.Red
        $message = 'Pipeline stopped. Review the output above.'
    }
    Write-Line @(
        (Seg '  ' $P.White $P.Canvas),
        $chip,
        (Seg "  $message" $P.Off $P.Canvas),
        (Seg "   exit $Code" $P.Dim $P.Canvas)
    ) -Fill $P.Canvas
    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '
}

function Show-Exit {
    Update-Width
    try { Clear-Host } catch { }
    $P = $script:P
    $G = $script:G
    Write-Line
    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '
    Write-Line
    Write-Line @(
        (Seg '  INTRIQUE' $P.White $P.Canvas),
        (Seg '  /  RELEASE CONSOLE' $P.Muted $P.Canvas)
    ) -Fill $P.Canvas
    Write-Line @(
        (Seg '  Session closed. No processes are running.' $P.Dim $P.Canvas)
    ) -Fill $P.Canvas
    Write-Line
    Write-Line @((Seg (Repeat $G.H ($script:Width - 4)) $P.Line $P.Canvas)) -Indent '  '
    Write-Line
}

# --------------------------------------------------------------- actions ----
function Invoke-Batch([string]$Path, [string[]]$Arguments = @()) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Line @((Seg "  Missing script: $Path" $script:P.Red $script:P.Canvas)) -Fill $script:P.Canvas
        return 1
    }

    $command = $env:ComSpec
    if (-not $command) { $command = 'cmd.exe' }

    if ($Arguments.Count -gt 0) {
        & $command /c $Path @Arguments | Out-Host
    } else {
        & $command /c $Path | Out-Host
    }
    return $LASTEXITCODE
}

function Invoke-MenuAction([int]$Index) {
    $P = $script:P
    $code = 0

    switch ($Index) {
        1 {
            Show-ActionHeader 'BUILD CLIENT EXECUTABLE' 'Compile, package, and publish the Windows release.'
            $code = Invoke-Batch $script:BuildScript @('--no-pause')
        }
        2 {
            Show-ActionHeader 'PUBLISH WEBSITE' 'Commit the current site and push it to GitHub Pages.'
            $code = Invoke-Batch $script:WebsiteScript
        }
        3 {
            Show-ActionHeader 'FULL SYNCHRONIZED RELEASE' 'Build the client, then deploy the website.'
            Write-Line @(
                (Seg '  STAGE 1 / 2  ' $P.White $P.Canvas),
                (Seg 'BUILD CLIENT EXECUTABLE' $P.Muted $P.Canvas)
            ) -Fill $P.Canvas
            $code = Invoke-Batch $script:BuildScript @('--no-pause')
            if ($code -eq 0) {
                Write-Line
                Write-Line @(
                    (Seg '  STAGE 2 / 2  ' $P.White $P.Canvas),
                    (Seg 'PUBLISH WEBSITE' $P.Muted $P.Canvas)
                ) -Fill $P.Canvas
                $code = Invoke-Batch $script:WebsiteScript
            } else {
                Write-Line
                Write-Line @(
                    (Seg '  STAGE 2 / 2  ' $P.Dim $P.Canvas),
                    (Seg 'SKIPPED - the build did not complete' $P.Amber $P.Canvas)
                ) -Fill $P.Canvas
            }
        }
    }

    if ($Index -ne 4) {
        Show-ActionResult $code
        Update-Context
        if ($script:Interactive) {
            Write-Line
            Write-Line @((Seg '  Press any key to return to the console' $P.Muted $P.Canvas)) -Fill $P.Canvas
            try { [void][Console]::ReadKey($true) } catch { }
        }
    }
    return $code
}

# ------------------------------------------------------------------ main ----
$env:INTRIQUE_UI = '1'
Set-ConsoleSize
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
        'UpArrow'   { $selected = ($selected + 3) % 4 }
        'DownArrow' { $selected = ($selected + 1) % 4 }
        'Enter'     { $activate = $true }
        'Escape'    { $selected = 3; $activate = $true }
        default {
            $char = $key.KeyChar
            if ($char -ge [char]'1' -and $char -le [char]'4') {
                $selected = [int]$char - [int][char]'1'
                $activate = $true
            }
        }
    }

    if (-not $activate) { continue }
    if ($selected -eq 3) {
        Show-Exit
        break
    }
    [void](Invoke-MenuAction ($selected + 1))
}

exit 0
