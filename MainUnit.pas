unit MainUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Types;

const
  WM_COMPLETE = WM_APP + 1;
  WM_PROGRESS = WM_APP + 2;

type
  TConversionSettings = record
    FileDate: TDateTime;
    Files: TStringDynArray;
    SelectedFolderPath: string;
    DestinationPath: string;
    UseDestinationFolder: Boolean;
  end;

  TWorkThread = class(TThread)
  private
    FHandle: THandle;
    FAbort: Boolean;
    FConversionSettings: TConversionSettings;
    procedure RemoveMetaData;
    procedure RemoveMetaDataFromFile(const AFileName: string;
      out ANewFileName: string);
    function StartProcess(const ExeName: string; const CmdLineArgs: string;
      var Response: string): Integer;
    procedure SetFileDateToFile(const AFileName: string);
  protected
    procedure Execute; override;
  public
    constructor Create(AHandle: THandle; AConversionSettings: TConversionSettings);
    property Abort: Boolean read FAbort write FAbort;
  end;

  TMainForm = class(TForm)
    lblFolderText: TLabel;
    lblSelectedFolder: TLabel;
    btnSelectFolder: TButton;
    btnStart: TButton;
    cbSetFileDate: TCheckBox;
    dtpFileDate: TDateTimePicker;
    lblFileCount: TLabel;
    lblFileCountText: TLabel;
    pbProgress: TProgressBar;
    lblProgress: TLabel;
    btnSelectFiles: TButton;
    lblFilesText: TLabel;
    lblSelectedFiles: TLabel;
    cbSetOutputFolder: TCheckBox;
    lblOutputFolder: TLabel;
    btnOutputFolder: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSelectFolderClick(Sender: TObject);
    procedure cbSetFileDateClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnSelectFilesClick(Sender: TObject);
    procedure cbSetOutputFolderClick(Sender: TObject);
    procedure btnOutputFolderClick(Sender: TObject);
  private
    FWorkThread: TWorkThread;
    FConversionSettings: TConversionSettings;
    FFileTypesArr: TStringDynArray;
    function IncludeFolderPathDelimiter(const APath: string): string;
    function AllowedFileTypes(const AFileType: string): Boolean;
    function GetFilesFromPath(const APath: string): TStringDynArray;
    function CleanTimeFromSeconds(ADate: TDateTime): TDateTime;
    procedure SetDestinationPath(const APath: string);
    procedure ProgressUpdate(var AMsg: TMessage); message WM_PROGRESS;
    procedure ProcessComplete(var AMsg: TMessage); message WM_COMPLETE;
    procedure WMDropFiles(var AMsg: TWMDropFiles); message WM_DROPFILES;
    procedure DoTerminate(ASender: TObject);
    procedure LoadSettings;
    procedure SaveSettings;
    procedure GetFilesFromFolder;
    procedure SetButtons;
    procedure EnableFiles;
    procedure EnableFolder;
    procedure DisableFiles;
    procedure DisableFolders;
    function FolderCheck: Boolean;
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}
uses
  JSON.Serializers, IOUtils, ShellAPI,
  DateUtils, Math, StrUtils, Masks;

const
  SETTINGS_FILENAME = 'Settings.json';
  TMP_FOLDER = 'tmp';
  SUPPORTED_FILE_TYPES = 'mp4;mkv';

type
  TSettings = record
    FileDate: TDateTime;
    SetFileDate: Boolean;
    SetOutputFolder: Boolean;
    OutputFolder: string;
  end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FFileTypesArr := SplitString(SUPPORTED_FILE_TYPES, ';');
  btnStart.Enabled := False;
  DisableFiles;
  DisableFolders;
  dtpFileDate.Enabled := False;
  lblFileCount.Caption := '-';
  lblProgress.Caption := '';
  DragAcceptFiles(Handle, True);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  DragAcceptFiles(Handle, False);
  SaveSettings;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  SendMessage(Handle, WM_PROGRESS, 0, 0);
  LoadSettings;
  cbSetOutputFolderClick(nil);
end;

procedure TMainForm.EnableFiles;
begin
  pbProgress.Position := 0;
  lblFileCount.Caption := Length(FConversionSettings.Files).ToString;

  SetButtons;

  if Length(FConversionSettings.Files) = 0 then
  begin
    ShowMessage('There is no mp4 or mkv file selected.');
    Exit;
  end;

  SendMessage(Handle, WM_PROGRESS, 0, Length(FConversionSettings.Files));

  if Length(FConversionSettings.Files) > 1 then
    lblSelectedFiles.Caption := 'Multiple files'
  else
    lblSelectedFiles.Caption := FConversionSettings.Files[0];

  lblSelectedFiles.Font.Style := [];
  lblSelectedFiles.Font.Color := clGreen;

  DisableFolders;
end;

procedure TMainForm.EnableFolder;
begin
  pbProgress.Position := 0;
  GetFilesFromFolder;
  SetButtons;

  if Length(FConversionSettings.Files) = 0 then
  begin
    ShowMessage('There are no mp4 or mkv files in this folder.');
    Exit;
  end;

  SendMessage(Handle, WM_PROGRESS, 0, Length(FConversionSettings.Files));

  lblSelectedFolder.Caption := FConversionSettings.SelectedFolderPath;
  lblSelectedFolder.Font.Style := [];
  lblSelectedFolder.Font.Color := clGreen;

  DisableFiles;
end;

procedure TMainForm.DisableFolders;
begin
  lblSelectedFolder.Caption := 'Select a folder';
  lblSelectedFolder.Font.Style := [fsItalic];
  lblSelectedFolder.Font.Color := clWindowText;
end;

procedure TMainForm.DisableFiles;
begin
  lblSelectedFiles.Caption := 'Select file(s)';
  lblSelectedFiles.Font.Style := [fsItalic];
  lblSelectedFiles.Font.Color := clWindowText;
end;

procedure TMainForm.GetFilesFromFolder;
begin
  FConversionSettings.Files := GetFilesFromPath(FConversionSettings.SelectedFolderPath);
  lblFileCount.Caption := Length(FConversionSettings.Files).ToString;
end;

function TMainForm.GetFilesFromPath(const APath: string): TStringDynArray;
var
  Predicate: TDirectory.TFilterPredicate;
begin
  Predicate :=
    function(const Path: string; const SearchRec: TSearchRec): Boolean
    begin
      for var LType in FFileTypesArr do
        if MatchesMask(SearchRec.Name, '*.' + LType) then
          Exit(True);

      Result := False;
    end;
  Result := TDirectory.GetFiles(APath, Predicate);
end;

function TMainForm.IncludeFolderPathDelimiter(const APath: string): string;
begin
  if APath.EndsWith('\') then
    Result := APath
  else
    Result := APath + '\';
end;

function TMainForm.AllowedFileTypes(const AFileType: string): Boolean;
begin
  for var LType in FFileTypesArr do
    if MatchesMask(AFileType, '*.' + LType) then
      Exit(True);

  Result := False;
end;

procedure TMainForm.btnOutputFolderClick(Sender: TObject);
begin
  var LFd := TFileOpenDialog.Create(nil);
  try
    LFd.Options := [fdoPickFolders];
    if LFd.Execute then
    begin
      pbProgress.Position := 0;
      SetDestinationPath(LFd.FileName);
      SetButtons;
    end;
  finally
    LFd.Free;
  end;
end;

procedure TMainForm.btnSelectFolderClick(Sender: TObject);
begin
  var LFd := TFileOpenDialog.Create(nil);
  try
    LFd.Options := [fdoPickFolders];
    if LFd.Execute then
    begin
      FConversionSettings.SelectedFolderPath := LFd.FileName;
      EnableFolder;
    end;
  finally
    LFd.Free;
  end;
end;

procedure TMainForm.btnSelectFilesClick(Sender: TObject);
begin
  var LFd := TFileOpenDialog.Create(nil);
  try
    for var LType in FFileTypesArr do
    begin
      var LItem := LFd.FileTypes.Add;
      LItem.DisplayName := Format('%s file', [LType]);
      Litem.FileMask := '*.' + LType;
    end;
    LFd.Options := [fdoAllowMultiSelect];

    if LFd.Execute then
    begin
      FConversionSettings.Files := LFd.Files.ToStringArray;
      EnableFiles;
    end;
  finally
    LFd.Free;
  end;
end;

procedure TMainForm.btnStartClick(Sender: TObject);
begin
  if Assigned(FWorkThread) then
  begin
    FWorkThread.Abort := True;
    btnStart.Caption := 'Aborting...';
    btnStart.Enabled := False;
  end
  else
  begin
    if not FConversionSettings.UseDestinationFolder then
      FConversionSettings.DestinationPath :=
        TPath.Combine(ExtractFilePath(FConversionSettings.Files[0]), TMP_FOLDER);

    if not FolderCheck then
    begin
      ShowMessage('It''s not allowed to use the same folder as output folder.');
      Exit;
    end;

    btnStart.Caption := 'Stop';
    btnSelectFolder.Enabled := False;
    cbSetFileDate.Enabled := False;
    dtpFileDate.Enabled := False;
    FConversionSettings.FileDate := RecodeMilliSecond(RecodeSecond(IfThen(cbSetFileDate.Checked, dtpFileDate.dateTime, 0), 0), 0);

    FWorkThread := TWorkThread.Create(Handle, FConversionSettings);
    FWorkThread.OnTerminate := DoTerminate;
  end;
end;

procedure TMainForm.cbSetFileDateClick(Sender: TObject);
begin
  dtpFileDate.Enabled := cbSetFileDate.Checked;
end;

procedure TMainForm.cbSetOutputFolderClick(Sender: TObject);
begin
  FConversionSettings.UseDestinationFolder := cbSetOutputFolder.Checked;
  lblOutputFolder.Enabled := cbSetOutputFolder.Checked;
  btnOutputFolder.Enabled := cbSetOutputFolder.Checked;
  SetButtons;
end;

procedure TMainForm.DoTerminate(ASender: TObject);
begin
  FWorkThread := nil;
  btnStart.Caption := 'Start';
  btnStart.Enabled := True;
end;

procedure TMainForm.LoadSettings;
begin
  var LSettings := Default(TSettings);
  LSettings.FileDate := CleanTimeFromSeconds(Now);

  if TFile.Exists(SETTINGS_FILENAME) then
  begin
    var LSerializer := TJsonSerializer.Create;
    try
      var LStr := TFile.ReadAllText(SETTINGS_FILENAME, TEncoding.UTF8);
       LSettings := LSerializer.DeSerialize<TSettings>(LStr);
    finally
      LSerializer.Free;
    end;
  end;

  // Update GUI.
  cbSetFileDate.Checked := LSettings.SetFileDate;
  dtpFileDate.DateTime := CleanTimeFromSeconds(LSettings.FileDate);
  cbSetOutputFolder.Checked := LSettings.SetOutputFolder;
  SetDestinationPath(LSettings.OutputFolder);
end;

procedure TMainForm.SaveSettings;
begin
  var LSettings: TSettings;

  // Read from GUI.
  LSettings.SetFileDate := cbSetFileDate.Checked;
  LSettings.FileDate := CleanTimeFromSeconds(dtpFileDate.DateTime);
  LSettings.SetOutputFolder := cbSetOutputFolder.Checked;
  LSettings.OutputFolder := FConversionSettings.DestinationPath;

  var LSerializer := TJsonSerializer.Create;
  try
    var LStr := LSerializer.Serialize<TSettings>(LSettings);
    TFile.WriteAllText(SETTINGS_FILENAME, LStr, TEncoding.UTF8);
  finally
    LSerializer.Free;
  end;
end;

procedure TMainForm.SetButtons;
begin
  btnStart.Enabled := (Length(FConversionSettings.Files) > 0) and
    (FConversionSettings.UseDestinationFolder and TDirectory.Exists(FConversionSettings.DestinationPath) or not FConversionSettings.UseDestinationFolder);
end;

procedure TMainForm.SetDestinationPath(const APath: string);
begin
  if APath.IsEmpty or not TDirectory.Exists(APath) then
  begin
    FConversionSettings.DestinationPath := '';
    lblOutputFolder.Caption := 'Select a folder';
    lblOutputFolder.Font.Style := [fsItalic];
    lblOutputFolder.Font.Color := clWindowText;
    FConversionSettings.UseDestinationFolder := False;
  end
  else
  begin
    FConversionSettings.DestinationPath := APath;
    lblOutputFolder.Caption := APath;
    lblOutputFolder.Font.Style := [];
    lblOutputFolder.Font.Color := clGreen;
    FConversionSettings.UseDestinationFolder := True;
  end;
end;

procedure TMainForm.ProcessComplete(var AMsg: TMessage);
begin
  if AMsg.WParam = 0 then
    ShowMessage('Conversion is complete.')
  else if AMsg.WParam = 1 then
    // Aborted - do nothing.
  else
    ShowMessage('Conversion failed.');

  btnSelectFolder.Enabled := True;
  btnStart.Enabled := True;
  cbSetFileDate.Enabled := True;
  dtpFileDate.Enabled := True;
end;

procedure TMainForm.ProgressUpdate(var AMsg: TMessage);
begin
  pbProgress.Position := AMsg.WParam;
  pbProgress.Max := AMsg.LParam;
  lblProgress.Caption := Format('Progress: %d/%d', [AMsg.WParam, AMsg.LParam]);
end;

function TMainForm.FolderCheck: Boolean;
begin
  if FConversionSettings.UseDestinationFolder then
  begin
    var LFilePath := IncludeFolderPathDelimiter(ExtractFilePath(FConversionSettings.Files[0]));
    var LDestPath := IncludeFolderPathDelimiter(FConversionSettings.DestinationPath);
    Result := LFilePath <> LDestPath;
  end
  else
    Result := True;
end;

procedure TMainForm.WMDropFiles(var AMsg: TWMDropFiles);
var
  LFileName: array[0..MAX_PATH] of Char;
begin
  inherited;
  try
    try
      var LCount := DragQueryFile(AMsg.Drop, $FFFFFFFF, nil, 0);

      var LFolderMode := False;

      var LList := TStringList.Create;
      try

        for var i := 0 to LCount - 1 do
        begin
          if DragQueryFile(AMsg.Drop, i, LFileName, MAX_PATH) > 0 then
          begin
            var LPath: string := LFileName;
            if AllowedFileTypes(ExtractFileExt(LPath)) then
              LList.Add(LPath)
            else if (LCount = 1) and TDirectory.Exists(LPath) then
            begin
              FConversionSettings.SelectedFolderPath := LPath;
              LFolderMode := True;
            end;
          end
          else
            raise Exception.Create('It was not possible to drop the file here.');
        end;

        if LFolderMode then
          EnableFolder
        else if LList.Count > 0 then
        begin
          FConversionSettings.Files := LList.ToStringArray;
          EnableFiles;
        end;

      finally
        LList.Free;
      end;

    finally
      DragFinish(AMsg.Drop);
    end;

    AMsg.Result := 0;
  except
    MessageBeep(MB_ICONERROR);
    AMsg.Result := 0;
  end;
end;

function TMainForm.CleanTimeFromSeconds(ADate: TDateTime): TDateTime;
begin
  Result := RecodeDateTime(ADate, YearOf(ADate), MonthOf(ADate), DayOf(ADate),
    HourOf(ADate), MinuteOf(ADate), 0, 0);
end;

{ TWorkThread }

constructor TWorkThread.Create(AHandle: THandle;
  AConversionSettings: TConversionSettings);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FHandle := AHandle;
  FConversionSettings := AConversionSettings;
end;

procedure TWorkThread.Execute;
begin
  try
    RemoveMetaData;
    if FAbort then
      SendMessage(FHandle, WM_COMPLETE, 1, 0)
    else
      SendMessage(FHandle, WM_COMPLETE, 0, 0);
  except
    SendMessage(FHandle, WM_COMPLETE, 2, 0);
  end;
end;

procedure TWorkThread.RemoveMetaData;
begin
  SendMessage(FHandle, WM_PROGRESS, 0, Length(FConversionSettings.Files));

  ForceDirectories(FConversionSettings.DestinationPath);

  var LNewFileName: string;
  for var i := 0 to Length(FConversionSettings.Files) - 1 do
  begin
    if FAbort then
      Break;

    RemoveMetaDataFromFile(FConversionSettings.Files[i], LNewFileName);
    if FConversionSettings.FileDate > 0 then
      SetFileDateToFile(LNewFileName);

    if not FConversionSettings.UseDestinationFolder then
    begin
      TFile.Delete(FConversionSettings.Files[i]);
      TFile.Move(LNewFileName, FConversionSettings.Files[i]);
    end;

    SendMessage(FHandle, WM_PROGRESS, i + 1, Length(FConversionSettings.Files));
  end;

  if not FConversionSettings.UseDestinationFolder then
    TDirectory.Delete(FConversionSettings.DestinationPath);
end;

procedure TWorkThread.RemoveMetaDataFromFile(const AFileName: string; out ANewFileName: string);
const
  EXECUTABLE = 'ffmpeg.exe';
  ARGS = '-i "%s" -map_metadata -1 -c:v copy -c:a copy -fflags +bitexact ' +
    '-flags:v +bitexact -flags:a +bitexact "%s"';
begin
  ANewFileName := TPath.Combine(FConversionSettings.DestinationPath, TPath.GetFileName(AFileName));
  var LArgs := Format(ARGS, [AFileName, ANewFileName]);
  var LResponse: string;
  if FileExists(ANewFileName) then
    DeleteFile(ANewFileName);
  StartProcess(EXECUTABLE, LArgs, LResponse);
end;

procedure TWorkThread.SetFileDateToFile(const AFileName: string);
begin
  TFile.SetCreationTime(AFileName, FConversionSettings.FileDate);
  TFile.SetLastWriteTime(AFileName, FConversionSettings.FileDate);
  TFile.SetLastAccessTime(AFileName, FConversionSettings.FileDate);
end;

function TWorkThread.StartProcess(const ExeName: string;
  const CmdLineArgs: string; var Response: string): Integer;
var
  StartInfo: TStartupInfo;
  ProcInfo: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  SecurityAttributes: TSecurityAttributes;
  ResultOK, Handle: Boolean;
  Buffer: array[0..255] of AnsiChar;
  BytesRead: Cardinal;
begin
  Response := EmptyStr;
  //Simple wrapper for the CreateProcess command
  //returns the process id of the started process.
  SecurityAttributes.nLength := SizeOf(SecurityAttributes);
  SecurityAttributes.bInheritHandle := True;
  SecurityAttributes.lpSecurityDescriptor := nil;
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SecurityAttributes, 0);

  FillChar(StartInfo,SizeOf(TStartupInfo),#0);
  FillChar(ProcInfo,SizeOf(TProcessInformation),#0);

  StartInfo.cb := SizeOf(TStartupInfo);
  StartInfo.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
  StartInfo.hStdOutput := StdOutPipeWrite;
  StartInfo.hStdError := StdOutPipeWrite;
  StartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
  StartInfo.wShowWindow := SW_HIDE;

  Handle := CreateProcess(nil, PChar(ExeName + ' ' + CmdLineArgs), nil, nil, True,
                          0, nil, PChar('.\'), StartInfo,ProcInfo);

  CloseHandle(StdOutPipeWrite);
  Result := ProcInfo.dwProcessId;

  if Handle then
  begin
    try
      repeat
        ResultOK := ReadFile(StdOutPipeRead, Buffer, 255, BytesRead, nil);
        if BytesRead > 0 then
        begin
          Buffer[BytesRead] := #0;
          Response := Response + UnicodeString(Buffer);
        end;
      until not ResultOK or (BytesRead = 0);
      WaitForSingleObject(ProcInfo.hProcess, INFINITE);
    finally
      CloseHandle(ProcInfo.hThread);
      CloseHandle(ProcInfo.hProcess);
    end;
  end;
end;

end.
