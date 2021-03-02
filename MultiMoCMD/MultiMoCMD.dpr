program MultiMoCMD;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  dProtocol in '..\lib\dProtocol.pas' {Proto: TDataModule},
  uLoggerLib in '..\lib\uLoggerLib.pas',
  uConsoleLogger in '..\lib\uConsoleLogger.pas';

begin
  try
    writeln('MultiMoCMD');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  readln
end.
