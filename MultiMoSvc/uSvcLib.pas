unit uSvcLib;

interface

uses
  Winapi.Windows
  , Winapi.Messages
  , System.SysUtils
  , System.Classes
  , Vcl.Graphics
  , Vcl.Controls
  , Vcl.SvcMgr
  , Vcl.Dialogs
  , System.Threading
  , System.SyncObjs
  , unitDebugService
  ;

type
  TsvcMultiMo = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceExecute(Sender: TService);
  private
    { Private declarations }
    FDone:TEvent;
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  svcMultiMo: TsvcMultiMo;

implementation

{$R *.dfm}

uses
  uLoggerLib
  , uAPILib
  , uAPILogClient
//  , uMonitorLib
//  , uMouseHookLib
  ;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  svcMultiMo.Controller(CtrlCode);
end;

function TsvcMultiMo.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TsvcMultiMo.ServiceExecute(Sender: TService);
begin
  try
    Log('Hook starting..');
//    StartMonitor(FDone, [moLLMouseHook, moMouseHook, moCBTHook]);
    FDone.WaitFor(INFINITE);
    Log('Hook stopping..');
//    EndLLMouseHook
  except
    on e:exception do
      Log(e, 'Hook')
  end;
end;

procedure TsvcMultiMo.ServiceStart(Sender: TService; var Started: Boolean);
begin
  InitShareLog('MultiMoCLI');

  var ACount:byte := 0;
  if not InitAPI(ACount) then
    exit;

  SetLogger(
    TSimpleLogger.create(
//        TThreadPool.Default,
      function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
      begin
//        writeln(ALogMsg);
        SLog^.log(ALogMsg);
        result := ALogMsg
      end
      , 'MULTIMOSVC'
    ));

  FDone := TSimpleEvent.Create(nil, true, false, '');
  Log('Service starting..');
  Started := true
end;

procedure TsvcMultiMo.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  FDone.SetEvent;
  Stopped := true
end;

end.
