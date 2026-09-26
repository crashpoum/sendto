#define MyAppName "SendTo"
#define MyAppVersion "0.1.3"
#define MyAppPublisher "crashpoum"
#define MyAppExeName "sendto.exe"
#define ReleaseDir "..\..\..\..\dev\sendto\build\windows\x64\runner\Release"

#ifndef ReleaseDirOverride
  #define ReleaseDir "C:\dev\sendto\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{8E2C1A7B-4F19-4D3E-9C61-A1B2C3D4E5F6}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=C:\dev\sendto\installer\out
OutputBaseFilename=SendTo-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#MyAppExeName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Extra shortcuts:"; Flags: unchecked

[Files]
Source: "C:\dev\sendto\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch SendTo"; Flags: nowait postinstall skipifsilent
