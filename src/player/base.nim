import options
import httpclient

import ../process
import ../media/types

type Player = ref object of CliApplication

method watch_mp4(player: Player, media: MediaFormatData) {.base.} = discard
method watch_m3u8(player: Player, media: MediaFormatData) {.base.} = discard

method setUserAgent(player: Player, val: string) {.base.} = discard
method setReferer(player: Player, val: string) {.base.} = discard
method setCookie(player: Player, val: string) {.base.} = discard

method setSubtitle(player: Player, subtitle: MediaSubtitle) {.base.} = discard

proc setHeader(player: Player, header: MediaHttpHeader) =
  for key, val in header.fieldPairs() :
    if val != "" :
      case key
      of "userAgent":
        player.setUserAgent(val)
      of "referer" :
        player.setReferer(val)
      of "cookie"  :
        player.setCookie(val)

proc watch*(player: Player, media: MediaFormatData) =
  if media.headers.isSome :
    player.setHeader(media.headers.get)

  if media.subtitle.isSome :
    player.setSubtitle(media.subtitle.get)
  case media.typeExt
  of extMp4 :
    player.watch_mp4(media)
  of extM3u8 :
    player.watch_m3u8(media) 
  of extNone :
    raise newException(ValueError, "Not supported format.")

  discard player.execute() # Tar benerin lagi

export
  Player,
  MediaFormatData,
  MediaSubtitle,
  MediaExt

export  
  get,
  setUp
