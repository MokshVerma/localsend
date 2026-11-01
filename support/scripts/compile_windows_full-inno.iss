; All-in-one Windows installer: the LocalSend desktop app, the CLI with its MCP server, and the setup
; around them (PATH, firewall rules, registering the MCP server with Claude Code).
;
; Build:
;   1. cd app; fvm flutter build windows --release
;   2. cargo build --release -p localsend-cli
;   3. iscc support\scripts\compile_windows_full-inno.iss
; Output: dist\localsend-full-setup.exe (override with /DResultDir=...)

#ifndef AppBuildDir
  #define AppBuildDir "..\..\app\build\windows\x64\runner\Release"
#endif
#ifndef RuntimeDir
  #define RuntimeDir "..\build\windows\x64"
#endif
#ifndef ResultDir
  #define ResultDir "..\..\dist"
#endif

#define MyAppName "LocalSend"
#define MyAppVersion "1.18.2"
#define MyAppPublisher "Tien Do Nam"
#define MyAppURL "https://localsend.org"
#define MyAppExeName "localsend_app.exe"
#define MyCliExeName "localsend-cli.exe"

; The MCP endpoint the desktop app serves while it runs (see app/lib/provider/agent_server_provider.dart).
#define MyMcpUrl "http://127.0.0.1:53319/mcp"

[Setup]
; Distinct from the app-only installer's AppId, which stays installable on its own.
AppId={{B4E7A2D9-61C3-4F08-8A15-2E9D0C73F6B1}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#ResultDir}
OutputBaseFilename=localsend-full-setup
SetupIconFile=..\..\app\assets\packaging\logo.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes
UsedUserAreasWarning=no
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full installation (app, CLI and agent integration)"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "app"; Description: "LocalSend desktop app"; Types: full custom
Name: "cli"; Description: "Command-line tool and MCP server for AI agents"; Types: full

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Components: app; Flags: unchecked
Name: "addtopath"; Description: "Add localsend-cli to the &PATH"; GroupDescription: "Command-line tool:"; Components: cli
Name: "firewall"; Description: "Allow LocalSend through Windows &Firewall on private networks (needed to receive files and be discovered)"; GroupDescription: "Network:"; Check: IsAdminInstallMode
Name: "mcp"; Description: "Register the MCP server with &Claude Code, so Claude can send and receive files (served by LocalSend while it is open)"; GroupDescription: "Agent integration:"; Components: cli; Check: ClaudeAvailable

[Files]
Source: "{#AppBuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Components: app; Flags: ignoreversion
Source: "{#AppBuildDir}\*.dll"; DestDir: "{app}"; Components: app; Flags: ignoreversion
Source: "{#AppBuildDir}\data\*"; DestDir: "{app}\data"; Components: app; Flags: ignoreversion recursesubdirs createallsubdirs
; The Visual C++ runtime the app needs, as in the app-only installer.
Source: "{#RuntimeDir}\*.dll"; DestDir: "{app}"; Components: app; Flags: ignoreversion skipifsourcedoesntexist
Source: "..\..\target\release\{#MyCliExeName}"; DestDir: "{app}\cli"; Components: cli; Flags: ignoreversion
Source: "..\..\cli\MCP.md"; DestDir: "{app}\cli"; Components: cli; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Components: app
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Components: app; Tasks: desktopicon

[Registry]
; Per-machine installs extend the system PATH, per-user installs the user PATH.
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\cli"; Components: cli; Tasks: addtopath; Check: IsAdminInstallMode and NeedsAddPath(True)
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}\cli"; Components: cli; Tasks: addtopath; Check: (not IsAdminInstallMode) and NeedsAddPath(False)

[Run]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName}"" dir=in action=allow program=""{app}\{#MyAppExeName}"" profile=private enable=yes"; Flags: runhidden; Components: app; Tasks: firewall; StatusMsg: "Adding the firewall rule for the app..."
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName} CLI"" dir=in action=allow program=""{app}\cli\{#MyCliExeName}"" profile=private enable=yes"; Flags: runhidden; Components: cli; Tasks: firewall; StatusMsg: "Adding the firewall rule for the CLI..."
; Replace an earlier registration (it errors harmlessly when there is none), as the user who runs Claude Code.
Filename: "{cmd}"; Parameters: "/C claude mcp remove localsend --scope user"; Flags: runhidden runasoriginaluser; Components: cli; Tasks: mcp; StatusMsg: "Registering the MCP server..."
Filename: "{cmd}"; Parameters: "/C claude mcp add --scope user --transport http localsend {#MyMcpUrl}"; Flags: runhidden runasoriginaluser; Components: cli; Tasks: mcp; StatusMsg: "Registering the MCP server..."
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent; Components: app

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#MyAppName}"" program=""{app}\{#MyAppExeName}"""; Flags: runhidden; RunOnceId: "RemoveAppFirewallRule"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#MyAppName} CLI"" program=""{app}\cli\{#MyCliExeName}"""; Flags: runhidden; RunOnceId: "RemoveCliFirewallRule"
Filename: "{cmd}"; Parameters: "/C claude mcp remove localsend --scope user"; Flags: runhidden; RunOnceId: "RemoveMcpRegistration"

[Code]
function ClaudeAvailable: Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(ExpandConstant('{cmd}'), '/C where claude >nul 2>nul', '', SW_HIDE, ewWaitUntilTerminated, ResultCode)
    and (ResultCode = 0);
end;

procedure PathLocation(Machine: Boolean; var Root: Integer; var Subkey: string);
begin
  if Machine then begin
    Root := HKLM;
    Subkey := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
  end else begin
    Root := HKCU;
    Subkey := 'Environment';
  end;
end;

function NeedsAddPath(Machine: Boolean): Boolean;
var
  Paths, Subkey: string;
  Root: Integer;
begin
  PathLocation(Machine, Root, Subkey);
  if not RegQueryStringValue(Root, Subkey, 'Path', Paths) then
    Result := True
  else
    Result := Pos(';' + Lowercase(ExpandConstant('{app}\cli')) + ';', ';' + Lowercase(Paths) + ';') = 0;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Paths, Subkey, Entry: string;
  Root, P: Integer;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  PathLocation(IsAdminInstallMode, Root, Subkey);
  if not RegQueryStringValue(Root, Subkey, 'Path', Paths) then Exit;
  Entry := ';' + ExpandConstant('{app}\cli');
  P := Pos(Lowercase(Entry), Lowercase(Paths));
  if P > 0 then begin
    Delete(Paths, P, Length(Entry));
    RegWriteExpandStringValue(Root, Subkey, 'Path', Paths);
  end;
end;
