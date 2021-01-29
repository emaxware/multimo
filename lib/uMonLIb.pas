unit uMonLIb;

interface

uses
  WinApi.windows,
  System.SyncObjs,
  uAPILib
  ;

type
  TMonDefs = TArray<TMonitorDef>;

function InitMonitors(AReset:boolean):TMonDefs;
procedure PrintMonDefs(AMonDefs:TMonDefs);
function MonDefsChanged(AOrigMonDefs, ANewMonDefs:TMonDefs):boolean;

implementation

uses
  Winapi.AccCtrl
  , Winapi.AclAPI
  , Winapi.psapi
//  , Winapi.shellscaling
//  , System.Win.Comobj
  , Winapi.multimon
  , System.SysUtils
  , FMX.Platform
  , FMX.Types
  , uLoggerLib
  ;

procedure PrintMonDefs(AMonDefs:TMonDefs);
begin
  var i:integer := 0;
  for var mon in AMonDefs do
  begin
    log(format('#%2d %5d,%5d %5d,%5d (%5d,%5d) primary:%d "%s"',[
      i, mon.orig.x, mon.orig.y, mon.size.width, mon.size.height
      , mon.virtSize.width, mon.virtSize.height//, mon.xscale, mon.yscale
      , ord(mon.primary)
      , mon.monname]));
    inc(i)
  end;
end;

function MonDefsChanged(AOrigMonDefs, ANewMonDefs:TMonDefs):boolean;
begin
  result := length(AOrigMonDefs) <> length(ANewMonDefs);
  if not result then
  begin
    var index := 0;
    for var mon in AOrigMonDefs do
    begin
      var ANewMon := ANewMonDefs[index];
      result :=
        (ANewMon.orig <> mon.orig)
        or (ANewMon.size <> mon.size)
        or (ANewMon.primary <> mon.primary);
      if result then
        break;
      inc(index)
    end
  end
end;

var
  FMons:IFMXMultiDisplayService = nil;
  FMachineName:string = 'UNKNOWN';
  FMonDefs:TMonDefs;

type
  TEnumMonHelper = record
    nextMonIndex:integer;
    monDefs:array[0..20] of TMonitorDef;
  end;
  PEnumMonHelper = ^TEnumMonHelper;

const
  ENUM_CURRENT_SETTINGS=$FFFFFFFE;

function EnumMonitorProc(hm: HMONITOR; dc: HDC; r: PRect; l: LPARAM): Boolean; stdcall;
var monDefsRec:PEnumMonHelper absolute l;
var monitorInfo:TMonitorInfoEx;
var devMode:TDevMode;
begin
  monitorInfo.cbSize := sizeof(monitorInfo);
  devMode.dmSize := sizeof(devMode);
  if GetMonitorInfo(hm, @monitorInfo) then
    with monitorInfo, monDefsRec^, monDefs[nextMonIndex] do
    begin
      orig.x := rcMonitor.Left;
      orig.y := rcMonitor.Top;
      virtSize.width := rcMonitor.Width;
      virtSize.height := rcMonitor.Height;
//      virtscreenwidth := GetSystemMetrics(SM_CXVIRTUALSCREEN);
//      virtscreenheight := GetSystemMetrics(SM_CYVIRTUALSCREEN);
//      defIndex := nextMonIndex;
      primary := monitorInfo.dwFlags = MONITORINFOF_PRIMARY;
      var name := StrPas(Pchar(@szDevice));
      monname := name;
      if EnumDisplaySettings(szDevice, ENUM_CURRENT_SETTINGS, devMode) then
      begin
        size.width := devMode.dmPelsWidth;
        size.height := devMode.dmPelsHeight;
      end;
      inc(nextMonIndex);
      result := true;
    end;
end;

function InitMonitors(AReset:boolean):TMonDefs;
begin
  if FMons = nil then
  begin
    FMachineName := ProcessFileName(GetCurrentProcessID, false);
    TPlatformServices.Current.SupportsPlatformService(IFMXMultiDisplayService, FMons);
    AReset := true
  end;

  if AReset then
  begin
    var tmpMonDefs:TMonDefs;
    var monList:TEnumMonHelper;
    monList.nextMonIndex := 0;
    EnumDisplayMonitors(0, nil, @EnumMonitorProc, Winapi.Windows.LPARAM(@monList));

    SetLength(tmpMonDefs, monList.nextMonIndex);

    var activeIndex:integer;
    for var i := 0 to monList.nextMonIndex-1 do
    begin
      if monLIst.monDefs[i].primary then
        activeIndex := i;
      tmpMonDefs[i] := monList.monDefs[i];
      tmpMOnDefs[i].index := i;
      with tmpMOnDefs[i] do
        if size.cx > size.cy then
          polarSize := size.cy
        else
          polarSize := size.cx
    end;
    var primaryMon := tmpMonDefs[activeIndex];
    for var i := 0 to monList.nextMonIndex-1 do
    begin
      tmpMonDefs[i].primarySize := primaryMon.size;
    end;
    FMonDefs := tmpMonDefs
  end;
  result := FMonDefs
end;

procedure StrResetLength(var S: UnicodeString);
var
  I: integer;
begin
  for I := 0 to Length(S) - 1 do
    if S[I + 1] = #0 then
    begin
      SetLength(S, I);
      Exit;
    end;
end;

end.
