unit uController;

interface

uses
  uCommandLineOptions
//  , dProtocol
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
//    property MachineName:string read GetMachineName write fMachineName;
  end;

  TDispatchController = class(TCustomController)
  protected
    fOpts:TCmdOptions;
    class var fInstance:TDispatchController;
  public
    constructor create;

    function Start: boolean; override;

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
  ;

constructor TDispatchController.create;
begin
  fOpts := TCmdOptions.create;

  fOpts
    .Add('HOOK', [cosCmd])
      .BeginSubCmd
      .Add('MOUSEMOVE',[cosCmd])
      .Add('KEYBD',[cosCmd])
      .EndSubCmd
    .Add('SERVER', [], '8989')
      .BeginSubCmd
//      .Add('ECHO', [], 'Hello')
//      .Add('LISTENINPUT', [cosCmd])
      .Add('LOG', [cosCmd], '')
      .Add('SENDINPUT', [cosCmd])
        .BeginSubCmd
        .Add('SENDSTRING', [], '15,0|-15,15|-15,-15|15,-15|15,15')
        .Add('SENDHOOKINPUT', [cosCmd])
        .EndSubCmd
      .EndSubCmd
    .Add('CLIENT', [cosCmd])
      .BeginSubCmd
      .Add('PORT', [cosRequired], '8989', 'Protocol Port')
      .Add('HOST', [cosRequired])
//      .Add('ECHO', [], 'Hello')
      .Add('LOG', [cosCmd], 'Started')
      .Add('LISTENINPUT', [cosCmd])
//      .Add('SENDINPUT', [], '15,0|-15,15|-15,-15|15,-15|15,15')
//      .Add('SENDHOOKINPUT', [cosCmd], '')
      .EndSubCmd
    .Add('INPUT', [], '15,0|-15,15|-15,-15|15,-15|15,15')
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
//  with TProto.Instance do
//  begin
  result := inherited;
  try
    if fVals.Enabled['HOOK'] then
    begin
      TLLMouseHook.Instance.Start
    end;

    if fVals.Enabled['SERVER'] then
    with fVals['SERVER'] do
    begin
//          StartServer(cancel, fVals['SERVER'],
      if Enabled['SENDINPUT'] then
        THookInputServerController.create(Self, Option['SENDINPUT'], 'SENDINPUT');

      TProto.Instance.StartServer(nil, fVals['SERVER'])
    end
    else
    if fVals.Enabled['CLIENT'] then
    with fVals['CLIENT'] do
    begin
      if Enabled['LISTENINPUT'] then
        THookInputClientController.create(Self, Option['LISTENINPUT'], 'LISTENINPUT', Option['PORT'].asInteger, Option['HOST'].Value)
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

  except
    on e:exception do
    begin
      stop;
      raise
    end
  end
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
  fStarted.ResetEvent;
  result := true
end;

end.
