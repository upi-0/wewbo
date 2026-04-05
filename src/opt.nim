import
  json, sequtils,
  tui/[ask, base],
  tui/questionable/[base, option]

from strutils import
  parseInt

from sugar import
  `=>`  

type OptionArgs* = ref object of RootObj
  jsonStructure = newJObject()
  jsonValue = newJObject()

proc s*(plate: JsonNode): string =
  plate.getStr()

proc n*(plate: JsonNode; default: int = 0): int =
  plate.getStr().parseInt()

proc b*(plate: JsonNode): bool =
  plate.getStr() == "True"

proc putEnum*(opt: OptionArgs; val: openArray[string]; key: string): void {.inline.} =
  opt.jsonStructure[key] = %val

proc putEnum*[T: Questionable](opt: OptionArgs; inputs: seq[T]; key: string) =
  var res: seq[string]
  
  for input in inputs:
    res.add(input.title)

  opt.putEnum(res, key)   

proc put*(opt: OptionArgs; val, key: string): void {.inline.} =
  opt.jsonStructure[key] = %val

proc putBool*(opt: OptionArgs; key: string): void {.inline.} =
  opt.putEnum(["True", "False"], key)

proc putRange*(opt: OptionArgs; sn, bp: int; key: string; default: int = sn) : void {.inline.} =
  var s: seq[string]
  if default != sn:
    s.add $default
  for i in sn..bp:
    s.add $i
  opt.jsonStructure[key] = %s

proc ask*(plate: OptionArgs; title = "Select Option"): void =
  var cont: seq[OptionValuedQuestionable]
  
  proc isAny(key: string) : bool =
    try:
      discard plate.jsonValue[key]
      true
    except KeyError:
      false  
  
  # To OptionValuedQuestionable
  for (key, val) in plate.jsonStructure.pairs():
    case val.kind
    of JString:
      if isAny(key):
        cont.add optionQ(plate.jsonValue[key].getStr(), key=key)  
      else:  
        cont.add optionQ(val.getStr(), key=key)
    of JArray:
      let enumVals = val.getElems().map(x => x.getStr())
      if isAny(key):
        cont.add optionQ(enumVals, key=key, optIdx = val.getElems().find(plate.jsonValue[key]))
      else:  
        cont.add optionQ(enumVals, key=key)
    of JInt:
      if isAny(key):
        cont.add optionQ($plate.jsonValue[key].getInt(), key=key) 
      else:  
        cont.add optionQ($val.getInt(), key=key)  
    else:
      discard  

  # To Json
  discard cont.ask(title)
  
  for key in plate.jsonStructure.keys:
    plate.jsonValue[key] = %cont.get(key)

proc `[]`(opt: OptionArgs; key: string) : JsonNode =
  opt.jsonValue[key]




# DEPRECATED
type
  OptionJson* {.deprecated.} = JsonNode
 
proc putEnum*(plate: var OptionJson; val: openArray[string]; key: string): void {.inline.} =
  plate[key] = %val

proc put*(plate: var OptionJson; val, key: string): void {.inline.} =
  plate[key] = %val

proc putBool*(plate: var OptionJson; key: string): void {.inline.} =
  plate.putEnum(["True", "False"], key)

proc putRange*(plate: var OptionJson; sn, bp: int; key: string; default: int = sn) : void {.inline.} =
  var s: seq[string]
  if default != sn:
    s.add $default
  for i in sn..bp:
    s.add $i
  plate[key] = %s

proc putEnum*[T: Questionable](plate: var OptionJson; inputs: seq[T]; key: string): void {.deprecated.} =
  var res: seq[string]
  
  for input in inputs:
    res.add(input.title)

  plate.putEnum(res, key)  

proc ask*(plate: var OptionJson; title: string = "Select Option"): void {.deprecated.} =
  var cont: seq[OptionValuedQuestionable]
  
  # To OptionValuedQuestionable
  for (key, val) in plate.pairs():
    case val.kind
    of JString:
      cont.add optionQ(val.getStr(), key=key)
    of JArray:
      cont.add optionQ(val.getElems().map(x => x.getStr()), key=key)
    of JInt:
      cont.add optionQ($val.getInt(), key=key)  
    else:
      discard  

  # To Json
  discard cont.ask(title)
  
  for key in plate.keys:
    plate[key] = %cont.get(key)

export
  OptionJson

export  
  put, putEnum, putRange, newJObject, `[]`
  