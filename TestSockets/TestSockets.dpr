program TestSockets;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  IdUDPServer,
  dProtocol in '..\lib\dProtocol.pas' {Proto: TDataModule};

begin
  try
    var dm := TdmMain.Create(nil);
    dm.IdUDPServer1.DefaultPort := 8111;
    dm.IdUDPClient1.BoundPort := 8111;
    dm.IdUDPServer1.BroadcastEnabled := true;
    dm.IdUDPClient1.BroadcastEnabled := true;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
