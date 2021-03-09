unit dProtocol;

interface

uses
  winapi.windows
  , System.SysUtils
  , System.Types
  , System.Classes
  , System.SyncObjs, IdCustomTCPServer, IdTCPServer, IdCmdTCPServer,
  IdTCPConnection, IdTCPClient, IdUDPClient, IdBaseComponent, IdComponent,
  IdUDPBase, IdUDPServer, IdContext, IdCommandHandlers, IdIOHandler,
  IdSocketHandle, IdGlobal, IdCmdTCPClient, IdMappedPortTCP,
  IdServerInterceptLogEvent, IdIntercept, IdServerInterceptLogBase
  , uSendInput
  , uCommandLineOptions, IdIPMCastServer, IdIPMCastBase, IdIPMCastClient
  ;

type
  TProto = class(TDataModule)
    cmdTcpServer: TIdCmdTCPServer;
    _cmdTcpClient: TIdCmdTCPClient;
    _tcpClient: TIdTCPClient;
    hook1: TIdServerInterceptLogEvent;
    con1: TIdConnectionIntercept;
    IdIPMCastClient1: TIdIPMCastClient;
    IdIPMCastServer1: TIdIPMCastServer;
    procedure cmdTcpServerCommandHandlers1Command(ASender: TIdCommand);
    procedure cmdTcpServerExecute(AContext: TIdContext);
    procedure cmdTcpServerConnect(AContext: TIdContext);
    procedure IdTCPClient1Connected(Sender: TObject);
    procedure IdTCPClient1Disconnected(Sender: TObject);
    procedure cmdTcpServerDisconnect(AContext: TIdContext);
    procedure cmdTcpServerCommandHandlers0Command(ASender: TIdCommand);
    procedure cmdTcpServerCommandHandlers2Command(ASender: TIdCommand);
    procedure con1Receive(ASender: TIdConnectionIntercept; var ABuffer: TIdBytes);
    procedure con1Send(ASender: TIdConnectionIntercept; var ABuffer: TIdBytes);
    procedure hook1LogString(ASender: TIdServerInterceptLogEvent; const AText:
        string);
    procedure _tcpClientAfterBind(Sender: TObject);
    procedure _tcpClientConnected(Sender: TObject);
  private
    class
      var FProto:TProto;
    { Private declarations }
//    FCancel:TEvent;
//    FConfigHandler, FMouseHandler, FTestHandler:TFunc<TIdTcpConnection,integer>;
  public
    { Public declarations }
    class function Instance:TProto;

    procedure StartServer(ACancel:TEvent; AValues:TCmdValue);//;ConfigHandler,MouseHandler,TestHandler:TFunc<TIdTcpConnection,integer>);
    procedure StartClient(ACancel:TEvent; AValues:TCmdValue);
    procedure SendEcho(AClient:TIdTcpClient; const msg:string);//; writer:TFunc<TIdTCPConnection, integer>);
    procedure SendInput(AClient:TIdTcpClient; AInputs:TSendInputHelper);

    procedure Stop;
  end;

  TInputHelper = class helper for TSendInputHelper
    procedure AddMouseMoves(moves:TStringDynArray);
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
  ;

{$R *.dfm}

{ TProto }

class function TProto.Instance: TProto;
begin
  if FProto = nil then
    FProto := TProto.create(nil);
  result := FProto
end;

procedure TProto.cmdTcpServerCommandHandlers1Command(ASender: TIdCommand);
begin
  Log('%s %s received',[ASender.CommandHandler.Command, ASender.Params.Text]);
  ASender.Reply.SetReply(200, 'OK');
  ASender.SendReply;

  var inps := TSendInputHelper.Create;
  try
    with ASender.Context.Connection, IOHandler do
    begin
      var l:integer := Readint32;
      log('read count = %d',[l]);
      var s := sizeof(TInput);
      for var i := 0 to l-1 do
      begin
        var inp:TInput;
        var bytes:TIdBytes;
        ReadBytes(bytes, s);
        inp := PInput(@bytes[0])^;
        inps.Add(inp);
        log('read input %d (%x %d,%d %d %d)',[i, inp.Itype, inp.mi.dx, inp.mi.dy, inp.mi.time, length(bytes)]);
      end;
    end;

    inps.Flush;
    log('input flushed')
  finally
    inps.free
  end;
end;

procedure TProto.cmdTcpServerCommandHandlers0Command(ASender: TIdCommand);
begin
  Log('%s %s received',[ASender.CommandHandler.Command, ASender.Params.Text]);
  var msg :=
      ReverseString(
        StringsReplace(
          ASender.Params.Text
          , [#13#10,#13,#10]
          , ['','','']
          ));
  ASender.Reply.SetReply(200, msg);
  ASender.SendReply
//  var strm := TStringStream.Create('this is a stream');
//  ASender.Context.Connection.IOHandler.Write(strm, 0, true);
//  strm.free
end;

procedure TProto.cmdTcpServerCommandHandlers2Command(ASender: TIdCommand);
begin
//  ASender.Context.Binding.IP
end;

procedure TProto.SendEcho(AClient:TIdTcpClient; const Msg:string);
begin
  var reply := AClient.SendCmd('ECHO hello', '');
  writeln(AClient.LastCmdResult.Text.Text)

//  var strm := TStringStream.Create;
//  tcpClient.IOHandler.ReadStream(strm, -1, false);
//  writeln(strm.DataString);
//  strm.free
//  writeln(tcpClient.LastCmdResult.FormattedReply.Text);
end;

procedure TProto.SendInput(AClient:TIdTcpClient; AInputs: TSendInputHelper);
begin
  var reply := AClient.SendCmd('INPUT', '');
  writeln(AClient.LastCmdResult.Text.Text);

  with AClient, IOHandler do
  begin
    Write(AInputs.Count);
    log('write count = %d',[AInputs.Count]);
    var i := 0;
    for var inp in AInputs do
    begin
      var bytes := RawToBytes(inp, sizeof(inp));
      log('write input #%d (%x %d,%d %d %d)',[i, inp.Itype, inp.mi.dx, inp.mi.dy, inp.mi.time, Length(bytes)]);
      write(bytes);
      inc(i)
    end
  end
end;

type
  TListenerThread = class;

  TListenerThreadProc = reference to procedure(AThread:TListenerThread);

  TListenerThread = class(TThread)
    fProc:TListenerThreadProc;
    fClient:TidTcpClient;
    procedure Execute; override;
  public
    constructor create(AProc:TListenerThreadProc; AClient:TIdTcpClient);

    property Client:TidTcpClient read FClient;
  end;

procedure TProto.StartClient(ACancel: TEvent; AValues:TCmdValue);

  function NewClient:TIdTCPClient;
  begin
    result := TIdTCPClient.Create();
    with result do
    begin
      Host := AValues.Value;
      Port := AValues['PORT'].asInteger;
      Connect
    end;
//    TListenerThread.create()
  end;

begin
  if AValues.Enabled['ECHO'] then
  TListenerThread.create(
    procedure(AThread:TListenerThread)
    begin
      SendEcho(AThread.Client, AValues.Option['ECHO'].value);
    end,
    NewClient);

  if AValues.Enabled['SENDMOUSEMOVE'] then
  TListenerThread.create(
    procedure(AThread:TListenerThread)
    begin
      var inp := TSendInputHelper.Create;
      try
  //              inp.AddDelay(10000);
        inp.AddMouseMoves(AValues.Option['SENDMOUSEMOVE'].asArray('|'));
        SendInput(AThread.Client, inp)
      finally
        inp.free
      end;
    end,
    NewClient);

  if AValues.Enabled['LISTENMOUSEMOVE'] then
  TListenerThread.create(
    procedure(AThread:TListenerThread)
    begin
      var inp := TSendInputHelper.Create;
      try
  //              inp.AddDelay(10000);
//        inp.AddMouseMoves(AValues.Option['SENDMOUSEMOVE'].asArray('|'));
//        SendInput(AThread.Client, inp)
      finally
        inp.free
      end;
    end,
    NewClient);
end;

procedure TProto.StartServer(ACancel: TEvent; AValues:TCmdValue);
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
    Port := AValues['PORT'].asInteger;
    log('Echo server starting on %s..',[ip])
  end;

  cmdTcpServer.DefaultPort := AValues['PORT'].asInteger;
  cmdTcpServer.Active := true;
//
//  ACancel.WaitFor(INFINITE);
//  cmdTcpServer.Active := false
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
begin
  log('tcpClientConnected');
  try
    var msg :=
      'ERROR';
//      tcpClient.IOHandler.ReadLnWait(10);
    log('tcpClientConnected %s',[msg]);
  except
    on e:exception do
      log(e, 'tcpClientConnected')
  end;
end;

{ TInputHelper }

procedure TInputHelper.AddMouseMoves;
begin
  for var move in moves do
  begin
    var m := SplitString(move,',');
    AddRelativeMouseMove(strtoint(m[0]),strtoint(m[1]));
    AddDelay(1000);
  end;
end;

{ TListenerThread }

constructor TListenerThread.create;
begin
  fProc := AProc;
  fClient := AClient;
//  fClient.
  inherited create(false)
end;

procedure TListenerThread.Execute;
begin
//  fClient.ConnectTimeout :=
  fProc(self)
end;

end.
