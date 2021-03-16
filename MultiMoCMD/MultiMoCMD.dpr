program MultiMoCMD;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  winapi.windows,
  System.SysUtils,
  System.SyncObjs,
  System.StrUtils,
  System.threading,
  dProtocol in '..\lib\dProtocol.pas' {Proto: TDataModule},
  uLoggerLib in '..\lib\uLoggerLib.pas',
  uCommandLineOptions in '..\lib\uCommandLineOptions.pas',
  uConsoleLogger in '..\lib\uConsoleLogger.pas',
  uSendInput in '..\lib\uSendInput.pas',
  uLLHookLib in '..\lib\uLLHookLib.pas',
  uController in '..\lib\uController.pas';

begin
  try
    SetLogger(TConsoleLogger.create('MULTIMO'));
    log('Logger started..');

    TCustomController.Instance.Start

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  Writeln('Done');
  readln
end.
