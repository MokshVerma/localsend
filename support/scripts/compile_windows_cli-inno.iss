; Installer for the LocalSend CLI (localsend-cli.exe), including its MCP server mode.
; Build the CLI first:  cargo build --release -p localsend-cli
; Then compile this script:  iscc support\scripts\compile_windows_cli-inno.iss
; Output: dist\localsend-cli-setup.exe (override with /DResultDir=...)

#ifndef ResultDir
  #define ResultDir "..\..\dist"
#endif

#define MyAppName "LocalSend CLI"
#define MyAppVersion "1.18.2"
#define MyAppPublisher "Tien Do Nam"
#define MyAppURL "https://localsend.org"
#define MyAppExeName "localsend-cli.exe"

[Setup]
; Distinct from the Flutter app's AppId so both can be installed side by side.
AppId={{6F2C1B8E-3D47-4A59-9B0E-5C8A7D14E2F3}
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
OutputBaseFilename=localsend-cli-setup
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

[Tasks]
Name: "addtopath"; Description: "Add localsend-cli to the &PATH (needed to run it from any terminal or to register it as an MCP server)"
Name: "firewall"; Description: "Allow localsend-cli through Windows &Firewall on private networks (needed to receive files and be discovered)"; Check: IsAdminInstallMode

[Files]
Source: "..\..\target\release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\cli\MCP.md"; DestDir: "{app}"; Flags: ignoreversion

[Registry]
; Per-machine installs extend the system PATH, per-user installs the user PATH.
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Tasks: addtopath; Check: IsAdminInstallMode and NeedsAddPath(True)
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; Tasks: addtopath; Check: (not IsAdminInstallMode) and NeedsAddPath(False)

[Run]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#MyAppName}"" dir=in action=allow program=""{app}\{#MyAppExeName}"" profile=private enable=yes"; Flags: runhidden; Tasks: firewall; StatusMsg: "Adding the firewall rule..."

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#MyAppName}"" program=""{app}\{#MyAppExeName}"""; Flags: runhidden; RunOnceId: "RemoveFirewallRule"

[Code]
function NeedsAddPath(Machine: Boolean): Boolean;
var
  Paths, Subkey: string;
  Root: Integer;
begin
  if Machine then begin
    Root := HKLM;
    Subkey := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
  end else begin
    Root := HKCU;
    Subkey := 'Environment';
  end;
  if not RegQueryStringValue(Root, Subkey, 'Path', Paths) then
    Result := True
  else
    Result := Pos(';' + Lowercase(ExpandConstant('{app}')) + ';', ';' + Lowercase(Paths) + ';') = 0;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Paths, Subkey: string;
  Root, P: Integer;
  Entry: string;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  if IsAdminInstallMode then begin
    Root := HKLM;
    Subkey := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
  end else begin
    Root := HKCU;
    Subkey := 'Environment';
  end;
  if not RegQueryStringValue(Root, Subkey, 'Path', Paths) then Exit;
  Entry := ';' + ExpandConstant('{app}');
  P := Pos(Lowercase(Entry), Lowercase(Paths));
  if P > 0 then begin
    Delete(Paths, P, Length(Entry));
    RegWriteExpandStringValue(Root, Subkey, 'Path', Paths);
  end;
end;
