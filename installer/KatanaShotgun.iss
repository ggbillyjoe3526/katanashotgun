; Windows installer for KATANA / SHOTGUN (Inno Setup 6).
; Built by .github/workflows/release.yml, with the forms tools/version.sh gives:
;   ISCC.exe "/DAppVersion=0.1 Dev 1" /DAppTag=0.1-dev.1 /DAppNumber=0.1.1.1 installer\KatanaShotgun.iss
; AppVersion is the name players see; AppTag goes in the file name; AppNumber
; is the four-number version Windows needs in the setup exe's properties.
; No slash in any file, folder or shortcut name: "KATANA SHOTGUN" there, the
; slash only in display text. Saves live in %APPDATA%\KatanaShotgun, never in
; the install folder, so uninstalling or upgrading never touches progress.

#ifndef AppVersion
  #define AppVersion "0.0"
#endif
#ifndef AppTag
  #define AppTag "0.0"
#endif
#ifndef AppNumber
  #define AppNumber "0.0.0.0"
#endif
#ifndef AppPublisher
  #define AppPublisher "ggbillyjoe3526"
#endif

[Setup]
; AppId identifies the game for upgrades and uninstall. NEVER change it.
AppId={{D6D0BE94-DB3E-4C11-9AE8-663EB30DCA64}
AppName=KATANA SHOTGUN
AppVerName=KATANA / SHOTGUN {#AppVersion}
AppVersion={#AppVersion}
VersionInfoVersion={#AppNumber}
VersionInfoProductVersion={#AppNumber}
VersionInfoTextVersion={#AppVersion}
VersionInfoProductTextVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/ggbillyjoe3526/katanashotgun
AppSupportURL=https://github.com/ggbillyjoe3526/katanashotgun/issues
AppUpdatesURL=https://github.com/ggbillyjoe3526/katanashotgun/releases
DefaultDirName={autopf}\KATANA SHOTGUN
DefaultGroupName=KATANA SHOTGUN
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=KatanaShotgun-v{#AppTag}-Windows-Setup
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\KatanaShotgun.ico
UninstallDisplayName=KATANA / SHOTGUN
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\KatanaShotgun.exe"; DestDir: "{app}"; Flags: ignoreversion
; The exe keeps Godot's icon (it is exported on Linux without rcedit), so shortcuts use this one.
Source: "icon.ico"; DestDir: "{app}"; DestName: "KatanaShotgun.ico"; Flags: ignoreversion
; Licences for the engine and fonts, shipped next to the game.
Source: "..\THIRD_PARTY_NOTICES.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\KATANA SHOTGUN"; Filename: "{app}\KatanaShotgun.exe"; IconFilename: "{app}\KatanaShotgun.ico"
Name: "{group}\Uninstall KATANA SHOTGUN"; Filename: "{uninstallexe}"
Name: "{autodesktop}\KATANA SHOTGUN"; Filename: "{app}\KatanaShotgun.exe"; IconFilename: "{app}\KatanaShotgun.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\KatanaShotgun.exe"; Description: "{cm:LaunchProgram,KATANA SHOTGUN}"; Flags: nowait postinstall skipifsilent
