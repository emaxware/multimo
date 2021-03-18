unit uLogController;

{.$DEFINE  LOG_TRACE}

interface

uses
  uLoggerLib
  , uController
  , dProtocol
  ;

type
  TLogServerController = class(TProtoServerController)
  protected
    fLogger:ILogger;
  public
    function Start:boolean; override;

    property Logger:ILogger read fLogger;
  end;

  TLogClientController = class(TProtoClientController)
  protected
    fLogger:ILogger;
  public
    function Start:boolean; override;

    property Logger:ILogger read fLogger;
  end;

implementation

uses
  winapi.windows
  , system.SysUtils
  , system.SyncObjs
  , System.Threading
  , IdGlobal
  , IdIOHandler
  , uSendInput
  ;

{ TLogServerController }

function TLogServerController.Start: boolean;
begin
  fLogger := TNullLogger.Create;
  result := inherited start;
  if result then
    InternalStartServer(
      procedure(AIO:TIdIOHandler)
      begin
        var logmsg:TLogMsgRec;

        repeat
          var msg := AIO.ReadLn;
          if msg='>>' then
          begin
            with logmsg do
            begin
              threadid := AIO.ReadInt32;
              PUInt64(@dt)^ := AIO.ReadUInt64;
              p := TLogPriority(AIO.ReadByte);
              module := AIO.ReadLn;
              msg := AIO.ReadLn
            end;
            writeln(fLogger.FormatLogMsgRec(logmsg));
            AIO.WriteLn('sent');
            continue
          end;
          writeln('Unknown log terminator ',msg)
        until false;

        writeln('Stopping Log listener..')
      end)
end;

{ TLogClientController }

function TLogClientController.Start: boolean;
begin
  result := inherited start;
  if result then
  begin
    var started := TSimpleEvent.Create;
    InternalStartClient(
      procedure(const AReply:string; AThread:TListenerThread)
      begin
        fLogger := TAsyncLogger.CreateWithLogMsg(
          TThreadPool.Default,
          procedure(AMsgRec:TLogMsgRec)
          begin
            with AThread.fClient, AMsgRec do
            begin
              IOHandler.WriteLn('>>');
              IOHandler.Write(Int32(threadid));
              IOHandler.Write(PUInt64(@dt)^);
              IOHandler.Write(byte(p));
              IOHandler.WriteLn(module);
              IOHandler.WriteLn(msg)
            end
          end,
          'LOGCLIENT',
          lpVerbose,
          lpVerbose
          );

        if fVals.Value <> '' then
          fLogger.DefLog(fVals.Value);

        started.SetEvent;

        var msg := '';
        repeat
          msg := AThread.fClient.IOHandler.ReadLn;
{$IFDEF LOG_TRACE}
          writeln(msg);
{$ENDIF}
        until msg <> 'sent';

        writeln('Stopping Log sender..')
      end);
    started.WaitFor;
    started.free
  end;
end;

end.
