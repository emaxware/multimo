unit uHookLib;

interface

uses
  System.SyncObjs
//  , uMonLib,
//  , uAPILib
  ;

procedure StartMouseHook(ACancel:TEvent; AddMessagePump:boolean);
procedure EndMouseHook;

//procedure InitMonDefs(monDefs:TMonDefs);

implementation

uses
  Winapi.psapi,
  Winapi.messages,
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Threading,
  System.Generics.Collections,
  uMonLib,
  uEventLib,
  uHelperLib,
  HidUsage,
  CnRawInput
  , uLoggerLib
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

var
  HookHandle:HHOOK;
  MonDefs:TMonDefs;
  MsgPump:TObject;
  MonHWND:TMonitorWindow;

const
  WM_GETMONDEFS = WM_USER + 1;
  WM_MOVEMOUSE = WM_USER + 2;

type
  TPortalWindow = class(TMonitorWindow)
  protected
    FMon:TMonitorDef;
    FRect:TRect;
  public
    constructor create(AWndProc:TWndProcRef; AMonDef:TMonitorDef);

    property Mon:TMonitorDef read FMon;
    property Rect:TRect read FRect;
  end;

var
{$IFDEF PORTALWINDOWS}
  MonMasks:TObjectList<TPortalWindow> = nil;
{$ENDIF}
  PendingMove:TInputEvent = (
    event : tiNull
    );
  nextIndex:integer = -1;

{ TPortalWindow }

constructor TPortalWindow.create(AWndProc:TWndProcRef; AMonDef:TMonitorDef);
begin
  DefWindowClass.hbrBackground := GetStockObject(WHITE_BRUSH);
  FMon := AMonDef;
  FRect := TRect.Create(AMonDef.orig, AMonDef.virtSize.cx, AMonDef.virtSize.cy);
//  FOrigin := AMonDef.orig;
  FRect.Offset(200*(AMonDef.index+1), 200*(AMonDef.index+1));
//  FSize := AMonDef.virtsize;
  FRect.Width := 100;//FRect.Width div 4;
  FRect.Height := 100;// FRect.Height div 4;
  inherited create(
    AWndProc
    , DefWindowClass
    , pchar(string(AMonDef.monname))
    , WS_EX_TOPMOST //or WS_EX_LAYERED
    , WS_POPUP or WS_CAPTION or WS_VISIBLE
    , FRect.Left
    , FRect.Top
    , FRect.Width
    , FRect.Height
    );
  Win32Check(SetWindowLong(FHWND, GWL_STYLE, WS_POPUP or WS_VISIBLE) <> 0);
//  Win32Check(ShowWindow(FHWND, SW_SHOW));
  Win32Check(SetWindowLong(FHWND, GWL_EXSTYLE, GetWindowLong(FHWND, GWL_EXSTYLE) or WS_EX_LAYERED) <> 0);
  Win32Check(SetLayeredWindowAttributes(FHWND, $00FFFF00, $7F, LWA_ALPHA OR LWA_COLORKEY));
end;

function ResetMonDefs(AmonDefs:TMonDefs):boolean;
begin
  TMonitor.Enter(MsgPump);
  try
    result := MonDefsChanged(MonDefs, AMonDefs);
    if result then
    begin
{$IFDEF PORTALWINDOWS}
      if assigned(MonMasks) then
        MonMasks.clear
      else
        MonMasks := TObjectList<TPortalWindow>.create;
{$ENDIF}
      PrintMonDefs(MonDefs);
      MonDefs := AmonDefs;
{$IFDEF PORTALWINDOWS}
      for var mon in MonDefs do
      begin
        var monMask:TPortalWindow;
        monMask := TPortalWindow.create(
          function (var msg:TMessage):boolean
          begin
            result := true;
          end
          , mon);
//        monMask.EnableHover;
        MonMasks.add(monMask)
      end;
{$ENDIF}
      PrintMonDefs(MonDefs)
    end
  finally
    TMonitor.Exit (MsgPump)
  end;
end;

//var lastMonDefIndex:integer = -1;

function LowLevelMouseProc(code: Integer; wparam: WPARAM; lparam: LPARAM): LRESULT stdcall;
var MouseInfo:PLLMouseHookStruct absolute lparam;
begin
  if TMonitor.TryEnter(MsgPump) then
  try
    case wparam of
      WM_LBUTTONDOWN:
        log('HOOK: WM_LBUTTONDOWN');
      WM_LBUTTONUP:
        log('HOOK: WM_LBUTTONUP');
      WM_MOUSEMOVE:
      with mouseinfo^ do
      begin
//        var monIndex:integer;
//        var deskpt,monpt,sclpt,normPt:TPoint;
//        var polarpt:TPointf;
//        var monDef:TMonitorDef;
//        if pt.FromMousePtToMonPt(
//          MonDefs
//          , monIndex
//          , deskpt
//          , monpt
//          , sclpt
//          , normPt
//          , polarpt
//          , monDef) then
//        begin
//          var foundWin:TPortalWindow := nil;
//          for var win in MonMasks do
//            if win.FRect.Contains(deskpt) then
//            begin
//              foundWin := win;
//              break
//            end;
//          if assigned(foundWin) then
//          begin
//            if (nextIndex <> monIndex) then
//            begin
//              log(format('%s %d -> %d',[foundWin.FMon.monname,monIndex,(monIndex+1) mod length(monDefs)]));
//              nextIndex := (monIndex+1) mod length(monDefs);
//              sclpt.SetLocation(
//                sclpt.X
//                  -(MonMasks[monIndex].FRect.Left-MonMasks[monIndex].FMon.orig.x)
//                  +(MonMasks[nextIndex].FRect.Left-MonMasks[nextIndex].FMon.orig.x)
//                , sclpt.X
//                  -(MonMasks[monIndex].FRect.Top-MonMasks[monIndex].FMon.orig.y)
//                  +(MonMasks[nextIndex].FRect.Top-MonMasks[nextIndex].FMon.orig.y)
//                );
//              PendingMove.MoveTo(
//                mondefs[nextIndex]
//                , sclpt.FromScaledtoMon(mondefs[nextIndex]));// double(-0.25), double(0.25));
//              PostMessage(MonHWND.HWND, WM_MOVEMOUSE, 0, 0);
//            end
//            else
//              log(foundWin.FMon.monname);
//          end
//          else
//          begin
//            nextIndex := -1;
//            log(format('HOOK: %d %d -> mon:%d,%d scale:%d,%d desk:%d,%d norm:%d,%d polar:%.2f,%.2f mon(#%d %d,%d %d,%d)',[
//              pt.x, pt.y
//              , monpt.x, monpt.Y
//              , sclpt.X, sclpt.y
//              , deskpt.X, deskpt.Y
//              , normpt.x, normpt.y
//              , polarpt.x, polarpt.Y
//              , monIndex
//              , mondef.orig.x, mondef.orig.y, mondef.size.width, mondef.size.height
//              ]));
//          end;
//        end
//        else
          log(format('HOOK: WM_MOUSEMOVE %d %d (%X)',[
            pt.X
            , pt.Y
            , flags
            ]));
      end;
      WM_MOUSEWHEEL:
        log('HOOK: WM_MOUSEWHEEL');
      WM_MOUSEHWHEEL:
        log('HOOK: WM_MOUSEHWHEEL');
      WM_RBUTTONDOWN:
        log('HOOK: WM_RBUTTONDOWN');
      WM_RBUTTONUP:
        log('HOOK: WM_RBUTTONUP');
    end;
  finally
    TMonitor.Exit(MsgPump)
  end;
  result := CallNextHookEx(0, code, wparam, lparam)
end;

procedure StartMouseHook(ACancel:TEvent; AddMessagePump:boolean);
begin
  var monLoop:TFunc<boolean> := function:boolean
    begin
      try
        Log('Starting monitor window..');
        MonHWND := TMonitorWindow.create(
          function (var msg:TMessage):boolean
          begin
            try
              result := true;
              case msg.Msg of
                WM_MOUSEMOVE:
                  log('MON: WM_MOUSEMOVE');
                WM_DISPLAYCHANGE:
                begin
                  log('MON: WM_DISPLAYCHANGE *');
                  PostMessage(MonHWND.HWND, WM_GETMONDEFS, 0, 0)
                end;
                WM_GETMONDEFS:
                begin
                  log('MON: WM_GETMONDEFS * %X', [msg.LParam]);
                  if not ResetMonDefs(InitMonitors(true)) and (msg.LParam < 30) then
                    PostMessage(MonHWND.HWND, WM_GETMONDEFS, 0, msg.lparam + 1)
                end;
                WM_MOVEMOUSE:
                begin
                  log('MON: WM_MOVEMOUSE * ');
                  PendingMove.Emit;
                  PendingMove.Emit;
                  PendingMove.Clear
                end;
                WM_INPUT:
                begin
                  var Ri: tagRAWINPUT;
                  var Size: Cardinal;
                  Ri.header.dwSize := SizeOf(RAWINPUTHEADER);
                  Size := SizeOf(RAWINPUTHEADER);
                  GetRawInputData(HRAWINPUT(msg.LParam), RID_INPUT, nil,
                    Size, SizeOf(RAWINPUTHEADER));

                  if GetRawInputData(HRAWINPUT(msg.LParam), RID_INPUT, @Ri,
                    Size, SizeOf(RAWINPUTHEADER)) = Size then
                  begin
                    case Ri.header.dwType of
                      RIM_TYPEMOUSE:
                      begin
                        log(format('MON: WM_INPUT %d,%d',[ri.mouse.lLastX, ri.mouse.lLastY]));
                      end;
                    end;
                  end;
                end;
              end
            except
              on e:exception do
                log(e, 'HOOKLL')
            end;
          end
          );
        result := true;

        Log('Starting raw input..');
        if not GetRawInputAPIS then
        begin
          result := false;
          var error := GetLastError;
          log(format('Error GetRawInputAPIS: %d %s',[error, SysErrorMessage(error)]));
{$IFDEF ISCONSOLE}
          readln
{$ENDIF}
        end;

        var rid: RAWINPUTDEVICE;
        rid.usUsagePage := HID_USAGE_PAGE_GENERIC;
        rid.usUsage := HID_USAGE_GENERIC_MOUSE;
        rid.dwFlags :=  RIDEV_INPUTSINK;
        rid.hwndTarget := MonHWND.HWND;
        Log('Starting registring input devices..');
        if not RegisterRawINputDevices(@rid, 1, sizeof(rid)) then
        begin
          result := false;
          var error := GetLastError;
          log(format('Error registering rawinputdevice: %d %s',[error, SysErrorMessage(error)]));
{$IFDEF ISCONSOLE}
          readln
{$ENDIF}
        end;

        HookHandle := SetWindowsHookEx(WH_MOUSE_LL, @LowLevelMouseProc, 0, 0);
        Log('Starting hook..');
        if HookHandle = 0 then
        begin
          result := false;
          var error := GetLastError;
          log(format('Error setting hook: %d %s',[error, SysErrorMessage(error)]));
{$IFDEF ISCONSOLE}
          readln
{$ENDIF}
        end
        else
        begin
          ResetMonDefs(InitMonitors(false));
        end;
      except
        on e:exception do
          log(e, 'Start mouse hook..')
      end;
    end;
  if AddMessagePump then
    MsgPump := TMessageLoop.create(
      ACancel
      , function (var msg:TMsg):boolean
      begin
        result := true;
      end
      , monLoop
      , function:boolean
      begin
        result := true;
        EndMouseHook;
        MonHWND.free
      end)
  else
  begin
    MsgPump := TObject.create;
    var rslt:boolean := monLoop()
  end;
//  TMonitorWindow.CreateMonitorWindow(ACancel);
end;

procedure EndMouseHook;
begin
  UnhookWindowsHookEx(HookHandle)
end;

var
  client:uint8;

//procedure TPortalWindow.EnableHover;
//begin
//  var tm:TTrackMouseEvent;
//  tm.cbSize := sizeof(TTrackMouseEvent);
//  tm.dwFlags := TME_HOVER;
//  tm.hwndTrack := FHWND;
//  tm.dwHoverTime := HOVER_DEFAULT;
//  if not TrackMouseEvent(tm) then
//  begin
//    var error := GetLastError;
//    log(format('Error GetRawInputAPIS: %d %s',[error, SysErrorMessage(error)]));
//  end;
//end;

//procedure TPortalWindow.EnableLeave;
//begin
//  var tm:TTrackMouseEvent;
//  tm.cbSize := sizeof(TTrackMouseEvent);
//  tm.dwFlags := TME_LEAVE;
//  tm.hwndTrack := FHWND;
//  tm.dwHoverTime := HOVER_DEFAULT;
//  if not TrackMouseEvent(tm) then
//  begin
//    var error := GetLastError;
//    log(format('Error GetRawInputAPIS: %d %s',[error, SysErrorMessage(error)]));
//  end;
//end;

initialization
//  InitAPI(client)
end.
