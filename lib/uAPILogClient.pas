unit uAPILogClient;

interface

uses
  System.SyncObjs
  , uShareLib
  , winapi.windows
//  , uAPILib
  ;

const
  LogBufferSize =
//    256;
    100 * 1024;

type
  TLogHeader = record
    logtime:TDatetime;
    logcnt:cardinal;
    logmsg:ShortString;
  end;
  PLogHeader = ^TLogHeader;

  TSharedLog = record
    timestamp:TDateTime;
    writecnt:cardinal;
    count:Uint8;
    nextPos:UInt32;
    buffer:array[0..LogBufferSize] of byte;
  end;
  PSharedLog = ^TSharedLog;

  TLogHeaderHelper = record helper for TSharedMem
    function log(const AMsg:shortstring; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean; overload;
    function log(const AFmtMsg:shortstring; Args:array of const; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean; overload;
  end;

  function writelog(var ASharedMem:TSharedMem; const AMsg:shortstring; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean; overload;

function InitShareLog(const ADesc:string; Async:boolean = false):boolean;

var
  SLog:PSharedMem = nil;

implementation

uses
  System.SysUtils
  , winapi.psapi
  , uLoggerLib
  ;

function InitShareLog(const ADesc:string; Async:boolean = false):boolean;
begin
  result := false;
  if SLog = nil then
  begin
    result := true;
//    APIDLLStarted := true;
    new(SLog);
    OpenSharedMem('Log', SLog^, sizeof(TSharedLog),
      function(AData:PSharedHeader):boolean
      var ALogData:PSharedLog absolute AData;
      begin
        inc(ALogData^.count);
        SLog^.refcnt := ALogData^.count;
        result := true
      end);

    SetLogger(
      TSimpleLogger.create(
//        TThreadPool.Default,
        function(APriority:TLogPriority; const ALogMsg, AMsg:string):string
        begin
{$IFDEF ISCONSOLE}
          writeln(ALogMsg);
{$ENDIF}
          SLog^.log(ALogMsg);
          result := AMsg
        end
        , ProcessFileName(GetCurrentProcessID, false) + '-' + ADesc
        , lpInfo
//{$IFDEF INDLL}
//        , 'MULTIMODLL'
//{$ELSE}
//        , 'MULTIMOCLI'
//{$ENDIF}
      ));

      log(lpInfo,'InitShareLog: '+ADesc)
  end;
end;

function TLogHeaderHelper.log(const AMsg:shortstring; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean;
begin
  result := writelog(self, AMsg, ATimeout, ACancelEvent)
end;

function writelog(var ASharedMem:TSharedMem; const AMsg:shortstring; ATimeout:Cardinal = 500; ACancelEvent:TEvent = nil):boolean;
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

end.
