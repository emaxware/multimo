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
  TCmdHandler = reference to procedure(AIOHandler:TIdIOHandler);
  TInputSender = reference to procedure(AIOHandler:TIdIOHandler);
  TListenerThread = class;
  TListenerThreadProc = reference to procedure(AThread:TListenerThread);

  TProto = class(TDataModule)
    cmdTcpServer: TIdCmdTCPServer;
    _tcpClient: TIdTCPClient;
    hook1: TIdServerInterceptLogEvent;
    con1: TIdConnectionIntercept;
    procedure cmdTcpServerCommandHandlers0Command(ASender: TIdCommand);
    procedure cmdTcpServerCommandHandlers1Command(ASender: TIdCommand);
    procedure cmdTcpServerCommandHandlers2Command(ASender: TIdCommand);

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
//    FCancel:TEvent;
//    FConfigHandler, FMouseHandler, FTestHandler:TFunc<TIdTcpConnection,integer>;
    fInputSender:TInputSender;
  public
    { Public declarations }
    class function Instance:TProto;

    procedure StartServer(ACancel:TEvent; AValues:TCmdValue
      ; AInputSender:TInputSender);//;ConfigHandler,MouseHandler,TestHandler:TFunc<TIdTcpConnection,integer>);

    procedure StartClient(ACancel:TEvent; AValues:TCmdValue);
    procedure SendEcho(AClient:TIdTcpClient; const msg:string);//; writer:TFunc<TIdTCPConnection, integer>);
    procedure SendInput(AClient:TIdTcpClient; AInputs:TSendInputHelper);
    procedure SendListenMouse(AClient:TIdTcpClient);//; writer:TFunc<TIdTCPConnection, integer>);

    function AddServerCmd(const ACmdName:string; ACmdHandler:TCmdHandler):TIdCommandHandler;
    function AddClientListener(const ACmdName:string; APort:integer; const AHostname:string; AListenerHandler:TListenerThreadProc):TListenerThread;

    procedure Stop;
  end;

  TInputHelper = class helper for TSendInputHelper
    procedure AddMouseMoves(moves:TStringDynArray);
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
    procedure Execute; override;
  public
    constructor create(AProc:TListenerThreadProc; ANewClient:TFunc<Tidtcpclient>);

    property Client:TidTcpClient read FClient;
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

{$REGION 'ECHO Protocol'}

function TProto.AddClientListener(const ACmdName: string;APort:integer; const AHostname:string;
  AListenerHandler: TListenerThreadProc): TListenerThread;
begin
  result :=  TListenerThread.create(
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
        Intercept := _tcpClient.Intercept;
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

{$ENDREGION}

{$REGION 'INPUT Protocol'}

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

{$ENDREGION}

procedure TProto.cmdTcpServerCommandHandlers2Command(ASender: TIdCommand);
begin
  Log('%s %s received',[ASender.CommandHandler.Command, ASender.Params.Text]);
  var msg := 'OK';
  ASender.Reply.SetReply(200, msg);
  ASender.SendReply;

  var io := ASender.Context.Connection.IOHandler;

  fInputSender(io)
end;

procedure TProto.SendListenMouse(AClient: TIdTcpClient);
begin
  try
    var reply := AClient.SendCmd('SENDINPUT', '');
    writeln(AClient.LastCmdResult.Text.Text);

    var inps := TSendInputHelper.Create;
    var msg := 'Starting..';
//    with AClient do
//    begin
//      var io := IOHandler;
//      var data:TLLMouseHookData;
//      var bytes:TIdBytes;
//      repeat
//
//        WriteLn('CLIENT SENDINPUT ',msg);
//        msg := io.ReadLn;
//        WriteLn('CLIENT SENDINPUT ',msg);
//        if msg <> '>>' then
//          raise Exception.Create('Unexpected response');
//
//        io.ReadBytes(bytes, Size, false);
//        msg := io.ReadLn;
//        WriteLn('CLIENT SENDINPUT ',msg);
//        if msg <> 'sent' then
//          raise Exception.Create('Unexpected response');
//
//        data := PLLMouseHookData(@bytes[0])^;
//        case data.wparam of
//  //            WM_LBUTTONDOWN:
//          WM_LBUTTONUP:
//          begin
//            WriteLn('CLIENT SENDINPUT WM_LBUTTONUP');
//            inps.AddAbsoluteMouseMove(data.data.pt.X, data.data.pt.Y);
//            inps.AddMouseClick(TMouseButton.mbLeft);
//            inps.Flush
//          end;
//          WM_MOUSEMOVE:
//          begin
//            WriteLn('CLIENT SENDINPUT WM_MOUSEMOVE');
//            inps.AddAbsoluteMouseMove(data.data.pt.X, data.data.pt.Y);
//            inps.Flush
//          end;
//        end;
//
//        io.WriteLn('rcvd');
//        msg := 'waiting..';
//      until false;
//    end
  except
    on e:exception do
    begin
      log(e, 'SendListenMouse');
      raise
    end;
  end;
end;

procedure TProto.StartClient(ACancel: TEvent; AValues:TCmdValue);

//  function NewClient:TIdTCPClient;
//  begin
//    result := TIdTCPClient.Create();
//    with result do
//    begin
//      Host := AValues['HOST'].Value;
//      Port := AValues['PORT'].asInteger;
//      ConnectTimeout := _tcpClient.ConnectTimeout;
//      ReadTimeout := _tcpClient.ReadTimeout;
//      Intercept := _tcpClient.Intercept;
//      ReadTimeout := _tcpClient.ReadTimeout;
//      OnConnected := _tcpClient.OnConnected;
//      OnAfterBind := _tcpClient.OnAfterBind;
//      Connect
//    end;
////    TListenerThread.create()
//  end;

begin
  var newClient:TNewClientProc :=
  function:TIdTCPClient
  begin
    result := TIdTCPClient.Create();
    with result do
    begin
      Host := AValues['HOST'].Value;
      Port := AValues['PORT'].asInteger;
      ConnectTimeout := _tcpClient.ConnectTimeout;
      ReadTimeout := _tcpClient.ReadTimeout;
      Intercept := _tcpClient.Intercept;
      ReadTimeout := _tcpClient.ReadTimeout;
      OnConnected := _tcpClient.OnConnected;
      OnAfterBind := _tcpClient.OnAfterBind;
      Connect
    end;
  end;

  if AValues.Enabled['ECHO'] then
  TListenerThread.create(
    procedure(AThread:TListenerThread)
    begin
      SendEcho(AThread.Client, AValues.Option['ECHO'].value);
    end,
    newClient);

  if AValues.Enabled['SENDINPUT'] then
  TListenerThread.create(
    procedure(AThread:TListenerThread)
    begin
      var inp := TSendInputHelper.Create;
      try
        inp.AddMouseMoves(AValues.Option['SENDINPUT'].asArray('|'));
        SendInput(AThread.Client, inp)
      finally
        inp.free
      end;
    end,
    newClient);

  if AValues.Enabled['LISTENMOUSEMOVE'] then
  TListenerThread.create(
    procedure(AThread:TListenerThread)
    begin
      SendListenMouse(AThread.Client)
    end,
    newClient);
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

  fInputSender := AInputSender;
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
    var msg :=
//      'ERROR';
      tcpClient.IOHandler.ReadLnWait(10);
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
  fNewClient := ANewClient;
  inherited create(false)
end;

procedure TListenerThread.Execute;
begin
  fClient := fNewClient();
  try
    fProc(self)
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
  fCmdHandler(ASender.Context.Connection.IOHandler)
end;

end.
