unit uLLHookLib;

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
  PLLMouseHookStruct = ^TLLMouseHookStruct;
  tagLLMOUSEHOOKSTRUCT = record
    pt: TPoint;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  TLLMouseHookStruct = tagLLMOUSEHOOKSTRUCT;
//  LLMOUSEHOOKSTRUCT = tagLLMOUSEHOOKSTRUCT;

  PLLKbdHookStruct = ^TLLKbdHookStruct;
  tagLLKBDHOOKSTRUCT = record
    vkCode:DWORD;
    scanCode:DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  TLLKbdHookStruct = tagLLKBDHOOKSTRUCT;

  TLLMouseHookData = record
    wparam:WPARAM;
    data:TLLMouseHookStruct;
    constructor Create(AParam:WPARAM; AData:TLLMouseHookStruct);
  end;

  TLLKbdHookData = record
    wparam:WPARAM;
    data:TLLKbdHookStruct;
    constructor Create(AParam:WPARAM; AData:TLLKbdHookStruct);
  end;

  TCustomHookThread = class(TThread)
  protected
    function StartHook(var AHandle:HHOOK):boolean; virtual;
    procedure StopHook(var AHandle:HHOOK); virtual;
    procedure ListenHook; virtual;

    procedure OnHookReceived; virtual; abstract;
//    function ReadyEvent:TSimpleEvent; virtual; abstract;

    procedure Execute; override;
    constructor create;
  end;

  TOnMouseHookListener = reference to procedure(AHookData:TLLMouseHookData);

  TLLMouseHook = class(TCustomHookThread)
  protected
    class var
//      fReady:TSimpleEvent;
      fHandle:HHOOK;
      fBuffer:TThreadList<TLLMouseHookData>;
      fListeners:TThreadList<TOnMouseHookListener>;
//      fHooks
      fThreadId:Cardinal;
      fInstance:TLLMouseHook;
    function StartHook(var AHandle:HHOOK):boolean; override;
    procedure StopHook(var AHandle:HHOOK); override;
    procedure OnHookReceived; override;
//    function ReadyEvent:TSimpleEvent; override;
    constructor create;
  public
    class function Instance:TLLMouseHook;

    function AddListener(AListener:TOnMouseHookListener):integer;
    procedure RemoveListener(AIndex:Integer);
  end;

  TOnKbdHookListener = reference to procedure(AHookData:TLLKbdHookData);

  TLLKbdHook = class(TCustomHookThread)
  protected
    class var
//      fReady:TSimpleEvent;
      fHandle:HHOOK;
      fBuffer:TThreadList<TLLKbdHookData>;
      fListeners:TThreadList<TOnKbdHookListener>;
//      fHooks
      fThreadId:Cardinal;
      fInstance:TLLKbdHook;
    function StartHook(var AHandle:HHOOK):boolean; override;
    procedure StopHook(var AHandle:HHOOK); override;
    procedure OnHookReceived; override;
//    function ReadyEvent:TSimpleEvent; override;
    constructor create;
  public
    class function Instance:TLLKbdHook;

    function AddListener(AListener:TOnKbdHookListener):integer;
    procedure RemoveListener(AIndex:Integer);
  end;

implementation

uses
  winapi.messages
  , uLoggerLib
  ;

{ TCustomHookThread }

constructor TCustomHookThread.create;
begin
  FreeOnTerminate := true;
  inherited create(true)
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

function TLLMouseHook.AddListener(AListener: TOnMouseHookListener): integer;
begin
  with fListeners, LockList do
  try
    result := Add(AListener)
  finally
    UnlockList
  end;
end;

constructor TLLMouseHook.create;
begin
  if fBuffer = nil then
  begin
    inherited create
  end
  else
    raise Exception.Create('Hook already exists!!')
end;

class function TLLMouseHook.Instance: TLLMouseHook;
begin
  if fInstance = nil then
    fInstance := TLLMouseHook.create;
  result := fInstance
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

    with fListeners do
    try
      var list := LockList;
      for var listener in list do
      if listener <> nil then
        listener(AMouseMsg);
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

procedure TLLMouseHook.RemoveListener(AIndex: Integer);
begin
  with fListeners, LockList do
  try
    Items[AIndex] := nil
  finally
    UnlockList
  end;
end;

function TLLMouseHook.StartHook(var AHandle:HHOOK):boolean;
begin
  result := inherited;
  if result and (fBuffer = nil) then
  begin
    fBuffer := TThreadList<TLLMouseHookData>.Create;
    fBuffer.Duplicates := dupAccept;
    fListeners := TThreadList<TOnMouseHookListener>.create;
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
  freeandnil(fBuffer)
end;

constructor TLLMouseHookData.Create(AParam:WPARAM; AData:TLLMouseHookStruct);
begin
  wParam := AParam;
  data := AData
end;

{ TLLKbdHookData }

constructor TLLKbdHookData.Create(AParam: WPARAM; AData: TLLKbdHookStruct);
begin
  wparam := AParam;
  data := AData
end;

{ TLLKbdHook }

function _LowLevelKbdProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT; stdcall;
var KbdInfo:PLLKbdHookStruct absolute lparam;
begin
  if TLLKbdHook.fBuffer <> nil then
  begin
    with TLLKbdHook.fBuffer, LockList do
    try
      Add(TLLKbdHookData.Create(wparam, KbdInfo^));
      if Count > 1000 then
        Delete(0)
    finally
      UnlockList
    end;
    PostThreadMessage(TLLKbdHook.fThreadId, WM_APP_LLMOUSE, wparam, code);
    result := CallNextHookEx(TLLKbdHook.fHandle, code, wparam, lparam);
    exit
  end;
  result := 0// CallNextHookEx(TLLMouseHook.fHandle, code, wparam, lparam)
end;
function TLLKbdHook.AddListener(AListener: TOnKbdHookListener): integer;
begin

end;

constructor TLLKbdHook.create;
begin
  if fBuffer = nil then
    inherited create
  else
    raise Exception.Create('Hook already exists!!')
end;

class function TLLKbdHook.Instance: TLLKbdHook;
begin

end;

procedure TLLKbdHook.OnHookReceived;
var
  AMsg:TLLKbdHookData;
begin
  repeat
    with TLLKbdHook.fBuffer, LockList do
    try
      if Count > 0 then
      begin
        AMsg := Items[0];
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
    var msgname := format('$%8.8X',[AMsg.wparam]);
    var msgdet := format('%8.8X %8.8X',[AMsg.data.vkCode, AMsg.data.scanCode]);
    var msgdata := '';
    case AMsg.wparam of
      WM_KEYDOWN            : msgname := 'WM_KEYDOWN';
      WM_KEYUP              : msgname := 'WM_KEYUP';
      WM_CHAR               : msgname := 'WM_CHAR';
      WM_DEADCHAR           : msgname := 'WM_DEADCHAR';
      WM_SYSKEYDOWN         : msgname := 'WM_SYSKEYDOWN';
      WM_SYSKEYUP           : msgname := 'WM_SYSKEYUP';
      WM_SYSCHAR            : msgname := 'WM_SYSCHAR';
      WM_SYSDEADCHAR        : msgname := 'WM_SYSDEADCHAR';
      WM_UNICHAR            : msgname := 'WM_UNICHAR';
    end;
    writeln(format('%s %s %s',[msgname, msgdet, msgdata]))
  until false;
end;

procedure TLLKbdHook.RemoveListener(AIndex: Integer);
begin

end;

function TLLKbdHook.StartHook(var AHandle: HHOOK): boolean;
begin
  result := inherited;
  if result and (fBuffer = nil) then
  begin
    fBuffer := TThreadList<TLLKbdHookData>.Create;
    fBuffer.Duplicates := dupAccept;
    fThreadId  := threadid;
//    fReady := TSimpleEvent.Create(false);
    AHandle := SetWindowsHookEx(WH_KEYBOARD_LL, @_LowLevelKbdProc, 0, 0);
    fHandle := AHandle;
  end
end;

procedure TLLKbdHook.StopHook(var AHandle: HHOOK);
begin
  inherited;
  with fBuffer, LockList do
  try
    Clear
  finally
    UnlockList
  end;
  freeandnil(fBuffer)
end;

end.
