unit uIdLib;

interface

uses
  System.SyncObjs
  , IdIOHandler
  , uEventLib
  ;

type
  TIOHandlerHelper = class helper for TIdIOHandler
    procedure WriteEvent(AEvent:TInputEvent); overload;
    procedure ReadEvent(var AEvent:TInputEvent);
  end;

implementation

uses
  IdGlobal
  ;

{ TIOHandlerHelper }

procedure TIOHandlerHelper.ReadEvent(var AEvent: TInputEvent);
begin
  var buffer:TidBytes;
  self.ReadBytes(buffer, sizeof(AEvent));
  Move(buffer[0],AEvent,sizeof(AEvent));
//  AEvent := PInputEvent(@buffer[0])^;
end;

procedure TIOHandlerHelper.WriteEvent(AEvent: TInputEvent);
begin
  var buffer:TIdBytes := RawToBytes(AEvent, sizeof(AEvent));
  self.Write(buffer);
end;

end.
