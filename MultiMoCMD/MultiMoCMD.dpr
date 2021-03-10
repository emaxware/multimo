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
  uLLHookLib in '..\lib\uLLHookLib.pas';

var
  opts:TCmdOptions = nil;
  vals:TCmdValue = nil;
  cancel:TEvent;

begin
  SetLogger(TConsoleLogger.create('MULTIMO'));
  log('Logger started..');

  cancel := TEvent.create(False);

  opts := TCmdOptions.create;
  try
    opts
      .Add('HOOK', [cosCmd])
        .BeginSubCmd
        .Add('MOUSEMOVE',[cosCmd])
        .Add('KEYBD',[cosCmd])
        .EndSubCmd
      .Add('SERVER', [], '8989')
//        .BeginSubCmd
//        .Add('PORT',[cosRequired], '8989')
//        .Add('SENDMOUSEMOVE', [], '15,0|-15,15|-15,-15|15,-15|15,15')
//        .EndSubCmd
      .Add('CLIENT', [cosCmd])
        .BeginSubCmd
        .Add('PORT', [cosRequired], '8989', 'Protocol Port')
        .Add('HOST', [cosRequired])
        .Add('ECHO', [], 'Hello')
        .Add('LISTENMOUSEMOVE', [cosCmd])
        .Add('SENDMOUSEMOVE', [], '15,0|-15,15|-15,-15|15,-15|15,15')
        .EndSubCmd
      .Add('MOUSEMOVE', [], '15,0|-15,15|-15,-15|15,-15|15,15')
      ;

    try
      if opts.ParseCommandLine(vals, TCmdOption.ConsoleOptionHandler()) then
      with TProto.Instance do
      try
        if vals.Enabled['HOOK'] then
        begin
          TLLMouseHook.Instance.Start
        end;

        if vals.Enabled['SERVER'] then
          StartServer(cancel, vals['SERVER'])
        else
        if vals.Enabled['CLIENT'] then
          StartClient(cancel, vals['CLIENT']);

        if vals.Enabled['MOUSEMOVE'] then
        begin
          var ih := TSendInputHelper.create;
          try
//            ih.AddDelay(10000);
            ih.AddMouseMoves(vals['MOUSEMOVE'].asArray('|'));
            ih.Flush
          finally
            ih.free
          end
        end;

        writeln('Press ENTER');
        readln;
        stop
      finally
        free;
        vals.free
      end
    finally
      opts.free
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  Writeln('Done');
  readln
end.
