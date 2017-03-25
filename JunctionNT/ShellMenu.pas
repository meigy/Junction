unit ShellMenu;

interface

uses
  Windows, Messages, Classes, Graphics, Math, ActiveX, ComObj, ShlObj, Dialogs,
  SysUtils, Registry, ShellApi, ComServ, EncdDecd, Junction;

type
  TExtendMenu = class(TComObject, IShellExtInit, IContextMenu, IContextMenu3)
  private
    FManager: TJunctionManager;
    procedure DrawMenuGraph(hItem: HWND; ItemID: Cardinal; adc: HDC; r: TRect; State: Integer; Graphic: TBitmap); stdcall;
    procedure DrawMenuText(hItem: HWND; ItemID: Cardinal; adc: HDC; r: TRect; State: Integer); stdcall;
  protected
    //IShellExtInit
    function IShellExtInit.Initialize = SEIInitialize;
    function SEIInitialize(pidlFolder: PItemIDList; lpdobj: IDataObject;
      hKeyProgID: HKEY): HResult; stdcall;
    //IContextMenu
    function QueryContextMenu(Menu: HMENU; indexMenu, idCmdFirst, idCmdLast,
      uFlags: UINT): HResult; stdcall;
    function InvokeCommand(var lpici: TCMInvokeCommandInfo): HResult; stdcall;
    function GetCommandString(idCmd, uType: UINT; pwReserved: PUINT;
      pszName: LPSTR; cchMax: UINT): HResult; stdcall;
    { IContextMenu2 接口 }
    function HandleMenuMsg(uMsg: UINT; WParam, LParam: Integer): HResult; stdcall;
    { IContextMenu3 接口 }
    function HandleMenuMsg2(uMsg: UINT; wParam, lParam: Integer;
      var lpResult: Integer): HResult; stdcall;
    //extended
    function GetCaptionByCMDID(nCmd: UINT): string;
    function GetImgDataByCMDID(nCmd: UINT): string;
    function GetBmpDataByCMDID(nCmd: UINT): string;
    function GetCommandByCMDID(nCmd: UINT): string;
    function GetCustomContextMenu(var parentMenu: HMENU; var indexMenu, idCmdFirst: UINT): SmallInt;
  public
    procedure Initialize(); override;
    destructor Destroy(); override;
  end;

type
  TExtendMenuFactory = class(TComObjectFactory)
  public
    procedure UpdateRegistry(Register: Boolean); override;
  end;

const
  GUID_EXTENDMENUCLASS: TGUID = '{E7C290CC-03A2-454D-9609-2A0E04F7F33E}';

var
  //hJunctionMenu: HMENU = 0;
  FirstCMDID: Cardinal = 0;

implementation

uses myUtils;

{ TExtendMenu }

procedure TExtendMenu.Initialize;
begin
  inherited;
  _DEBUG('junction menun created');
  FManager := TJunctionManager.Create;
end;

destructor TExtendMenu.Destroy;
begin
  FManager.Free;
  inherited;
  _DEBUG('junction menun destroy');
end;

procedure TExtendMenu.DrawMenuGraph(hItem: HWND; ItemID: Cardinal; adc: HDC; r: TRect; State: Integer;
  Graphic: TBitmap);stdcall;
var
  rImage, rText : TRect;
  Canvas : TCanvas;
  nTextHeight, nFrameSize, nSaveDC : integer;
  bSelected : BOOL;
begin
  _DEBUG('DrawMenuGraph begin');

  bSelected := longbool(State and ODS_SELECTED);
  nTextHeight := 16;
  nFrameSize := 1;
  rImage := Rect(r.Left + nFrameSize, r.Top + nFrameSize, r.Right - nFrameSize, r.Bottom - nFrameSize);
  rText := Rect(rImage.Left, ((rImage.Bottom + rImage.Top - nTextHeight) div 2),
               rImage.Right, ((rImage.Bottom + rImage.Top + nTextHeight) div 2));

  Canvas := TCanvas.Create;
  try
    nSaveDC := SaveDC(adc);
    Canvas.Handle := adc;
    with Canvas do
    begin 
      if Assigned(Graphic) then
      begin
        DrawRectangle(canvas, r, bSelected);
        DrawBitmap(canvas, rImage, Graphic);
      end;
      DrawString(canvas, rText, GetCaptionByCMDID(ItemID - FManager.CMDBase), bSelected, DT_CENTER, clrText, clrBackGround);
    end;
  finally
    Canvas.Handle := 0;
    Canvas.Free;
    RestoreDC(adc, nSaveDC);
  end;

  _DEBUG('DrawMenuGraph end');
end;

procedure TExtendMenu.DrawMenuText(hItem: HWND; ItemID: Cardinal; adc: HDC;
  r: TRect; State: Integer);stdcall;
var
  rImage, rText, rLeft : TRect;
  Canvas : TCanvas;
  nSaveDC : integer;
  sImage: String;
  sCaption: String;
  strStream: TStringStream;
  iconStream: TMemoryStream;
  ico: TICON;
  bSelected:BOOL;
begin
  _DEBUG('DrawMenuText begin');

	bSelected := longbool(State and ODS_SELECTED);
  rImage := Rect(r.Left + HALFICONSIZE div 2,
                (r.Top + r.Bottom) div 2 - HALFICONSIZE,
                r.Left + ICONSIZE + HALFICONSIZE div 2,
                (r.Top + r.Bottom) div 2 + HALFICONSIZE);
  rText := Rect(rImage.Right + HALFICONSIZE + 1, r.Top, r.Right, r.Bottom);
  rLeft := Rect(r.Left, r.Top, rImage.Right + HALFICONSIZE div 2,r.Bottom);

  Canvas := TCanvas.Create;
  try
    nSaveDC := SaveDC(adc);
    Canvas.Handle := adc;
    with Canvas do
    begin
      DrawBackGroud(canvas, r, rleft, bSelected, False);
      sCaption := GetCaptionByCMDID(ItemID - FManager.CMDBase);
      _DEBUG('caption ItemID');
      _DEBUG(IntToStr(ItemID));
      sImage := GetImgDataByCMDID(ItemID - FManager.CMDBase);
      //drawicon
      if sImage <> '' then
      begin
        ico := TICon.Create;
        strStream := TStringStream.Create(sImage);
        iconStream := TMemoryStream.Create();
        try
          DecodeStream(strStream, iconStream);
          iconStream.Position := 0;
          ico.LoadFromStream(iconStream);
          DrawMenuIcon(Handle, rImage, ico.Handle, bSelected);
        finally
          StrStream.Free;
          IconStream.Free;
          Ico.Free;
        end;
      end;
      //drawtext
      if sCaption <> '-' then
        DrawString(canvas, rText, sCaption, bSelected, DT_LEFT, clBlack, clBlack)
      else
        DrawSeperator(canvas, rText);
    end;
  finally
    Canvas.Handle := 0;
    Canvas.Free;
    RestoreDC(adc, nSaveDC);
  end;

  _DEBUG('DrawMenuText end');
end;

function TExtendMenu.GetBmpDataByCMDID(nCmd: UINT): string;
var i : Integer;
begin
  _DEBUG('GetBmpDataByCMDID begin');
  for i := 0 to Length(FManager.MenuData) - 1 do
  begin
    if FManager.MenuData[i].cmdid - FManager.MenuData[i].cmdbase = nCmd then
    begin
      Result := FManager.MenuData[i].bitmap;
      break;
    end;
  end;
  _DEBUG('GetBmpDataByCMDID end');
end;

function TExtendMenu.GetCaptionByCMDID(nCmd: UINT): string;
var i : Integer;
begin
  _DEBUG('GetCaptionByCMDID begin');
  for i := 0 to Length(FManager.MenuData) - 1 do
  begin
    if FManager.MenuData[i].cmdid - FManager.MenuData[i].cmdbase = nCmd then
    begin
      Result := FManager.MenuData[i].caption;
      break;
    end;
  end;
  _DEBUG(Result);
  _DEBUG('GetCaptionByCMDID end');
end;

function TExtendMenu.GetCommandByCMDID(nCmd: UINT): string;
var i : Integer;
begin
  _DEBUG('GetCommandByCMDID begin');
  for i := 0 to Length(FManager.MenuData) - 1 do
  begin
    if FManager.MenuData[i].cmdid - FManager.MenuData[i].cmdbase = nCmd then
    begin
      Result := FManager.MenuData[i].command;
      break;
    end;
  end;
  _DEBUG(IntToStr(nCmd));
  _DEBUG(Result);
  _DEBUG('GetCommandByCMDID end');
end;

function TExtendMenu.GetImgDataByCMDID(nCmd: UINT): string;
var i : Integer;
begin
  for i := 0 to Length(FManager.MenuData) - 1 do
  begin
    if FManager.MenuData[i].cmdid - FManager.MenuData[i].cmdbase = nCmd then
    begin
      Result := FManager.MenuData[i].image;
      break;
    end;
  end;
end;

function TExtendMenu.GetCommandString(idCmd, uType: UINT; pwReserved: PUINT;
  pszName: LPSTR; cchMax: UINT): HResult;
begin
  _DEBUG('GetCommandString begin');

  if (uType = GCS_HELPTEXT) then
  begin
     StrCopy(pszName, PChar(GetCaptionByCMDID(idCmd)));
     //StrCopy(pszName, PChar(GetCaptionByCMDID(idCmd-1)));
     //_DEBUG('GetCommandString print');
     //_DEBUG(pszName);
     Result := NOERROR;
  end
  else
  begin
     Result := E_INVALIDARG;
  end;

  _DEBUG('GetCommandString end');
end;

function TExtendMenu.GetCustomContextMenu(var parentMenu: HMENU;
  var indexMenu, idCmdFirst: UINT): SmallInt;
begin
  //_DEBUG('custom create menu');
  Result := FManager.MakeMenu(idCmdFirst, indexMenu, parentMenu);
  //_DEBUG('custom create menu end');
end;


function TExtendMenu.HandleMenuMsg(uMsg: UINT; WParam,
  LParam: Integer): HResult;
var Ret : Integer;
begin
  //_DEBUG('HandleMenuMsg begin');

  Ret := 0;
  Result := HandleMenuMsg2(uMsg, wParam, lParam, Ret);

  //_DEBUG('HandleMenuMsg end');
end;

function TExtendMenu.HandleMenuMsg2(uMsg: UINT; wParam, lParam: Integer;
  var lpResult: Integer): HResult;
var
  pmis : PMeasureItemStruct;
  pdis : PDrawItemStruct;
  sBmp, sCaption, scommand: string;
  BMP : TBitMap;
begin
  _DEBUG('HandleMenuMsg2 begin');

  Result := S_OK;
  sBmp := '';
  case uMsg of
     WM_MEASUREITEM:
     begin
        pmis := PMeasureItemStruct(lParam);
        if pmis.CtlType <> ODT_MENU then Exit;
        _DEBUG('HandleMenuMsg2 WM_MEASUREITEM begin');
        //_DEBUG(PChar('HandleMenuMsg2 WM_MEASUREITEM begin'+inttostr(pmis.itemid-FirstCMDID-1)));
        sBmp := GetBmpDataByCMDID(pmis.itemid - FManager.CMDBase);
        //_DEBUG(PChar('HandleMenuMsg2 WM_MEASUREITEM end'+inttostr(pmis.itemid-FirstCMDID-1)));
        if sBmp <> '' then
        begin
          _DEBUG('HandleMenuMsg2 WM_MEASUREITEM 11 begin');
          BMP := TBitmap.Create();
          try
            BMP.Handle := StringtoHBMP(sBmp);
            begin
               pmis.itemWidth := BMP.Width;
               pmis.itemHeight := BMP.Height;
            end;
          finally
            Free;
          end;
        end;

        _DEBUG('HandleMenuMsg2 WM_MEASUREITEM 22 begin');
        sCaption := GetCaptionByCMDID(pmis.itemid - FManager.CMDBase);
        if sCaption = '-' then
        begin
          sCommand := Trim(GetCommandByCMDID(pmis.itemid - FManager.CMDBase));
          if scommand = '' then
            pmis.itemHeight := 4
          else
            pmis.itemHeight := ICONSIZE - 2;
          pmis.itemWidth := GetTextWidth(GetDC(0), scommand) + ICONSIZE+HALFICONSIZE * 2;
        end
        else
        begin
          pmis.itemHeight := ICONSIZE + 4;
          pmis.itemWidth := GetTextWidth(GetDC(0), sCaption) + ICONSIZE+HALFICONSIZE * 2;
        end;
        _DEBUG('HandleMenuMsg2 WM_MEASUREITEM 22 end');
     end;

     WM_DRAWITEM:
     begin
        pdis := PDrawItemStruct(lParam);
        if pdis.CtlType <> ODT_MENU then Exit;
        _DEBUG('HandleMenuMsg2 WM_DRAWITEM begin');
        sBmp := GetBmpDataByCMDID(pdis.itemid - FManager.CMDBase);
        if sBmp <> '' then
        begin
          BMP := TBitmap.Create();
          try
            BMP.Handle := StringtoHBMP(sBmp);
            DrawMenuGraph(pdis.hwndItem, pdis.itemID, pdis.hDC, pdis.rcItem, pdis.itemState, BMP);
          finally
            BMP.Free;
          end;
        end
        else
        begin
          DrawMenuText(pdis.hwndItem, pdis.itemID, pdis.hDC, pdis.rcItem, pdis.itemState);
        end;
     end;
  end;

  _DEBUG('HandleMenuMsg2 end');
end;

function TExtendMenu.InvokeCommand(var lpici: TCMInvokeCommandInfo): HResult;
var sCMD,sDir:string;
  sCommand,sParam:string;
begin
  _DEBUG('InvokeCommand begin');

  Result := E_FAIL;
  sCMD := '';
  if (HiWord(Integer(lpici.lpVerb)) <> 0) then Exit;
  try
    //FManager.Junction_To := StrPas(lpici.lpDirectory);
    _DEBUG(FManager.Junction_To);
    begin
      sCMD := GetCommandByCMDID(LoWord(lpici.lpVerb));
      _DEBUG(sCMD);
      if sCMD = '' then  Exit;
      if LongBool(GetAsyncKeyState(VK_SHIFT) shr ((sizeof(SHORT) *8 ) - 1)) then
      begin
        FManager.Data.RemoveData(GetCommandByCMDID(LoWord(lpici.lpVerb)), FManager.Junction_To);
      end 
      else if LongBool(GetAsyncKeyState(VK_CONTROL) shr ((sizeof(SHORT) *8 ) - 1)) then
      begin
        FManager.Data.DrawType := Integer(not BOOL(FManager.Data.DrawType));
      end else
      begin
        FManager.InvokeMenu(LoWord(lpici.lpVerb));
      end;
    end;
    Result := NOERROR;
  finally
    //ClearMemory(pStrsmem);
    //ClearMemory(pIdxMem);
  end;

  _DEBUG('InvokeCommand end');
end;

function TExtendMenu.QueryContextMenu(Menu: HMENU; indexMenu, idCmdFirst,
  idCmdLast, uFlags: UINT): HResult;
  function Make_HResult(sev, fac, code: Word): DWord;
  begin
    Result := (sev shl 31) or (fac shl 16) or code;
  end;
var nCount : SmallInt;
begin
  _DEBUG('QueryContextMenu begin');
  _DEBUG(PChar('QueryContextMenu ='+inttostr(idCmdFirst)));

  Result := Make_HResult(SEVERITY_SUCCESS, FACILITY_NULL, 0);
  if (uFlags and CMF_DEFAULTONLY) <> 0 then  Exit;
  if FManager.Junction_To = '' then Exit;
  //if hJunctionMenu = Menu then Exit;
  nCount := GetCustomContextMenu(Menu, indexMenu, idCmdFirst);
  //2007-05-28 add
  _DEBUG(PChar('QueryContextMenu count ='+inttostr(nCount)));
  Result := Make_HResult(SEVERITY_SUCCESS, FACILITY_NULL, nCount);

  _DEBUG('QueryContextMenu end');
end;

function TExtendMenu.SEIInitialize(pidlFolder: PItemIDList; lpdobj: IDataObject;
  hKeyProgID: HKEY): HResult;
var
  StgMedium: TStgMedium;
  FormatEtc: TFormatEtc;
  FFileName: array[0..MAX_PATH] of Char;
begin
  _DEBUG('SEIInitialize begin');

  if (lpdobj = nil) then begin
    Result := E_INVALIDARG;
    Exit;
  end;

  with FormatEtc do begin
    cfFormat := CF_HDROP;
    ptd      := nil;
    dwAspect := DVASPECT_CONTENT;
    lindex   := -1;
    tymed    := TYMED_HGLOBAL;
  end;

  Result := lpdobj.GetData(FormatEtc, StgMedium);
  if Failed(Result) then
    Exit;
  
  if (DragQueryFile(StgMedium.hGlobal, $FFFFFFFF, nil, 0) = 1) then begin
    DragQueryFile(StgMedium.hGlobal, 0, FFileName, SizeOf(FFileName));
    Result := NOERROR;
  end
  else begin
    FFileName[0] := #0;
    Result := E_FAIL;
  end;
  ReleaseStgMedium(StgMedium);

  FManager.Junction_To := FFileName;
  _DEBUG(StrPas(@FFileName));
  _DEBUG('SEIInitialize end');
end;


{ TExtendMenuFactory }

procedure TExtendMenuFactory.UpdateRegistry(Register: Boolean);
var
  ClassID: string;
begin
  if Register then
  begin
    inherited UpdateRegistry(Register);

    ClassID := GUIDToString(GUID_EXTENDMENUCLASS);
    {
    CreateRegKey('exefile\shellex', '', '');
    CreateRegKey('exefile\shellex\ContextMenuHandlers', '', '');
    CreateRegKey('exefile\shellex\ContextMenuHandlers\ExtendMenu', '', ClassID);

    CreateRegKey('*\shellex', '', '');
    CreateRegKey('*\shellex\ContextMenuHandlers', '', '');
    CreateRegKey('*\shellex\ContextMenuHandlers\ExtendMenu', '', ClassID);
    }
    CreateRegKey('Directory\shellex', '', '');
    CreateRegKey('Directory\shellex\ContextMenuHandlers', '', '');
    CreateRegKey('Directory\shellex\ContextMenuHandlers\JunctionMenu', '', ClassID);
    if (Win32Platform = VER_PLATFORM_WIN32_NT) then
    with TRegistry.Create do
      try
        RootKey := HKEY_LOCAL_MACHINE;
        OpenKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions', True);
        OpenKey('Approved', True);
        WriteString(ClassID, 'junction menu');
      finally
        Free;
      end;
  end
  else begin
    {
    DeleteRegKey('exefile\shellex\ContextMenuHandlers\ExtendMenu');
    DeleteRegKey('exefile\shellex\ContextMenuHandlers');
    DeleteRegKey('exefile\shellex');

    DeleteRegKey('*\shellex\ContextMenuHandlers\ExtendMenu');
    DeleteRegKey('*\shellex\ContextMenuHandlers');
    DeleteRegKey('*\shellex');
    }
    DeleteRegKey('Directory\shellex\ContextMenuHandlers\JunctionMenu');
    DeleteRegKey('Directory\shellex\ContextMenuHandlers');
    //DeleteRegKey('Directory\shellex');
    inherited UpdateRegistry(Register);
  end;
end;

initialization
  TExtendMenuFactory.Create(ComServer, TExtendMenu, GUID_EXTENDMENUCLASS,
    '', 'junction menu', ciMultiInstance,
    tmApartment);

  _DEBUG('junction menu start');
finalization

end.

