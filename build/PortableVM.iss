[Setup]
AppName=PortableVM Setup
AppVersion=0.1-beta
DefaultDirName={code:GetTempDir}
CreateAppDir=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableFinishedPage=yes
DisableWelcomePage=yes
SolidCompression=yes
OutputDir=..\
OutputBaseFilename=PortableVM_Setup
Uninstallable=no
PrivilegesRequired=lowest
ShowLanguageDialog=no
SetupIconFile=..\logo\portable_vm_logo.ico
ArchitecturesAllowed=x64 arm64
ArchitecturesInstallIn64BitMode=x64 arm64

[Files]
Source: "..\scripts\*"; DestDir: "{app}\scripts"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "..\logo\*"; DestDir: "{app}\logo"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "..\config.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\launch*"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\setup*"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Dirs]
Name: "{app}\vms"
Name: "{app}\backends\windows\qemu"

[Code]
var
  TempPath: String;

function GetTempDir(Param: String): String;
begin
  if TempPath = '' then
  begin
    TempPath := ExpandConstant('{localappdata}\Temp\PortableVM_Setup_') + GetDateTimeString('yyyymmddhhnnss', '-', ':');
  end;
  Result := TempPath;
end;

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\scripts\windows\setup_installer.ps1"" -SourceRoot ""{app}"""; Flags: nowait runhidden
