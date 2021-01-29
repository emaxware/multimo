unit uEventLib;

interface

uses
  Winapi.windows
  , System.types
  , uMonLib
  , uAPILib
  ;

type
  TInputType = (tiMouse, tiKeybd, tiNull);

  TPointHelper = record helper for TPoint
    function FromMonToScaled(AMonitor:TMonitorDef):TPoint;
    function FromMonToMouse(AMonitor:TMonitorDef):TPoint;
    function FromMonToPolar(AMonitor:TMonitorDef):TPointF;
    function FromDeskToScale(AMonitor:TMonitorDef):TPoint;
    function FromMouseToMon(AMonitor:TMonitorDef):TPoint;
    function FromMouseToNorm(AMonitor:TMonitorDef):TPoint;
    function FromScaledToDesk(AMonitor:TMonitorDef):TPoint;
    function FromScaledToMon(AMonitor:TMonitorDef):TPoint;

    function FromDeskPtToMonPt(
      AMonDefs:TMonDefs;
      var monWithPt:integer;
      var AMousePoint, AMonPoint, ASclPoint, ANormPoint: TPoint;
      var APolarPoint: TPointF;
      var AMonDef:TMonitorDef
      ):boolean;

    function FromMousePtToMonPt(
      AMonDefs: TMonDefs;
      var monWithPt:integer;
      var ADeskPoint, AMonPoint, ASclPoint, ANormPoint: TPoint;
      var APolarPoint: TPointF;
      var AMonDef: TMonitorDef
      ):boolean;
  end;

  TMonitorRecHelper = record helper for TMonitorDef
    function toRect:TRect;
    function toVirtRect:TRect;
  end;

  TInputEvent = record
  private
    ts:TDatetime;
    dwFlags: DWORD;

//    procedure WndProc:
    procedure InternalMoveTo(dx, dy:integer); overload;
  public
    constructor createMouse(dwFlags, dx, dy, dwData:integer);
    procedure Emit;
    procedure Clear;
    procedure MoveTo(x, y:integer); overload;
    procedure MoveTo(dx, dy:extended); overload;
    procedure MoveTo(AMonitor:TMonitorDef; x, y:integer); overload;
    procedure MoveTo(AMonitor:TMonitorDef; x, y:double); overload;
    procedure MoveTo(AMonitor:TMonitorDef; pt:TPoint); overload;
    procedure MoveTo(AMonitor:TMonitorDef; pt:TPointF); overload;

    case event:TInputType of
      tiMouse:(
        dx, dy: integer;
        dwData: DWORD;
      );
      tiKeybd:(
        bVk: Byte;
        bScan: Byte;
      );
  end;
  PInputEvent = ^TInputEvent;

implementation

uses
  System.SysUtils
  , uLoggerLib
  ;

{ TInputEvent }

procedure TInputEvent.Clear;
begin
  event := tiNull
end;

constructor TInputEvent.createMouse(dwFlags, dx, dy, dwData: integer);
begin
  event := tiMouse;
  self.ts := now;
  self.dwFlags := dwFlags;
  self.dx := dx;
  self.dy := dy;
  self.dwData := dwData;
end;

procedure TInputEvent.InternalMoveTo(dx, dy: integer);
begin
  self.event := tiMouse;
  self.ts := now;
  self.dx := dx;
  self.dy := dy;
  self.dwFlags := MOUSEEVENTF_MOVE or MOUSEEVENTF_ABSOLUTE;
end;

procedure TInputEvent.MoveTo(AMonitor: TMonitorDef; x, y: integer);
begin
  log(format('TInputEvent.MoveTo %d %d -> %d %d'
//    +#13#10'integer(trunc(x:%d * MAXWORD:%d / GetSystemMetrics(SM_CXSCREEN):%d)+AMonitor.orig.x:%d)'
    ,[
    x, y
    , integer((AMonitor.orig.x+x) * MAXWORD div AMonitor.primarySize.cx)
    , integer((AMonitor.orig.y+y) * MAXWORD div AMonitor.primarySize.cy)
//    , x
//    , MAXWORD
//    , GetSystemMetrics(SM_CXSCREEN)
//    , AMonitor.orig.x
    ]));
  InternalMoveTo(
    integer((AMonitor.orig.x+x) * MAXWORD div AMonitor.primarySize.cx)
    , integer((AMonitor.orig.y+y) * MAXWORD div AMonitor.primarySize.cy)
    )
end;

procedure TInputEvent.MoveTo(AMonitor: TMonitorDef; x, y: double);
begin
  MoveTo(AMonitor
    , integer(trunc(AMonitor.size.width * (x + 0.5)))
    , integer(trunc(AMonitor.size.height * (0.5 - y))))
end;

procedure TInputEvent.MoveTo(AMonitor: TMonitorDef; pt: TPoint);
begin
  MoveTo(AMonitor, pt.x, pt.Y)
end;

procedure TInputEvent.MoveTo(AMonitor: TMonitorDef; pt: TPointF);
begin
  MoveTo(AMonitor, pt.x, pt.Y)
end;

procedure TInputEvent.MoveTo(x, y: integer);
begin
  InternalMoveTo(x, y)
end;

procedure TInputEvent.MoveTo(dx, dy: extended);
begin
  InternalMoveTo(
    integer(trunc((dx + 0.5) * MAXWORD / GetSystemMetrics(SM_CXVIRTUALSCREEN)))
    , integer(trunc((0.5 - dy) * MAXWORD / GetSystemMetrics(SM_CYVIRTUALSCREEN))))
end;

procedure TInputEvent.Emit;
begin
  if Self.event = tiMouse then
  begin
    log(format('mouse_event %d,%d',[self.dx, self.dy]));
    mouse_event(Self.dwFlags, self.dx, self.dy, self.dwData, 0)
  end
end;

{ TPointHelper }

function TPointHelper.FromDeskToScale(AMonitor: TMonitorDef): TPoint;
begin
  result.SetLocation(
    self.X - AMonitor.orig.X
    , self.Y - AMonitor.orig.Y
    );
end;

function TPointHelper.FromMonToMouse(AMonitor: TMonitorDef): TPoint;
begin
  result := self.FromScaledToDesk(AMonitor)
end;

function TPointHelper.FromMonToPolar(AMonitor: TMonitorDef): TPointF;
begin
  result.SetLocation(
    self.X / AMonitor.size.width - 0.5
         , 0.5 - self.Y / AMonitor.size.height
  );
end;

function TPointHelper.FromMonToScaled(AMonitor: TMonitorDef): TPoint;
begin
  result.setlocation(
    self.X * AMonitor.virtSize.cx div AMonitor.size.cx
    , self.Y * AMonitor.virtSize.cy div AMonitor.size.cy
  );
end;

function TPointHelper.FromMouseToMon(AMonitor: TMonitorDef): TPoint;
begin
  result := self.FromDeskToScale(AMonitor)
end;

function TPointHelper.FromMouseToNorm(AMonitor: TMonitorDef): TPoint;
begin
  result.SetLocation(
    self.x * MAXWORD div AMonitor.primarySize.cx
    , self.y * MAXWORD div AMonitor.primarySize.cy
  );
end;

function TPointHelper.FromScaledToDesk(AMonitor: TMonitorDef): TPoint;
begin
  result.SetLocation(
    self.X + AMonitor.orig.X
    , self.Y + AMonitor.orig.y
    );
end;

function TPointHelper.FromScaledToMon(AMonitor: TMonitorDef): TPoint;
begin
  result.SetLocation(
    self.X * AMonitor.size.cx div AMonitor.virtSize.cx
    , self.Y * AMonitor.size.cy div AMonitor.virtSize.cy
    );
end;

function TPointHelper.FromMousePtToMonPt(
  AMonDefs: TMonDefs;
//  AMousePoint:TPoint;
  var monWithPt:integer;
  var ADeskPoint, AMonPoint, ASclPoint, ANormPoint: TPoint;
  var APolarPoint: TPointF;
  var AMonDef: TMonitorDef
  ): boolean;
begin
  result := false;
  monWithPt := -1;
//  var priMon:integer := -1;
  var currMonIndex:integer := 0;
//  AMonPoint := AMousePoint;
  for var mon in AMonDefs do
  begin
    var monRect := TRect.Create( mon.orig, mon.size.width, mon.size.height);
    if monRect.Contains(self) then
      monWithPt := currMonIndex;
//    if mon.primary then
//      priMon := currMonIndex;
    inc(currMonIndex);
  end;
  if monWithPt >= 0 then
  begin
    result := true;
    AMonDef := AMonDefs[monWithPt];
    AMonPoint := self.FromMouseToMon(AMonDef);
//    AMonPoint.SetLocation(
//      (self.X - AMonDef.orig.x)
//      , (self.Y - AMonDef.orig.y)
//      );
    ADeskPoint := AMonPoint.FromMonToScaled(AMonDef).FromScaledToDesk(AMonDef);
//    ADeskPoint.SetLocation(
//      trunc(ADeskPoint.X / AMonDef.size.cx * AMonDef.virtSize.cx) + AMonDef.orig.x
//      , trunc(ADeskPoint.Y / AMonDef.size.cy * AMonDef.virtSize.cy) + AMonDef.orig.y
//      );
    ASclPoint := AMonPoint.FromMonToScaled(AMonDef);
//    ANormPoint.SetLocation(
//      self.x * MAXWORD div AMonDef.primarySize.cx
//      , self.y * MAXWORD div AMonDef.primarySize.cy
//      );
    ANormPoint := self.FromMouseToNorm(AMonDef);
//    APolarPoint := TPointF.create(
//     AMonPoint.X / AMonDef.size.width - 0.5
//     , 0.5 - AMonPoint.Y / AMonDef.size.height
//     );
    APolarPoint := AMonPoint.FromMonToPolar(AMonDef);
  end
end;

function TPointHelper.FromDeskPtToMonPt(
  AMonDefs:TMonDefs;
//      ADeskPt:TPoint;
  var monWithPt:integer;
  var AMousePoint, AMonPoint, ASclPoint, ANormPoint: TPoint;
  var APolarPoint: TPointF;
  var AMonDef:TMonitorDef
  ): boolean;
begin
  result := false;
  monWithPt := -1;
//  var priMon:integer := -1;
  var currMonIndex:integer := 0;
//  AMonPoint := TPoint.create(x, y);
  for var mon in AMonDefs do
  begin
    var monRect := TRect.Create( mon.orig, mon.virtsize.width, mon.virtsize.height);
    if monRect.Contains(self) then
      monWithPt := currMonIndex;
//    if mon.primary then
//      priMon := currMonIndex;
    inc(currMonIndex);
  end;
  if monWithPt >= 0 then
  begin
    result := true;
    AMonDef := AMonDefs[monWithPt];
    AMonPoint := self.FromDeskToScale(AMonDef).FromScaledToMon(AMonDef);
//    AMonPoint.SetLocation(
//      trunc((AMonPoint.X - AMonDef.orig.x) / AMonDef.virtSize.width * AMonDef.size.width)
//      , trunc((AMonPoint.Y - AMonDef.orig.y) / AMonDef.virtSize.height * AMonDef.size.height)
//      );
    ASclPoint := AMonPoint.FromMonToScaled(AMonDef);
//    AMousePoint := AMonPoint;
//    AMousePoint.Offset(AMonDef.orig.x, AMonDef.orig.y);
    AMousePoint := AMonPoint.FromMonToMouse(AMonDef);
//    ANormPoint.SetLocation(
//      AMousePoint.x * MAXWORD div AMonDef.primarySize.cx
//      , AMousePoint.y * MAXWORD div AMonDef.primarySize.cy
//      );
    ANormPoint := AMousePoint.FromMouseToNorm(AMonDef);
//    APolarPoint := TPointF.create(
//     AMonPoint.X / AMonDef.size.width - 0.5
//     , 0.5 - AMonPoint.Y / AMonDef.size.height
//     );
    APolarPoint := AMonPOint.FromMonToPolar(AMonDef);
  end
end;

{ TMonitorRecHelper }

function TMonitorRecHelper.toRect: TRect;
begin
  result := TRect.Create(
    self.orig
    , self.size.cx
    , self.size.cy);
end;

function TMonitorRecHelper.toVirtRect: TRect;
begin
  result := TRect.Create(
    self.orig
    , self.virtsize.cx
    , self.virtsize.cy);
end;

end.
