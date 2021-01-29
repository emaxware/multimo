unit dmain;

interface

uses
  System.SysUtils, System.Classes, IdBaseComponent, IdComponent, IdUDPBase,
  IdUDPServer, IdUDPClient;

type
  TdmMain = class(TDataModule)
    IdUDPServer1: TIdUDPServer;
    IdUDPClient1: TIdUDPClient;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  dmMain: TdmMain;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

end.
