import
  types, std/re, strutils

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

export
  MediaResolution, MediaExt
