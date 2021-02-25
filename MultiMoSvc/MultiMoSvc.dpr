program MultiMoSvc;

uses
  Vcl.SvcMgr,
  uSvcLib in 'uSvcLib.pas' {svcMultiMo: TService},
  uLoggerLib in '..\lib\uLoggerLib.pas',
  uShareLib in '..\lib\uShareLib.pas',
  uAPILogClient in '..\lib\uAPILogClient.pas',
  uAPILib in '..\lib\uAPILib.pas',
  unitDebugService in '..\..\hcUpdateFramework\NTLowLevel100\Source\unitDebugService.pas',
  uConsoleLogger in '..\lib\uConsoleLogger.pas';

{$R *.RES}

begin
  // Windows 2003 Server requires StartServiceCtrlDispatcher to be
  // called before CoRegisterClassObject, which can be called indirectly
  // by Application.Initialize. TServiceApplication.DelayInitialize allows
  // Application.Initialize to be called from TService.Main (after
  // StartServiceCtrlDispatcher has been called).
  //
  // Delayed initialization of the Application object may affect
  // events which then occur prior to initialization, such as
  // TService.OnCreate. It is only recommended if the ServiceApplication
  // registers a class object with OLE and is intended for use with
  // Windows 2003 Server.
  //
  // Application.DelayInitialize := True;
  //

  if (ParamCount > 0) and (ParamStr(1)='DEBUG') then
  begin
    SetLogger(TConsoleLogger.create('MMSVC'));
    Application.Free;
    Application := TDebugServiceApplication.Create(nil);
  end;

  if not Application.DelayInitialize or Application.Installing then
    Application.Initialize;
  Application.CreateForm(TsvcMultiMo, svcMultiMo);
  Application.Run;
end.
