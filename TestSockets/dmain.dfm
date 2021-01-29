object dmMain: TdmMain
  OldCreateOrder = False
  Height = 262
  Width = 373
  object IdUDPServer1: TIdUDPServer
    BroadcastEnabled = True
    Bindings = <>
    DefaultPort = 8111
    Left = 32
    Top = 32
  end
  object IdUDPClient1: TIdUDPClient
    BroadcastEnabled = True
    BoundIP = '8111'
    Port = 0
    Left = 32
    Top = 96
  end
end
