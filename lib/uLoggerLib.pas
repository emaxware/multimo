unit uLoggerLib;

interface

uses
  system.classes
{$IFDEF MSWINDOWS}
  , Winapi.windows
{$ENDIF}
  , System.Sysutils
  , System.Generics.Collections
  , System.Syncobjs
  , System.Threading
  ;


type
  TLogPriority = (lpError,lpWarning,lpInfo,lpDebug,lpVerbose);

var
  CLogPrefix:array[TLogPriority] of string = ('!','?',':','#','.');

type
  ILogger = interface(IUnknown)
  ['{B1A25AF5-8C05-489F-B6D8-934B7806872D}']
    procedure DefLog(const AMsg:string);
    procedure DefLogFmt(const AFmtStr:string; const Args:array of const);
    procedure Log(APriority:TLogPriority; const AMsg:string);
    procedure LogFmt(APriority:TLogPriority;  const AFmtStr:string; const Args:array of const);
    procedure LogDebug(const AMsg:string);
    procedure LogDebugFmt(const AFmtStr:string; const Args:array of const);
    procedure LogError(Ex:Exception;const AMsg:string);
    procedure LogErrorFmt(Ex:Exception;const AFmtStr:string; const Args:array of const);
//    procedure FlushLog;
    procedure StopLog;
    procedure WaitForLogStop;
    function Modulename:string;
  end;

  TOnLog = reference to function(APriority:TLogPriority; const ALogMsg, AMsg:string):string;

  TNullLogger = class(TInterfacedObject, ILogger)
  protected
    procedure DefLog(const AMsg:string);
    procedure DefLogFmt(const AFmtStr:string; const Args:array of const);
    procedure Log(APriority:TLogPriority; const AMsg:string);
    procedure LogFmt(APriority:TLogPriority;  const AFmtStr:string; const Args:array of const);
    procedure LogDebug(const AMsg:string);
    procedure LogDebugFmt(const AFmtStr:string; const Args:array of const);
    procedure LogError(Ex:Exception;const AMsg:string);
    procedure LogErrorFmt(Ex:Exception;const AFmtStr:string; const Args:array of const);
    procedure FlushLog;
    procedure StopLog;
    procedure WaitForLogStop;
    function Modulename:string;
  public
    constructor create;
  end;

  TSimpleLogger = class(TInterfacedObject, ILogger)
  protected
//    class var
      FFormatSettingSync:TFormatSettings;
      FFormatSyncObj:TMutex;// TCriticalSection;
      class var
        fDefLogger:ILogger;
    var
      FPriorityThreshold, FDefaultPriority: TLogPriority;
      FOnLog:TOnLog;
      FModulename:string;
    function FormatLog(APriority:TLogPriority; ADate:TDateTime; AThreadID:integer; const AModuleName, AMsg:string):string;

    procedure DoLog(APriority:TLogPriority; const AMsg:string); virtual;

    procedure DefLog(const AMsg:string);
    procedure DefLogFmt(const AFmtStr:string; const Args:array of const);
    procedure Log(APriority:TLogPriority; const AMsg:string);
    procedure LogFmt(APriority:TLogPriority;  const AFmtStr:string; const Args:array of const);
    procedure LogDebug(const AMsg:string);
    procedure LogDebugFmt(const AFmtStr:string; const Args:array of const);
    procedure LogError(Ex:Exception;const AMsg:string);
    procedure LogErrorFmt(Ex:Exception;const AFmtStr:string; const Args:array of const);
    procedure FlushLog; virtual;
    procedure StopLog; virtual;
    procedure WaitForLogStop; virtual;
    function Modulename:string; virtual;
  public
//    class constructor create;
    constructor create(AOnLog:TOnLog; const AModulename:string; AThresholdPriority:TLogPriority =
{$IFDEF DEBUG}
      lpDebug
{$ELSE}
      lp Info
{$ENDIF}
      ; ADefaultPriority:TLogPriority =
{$IFDEF DEBUG}
      lpDebug
{$ELSE}
      lp Info
{$ENDIF}
      );

    function formatsync(const AFmtStr:string; Args:array of const):string;
    function formatdatetime(ADate:TDateTime):string;
    class function DefLogger:ILogger; overload;

    property ThresholdPriority:TLogPriority read FPriorityThreshold write FPriorityThreshold;
    property DefaultPriority:TLogPriority read FDefaultPriority write FDefaultPriority;
  end;

  TLogMsgRec = record
    msg:string;
    module:string;
    dt:TDateTime;
    p:TLogPriority;
    threadid:integer;
  end;

  TAsyncLogger = class(TSimpleLogger)
  protected
    FThreadPool:TThreadPool;
    FLogMsg:TList<TLogMsgRec>;
    FLogEvent, FLogActive, FLogStopped:TSimpleEvent;
    procedure DoLog(APriority:TLogPriority; const AMsg:string); override;
  public
    constructor create(AThreadPool:TThreadPool;AOnLog:TOnLog;const AModulename:string; AThresholdPriority:TLogPriority =
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

    procedure FlushLog; override;
    procedure StopLog; override;
    procedure WaitForLogStop; override;
  end;

  TSynchroObjectHelper = class helper for TSynchroObject
    function IsSet(ATimeout:Cardinal = INFINITE):boolean;
  end;

  TSyncHelper = class helper for TObject
  public
    procedure lock(AProc:TProc);
  end;

  EAssertWin32 = class(Exception)
  end;

procedure sync(AProc:TThreadProcedure);      overload;
function sync(AProc:TFunc<Boolean>):boolean; overload;
function sync(AProc:TFunc<string>):string; overload;

procedure SetLogger(ALogger:ILogger);
procedure FlushLog;

procedure Log(const AMsg:string); overload;
procedure Log(const AFmtStr:string; const Args:array of const); overload;
procedure Log(APriority:TLogPriority; const AMsg:string); overload;
procedure Log(APriority:TLogPriority; const AFmtStr:string; const Args:array of const); overload;
procedure LogDebug(const AMsg:string); overload;
procedure LogDebug(const AFmtStr:string; const Args:array of const); overload;
procedure Log(Ex:Exception;const AMsg:string); overload;
procedure Log(Ex:Exception;const AFmtStr:string; const Args:array of const); overload;

procedure BreakIfNot(ACondition:Boolean); overload;
procedure BreakIf(ACondition:Boolean); overload;
procedure BreakIf(AObject:TObject); overload;

{$IFDEF MSWINDOWS}
function AssertWin32(IsTrue:boolean; const AFmtStr:string; const Args:array of const; RaiseException:boolean = false):boolean; overload;
function AssertWin32(IsTrue:boolean; const AMsg:string; RaiseException:boolean = false):boolean; overload;

function ProcessFileName(PID: DWORD; Fullpath:boolean): string;
{$ENDIF}

implementation

{$IFDEF MSWINDOWS}
uses
  winapi.psapi
//  , system.syncobjs
  ;

function ProcessFileName(PID: DWORD; Fullpath:boolean): string;
var
  Handle: THandle;
begin
  Result := '';
  Handle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, PID);
  if Handle <> 0 then
  try
    SetLength(Result, MAX_PATH);
//    if FullPath then
//    begin
//      if GetModuleFileNameEx(Handle, 0, PChar(Result), MAX_PATH) > 0 then
//        StrResetLength(Result)
//      else
//        Result := '';
//    end
//    else
//    begin
      var rslt := GetModuleBaseName(Handle, 0, PChar(Result), MAX_PATH);
      if rslt > 0 then
        setlength(result, rslt)
      else
        Result := '';
//    end;
  finally
    CloseHandle(Handle);
  end;
end;


function AssertWin32(IsTrue:boolean; const AFmtStr:string; const Args:array of const; RaiseException:boolean = false):boolean; overload;
begin
  result := AssertWin32(IsTrue, Format(AFmtStr,Args), RaiseException)
end;

function AssertWin32(IsTrue:boolean; const AMsg:string; RaiseException:boolean = false):boolean;
begin
  result := true;
  if IsTrue then
    log('%s succeeded',[AMsg])
  else
  begin
    result := false;
    var error := GetLastError;
    var msg := Format('%s: %d %s',[AMsg, error, SysErrorMessage(error)]);
    log(lpError, msg);
    if RaiseException then
      raise EAssertWin32.Create(msg);
  end
end;
{$ENDIF}

procedure BreakIf(ACondition:Boolean);
begin
  if ACondition then
//  asm
//    int 3
//  end;
end;

procedure BreakIfNot(ACondition:Boolean);
begin
  BreakIf(not ACondition)
end;

procedure BreakIf(AObject:TObject);
begin
  BreakIf(AObject = nil)
end;


procedure SetLogger(ALogger:ILogger);
begin
  TSimpleLogger.fDefLogger := ALogger
end;

procedure FlushLog;
begin
  TSimpleLogger.fDefLogger.StopLog
end;

procedure Log(const AMsg:string);
begin
  TSimpleLogger.fDefLogger.DefLog(AMsg)
end;

procedure Log(const AFmtStr:string; const Args:array of const);
begin
  TSimpleLogger.fDefLogger.DefLogFmt(AFmtStr,Args)
end;

procedure Log(APriority:TLogPriority; const AMsg:string); overload;
begin
  TSimpleLogger.fDefLogger.Log(APriority,AMsg)
end;

procedure Log(APriority:TLogPriority;  const AFmtStr:string; const Args:array of const);
begin
  TSimpleLogger.fDefLogger.LogFmt(APriority, AFmtStr, Args)
end;

procedure LogDebug(const AMsg:string);
begin
  TSimpleLogger.fDefLogger.LogDebug(AMsg)
end;

procedure LogDebug(const AFmtStr:string; const Args:array of const);
begin
  TSimpleLogger.fDefLogger.LogDebugFmt(AFmtStr,Args)
end;

procedure Log(Ex:Exception;const AMsg:string);
begin
  TSimpleLogger.fDefLogger.LogError(Ex,AMsg)
end;

procedure Log(Ex:Exception;const AFmtStr:string; const Args:array of const);
begin
  TSimpleLogger.fDefLogger.LogErrorFmt(Ex,AFmtStr,Args)
end;

procedure sync(AProc:TThreadProcedure);
begin
  TThread.Synchronize(
    nil
    , AProc
    );
end;

function sync(AProc:TFunc<Boolean>):boolean; overload;
var rslt:boolean;
begin
  TThread.Synchronize(
    nil
    , procedure
      begin
        rslt := AProc;
      end
    );
  result := rslt
end;

function sync(AProc:TFunc<string>):string; overload;
var rslt:string;
begin
  TThread.Synchronize(
    nil
    , procedure
      begin
        rslt := AProc;
      end
    );
  result := rslt
end;

{ TSyncHelper }

procedure TSyncHelper.lock(AProc: TProc);
begin
  TMonitor.Enter(Self);
  try
    AProc
  finally
    TMonitor.Exit(self)
  end
end;

{ TSynchroObjectHelper }

function TSynchroObjectHelper.IsSet;
begin
  result := WaitFor(ATimeout) = TWaitResult.wrSignaled
end;

{ TSimpleLogger }

procedure TSimpleLogger.Log(APriority:TLogPriority; const AMsg: string);
begin
  DoLog(APriority,AMsg)
end;

procedure TSimpleLogger.LogFmt(APriority:TLogPriority; const AFmtStr: string; const Args: array of const);
begin
  Log(APriority,FormatSync(AFmtStr,Args))
end;

function TSimpleLogger.Modulename: string;
begin
  result := FModulename
end;

procedure TSimpleLogger.StopLog;
begin

end;

procedure TSimpleLogger.WaitForLogStop;
begin

end;

procedure TSimpleLogger.LogDebug(const AMsg: string);
begin
  Log(lpDebug,AMsg)
end;

procedure TSimpleLogger.LogDebugFmt(const AFmtStr: string;
  const Args: array of const);
begin
  LogDebug(FormatSync(AFmtStr,Args))
end;

procedure TSimpleLogger.LogError(Ex: Exception; const AMsg: string);
begin
  if ex <> nil then
    Log(lpError,FormatSync('%s:%s!! %s',[Ex.classname,Ex.message,AMsg]))
  else
    Log(lpError,FormatSync('!! %s',[AMsg]))
end;

procedure TSimpleLogger.LogErrorFmt(Ex: Exception; const AFmtStr: string;
  const Args: array of const);
begin
  LogError(Ex,FormatSync(AFmtStr,Args))
end;

constructor TSimpleLogger.create(AOnLog: TOnLog; const AModulename: string;
  AThresholdPriority, ADefaultPriority: TLogPriority);
begin
  inherited create;
  FOnLog := AOnLog;
  FPriorityThreshold := AThresholdPriority;
  FDefaultPriority := ADefaultPriority;
  FModulename := AModulename;
  FFormatSyncObj := TMutex.create;// TCriticalSection.Create;
  FFormatSettingSync := FormatSettings;
end;

//class constructor TSimpleLogger.create;
//begin
//  FFormatSyncObj := TMutex.create;// TCriticalSection.Create;
//  FFormatSettingSync := FormatSettings;
//end;

procedure TSimpleLogger.DefLog(const AMsg: string);
begin
  Log(FDefaultPriority, AMsg)
end;

class function TSimpleLogger.DefLogger: ILogger;
begin
  result := fDefLogger
end;

procedure TSimpleLogger.DefLogFmt(const AFmtStr: string;
  const Args: array of const);
begin
  LogFmt(FDefaultPriority, AFmtStr, Args)
end;

threadvar
  ThreadID:integer;

procedure TSimpleLogger.DoLog(APriority: TLogPriority; const AMsg: string);
begin
  if assigned(FOnLog) and (APriority <= FPriorityThreshold) then
  begin
    if ThreadID = 0 then
      ThreadID := TThread.Current.ThreadID;
    FOnLog(APriority,FormatLog(APriority,Now,ThreadID,FModuleName,AMsg),AMsg)
  end
end;

procedure TSimpleLogger.FlushLog;
begin

end;

function TSimpleLogger.formatdatetime(ADate: TDateTime): string;
var
  d1, d2, d3, d4, d5, d6, d7:word;
begin
  DecodeDate(ADate, d1, d2, d3);
  DecodeTime(ADate, d4, d5, d6, d7);
  result := FormatSync('%4d%2.2d%2.2dT%2.2d%2.2d%2.2d.%3.3d',[d1,d2,d3,d4,d5,d6,d7])
end;

function TSimpleLogger.FormatLog(APriority: TLogPriority; ADate:TDateTime; AThreadID:integer; const AModuleName, AMsg: string): string;
begin
//  if AModuleName = '' then
//    result := format('%s%s-%10s-%8d-%s',[
//      CLogPrefix[APriority]
//      , formatdatetime('yyyymmdd"T"hhnnss.zzz',ADate)
//      , ''
//      , ThreadID
//      , AMsg
//      ])
//  else
  try
    result := //AMsg;
      formatsync('%s%s-%-10s-%8d-%s',[
      CLogPrefix[APriority]
      , formatdatetime(ADate)
      , AModuleName
      , AThreadID
      , AMsg
      ])
  except
    on e:exception do
      result := 'FormatLog: ' + AMsg + ' !!' + e.classname + ' ' + e.message
  end;
end;

function TSimpleLogger.formatsync(const AFmtStr: string;
  Args: array of const): string;
begin
  FFormatSyncObj.Acquire;
  try
    try
      result := Format(AFmtStr,Args,FFormatSettingSync)
    except
      on e:exception do
        result := 'formatsync: ' + AFmtStr + ' !!' + e.classname + ' ' + e.message
    end;
  finally
    FFormatSyncObj.Release
  end;
end;

{ TAsyncLogger }

constructor TAsyncLogger.create;
begin
  inherited create(AOnLog,AModulename,AThresholdPriority,ADefaultPriority);
  FThreadPool := AThreadPool;
  FLogMsg := TList<TLogMsgRec>.create;
  FLogEvent := TSimpleEvent.Create(nil, false, false, '');
  FLogActive := TSimpleEvent.Create(nil, True, True, '');
  FLogStopped := TSimpleEvent.Create(nil, True, false, '');

  FThreadPool.QueueWorkItem(
    procedure
    begin
      FlushLog
    end
  );
end;

procedure TAsyncLogger.FlushLog;
var msgrec:TLogMsgRec;
begin
  while FLogEvent.IsSet do
  try
//        TThread.Synchronize(
//          nil
//          , procedure
//          begin
        TMonitor.Enter(FLogMsg);
        try
          while FLogMsg.Count > 0 do
          begin
            msgrec := FLogMsg.Items[0];
            FLogMsg.Delete(0);
            TMonitor.Exit(FLogMsg);
            try
              FOnLog(msgrec.p,FormatLog(msgrec.p,msgrec.dt,msgrec.threadid,msgrec.module,msgrec.msg),msgrec.msg)
            finally
              TMonitor.Enter(FLogMsg)
            end
          end
        finally
          TMonitor.Exit(FLogMsg);
        end;
//          end
//          );
    if not FLogActive.IsSet(0) then
      break;
  finally
//    FLogEvent.ResetEvent
  end;
  FLogStopped.SetEvent
end;

procedure TAsyncLogger.StopLog;
begin
  FLogActive.ResetEvent;
  FLogEvent.SetEvent;
  WaitForLogStop
end;

procedure TAsyncLogger.WaitForLogStop;
begin
  FLogStopped.IsSet
end;

threadvar
  ASyncThreadID:integer;

procedure TAsyncLogger.DoLog(APriority: TLogPriority; const AMsg: string);
var
  AMsgRec:TLogMsgRec;
begin
  if APriority > FPriorityThreshold then
    exit;
  TMonitor.Enter(FLogMsg);
  try
    if ASyncThreadID = 0 then
      ASyncThreadID := TThread.Current.ThreadID;
    AMsgRec.p := APriority;
    AMsgRec.dt := now;
    AMsgRec.msg := AMsg;
    AMsgRec.module := FModulename;
    AMsgRec.threadid := ASyncThreadID;
    FLogMsg.Add(AMsgRec);
//    if FLogMsg.Count > 1024 then
//      FlushBuffer
  finally
    TMonitor.Exit(FLogMsg);
    FLogEvent.SetEvent
  end;
end;

{ TNullLogger }

constructor TNullLogger.create;
begin
  inherited create
end;

procedure TNullLogger.DefLog(const AMsg: string);
begin

end;

procedure TNullLogger.DefLogFmt(const AFmtStr: string;
  const Args: array of const);
begin

end;

procedure TNullLogger.FlushLog;
begin

end;

procedure TNullLogger.Log(APriority: TLogPriority; const AMsg: string);
begin

end;

procedure TNullLogger.LogDebug(const AMsg: string);
begin

end;

procedure TNullLogger.LogDebugFmt(const AFmtStr: string;
  const Args: array of const);
begin

end;

procedure TNullLogger.LogError(Ex: Exception; const AMsg: string);
begin

end;

procedure TNullLogger.LogErrorFmt(Ex: Exception; const AFmtStr: string;
  const Args: array of const);
begin

end;

procedure TNullLogger.LogFmt(APriority: TLogPriority; const AFmtStr: string;
  const Args: array of const);
begin

end;

function TNullLogger.Modulename: string;
begin

end;

procedure TNullLogger.StopLog;
begin

end;

procedure TNullLogger.WaitForLogStop;
begin

end;

initialization
  SetLogger(TNullLogger.create)

end.
