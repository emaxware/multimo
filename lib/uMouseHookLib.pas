unit uMouseHookLib;

interface

uses
  Winapi.windows
  , System.SysUtils
  ;

type
  PLLMouseHookStruct = ^TLLMouseHookStruct;
  tagLLMOUSEHOOKSTRUCT = record
    pt: TPoint;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  TLLMouseHookStruct = tagLLMOUSEHOOKSTRUCT;
  LLMOUSEHOOKSTRUCT = tagLLMOUSEHOOKSTRUCT;

function StartLLMouseHook(OnHook:TFunc<integer,wparam,PLLMouseHookStruct,boolean>):boolean;
procedure EndLLMouseHook;

function StartMouseHook:boolean;//(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
procedure EndMouseHook;

function StartCBTHook:boolean;//(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
procedure EndCBTHook;

//procedure InitDLL(const ADesc:string);

implementation

uses
  winapi.messages
  , system.syncobjs
  , uShareLib
  , uAPILogClient
  , uAPILib
  , uLoggerLib
  ;

var
  HookHandle:HHOOK = 0;
  FOnLLMouseHook:TFunc<integer,wparam,PLLMouseHookStruct,boolean> = nil;

procedure EndLLMouseHook;
begin
  UnhookWindowsHookEx(HookHandle)
end;

function LowLevelMouseProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT stdcall;
var MouseInfo:PLLMouseHookStruct absolute lparam;
begin
  InitShareLog('LowLevelMouseProc');
  if FOnLLMouseHook(code,wparam,MouseInfo) then
    result := CallNextHookEx(HookHandle, code, wparam, lparam)
end;

function StartLLMouseHook(OnHook:TFunc<integer,wparam,PLLMouseHookStruct,boolean>):boolean;
begin
  InitShareLog('StartLLMouseHook');
  FOnLLMouseHook := OnHook;
  HookHandle := SetWindowsHookEx(WH_MOUSE_LL, @LowLevelMouseProc, 0, 0);
  result := HookHandle <> 0
end;

{$IFNDEF INDLL}

function StartMouseHook:boolean; external 'MultiMoDLL.dll'; //(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
procedure EndMouseHook; external 'MultiMoDLL.dll';

function StartCBTHook:boolean; external 'MultiMoDLL.dll';//(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
procedure EndCBTHook; external 'MultiMoDLL.dll';

{$ELSE}

var
  initLog:boolean = true;
  hookbusy:TCriticalSection = nil;
  logger:ILogger = nil;

procedure EndMouseHook;
begin
  UnhookWindowsHookEx( HookHandle)
end;

function MouseProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT stdcall;
var MouseInfo:PMouseHookStruct absolute lparam;
begin
  if hookbusy = nil then
    hookbusy := TCriticalSection.Create;
  hookbusy.Acquire;
  try
    if InitShareLog('CBTProc') then
      ;
    if logger = nil then
    begin
      logger :=
        TSimpleLogger.create(
          function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
          begin
            SLog^.log(ALogMsg);
            result := AMsg
          end
          , ProcessFileName(GetCurrentProcessID, false)
          , lpVerbose
          , lpDebug
        );
      logger.log(lpVerbose,'new logger');
    end;
    with logger do
    case wparam of
      WM_MOUSEMOVE:
        deflog('MouseProc: WM_MOUSEMOVE');
      WM_LBUTTONDOWN:
        deflog('MouseProc: WM_LBUTTONDOWN');
      WM_LBUTTONUP:
        deflog('MouseProc: WM_LBUTTONUP');
      WM_LBUTTONDBLCLK:
        deflog('MouseProc: WM_LBUTTONDBLCLK');
      WM_RBUTTONDOWN:
        deflog('MouseProc: WM_RBUTTONDOWN');
      WM_RBUTTONUP:
        deflog('MouseProc: WM_RBUTTONUP');
      WM_RBUTTONDBLCLK:
        deflog('MouseProc: WM_RBUTTONDBLCLK');
      WM_MBUTTONDOWN:
        deflog('MouseProc: WM_MBUTTONDOWN');
      WM_MBUTTONUP:
        deflog('MouseProc: WM_MBUTTONUP');
      WM_MBUTTONDBLCLK:
        deflog('MouseProc: WM_MBUTTONDBLCLK');
      WM_MOUSEWHEEL:
        deflog('MouseProc: WM_MOUSEWHEEL');
      WM_XBUTTONDOWN:
        deflog('MouseProc: WM_XBUTTONDOWN');
      WM_XBUTTONUP:
        deflog('MouseProc: WM_XBUTTONUP');
      WM_XBUTTONDBLCLK:
        deflog('MouseProc: WM_XBUTTONDBLCLK');
      else
        deflogfmt('MouseProc: %8.8X',[wparam]);
    end;
  finally
    hookbusy.release
  end;
  result := CallNextHookEx(0, code, wparam, lparam)
end;

function StartMouseHook:boolean;//(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
begin
  InitShareLog('StartMouseHook');
  HookHandle := SetWindowsHookEx(WH_MOUSE, @MouseProc, hinstance, 0);
  log('StartMouseHook: %d %X',[HookHandle,hinstance]);
  result := HookHandle <> 0
end;

procedure EndCBTHook;
begin
  UnhookWindowsHookEx(HookHandle)
end;

function CBTProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT stdcall;
begin
  if hookbusy = nil then
    hookbusy := TCriticalSection.Create;
  hookbusy.Acquire;
  try
    if InitShareLog('CBTProc') then
      ;
    if logger = nil then
    begin
      logger :=
        TSimpleLogger.create(
          function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
          begin
            SLog^.log(ALogMsg);
            result := AMsg
          end
          , ProcessFileName(GetCurrentProcessID, false)
          , lpVerbose
          , lpDebug
        );
      logger.log(lpVerbose,'new logger');
    end;
    with logger do
    case code of
      HCBT_MOVESIZE:
        deflog('CBTProc: HCBT_MOVESIZE');
      HCBT_MINMAX:
        deflog('CBTProc: HCBT_MINMAX');
      HCBT_QS:
        deflog('CBTProc: HCBT_QS');
      HCBT_CREATEWND:
        deflog('CBTProc: HCBT_CREATEWND');
      HCBT_DESTROYWND:
        deflog('CBTProc: HCBT_DESTROYWND');
      HCBT_ACTIVATE:
        deflog('CBTProc: HCBT_ACTIVATE');
      HCBT_CLICKSKIPPED:
        deflog('CBTProc: HCBT_CLICKSKIPPED');
      HCBT_KEYSKIPPED:
        deflog('CBTProc: HCBT_KEYSKIPPED');
      HCBT_SYSCOMMAND:
        deflog('CBTProc: HCBT_SYSCOMMAND');
      HCBT_SETFOCUS:
        deflog('CBTProc: HCBT_SETFOCUS');
      else
        deflogfmt('CBTProc: %8.8X',[wparam]);
    end;
  finally
    hookbusy.Release
  end;
  result := CallNextHookEx(0, code, wparam, lparam);
end;

function StartCBTHook:boolean;//(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
begin
  InitShareLog('StartCBTHook');
  HookHandle := SetWindowsHookEx(WH_CBT, @CBTProc, hinstance, 0);
  log('StartCBTHook: %X %X',[HookHandle,hinstance]);
  result := HookHandle <> 0
end;

{$ENDIF}

end.
