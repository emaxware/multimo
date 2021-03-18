unit dProtocol;

{.$DEFINE  PROTO_TRACE}

interface

uses
  winapi.windows
  , System.SysUtils
  , System.Types
  , System.Classes
  , System.SyncObjs
  , IdContext
  , IdCustomTCPServer
  , IdTCPServer
  , IdCmdTCPServer
  , IdTCPConnection
  , IdTCPClient
  , IdServerInterceptLogEvent
  , IdIntercept
  , IdGlobal
  , IdServerInterceptLogBase
  , IdBaseComponent
  , IdComponent
  , IdIOHandler
  , IdCommandHandlers
  , uSendInput
  , uController
  , uCommandLineOptions
  ;

type
  TCmdHandler = reference to procedure(AIOHandler:TIdIOHandler);
  TInputSender = reference to procedure(AIOHandler:TIdIOHandler);
  TListenerThread = class;
  TListenerThreadProc = reference to procedure(const AReply:string; AThread:TListenerThread);

  TProto = class(TDataModule)
    cmdTcpServer: TIdCmdTCPServer;
    _tcpClient: TIdTCPClient;
    hook1: TIdServerInterceptLogEvent;
    con1: TIdConnectionIntercept;

    procedure cmdTcpServerExecute(AContext: TIdContext);
    procedure cmdTcpServerConnect(AContext: TIdContext);
    procedure cmdTcpServerDisconnect(AContext: TIdContext);

    procedure IdTCPClient1Connected(Sender: TObject);
    procedure IdTCPClient1Disconnected(Sender: TObject);

    procedure con1Receive(ASender: TIdConnectionIntercept; var ABuffer: TIdBytes);
    procedure con1Send(ASender: TIdConnectionIntercept; var ABuffer: TIdBytes);

    procedure hook1LogString(ASender: TIdServerInterceptLogEvent; const AText:string);

    procedure _tcpClientAfterBind(Sender: TObject);
    procedure _tcpClientConnected(Sender: TObject);
  private
    class
      var FProto:TProto;
    { Private declarations }
  public
    { Public declarations }
    class function Instance:TProto;

    procedure StartServer(ACancel:TEvent; AValues:TCmdValue);
//    procedure StartClient(ACancel:TEvent; AValues:TCmdValue);

    function AddServerCmd(const ACmdName:string; ACmdHandler:TCmdHandler):TIdCommandHandler;
    function AddClientListener(const ACmdName:string; APort:integer; const AHostname:string; AListenerHandler:TListenerThreadProc):TListenerThread;

    procedure Stop;
  end;

  TCmdHandlerHelper = class(TInterfacedObject)
  protected
    fCmdHandler:TCmdHandler;
    constructor create(ACmdHandler:TCmdHandler);
  public
    procedure OnCommand(ASender: TIdCommand);
  end;

  TNewClientProc = TFunc<Tidtcpclient>;

  TListenerThread = class(TThread)
    fProc:TListenerThreadProc;
    fNewClient:TFunc<Tidtcpclient>;
    fClient:TidTcpClient;
    fCmd:string;
    procedure Execute; override;
  public
    constructor create(const ACmd:string; AProc:TListenerThreadProc; ANewClient:TFunc<Tidtcpclient>);

    property Client:TidTcpClient read FClient;
  end;

  TProtoClientController = class(TCustomController)
  protected
    fListenerThread:TListenerThread;
    fCmdName:string;
    fPort:integer;
    fHostName:string;
    function InternalStartClient(AListenerHandler:TListenerThreadProc):boolean; virtual;
  public
    constructor create(AController:TCustomController; AValues:TCmdValue; const ACmdName:string; APort:integer; const AHostname:string); reintroduce;
  end;

  TProtoServerController = class(TCustomController)
  protected
    fCmdName:string;
    fCmdHandler:TIdCommandHandler;
    function InternalStartServer(ACmdHandler:TCmdHandler):boolean; virtual;
  public
    constructor create(AController:TCustomController; AValues:TCmdValue; const ACmdName:string); reintroduce;
  end;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

uses
  IdReplyRFC
  , IdStack
  , uLoggerLib
  , System.StrUtils
  , System.RegularExpressions
  , System.Generics.Collections
//  , uLLHookLib
  , winapi.Messages
  , IdException
  , System.UITypes
  ;

{$R *.dfm}

{ TProto }

class function TProto.Instance: TProto;
begin
  if FProto = nil then
    FProto := TProto.create(nil);
  result := FProto
end;

function TProto.AddClientListener(const ACmdName: string; APort:integer; const AHostname:string;
  AListenerHandler: TListenerThreadProc): TListenerThread;
begin
  result := TListenerThread.create(
    ACmdName,
    AListenerHandler,
    function:TIdTCPClient
    begin
      result := TIdTCPClient.Create();
      with result do
      begin
        Host := AHostname;
        Port := APort;
        ConnectTimeout := _tcpClient.ConnectTimeout;
        ReadTimeout := _tcpClient.ReadTimeout;
{$IFDEF PROTO_TRACE}
        Intercept := _tcpClient.Intercept;
{$ENDIF}
        ReadTimeout := _tcpClient.ReadTimeout;
        OnConnected := _tcpClient.OnConnected;
        OnAfterBind := _tcpClient.OnAfterBind;
        Connect
      end;
    end)
end;

function TProto.AddServerCmd(const ACmdName: string;
  ACmdHandler: TCmdHandler): TIdCommandHandler;
begin
  result := cmdTcpServer.CommandHandlers.Add;
  with result do
  begin
    Command := ACmdName;
    Disconnect := false;
    onCommand := TCmdHandlerHelper.create(
      ACmdHandler).OnCommand
  end;
end;

procedure TProto.StartServer;
begin
  var ips:TStrings;
  TidStack.IncUsage;
  try
    ips := GStack.LocalAddresses
  finally
    TidStack.DecUsage
  end;
  for var _ip in ips do
  with cmdTcpServer.Bindings.Add do
  begin
    IP := _ip;
    Port := AValues.asInteger;
    log('Echo server starting on %s..',[ip])
  end;

{$IFNDEF  PROTO_TRACE}
  cmdTcpServer.Intercept := nil;
{$ENDIF}
  cmdTcpServer.DefaultPort := AValues.asInteger;
  cmdTcpServer.Active := true;
end;

procedure TProto.Stop;
begin
  cmdTcpServer.Active := false;
//  cmdTcpClient.Disconnect;
//  tcpClient.Disconnect;
end;

procedure TProto.cmdTcpServerConnect(AContext: TIdContext);
begin
  log('cmdTcpServerConnect')
end;

procedure TProto.cmdTcpServerDisconnect(AContext: TIdContext);
begin
  log('cmdTcpServerDisconnect');
end;

procedure TProto.cmdTcpServerExecute(AContext: TIdContext);
begin
  log('cmdTcpServerExecute')
end;

procedure TProto.con1Receive(ASender: TIdConnectionIntercept; var ABuffer:
    TIdBytes);
begin
  log('CLIENT RECV %s',[BytesToString(ABuffer)])
end;

procedure TProto.con1Send(ASender: TIdConnectionIntercept; var ABuffer:
    TIdBytes);
begin
  log('CLIENT SEND %s',[BytesToString(ABuffer)])
end;

procedure TProto.hook1LogString(ASender: TIdServerInterceptLogEvent; const
    AText: string);
begin
  if cmdTcpServer.Active then
    log('SERVER %s',[AText])
  else
    log('CLIENT %s',[AText])
end;

procedure TProto.IdTCPClient1Connected(Sender: TObject);
begin
  log('tcpclient connected..')
end;

procedure TProto.IdTCPClient1Disconnected(Sender: TObject);
begin
  log('tcpclient disconnected..')
end;

procedure TProto._tcpClientAfterBind(Sender: TObject);
begin
  log('tcpClientAfterBind');
end;

procedure TProto._tcpClientConnected(Sender: TObject);
var
  tcpClient:TIdTCPClient absolute sender;
begin
  log('tcpClientConnected');
  try
    // read and absorb initial 'Welcome'
    var msg := tcpClient.IOHandler.ReadLnWait(10);
    log('tcpClientConnected %s',[msg]);
  except
    on e:exception do
      log(e, 'tcpClientConnected')
  end;
end;

{ TListenerThread }

constructor TListenerThread.create;
begin
  fCmd := ACmd;
  fProc := AProc;
  fNewClient := ANewClient;
  inherited create(false)
end;

procedure TListenerThread.Execute;
begin
  fClient := fNewClient();
  try
    var reply := fClient.SendCmd(fCmd, '');
    log('REPLY:%s RESULT:%s',[
      reply,
      fClient.LastCmdResult.Text.Text
      ]);
    fProc(reply, self)
  except
    on e:EIdConnClosedGracefully do
    begin
      log('Waiting to reconnect..');
      FreeAndNil(fClient);
      fClient := fNewClient();
      log('Reconnected..');
    end
  end;
end;

{ TCmdHandlerHelper }

constructor TCmdHandlerHelper.create(ACmdHandler: TCmdHandler);
begin
  fCmdHandler := ACmdHandler
end;

procedure TCmdHandlerHelper.OnCommand(ASender: TIdCommand);
begin
  ASender.Reply.SetReply(200, 'OK');
  ASender.SendReply;
  fCmdHandler(ASender.Context.Connection.IOHandler)
end;

{ TProtoClientController }

constructor TProtoClientController.create;
begin
  inherited create(AController, AValues);
  fCmdName := ACmdName;
  fPort := APort;
  fHostName := AHostname
end;

function TProtoClientController.InternalStartClient(
  AListenerHandler: TListenerThreadProc): boolean;
begin
  fListenerThread := TProto.Instance.AddClientListener(
    fCmdName,
    fPort,
    fHostName,
    AListenerHandler);
  result := true
end;

{ TProtoServerController }

constructor TProtoServerController.create;
begin
  inherited create(AController, AValues);
  fCmdName := ACmdName;
end;

function TProtoServerController.InternalStartServer(
  ACmdHandler: TCmdHandler): boolean;
begin
  fCmdHandler := TProto.Instance.AddServerCmd(fCmdName, ACmdHandler);
  result := true
end;

end.
