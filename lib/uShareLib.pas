unit uShareLib;

interface

uses
  Winapi.windows,
  System.SysUtils,
  System.SyncObjs
  ;

type
  TSharedHeader = record
    timestamp:TDateTime;
    writecnt:cardinal;
  end;
  PSharedHeader = ^TSharedHeader;

  TSharedMem = record
    name:string;
    size:cardinal;
    lasttime:TDateTime;
    lastwritecnt:cardinal;
    refcnt:byte;
    busy:TMutex;
    dirty:TEvent;
    hmapping:THandle;
    data2:PSharedHeader;
  end;
  PSharedMem = ^TSharedMem;

function OpenSharedMem(const AName:string; var ASharedMem:TSharedMem; ASize:cardinal; AInit:TFunc<PSharedHeader,boolean> = nil):boolean;
procedure CloseSharedMem(var ASharedMem:TSharedMem);

function WaitForSharedMem(var ASharedMem:TSharedMem; ATimeout:cardinal; ACancelEvent:TEvent; AWhileLocked:TFunc<PSharedHeader,boolean>):boolean;
function WriteSharedMem(var ASharedMem:TSharedMem; ATimeout:cardinal; ACancelEvent:TEvent; AWriter:TFunc<PSharedHeader,boolean>):boolean;
function ReadSharedMem(var ASharedMem:TSharedMem; ASignalTimeout, AReadTimeout:cardinal; ACancelEvent:TEvent; AReader:TFunc<PSharedHeader,boolean>):boolean;

implementation

uses
  Winapi.AccCtrl
  , Winapi.AclAPI
  , Winapi.psapi
  , Winapi.multimon
  , FMX.Platform
  , FMX.Types
  , uLoggerLib
  ;

const
  SharedMem = 'MM';

function WaitForSharedMem(var ASharedMem:TSharedMem; ATimeout:cardinal; ACancelEvent:TEvent; AWhileLocked:TFunc<PSharedHeader,boolean>):boolean;
begin
  var signal := ASharedMem.busy;
  var waitRslt:THandleObject;
  var handles:THandleObjectArray;
  if (ACancelEvent = nil) then
    handles := [signal]
  else
    handles := [ACancelEvent,signal];
  var rslt := THandleObject.WaitForMultiple(handles, ATimeout, false, waitRslt);
  case rslt of
    wrTimeout:
      result := false;
    wrSignaled:
      result := waitRslt = signal;
    wrAbandoned:
      result := waitRslt = signal;
    wrError:
    begin
      var error := GetLastError();
      assertwin32(false, '************** #2');
{$IFDEF ISCONSOLE}
      readln;
{$ENDIF}
      result := false;
    end;
  end;
  if result then
  try
    result := AWhileLocked(ASharedMem.data2);
    ASharedMem.lasttime := ASharedMem.data2^.timestamp;
    ASharedMem.lastwritecnt := ASharedMem.data2^.writecnt;
  finally
    ASharedMem.busy.Release
  end;
end;

function WriteSharedMem(var ASharedMem:TSharedMem; ATimeout:cardinal; ACancelEvent:TEvent; AWriter:TFunc<PSharedHeader,boolean>):boolean;
begin
  var dirty := ASharedMem.dirty;
  result := WaitForSharedMem(ASharedMem, ATimeout, ACancelEvent,
    function(AData:PSharedHeader):boolean
    begin
      result := AWriter(AData);
      if result then
      begin
        AData^.timestamp := now;
        inc(AData^.writecnt);
        dirty.SetEvent;
//        sleep(0)
      end
    end)
end;

function ReadSharedMem(var ASharedMem:TSharedMem; ASignalTimeout, AReadTimeout:cardinal; ACancelEvent:TEvent; AReader:TFunc<PSharedHeader,boolean>):boolean;
begin
  var dirty := ASharedMem.dirty;
  var waitRslt:THandleObject;
  var handles:THandleObjectArray;
  if (ACancelEvent = nil) then
    handles := [dirty]
  else
    handles := [ACancelEvent,dirty];
  var rslt := THandleObject.WaitForMultiple(handles, ASignalTimeout, false, waitRslt);
  case rslt of
    wrTimeout:
      result := true;
    wrSignaled:
      result := waitRslt = dirty;
    wrAbandoned:
      result := waitRslt = dirty;
    wrError:
    begin
      AssertWin32(false,'************** #1 ',[error, SysErrorMessage(error)]);
{$IFDEF ISCONSOLE}
      readln;
{$ENDIF}
      result := false;
    end;
  end;
  if result then
  try
    var lastwritecnt := ASharedMem.lastwritecnt;
    var read := false;
    result := WaitForSharedMem(ASharedMem, AReadTimeout, ACancelEvent,
      function(AData:PSharedHeader):boolean
      begin
        result := false;
        if (AData^.writecnt <> lastwritecnt) then
        begin
          read := true;
          result := AReader(AData);
        end
      end);
    result := read
  except
    on e:exception do
    begin
      log(e, 'ReadSharedMem')
    end;
  end
end;

const PROTECTED_DACL_SECURITY_INFORMATION     =$80000000;

procedure MakeObjectShareable(AHandle:THandle);
begin
  CheckOSError(SetSecurityInfo(AHandle
    , SE_KERNEL_OBJECT
    , DACL_SECURITY_INFORMATION or PROTECTED_DACL_SECURITY_INFORMATION
    , nil
    , nil
    , nil
    , nil))
end;

procedure CloseSharedMem(var ASharedMem:TSharedMem);
begin
  ASharedMem.busy.Free;
  ASharedMem.dirty.free;
  UnmapViewOfFile(ASharedMem.data2);
  CloseHandle(ASharedMem.hmapping);
end;

function OpenSharedMem(const AName:string; var ASharedMem:TSharedMem; ASize:cardinal; AInit:TFunc<PSharedHeader,boolean>):boolean;
begin
  result := false;
  FillChar(ASharedMem, sizeof(ASharedMem), 0);
  ASharedMem.name := AName;
  ASharedMem.size := ASize;

  var hmapping := OpenFileMapping(FILE_MAP_ALL_ACCESS, true, pchar('Global\'+SharedMem+AName));
  var error := GetLastError();

  if hmapping = 0 then
  begin
    if error <> ERROR_FILE_NOT_FOUND then
      RaiseLastOSError(error);
    hmapping := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE, 0, ASize, pchar('Global\'+SharedMem+AName));
    if hmapping = 0 then
      RaiseLastOSError;
    MakeObjectShareable(hmapping);
    ASharedMem.busy := TMutex.create(nil, false, 'Global\'+SharedMem+AName+'busy');
    MakeObjectShareable(ASharedMem.busy.Handle);
    ASharedMem.dirty := TEvent.Create(nil, true, false, 'Global\'+SharedMem+AName+'signal');
    MakeObjectShareable(ASharedMem.dirty.Handle);
  end
  else
  begin
    ASharedMem.busy := TMutex.create(nil, false, 'Global\'+SharedMem+AName+'busy');
    ASharedMem.dirty := TEvent.Create(nil, true, false, 'Global\'+SharedMem+AName+'signal');
  end;

  ASharedMem.hmapping := hmapping;
  try
    if (ASharedMem.hmapping = 0) then
      RaiseLastOSError(error);

    var AlreadyExisted := (GetLastError()=ERROR_ALREADY_EXISTS);

    ASharedMem.data2 := MapViewOfFile(ASharedMem.hmapping, FILE_MAP_ALL_ACCESS, 0, 0, ASize);
    if ASharedMem.data2 = nil then
      RaiseLastOSError;

    ASharedMem.lasttime := 0;

    if ASharedMem.busy.WaitFor(INFINITE) in [wrSignaled,wrAbandoned] then
    try
      result := true;
      if not AlreadyExisted then
      begin
        FillChar(ASharedMem.data2^, ASize, 0);
        ASharedMem.data2^.timestamp := now;
        result := true;
      end;
      ASharedMem.lasttime := ASharedMem.data2^.timestamp;
      ASharedMem.lastwritecnt := ASharedMem.data2^.writecnt;
      if assigned(AInit) then
        result := AInit(ASharedMem.data2)
    finally
      ASharedMem.busy.release
    end;
  finally
    if not result then
    begin
      if ASharedMem.data2 <> nil then
        UnmapViewOfFile(ASharedMem.data2);
      if ASharedMem.hmapping <> 0 then
        CloseHandle(ASharedMem.hmapping);
    end
  end;
end;

end.
