unit uMonitorLib;

interface

uses
  System.SyncObjs
//  , uMonLib,
//  , uAPILib
  ;

type
  TMonitorOpt = (moAddMessagePump, moLLMouseHook, moMouseHook, moCBTHook);
  TMonitorOpts = set of TMonitorOpt;

procedure StartMonitor(ACancel:TEvent; Opts:TMonitorOpts);
//procedure EndMouseMonitor;

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
  uMouseHookLib,
  uHWNDLib,
  HidUsage,
  CnRawInput
  , uLoggerLib
  , uPortalWin
  , uAPILib
  ;

var
//  HookHandle:HHOOK;
  MonDefs:TMonDefs;
  MsgPump:TObject;
  MonHWND:TMonitorWindow;

const
  WM_GETMONDEFS = WM_USER + 1;
  WM_MOVEMOUSE = WM_USER + 2;

var
{$IFDEF PORTALWINDOWS}
  MonMasks:TObjectList<TPortalWindow> = nil;
{$ENDIF}
  PendingMove:TInputEvent = (
    event : tiNull
    );
  nextIndex:integer = -1;

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
          , TRect.Create(mon.orig, 200, 200).offsetto(100, 100)
          , mon);
//        monMask.EnableHover;
        MonMasks.add(monMask);

        monMask := TPortalWindow.create(
          function (var msg:TMessage):boolean
          begin
            result := true;
          end
          , TRect.Create(mon.orig, 200, 200).offsetto(mon.virtSize.cx-300, mon.virtSize.cy-300), mon);
//        monMask.EnableHover;
        MonMasks.add(monMask);

        monMask := TPortalWindow.create(
          function (var msg:TMessage):boolean
          begin
            result := true;
          end
          , TRect.Create(mon.orig, 200, 200).offsetto(100, mon.virtSize.cy-300), mon);
//        monMask.EnableHover;
        MonMasks.add(monMask);

        monMask := TPortalWindow.create(
          function (var msg:TMessage):boolean
          begin
            result := true;
          end
          , TRect.Create(mon.orig, 200, 200).offsetto(mon.virtSize.cx-300, 100), mon);
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

type
  THookMonitor = class(TMonitorWindow)

  end;

procedure StartMonitor(ACancel:TEvent; Opts:TMonitorOpts);
begin
  var monMSG := RegisterWindowMessage(pchar('CBTProc'));

  var monLoop:TFunc<boolean> := function:boolean
    begin
      try
        Log('Starting monitor window..');
        MonHWND := THookMonitor.create(
          DefWindowClass
          , function (var msg:TMessage):boolean
          begin
            try
              result := true;
//              if msg.msg = monMSG then
//              begin
//                var procname := ProcessFilename(msg.LParam, false);
//                case msg.WParam of
//                  HCBT_MOVESIZE:
//                    log('MONHWND: HCBT_MOVESIZE (%s)',[procname]);
//                  HCBT_MINMAX:
//                    log('MONHWND: HCBT_MINMAX (%s)',[procname]);
//                  HCBT_QS:
//                    log('MONHWND: HCBT_QS (%s)',[procname]);
//                  HCBT_CREATEWND:
//                    log('MONHWND: HCBT_CREATEWND (%s)',[procname]);
//                  HCBT_DESTROYWND:
//                    log('MONHWND: HCBT_DESTROYWND (%s)',[procname]);
//                  HCBT_ACTIVATE:
//                    log('MONHWND: HCBT_ACTIVATE (%s)',[procname]);
//                  HCBT_CLICKSKIPPED:
//                    log('MONHWND: HCBT_CLICKSKIPPED (%s)',[procname]);
//                  HCBT_KEYSKIPPED:
//                    log('MONHWND: HCBT_KEYSKIPPED (%s)',[procname]);
//                  HCBT_SYSCOMMAND:
//                    log('MONHWND: HCBT_SYSCOMMAND (%s)',[procname]);
//                  HCBT_SETFOCUS:
//                    log('MONHWND: HCBT_SETFOCUS (%s)',[procname]);
//                  else
//                    log('MONHWND: %8.8X (%s)',[msg.wparam,procname])
//                end;
//              end
//              else
              case msg.Msg of
//                WM_MOUSEMOVE:
//                  log('MONHWND: WM_MOUSEMOVE');
                WM_DISPLAYCHANGE:
                begin
                  log('MONHWND: WM_DISPLAYCHANGE *');
                  PostMessage(MonHWND.HWND, WM_GETMONDEFS, 0, 0)
                end;
                WM_GETMONDEFS:
                begin
                  log('MONHWND: WM_GETMONDEFS * %X', [msg.LParam]);
                  if not ResetMonDefs(InitMonitors(true)) and (msg.LParam < 30) then
                    PostMessage(MonHWND.HWND, WM_GETMONDEFS, 0, msg.lparam + 1)
                end;
                WM_MOVEMOUSE:
                begin
                  log('MONHWND: WM_MOVEMOUSE * ');
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
//                        log('MONHWND: WM_INPUT %d,%d',[ri.mouse.lLastX, ri.mouse.lLastY]);
                      end;
                    end;
                  end;
                end;
              end
            except
              on e:exception do
                log(e, 'MONLOOP')
            end;
          end
          , pchar('Monitor')
          , HWND_MESSAGE
          );
        result := true;

        AssertWin32(GetRawInputAPIS, 'GetRawInputAPIS', true);

        var rid: RAWINPUTDEVICE;
        rid.usUsagePage := HID_USAGE_PAGE_GENERIC;
        rid.usUsage := HID_USAGE_GENERIC_MOUSE;
        rid.dwFlags :=  RIDEV_INPUTSINK;
        rid.hwndTarget := MonHWND.HWND;
        AssertWin32(RegisterRawINputDevices(@rid, 1, sizeof(rid)), 'Registering rawinputdevice', true);

        ResetMonDefs(InitMonitors(false));

        Log('Starting hook..');
        if moCBTHook in Opts then
          AssertWin32(StartCBTHook, 'StartCBTHook', true);

        if moMouseHook in Opts then
          AssertWin32(StartMouseHook, 'StartMouseHook', true);
          ;

        if moLLMouseHook in Opts then
          AssertWin32(StartLLMouseHook
            (Function(
              code: Integer; wparam: WPARAM; MouseInfo:PLLMouseHookStruct
            ):boolean
            begin
              result := true;
              if TMonitor.TryEnter(MsgPump) then
              try
                case wparam of
                  WM_LBUTTONDOWN:
                    log(lpVerbose, 'LLMOUSE: WM_LBUTTONDOWN');
                  WM_LBUTTONUP:
                    log(lpVerbose, 'LLMOUSE: WM_LBUTTONUP');
                  WM_MOUSEMOVE:
                  with mouseinfo^ do
                  begin
                    var monIndex:integer;
                    var deskpt,monpt,sclpt,normPt:TPoint;
                    var polarpt:TPointf;
                    var monDef:TMonitorDef;
                    if pt.FromMousePtToMonPt(
                      MonDefs
                      , monIndex
                      , deskpt
                      , monpt
                      , sclpt
                      , normPt
                      , polarpt
                      , monDef) then
                    begin
                      var foundWin:TPortalWindow := nil;
                      var foundIndex := 0;
                      for var win in MonMasks do
                        if win.Rect.Contains(deskpt) then
                        begin
                          foundWin := win;
                          break
                        end
                        else
                          inc(foundIndex);
                      if assigned(foundWin) then
                      begin
                        if (nextIndex <> foundIndex) then
                        begin
                          log(lpInfo,'%d -> %d',[foundIndex,(foundIndex+1) mod MonMasks.Count]);
                          nextIndex := (foundIndex+1) mod MonMasks.Count;
                          sclpt.SetLocation(
                            sclpt.X
                              -(MonMasks[foundIndex].Rect.Left-MonMasks[foundIndex].Mon.orig.x)
                              +(MonMasks[nextIndex].Rect.Left-MonMasks[nextIndex].Mon.orig.x)
                            , sclpt.Y
                              -(MonMasks[foundIndex].Rect.Top-MonMasks[foundIndex].Mon.orig.y)
                              +(MonMasks[nextIndex].Rect.Top-MonMasks[nextIndex].Mon.orig.y)
                            );
                          PendingMove.MoveTo(
                            MonMasks[nextIndex].Mon
                            , sclpt.FromScaledtoMon(MonMasks[nextIndex].Mon));// double(-0.25), double(0.25));
                          PostMessage(MonHWND.HWND, WM_MOVEMOUSE, 0, 0);
                        end
                        else
                          log(lpVerbose,foundWin.Mon.monname);
                      end
                      else
                      begin
                        nextIndex := -1;
                        log(lpDebug,'HOOK: %d %d -> mon:%d,%d scale:%d,%d desk:%d,%d norm:%d,%d polar:%.2f,%.2f mon(#%d %d,%d %d,%d)',[
                          pt.x, pt.y
                          , monpt.x, monpt.Y
                          , sclpt.X, sclpt.y
                          , deskpt.X, deskpt.Y
                          , normpt.x, normpt.y
                          , polarpt.x, polarpt.Y
                          , monIndex
                          , mondef.orig.x, mondef.orig.y, mondef.size.width, mondef.size.height
                          ]);
                      end;
                    end
                    else
                      log(lpVerbose,'LLMOUSE: WM_MOUSEMOVE %d %d (%X)',[
                        pt.X
                        , pt.Y
                        , flags
                        ]);
                  end;
                  WM_MOUSEWHEEL:
                    log(lpVerbose,'LLMOUSE: WM_MOUSEWHEEL');
                  WM_MOUSEHWHEEL:
                    log(lpVerbose,'LLMOUSE: WM_MOUSEHWHEEL');
                  WM_RBUTTONDOWN:
                    log(lpVerbose,'LLMOUSE: WM_RBUTTONDOWN');
                  WM_RBUTTONUP:
                    log(lpVerbose,'LLMOUSE: WM_RBUTTONUP');
                end;
              finally
                TMonitor.Exit(MsgPump)
              end;

            end)
            , 'StartLLMouseHook', true);
      except
        on e:exception do
          log(e, 'Start hook..')
      end;
    end;
  if moAddMessagePump in Opts then
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
//        EndLLMouseHook;
        MonHWND.free
      end)
  else
  begin
    MsgPump := TObject.create;
    var rslt:boolean := monLoop()
  end;
//  TMonitorWindow.CreateMonitorWindow(ACancel);
end;

var
  client:uint8;

initialization
//  InitAPI(client)
end.
