library JunctionShell;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  SysUtils,
  Classes,
  ComServ {: CoClass},
  ShellMenu in 'ShellMenu.pas',
  myUtils in 'myUtils.pas',
  Junction in 'Junction.pas',
  RegExpr in 'RegExpr.pas',
  Browse4Folder in 'Browse4Folder.pas',
  JunctionNTFS in 'JunctionNTFS.pas',
  JunctionShell_TLB in 'JunctionShell_TLB.pas',
  Resource in 'Resource.pas';

{$R *.TLB}

{$R *.res}

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer;

begin
end.
