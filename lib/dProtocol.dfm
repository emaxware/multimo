object Proto: TProto
  OldCreateOrder = False
  Height = 262
  Width = 373
  object cmdTcpServer: TIdCmdTCPServer
    Bindings = <>
    DefaultPort = 8111
    Intercept = hook1
    OnConnect = cmdTcpServerConnect
    OnDisconnect = cmdTcpServerDisconnect
    OnExecute = cmdTcpServerExecute
    CommandHandlers = <
      item
        CmdDelimiter = ' '
        Command = 'ECHO'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'ECHO'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
        OnCommand = cmdTcpServerCommandHandlers0Command
      end
      item
        CmdDelimiter = ' '
        Command = 'INPUT'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'INPUT'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
        OnCommand = cmdTcpServerCommandHandlers1Command
      end
      item
        CmdDelimiter = ' '
        Command = 'SENDMOUSEMOVE'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'SENDMOUSEMOVE'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
        OnCommand = cmdTcpServerCommandHandlers2Command
      end
      item
        CmdDelimiter = ' '
        Command = 'TEST'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'TEST'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
        OnCommand = cmdTcpServerCommandHandlers0Command
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
    Left = 48
    Top = 32
  end
  object _cmdTcpClient: TIdCmdTCPClient
    OnDisconnected = IdTCPClient1Disconnected
    OnConnected = IdTCPClient1Connected
    BoundIP = 'LOCALHOST'
    BoundPort = 8111
    ConnectTimeout = 0
    Port = 0
    ReadTimeout = -1
    CommandHandlers = <
      item
        CmdDelimiter = ' '
        Command = 'CONFIG'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'cmdCONFIG'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
      end
      item
        CmdDelimiter = ' '
        Command = 'MOUSE'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'cmdMOUSE'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
      end
      item
        CmdDelimiter = ' '
        Command = 'TEST'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'cmdTEST'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
      end
      item
        CmdDelimiter = ' '
        Command = 'ECHO'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'cmdECHO'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
      end>
    ExceptionReply.Code = '500'
    ExceptionReply.Text.Strings = (
      'Unknown Internal Error')
    Left = 48
    Top = 96
  end
  object _tcpClient: TIdTCPClient
    Intercept = con1
    OnConnected = _tcpClientConnected
    ConnectTimeout = 0
    Port = 0
    ReadTimeout = 100
    OnAfterBind = _tcpClientAfterBind
    Left = 48
    Top = 160
  end
  object hook1: TIdServerInterceptLogEvent
    OnLogString = hook1LogString
    Left = 112
    Top = 32
  end
  object con1: TIdConnectionIntercept
    OnReceive = con1Receive
    OnSend = con1Send
    Left = 112
    Top = 160
  end
  object IdIPMCastClient1: TIdIPMCastClient
    Bindings = <>
    DefaultPort = 0
    MulticastGroup = '224.0.0.1'
    Left = 216
    Top = 32
  end
  object IdIPMCastServer1: TIdIPMCastServer
    BoundPort = 0
    MulticastGroup = '224.0.0.1'
    Port = 0
    Left = 216
    Top = 96
  end
end
