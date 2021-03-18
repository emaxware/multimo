unit uHookInputController;

interface

uses
  system.UITypes
  , System.Types
//  , system.Classes
  , IdCommandHandlers
  , uController
  , uCommandLineOptions
  , dProtocol
  , uSendInput
  ;

type
  THookInputServerController = class(TProtoServerController)
  protected
  public
    function Start:boolean; override;
  end;

  THookInputClientController = class(TProtoClientController)
  protected
  public
    function Start:boolean; override;
  end;

  TInputHelper = class helper for TSendInputHelper
    procedure AddMouseMoves(moves:TStringDynArray);
  end;

implementation

uses
  winapi.Windows
  , winapi.Messages
  , system.SysUtils
  , System.StrUtils
  , IdIOHandler
  , IdGlobal
  , uLLHookLib
  ;

const
  LLKHF_EXTENDED = KF_EXTENDED shr 8;
  LLKHF_LOWER_IL_INJECTED = $00000002;
  LLKHF_INJECTED = $00000010;
  LLKHF_ALTDOWN = KF_ALTDOWN shr 8;
  LLKHF_UP = KF_UP shr 8;

{ TInputHelper }

procedure TInputHelper.AddMouseMoves;
begin
  for var move in moves do
  begin
    var m := SplitString(move,',');
    AddRelativeMouseMove(strtoint(m[0]),strtoint(m[1]));
    AddDelay(1000);
  end;
end;

{ THookInputClientController }

function THookInputClientController.Start: boolean;
begin
  result := inherited start;
  if result then
    InternalStartClient(
      procedure(const AReply:string; AThread:TListenerThread)
      begin
        var sizeTInput := SizeOf(TInput);
        var inps := TSendInputHelper.Create;

        repeat
          var msg := AThread.Client.IOHandler.ReadLn();
          if msg='>>' then
          begin
            var data:TIdBytes;
            AThread.Client.IOHandler.ReadBytes(data, sizeTInput);
            inps.Add(PInput(@data[0])^);
            continue;
          end;
          if msg='sent' then
          begin
            AThread.Client.IOHandler.WriteLn('rcvd');
            inps.Flush;
            continue
          end;
          raise Exception.CreateFmt('Unexpected token "%s"',[msg]);
        until false;
      end)
end;

{ THookInputServerController }

function THookInputServerController.Start: boolean;
begin
  result := inherited start;
  if result then
    InternalStartServer(
        procedure(AIO:TIdIOHandler)
        begin
          var sizeTInput := SizeOf(TInput);
          if fVals.Enabled['SENDSTRING'] then
          begin
            var inps := TSendInputHelper.Create;
            try
              inps.AddMouseMoves(fVals.Option['SENDSTRING'].asArray('|'));

              for var inp in inps do
              begin
                AIO.WriteLn('>>');
                AIO.Write(RawToBytes(inp, sizeTInput), sizeTInput);
              end;

              AIO.WriteLn('sent');
              var msg := AIO.ReadLn;
            finally
              inps.free
            end
          end;

          if fVals.Enabled['KBDINPUT'] then
          begin
            var inps := TSendInputHelper.Create;
            var i := TLLKbdHook.Instance.AddListener(
              procedure(AHookData:TLLKbdHookData)
              begin
                if (AHookData.data.flags and LLKHF_INJECTED) = LLKHF_INJECTED then
                  exit;

                inps.Clear;
                case AHookData.wParam of
//                  WM_KEYDOWN:
//                  WM_KEYUP:
                  0:;
                  else
                    inps.AddKeyboardInput(AHookData.data.vkCode, AHookData.data.scanCode, AHookData.data.flags, AHookData.data.time);
                end;

                for var inp in inps do
                begin
                  AIO.WriteLn('>>');
                  AIO.Write(RawToBytes(inp, sizeTInput), sizeTInput);
                end;

                AIO.WriteLn('sent');
              end);

            var msg:string;
            try
              repeat
                msg := AIO.ReadLn;
              until msg <> 'rcvd';
            finally
              TLLMouseHook.Instance.RemoveListener(i)
            end
          end;

          if fVals.Enabled['MOUSEINPUT'] then
          begin
            var inps := TSendInputHelper.Create;
            var i := TLLMouseHook.Instance.AddListener(
              procedure(AHookData:TLLMouseHookData)
              begin
                if (AHookData.data.flags and LLKHF_INJECTED) = LLKHF_INJECTED then
                  exit;

                inps.Clear;
//                var inp:TInput;
//
//                with inp.mi do
//                begin
//                  dx := AHookData.data.pt.x;
//                  dy := AHookData.data.pt.Y;
//                  mouseData := AHookData.data.mouseData;
//                  dwFlags := AHookData.data.flags;
//                  time := AHookData.data.time
//                end;
//                inps.add(inp);

                case AHookData.wParam of
                  WM_RBUTTONUP:
                  begin
                    inps.AddAbsoluteMouseMove(AHookData.data.pt.X, AHookData.data.pt.Y);
                    inps.AddMouseClick(TMouseButton.mbRight);
                  end;
                  WM_LBUTTONUP:
                  begin
                    inps.AddAbsoluteMouseMove(AHookData.data.pt.X, AHookData.data.pt.Y);
                    inps.AddMouseClick(TMouseButton.mbLeft);
                  end;
                  WM_MOUSEMOVE:
                  begin
                    inps.AddAbsoluteMouseMove(AHookData.data.pt.X, AHookData.data.pt.Y);
                  end;
                end;

                for var inp in inps do
                begin
                  AIO.WriteLn('>>');
                  AIO.Write(RawToBytes(inp, sizeTInput), sizeTInput);
                end;

                AIO.WriteLn('sent');
              end);

            var msg:string;
            try
              repeat
                msg := AIO.ReadLn;
              until msg <> 'rcvd';
            finally
              TLLMouseHook.Instance.RemoveListener(i)
            end
          end
        end)
end;

end.
