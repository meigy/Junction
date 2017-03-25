program testNT;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  JunctionNTFS in 'JunctionNTFS.pas';

var nError : Integer;
begin
  nError := 0;
  { TODO -oUser -cConsole Main : Insert code here }
  if not Junction_Exists('H:\1') then
    nError := Junction_Create('H:\1', 'H:\temp');
  if nError <> 0 then
    Writeln(Junction_geterror());
  if Junction_Exists('H:\1', 'H:\temp') then
    nError := Junction_Delete('H:\1');
  if nError <> 0 then
    Writeln(Junction_geterror());
end.
