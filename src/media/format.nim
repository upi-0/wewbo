import
  types, std/re, strutils, languages

type FormatIdentity* = tuple[
  res: MediaResolution,
  ext: MediaExt,
  lang: Languages,
]

proc detectResolution*(name: string) : MediaResolution =
  const
    badResolution = @[$480, $520, $360]
    goodResolution = @[$720, $1080]

  let containResolution = name.findAll(re"\d+")

  for res in containResolution:
    if badResolution.contains(res):
      return rBad
    elif goodResolution.contains(res):
      return rGood

proc detectExt*(name: string) : MediaExt =
  if name.endsWith(".mp4"):
    return extMp4
  if name.contains(".m3u8"):
    return extM3u8
  MediaExt.extNone

proc detectFormat*(title: string) : FormatIdentity =
  result.res = title.detectResolution()
  result.ext = title.detectExt()
  result.lang = title.detectLang()

export
  MediaResolution, MediaExt
