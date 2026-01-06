import ../base 
from strutils import `%`, join, contains

type
  FfplayPL {.final.} = ref object of Player

proc setHeader(ffplay: FfplayPL, ty, val: string) =
  ffplay.args.add "-headers"
  ffplay.args.add "$#: $#" % [ty, val]

method specialLineCB(ffplay: FfplayPL) : SpecialLineProc =
  (proc(x: string) : bool = x.contains("A-V"))

method setUserAgent(ffplay: FfplayPL, val: string) =
  ffplay.setHeader("User-Agent", val)

method setReferer(ffplay: FfplayPL, val: string) =
  ffplay.setHeader("Referer", val)

method watch_mp4(ffplay: FfplayPL, media: MediaFormatData) =
  ffplay.args.add "-i"
  ffplay.args.add media.video

method watch_m3u8(ffplay: FfplayPL, media: MediaFormatData) =
  ffplay.watch_mp4(media)

export
  FfplayPL,
  setUp,
  watch  
