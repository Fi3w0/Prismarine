; Windows installer (Inno Setup). CI calls:
;   iscc /DVersion=x.y.z /DSource=<install folder> /DOutput=<folder> prismarine.iss
#ifndef Version
  #define Version "0.0.0"
#endif

[Setup]
AppId={{6F0C2B52-7A1E-4C8E-9F43-5D2B9A61E0F7}
AppName=Prismarine
AppVersion={#Version}
AppPublisher=Fiw Labs
AppPublisherURL=https://github.com/Fi3w0
DefaultDirName={autopf}\Prismarine
DefaultGroupName=Prismarine
DisableProgramGroupPage=yes
; Per-user by default, so no administrator rights are needed; the dialog offers all users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile={#Source}\licenses\LICENSE
SetupIconFile=..\..\assets\logos\icons\prismarine.ico
UninstallDisplayIcon={app}\prismarine.exe
OutputDir={#Output}
OutputBaseFilename=Prismarine-{#Version}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Source}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Prismarine"; Filename: "{app}\prismarine.exe"
Name: "{autodesktop}\Prismarine"; Filename: "{app}\prismarine.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\prismarine.exe"; Description: "{cm:LaunchProgram,Prismarine}"; Flags: nowait postinstall skipifsilent
