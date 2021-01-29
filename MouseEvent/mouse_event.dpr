program mouse_event;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.windows,
  Winapi.messages,
  System.Types,
  System.SysUtils,
  System.RegularExpressions,
  System.SyncObjs,
  uEventLib in '..\lib\uEventLib.pas',
  uMonLIb in '..\lib\uMonLIb.pas',
  uMonitorLib in '..\lib\uMonitorLib.pas',
  uHWNDLib in '..\lib\uHWNDLib.pas',
  HidUsage in '..\lib\HidUsage.pas',
  CnRawInput in '..\lib\CnRawInput.pas',
  uLoggerLib in '..\lib\uLoggerLib.pas',
  uMouseHookLib in '..\lib\uMouseHookLib.pas';

begin
  try
    var monDefs := initMonitors(false);
    var mouse:TInputEvent;
    if ParamCount >= 2 then
    begin
      var monIndex := -1;
      if (ParamCount > 2) then
        monIndex := StrToInt(ParamStr(3));

      var fx:extended;
      var dx:integer;

      if TRegEx.IsMatch(ParamStr(1), '\d+\.\d+') and TryStrToFloat(paramstr(1), fx) then
      begin
        var fy := StrToFloat(paramstr(2));
        if monIndex = -1 then
          mouse.MoveTo(fx, fy)
        else
          mouse.MoveTo(monDefs[monIndex], fx, fy);
        mouse.Emit;
        mouse.Emit
      end
      else
      if TryStrToInt(paramstr(1), dx) then
      begin
//        var dx:dword := x;
        var dy:integer := StrToInt(paramstr(2));
        if monIndex = -1 then
          mouse.MoveTo(dx, dy)
        else
          mouse.MoveTo(monDefs[monIndex], dx, dy);
        mouse.Emit;
        mouse.Emit
      end;
    end
    else
    if ParamCount = 1 then
    begin
      var ADone := TEvent.create;
      try
        if ParamStr(1)='HIDEMOUSE' then
        begin
          writeln(ShowCursor(false));
          readln;
          ShowCursor(TRUE);
        end
        else
        if ParamStr(1)='HOOK' then
        begin
          StartMouseMonitor(ADone, true);
          readln
        end
        else
        if ParamStr(1)='MOUSE' then
        begin
          var deskpt, mousept, monpt, sclpt, normpt:TPoint;
          var monIndex:integer;
          var polarpt:TPointF;
          var monDef:TMonitorDef;

          if GetCursorPos(deskpt) and deskpt.FromDeskPtToMonPt(
            InitMonitors(true)
//            , deskpt.X, deskpt.Y
            , monIndex
            , mousept
            , monpt
            , sclpt
            , normpt
            , polarpt
            , monDef) then
          begin
            writeln(format('%d %d -> mouse:%d,%d mon:%d,%d scl:%d,%d norm:%d,%d polar:%.2f,%.2f mon(#%d %d,%d %d,%d)',[
              deskpt.x, deskpt.y
              , mousept.x, mousept.Y
              , monpt.x, monpt.y
              , sclpt.X, sclpt.Y
              , normpt.X, normpt.Y
              , polarpt.x, polarpt.Y
              , monIndex
              , mondef.orig.x, mondef.orig.y, mondef.size.width, mondef.size.height
              ]));
          end
          else
            writeln(format('%d %d',[
              deskpt.x, deskpt.y
              ]));
        end;
      finally
        ADone.SetEvent
      end;
    end
    else
    begin
      PrintMonDefs(monDefs)
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  writeln('Done');
  if DebugHook <> 0 then
    readln
end.
