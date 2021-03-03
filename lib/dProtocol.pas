unit dProtocol;

interface

uses
  System.SysUtils
  , System.Classes
  , System.SyncObjs, IdCustomTCPServer, IdTCPServer, IdCmdTCPServer,
  IdTCPConnection, IdTCPClient, IdUDPClient, IdBaseComponent, IdComponent,
  IdUDPBase, IdUDPServer, IdContext, IdCommandHandlers, IdIOHandler,
  IdSocketHandle, IdGlobal, IdCmdTCPClient, IdMappedPortTCP
  ;

type
  TProto = class(TDataModule)
    cmdTcpServer: TIdCmdTCPServer;
    _cmdTcpClient: TIdCmdTCPClient;
    tcpClient: TIdTCPClient;
    procedure cmdTcpServerExecute(AContext: TIdContext);
    procedure cmdTcpServerConnect(AContext: TIdContext);
    procedure IdTCPClient1Connected(Sender: TObject);
    procedure IdTCPClient1Disconnected(Sender: TObject);
    procedure cmdTcpServerDisconnect(AContext: TIdContext);
    procedure cmdTcpServerCommandHandlers3Command(ASender: TIdCommand);
    procedure tcpClientAfterBind(Sender: TObject);
  private
    class
      var FProto:TProto;
    { Private declarations }
//    FCancel:TEvent;
//    FConfigHandler, FMouseHandler, FTestHandler:TFunc<TIdTcpConnection,integer>;
    procedure HandleCommand(ASender: TIdCommand; AHandler:TFunc<TIdTcpConnection,integer>);
  public
    { Public declarations }
    class function Instance:TProto;

    procedure StartServer(ACancel:TEvent; APort:word);//;ConfigHandler,MouseHandler,TestHandler:TFunc<TIdTcpConnection,integer>);
    procedure AddCmdHandler(const ACommand:string;AHandler:TFunc<TIdTcpConnection,integer>);
    procedure StartClient(const AServerIP:string; APort:word; ACancel:TEvent);
    procedure SendEcho(const msg:string);//; writer:TFunc<TIdTCPConnection, integer>);
    procedure Broadcast(const AMsg:string; APort:word);

    procedure Stop;
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

procedure TProto.cmdTcpServerCommandHandlers3Command(ASender: TIdCommand);
begin
  var msg := ASender.Context.Connection.IOHandler.ReadLn;
  Log('%s %s',[ASender.CommandHandler.Command, msg]);
  ASender.Context.Connection.IOHandler.WriteLn(Format('ECHOED %s',[msg]))
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

procedure TProto.IdTCPClient1Connected(Sender: TObject);
begin
  log('tcpclient connected..')
end;

procedure TProto.IdTCPClient1Disconnected(Sender: TObject);
begin
  log('tcpclient disconnected..')
end;

procedure TProto.SendEcho(const Msg:string);//; writer: TFunc<TIdTCPConnection, integer>);
begin
  if not tcpClient.Connected then
    tcpClient.Connect;
  if not tcpClient.Connected then
    raise Exception.create('Not connected!!');

  tcpClient.SendCmd('ECHO');
//  var context := TIdContext.Create(tcpClient, nil, nil);
//  _cmdTcpClient.CommandHandlers.Items[3].DoCommand(Msg, context, '');
//  cmdTcpClient.SendCmd('ECHO hello');
//  cmdTcpClient.CommandHandlers.
//  var connection := IdTCPClient1;
//  var response := TIdReplyRFC.Create(nil);
//  try
//    log(format('%s: %s',[cmd,'writing cmd']));
//    connection.IOHandler.writeln(Cmd);// SendCmd(Cmd, 200);
//    try
//      log(format('%s: %s',[cmd,'getting response']));
//      var reply := IdTCPClient1.GetResponse(200);
//      log(format('%s: %s < %d %s',[cmd,'RESPONSE',reply,IdTCPClient1.LastCmdResult.FormattedReply.Text]));
//      writer(connection);
//      log(format('%s: %s',[cmd,'writing message']));
//      response.SetReply(200,cmd + ' OK');
//    except
//      on e:exception do
//      begin
//        log(format('%s: !!%s',[cmd,e.ClassName,e.message]));
//        response.SetReply(404,format('%s: %s %s',[cmd,e.ClassName,e.message]));
//      end;
//    end;
//  finally
//    var finalResponse := response.FormattedReply;
//    log(format('%s: %s > %s %s',[cmd,'REPLY',response.Code,finalResponse.Text]));
//    connection.IOHandler.Write(finalResponse);
//    try
//      var reply := IdTCPClient1.GetResponse();
//      log(format('%s: %s < %d %s',[cmd,'RESPONSE',reply,IdTCPClient1.LastCmdResult.FormattedReply.Text]));
//    finally
//      IdTCPClient1.Disconnect
//    end;
//  end;
end;

procedure TProto.StartClient(const AServerIP:string; APort:word; ACancel: TEvent);
begin
//  FCancel := ACancel;
  with tcpClient do
  begin
    Host := AServerIP;
    Port := APort;
    Connect
  end
end;

procedure TProto.StartServer(ACancel: TEvent; APort:word);
begin
//  FCancel := ACancel;
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
    Port := APort;
    log('Echo server starting on %s..',[ip])
  end;

  cmdTcpServer.DefaultPort := APort;
  cmdTcpServer.Active := true;
//
//  ACancel.WaitFor(INFINITE);
//  cmdTcpServer.Active := false
end;

procedure TProto.Stop;
begin
  cmdTcpServer.Active := false;
//  cmdTcpClient.Disconnect;
  tcpClient.Disconnect;
end;

procedure TProto.tcpClientAfterBind(Sender: TObject);
begin

end;

{ TCommandHandler }

constructor TCommandHandler.create(AProto: TProto; const ACommand: string;
  AHandler: TFunc<TIdTCPConnection, integer>);
begin
  FProto := AProto;
  FCommand := ACommand;
  FHandler := AHandler;
  with FProto.cmdTcpServer.CommandHandlers.Add do
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
