program MultiMoCLI;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Threading,
  System.SyncObjs,
  System.Types,
  IdTCPConnection,
  IdGlobal,
  uAPILogServer in '..\lib\uAPILogServer.pas',
  uShareLib in '..\lib\uShareLib.pas',
  uAPILogClient in '..\lib\uAPILogClient.pas',
  uMonitorLib in '..\lib\uMonitorLib.pas',
  dProtocol in '..\lib\dProtocol.pas' {Proto: TDataModule},
  uMonLIb in '..\lib\uMonLIb.pas',
  uServerProtocol in '..\lib\uServerProtocol.pas',
  uHWNDLib in '..\lib\uHWNDLib.pas',
  uIdLib in '..\lib\uIdLib.pas',
  CnRawInput in '..\lib\CnRawInput.pas',
  uEventLib in '..\lib\uEventLib.pas',
  HidUsage in '..\lib\HidUsage.pas',
  uLoggerLib in '..\lib\uLoggerLib.pas',
  uAPILib in '..\lib\uAPILib.pas',
  uMouseHookLib in '..\lib\uMouseHookLib.pas',
  uPortalWin in '..\lib\uPortalWin.pas',
  uConsoleLogger in '..\lib\uConsoleLogger.pas';

var
  ACount:uint8;
  ADone:TEvent;

begin
  try
    if not InitAPI(ACount) then
      exit;

    InitShareLog('MultiMoCLI');
    SetLogger(
      TConsoleLogger.create(
//        TThreadPool.Default,
//        function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
//        begin
//          writeln(ALogMsg);
//          SLog^.log(ALogMsg);
//          result := AMsg
//        end
        'MULTIMOCLI'
        , true
        , lpDebug
        , lpDebug
      ));
    ADone := TEvent.Create(nil, true, false, '');

    if (ParamCount > 0) then
      if (ParamStr(1)='LOGGER') then
      begin
        if ParamCount > 1 then
        begin
          if ParamStr(2)='TEST' then
          begin
            var loops := 100;
            if ParamCount > 2 then
              loops := StrToInt(ParamStr(3));
            for var i := 0 to loops do
              log('TEST %d',[i]);
          end
        end
        else
        begin
          SetLogger(
            TAsyncLogger.create(
              TThreadPool.Default
              , function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
              begin
                writeln(AMsg);
                result := AMsg
              end
              , 'MULTIMOCLI'
              , lpInfo
            ));
          _StartAPILogServer(SLog, ADone);
          log('LOGGER');
          TThreadPool.Default.QueueWorkItem(
            procedure
            begin
              var readCnt := 0;
              try
                while ADone.WaitFor(0)<>TWaitResult.wrSignaled do
                begin
                  var rslt := _ReadLog(SLog, INFINITE, ADone,
                    function (ALogHdr:PLogHeader;AMsg:string):boolean
                    begin
                      inc(readCnt);
                      writeln(format('r#:%5d/%5d %s',[readcnt,ALogHdr.logcnt,AMsg]));
                      result := true
                    end);
                  rslt := not rslt;
                end
              except
                on e:exception do
                  log(e, 'LOGGER loop')
              end;
              log('LOGGER DONE');
              StopAPILogServer
            end);
          readln
        end
      end
      else
      if ParamStr(1)='HIDEMOUSE' then
      begin
//        log(
          ShowCursor(false)
//          )
          ;
        readln;
        ShowCursor(TRUE);
      end
      else
      if ParamStr(1)='HOOK' then
      begin
        StartMonitor(ADone, [moAddMessagePump
          , moLLMouseHook
//          , moMouseHook
//          , moCBTHook
          ]);
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
          log('%d %d -> mouse:%d,%d mon:%d,%d scl:%d,%d norm:%d,%d polar:%.2f,%.2f mon(#%d %d,%d %d,%d)',[
            deskpt.x, deskpt.y
            , mousept.x, mousept.Y
            , monpt.x, monpt.y
            , sclpt.X, sclpt.Y
            , normpt.X, normpt.Y
            , polarpt.x, polarpt.Y
            , monIndex
            , mondef.orig.x, mondef.orig.y, mondef.size.width, mondef.size.height
            ]);
        end
        else
          log('%d %d',[
            deskpt.x, deskpt.y
            ]);
      end
      else
      if (ParamStr(1)='CLIENT') then
      begin
        TProto.Instance.StartClient(ParamStr(2),StrToInt(ParamStr(3)),ADone);

        if (ParamCount > 3) then
        begin
          var currParam := 4;
          while currParam <= ParamCount do
          begin
            var ACommand := ParamStr(currParam);
//            if ACommand = 'TEST' then
//              TProto.Instance.Send(
//                'TEST'
//                , function(AConnection:TIdTCPConnection):integer
//                begin
//                  result := 200;
//                  AConnection.IOHandler.log('TEST MESSAGE');
//                  log(format('TEST: > %s',['TEST MESSAGE']));
//                  var resply := AConnection.IOHandler.ReadLn();
//                  log(format('TEST: < %s',[resply]));
//
//                  var i:UInt16;
//                  for i := 1 to 100 do
//                  begin
//                    log(format('TEST: > %d',[i]));
//                    AConnection.IOHandler.Write(i);
//                  end;
//
//                  repeat
//                    i := AConnection.IOHandler.ReadUInt16();
//                    log(format('TEST: < %d',[i]));
//                  until i >= 100;
//
//                  var msg:string;
//                  repeat
//                    msg := AConnection.IOHandler.ReadLn;
//                    log(format('TEST: < %s',[msg]));
//                  until msg = 'DONE2';
//
//                  repeat
//                    log('?');
//                    readln(msg);
//                    AConnection.IOHandler.log(msg);
//                    log(format('TEST: > %s',[msg]));
//                  until msg = 'DONE';
//                end);
            if ACommand = 'MOUSE' then
              TProto.Instance.Send(
                'MOUSE'
                , function(AConnection:TIdTCPConnection):integer
                begin
                  result := 200;
                  var monDefs := InitMonitors(true);
                  var monDefsBuffer:TIdBytes := RawtoBytes(monDefs[0], length(monDefs) * sizeof(TMonitorDef));
                  log('MOUSE: > monDefs %d',[length(monDefsBuffer)]);
                  AConnection.IOHandler.Write(UInt32(length(monDefsBuffer)));
                  AConnection.IOHandler.Write(monDefsBuffer, length(monDefsBuffer));
                  var response := AConnection.GetResponse(200);
                  log('MOUSE: < %s',[AConnection.LastCmdResult.FormattedReply.Text]);

                  var AInputEvent:TInputEvent;
                  repeat
                    log('MOUSE: ? InputEvent');
                    AConnection.IOHandler.ReadEvent(AInputEvent);
                    log('MOUSE: < (%d) %d,%d',[ord(AInputEvent.event),AInputEvent.dx,AInputEvent.dy]);
                    case AInputEvent.event of
                      tiMouse:
                        AInputEvent.Emit;
                      tiNull:
                        break;
                    end;
                  until false
                end);
            if ACommand = 'ECHO' then
              TProto.Instance.Send(
                'ECHO2'
                , function(AConnection:TIdTCPConnection):integer
                begin
                  result := 200;
                  inc(currParam);
                  ACommand := ParamStr(currParam);
                  log('ECHO: > %s',[ACommand]);
                  AConnection.IOHandler.writeln(ACommand);
                  var response := AConnection.GetResponse(200);
                  log('ECHO: %s',[AConnection.LastCmdResult.FormattedReply.Text]);
                  ACommand := AConnection.IOHandler.ReadLn;
                  log('ECHO: < %s',[ACommand]);
                end);
            inc(currParam)
          end
        end
      end
      else
      if (ParamStr(1)='SERVER') then
      begin
        if ParamCount = 1 then
          StartServer(ADone, 8111)
        else
          StartServer(ADone, StrToIntDef(ParamStr(2),8111))
      end
      else
      if (ParamStr(1)='BROADCAST') then
      begin
        if ParamCount = 1 then
          TProto.Instance.Broadcast('TEST BROADCAST', 8111)
        else
          TProto.Instance.Broadcast('TEST BROADCAST', StrToIntDef(ParamStr(2),8111));
        ADone.WaitFor(INFINITE)
      end
  except
    on E: Exception do
    begin
      log(e, 'MultiMoCLI');
      readln
    end
  end;
  log('DONE');
//  if DebugHook <> 0 then
  readln;
  ADone.SetEvent;
  CloseAPI;
end.
