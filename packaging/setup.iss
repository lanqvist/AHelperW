#define AppVersion "0.5.0"
#define RootDir AddBackslash(SourcePath) + ".."

[Setup]
AppId={{0F51413C-FD3A-49A6-9A5B-AB173A4D21E3}
AppName=AHelperW
AppVersion={#AppVersion}
AppPublisher=lanqvist
AppPublisherURL=https://github.com/lanqvist/AHelperW
DefaultDirName={autopf}\AHelperW
DefaultGroupName=AHelperW
UninstallDisplayIcon={app}\AHelperW.exe
OutputDir={#RootDir}\dist\release
OutputBaseFilename=AHelperW-Setup-{#AppVersion}-windows-x64
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
AppMutex=Local\AHelperW.Reader.Installed
CloseApplications=yes
RestartApplications=no
InfoBeforeFile={#RootDir}\packaging\INSTALL.txt
SetupLogging=yes

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Ридер и аддон"
Name: "custom"; Description: "Выбор компонентов"; Flags: iscustom

[Components]
Name: "reader"; Description: "Ридер AHelperW с Python и OCR"; Types: full custom; Flags: fixed
Name: "addon"; Description: "Аддон для World of Warcraft Retail"; Types: full

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; Flags: unchecked

[Files]
Source: "{#RootDir}\dist\AHelperW\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#RootDir}\AHelperW\*"; DestDir: "{code:GetAddonDir}"; Components: addon; Flags: ignoreversion recursesubdirs createallsubdirs uninsneveruninstall
Source: "{#RootDir}\packaging\INSTALL.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootDir}\THIRD_PARTY_NOTICES.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#RootDir}\docs\arms-apl\COPYING"; DestDir: "{app}"; DestName: "SimulationCraft-COPYING.txt"; Flags: ignoreversion
Source: "{#RootDir}\dist\release\AHelperW-Source-{#AppVersion}.zip"; DestDir: "{app}\Source"; Flags: ignoreversion

[Icons]
Name: "{group}\AHelperW"; Filename: "{app}\AHelperW.exe"; WorkingDir: "{app}"
Name: "{group}\Инструкция"; Filename: "{app}\INSTALL.txt"
Name: "{autodesktop}\AHelperW"; Filename: "{app}\AHelperW.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Code]
var
  WoWPage: TInputDirWizardPage;
  AddonBackupDone: Boolean;

function RetailDir(): String;
begin
  Result := RemoveBackslashUnlessRoot(WoWPage.Values[0]);
  if DirExists(Result + '\_retail_') then Result := Result + '\_retail_';
end;

function GetAddonDir(Param: String): String;
begin
  Result := RetailDir() + '\Interface\AddOns\AHelperW';
end;

function IsRetailDirValid(): Boolean;
begin
  Result := (ExtractFileName(RetailDir()) = '_retail_') and FileExists(RetailDir() + '\Wow.exe');
end;

procedure InitializeWizard;
var
  Suggested: String;
begin
  AddonBackupDone := False;
  WoWPage := CreateInputDirPage(wpSelectComponents, 'Папка World of Warcraft',
    'Выбери папку игры или её подпапку _retail_.',
    'Аддон установится в _retail_\Interface\AddOns\AHelperW. Существующая версия будет сохранена в Backups рядом с ридером. Настройки WTF не изменяются.', False, '');
  WoWPage.Add('Папка World of Warcraft Retail:');
  Suggested := ExpandConstant('{autopf32}\World of Warcraft');
  if DirExists(Suggested + '\_retail_') then WoWPage.Values[0] := Suggested;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = WoWPage.ID) and not WizardIsComponentSelected('addon');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (CurPageID = WoWPage.ID) and WizardIsComponentSelected('addon') and not IsRetailDirValid() then begin
    MsgBox('Не найден _retail_\Wow.exe. Выбери установленный World of Warcraft Retail или отключи компонент аддона.', mbError, MB_OK);
    Result := False;
  end;
end;

function BackupTree(SourceDir, DestDir: String): Boolean;
var
  Item: TFindRec;
begin
  Result := ForceDirectories(DestDir);
  if not Result then Exit;
  if FindFirst(SourceDir + '\*', Item) then begin
    try
      repeat
        if (Item.Name <> '.') and (Item.Name <> '..') then begin
          { Refuse junctions rather than following paths outside the addon. }
          if (Item.Attributes and $400) <> 0 then begin Result := False; Exit; end;
          if (Item.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
            Result := BackupTree(SourceDir + '\' + Item.Name, DestDir + '\' + Item.Name)
          else
            Result := FileCopy(SourceDir + '\' + Item.Name, DestDir + '\' + Item.Name, True);
          if not Result then Exit;
        end;
      until not FindNext(Item);
    finally
      FindClose(Item);
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  BackupDir: String;
begin
  Result := '';
  if WizardIsComponentSelected('addon') then begin
    if not IsRetailDirValid() then begin
      Result := 'Выбери папку установленного World of Warcraft Retail.';
      Exit;
    end;
    if not AddonBackupDone and DirExists(GetAddonDir('')) then begin
      BackupDir := ExpandConstant('{app}\Backups\AHelperW-') + GetDateTimeString('yyyymmdd-hhnnss', '-', ':');
      if not BackupTree(GetAddonDir(''), BackupDir) then begin
        Result := 'Не удалось сохранить старый аддон. Установка остановлена. Проверь доступ к папкам.';
        Exit;
      end;
    end;
    AddonBackupDone := True;
  end;
end;
