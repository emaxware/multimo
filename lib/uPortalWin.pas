unit uPortalWin;

interface

uses
  Winapi.windows
  , uAPILib
  , uHWNDLib
  , uMonLib
  ;

var
  DefWindowClass: TWndClass = (
    style: 0;
    lpfnWndProc: @DefWindowProc;
    cbClsExtra: 0;
    cbWndExtra: 0;
    hInstance: 0;
    hIcon: 0;
    hCursor: 0;
    hbrBackground: 0;
    lpszMenuName: nil;
    lpszClassName: 'DefWindowClass');

type
  TPortalWindow = class(TMonitorWindow)
  protected
    FMon:TMonitorDef;
    FRect:TRect;
  public
    constructor create(AWndProc:TWndProcRef; ARect:TRect; AMonDef:TMonitorDef);

    property Mon:TMonitorDef read FMon;
    property Rect:TRect read FRect;
  end;

  TRectHelper = record helper for TRect
    function OffsetTo(DX, DY:integer):TRect;
  end;

implementation

uses
//  Winapi.psapi,
//  Winapi.messages,
//  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Types,
//  System.Threading,
//  System.Generics.Collections,
//  uMonLib,
//  uEventLib,
//  uMouseHookLib,
//  uHelperLib,
//  HidUsage,
//  CnRawInput
  uLoggerLib
  ;

{ TPortalWindow }

constructor TPortalWindow.create(AWndProc:TWndProcRef; ARect:TRect; AMonDef:TMonitorDef);
begin
  DefWindowClass.hbrBackground := GetStockObject(WHITE_BRUSH);
  FRect := ARect;
  FMon := AMonDef;
//  FRect := TRect.Create(AMonDef.orig, AMonDef.virtSize.cx, AMonDef.virtSize.cy);
////  FOrigin := AMonDef.orig;
//  FRect.Offset(200*(AMonDef.index+1), 200*(AMonDef.index+1));
////  FSize := AMonDef.virtsize;
//  FRect.Width := 100;//FRect.Width div 4;
//  FRect.Height := 100;// FRect.Height div 4;
  inherited create(
    DefWindowClass
    , AWndProc
    , 0
    , pchar('')//string(AMonDef.monname))
    , WS_EX_TOPMOST //or WS_EX_LAYERED
    , WS_POPUP or WS_CAPTION or WS_VISIBLE
    , FRect.Left
    , FRect.Top
    , FRect.Width
    , FRect.Height
    );
  AssertWin32(SetWindowLong(FHWND, GWL_STYLE, WS_POPUP or WS_VISIBLE) <> 0, 'TPortalWindow.SetWindowLong GWL_STYLE', true);
//  Win32Check(ShowWindow(FHWND, SW_SHOW));
  AssertWin32(SetWindowLong(FHWND, GWL_EXSTYLE, GetWindowLong(FHWND, GWL_EXSTYLE) or WS_EX_LAYERED) <> 0, 'TPortalWindow.SetWindowLong GWL_EXSTYLE', true);
  AssertWin32(SetLayeredWindowAttributes(FHWND, $00ffffff, $7F, LWA_ALPHA OR LWA_COLORKEY), 'TPortalWindow.SetLayeredWindowAttributes', true);
end;

{ TRectHelper }

function TRectHelper.OffsetTo(DX, DY: integer): TRect;
begin
  self.Offset(DX, DY);
  result := self
end;

end.
