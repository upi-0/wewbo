import 
  json,
  strutils,
  os,
  options

type
  AllowedValType* = enum
    tString = "string",
    tInt = "int",
    tSeq = "list",
    tBool = "true|false",

  ArgOption* = ref object of RootObj
    flag*: string
    name*: string
    help*: string
    valType*: AllowedValType
    default*: JsonNode

  ArgOptions* = seq[ArgOption]  
  
  FullArgument {.final.} = ref object of RootObj
    argLine*: seq[string]
    options*: ArgOptions
    flags*: seq[string]
    nargs*: seq[string]
    seperator*: string = ":"
    parsed: JsonNode = %*{}

  InvalidArgument* = object of CatchableError

proc loadArguments*(args: seq[string] = @[]) : FullArgument {.gcsafe.} =
  var rArgs = args
  
  if args.len == 0 :
    rArgs = commandLineParams()

  return FullArgument(
    argLine: rArgs
  )

proc extract_flags(options: ArgOptions) : seq[string] = 
  for option in options :
    result.add option.flag

proc get(options: ArgOptions, flag: string) : ArgOption =
  for option in options :
    if option.flag == flag :
      return option

  raise newException(InvalidArgument, "Invalid Argument: " & flag)  

proc convert*(val: string, target: AllowedValType) : JsonNode =
  try :
    case target:
    of tInt :
      var lVal = parseInt val
      result = newJInt lVal
    of tString :
      result = newJString val
    of tSeq :
      var lVal = val.split(",")
      result = %lVal
    of tBool :
      let normalized = val.strip().toLowerAscii()
      if normalized in ["true", "1", "yes", "y", "on"]:
        result = newJBool(true)
      elif normalized in ["false", "0", "no", "n", "off"]:
        result = newJBool(false)
      else:
        raise newException(InvalidArgument, "Invalid boolean value: " & val)
  except InvalidArgument:
    raise
  except :
    raise newException(InvalidArgument, "Invalid value '" & val & "' for type " & $target)

proc add*(fa: FullArgument, flag: string, name: string, val: AllowedValType, default: auto = "") {.gcsafe, deprecated.} =  
  let defa = convert($default, val)
  fa.options.add ArgOption(
      flag: flag,
      name: name,
      valType: val,
      default: defa
    )

proc option*(flag: string, name: string, val: AllowedValType, default: auto = "", help: string = "") : ArgOption {.deprecated.} =
  ArgOption(
    flag: flag,
    name: name,
    valType: val,
    default: convert($default, val),
    help: help
  )    

proc option*[T: string|int|bool|openArray[string]](flag, name, help: string; defaultValue: T = "") : ArgOption =
  var
    default: JsonNode
    valType: AllowedValType

  when T is string:
    default = newJString defaultValue
    valType = tString

  when T is int:
    default = newJInt defaultValue
    valType = tInt

  when T is bool:
    default = newJBool defaultValue
    valType = tBool

  when T is openArray[string]:
    default = %(defaultValue.split(","))
    valType = tSeq

  ArgOption(
    flag: flag,
    name: name,
    valType: valType,
    default: default,
    help: help
  )

proc add(fa: FullArgument, argOpt: ArgOption) =
  fa.options.add(argOpt)

proc add*(fa: FullArgument, argOpts: openArray[ArgOption]) {.gcsafe.} =
  for ar in argOpts :
    fa.add(ar)

proc fill_from_default(fa: FullArgument) =
  for option in fa.options :
    if not option.default.isNil :
      fa.parsed[option.name] = option.default
    else :
      discard

proc parse*(fa: FullArgument) {.gcsafe.} =
  var
    base: seq[string]
    faKey: string
    faVal: string
    option: ArgOption
    realVal: JsonNode
    flags = fa.options.extract_flags()

  fa.fill_from_default()

  for arg in fa.argLine :
    base = arg.split(fa.seperator, 1)

    if (arg.contains(fa.seperator) and arg.startsWith("-")) or flags.contains(base[0]) :
      option = fa.options.get base[0]
      faKey = option.name

      try: 
        faVal = base[1]
        realVal = convert(faVal, option.valType)
      
      except IndexDefect :
        if option.valType == tBool :
          realVal = newJBool(true)
        else:
          raise newException(InvalidArgument, "Missing value for argument: " & base[0] & " (use " & base[0] & fa.seperator & "<value>)")

      fa.flags.add arg.split(fa.seperator)[0]
      fa.parsed[faKey] = realVal

    elif arg.startsWith("-") and not flags.contains(arg):
      raise newException(InvalidArgument, "Invalid argument: " & arg)

    elif not arg.startsWith("-"):
      fa.nargs.add arg

proc `[]`*(fa: FullArgument, key: string) : JsonNode {.gcsafe.} =
  fa.parsed[key]

export
  FullArgument,
  AllowedValType

export  
  getStr,
  getInt,
  getBool