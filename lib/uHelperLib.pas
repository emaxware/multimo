unit uHelperLib;

interface

uses
  Winapi.messages
  , Winapi.windows
  , System.SysUtils
  , System.SyncObjs
  , System.classes
//  , System.
  ;

var
  DefWindowClass: TWndClass = (
    style: 0;
    lpfnWndProc: @DefWindowProc;
    cbClsExtra: 0;
    cbWndExtra: 0;
    hInstance: 0;
    hIcon: 0;
    hCursor: 0;
    hbrBackground: 0;
    lpszMenuName: nil;
    lpszClassName: 'DefWindowClass');

type
  TWndProcRef = reference to function(var Message:TMessage):boolean;
  TMsgProcRef = reference to function(var Message:TMsg):boolean;

  TMonitorWindow = class
  protected
    FHWND:HWND;
    FWndProc:TWndProcRef;
  public
    constructor create(const AWndClass:TWndClass; AWndProc:TWndProcRef; AName:pwidechar; AParentHWND:HWND = 0); overload;
    constructor create(AWndClass:TWndClass; AWndProc:TWndProcRef; AParentHWND:HWND; AName:pwidechar; AExStyle, AStyle:DWORD; x, y, width, height:integer); overload;
    destructor destroy; override;

    procedure WndProc(var Message: TMessage);
    property HWND:HWND read FHWND;
  end;

  TMessageLoop = class
  protected
//    FMsgProc:TWndProcRef;
//    FInitLoop, FCleanupLoop:TProc;
  public
    constructor Create(ACancel:TEvent; AMsgProc:TMsgProcRef = nil; AInitLoop:TFunc<boolean> = nil; ACleanupLoop:TFunc<boolean> = nil);
  end;

function AllocateHWnd2(const AMethod: TWndMethod; const AWndClass:TWndClass; AParentHWND:HWND = 0): HWND; overload;
function AllocateHWnd2(const AMethod: TWndMethod; AWndClass:TWndClass; AParentHWND:HWND; ATitle:pchar; AExStyle:DWORD = WS_EX_TOOLWINDOW; AStyle:DWORD = WS_POPUP; x:integer = 0; y:integer = 0; width:integer = 0; height:integer = 0): HWND; overload;

implementation

uses
  System.Threading
  , uLoggerLib
  ;

function AllocateHWnd2(const AMethod: TWndMethod; const AWndClass:TWndClass; AParentHWND:HWND = 0): HWND; overload;
begin
  result := AllocateHWnd2(AMethod, AWndClass, AParentHWND, '')
end;

function AllocateHWnd2(const AMethod: TWndMethod; AWndClass:TWndClass; AParentHWND:HWND; ATitle:pchar; AExStyle, AStyle:DWORD; x, y, width, height:integer ): HWND; overload;
var
  TempClass: TWndClass;
  ClassRegistered: Boolean;
begin
  AWndClass.hInstance := HInstance;
  AWndClass.hCursor := LoadCursor(0, IDC_ARROW);
  ClassRegistered := GetClassInfo(HInstance, AWndClass.lpszClassName, TempClass);
  if not ClassRegistered or (TempClass.lpfnWndProc <> @DefWindowProc) then
  begin
    if ClassRegistered then
      Winapi.Windows.UnregisterClass(AWndClass.lpszClassName, HInstance);
    Winapi.Windows.RegisterClass(AWndClass);
  end;
  Result := CreateWindowEx(AExStyle
    , AWndClass.lpszClassName
    , pchar(ATitle)
    , AStyle
    , x
    , y
    , width
    , height
    , AParentHWND
    , 0
    , HInstance
    , nil);
  Win32Check(result <> 0);
  if Assigned(AMethod) then
    SetWindowLongPtr(Result, GWL_WNDPROC, IntPtr(MakeObjectInstance(AMethod)));
end;

constructor TMonitorWindow.create(AWndClass:TWndClass; AWndProc:TWndProcRef; AParentHWND:HWND; AName:pwidechar;
  AExStyle, AStyle: DWORD; x, y, width, height: integer);
begin
  FWNDProc := AWndProc;
  AWndClass.lpszClassName := pchar(self.ClassName);
  FHWND := AllocateHWnd2(WndProc, AWndClass, AParentHWND, AName, AExStyle, AStyle, x, y, width, height)
end;

constructor TMonitorWindow.create(const AWndClass:TWndClass; AWndProc:TWndProcRef; AName:pwidechar; AParentHWND:HWND);
begin
//  FWNDProc := AWndProc;
  create(AWndClass, AWndProc, AParentHWND, AName, WS_EX_TOOLWINDOW, WS_POPUP, 0, 0, 0, 0)
//  FHWND := AllocateHWnd2(WndProc, AWndClass, AParentHWND)
end;

destructor TMonitorWindow.destroy;
begin
  DeallocateHWND(FHWND);
  inherited;
end;

procedure TMonitorWindow.WndProc(var Message: TMessage);
begin
  if not (assigned(FWndProc) and FWndProc(message)) then
    with Message do
      Result := DefWindowProc(FHWND, Msg, wParam, lParam);
//  if not (assigned(FWndProc) and FWndProc(message)) then
end;

constructor TMessageLoop.Create(ACancel:TEvent; AMsgProc:TMsgProcRef; AInitLoop, ACleanupLoop:TFunc<boolean>);
begin
  var cancel := ACancel;
  TThreadPool.Default.QueueWorkItem(
    procedure
    begin
      var msg:TMsg;
      if (not assigned(AInitLoop)) or AInitLoop then
      begin
        while GetMessage(Msg, 0, 0, 0) and (ACancel.WaitFor(0) = twaitresult.wrTimeout) do
        try
          if (not assigned(AMsgProc)) or AMsgProc(msg) then
          begin
            TranslateMessage(msg);
            DispatchMessage(msg)
          end
        except
          on e:exception do
            log(e, 'Creating messageloop')
        end;
        if not assigned(ACleanupLoop) then
          ACleanupLoop
      end
    end);
end;

end.
