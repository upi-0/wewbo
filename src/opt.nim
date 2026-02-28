import
  json

from strutils import
  parseInt

type
  OptionJson* = JsonNode

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

proc s*(plate: OptionJson): string =
  plate.getStr()

proc n*(plate: OptionJson; default: int = 0): int =
  plate.getStr().parseInt()

proc b*(plate: OptionJson): bool =
  plate.getStr() == "True"

export
  OptionJson

export  
  put, putEnum, putRange, newJObject, `[]`
  
when isMainModule:
  import tui/ask, terminal
  var opt: OptionJson = newJObject()

  opt.put("default", "api")
  opt.putEnum(["ffmpeg", "mpv", "vlc"], "player")
  opt.putRange(1, 24, "fps")
  
  opt.ask()
  
  type
    RijalOpt = ref tuple[status, hitam, nama: string]
      
    Rijal = ref object of RootObj
      nama: string
      umur: int
      opt: OptionJson = newJObject()
      oops: RijalOpt    

  proc newRijal() : Rijal =
    result = Rijal()
    result.opt.put("-", "nama")
    result.opt.putEnum(["On", "Off"], "status")
    result.opt.putRange(0, 100, "hitam", 50)
    result.opt.putBool("verbose")

  let rijal = newRijal()
  
  rijal.opt.ask()  
  eraseScreen()

  echo rijal.opt["verbose"].b

