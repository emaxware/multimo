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
        Name = 'Receive INPUT'
        NormalReply.Code = '200'
        ParamDelimiter = ' '
        ParseParams = True
        Tag = 0
        OnCommand = cmdTcpServerCommandHandlers1Command
      end
      item
        CmdDelimiter = ' '
        Command = 'SENDINPUT'
        Disconnect = False
        ExceptionReply.Code = ''
        Name = 'SEND INPUT STREAM'
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
  object _tcpClient: TIdTCPClient
    Intercept = con1
    OnConnected = _tcpClientConnected
    ConnectTimeout = 600000
    Port = 0
    ReadTimeout = 600000
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
end
