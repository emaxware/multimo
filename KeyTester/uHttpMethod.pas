unit uHttpMethod;

interface

uses
  SysUtils,
  Classes,
  SynCommons,
  SynTable,
  SynLog,
  mORMot,
  SynBidirSock,
  mORMotHttpServer,
  mORMotHttpClient,
  CallbackInterface
  ;

type
  TChatService = class(TInterfacedObject,IChatService)
  protected
    fConnected: array of IChatCallback;
  public
    procedure Join(const pseudo: string; const callback: IChatCallback);
    procedure BlaBla(const pseudo,msg: string);
    procedure CallbackReleased(const callback: IInvokable; const interfaceName: RawUTF8);
  end;

  TChatCallback = class(TInterfacedCallback,IChatCallback)
  protected
    procedure NotifyBlaBla(const pseudo, msg: string);
  end;

var
  mode:string = '';

procedure RunHttpServer;
procedure RunHttpClient;

implementation

procedure TChatCallback.NotifyBlaBla(const pseudo, msg: string);
begin
  TextColor(ccLightBlue);
  writeln(#13'@',pseudo,' ',msg);
  TextColor(ccLightGray);
  write('>');
end;

procedure TChatService.Join(const pseudo: string;
  const callback: IChatCallback);
begin
  InterfaceArrayAdd(fConnected,callback);
end;

procedure TChatService.BlaBla(const pseudo,msg: string);
var i: integer;
begin
  for i := high(fConnected) downto 0 do // downwards for InterfaceArrayDelete()
    try
      fConnected[i].NotifyBlaBla(pseudo,msg);
    except
      InterfaceArrayDelete(fConnected,i); // unsubscribe the callback on failure
    end;
end;

procedure TChatService.CallbackReleased(const callback: IInvokable; const interfaceName: RawUTF8);
begin
  if interfaceName='IChatCallback' then
    InterfaceArrayDelete(fConnected,callback);
end;


procedure RunHttpServer;
var HttpServer: TSQLHttpServer;
    Server: TSQLRestServerFullMemory;
begin
  Server := TSQLRestServerFullMemory.CreateWithOwnModel([]);
  try
    Server.CreateMissingTables;
    Server.ServiceDefine(TChatService,[IChatService],sicShared).
      SetOptions([],[optExecLockedPerInterface]). // thread-safe fConnected[]
      ByPassAuthentication := true;
    HttpServer := TSQLHttpServer.Create('8888',[Server],'+',useBidirSocket);
    try
      HttpServer.WebSocketsEnable(Server,PROJECT31_TRANSMISSION_KEY).
        Settings.SetFullLog; // full verbose logs for this demo
      TextColor(ccLightGreen);
      writeln('WebSockets Chat Server running on localhost:8888'#13#10);
      TextColor(ccWhite);
      writeln('Please compile and run Project31ChatClient.exe'#13#10);
      TextColor(ccLightGray);
      writeln('Press [Enter] to quit'#13#10);
      TextColor(ccCyan);
      readln;
    finally
      HttpServer.Free;
    end;
  finally
    Server.Free;
  end;
end;

procedure RunHttpClient;
var Client: TSQLHttpClientWebsockets;
    pseudo,msg: string;
    Service: IChatService;
    callback: IChatCallback;
    address:string;
begin
  if ParamCount < 2 then
  begin
    writeln('Enter server address:');
    readln(address);
  end
  else
    address := paramstr(2);
  if address='' then
    address := '127.0.0.1';
  writeln(format('Connecting to the Websockets server @ %s...',[address]));
  Client := TSQLHttpClientWebsockets.Create(address,'8888',TSQLModel.Create([]));
  try
    Client.Model.Owner := Client;
    Client.WebSocketsUpgrade(PROJECT31_TRANSMISSION_KEY);
    if not Client.ServerTimeStampSynchronize then
      raise EServiceException.Create(
        'Error connecting to the server: please run Project31ChatServer.exe');
    Client.ServiceDefine([IChatService],sicShared);
    if not Client.Services.Resolve(IChatService,Service) then
      raise EServiceException.Create('Service IChatService unavailable');
    try
      TextColor(ccWhite);
      writeln('Please enter you name, then press [Enter] to join the chat');
      writeln('Enter a void line to quit');
      write('@');
      TextColor(ccLightGray);
      readln(pseudo);
      if pseudo='' then
        exit;
      callback := TChatCallback.Create(Client,IChatCallback);
      Service.Join(pseudo,callback);
      TextColor(ccWhite);
      writeln('Please type a message, then press [Enter]');
      writeln('Enter a void line to quit');
      repeat
        TextColor(ccLightGray);
        write('>');
        readln(msg);
        if msg='' then
          break;
        Service.BlaBla(pseudo,msg);
      until false;
    finally
      callback := nil; // will unsubscribe from the remote publisher
      Service := nil;  // release the service local instance BEFORE Client.Free
    end;
  finally
    Client.Free;
  end;
end;

end.
