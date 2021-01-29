unit uServerProtocol;

interface

uses
  System.SyncObjs
  , IdIOHandler
  , uEventLib
//  , SynCommons
  ;

procedure StartServer(ADone:TEvent; APort:word);

implementation

uses
  System.Types
  , System.SysUtils
  , dProtocol
  , IdGlobal
  , IdTCPConnection
  , IdReplyRFC
  , uAPILib
  , uMonLib
  , uIdLib
  , uLoggerLib
  ;

procedure StartServer(ADone:TEvent; APort:word);
begin
//  TProto.Instance.StartServer(ADone
//    , nil
  TProto.Instance.AddCmdHandler('ECHO2', function(AConnection:TIdTCPConnection):integer
    begin
      result := 200;
      var echoStr := AConnection.IOHandler.ReadLn;
      log(format('ECHO: < %s',[echoStr]));

      var reply := TidReplyRFC.Create(nil);
      reply.SetReply(200, format('ECHO: RECEIVED %s',[echoStr]));
      AConnection.IOHandler.Write(reply.FormattedReply.Text);

      echoStr := format('echoing %s',[echoStr]);
      log(format('ECHO: > %s',[echoStr]));
      AConnection.IOHandler.writeln(echoStr);
    end);
  TProto.Instance.AddCmdHandler('MOUSE', function(AConnection:TIdTCPConnection):integer
    begin
      result := 200;
      var buffer:TIdBytes;
      var bufferSize := AConnection.IOHandler.ReadUInt32;
      log(format('MOUSE: < monDefs %d',[bufferSize]));
      AConnection.IOHandler.ReadBytes(buffer, bufferSize, false);

      var monDefs:TMonDefs;
      var defCount:integer := bufferSize div sizeof(TMonitorDef);
      setlength(monDefs, defCount);
      Move(buffer[0], monDefs[0], bufferSize);

      var reply := TidReplyRFC.Create(nil);
      reply.SetReply(200, format('MOUSE: RECEIVED %d monitor defs',[defCount]));
      AConnection.IOHandler.Write(reply.FormattedReply.Text);

      var mouse:TInputEvent;
      mouse.MoveTo(monDefs[0], TPointF.Create(0, 0));
      log(format('MOUSE: > mouse_event (%d) %d,%d',[ord(mouse.event), mouse.dx,mouse.dy]));
      AConnection.IOHandler.WriteEvent(mouse);
    end);
  TProto.Instance.AddCmdHandler('TEST', function(AConnection:TIdTCPConnection):integer
    begin
      result := 200;
      var msg := AConnection.IOHandler.ReadLn;
      log(format('TEST: < %s',[msg]));
      AConnection.IOHandler.writeln('OK');
      log(format('TEST: > %s',['OK']));

      var i:UInt16;
      repeat
        i := AConnection.IOHandler.ReadUInt16();
        log(format('TEST: < %d',[i]));
      until i >= 100;

      for i := 1 to 100 do
      begin
        log(format('TEST: > %d',[i]));
        AConnection.IOHandler.Write(i);
      end;

      repeat
        log('?');
        readln(msg);
        AConnection.IOHandler.writeln(msg);
        log(format('TEST: > %s',[msg]));
      until msg = 'DONE2';

      repeat
        msg := AConnection.IOHandler.ReadLn;
        log(format('TEST: < %s',[msg]));
      until msg = 'DONE';
    end);
    TProto.Instance.StartServer(ADone, APort);
end;

end.
