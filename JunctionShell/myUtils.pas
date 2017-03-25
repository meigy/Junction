unit myUtils;

interface

uses
  Windows, Messages, SysUtils, Graphics, classes, EncdDecd;

const
  ICONSIZE=16;
  HALFICONSIZE=ICONSIZE div 2;

  MENUCOLOR_LEFT=$00F6F4F5;
  MENUCOLOR_SELECTOR=$00E5CFC2;
  MENUCOLOR_SELECTOR_EDGE=$00A85E33;
  MENUCOLOR_SEPERATOR=$00AAA6A7;

var
  clrBackGround,
  clrSelectedBar,
  clrSelectedText,
  clrText,clrFrame: Cardinal;

procedure _DEBUG(s : string);
function GetTextWidth(adc:HDC;Text:string):Cardinal;
procedure DrawBackGroud(canvas: TCanvas;rc,rcimage: TRect;bSelected: BOOL;bDrawLeft:BOOL=True);
procedure DrawString(canvas: TCanvas;rc:TRect;Text:string;bSelected: BOOL;
  Align: Cardinal;clrTextcolor:TColor;clrTextSelectedcolor:TColor);
procedure DrawMenuIcon(adc: HDC;rc:TRect;icon: HICON;bSelected:Boolean);
procedure DrawBitmap(canvas: TCanvas;rc:TRect;bmp: TBitmap);
procedure DrawRectangle(canvas: TCanvas;rc: TRect;bSelected: BOOL);
procedure DrawSeperator(canvas: TCanvas;rc:TRect;Text:string='');
procedure divideCommand(s:string; var sCommand:string; var sParament:string);
function StringtoHBMP(str: string): HBITMAP;

implementation

procedure _DEBUG(s : string);
begin
  OutputDebugString(PChar(s));
end;

function GetTextWidth(adc:HDC;Text:string):Cardinal;
var Size: TSize;
begin
  Windows.GetTextExtentPoint32(adc, PChar(Text), Length(Text), Size);
  Result:=Size.cx;
end;

procedure DrawBackGroud(canvas: TCanvas;rc,rcimage: TRect;bSelected: BOOL;bDrawLeft:BOOL=True);
begin
  with Canvas do
  begin
    if bSelected then
    begin
      Brush.Color:=MENUCOLOR_SELECTOR;
      FillRect(rc);
      Pen.Color:=MENUCOLOR_SELECTOR_EDGE;
      Rectangle(rc);
    end else
    begin
      Brush.Color:=clrBackGround;
      FillRect(rc);
      if bDrawLeft then
      begin
        Brush.Color:=MENUCOLOR_LEFT;
        FillRect(rcimage);
      end;
    end;
  end;
end;

procedure DrawString(canvas: TCanvas;rc:TRect;Text:string;bSelected: BOOL;
  Align: Cardinal;clrTextcolor:TColor;clrTextSelectedcolor:TColor);
begin
  with Canvas do
  begin
    Font.Name:='Tahoma';
    Font.Size:=9;
    if bSelected then
      Font.Color:=clrTextSelectedcolor
    else
      Font.Color:=clrTextcolor;
    SetBkMode(Handle,TRANSPARENT);
    DrawText(Handle, PChar(Text), -1, rc,
             DT_SINGLELINE or Align or DT_VCENTER);
  end;
end;

procedure DrawSeperator(canvas: TCanvas;rc:TRect;Text:string='');
var iTxtWidth:Integer;
  rcleft,rctext,rcright: TRect;
begin
  with Canvas do
  begin
    Font.Name:='Lusida Console';
    Font.Size:=8;
    Font.Style:=[fsItalic];

    Font.Color:=MENUCOLOR_SEPERATOR;
    iTxtWidth:=canvas.TextWidth(Text);

    if Text<>'' then
    begin
      rcleft:=Rect(rc.Left,((rc.top+rc.Bottom) div 2),rc.Left+(rc.Right-iTxtWidth-rc.Left) div 2-4,((rc.top+rc.Bottom) div 2) +1);
      rctext:=Rect(rcleft.Right+8,rc.Top,rcleft.Right+iTxtWidth+8+8,rc.Bottom);
      rcright:=Rect(rcText.Right+8,((rc.top+rc.Bottom) div 2),rc.Right-3,((rc.top+rc.Bottom) div 2) +1);

      Brush.Color:=MENUCOLOR_SEPERATOR;
      FillRect(rcleft);
      FillRect(rcRight);
      SetBkMode(Handle,TRANSPARENT);
      DrawText(Handle, PChar(Text), -1, rcText,
             DT_SINGLELINE or DT_VCENTER);
    end else
    begin
      rcText:=Rect(rc.Left,((rc.top+rc.Bottom) div 2),rc.Right-3,((rc.top+rc.Bottom) div 2)+1);
            Brush.Color:=MENUCOLOR_SEPERATOR;
      FillRect(rcText);
    end;  
  end;
end;

procedure DrawMenuIcon(adc: HDC;rc:TRect;icon: HICON;bSelected:Boolean);
begin
  if bSelected then
    offsetRect(rc,-1,-1);
  DrawIconEx(adc, rc.Left, rc.Top, icon, rc.Right-rc.Left, rc.Bottom-rc.Top,
             0, WHITE_BRUSH , DI_MASK or DI_NORMAL);
end;

procedure DrawBitmap(canvas: TCanvas;rc:TRect; bmp: TBitmap);
begin
  Canvas.StretchDraw(rc,bmp);
end;

procedure DrawRectangle(canvas: TCanvas;rc: TRect;bSelected: BOOL);
begin
  with canvas do
  begin
    if bSelected then
      Pen.Color:=clrSelectedBar
    else
      Pen.Color:=clrBackGround;
    Rectangle(rc);
  end;
end;

procedure divideCommand(s:string;var sCommand:string; var sParament:string);
var i{,j}:Integer;
begin
  i:=0;
  while i<Length(s) do
  begin
    if s[i+1]='"' then
    begin
      inc(i);
      while (s[i+1]<>'"') and (i<Length(s)) do
        inc(i);
    end;
    if s[i+1] in ['/','-'] then
      break;
    inc(i);
  end;
  sCommand:=copy(s,1,i);
  sParament:=copy(s,i+1,length(s)-i);
  outputdebugstring(pchar(sCommand));
  outputdebugstring(pchar(sParament));
end;

function StringtoHBMP(str: string): HBITMAP;
var StrStream:TStringStream;
  bmpStream:TMemoryStream;
  bmp: TBitmap;
begin
  Result := 0;
  if length(str)=0 then Exit;
  bmp:=TBitmap.Create;
  StrStream:=TStringStream.Create(str);
  bmpStream:=TMemoryStream.Create();
  try
    DecodeStream(strStream,bmpStream);
    bmpStream.Position:=0;
    bmp.LoadFromStream(bmpStream);
    Result:=bmp.ReleaseHandle;
  finally
    StrStream.Free;
    bmpStream.Free;
    bmp.Free;
  end;
end;


initialization
	clrBackGround := GetSysColor(COLOR_MENU);
	clrSelectedBar := GetSysColor(COLOR_HIGHLIGHT);
	clrSelectedText := GetSysColor(COLOR_HIGHLIGHTTEXT);
	clrText := GetSysColor(COLOR_MENUTEXT);
  clrFrame:= clBlack;

end.

