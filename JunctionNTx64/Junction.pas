unit Junction;

interface

uses
  Windows, Messages, Classes, VCL.Graphics, SysUtils, Registry, ShellAPI, IniFiles;

type
  TJunctionData = class
  private
    FPathList : TStringList;
    FCurrents : TStringList;
    FDrawType : Integer;
  protected
    procedure PrintData();
  public
    constructor Create(); reintroduce;
    destructor Destroy(); override;
    procedure LoadData();
    procedure SaveData();
    procedure AddData(sPathfrom, sPathto : string);
    procedure RemoveData(sPathfrom, sPathto : string);
    procedure SetCurrent(sPathfrom, sPathto : string);
    procedure FilterData(sPathto : string; var Results : TStrings);
    function IsCurrent(sPathfrom, sPathto : string): boolean;

    property DrawType : Integer read FDrawType write FDrawType;
  end;

  TMenuItemData = record
    cmdid : Integer;
    index : Integer;
    cmdbase : Integer;
    caption : string;
    bitmap : string;
    image : string;
    command : string;
    cmdtype : string;
  end;
  TMenuItemDatas = array of TMenuItemData;

  TJunctionManager = class
  private
    FData : TJunctionData;
    FCMDBase : Cardinal;
    FJunction_To : string;
    FJunction_Froms : TStrings;
    FMenuData : TMenuItemDatas;
  protected
    function SysCall(sCmd : string): string;
    function Regmatch(sExpr, sCheck: string): boolean;
  public
    constructor Create(); reintroduce;
    destructor Destroy(); override;
    function DoJunction(sPathfrom, sPathto : string): boolean;
    function MakeMenu(var ifirstCMDID : Cardinal; var ifirstINDEX : Cardinal; hParentMenu : HMENU): SmallInt;
    procedure InvokeMenu(iCMDID : Cardinal);
  published
    property Junction_To : string read FJunction_To write FJunction_To;
    property Data : TJunctionData read FData;
    property MenuData : TMenuItemDatas read FMenuData;
    property CMDBase : Cardinal read FCMDBase;
  end;

implementation

uses RegExpr, Browse4Folder, myUtils, JunctionNTFS, Resource;

{ TJunctionData }

const
  REGPATH = 'software\meigy\junction\';
  CMDCHECK = '%sjunction.exe %s';
  CMDJUNCTION = '%sjunction.exe %s %s';
  MAXMENUITEMS = 20;

procedure TJunctionData.AddData(sPathfrom, sPathto: string);
var pathitem : string;
begin
  if not DirectoryExists(sPathfrom) then
    Exit;
  if not DirectoryExists(sPathto) then
    Exit;
  if sPathto[Length(sPathto)] = '\' then sPathto := Copy(sPathto, 1, Length(sPathto) - 1);
  if sPathfrom[Length(sPathfrom)] = '\' then sPathfrom := Copy(sPathfrom, 1, Length(sPathfrom) - 1);

  pathitem := Format('%s*%s', [spathfrom, spathto]);
  if FPathList.indexof(pathitem) < 0 then
    FPathList.add(pathitem);
end;

procedure TJunctionData.RemoveData(sPathfrom, sPathto: string);
var pathitem : string;
  iindex : Integer;
begin
  if sPathto[Length(sPathto)] = '\' then sPathto := Copy(sPathto, 1, Length(sPathto) - 1);
  if sPathfrom[Length(sPathfrom)] = '\' then sPathfrom := Copy(sPathfrom, 1, Length(sPathfrom) - 1);

  pathitem := Format('%s*%s', [spathfrom, spathto]);
  iindex := FPathList.indexof(pathitem);
  if (iindex >= 0) and (iindex < FPathList.Count) then
    FPathList.Delete(iindex);
end;

constructor TJunctionData.Create;
begin
  FPathList := TStringList.Create;
  FCurrents := TStringList.Create;
  FDrawType := 0;
  LoadData();
end;

destructor TJunctionData.Destroy;
begin
  SaveData();
  FPathList.Free;
  FCurrents.Free;
  inherited;
end;

procedure TJunctionData.FilterData(sPathto: string;
  var Results: TStrings);
var i, ipos : Integer;
begin
  Results.Clear;
  for i := 0 to FPathList.Count - 1 do
  begin
    ipos := Pos('*', FPathList.Strings[i]);
    if (Pos('*' + sPathto, FPathList.Strings[i]) = ipos)
    and (ipos + Length(sPathto) = Length(FPathList[i])) then
      Results.Add(Copy(FPathList.Strings[i], 1, ipos - 1));
  end;
end;

procedure TJunctionData.LoadData;
var R : TRegistry;
begin
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    R.OpenKey(REGPATH, True);
    FPathList.Text := R.ReadString('recent');
    FCurrents.Text := R.ReadString('current');
    FDrawType := R.ReadInteger('show');
    _DEBUG('FDrawType');
    _DEBUG(IntToStr(FDrawType));
    R.CloseKey;
  except
    //donothing
  end;
  R.Free;
end;

procedure TJunctionData.SaveData;
var R : TRegistry;
  i, j : integer;
begin
  For i := FPathList.Count - 1 downto 0 do
  begin
    j := pos('*', FPathList.Strings[i]);
    if not DirectoryExists(copy(FPathList[i], 1, j - 1)) then
      FPathList.Delete(i);
  end;
  //while FPathList.Count > 10 do FPathList.Delete(FPathList.Count - 1);
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    R.OpenKey(REGPATH, True);
    R.WriteString('recent', FPathList.Text);
    R.WriteString('current', FCurrents.Text);
    R.WriteInteger('show', FDrawType);
    R.CloseKey;
  finally
    R.Free;
  end;
end;

procedure TJunctionData.PrintData;
var i : Integer;
begin
  for i := 0 to FPathList.Count - 1 do
    _DEBUG(FPathList[i]);
end;

function TJunctionData.IsCurrent(sPathfrom, sPathto: string): boolean;
begin
  Result := FCurrents.Values[sPathto] = sPathfrom;
end;

procedure TJunctionData.SetCurrent(sPathfrom, sPathto: string);
begin
  FCurrents.Values[sPathto] := sPathfrom;
end;

{ TJunctionManager }

constructor TJunctionManager.Create;
begin
  FCMDBase := 0;
  FData := TJunctionData.Create;
  FJunction_Froms := TStringList.Create;
  FJunction_To := '';
  OutputDebugString('junction menun initialized');
end;

destructor TJunctionManager.Destroy;
begin
  FData.SaveData;
  FData.Free;
  FJunction_Froms.Free;
  inherited;
end;

function TJunctionManager.DoJunction(sPathfrom, sPathto: string): boolean;
var sear : TSearchRec;
  iresult : Integer;
  isempty : boolean;
  isjunc : boolean;
  isok : boolean;
  scmdresult : string;
begin
  _DEBUG(sPathfrom + ',' + sPathto);
  Result := False;

  isempty := false;
  isjunc := false;
  isok := false;

  if not DirectoryExists(sPathfrom) then
    raise Exception.Create('source directory don''t exist');
  if sPathto[Length(sPathto)] = '\' then sPathto := Copy(sPathto, 1, Length(sPathto) - 1);
  if sPathfrom[Length(sPathfrom)] = '\' then sPathfrom := Copy(sPathfrom, 1, Length(sPathfrom) - 1);

  if DirectoryExists(sPathto) then
  begin
    isempty := true;
    iresult := FindFirst(sPathto + '\*.*',faAnyFile or faDirectory, sear);
    while iresult = 0 do
    begin
      if (sear.Name <> '.') and (sear.Name <> '..') then
      begin
        isempty := False;
        Break;
      end;
      iresult := FindNext(sear);
    end;
    FindClose(sear);

    {
    scmdresult := Trim(SysCall(Format(CMDCHECK, [ExtractFilePath(GetModuleName(HInstance)), sPathto])));
    isjunc := Regmatch(StringReplace('.*Substitute[ ]*Name:[ ]*.*', '\', '\\', [rfreplaceall]), scmdresult);
    if Regmatch(StringReplace(Format('.*Substitute[ ]*Name:[ ]*%s[^\a-z0-9A-Z]*', [sPathfrom]), '\', '\\', [rfreplaceall]), scmdresult) then
      raise Exception.Create(scmdresult);
    }
  end;

  isjunc := Junction_Exists(sPathto);
  //if Junction_geterror() <> '' then
  //  raise Exception.Create(Junction_geterror());
  if Junction_Exists(sPathto, sPathfrom) then
    raise Exception.Create(Format('already linked %s to %s', [sPathfrom, sPathto]));

  {
  if DirectoryExists(sPathto) and (isjunc or isempty) then
    RemoveDir(sPathto)
  else if DirectoryExists(sPathto) then
    raise Exception.Create(Format('directory %s exist and is real directory', [sPathto]));
  }

  if DirectoryExists(sPathto) and (not isjunc) and (not isempty) then
    raise Exception.Create(Format('directory %s exist and is real directory', [sPathto]));
  {
  scmdresult := SysCall(Format(CMDJUNCTION, [ExtractFilePath(GetModuleName(HInstance)), sPathto, sPathfrom]));
  if not Regmatch(StringReplace(Format('.*Targetted[ ]*at:[ ]*%s', [sPathfrom]), '\', '\\', [rfreplaceall]), scmdresult) then
    raise Exception.Create(scmdresult);
  scmdresult := SysCall(Format(CMDCHECK, [ExtractFilePath(GetModuleName(HInstance)), sPathto]));

  Sleep(10);
  isok := Regmatch(StringReplace(Format('.*Substitute[ ]*Name:[ ]*%s[^\\a-z0-9A-Z]*', [sPathfrom]), '\', '\\', [rfreplaceall]), scmdresult);
  if not isok then
    raise Exception.Create(scmdresult);
  }

  isok := Junction_Create(sPathto, sPathfrom) = 0;
  if Junction_geterror() <> '' then
    raise Exception.Create(Junction_geterror());

  Result := isok;
end;

procedure TJunctionManager.InvokeMenu(iCMDID: Cardinal);
  function isMenuExist(imenuIdx : Integer): boolean;
  var i : Integer;
  begin
    Result := False;
    for i := 0 to Length(FMenuData) - 1 do
    begin
      if FMenuData[i].cmdid - FMenuData[i].cmdbase = imenuIdx then
      begin
        Result := True;
        break;
      end;
    end;
  end;
var iMenuID : Integer;
  sPathFrom : string;
begin
  _DEBUG('InvokeMenu begin');
  _DEBUG(IntToStr(iCMDID));

  if not isMenuExist(iCMDID) then  Exit;
  iMenuID := iCMDID;

  if FMenuData[iMenuID].cmdtype = 'SYS_SELECT' then
  begin
    with TBrowse4Folder.Create(nil) do
    try
      Title := Format(TITLE_JUNCTIONFROM + ' --> ''%s''', [FJunction_To]);
      InitialDir := FJunction_To;
      if Execute then
      begin
        sPathFrom := FileName;
        _DEBUG('junction to ' + sPathFrom);
        try
          if DoJunction(sPathFrom, FJunction_To) then
          begin
            FData.AddData(sPathFrom, FJunction_To);
            FData.SetCurrent(sPathFrom, FJunction_To);
            ShellExecute(0, 'open', PChar(FJunction_To), nil, nil, SW_SHOWNORMAL);
          end;
        except on e : Exception do
          MessageBox(0, PChar(e.Message), 'exception', MB_OK or MB_ICONERROR);
        end
      end;
    finally
      Free;
    end;
    Exit;
  end
  else if FMenuData[iMenuID].cmdtype <> ''  then
  //iMenuID := iCMDID - MENUOFFSET - FCMDBase - 1;
  //if (iMenuID >= 0) and (iMenuID < FJunction_Froms.Count) then
  try
    if DoJunction(FMenuData[iMenuID].command, FJunction_To) then
    begin
      FData.SetCurrent(FMenuData[iMenuID].command, FJunction_To);
      ShellExecute(0, 'open', PChar(FJunction_To), nil, nil, SW_SHOWNORMAL);
    End;
  except on e : Exception do
    MessageBox(0, PChar(e.Message), 'exception', MB_OK or MB_ICONERROR);
  end;

  _DEBUG('InvokeMenu end');
end;

function TJunctionManager.MakeMenu(var ifirstCMDID, ifirstINDEX: Cardinal;
  hParentMenu: HMENU): SmallInt;
var   hContextMenu : HMENU;
  LastCMDID : Cardinal;
  LastINDEX : Cardinal;
  adir : array[0..MAX_PATH - 1] of char;
  sdir : string;
  mii : MENUITEMINFO;
  mhandles : TList;
  i : integer;
  MenuStyleEx : Cardinal;
  nCommand, nPosition : Cardinal;
  procedure _AddMenuBegin(var CMDID, CMDIDX : Cardinal; var outCMDID, outCMDIDX: Cardinal);
  begin
    outCMDID := CMDID;
    outCMDIDX := CMDIDX;
    inc(CMDID);
    inc(CMDIDX);
  end;
  procedure _AddMenuEnd(CMDID, CMDIDX : Cardinal; caption, bitmap, image, command, cmdtype: string);
  begin
    SetLength(FMenuData, Length(FMenuData) + 1);
    FMenuData[High(FMenuData)].cmdid := CMDID;
    FMenuData[High(FMenuData)].index := CMDIDX;
    FMenuData[High(FMenuData)].caption := caption;
    FMenuData[High(FMenuData)].bitmap := bitmap;
    FMenuData[High(FMenuData)].image := image;
    FMenuData[High(FMenuData)].command := command;
    FMenuData[High(FMenuData)].cmdbase := FCMDBase;
    FMenuData[High(FMenuData)].cmdtype := cmdtype;
  end;
begin
  Data.PrintData;

  Result := 0;
  FCMDBase := ifirstCMDID;
  LastCMDID := ifirstCMDID;
  LastINDEX := ifirstINDEX;
  MenuStyleEx := 0;
  if  FData.FDrawType <> 0 then MenuStyleEx := MFT_OWNERDRAW;
  SetLength(FMenuData, 0);
  //first Separator
  ZeroMemory(@mii, Sizeof(MENUITEMINFO));
  GetMenuItemInfo(hParentMenu, ifirstINDEX - 1, True, mii);
  if (mii.fType and MFT_SEPARATOR) = 0 then
  begin
    _AddMenuBegin(ifirstCMDID, ifirstINDEX, nCommand, nPosition);
    InsertMenu(hParentMenu, nPosition, MF_BYPOSITION or MF_SEPARATOR, nCommand, '-');
    _AddMenuEnd(nCommand, nPosition, '-', '', '', '', '');
    //Result := HResult(Result + 1);
  end;

  //if hParentMenu = 0 then
  //  hParentMenu := CreatePopupMenu();
  mhandles := TList.Create;
  try
    _AddMenuBegin(ifirstCMDID, ifirstINDEX, nCommand, nPosition);
    hContextMenu := CreatePopupMenu();
    mii.cbSize := sizeof(MENUITEMINFO);
    mii.fMask := MIIM_SUBMENU or MIIM_TYPE or MIIM_ID;
    mii.wID := nCommand; //Cardinal(pDataIndex.VCommand);
    mii.fType := MF_BYCOMMAND or MenuStyleEx; //MFT_OWNERDRAW or MF_BYCOMMAND  MFT_STRING;
    mii.hSubMenu := hContextMenu;
    mii.dwTypeData := PChar(MAIN_MENU_NAME);
    mii.cch := Length(MAIN_MENU_NAME) * sizeof(Char);
    if InsertMenuItem(hParentMenu, nPosition, True, mii) = FALSE then Exit;
    _AddMenuEnd(nCommand, nPosition, MAIN_MENU_NAME, '', '', 'junction shell', '');
    //DrawMenuBar(Handle);
    //lmilist.Add(Pointer(Result));

    _DEBUG('begin filter');
    _DEBUG(FJunction_To);
    _DEBUG('end filter');

    FData.FilterData(FJunction_To, FJunction_Froms);

    //submenu
    _AddMenuBegin(ifirstCMDID, ifirstINDEX, nCommand, nPosition);
    InsertMenu(hContextMenu, nPosition ,MF_BYPOSITION or MenuStyleEx, nCommand, MENU_SELECTTARGET);
    _AddMenuEnd(nCommand, nPosition, MENU_SELECTTARGET, '', '', 'select...', 'SYS_SELECT');

    if FJunction_Froms.Count > 0 then
    begin
      _AddMenuBegin(ifirstCMDID, ifirstINDEX, nCommand, nPosition);
      InsertMenu(hContextMenu, nPosition, MF_BYPOSITION or MF_SEPARATOR, nCommand, '-');
      _AddMenuEnd(nCommand, nPosition, '-', '', '', '', '');
    end;
    for i := 0 to FJunction_Froms.Count - 1 do
    begin
      if i >= MAXMENUITEMS then break;
      _AddMenuBegin(ifirstCMDID, ifirstINDEX, nCommand, nPosition);
      if FData.IsCurrent(FJunction_Froms[i], FJunction_To) and (FData.DrawType = 0) then
        InsertMenu(hContextMenu, nPosition ,MF_BYPOSITION or MF_CHECKED, nCommand, PChar(FJunction_Froms[i]))
      else
        InsertMenu(hContextMenu, nPosition ,MF_BYPOSITION or MF_UNCHECKED or MenuStyleEx, nCommand, PChar(FJunction_Froms[i]));
      _AddMenuEnd(nCommand, nPosition, FJunction_Froms[i], '', '', FJunction_Froms[i], FJunction_Froms[i]);
    end;
  finally
    for i := 0 to mhandles.Count - 1 do
      DestroyMenu(HMENU(mhandles[i]));
    DestroyMenu(hContextMenu);
    mhandles.Free;
  end;

  //last Separator
  _AddMenuBegin(ifirstCMDID, ifirstINDEX, nCommand, nPosition);
  InsertMenu(hParentMenu, nPosition, MF_BYPOSITION or MF_SEPARATOR, nCommand, '-');
  _AddMenuEnd(nCommand, nPosition, '-', '', '', '', '');

  Result := ifirstCMDID - LastCMDID;
end;

function TJunctionManager.Regmatch(sExpr, sCheck: string): boolean;
var regex : TRegExpr;
begin
  regex := TRegExpr.Create;
  try
    regex.Expression := sExpr;
    Result := regex.Exec(sCheck);
  finally
    regex.Free;
  end;
end;

function TJunctionManager.SysCall(sCmd: string): string;
var si: STARTUPINFO;
  hReadPipe, hWritePipe: THandle;
  lsa: SECURITY_ATTRIBUTES;
  pi: PROCESS_INFORMATION;
  cchReadBuffer: DWORD; 
  buffer: array[0..255] of char;
begin
  Result := '';
  lsa.nLength := sizeof(SECURITY_ATTRIBUTES);
  lsa.lpSecurityDescriptor := nil;
  lsa.bInheritHandle := True; 
  if CreatePipe(hReadPipe, hWritePipe, @lsa, 0) = False then
    raise Exception.Create('create pipe failed');
  FillChar(si, sizeof(STARTUPINFO), 0);
  si.cb := sizeof(STARTUPINFO); 
  si.dwFlags := (STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW); 
  si.wShowWindow := SW_HIDE; 
  si.hStdOutput := hWritePipe;
  si.hStdError := hWritePipe;

  if CreateProcess(nil, PChar(sCmd), nil, nil, true, 0, nil, nil, si, pi) = False then
    raise Exception.Create(Format('create process %s failed', [sCmd]));
  CloseHandle(hWritePipe);
  while (true) do
  begin
    if not PeekNamedPipe(hReadPipe, @buffer, 1, @cchReadBuffer, nil, nil) then
      break;
    if cchReadBuffer <> 0 then
    begin
      FillChar(buffer, Length(buffer), 0);
      if ReadFile(hReadPipe, buffer, Length(buffer), cchReadBuffer, nil) = False then
        break;
      Result := Result + buffer;
    end
    else if (WaitForSingleObject(pi.hProcess, 0) = WAIT_OBJECT_0) then
      break;
    //Application.ProcessMessages;
    Sleep(10);
  end;
  CloseHandle(hReadPipe); 
  CloseHandle(pi.hThread); 
  CloseHandle(pi.hProcess);
end;

end.
