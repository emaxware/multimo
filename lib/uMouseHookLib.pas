unit uMouseHookLib;

interface

uses
  Winapi.windows
  , System.SysUtils
  , System.Classes
  , System.Generics.Collections
  , System.SyncObjs
//  , Vcl.Forms
//  , System.Threading
  ;

const
  WM_APP = $8000;

  WM_APP_STOPHOOK             = WM_APP + $0001;
  WM_APP_LLMOUSE              = WM_APP + $0002;
//  SYNERGY_MSG_MARK            = WM_APP + $0011;        // mark id; <unused>
//  SYNERGY_MSG_KEY             = WM_APP + $0012;        // vk code; key data
//  SYNERGY_MSG_MOUSE_BUTTON    = WM_APP + $0013;        // button msg; <unused>
//  SYNERGY_MSG_MOUSE_WHEEL     = WM_APP + $0014;        // delta; <unused>
//  SYNERGY_MSG_MOUSE_MOVE      = WM_APP + $0015;        // x; y
//  SYNERGY_MSG_POST_WARP       = WM_APP + $0016;        // <unused>; <unused>
//  SYNERGY_MSG_PRE_WARP        = WM_APP + $0017;        // x; y
//  SYNERGY_MSG_SCREEN_SAVER    = WM_APP + $0018;        // activated; <unused>
//  SYNERGY_MSG_DEBUG           = WM_APP + $0019;        // data, data
//  SYNERGY_MSG_INPUT_FIRST     = SYNERGY_MSG_KEY;
//  SYNERGY_MSG_INPUT_LAST      = SYNERGY_MSG_PRE_WARP;
//  SYNERGY_HOOK_LAST_MSG       = SYNERGY_MSG_DEBUG;

type
//  PLLMouseHookStruct = ^TLLMouseHookStruct;
//  tagLLMOUSEHOOKSTRUCT = record
//    pt: TPoint;
//    mouseData: DWORD;
//    flags: DWORD;
//    time: DWORD;
//    dwExtraInfo: ULONG_PTR;
//  end;
  TLLMouseHookStruct = tagLLMOUSEHOOKSTRUCT;
//  LLMOUSEHOOKSTRUCT = tagLLMOUSEHOOKSTRUCT;



  TLLMouseHookData = record
    wparam:WPARAM;
    data:TLLMouseHookStruct;
    constructor Create(AParam:WPARAM; AData:TLLMouseHookStruct);
  end;

  TLLMouseProc = reference to function(code:integer; wparam:WPARAM; var llMouse:TLLMouseHookStruct):boolean;

  TCustomHookThread = class(TThread)
  protected
    function StartHook(var AHandle:HHOOK):boolean; virtual;
    procedure StopHook(var AHandle:HHOOK); virtual;
    procedure ListenHook; virtual;

    procedure OnHookReceived; virtual; abstract;
//    function ReadyEvent:TSimpleEvent; virtual; abstract;

    procedure Execute; override;
  public
    constructor create;
  end;

  TLLMouseHook = class(TCustomHookThread)
  protected
    class var
//      fReady:TSimpleEvent;
      fHandle:HHOOK;
      fBuffer:TThreadList<TLLMouseHookData>;
//      fHooks
      fThreadId:Cardinal;
    function StartHook(var AHandle:HHOOK):boolean; override;
    procedure StopHook(var AHandle:HHOOK); override;
    procedure OnHookReceived; override;
//    function ReadyEvent:TSimpleEvent; override;
  public
    constructor create;
  end;

  TLLMouseHook = class(TCustomHookThread)
  protected
    class var
//      fReady:TSimpleEvent;
      fHandle:HHOOK;
      fBuffer:TThreadList<TLLMouseHookData>;
//      fHooks
      fThreadId:Cardinal;
    function StartHook(var AHandle:HHOOK):boolean; override;
    procedure StopHook(var AHandle:HHOOK); override;
    procedure OnHookReceived; override;
//    function ReadyEvent:TSimpleEvent; override;
  public
    constructor create;
  end;

function StartLLMouseHook(OnHook:TLLMouseProc):boolean;
procedure EndLLMouseHook;

function StartMouseHook:boolean;//(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
procedure EndMouseHook;

function StartCBTHook:boolean;//(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
procedure EndCBTHook;

//procedure InitDLL(const ADesc:string);

implementation

uses
  winapi.messages
//  , system.syncobjs
{$IFDEF SHARELIB}
  , uShareLib
  , uAPILogClient
  , uAPILib
{$ENDIF}
  , uLoggerLib
  ;

var
  HookHandle:HHOOK = 0;
  FOnLLMouseHook:TLLMouseProc = nil;

procedure EndLLMouseHook;
begin
  UnhookWindowsHookEx(HookHandle)
end;

function LowLevelMouseProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT stdcall;
var MouseInfo:PLLMouseHookStruct absolute lparam;
begin
{$IFDEF SHARELIB}
  InitShareLog('LowLevelMouseProc');
{$ENDIF}
  writeln('LowLevelMouseProc');
//  if FOnLLMouseHook(code,wparam,MouseInfo^) then
    result := CallNextHookEx(HookHandle, code, wparam, lparam)
end;

function StartLLMouseHook(OnHook:TLLMouseProc):boolean;
begin
{$IFDEF SHARELIB}
  InitShareLog('StartLLMouseHook');
{$ENDIF}
  log('Starting StartLLMouseHook');
  FOnLLMouseHook := OnHook;
  HookHandle := SetWindowsHookEx(WH_MOUSE_LL, @LowLevelMouseProc, 0, 0);
  result := HookHandle <> 0
end;

{$IF DEFINED(USEDLLHOOK) AND NOT DEFINED(INDLL)}

function StartMouseHook:boolean; external 'MultiMoDLL.dll'; //(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
procedure EndMouseHook; external 'MultiMoDLL.dll';

function StartCBTHook:boolean; external 'MultiMoDLL.dll';//(OnHook:TFunc<integer,wparam,PMouseHookStruct,boolean>):boolean;
procedure EndCBTHook; external 'MultiMoDLL.dll';

{$IFEND}

{$IF NOT DEFINED(USEDLLHOOK) OR DEFINED(INDLL)}

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
{$IFDEF SHARELIB}
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
{$ELSE}
    with TSimpleLogger.DefLogger do
{$ENDIF}
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
{$IFDEF SHARELIB}
  InitShareLog('StartMouseHook');
{$ENDIF}
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
{$IFDEF SHARELIB}
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
{$ELSE}
    with TSimpleLogger.DefLogger do
{$ENDIF}
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
{$IFDEF SHARELIB}
  InitShareLog('StartCBTHook');
{$ENDIF}
  HookHandle := SetWindowsHookEx(WH_CBT, @CBTProc, hinstance, 0);
  log('StartCBTHook: %X %X',[HookHandle,hinstance]);
  result := HookHandle <> 0
end;

{$ENDIF}

{ TCustomHookThread }

constructor TCustomHookThread.create;
begin
  FreeOnTerminate := true;
  inherited create(False)
end;

procedure TCustomHookThread.Execute;
var
  AHandle:HHOOK;
begin
  if StartHook(AHandle) then
  try
    ListenHook
  finally
    StopHook(AHandle)
  end
end;

procedure TCustomHookThread.ListenHook;
var
  AReadyEvent:THandle;
  msg:TMsg;
begin
//  AReadyEvent := ReadyEvent.Handle;
  while
    GetMessage(Msg, 0, 0, 0)
    and (msg.message <> WM_APP_STOPHOOK) do
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
    if msg.message=WM_APP_LLMOUSE then
      OnHookReceived
  end
end;

function TCustomHookThread.StartHook(var AHandle:HHOOK):boolean;
var
  AMsg:tagMSG;
begin
  result := true;
  PeekMessage(AMsg, 0, WM_USER, WM_USER, PM_NOREMOVE)
end;

procedure TCustomHookThread.StopHook(var AHandle:HHOOK);
begin
  if AHandle <> 0 then
  begin
    UnhookWindowsHookEx(AHandle);
    AHandle := 0
  end;
end;

{ TLLMouseHook }

function _LowLevelMouseProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT; stdcall;
var MouseInfo:PLLMouseHookStruct absolute lparam;
begin
  if TLLMouseHook.fBuffer <> nil then
  begin
    with TLLMouseHook.fBuffer, LockList do
    try
      Add(TLLMouseHookData.Create(wparam, MouseInfo^));
      if Count > 1000 then
        Delete(0)
    finally
      UnlockList
    end;
    PostThreadMessage(TLLMouseHook.fThreadId, WM_APP_LLMOUSE, wparam, code);
    result := CallNextHookEx(TLLMouseHook.fHandle, code, wparam, lparam);
    exit
  end;
  result := 0// CallNextHookEx(TLLMouseHook.fHandle, code, wparam, lparam)
end;

constructor TLLMouseHook.create;
begin
  if fBuffer = nil then
    inherited create
  else
    raise Exception.Create('Hook already exists!!')
end;

procedure TLLMouseHook.OnHookReceived;
var
  AMouseMsg:TLLMouseHookData;
begin
  repeat
    with TLLMouseHook.fBuffer, LockList do
    try
      if Count > 0 then
      begin
        AMouseMsg := Items[0];
        Delete(0)
      end
      else
      begin
//        fReady.ResetEvent;
        exit
      end
    finally
      UnlockList
    end;
    var msgname := format('$%4X',[AMouseMsg.wparam]);
    var msgdet := format('%d,%d',[AMouseMsg.data.pt.x, AMouseMsg.data.pt.Y]);
    var msgdata := '';
    case AMouseMsg.wparam of
      WM_LBUTTONDBLCLK    : msgname := 'WM_LBUTTONDBLCLK';
      WM_LBUTTONDOWN      : msgname := 'WM_LBUTTONDOWN';
      WM_LBUTTONUP        : msgname := 'WM_LBUTTONUP';
      WM_MBUTTONDBLCLK    : msgname := 'WM_MBUTTONDBLCLK';
      WM_MBUTTONDOWN      : msgname := 'WM_MBUTTONDOWN';
      WM_MBUTTONUP        : msgname := 'WM_MBUTTONUP';
      WM_MOUSEHWHEEL      : msgname := 'WM_MOUSEHWHEEL';
      WM_MOUSEMOVE        : msgname := 'WM_MOUSEMOVE';
      WM_MOUSEWHEEL       : msgname := 'WM_MOUSEWHEEL';
      WM_RBUTTONDBLCLK    : msgname := 'WM_RBUTTONDBLCLK';
      WM_RBUTTONDOWN      : msgname := 'WM_RBUTTONDOWN';
      WM_RBUTTONUP        : msgname := 'WM_RBUTTONUP';
      WM_XBUTTONDBLCLK    : msgname := 'WM_XBUTTONDBLCLK';
      WM_XBUTTONDOWN      : msgname := 'WM_XBUTTONDOWN';
      WM_XBUTTONUP        : msgname := 'WM_XBUTTONUP';
    end;
    writeln(format('%s %s %s',[msgname, msgdet, msgdata]))
  until false;
end;

//function TLLMouseHook.ReadyEvent: TSimpleEvent;
//begin
//  result := fReady
//end;

function TLLMouseHook.StartHook(var AHandle:HHOOK):boolean;
begin
  result := inherited;
  if result and (fBuffer = nil) then
  begin
    fBuffer := TThreadList<TLLMouseHookData>.Create;
    fBuffer.Duplicates := dupAccept;
    fThreadId  := threadid;
//    fReady := TSimpleEvent.Create(false);
    AHandle := SetWindowsHookEx(WH_MOUSE_LL, @_LowLevelMouseProc, 0, 0);
    fHandle := AHandle;
  end
end;

procedure TLLMouseHook.StopHook(var AHandle: HHOOK);
begin
  inherited;
  with fBuffer, LockList do
  try
    Clear
  finally
    UnlockList
  end;
  freeandnil(fBuffer);
//  freeandnil(fReady)
end;

constructor TLLMouseHookData.Create(AParam:WPARAM; AData:TLLMouseHookStruct);
begin
  wParam := AParam;
  data := AData
end;

end.
