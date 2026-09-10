; Inno Setup script for Master Idea.
;
; Built by CI on windows-latest; see .github/workflows/ci.yml. Compile with:
;
;   ISCC /DAppVersion=0.1.0.42 /DBuildDir=..\..\build\windows\x64\runner\Release ^
;        /DOutputDir=..\..\..\out /DOutputBase=MasterIdeaSetup-42-a1b2c3d ^
;        master_idea.iss
;
; Two properties matter more than anything else here.
;
; **Per-user, so there is no UAC prompt.** PrivilegesRequired=lowest makes
; {autopf} resolve to %LOCALAPPDATA%\Programs, which the user already owns.
; Installing into Program Files would need elevation on every update, which is
; the opposite of the one-click update this exists to serve.
;
; **AppId never changes.** It, with the install directory, is what makes the
; next install an upgrade rather than a second copy beside the first. Change it
; and every user ends up with two Master Ideas and two uninstall entries.

#define AppName "Master Idea"
#define AppExe "MasterIdea.exe"
#define AppPublisher "Master Idea"
#define AppUrl "https://github.com/kaiharimoto/Master-Idea"

#ifndef AppVersion
  #define AppVersion "0.1.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\..\out"
#endif
#ifndef OutputBase
  #define OutputBase "MasterIdeaSetup"
#endif

[Setup]
AppId={{3F7A9C21-58B4-4D0E-9E6C-1B2D8A4F7C05}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases/tag/dev
VersionInfoVersion={#AppVersion}

; Per-user. No administrator, no UAC prompt, no elevation on update.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableDirPage=auto

; Windows' own list of installed programs, so it can be removed the ordinary
; way rather than by deleting a folder.
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExe}

OutputDir={#OutputDir}
OutputBaseFilename={#OutputBase}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

; Replaces a running copy instead of failing with "file in use". The app closes
; itself before spawning a silent update, but someone who runs the installer by
; hand with the app open should not have to think about it.
CloseApplications=yes
CloseApplicationsFilter=*.exe,*.dll
; The relaunch is ours, via [Run] below, so Restart Manager must not also try.
RestartApplications=no
SetupMutex=MasterIdeaSetupMutex

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; \
  GroupDescription: "Shortcuts:"; Flags: unchecked

; A council sitting runs for hours with nobody watching, and nothing happens
; while the app is shut. Starting with Windows needs no code at all, and this
; is where people expect to find the choice. Unticked, because an app that adds
; itself to startup uninvited is a different kind of rude.
Name: "startup"; Description: "Start Master Idea when I sign in"; \
  GroupDescription: "Long sittings:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; \
  Tasks: desktopicon
Name: "{autostartup}\{#AppName}"; Filename: "{app}\{#AppExe}"; \
  Tasks: startup

[Run]
; The ordinary end-of-wizard tick box. Suppressed in a silent install.
Filename: "{app}\{#AppExe}"; Description: "Start {#AppName}"; \
  Flags: nowait postinstall skipifsilent

; The silent update's relaunch. The app spawns this installer with
; /relaunch=1, so it reopens itself when the copy is finished — the whole
; difference between "one click" and "now find it again".
Filename: "{app}\{#AppExe}"; Flags: nowait runasoriginaluser; \
  Check: WantsRelaunch

[Code]
function WantsRelaunch: Boolean;
begin
  Result := ExpandConstant('{param:relaunch|0}') = '1';
end;
