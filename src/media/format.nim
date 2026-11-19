import
  types, strutils, sets, languages

type FormatIdentity* = tuple[
  res: MediaResolution,
  ext: MediaExt,
  lang: Languages,
]

const
  KnownHeights = [2160, 1440, 1080, 720, 540, 520, 480, 360, 240]

proc detectResolutionHeight*(name: string): int {.gcsafe.} =
  ## Extract vertical resolution height (e.g., 1080 from "1920x1080", "1080p", "m720p", "Ak - 720", "4K").
  let lower = name.toLowerAscii()
  if lower.contains("4k") or lower.contains("uhd"):
    return 2160

  # 1. Check WxH patterns first (e.g. 1920x1080, 1280x720) -> take H
  var i = 0
  while i < lower.len:
    if lower[i] in Digits:
      let wStart = i
      while i < lower.len and lower[i] in Digits:
        inc i
      if i < lower.len and lower[i] == 'x' and i + 1 < lower.len and lower[i + 1] in Digits:
        inc i # skip 'x'
        let hStart = i
        while i < lower.len and lower[i] in Digits:
          inc i
        try:
          let h = parseInt(lower[hStart ..< i])
          if h >= 144 and h <= 4320:
            return h
        except ValueError:
          discard
        continue
      # Check <digits>p pattern (e.g., 1080p, 720p, m720p)
      if i < lower.len and lower[i] == 'p':
        try:
          let h = parseInt(lower[wStart ..< i])
          if h >= 144 and h <= 4320:
            return h
        except ValueError:
          discard
    else:
      inc i

  # 2. Fallback: look for known standalone resolution numbers
  i = 0
  while i < lower.len:
    if lower[i] in Digits:
      let dStart = i
      while i < lower.len and lower[i] in Digits:
        inc i
      try:
        let val = parseInt(lower[dStart ..< i])
        if val in KnownHeights:
          return val
      except ValueError:
        discard
    else:
      inc i

  return 0

proc detectResolution*(name: string) : MediaResolution {.gcsafe.} =
  let h = detectResolutionHeight(name)
  if h >= 1080:
    return rBest
  elif h >= 720:
    return rGood
  else:
    return rBad

proc detectExt*(name: string) : MediaExt {.gcsafe.} =
  let lower = name.toLowerAscii()
  if lower.contains(".mp4"):
    return extMp4
  if lower.contains(".m3u8"):
    return extM3u8
  if lower.contains(".mkv"):
    return extMkv
  MediaExt.extNone

proc detectFormat*(title: string) : FormatIdentity {.gcsafe.} =
  result.res = title.detectResolution()
  result.ext = title.detectExt()
  result.lang = title.detectLang()

proc extractServerTokens(title: string): HashSet[string] {.gcsafe.} =
  ## Extract normalized non-numeric provider/server tokens (e.g. "sun", "kiwi", "default", "ak", "pdrain").
  const sepChars = {' ', '-', '_', '|', '/', '(', ')', '[', ']', ',', ':'}
  for rawTok in title.toLowerAscii().split(sepChars):
    if rawTok.len < 2:
      continue
    # Skip pure numbers, WxH, and Np tokens
    var allDigitsOrRes = true
    for ch in rawTok:
      if ch notin (Digits + {'x', 'p', 'm'}):
        allDigitsOrRes = false
        break
    if allDigitsOrRes:
      continue
    result.incl(rawTok)

proc scoreFormatMatch*(candidateTitle, preferredTitle: string): int {.gcsafe.} =
  ## Score how well `candidateTitle` matches `preferredTitle`. Higher is better.
  if candidateTitle == preferredTitle:
    return 10_000

  let
    candH = detectResolutionHeight(candidateTitle)
    prefH = detectResolutionHeight(preferredTitle)
    candFmt = detectFormat(candidateTitle)
    prefFmt = detectFormat(preferredTitle)

  if candH > 0 and prefH > 0:
    if candH == prefH:
      result += 300
    else:
      result -= min(250, abs(candH - prefH) div 4)
  elif candFmt.res == prefFmt.res:
    result += 150

  let
    candTokens = extractServerTokens(candidateTitle)
    prefTokens = extractServerTokens(preferredTitle)
  for tok in prefTokens:
    if tok in candTokens:
      result += 100

  if candFmt.lang != laUnknown and candFmt.lang == prefFmt.lang:
    result += 40
  if candFmt.ext != extNone and candFmt.ext == prefFmt.ext:
    result += 20

export
  MediaResolution, MediaExt
