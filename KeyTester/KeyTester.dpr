program KeyTester;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  SynCommons,
  SynTable,
  SynLog,
  mORMot,
  SynBidirSock,
  mORMotHttpServer,
  mORMotHttpClient,
  CallbackInterface in 'CallbackInterface.pas',
  uHttpMethod in 'uHttpMethod.pas',
  uCrtSockMethod in 'uCrtSockMethod.pas';

var
  mode, host:string;

begin
  with TSQLLog.Family do begin // enable logging to file and to console
    Level := LOG_VERBOSE;// [sllInfo, sllWarning, sllError];
    EchoToConsole := LOG_VERBOSE;
    PerThreadLog := ptIdentifiedInOnFile;
  end;
  WebSocketLog := TSQLLog; // verbose log of all WebSockets activity
  try
    if ParamCount > 0 then
      mode := ParamStr(1);

    if mode = '' then
    begin
      writeln('Run as :'#13#10'  [S] Server'#13#10'  [C] Client');
      readln(mode)
    end;

    if mode = 'S' then
//      RunHttpServer
      RunTcpServer('8989', TSQLLog)
    else
    if mode = 'C' then
    begin
      host := 'localhost';
      if ParamCount=2 then
        host := ParamStr(2);

      if host='localhost' then
      begin
        writeln('Enter host: ');
        readln(host)
      end;
      RunTcpClient(
        host
        , '8989'
        , TSQLLog)
    end;
//      RunHttpClient
  except
    on E: Exception do
      ConsoleShowFatalException(E);
  end;
  writeln('done')
end.
