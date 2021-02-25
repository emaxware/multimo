program LogTester;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Threading,
  System.SyncObjs,
//  JclSysUtils,
  System.IOUtils,
  JvCreateProcess,
  uLoggerLib in '..\lib\uLoggerLib.pas',
  uAPILogServer in '..\lib\uAPILogServer.pas',
  uAPILogClient in '..\lib\uAPILogClient.pas',
  uShareLib in '..\lib\uShareLib.pas',
  uConsoleLogger in '..\lib\uConsoleLogger.pas';

var
  ADone:TEvent;

begin
  try
    ADone := TEvent.Create(nil, true, false, '');

    if (ParamCount = 3) and InitShareLog(ParamStr(1), false) then
    begin
      var testCnt:integer;
      if TryStrToInt(ParamStr(2), testCnt) then
      begin
        SetLogger(
          TConsoleLogger.Create(
//          TAsyncLogger.create(
//            TThreadPool.Default,
//            function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
//            begin
//              writeln(AMsg);
//              result := AMsg
//            end,
            ParamStr(1)
            , true
            , lpDebug
            , lpDebug
          ));

        _StartAPILogServer(SLog, ADone);
        log('%s started',[ParamStr(1)]);

        TThreadPool.Default.QueueWorkItem(
          procedure
          begin
            var readCnt := 0;
            try
              while (ADone.WaitFor(0) <> TWaitResult.wrSignaled) do
              begin
                var rslt := _ReadLog(SLog, INFINITE, ADone,
                  function (ALogHdr:PLogHeader;AMsg:string):boolean
                  begin
                    inc(readCnt);
//                    writeln(AMsg);
                    writeln(format('r#:%5d/%5d %s',[readcnt,ALogHdr.logcnt,AMsg]));
//                    writeln(format('r#:%5d %s',[ALogHdr.logcnt,AMsg]));
                    result := true
                  end);
                rslt := not rslt;
              end
            except
              on e:exception do
                log(e, '%s loop',[ParamStr(1)])
            end;
            log('%s DONE',[ParamStr(1)]);
            StopAPILogServer;
            log('%s Stopped',[ParamStr(1)]);
          end);

        for var i := 1 to testCnt do
          with TJvCreateProcess.Create(nil) do
          try
            CommandLine :=
              format('cmd.exe /C "%s" %s %s%d %s',[
                ParamStr(0)
                , ParamStr(1)
                , ParamStr(1)
                , i
                , ParamStr(3)
                ]);

            StartupInfo.ShowWindow := swNormal;
            CreationFlags := [cfNewConsole];
            Run;
            StopWaiting
          finally
            free
          end;

        readln;
        ADone.SetEvent;

      end
      else
      begin
        testCnt := StrToIntDef(ParamStr(3), 1);

        SetLogger(
          TLoggerClient.create(
            ParamStr(2)
            , true
            , lpDebug
            , lpDebug
          ));

        for var i := 1 to testCnt do
        begin
          Log('Log %d',[i]);
          sleep(100)
        end
      end
    end
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  FlushLog;
  writeln('Done');
  Readln
end.
