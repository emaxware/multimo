unit uController;

interface

uses
  uCommandLineOptions
  , dProtocol
  ;

type
  TCustomController = class;

  TCustomController = class
  protected
    fOpts:TCmdOptions;
    fVals:TCmdValue;
    class var fInstance:TCustomController;
    constructor create;
  public
    class function Instance:TCustomController;

    function Start: boolean;
//    property MachineName:string read GetMachineName write fMachineName;
  end;

implementation

uses
  winapi.Windows
  , winapi.Messages
  , system.UITypes
  , System.SysUtils
  , IdIOHandler
  , IdGlobal
  , uLoggerLib
  , uLLHookLib
  , uSendInput
  ;

//var
//  cancel:TEvent;
constructor TCustomController.create;
begin

//  cancel := TEvent.create(False);

  fOpts := TCmdOptions.create;

  fOpts
    .Add('HOOK', [cosCmd])
      .BeginSubCmd
      .Add('MOUSEMOVE',[cosCmd])
      .Add('KEYBD',[cosCmd])
      .EndSubCmd
    .Add('SERVER', [], '8989')
      .BeginSubCmd
      .Add('ECHO', [], 'Hello')
      .Add('LISTENINPUT', [cosCmd])
      .Add('SENDINPUT', [], '15,0|-15,15|-15,-15|15,-15|15,15')
      .Add('SENDHOOKINPUT', [cosCmd], '')
      .EndSubCmd
    .Add('CLIENT', [cosCmd])
      .BeginSubCmd
      .Add('PORT', [cosRequired], '8989', 'Protocol Port')
      .Add('HOST', [cosRequired])
      .Add('ECHO', [], 'Hello')
      .Add('LISTENINPUT', [cosCmd])
      .Add('SENDINPUT', [], '15,0|-15,15|-15,-15|15,-15|15,15')
      .Add('SENDHOOKINPUT', [cosCmd], '')
      .EndSubCmd
    .Add('INPUT', [], '15,0|-15,15|-15,-15|15,-15|15,15')
    ;

  fOpts.ParseCommandLine(fVals, TCmdOption.ConsoleOptionHandler())
end;

class function TCustomController.Instance: TCustomController;
begin
  if TCustomController.fInstance = nil then
    TCustomController.fInstance := TCustomController.create;
  result := TCustomController.fInstance
end;

function TCustomController.Start:boolean;
begin
  with TProto.Instance do
  try
    if fVals.Enabled['HOOK'] then
    begin
      TLLMouseHook.Instance.Start
    end;

    if fVals.Enabled['SERVER'] then
    with fVals['SERVER'] do
    begin
//          StartServer(cancel, fVals['SERVER'],
      if Enabled['SENDHOOKINPUT'] then
        AddServerCmd('SENDHOOKINPUT',
          procedure(AIO:TIdIOHandler)
          begin
            var sizeTInput := SizeOf(TInput);
            var inps := TSendInputHelper.Create;
            var i := TLLMouseHook.Instance.AddListener(
              procedure(AHookData:TLLMouseHookData)
              begin
                inps.Clear;
                case AHookData.wParam of
                  WM_RBUTTONUP:
                  begin
                    inps.AddAbsoluteMouseMove(AHookData.data.pt.X, AHookData.data.pt.Y);
                    inps.AddMouseClick(TMouseButton.mbRight);
                  end;
                  WM_LBUTTONUP:
                  begin
                    inps.AddAbsoluteMouseMove(AHookData.data.pt.X, AHookData.data.pt.Y);
                    inps.AddMouseClick(TMouseButton.mbLeft);
                  end;
                  WM_MOUSEMOVE:
                  begin
                    inps.AddAbsoluteMouseMove(AHookData.data.pt.X, AHookData.data.pt.Y);
                  end;
                end;

                for var inp in inps do
                begin
                  AIO.WriteLn('>>');
                  AIO.Write(RawToBytes(inp, sizeTInput), sizeTInput);
                end;

                AIO.WriteLn('sent');
              end);

            var msg:string;
            try
              repeat
                msg := AIO.ReadLn;
              until msg <> 'rcvd';
            finally
              TLLMouseHook.Instance.RemoveListener(i)
            end
          end)
    end
    else
    if fVals.Enabled['CLIENT'] then
    with fVals['CLIENT'] do
    begin
      AddClientListener('LISTENINPUT',
        Option['PORT'].asInteger,
        Option['HOST'].Value,
        procedure(AThread:TListenerThread)
        begin
          var sizeTInput := SizeOf(TInput);
          var inps := TSendInputHelper.Create;
          var reply := AThread.Client.SendCmd('SENDHOOKINPUT', '');
          system.writeln(AThread.Client.LastCmdResult.Text.Text);

          repeat
            var msg := AThread.Client.IOHandler.ReadLn();
            if msg='>>' then
            begin
              var data:TIdBytes;
              AThread.Client.IOHandler.ReadBytes(data, sizeTInput);
              inps.Add(PInput(@data[0])^);
              continue;
            end;
            if msg='sent' then
            begin

              break
            end;
            raise Exception.CreateFmt('Unexpected token "%s"',[msg]);
          until false;
        end)


//          StartClient(cancel, fVals['CLIENT'])
    end;

    if fVals.Enabled['MOUSEMOVE'] then
    begin
      var ih := TSendInputHelper.create;
      try
//            ih.AddDelay(10000);
        ih.AddMouseMoves(fVals['MOUSEMOVE'].asArray('|'));
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
    fVals.free
  end
end;

end.
