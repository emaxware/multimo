unit uConsoleLogger;

interface

uses
  system.Classes
  , uLoggerLib
{$IFDEF MSWINDOWS}
  , JclConsole
  , System.Threading
{$ENDIF}
  ;

type
  TConsoleLogger = class(TSimpleLogger)
{$IFDEF MSWINDOWS}
  private
    type
      TConsoleMonitor = class(TThread)
      protected
        procedure Execute; override;
      end;

    class var
      fConsoleMonitor:TConsoleMonitor;
  protected
    class var
      FDefaultConsoleBuffer:TJclScreenBuffer;

    FConsoleBuffer:TJclScreenBuffer;
{$ENDIF}
//    function InternalLog(ALogLevel:TLogPriority; const ALogMsg:string):string; override;
  public
    constructor create(const AModuleName:string; UseDefaultConsole:boolean = true
      ; ADefaultLogLevel: TLogPriority = lpDebug
      ; AUptoLevel:TLogPriority = lpDebug// lpInfo
      );

{$IFDEF MSWINDOWS}
    class function AddConsoleBuffer:TJclScreenBuffer;
    class function HaveDefaultConsole(tryCreateIfNotExists:boolean): Boolean;
{$ENDIF}
  end;


//function AmGUIApp:boolean;

implementation

uses
  System.SysUtils
{$IFDEF MSWINDOWS}
  , winapi.windows
{$ENDIF}
  ;

{$IFDEF MSWINDOWS}
var
  FAmGUIApp:boolean = true;
  FCheckDefaultConsole:boolean = True;
  FHaveDefaultConsole:boolean = false;

function AmGUIApp:boolean;
begin
  result := FAmGUIApp
end;

class function TConsoleLogger.HaveDefaultConsole(tryCreateIfNotExists:boolean): Boolean;
var
  Stdout: THandle;
begin
  if FCheckDefaultConsole then
  begin
    repeat
      Stdout := GetStdHandle(Std_Output_Handle);
      Win32Check(Stdout <> Invalid_Handle_Value);
      FHaveDefaultConsole := Stdout <> 0;
      if not FHaveDefaultConsole and FCheckDefaultConsole and tryCreateIfNotExists and AllocConsole then
      begin
        FAmGUIApp := true;
        FCheckDefaultConsole := false;
        continue
      end;
      FCheckDefaultConsole := false;
      if FHaveDefaultConsole then
      begin
        FDefaultConsoleBuffer := TJclScreenBuffer.Create(Stdout);
//        Log(llTrace, 'Default logging started..')
//        logBuffer.Write('Log started..'#13#10);
      end;
      break
    until false;
  end;
  result := FHaveDefaultConsole
end;

class function TConsoleLogger.AddConsoleBuffer: TJclScreenBuffer;
begin
  result := TJclConsole.Default.Add;
  if fConsoleMonitor = nil then
    fConsoleMonitor := TConsoleMonitor.Create(false)
end;
{$ENDIF}

constructor TConsoleLogger.create;
begin
  inherited create(
    function (ALogLevel:TLogPriority; const ALogMsg, AMsg:string):string
    begin
      result := ALogMsg;
      if assigned(FConsoleBuffer) then
        with FConsoleBuffer, Font do
        begin
//          case ALogLevel of
//            llCritical:
//            begin
//              BgColor := bclRed;
//              Color := fclWhite
//            end;
//
//            llError:
//            begin
//              BgColor := bclBlack;
//              Color := fclRed
//            end;
//
//            llWarning:
//            begin
//              BgColor := bclBlack;
//              Color := fclYellow
//            end;
//
//            llInfo:
//            begin
//              BgColor := bclBlack;
//              Color := fclWhite
//            end;
//
//            llDebug:
//            begin
//              BgColor := bclGreen;
//              Color := fclWhite
//            end;
//
//            llTrace:
//            begin
//              BgColor := bclGreen;
//              Color := fclBlack
//            end;
//          end;
          Write(ALogMsg+#13#10)
        end
    end,
    AModuleName,
    AUptoLevel,
    ADefaultLogLevel );

  FConsoleBuffer := nil;
  if HaveDefaultConsole(true) then
    if UseDefaultConsole then
      FConsoleBuffer := TJclConsole.Default.Screens[0]
    else
      FConsoleBuffer := AddConsoleBuffer
end;

//function TConsoleLogger.InternalLog(ALogLevel:TLogPriority; const ALogMsg:string):string;
//begin
//  result := ALogMsg;
//  if assigned(FConsoleBuffer) then
//    with FConsoleBuffer, Font do
//    begin
//      case ALogLevel of
//        llCritical:
//        begin
//          BgColor := bclRed;
//          Color := fclWhite
//        end;
//
//        llError:
//        begin
//          BgColor := bclBlack;
//          Color := fclRed
//        end;
//
//        llWarning:
//        begin
//          BgColor := bclBlack;
//          Color := fclYellow
//        end;
//
//        llInfo:
//        begin
//          BgColor := bclBlack;
//          Color := fclWhite
//        end;
//
//        llDebug:
//        begin
//          BgColor := bclGreen;
//          Color := fclWhite
//        end;
//
//        llTrace:
//        begin
//          BgColor := bclGreen;
//          Color := fclBlack
//        end;
//      end;
//      Write(ALogMsg+#13#10)
//    end
//end;

{ TLoggerMonitor }

procedure TConsoleLogger.TConsoleMonitor.Execute;
var index:integer;
begin
  with TJclConsole.Default do
  while Input.WaitEvent do
  begin
    with Input.GetEvent do
      case EventType of
      KEY_EVENT:
      begin
        case Event.KeyEvent.AsciiChar of
          '1'..'9':
          begin
            index := ord(Event.KeyEvent.AsciiChar) - ord('1');
            if index < ScreenCount then
              ActiveScreenIndex := index;
          end;
          'k','K':
            ExitProcess(0)
        end;
      end;
    end;
  end;
end;

initialization

end.
