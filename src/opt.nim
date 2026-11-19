import
  json, sequtils, tables,
  tui/[ask, base],
  tui/questionable/[base, option]

from strutils import
  parseInt

from sugar import
  `=>`  

type OptionArgs* = ref object of RootObj
  jsonStructure = newJObject()
  jsonValue = newJObject()
  defaultIndices = initTable[string, int]()

proc s*(plate: JsonNode): string =
  plate.getStr()

proc n*(plate: JsonNode; default: int = 0): int =
  plate.getStr().parseInt()

proc b*(plate: JsonNode): bool =
  plate.getStr() == "True"

proc putEnum*(opt: OptionArgs; val: openArray[string]; key: string; defaultIdx: int = 0): void {.inline.} =
  opt.jsonStructure[key] = %val
  if val.len > 0:
    opt.defaultIndices[key] = clamp(defaultIdx, 0, val.len - 1)
  else:
    opt.defaultIndices[key] = 0

proc putEnum*[T: Questionable](opt: OptionArgs; inputs: seq[T]; key: string; defaultIdx: int = 0) =
  var res: seq[string]
  
  for input in inputs:
    res.add(input.title)

  opt.putEnum(res, key, defaultIdx)   

proc put*(opt: OptionArgs; val, key: string): void {.inline.} =
  opt.jsonStructure[key] = %val

proc putBool*(opt: OptionArgs; key: string; default: bool = true): void {.inline.} =
  opt.putEnum(["True", "False"], key, defaultIdx = if default: 0 else: 1)

proc putRange*(opt: OptionArgs; sn, bp: int; key: string; default: int = sn) : void {.inline.} =
  var s: seq[string]
  for i in sn..bp:
    s.add $i
  let idx = if s.len > 0: clamp(default - sn, 0, s.len - 1) else: 0
  opt.putEnum(s, key, defaultIdx = idx)

proc applyDefaults*(plate: OptionArgs): void =
  ## Populate `jsonValue` with default values for any keys not yet set (useful for non-interactive `-y` mode).
  for (key, val) in plate.jsonStructure.pairs():
    if plate.jsonValue.hasKey(key):
      continue
    case val.kind
    of JString:
      plate.jsonValue[key] = val
    of JArray:
      let elems = val.getElems()
      if elems.len > 0:
        let idx = clamp(plate.defaultIndices.getOrDefault(key, 0), 0, elems.len - 1)
        plate.jsonValue[key] = elems[idx]
      else:
        plate.jsonValue[key] = newJString("")
    of JInt:
      plate.jsonValue[key] = newJString($val.getInt())
    else:
      discard

proc ask*(plate: OptionArgs; title = "Select Option"): void =
  var cont: seq[OptionValuedQuestionable]
  
  proc isAny(key: string) : bool =
    plate.jsonValue.hasKey(key)
  
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
        let foundIdx = val.getElems().find(plate.jsonValue[key])
        let idx = if foundIdx >= 0: foundIdx else: plate.defaultIndices.getOrDefault(key, 0)
        cont.add optionQ(enumVals, key=key, optIdx = clamp(idx, 0, max(0, enumVals.len - 1)))
      else:  
        let idx = clamp(plate.defaultIndices.getOrDefault(key, 0), 0, max(0, enumVals.len - 1))
        cont.add optionQ(enumVals, key=key, optIdx = idx)
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
  