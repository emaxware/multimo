unit uAPILib;

interface

uses
  Winapi.windows,
  System.SysUtils,
  System.SyncObjs,
//  uMonLib,
  uShareLib
  ;

const
  APIName = '';

type
  TMonitorDef = record
    index:uint8;
    orig:TPoint;
    virtSize:TSize;
    size:TSize;
    primarySize:TSize;
    polarSize:integer;
//    xscale, yscale:double;
    monname:string[50];
    machinename:string[50];
    primary:boolean;
  end;
  PMonitorDef = ^TMonitorDef;

  TSharedConfig = record
    timestamp:TDateTime;
    writecnt:cardinal;
    nextMonitorDef:UInt8;
    CBTHook, MouseHook:HHOOK;
    monitorDefs:array[0..50] of TMonitorDef;
  end;
  PSharedConfig = ^TSharedConfig;

var
  APIConfig:TSharedMem;
//  APILog:TSharedMem;

function InitAPI(var Count:uint8):boolean;
procedure CloseAPI;

implementation

uses
  Winapi.AccCtrl
  , Winapi.AclAPI
  , Winapi.psapi
  , Winapi.multimon
  , FMX.Platform
  , FMX.Types
  , uAPILogClient
  ;

procedure CloseAPI;
begin
  CloseSharedMem(APIConfig);
//  CloseSharedMem(APILog);
end;

var
  InitAPIRun:boolean = false;
  InitAPICount:uint8 = 0;

function InitAPI(var Count:uint8):boolean;
begin
  result := initAPIRun;

  if not result then
  begin
    var _count:uint8;
    result :=
      OpenSharedMem(APIName+'Config', APIConfig, sizeof(TSharedConfig))
//      and OpenSharedMem(APIName+'Log', APILog, sizeof(TSharedLog),
//        function(AData:PSharedHeader):boolean
//        var ALogData:PSharedLog absolute AData;
//        begin
//          inc(ALogData^.count);
////          _Count := ALogData^.count;
//          APILog.refcnt := ALogData^.count;
//          result := true
//        end)
      ;
    InitAPICount := _count;
    InitAPIRun := result;
  end;
  Count := InitAPICount
end;

end.
