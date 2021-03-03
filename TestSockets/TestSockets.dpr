program TestSockets;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.SyncObjs,
  dProtocol in '..\lib\dProtocol.pas' {Proto: TDataModule},
  uLoggerLib in '..\lib\uLoggerLib.pas',
  uCommandLineOptions in '..\lib\uCommandLineOptions.pas',
  uConsoleLogger in '..\lib\uConsoleLogger.pas';

var
  opts:TCmdOptions;
  vals:TCmdValue;
  cancel:TEvent;

begin
  SetLogger(TConsoleLogger.create('TESTSOCKETS'));
  cancel := TEvent.create(False);

  opts := TCmdOptions.create;
  opts
    .Add('PORT','p', [cosRequired], '8989', 'Protocol Port')
    .Add('SERVER', 'S', [cosIsFlag])
    .Add('CLIENT', 'C', [cosIsFlag])
      .Add('HOST', 'H', [cosChild,cosRequired]);

  try
    if opts.ParseCommandLine(vals, TCmdOption.ConsoleOptionHandler()) then
    with TProto.Instance do
    try
      if vals.Enabled['SERVER'] then
        StartServer(cancel, vals['PORT'].asInteger)
      else
      if vals.Enabled['CLIENT'] then
      begin
        StartClient(vals['CLIENT']['HOST'].Value, vals['PORT'].asInteger, cancel);
        SendEcho('Hello');
      end;
      readln;
      stop
    finally
      free;
      vals.free
    end
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  Writeln('Done');
  readln
end.
