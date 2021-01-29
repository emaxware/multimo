unit uAPILogServer;

interface

uses
  System.SysUtils,
  System.SyncObjs,
//  uAPILib,
  uShareLib,
  uAPILogClient
  ;

function _ReadLog(var SLog:PSharedMem; AWait:cardinal; ACancelEvent:TEvent; ALogRead:TFunc<PLogHeader,string,boolean>):boolean; overload;
procedure _StartAPILogServer(var SLog:PSharedMem; ACancel:TEvent = nil); overload;
procedure StopAPILogServer; overload;

implementation

uses
  System.Classes
  , System.Threading
  , uLoggerLib
  ;

var
  BufferList:TThreadList = nil;
  Cancel:TEvent = nil;
  LogReady:TEvent = nil;

procedure StopAPILogServer;
begin
  Cancel.SetEvent
end;

procedure _StartAPILogServer(var SLog:PSharedMem; ACancel:TEvent);
begin
  if SLog = nil then
    new(SLog);
  if BufferList = nil then
  begin
//    new(APILog);
    Cancel := ACancel;
    if Cancel = nil then
      Cancel := TEvent.create(nil, false, false, '');
    LogReady := TEvent.create(nil, false, false, '');
    BufferList := TThreadList.create;
    var _self:PSharedMem := SLog;
    TThreadPool.Default.QueueWorkItem(
      procedure
      var
        waitRslt:THandleObject;
        handles:THandleObjectArray;
      begin
        try
          var dirty := _self^.dirty;
          if (Cancel = nil) then
            handles := [dirty]
          else
            handles := [Cancel,dirty];

          var result := false;
          repeat
            var rslt := THandleObject.WaitForMultiple(handles, 1000, false, waitRslt);
            case rslt of
              wrTimeout:
                result := true;
              wrSignaled:
                if waitRslt = dirty then
                  result := true
                else
                  break;
              wrAbandoned:
                result := waitRslt = dirty;
              wrError:
              begin
//                var error := GetLastError();
                assertWin32(false, '************** #3');
//{$IFDEF ISCONSOLE}
//                readln;
//{$ENDIF}
                result := false;
              end;
            end;

            while result do
            begin
              var AAPICacheLog:PSharedLog := nil;
              result := WriteSharedMem(_Self^, 500, Cancel,
                function (ASharedHeader:PSharedHeader):boolean
                var AAPILog:PSharedLog absolute ASharedHeader;
                begin
                  result := AAPILog^.nextPos > 0;
                  if not result then
                    exit;
                  var len := sizeof(AAPILog^) - sizeof(AAPILog^.buffer) + AAPILog^.nextPos;
                  GetMem(AAPICacheLog, len);
//                  log('create cache len:%d / writecnt:%d',[len,AAPILog.writecnt]);
                  Move(AAPILog^, AAPICacheLog^, len);
                  AAPILog^.nextPos := 0;
                end);
              if result then
              try
                BufferList.LockList.Add(AAPICacheLog);
                LogReady.SetEvent
              finally
                BufferList.UnlockList
              end;
            end;
          until false;
        finally
          log('APIServer stopping..')
        end;
      end
      );
  end;
end;

function _ReadLog(var SLog:PSharedMem; AWait:cardinal; ACancelEvent:TEvent; ALogRead:TFunc<PLogHeader,string,boolean>):boolean;
var
  handles:THandleObjectArray;
  waitRslt:THandleObject;
begin
  _StartAPILogServer(SLog);
  if (ACancelEvent = nil) then
    handles := [LogReady]
  else
    handles := [ACancelEvent,LogReady];
  result := false;
  repeat
    var rslt := THandleObject.WaitForMultiple(handles, INFINITE, false, waitRslt);
    case rslt of
      wrTimeout:
        result := false;
      wrSignaled, wrAbandoned:
        if waitRslt = LogReady then
          result := true
        else
          break;
      wrError:
      begin
        var error := GetLastError();
        log('************** #4 !!(%d) %s',[error, SysErrorMessage(error)]);
        result := false;
      end;
    end;
    var AAPICacheLog:PSharedLog := nil;
    if result then
      repeat
        var currPos:cardinal := 0;
        var loglist:TList := BufferList.LockList;
        if loglist.Count = 0 then
        begin
          result := false;
          BufferList.unlocklist;
          break;
        end;
        AAPICacheLog := PSharedLog(loglist[0]);
        try
          loglist.Delete(0);
          BufferList.UnlockList;
          while currPos < AAPICacheLog.nextPos do
          try
            var hdr:PLogHeader := PLogHeader(@AAPICacheLog.buffer[currPos]);
            var hdrlen := sizeof(hdr^)-sizeof(hdr.logmsg)+length(hdr.logmsg)+1;
            inc(currpos,hdrlen);
            var AMsg:string := PShortString(@hdr^.logmsg)^;
//            AMsg := format('l#:%5d/w#:%5d %s',[hdr.logcnt,AAPICacheLog.writecnt,AMsg]);
            result := ALogRead(hdr,AMsg);
            if not result then
              break
          except
            on e:exception do
            begin
              log('!!%s:%s',[e.ClassName, e.message])
            end;
          end;
        finally
          FreeMem(AAPICacheLog)
        end;
      until false
  until not result;
end;

end.
