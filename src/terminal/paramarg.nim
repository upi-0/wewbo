import 
  json,
  strutils,
  os,
  options

type
  AllowedValType* = enum
    tString,
    tInt,
    tSeq,
    tBool,

  ArgOption* = ref object of RootObj
    flag*: string
    name*: string
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

  raise newException(ValueError, "Option not found for: " & flag)  

proc convert*(val: string, target: AllowedValType) : JsonNode {.gcsafe.} =
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
      result = newJBool(false)
  except :
    result = %*{} 

proc add*(fa: FullArgument, flag: string, name: string, val: AllowedValType, default: auto = "") {.gcsafe.} =  
  let defa = convert($default, val)
  fa.options.add ArgOption(
      flag: flag,
      name: name,
      valType: val,
      default: defa
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
    base = arg.split(fa.seperator)

    if (arg.contains(fa.seperator) and arg.contains("-")) or flags.contains(base[0]) :
      option = fa.options.get base[0]
      faKey = option.name

      try: 
        faVal = base[1]
        realVal = convert(faVal, option.valType)
      
      except IndexDefect :
        if option.valType == tBool :
          realVal = newJBool(true)

      fa.flags.add arg.split(fa.seperator)[0]
      fa.parsed[faKey] = realVal

    else :
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