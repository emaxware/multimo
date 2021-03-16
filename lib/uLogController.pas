unit uLogController;

interface

uses
  uLoggerLib
  , uController
  ;

type
  TLogServerController = class(TCustomController)
  protected
    fLogger:ILogger;
    fCmdHandler:TIdCommandHandler;
  public
    function Start:boolean; override;
  end;

  TLogClientController = class(TCustomController)
  protected
    fLogger:ILogger;
    fListenerThread:TListenerThread;
  public
    function Start:boolean; override;
  end;

implementation

{ TLogServerController }

function TLogServerController.Start: boolean;
begin

end;

{ TLogClientController }

function TLogClientController.Start: boolean;
begin
  result := inherited start;
  if result then
    fListenerThread := TProto.Instance.
      AddClientListener('LOG',
        fVals['PORT'].asInteger,
        fVals['HOST'].Value,
        procedure(AThread:TListenerThread)
        begin
          var sizeTInput := SizeOf(TInput);
          var inps := TSendInputHelper.Create;
          var reply := AThread.Client.SendCmd('SENDINPUT', '');
          system.writeln(AThread.Client.LastCmdResult.Text.Text);

          repeat
            var msg := AThread.Client.IOHandler.ReadLn();
            if msg='>>' then
            begin
              var data:TIdBytes;
              AThread.Client.IOHandler.ReadBytes(data, sizeTInput);
              inps.Add(PInput(@data[0])^);
              continue;
            end;
            if msg='sent' then
            begin

              break
            end;
            raise Exception.CreateFmt('Unexpected token "%s"',[msg]);
          until false;
        end)
end;

end.
