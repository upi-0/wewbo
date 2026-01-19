import
  options, ../ui/ask
from ../utils import contains

type  
  MediaHttpHeader* = object of RootObj
    userAgent*: string
    referer*: string
    cookie*: string

  MediaSubtitleExt* = enum
    sUnkown, sAss, sVtt

  MediaSubtitle* = ref object of Questionable
    url*: string
    lang*: string = ""
    target*: string = ""
    ext*: MediaSubtitleExt = sUnkown

  MediaExt* = enum
    extNone, extMp4, extM3u8

  MediaResolution* = enum
    rBad, rGood

  MediaFormatData* = object of RootObj
    video*: string
    typeExt*: MediaExt
    subtitle* : Option[MediaSubtitle] = none(MediaSubtitle)
    headers*: Option[MediaHttpHeader] = none(MediaHttpHeader)  

proc detectResolution*(name: string) : MediaResolution =
  const
    badResolution = @[$480, $360]
    goodResolution = @[$720, $1080]

  if name.contains(badResolution):
    return rBad
  if name.contains(goodResolution):
    return rGood

when isMainModule: 
  echo "360, pdrain, jpn".detectResolution()
