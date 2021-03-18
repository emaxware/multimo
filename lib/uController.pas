unit uController;

interface

uses
  uCommandLineOptions
  , system.SyncObjs
  ;

type
  TCustomController = class;

  TCustomController = class
  protected
    fVals:TCmdValue;
    fParent:TCustomController;
    fStarted:TSimpleEvent;
  public
    constructor create(
      AController:TCustomController;
      AValues:TCmdValue
    ); virtual;

    function Start: boolean; virtual;
    function Stop: boolean; virtual;

    function Started:boolean; virtual;
  end;

  TDispatchController = class(TCustomController)
  protected
    fOpts:TCmdOptions;
    fHookLogListener:integer;
    class var fInstance:TDispatchController;
  public
    constructor create; reintroduce;

    function Start: boolean; override;
    function Stop:boolean; override;

    class function Instance:TDispatchController;
  end;

implementation

uses
  winapi.Windows
  , winapi.Messages
  , system.UITypes
  , System.SysUtils
  , IdIOHandler
  , IdGlobal
  , dProtocol
  , uLoggerLib
  , uLLHookLib
  , uSendInput
  , uHookInputController
  , uLogController
  ;

constructor TDispatchController.create;
begin
  fOpts := TCmdOptions.create;

  fOpts
    .Add('HOOK', [cosCmd])
      .BeginSubCmd
      .Add('MOUSE',[cosCmd])
      .Add('KEYBD',[cosCmd])
      .Add('LOG',[cosCmd])
      .EndSubCmd
    .Add('SERVER', [], '8989')
      .BeginSubCmd
//      .Add('ECHO', [], 'Hello')
//      .Add('LISTENINPUT', [cosCmd])
      .Add('LISTENLOG', [cosCmd], '')
      .Add('SENDINPUT', [cosCmd])
        .BeginSubCmd
        .Add('SENDSTRING', [], '15,0|-15,15|-15,-15|15,-15|15,15')
        .Add('MOUSEINPUT', [cosCmd])
        .Add('KBDINPUT', [cosCmd])
        .EndSubCmd
      .EndSubCmd
    .Add('CLIENT', [cosCmd])
      .BeginSubCmd
      .Add('PORT', [cosRequired], '8989', 'Protocol Port')
      .Add('HOST', [cosRequired])
//      .Add('ECHO', [], 'Hello')
      .Add('SENDLOG', [cosCmd], 'Started')
      .Add('LISTENINPUT', [cosCmd])
//      .Add('SENDINPUT', [], '15,0|-15,15|-15,-15|15,-15|15,15')
//      .Add('SENDHOOKINPUT', [cosCmd], '')
      .EndSubCmd
    .Add('SENDINPUT', [], '15,0|-15,15|-15,-15|15,-15|15,15')
    ;

  var AVals:TCmdValue;
  if fOpts.ParseCommandLine(AVals, TCmdOption.ConsoleOptionHandler()) then
    inherited create(nil, AVals)
  else
    raise Exception.Create('Error Message');
end;

class function TDispatchController.Instance: TDispatchController;
begin
  if TDispatchController.fInstance = nil then
    TDispatchController.fInstance := TDispatchController.create;
  result := TDispatchController.fInstance
end;

function TDispatchController.Start:boolean;
begin
  result := inherited;
  try
    if fVals.Enabled['HOOK'] then
    with fVals['HOOK'] do
    begin
      if Enabled['MOUSE'] then
        TLLMouseHook.Instance.Start;
      if Enabled['KEYBD'] then
        TLLKbdHook.Instance.Start;
      if Enabled['LOG'] then
      begin
        TLLMouseHook.Instance.AddListener(
          procedure(AHookData:TLLMouseHookData)
          begin
            if AHookData.wparam <> WM_MOUSEMOVE then
              log(AHookData.ToString);
          end);
        TLLKbdHook.Instance.AddListener(
          procedure(AHookData:TLLKbdHookData)
          begin
            log(AHookData.ToString);
          end);
      end;
    end;

    if fVals.Enabled['SERVER'] then
    with fVals['SERVER'] do
    begin
      if Enabled['SENDINPUT'] then
        THookInputServerController.create(Self, Option['SENDINPUT'], 'SENDINPUT').Start;

      if Enabled['LISTENLOG'] then
        TLogServerController.create(Self, Option['LISTENLOG'], 'LISTENLOG').Start;

      TProto.Instance.StartServer(nil, fVals['SERVER'])
    end
    else
    if fVals.Enabled['CLIENT'] then
    with fVals['CLIENT'] do
    begin
      if Enabled['LISTENINPUT'] then
        THookInputClientController.create(Self, Option['LISTENINPUT'], 'SENDINPUT', Option['PORT'].asInteger, Option['HOST'].Value).Start;

      if Enabled['SENDLOG'] then
        with TLogClientController.create(Self, Option['SENDLOG'], 'LISTENLOG', Option['PORT'].asInteger, Option['HOST'].Value) do
        begin
          Start;
          for var i := 0 to 100 do
            Logger.DefLogFmt('This is test #%d',[i])
        end;
    end;

    if fVals.Enabled['SENDINPUT'] then
    begin
      var ih := TSendInputHelper.create;
      try
//            ih.AddDelay(10000);
        ih.AddMouseMoves(fVals['SENDINPUT'].asArray('|'));
        ih.Flush
      finally
        ih.free
      end
    end;

  except
    on e:exception do
    begin
      stop;
      raise
    end
  end
end;

function TDispatchController.Stop: boolean;
begin
  result := inherited stop;
  if result then
  begin
    TLLMouseHook.Instance.Terminate;
    TLLKbdHook.Instance.Terminate;
  end;
end;

{ TCustomController }

constructor TCustomController.create(AController: TCustomController;
  AValues: TCmdValue);
begin
  fVals := AValues;
  fParent := AController;
  fStarted := TSimpleEvent.Create
end;

function TCustomController.Start: boolean;
begin
  fStarted.SetEvent;
  result := true
end;

function TCustomController.Started: boolean;
begin
  result := fStarted.IsSet
end;

function TCustomController.Stop: boolean;
begin
  TProto.Instance.Stop;
  fStarted.ResetEvent;
  result := true
end;

end.
