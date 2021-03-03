unit uCommandLineOptions;

interface

uses
  System.SysUtils
  , System.RegularExpressions
  , System.Generics.Collections
  ;

type
  CommandOptionError = class(Exception) end;

  TCmdOption = class;
  TCmdValue = class;
  TCmdOptionSetting = (cosRequired,cosChild,cosIsFlag,cosIsFlagged,cosIsNotFlagged,cosHasDefaultValue);
  TCmdOptionSettings = set of TCmdOptionSetting;
  THelpFormatter = reference to procedure(const AFormattedOption:string);
  TMissingOptionHandler = reference to function(AOption:TCmdOption; var AValue:string; var Enable:Boolean):boolean;
  TCmdOptionClass = class of TCmdOption;

  TCmdOption = class
  private
    fOptDesc: string;
  protected
    fSettings: TCmdOptionSettings;
    fOpt: char;
    fOptName: string;
    fDefFlag: boolean;
    fDefValue:string;
    fOptions:TObjectList<TCmdOption>;
    fParent:TCmdOption;
    fProcessed:boolean;
    class var
      fOptNameMatch, fOptValueMatch:TRegEx;
//    class function OptGetName:TRegEx; virtual;

    function ParseCommandLine(const ACommandLine:string; var AValues:TCmdValue; var AStartPos:integer; MissingOptionHandler:TMissingOptionHandler = nil):boolean; overload; virtual;

    class constructor create;

    destructor destroy; override;
  public
    procedure AfterConstruction; override;

    class function ConsoleOptionHandler:TMissingOptionHandler;
    function Add(const AOptName:string; AOpt:Char; Options:TCmdOptionSettings; const ADefault, ADesc:string; AOptionClass:TCmdOptionClass):TCmdOption; overload; virtual;
    function Add(const AOptName:string; AOpt:Char; Options:TCmdOptionSettings; const ADefault:string = ''; const ADesc:string = ''):TCmdOption; overload; virtual;

    function ParseCommandLine(var AValues:TCmdValue; MissingOptionHandler:TMissingOptionHandler = nil):boolean; overload;

    property Settings:TCmdOptionSettings read fSettings;
    property OptName:string read fOptName;
    property Opt:char read fOpt;
    property OptDesc:string read fOptDesc;
    property DefValue:string read fDefValue;
    property DefFlag:boolean read fDefFlag;
  end;

  TCmdOptions = class(TCmdOption)
  protected
    class var
      finstance:TCmdOptions;
  public
    class function Instance:TCmdOptions; virtual;
  end;

  TCmdValue = class
  protected
    fCmdOption:TCmdOption;
    fFound, fFlagged:boolean;
    fValue:string;
    fValues:TObjectList<TCmdValue>;
    fParent:TCmdValue;

    function GetValueByName(AName: string): TCmdValue;
    function GetFlaggedByName(AName: string): boolean;
    function GetValueAsInteger: integer;

    constructor create;
  public
    destructor destroy; override;

    property CmdOption:TCmdOption read fCmdOption;
    property ValuesByName[AName:string]:TCmdValue read GetValueByName; default;
    property Enabled[AName:string]:boolean read GetFlaggedByName;
    property Flagged:boolean read fFlagged;
    property Value:string read fValue;
    property asInteger:integer read GetValueAsInteger;
    property Found:boolean read fFound;
  end;

implementation

uses
  System.StrUtils
  ;

{ TCmdOption }

function TCmdOption.Add(const AOptName:string; AOpt: char;
  Options: TCmdOptionSettings; const ADefault, ADesc:string; AOptionClass: TCmdOptionClass): TCmdOption;
begin
  result := AOptionClass.create;
  result.fOptName := AOptname;
  result.fOpt := AOpt;
  result.fSettings := Options;
  result.fDefValue := ADefault;
  if ADefault <> '' then
    include(result.fSettings, cosHasDefaultValue);
  if ADesc = '' then
    if fOptName='' then
      Result.fOptDesc := Format('-%s option',[string(AOpt)])
    else
//    if fOpt=' ' then
      Result.fOptDesc := Format('--%s option',[AOptName])
  else
    result.fOptDesc := ADesc;
  if cosIsFlagged in Options then
    result.fDefFlag := True;
  if [cosIsFlagged,cosIsNotFlagged] * Options <> [] then
  begin
    Include(Options, cosIsFlag);
    Include(Options, cosHasDefaultValue);
  end;
  if (cosChild in Options) then
  begin
    Result.fParent := self;
    fOptions.Add(result)
  end
  else
  if (fParent = nil) then
  begin
    Result.fParent := self;
    fOptions.Add(result)
  end
  else
  begin
    Result.fParent := fParent;
    fParent.fOptions.Add(result)
  end;
end;

function TCmdOption.Add(const AOptName:string; AOpt:Char; Options: TCmdOptionSettings; const ADefault, ADesc:string): TCmdOption;
begin
  result := Add(AOptName, AOpt, Options, ADefault, ADesc, TCmdOption)
end;

procedure TCmdOption.AfterConstruction;
begin
  inherited;
  fOptions := TObjectList<TCmdOption>.Create(True)
end;

const
  boolMap:array[boolean] of string = ('no','yes');
  boolRequiredMap:array[boolean] of string = ('','[Required]');

class function TCmdOption.ConsoleOptionHandler: TMissingOptionHandler;
begin
  result := function(AOption:TCmdOption; var AValue:string; var Enable:Boolean):boolean
    var resp:string;
    begin
      if cosHasDefaultValue in AOption.Settings then
        if cosIsFlag in AOption.Settings then
          Writeln(Format('Enable %s [--%s/-%s]? %s'#13#10'  [enter] "%s"'#13#10'  [y]es'#13#10'  [n]o'#13#10'  [s]kip',[
            AOption.OptDesc,
            AOption.OptName,
            string(AOption.Opt),
            boolRequiredMap[cosRequired in AOption.Settings],
            boolMap[AOption.DefFlag]]))
        else
          Writeln(Format('Value for %s [--%s/-%s]? %s'#13#10'  [enter] "%s"'#13#10'  [o]ther'#13#10'  [s]kip',[
            AOption.OptDesc,
            AOption.OptName,
            string(AOption.Opt),
            boolRequiredMap[cosRequired in AOption.Settings],
            AOption.DefValue]))
      else
        if cosIsFlag in AOption.Settings then
          Writeln(Format('Enable %s [--%s/-%s]? %s'#13#10'  [y]es'#13#10'  [n]o'#13#10'  [s]kip',[
            AOption.OptDesc,
            AOption.OptName,
            string(AOption.Opt),
            boolRequiredMap[cosRequired in AOption.Settings]
            ]))
        else
          Writeln(Format('Value for %s [--%s/-%s]? %s'#13#10'  [o]ther'#13#10'  [s]kip',[
            AOption.OptDesc,
            AOption.OptName,
            string(AOption.Opt),
            boolRequiredMap[cosRequired in AOption.Settings]
            ]));
      Readln(resp);
      resp := LowerCase(resp);
      result := true;
//      if resp = 's' then
//        result := false
//      else
      if resp = 'y' then
        Enable := true
      else
      if resp = 'n' then
        Enable := false
      else
      if resp = '' then
      else
      if resp = 'o' then
      begin
        Writeln('Other value:');
        Readln(resp);
        AValue := resp
      end
      else
        result := false
    end;
end;

destructor TCmdOption.destroy;
begin
  freeandnil(fOptions);
  inherited;
end;

function TCmdOption.ParseCommandLine(var AValues:TCmdValue; MissingOptionHandler:TMissingOptionHandler = nil): boolean;
var
  currPos:integer;
begin
  currPos := 1;
  AValues := TCmdValue.create;
  try
    var m := TRegEx.Match(
        string(CmdLine),
        '^"[^"]+" (.+)$',
        [TRegExOption.roMultiLine]
        );
    var cmdLine := '';
    if m.Success then
      cmdLine := m.Groups[1].Value;
    result := ParseCommandLine(cmdLine, AValues, currPos, MissingOptionHandler)
  except
    on e:CommandOptionError do
    begin
      AValues.Free;
      raise
    end
  end;
end;

class constructor TCmdOption.create;
begin
  fOptNameMatch := TRegEx.Create(' *(--|-|)(!|)([a-zA-Z0-9][a-zA-Z0-9_\-]+|"([a-zA-Z][a-zA-Z0-9_\- ]+)")',[roIgnoreCase]);
  fOptValueMatch := TRegEx.Create('(:|=| )([^" ]+|"([^"]+)")',[roIgnoreCase]);
end;

function TCmdOption.ParseCommandLine(const ACommandLine: string; var AValues:TCmdValue; var AStartPos:integer; MissingOptionHandler:TMissingOptionHandler = nil):boolean;
begin
  var cmdOptionFound := TList<TCmdOption>.create;
  result := true;
  try
    repeat
      var optNameMatch := fOptNameMatch.Match(ACommandLine, AStartPos);
      if not optNameMatch.Success then
        break;

      var enabled:boolean;
      if optNameMatch.Groups.Item[2].Success and (optNameMatch.Groups.Item[2].Value='!') then
        enabled := false
      else
        enabled := true;

      var foundName:string;
      if optNameMatch.Groups.Item[2].Success and (optNameMatch.Index = AStartPos) then
        if optNameMatch.Groups.Item[3].Success then
          foundName := optNameMatch.Groups.Item[3].Value
        else
          foundName := optNameMatch.Groups.Item[2].Value
      else
        raise CommandOptionError.CreateFmt('Error parsing option name: %s',[MidStr(ACommandLine,AStartPos,20)]);

      var optValueMatch := fOptValueMatch.Match(ACommandline, AStartPos + optNameMatch.Length);
      var foundValue:string := '';
      if optValueMatch.Success and (optValueMatch.Index = AStartPos + optNameMatch.Length) then
        if optValueMatch.Groups.Item[2].Success then
          foundValue := optValueMatch.Groups.Item[2].Value
        else
          foundValue := optValueMatch.Groups.Item[1].Value;

      var found := false;
      for var opt in fOptions do
      begin
        if (CompareText(opt.OptName, foundName) = 0) and not cmdOptionFound.Contains(opt) then
        begin
//          opt.fProcessed := true;
          var optValue := TCmdValue.create;
          optValue.fFound := true;
          optValue.fCmdOption := opt;
          optValue.fParent := AValues;
          optValue.fFlagged := enabled;
          cmdOptionFound.Add(opt);
          AValues.fValues.Add(optValue);

          if cosIsFlag in opt.fSettings then
          begin
            Inc(AStartPos, optNameMatch.Length);
          end
          else
          if foundValue <> '' then// optValueMatch.Success then
          begin
            Inc(AStartPos, optNameMatch.Length + optValueMatch.Length);
            optValue.fValue := foundValue
          end
          else
            raise CommandOptionError.CreateFmt('Error parsing option value: %s',[MidStr(ACommandLine,AStartPos + optNameMatch.Length,20)]);
          found := true;

          if optValue.fFlagged and (opt.fOptions.Count > 0) then
            opt.ParseCommandLine(ACommandLine, optValue, AStartPos, MissingOptionHandler);

          break
        end;
      end;

      if not found then
        break;
    until AStartPos >= length(ACommandLine);

    for var opt in fOptions do
    begin
      var optName := opt.OptName;
      if not cmdOptionFound.Contains(opt) then
      begin
        var defFlag := opt.fdefflag;
        var defValue := opt.fDefValue;
        var manualOverride := Assigned(MissingOptionHandler) and MissingOptionHandler(opt, defValue, defFlag);

        if (not manualOverride)
          and
          (cosRequired in opt.fSettings) then
          raise CommandOptionError.CreateFmt('Error missing required option %s: %s',[opt.OptName, MidStr(ACommandLine,AStartPos,20)])
        else
        begin
          var optValue := TCmdValue.create;
          optValue.fCmdOption := opt;
          optValue.fParent := AValues;
          if cosIsFlag in opt.fSettings then
            optValue.fFlagged := defFlag
          else
            optValue.fValue := defValue;

          AValues.fValues.Add(optValue);

          if optValue.fFlagged and (opt.fOptions.Count > 0) then
            opt.ParseCommandLine(ACommandLine, optValue, AStartPos, MissingOptionHandler);
        end
      end
    end
  finally
    cmdOptionFound.free
  end;
end;

{ TCmdOptions }

class function TCmdOptions.Instance: TCmdOptions;
begin
  if finstance=nil then
  begin
    fInstance := TCmdOptions.Create;
//    fInstance.ParseCommandLine(CmdLine);
  end;
  result := fInstance
end;

{ TCmdValue }

constructor TCmdValue.create;
begin
  fValues := TObjectList<TCmdValue>.create(True)
end;

destructor TCmdValue.destroy;
begin
  freeandnil(fValues);
  inherited;
end;

function TCmdValue.GetFlaggedByName(AName: string): boolean;
begin
  var value := ValuesByName[AName];
  if cosIsFlag in Value.fCmdOption.fSettings then
    result := value.fFlagged
  else
    result := false
end;

function TCmdValue.GetValueAsInteger: integer;
begin
  result := StrToInt(fValue)
end;

function TCmdValue.GetValueByName(AName: string): TCmdValue;
begin
  result := nil;
  for var AValue in fValues do
  begin
    if CompareText(AValue.fCmdOption.fOptName, AName) = 0 then
    begin
      result := AValue;
      break
    end
  end
end;

end.
