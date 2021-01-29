object Proto: TProto
  OldCreateOrder = False
  Height = 262
  Width = 373
  object IdUDPServer1: TIdUDPServer
    OnStatus = IdUDPServer1Status
    BroadcastEnabled = True
    Bindings = <>
    DefaultPort = 8111
    OnUDPRead = IdUDPServer1UDPRead
    Left = 32
    Top = 32
  end
  object IdUDPClient1: TIdUDPClient
    BroadcastEnabled = True
    BoundPort = 8111
    Host = '192.168.1.1'
    Port = 0
    Left = 32
    Top = 96
  end
  object IdTCPClient1: TIdTCPClient
    OnDisconnected = IdTCPClient1Disconnected
    OnConnected = IdTCPClient1Connected
    ConnectTimeout = 0
    IPVersion = Id_IPv4
    Port = 8111
    ReadTimeout = -1
    Left = 128
    Top = 96
  end
  object IdCmdTCPServer1: TIdCmdTCPServer
    Bindings = <
      item
        IP = '0.0.0.0'
        Port = 8111
      end>
    DefaultPort = 8111
    OnConnect = IdCmdTCPServer1Connect
    OnDisconnect = IdCmdTCPServer1Disconnect
    OnExecute = IdCmdTCPServer1Execute
    CommandHandlers = <
      item
        CmdDelimiter = ' '
        Command = 'CONFIG'
        Disconnect = False
        Name = 'CONFIG'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
      end
      item
        CmdDelimiter = ' '
        Command = 'MOUSE'
        Disconnect = False
        Name = 'MOUSE'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
      end
      item
        CmdDelimiter = ' '
        Command = 'TEST'
        Disconnect = False
        Name = 'TEST'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
      end
      item
        CmdDelimiter = ' '
        Command = 'ECHO'
        Disconnect = False
        Name = 'ECHO'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
      end>
    ExceptionReply.Code = '500'
    ExceptionReply.Text.Strings = (
      'Unknown Internal Error')
    Greeting.Code = '200'
    Greeting.Text.Strings = (
      'Welcome')
    HelpReply.Code = '100'
    HelpReply.Text.Strings = (
      'Help follows')
    MaxConnectionReply.Code = '300'
    MaxConnectionReply.Text.Strings = (
      'Too many connections. Try again later.')
    ReplyTexts = <>
    ReplyUnknownCommand.Code = '400'
    ReplyUnknownCommand.Text.Strings = (
      'Unknown Command')
    Left = 128
    Top = 32
  end
end
