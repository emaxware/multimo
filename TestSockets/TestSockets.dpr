program TestSockets;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  IdUDPServer,
  dProtocol in '..\lib\dProtocol.pas' {Proto: TDataModule},
  uLoggerLib in '..\lib\uLoggerLib.pas';

begin
  try
    var dm := TProto.Create(nil);
    dm.cmdTcpServer.DefaultPort := 8111;
    dm.cmdTcpClient.BoundPort := 8111;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
