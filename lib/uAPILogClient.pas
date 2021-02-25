unit uAPILogClient;

interface

uses
  System.SyncObjs
  , uShareLib
  , winapi.windows
  , uLoggerLib
//  , uAPILib
  ;

const
  LogBufferSize =
//    256;
    100 * 1024;

type
  TLogBuffer = TArray<Byte>;

  TLogHeader = record
    logtime:TDatetime;
    logcnt:cardinal;
    logmsg:ShortString;
  end;
  PLogHeader = ^TLogHeader;

  TSharedLog = record
    timestamp:TDateTime;
    writecnt:cardinal;
    opencnt:cardinal;
    nextPos:cardinal;
    buffer:array[0..LogBufferSize] of byte;
  end;
  PSharedLog = ^TSharedLog;

  TLogHeaderHelper = record helper for TSharedMem
    function log(const AMsg:shortstring; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean; overload;
    function log(const AFmtMsg:shortstring; Args:array of const; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean; overload;
  end;

  TLoggerClient = class(TSimpleLogger)
  public
    constructor create(const AModulename:string;
      WithConsole:Boolean = false;
      AThresholdPriority:TLogPriority =
{$IFDEF DEBUG}
      lpDebug
{$ELSE}
      lpInfo
{$ENDIF}
      ; ADefaultPriority:TLogPriority =
{$IFDEF DEBUG}
      lpDebug
{$ELSE}
      lpInfo
{$ENDIF}
      );
  end;

function InitShareLog(const ADesc:string; WithDefaultConsoleLogger:boolean):boolean;
function WriteLog(var ASharedMem:TSharedMem; const AMsg:shortstring; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean; overload;

var
  SLog:PSharedMem = nil;
//  SLogger:ILogger = nil;

implementation

uses
  System.SysUtils
  , System.Threading
  , winapi.psapi
  , uConsoleLogger
  , JclConsole
  ;

function InitShareLog;
begin
  result := false;
  if SLog = nil then
  begin
    result := true;
//    APIDLLStarted := true;
    new(SLog);
    OpenSharedMem(ADesc+'Log', SLog^, sizeof(TSharedLog),
      function(AData:PSharedHeader):boolean
      var ALogData:PSharedLog absolute AData;
      begin
        inc(ALogData^.opencnt);
        SLog^.opencnt := ALogData^.opencnt;
        result := true
      end);

    if WithDefaultConsoleLogger then
      SetLogger(TLoggerClient.create(ADesc,True));

////    if ASync then
//    SLogger :=
//      TSimpleLogger.create(
////      TAsyncLogger.create(
////        TThreadPool.Default,
//        function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
//        begin
//{$IFDEF ISCONSOLE}
//          writeln(ALogMsg);
//{$ENDIF}
//          SLog^.log(ALogMsg);
//          result := AMsg
//        end
//        , ProcessFileName(GetCurrentProcessID, false) + '-' + ADesc
//        , lpDebug
//        , lpDebug
////{$IFDEF INDLL}
////        , 'MULTIMODLL'
////{$ELSE}
////        , 'MULTIMOCLI'
////{$ENDIF}
//      );
//
//      SetLogger(SLogger);
//
//      log(lpInfo,'InitShareLog: '+ADesc)
  end;
end;

function TLogHeaderHelper.log(const AMsg:shortstring; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean;
begin
  result := writelog(self, AMsg, ATimeout, ACancelEvent)
end;

function WriteLog(var ASharedMem:TSharedMem; const AMsg:shortstring; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean;
var hdr:TLogHeader;
begin
  hdr.logmsg := AMsg;
  for var i := 0 to 10 do
  begin
    result := WriteSharedMem(
      ASharedMem
      , ATimeout, ACancelEvent,
      function (AData:PSharedHeader):boolean
      var
        ALogData:PSharedLog absolute AData;
      begin
  //      hdr.logmsg := format('%s (%.2f%% %d/%d)',[
  //        hdr.logmsg
  //        ,ALogData^.nextPos/sizeof(ALogData.buffer)*100
  //        ,ALogData^.nextPos
  //        ,sizeof(ALogData.buffer)
  //        ]);
        var hdrlen := sizeof(hdr)-sizeof(hdr.logmsg)+length(hdr.logmsg)+1;
        if ALogData^.nextPos+hdrlen >= high(ALogData.buffer) then
        begin
//          ALogData^.nextPos := 0;
{$IFDEF ISCONSOLE}
          writeln(format('**********overrun %d (ALogData^.nextPos+hdrlen (%d) >= (%d) high(ALogData.buffer)',[
            i
            , ALogData^.nextPos+hdrlen
            , high(ALogData.buffer)
            ]));
{$ENDIF}
//          readln;
          result := i >= 10;
          exit;
        end;
        hdr.logtime := now;
        hdr.logcnt := ALogData.writecnt;
        Move(hdr, ALogData^.buffer[ALogData^.nextPos], hdrlen);
        inc(ALogData^.nextPos,hdrlen);
//{$IFDEF ISCONSOLE}
//        writeln(format('[%2.0f%% %4d/%4d] %s',[
//          ALogData^.nextPos/sizeof(ALogData.buffer)*100
//          ,ALogData^.nextPos
//          ,sizeof(ALogData.buffer)
//          ,hdr.logmsg
//          ]));
//{$ENDIF}
        result := true
      end);
    if result then
      break;
//    sleep(100)
  end;
end;

function TLogHeaderHelper.log(const AFmtMsg: shortstring; Args: array of const;
  ATimeout: Cardinal; ACancelEvent: TEvent): boolean;
begin
  result := self.log(format(AFmtMsg,Args), ATimeout, ACancelEvent)
end;

{ TLoggerClient }

constructor TLoggerClient.create;
begin
//  if WithConsole then
//    TConsoleLogger.AddConsoleBuffer
  inherited Create(
    function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
    begin
      if HaveDefaultConsole(WithConsole) then
        TJclConsole.Default.Screens[0].Write(ALogMsg+#13#10);
      SLog^.log(ALogMsg);
      result := AMsg
    end,
    AModuleName,
    AThresholdPriority,
    ADefaultPriority)
end;

end.
