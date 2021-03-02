unit uCrtSockMethod;

interface

uses
  SynBidirSock
  , SynWinSock
  , SynCommons
  , SynLog
  , SynCrtSock
  ;

type
  TMoConnection = class(TAsynchConnection)

  end;

  TMoServerConnection = class(TMoConnection)
    procedure AfterCreate(Sender: TAsynchConnections); override;
    function OnRead(Sender: TAsynchConnections): TPollAsynchSocketOnRead; override;
  end;

  TMoClientConnection = class(TMoConnection)
    procedure AfterCreate(Sender: TAsynchConnections); override;
  end;

  TMoServer = class(TAsynchServer)
  public
    constructor create(
      const APort, AProcessName:string
      ; ASynLogClass:TSynLogClass
      ; aOptions: TAsynchConnectionsOptions = []
      );
  end;

  TMoClient = class(TAsynchClient)
  protected
    procedure Execute; override;
  public
    constructor create(
      const AServer, APort, AProcessName:string
      ; ASynLogClass:TSynLogClass
      ; aOptions: TAsynchConnectionsOptions = []
      );
  end;

procedure RunTcpClient(const AServer, APort:string; ALogClass:TSynLogClass);
procedure RunTcpServer(const APort:string; ALogClass:TSynLogClass);

implementation

uses
  StrUtils
  ;

procedure RunTcpClient;
var
  msg:string;
begin
  with TMoClient.create(AServer, APort, 'MOCLIENT', ALogClass ,[]) do
  begin
    waitfor;
    FreeOnTerminate := true;
    Terminate;
  end;
end;

procedure RunTcpServer;
begin
  with TMoServer.create(APort, 'MOSERVER', ALogClass ,[]) do
  begin
    waitfor;
    FreeOnTerminate := true;
    Terminate;
  end;
end;

{ TMoServer }

constructor TMoServer.create;
begin
  inherited create(APort, nil, nil, TMoServerConnection, AProcessName, ASynLogClass, aOptions, 1);
end;


{ TMoClient }

constructor TMoClient.create;
begin
  inherited create(AServer, APort, 1, 30000, nil, nil, TMoClientConnection, AProcessName, ASynLogClass, aOptions, 1);
end;

procedure TMoClient.Execute;
begin
  with Log.Enter(self, 'Execute') do
  begin
    inherited;
    Log(sllTrace, 'waiting for termination..');
    while not terminated do
      sleep(1000)
  end
end;

{ TMoClientConnection }

procedure TMoClientConnection.AfterCreate(Sender: TAsynchConnections);
var
  resp, msg:string;
  fSocket:TCrtSocket;
begin
  with Sender.Log.Enter(self, 'AfterCreate') do
  begin
    inherited;
    fSocket := TCrtSocket.Create(60000);
    fSocket.OpenBind('','',false,self.fSlot.socket);
    try
      fSocket.CreateSockIn;
      fSocket.CreateSockOut;
      writeln(fSocket.SockOut^,'HELLO');
      readln(fSocket.SockIn^, resp);
      writeln(resp);
      repeat
        write('>?');
        readln(msg);
        if msg='DONE' then
          break;

        writeln(fSocket.SockOut^, msg);
        readln(fSocket.SockIn^, resp);
        writeln(resp);
      until resp = 'STOP';
    finally
      fSocket.Close;
      FSocket.free;
      sender.Terminate
    end;
  end;
end;

{ TMoServerConnection }

procedure TMoServerConnection.AfterCreate(Sender: TAsynchConnections);
var
  resp, msg:string;
  fSocket:TCrtSocket;
begin
  with Sender.Log.Enter(self, 'AfterCreate') do
  begin
    inherited;
  end
end;

function TMoServerConnection.OnRead(
  Sender: TAsynchConnections): TPollAsynchSocketOnRead;
var
  resp, msg:string;
  fSocket:TCrtSocket;
begin
  with Sender.Log.Enter(self, 'OnRead') do
  begin
    msg := self.fSlot.readbuf;
    msg := ReplaceStr(msg, #13#10, '');
    self.fSlot.readbuf := '';
    writeln(msg);
    result := sorContinue;
    if msg='STOP' then
      result := sorClose
    else
      msg := 'ECHO '+msg;
    sender.Clients.WriteString(self, msg+#13#10);
//    sender.Clients.ProcessWrite()
//    sender.Clients.ProcessRead()
//    sender.
//    fSocket := TCrtSocket.Create(60000);
//    fSocket.OpenBind('','',false,self.fSlot.socket);
//    result := sorClose;
//    msg := fSlot.readbuf;
//    fSlot.readbuf := '';
//    try
//      writeln(msg);
//      fSocket.CreateSockIn;
//      fSocket.CreateSockOut;
//
//      repeat
//        readln(fSocket.SockIn^,msg);
//        if msg='STOP' then
//        else
//          msg := 'ECHO '+msg;
//        writeln(msg);
//        writeln(fSocket.SockOut^,msg);
//      until msg = 'STOP';
//    finally
//      fSocket.free
//    end
  end
end;

end.
