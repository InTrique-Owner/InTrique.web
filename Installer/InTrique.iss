
; ============================================================
; InTrique Windows x64 Installer
; Built by scripts\build-release.bat
; ============================================================

#ifndef MyAppVersion
  #define MyAppVersion "0.1.1"
#endif

#ifndef InTriqueBin
  #define InTriqueBin "C:\InTrique\Build\Bin"
#endif

#define MyAppName "InTrique"
#define MyAppPublisher "InTrique"
#define MyAppExeName "InTriqueClient.exe"
#define MyAppWebsite "https://intrique-owner.github.io/InTrique.web/"

[Setup]

; ------------------------------------------------------------
; APPLICATION IDENTITY
; Keep AppId unchanged across all releases so upgrades work.
; ------------------------------------------------------------

AppId={{A6B2A5D9-4E30-4C3E-9E3B-1A2B3C4D5E6F}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppWebsite}

DefaultDirName={autopf}\InTrique
DefaultGroupName=InTrique
UsePreviousAppDir=yes
UsePreviousTasks=yes

; ------------------------------------------------------------
; INSTALLER AND UNINSTALLER DETAILS
; ------------------------------------------------------------

SetupIconFile="{#InTriqueBin}\Assets\Icon\Icon.ico"
UninstallDisplayName={#MyAppName}
; AppVersion above automatically supplies the Add/Remove Programs version.
UninstallDisplayIcon={app}\Assets\Icon\Icon.ico

VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=InTrique Setup
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}.0
VersionInfoOriginalFileName=InTrique-Setup.exe

; ------------------------------------------------------------
; INTRIQUE BLACK / WHITE INSTALLER STYLE
; ------------------------------------------------------------

WizardStyle=modern dark polar includetitlebar hidebevels
WizardBackColor=black
WizardImageBackColor=black
WizardSmallImageBackColor=black
WizardSizePercent=100

; Artwork paths are relative to this .iss file (Installer\).
WizardImageFile=Assets\Welcome.png
WizardSmallImageFile=Assets\Header.png
WizardImageOpacity=255

; ------------------------------------------------------------
; OUTPUT
; build-release.bat overrides OutputDir with /O.
; This relative fallback also works when compiling manually.
; ------------------------------------------------------------

OutputDir=..\Downloads
OutputBaseFilename=InTrique-Setup

; ------------------------------------------------------------
; COMPRESSION
; ------------------------------------------------------------

Compression=lzma2
SolidCompression=yes

; ------------------------------------------------------------
; 64-BIT CLIENT SUPPORT
; ------------------------------------------------------------

SetupArchitecture=x64
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; ------------------------------------------------------------
; INSTALL / UPGRADE BEHAVIOUR
; ------------------------------------------------------------

PrivilegesRequired=admin
Uninstallable=yes
SetupLogging=yes
CloseApplications=yes
RestartApplications=no

DisableProgramGroupPage=yes
DisableDirPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; \
    Description: "Create a desktop shortcut"; \
    GroupDescription: "Additional shortcuts:"; \
    Flags: unchecked

Name: "startmenuicon"; \
    Description: "Create a Start Menu shortcut"; \
    GroupDescription: "Additional shortcuts:"; \
    Flags: checkedonce

[Files]

; Main application executable.
Source: "{#InTriqueBin}\{#MyAppExeName}"; \
    DestDir: "{app}"; \
    Flags: ignoreversion

; Application assets, including the application icon.
Source: "{#InTriqueBin}\Assets\*"; \
    DestDir: "{app}\Assets"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; Game content.
Source: "{#InTriqueBin}\Games\*"; \
    DestDir: "{app}\Games"; \
    Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

[Icons]

; Start Menu shortcut.
Name: "{autoprograms}\InTrique"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    IconFilename: "{app}\Assets\Icon\Icon.ico"; \
    Tasks: startmenuicon

; Optional Desktop shortcut.
Name: "{autodesktop}\InTrique"; \
    Filename: "{app}\{#MyAppExeName}"; \
    WorkingDir: "{app}"; \
    IconFilename: "{app}\Assets\Icon\Icon.ico"; \
    Tasks: desktopicon

[Run]

Filename: "{app}\{#MyAppExeName}"; \
    Description: "Launch InTrique"; \
    WorkingDir: "{app}"; \
    Flags: nowait postinstall skipifsilent
