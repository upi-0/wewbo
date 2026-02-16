import
  json, strutils

type
  OptionJson* = JsonNode

proc putEnum*(plate: var OptionJson; val: openArray[string]; key: string): void {.inline.} =
  plate[key] = %val

proc put*(plate: var OptionJson; val, key: string) : void {.inline.} =
  plate[key] = %val

proc putRange*(plate: var OptionJson; sn, bp: int; key: string; default: int = sn) : void {.inline.} =
  var s: seq[string]
  
  if default != sn:
    s.add $default

  for i in sn..bp:
    s.add $i
  plate[key] = %s

proc s*(plate: OptionJson): string =
  plate.getStr()

proc n*(plate: OptionJson; default: int = 0) : int =
  try:
    plate.getStr().parseInt()
  except:
    default

export
  OptionJson

export  
  put, putEnum, putRange
  
when isMainModule:
  discard """
  import tui/questionable/option
  var opt: OptionJson = newJObject()

  opt.put("default", "api")
  opt.putEnum(["ffmpeg", "mpv", "vlc"], "player")
  opt.putRange(1, 24, "fps")
  
  opt.ask()

  echo opt["api"].s
  echo opt["player"].s
  echo opt["fps"].n
  """

  discard """
  type Rijal = ref object of RootObj
    nama: string
    umur: int
    opt: OptionJson = newJObject()

  proc newRijal() : Rijal =
    result = Rijal()
    result.opt.put("-", "nama")
    result.opt.putEnum(["On", "Off"], "status")
    result.opt.putRange(0, 100, "hitam", 50)

  let rijal = newRijal()
  rijal.opt.ask()
  """
