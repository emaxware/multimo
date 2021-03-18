unit uLLHookLib;

{$DEFINE HOOK_TRACE}

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
  WM_APP_HOOKMSG              = WM_APP + $0002;

  MOUSEEVENTF_XDOWN = $0080;
  MOUSEEVENTF_XUP = $0100;
  MOUSEEVENTF_VIRTUALDESK = $4000;

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
    function ToString:string;
  end;
  PLLMouseHookData = ^TLLMouseHookData;

  TLLKbdHookData = record
    wparam:WPARAM;
    data:TLLKbdHookStruct;
    constructor Create(AParam:WPARAM; AData:TLLKbdHookStruct);
    function ToString:string;
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
    destructor Destroy; override;

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
    destructor Destroy; override;

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
  msg:TMsg;
begin
  while
    GetMessage(Msg, 0, 0, 0)
    and not terminated
//    and (msg.message <> WM_APP_STOPHOOK)
  do
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
    if msg.message=WM_APP_HOOKMSG then
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
    PostThreadMessage(TLLMouseHook.fThreadId, WM_APP_HOOKMSG, wparam, code);
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
    fListeners := TThreadList<TOnMouseHookListener>.create;
    inherited create
  end
  else
    raise Exception.Create('WH_MOUSE_LL Hook already exists!!')
end;

destructor TLLMouseHook.Destroy;
begin
  WaitFor;
  FreeAndNil(fBuffer);
  Freeandnil(fListeners);
  inherited;
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
        exit
    finally
      UnlockList
    end;

    with fListeners do
    try
      var list := LockList;
      var i:Integer;
      for i := 0 to list.Count-1 do
      begin
        var listener := list[i];
        if listener <> nil then
        try
          listener(AMouseMsg)
        except
          list[i] := nil
        end
      end
    finally
      UnlockList
    end;

{$IFDEF HOOK_TRACE}
//    if AMouseMsg.wparam<>WM_MOUSEMOVE then
    begin
      var currPt:TPoint;
      GetCursorPos(currPt);
      writeln(format('%d,%d %s',[currPt.X, currPt.Y, AMouseMsg.ToString]))
    end;
{$ENDIF}
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

function TLLKbdHookData.ToString: string;
begin
  var msgname := format('$%8.8X',[wparam]);
  var msgdet := format('%8.8X %8.8X',[data.vkCode, data.scanCode]);
  var msgdata := '';
  case wparam of
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
  result := format('%s %s %s',[msgname, msgdet, msgdata])
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
    PostThreadMessage(TLLKbdHook.fThreadId, WM_APP_HOOKMSG, wparam, code);
    result := CallNextHookEx(TLLKbdHook.fHandle, code, wparam, lparam);
    exit
  end;
  result := 0// CallNextHookEx(TLLMouseHook.fHandle, code, wparam, lparam)
end;

function TLLKbdHook.AddListener(AListener: TOnKbdHookListener): integer;
begin
  with fListeners, LockList do
  try
    result := Add(AListener)
  finally
    UnlockList
  end;
end;

constructor TLLKbdHook.create;
begin
  if fBuffer = nil then
  begin
    fListeners := TThreadList<TOnKbdHookListener>.create;
    inherited create
  end
  else
    raise Exception.Create('WH_KEYBOARD_LL Hook already exists!!')
end;

destructor TLLKbdHook.Destroy;
begin
  WaitFor;
  FreeAndNil(fBuffer);
  Freeandnil(fListeners);
  inherited;
end;

class function TLLKbdHook.Instance: TLLKbdHook;
begin
  if fInstance = nil then
    fInstance := TLLKbdHook.create;
  result := fInstance
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

    with fListeners do
    try
      var list := LockList;
      var i:Integer;
      for i := 0 to list.Count-1 do
      begin
        var listener := list[i];
        if listener <> nil then
        try
          listener(AMsg)
        except
          list[i] := nil
        end
      end
    finally
      UnlockList
    end;

{$IFDEF HOOK_TRACE}
    writeln(AMsg.ToString)
{$ENDIF}
  until false;
end;

procedure TLLKbdHook.RemoveListener(AIndex: Integer);
begin
  with fListeners, LockList do
  try
    Items[AIndex] := nil
  finally
    UnlockList
  end;
end;

function TLLKbdHook.StartHook(var AHandle: HHOOK): boolean;
begin
  result := inherited;
  if result and (fBuffer = nil) then
  begin
    fBuffer := TThreadList<TLLKbdHookData>.Create;
    fBuffer.Duplicates := dupAccept;
    fThreadId  := threadid;
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

function TLLMouseHookData.ToString: string;
  procedure CheckFlag(AFlag:WORD; const AFlagName:string; var ADesc:string);
  begin
    if (data.flags and AFlag) = AFlag then
      if ADesc='-' then
        ADesc := AFlagName
      else
        ADesc := ADesc + ',' + AFlagname
  end;
begin
  var msgname := format('$%4X',[wparam]);
  var msgdet := format('%d,%d',[data.pt.x, data.pt.Y]);
  var msgdata:string := '-';
  case wparam of
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

  CheckFlag(MOUSEEVENTF_MOVE, 'MOUSEEVENTF_MOVE', msgdata);
  CheckFlag(MOUSEEVENTF_LEFTDOWN, 'MOUSEEVENTF_LEFTDOWN', msgdata);
  CheckFlag(MOUSEEVENTF_LEFTUP, 'MOUSEEVENTF_LEFTUP', msgdata);
  CheckFlag(MOUSEEVENTF_RIGHTDOWN, 'MOUSEEVENTF_RIGHTDOWN', msgdata);
  CheckFlag(MOUSEEVENTF_RIGHTUP, 'MOUSEEVENTF_RIGHTUP', msgdata);
  CheckFlag(MOUSEEVENTF_MIDDLEDOWN, 'MOUSEEVENTF_MIDDLEDOWN', msgdata);
  CheckFlag(MOUSEEVENTF_MIDDLEUP, 'MOUSEEVENTF_MIDDLEUP', msgdata);
  CheckFlag(MOUSEEVENTF_XDOWN, 'MOUSEEVENTF_XDOWN', msgdata);
  CheckFlag(MOUSEEVENTF_XUP, 'MOUSEEVENTF_XUP', msgdata);
  CheckFlag(MOUSEEVENTF_WHEEL, 'MOUSEEVENTF_WHEEL', msgdata);
  CheckFlag(MOUSEEVENTF_HWHEEL, 'MOUSEEVENTF_HWHEEL', msgdata);
  CheckFlag(MOUSEEVENTF_MOVE_NOCOALESCE, 'MOUSEEVENTF_MOVE_NOCOALESCE', msgdata);
  CheckFlag(MOUSEEVENTF_VIRTUALDESK, 'MOUSEEVENTF_VIRTUALDESK', msgdata);
  CheckFlag(MOUSEEVENTF_ABSOLUTE, 'MOUSEEVENTF_ABSOLUTE', msgdata);

  if msgdata='-' then
    msgdata := format('$%4.4X',[data.flags]);

  result := format('%s %s %s',[msgname, msgdet, msgdata])
end;

end.
