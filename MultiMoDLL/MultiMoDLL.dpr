library MultiMoDLL;

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
  winapi.windows,
  system.sysutils,
  uShareLib in '..\lib\uShareLib.pas',
  uAPILogClient in '..\lib\uAPILogClient.pas',
  uLoggerLib in '..\lib\uLoggerLib.pas',
  uMouseHookLib in '..\lib\uMouseHookLib.pas',
  uAPILib in '..\lib\uAPILib.pas';

{$R *.res}

exports
  StartMouseHook
  , EndMouseHook
  , StartCBTHook
  , EndCBTHook
//  , LowLevelMouseProc
  ;

var
  oldDllProc:TDLLProc = nil;

procedure MMDllProc(Reason: Integer);
begin
  case Reason of
    DLL_PROCESS_ATTACH:
      Log('DLL_PROCESS_ATTACH');
    DLL_THREAD_ATTACH:
      Log('DLL_THREAD_ATTACH');
    DLL_PROCESS_DETACH:
      Log('DLL_PROCESS_DETACH');
    DLL_THREAD_DETACH:
      Log('DLL_THREAD_DETACH');
  end;

  if assigned(oldDllProc) then
    oldDllProc(Reason)
end;

begin
//  InitShareLog('DLLProc');
//  if not Assigned(OldDllProc) then
//  begin
//    OldDllProc := DLLProc;
//    DLLProc := MMDLLProc;
//    MMDllProc(DLL_PROCESS_ATTACH);
//  end;
end.
