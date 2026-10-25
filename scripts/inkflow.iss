#define AppName "InkFlow"
#define AppVersion "1.3.0"
[Setup]
AppId={{B13D2420-0834-480D-B65D-5FD0E683D738}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=InkFlow Personal
DefaultDirName={localappdata}\Programs\InkFlow
DefaultGroupName=InkFlow
PrivilegesRequired=lowest
OutputDir=..\builds
OutputBaseFilename=InkFlow-Setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\inkflow.exe
CloseApplications=yes
[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el escritorio"; Flags: unchecked
[Files]
Source: "..\builds\Windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\LICENSES.md"; DestDir: "{app}"
Source: "..\docs\THIRD_PARTY_NOTICES.txt"; DestDir: "{app}"
Source: "..\app\vendor\appflowy_editor\LICENSE"; DestDir: "{app}\licenses"; DestName: "appflowy_editor-LICENSE.txt"
Source: "..\app\vendor\appflowy_editor\INKFLOW_PATCHES.md"; DestDir: "{app}\licenses"
Source: "..\builds\appflowy-editor-source.zip"; DestDir: "{app}\licenses"
[Icons]
Name: "{group}\InkFlow"; Filename: "{app}\inkflow.exe"
Name: "{autodesktop}\InkFlow"; Filename: "{app}\inkflow.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\inkflow.exe"; Description: "Abrir InkFlow"; Flags: nowait postinstall skipifsilent
