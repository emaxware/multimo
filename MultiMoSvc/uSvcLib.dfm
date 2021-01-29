object svcMultiMo: TsvcMultiMo
  OldCreateOrder = False
  DisplayName = 'MultiMon Service'
  Interactive = True
  OnExecute = ServiceExecute
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
end
