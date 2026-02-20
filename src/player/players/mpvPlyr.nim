import ../base
from strutils import `%`, join, contains

type
  MpvPL {.final.} = ref object of Player
    headerString: string = ""

proc newMpvPlayer*(basePlayer: var Player): void {.gcsafe.} =
  basePlayer = MpvPL(name: "mpv")

proc generateHeader(mpv: MpvPL, ky, val: string) {.inline.} =
  mpv.headerString &= "$#:$#," % [ky, val]   

method specialLineCB(mpv: MpvPL) : SpecialLineProc =
  return (proc(line: string) : bool = line.contains("AV"))

method setUserAgent(mpv: MpvPL, val: string) {.inline.} =
  mpv.args.add "--user-agent=" & val

method setReferer(mpv: MpvPL, val: string) {.inline.} =
  mpv.generateHeader("Referer", val)

method setSubtitle(mpv: MpvPL, subtitle: MediaSubtitle) {.inline.} =
  mpv.args.add "--sub-file=" & subtitle.url  
    
method watch_mp4(mpv: MpvPL, media: MediaFormatData) =
  mpv.args.add "--fullscreen"
  mpv.args.add "--ytdl=no"
  mpv.args.add "--http-header-fields=" & mpv.headerString
  mpv.args.add media.video
 
method watch_m3u8(mpv: MpvPL, media: MediaFormatData) = 
  mpv.watch_mp4(media)

export
  MpvPL,
  watch
