from strutils import `%`
import
  base,
  tables,
  types,
  extractors/[
    animepahe,
    kuramanime,
    otakudesu,
    hianime
  ]

import
  ../tui/logger

type
  ExtractorInitProc = proc(ex: var BaseExtractor) {.gcsafe.}

proc getExtractor(name: string, mode: string = "tui"): BaseExtractor {.gcsafe.} = 

  let sukamto: Table[string, ExtractorInitProc] = {
    "pahe" : (proc: ExtractorInitProc = newAnimepahe)(),
    "hime" : newHianime,
    "kura" : newKuramanime,
    "taku" : newOtakudesu
  }.toTable

  if not sukamto.hasKey(name) :
    raise newException(ValueError, "No source found: " & "'$#'" % [name]) 
  
  sukamto[name](result)
  result.init(
    logMode=detectLogMode(mode)
  )

export
  BaseExtractor,
  AnimeData,
  EpisodeData,
  ExFormatData,
  AllEpisodeFormats

export
  getExtractor

export  
  init, animes, episodes, formats, getAllEpisodeFormats, get, subtitles
