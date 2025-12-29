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

let sukamto: Table[string, proc(ex: var BaseExtractor) {.nimcall.}] = {
  "pahe" : newAnimepahe,
  "hime" : newHianime,
  "kura" : newKuramanime,
  "taku" : newOtakudesu
}.toTable

proc getExtractor(name: string): BaseExtractor = 
  if not sukamto.hasKey(name) :
    raise newException(ValueError, "No source found: " & "'$#'" % [name]) 
  
  sukamto[name](result)
  result.init()

export
  BaseExtractor,
  AnimeData,
  EpisodeData,
  ExFormatData,
  AllEpisodeFormats

export
  getExtractor

export  
  init, animes, episodes, formats, getAllEpisodeFormats, get
