unit dProtocol;

interface

uses
  System.SysUtils
  , System.Classes
  , System.SyncObjs, IdCustomTCPServer, IdTCPServer, IdCmdTCPServer,
  IdTCPConnection, IdTCPClient, IdUDPClient, IdBaseComponent, IdComponent,
  IdUDPBase, IdUDPServer, IdContext, IdCommandHandlers, IdIOHandler,
  IdSocketHandle, IdGlobal
  ;

type
  TProto = class(TDataModule)
    IdUDPServer1: TIdUDPServer;
    IdUDPClient1: TIdUDPClient;
    IdTCPClient1: TIdTCPClient;
    IdCmdTCPServer1: TIdCmdTCPServer;
    procedure IdCmdTCPServer1Execute(AContext: TIdContext);
    procedure IdCmdTCPServer1Connect(AContext: TIdContext);
    procedure IdTCPClient1Connected(Sender: TObject);
    procedure IdTCPClient1Disconnected(Sender: TObject);
    procedure IdCmdTCPServer1Disconnect(AContext: TIdContext);
    procedure IdUDPServer1Status(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: string);
    procedure IdUDPServer1UDPRead(AThread: TIdUDPListenerThread;
      const AData: TIdBytes; ABinding: TIdSocketHandle);
  private
    class
      var FProto:TProto;
    { Private declarations }
    FCancel:TEvent;
//    FConfigHandler, FMouseHandler, FTestHandler:TFunc<TIdTcpConnection,integer>;
    procedure HandleCommand(ASender: TIdCommand; AHandler:TFunc<TIdTcpConnection,integer>);
  public
    { Public declarations }
    class function Instance:TProto;

    procedure StartServer(ACancel:TEvent; APort:word);//;ConfigHandler,MouseHandler,TestHandler:TFunc<TIdTcpConnection,integer>);
    procedure AddCmdHandler(const ACommand:string;AHandler:TFunc<TIdTcpConnection,integer>);
    procedure StartClient(AServerIP:string; APort:word; ACancel:TEvent);
    procedure Send(const Cmd:string; writer:TFunc<TIdTCPConnection, integer>);
    procedure Broadcast(const AMsg:string; APort:word);
  end;

  TCommandHandler = class
  protected
    FProto:TProto;
    FCommand:string;
    FHandler:TFunc<TIdTCPConnection, integer>;
    procedure handler(ASender: TIdCommand);
  public
    constructor create(AProto:TProto;const ACommand:string;AHandler:TFunc<TIdTCPConnection, integer>);
  end;
//var
//  dmMain: TdmMain;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

uses
  IdReplyRFC
  , IdStack
  , uLoggerLib
  ;

{$R *.dfm}

{ TdmMain }

class function TProto.Instance: TProto;
begin
  if FProto = nil then
    FProto := TProto.create(nil);
  result := FProto
end;

procedure TProto.AddCmdHandler(const ACommand: string;
  AHandler: TFunc<TIdTcpConnection, integer>);
begin
  TCommandHandler.create(self, ACommand, AHandler)
end;

procedure TProto.Broadcast(const AMsg: string; APort:word);
begin
  log('BROADCAST %X',[APort]);
  IdUDPClient1.Port := APort;
  IdUDPClient1.Broadcast(AMsg, APort);
end;

procedure TProto.HandleCommand(ASender:TIdCommand; AHandler:TFunc<TIdTcpConnection,integer>);
begin
  log(format('%s: %s',[ASender.CommandHandler.Command, 'OPENING..']));
  var responseCode:integer := 404;
  var responseText:string := 'DONE';
  var connection := ASender.Context.Connection;
  try
    responseCode := AHandler(Connection);
    var response := Connection.GetResponse(200);
    log(format('%s: %s < %d %s',[ASender.CommandHandler.Command, 'RESPONSE', response, Connection.LastCmdResult.Text.Text]));
  except
    on e:exception do
    begin
      log(format('%s: !!%s %s',[ASender.CommandHandler.Command, e.classname, e.message]));
      responseText := format('%s %s',[e.classname, e.message]);
    end;
  end;
  ASender.Reply.SetReply(
    responseCode
    ,format('%s: %s',[ASender.CommandHandler.Command, responseText]));
  log(format('%s: %s > %s',[ASender.CommandHandler.Command, 'REPLY', ASender.Reply.FormattedReply.Text]));
end;

procedure TProto.IdCmdTCPServer1Connect(AContext: TIdContext);
begin
  log('tcpserver connected..')
end;

procedure TProto.IdCmdTCPServer1Disconnect(AContext: TIdContext);
begin
  log('tcpserver disconnected..');
end;

procedure TProto.IdCmdTCPServer1Execute(AContext: TIdContext);
begin
  log('IdCmdTCPServer1Execute')
end;

procedure TProto.IdTCPClient1Connected(Sender: TObject);
begin
  log('tcpclient connected..')
end;

procedure TProto.IdTCPClient1Disconnected(Sender: TObject);
begin
  log('tcpclient disconnected..')
end;

procedure TProto.IdUDPServer1Status(ASender: TObject; const AStatus: TIdStatus;
  const AStatusText: string);
begin
  log('IdUDPServer1Status: %s',[AStatusText])
end;

procedure TProto.IdUDPServer1UDPRead(AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  var data := BytesToString(AData);
  log('IdUDPServer1UDPRead: %s',[data]);
end;

procedure TProto.Send(const Cmd:string; writer: TFunc<TIdTCPConnection, integer>);
begin
  if not IdTCPClient1.Connected then
    IdTCPClient1.Connect;
  if not IdTCPClient1.Connected then
    raise Exception.create('Not connected!!');
  var connection := IdTCPClient1;
  var response := TIdReplyRFC.Create(nil);
  try
    log(format('%s: %s',[cmd,'writing cmd']));
    connection.IOHandler.writeln(Cmd);// SendCmd(Cmd, 200);
    try
      log(format('%s: %s',[cmd,'getting response']));
      var reply := IdTCPClient1.GetResponse(200);
      log(format('%s: %s < %d %s',[cmd,'RESPONSE',reply,IdTCPClient1.LastCmdResult.FormattedReply.Text]));
      writer(connection);
      log(format('%s: %s',[cmd,'writing message']));
      response.SetReply(200,cmd + ' OK');
    except
      on e:exception do
      begin
        log(format('%s: !!%s',[cmd,e.ClassName,e.message]));
        response.SetReply(404,format('%s: %s %s',[cmd,e.ClassName,e.message]));
      end;
    end;
  finally
    var finalResponse := response.FormattedReply;
    log(format('%s: %s > %s %s',[cmd,'REPLY',response.Code,finalResponse.Text]));
    connection.IOHandler.Write(finalResponse);
    try
      var reply := IdTCPClient1.GetResponse();
      log(format('%s: %s < %d %s',[cmd,'RESPONSE',reply,IdTCPClient1.LastCmdResult.FormattedReply.Text]));
    finally
      IdTCPClient1.Disconnect
    end;
  end;
end;

procedure TProto.StartClient(AServerIP:string; APort:word; ACancel: TEvent);
begin
  FCancel := ACancel;
  with IdTCPClient1 do
  begin
    Host := AServerIP;
    Port := APort
  end;
end;

procedure TProto.StartServer(ACancel: TEvent; APort:word);
begin
  FCancel := ACancel;
  var ips:TStrings;
  TidStack.IncUsage;
  try
    ips := GStack.LocalAddresses
  finally
    TidStack.DecUsage
  end;
  for var ip in ips do
  begin
    log(ip)
  end;

  IdCmdTCPServer1.Active := true;
  IdUDPServer1.DefaultPort := APort;

//  IdUDPServer1.Bindings[0].Port := APort;
//  IdUDPServer1.Bindings[0].IP := '192.168.1.1';
  IdUDPServer1.Active := true;
  ACancel.WaitFor(INFINITE);
  IdCmdTCPServer1.Active := false
end;

{ TCommandHandler }

constructor TCommandHandler.create(AProto: TProto; const ACommand: string;
  AHandler: TFunc<TIdTCPConnection, integer>);
begin
  FProto := AProto;
  FCommand := ACommand;
  FHandler := AHandler;
  with FProto.IdCmdTCPServer1.CommandHandlers.Add do
  begin
    Command := ACommand;
    OnCommand := self.handler;
  end;
end;

procedure TCommandHandler.handler(ASender: TIdCommand);
begin
  FProto.HandleCommand(ASender, FHandler)
end;

end.
