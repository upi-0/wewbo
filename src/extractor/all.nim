import
  base,
  tables,
  types,
  strutils,
  options,
  extractors/[
    animepahe,
    kuramanime,
    otakudesu,
    hianime,
    allanime,
    tokyoinsider,
    kickass,
    moriru
  ]

import
  ../tui/[ask, logger],
  media/format

type
  ExtractorInitProc = proc(ex: var BaseExtractor) {.gcsafe.}

proc sukamtoList(): Table[string, ExtractorInitProc] =
  result["pahe"] = newMoriru
  result["hime"] = newHianime
  result["alme"] = newAllanime
  result["kura"] = newKuramanime
  result["taku"] = newOtakudesu
  result["toyo"] = newTokyoInsider
  result["kass"] = newKickass
  result["mori"] = newMoriru

const sukamto = sukamtoList()

proc listExtractor*() : seq[string] {.gcsafe.} =
  for k in sukamto.keys: result.add(k)

proc getExtractor(name: string, mode: string = "tui"): BaseExtractor {.gcsafe.} = 

  if not sukamto.hasKey(name) :
    raise newException(ValueError, "No source found: " & "'$#'" % [name]) 
  
  sukamto[name](result)
  result.init(
    logMode=detectLogMode(mode)
  )

proc parseTitleAndSource(title, extractorName: string): tuple[anTitle: string, exName: string] =
  var
    exName = extractorName
    anTitle = title

  if title.contains(":"):
    for ex in listExtractor():
      if title.contains(ex) and title.endsWith(ex):
        exName = title.split(":")[^1]
        anTitle = title.replace(exName)[ 0 ..< ^1]

  return (anTitle: anTitle, exName: exName)        

proc ask*(ex: BaseExtractor, title: string) : AnimeData =
  var listAnime = ex.animes(title)
  if listAnime.len < 1 :
    raise newException(AnimeNotFoundError, "No Anime Found")
  return listAnime.ask(title)

proc ask*(ex: BaseExtractor, ad: AnimeData) : tuple[index: int, episodes: seq[EpisodeData]] =
  var
    index: int
    episode: EpisodeData
  let
    animeUrl = ex.get(ad)
    listEpisode = ex.episodes(animeUrl)

  if listEpisode.len < 1 :
    raise newException(EpisodeNotFoundError, "No Episode Found")

  episode = listEpisode.ask()
  index = listEpisode.find(episode)

  return (index: index, episodes: listEpisode)  

proc ask*(ex: BaseExtractor; formats: seq[ExFormatData]; prevSelectedFormat: Option[FormatIdentity] = none(FormatIdentity)): ExFormatData =
  if prevSelectedFormat.isSome:
    for format in formats:
      if prevSelectedFormat.get == detectFormat(format.title):
        return format

  formats.ask("Select Format")    

proc findMatch*(listFormat: seq[ExFormatData]; prevSelectedFormat: Option[FormatIdentity]) : ExFormatData =
  if prevSelectedFormat.isSome:
    for fmt in listFormat:
      if detectFormat(fmt.title) == prevSelectedFormat.get:
        return fmt
  
  listFormat.ask("Select Format")

proc findBestMatch*(
  listFormat: seq[ExFormatData];
  preferredTitle: string;
  allowInteractive: bool = true
): ExFormatData {.gcsafe.} =
  ## Pick the format that best matches `preferredTitle` (server + resolution + language).
  ## Falls back to interactive prompt only when no format has a positive score and `allowInteractive` is true.
  if listFormat.len == 0:
    raise newException(ValueError, "No formats available for this episode.")
  if listFormat.len == 1:
    return listFormat[0]

  var
    bestIdx = 0
    bestScore = low(int)

  for idx, fmt in listFormat:
    let sc = scoreFormatMatch(fmt.title, preferredTitle)
    if sc > bestScore:
      bestScore = sc
      bestIdx = idx

  if bestScore > 0 or not allowInteractive:
    return listFormat[bestIdx]

  listFormat.ask("Select Format")

proc matchQualityPreference*(listFormat: seq[ExFormatData]; pref: string): Option[ExFormatData] {.gcsafe.} =
  ## Resolve a CLI quality preference ("best", "worst", "1080", "720", "480", "360", or substring).
  if listFormat.len == 0 or pref.strip().len == 0:
    return none(ExFormatData)

  let q = pref.strip().toLowerAscii()
  if q == "best":
    var bestIdx = 0
    var bestH = -1
    for i, fmt in listFormat:
      let h = detectResolutionHeight(fmt.title)
      if h > bestH:
        bestH = h
        bestIdx = i
    return some(listFormat[bestIdx])

  if q == "worst":
    var worstIdx = 0
    var worstH = high(int)
    for i, fmt in listFormat:
      let h = detectResolutionHeight(fmt.title)
      if h > 0 and h < worstH:
        worstH = h
        worstIdx = i
    return some(listFormat[worstIdx])

  let targetH = detectResolutionHeight(q)
  if targetH > 0:
    var
      bestIdx = -1
      bestDiff = high(int)
    for i, fmt in listFormat:
      let h = detectResolutionHeight(fmt.title)
      if h > 0:
        let diff = abs(h - targetH)
        if diff < bestDiff:
          bestDiff = diff
          bestIdx = i
    if bestIdx >= 0:
      return some(listFormat[bestIdx])

  # Substring fallback (e.g., server name)
  for fmt in listFormat:
    if fmt.title.toLowerAscii().contains(q):
      return some(fmt)

  return none(ExFormatData)

export
  BaseExtractor,
  AnimeData,
  EpisodeData,
  ExFormatData,
  AllEpisodeFormats

export
  getExtractor

export  
  init, animes, episodes, formats

export  
  getAllEpisodeFormats, get, subtitles, parseTitleAndSource
