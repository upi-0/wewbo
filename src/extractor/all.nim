from strutils import `%`
import
  base,
  tables,
  extractors/[
    animepahe,
    kuramanime,
    otakudesu,
    hianime
  ]

let sukamto: Table[string, proc(ex: var BaseExtractor) {.nimcall.}] = {
  "pahe" : newAnimepahe,
  "hian" : newHianime,
  "kura" : newKuramanime,
  "taku" : newOtakudesu
}.toTable

proc getExtractor(name: string): BaseExtractor = 
  if not sukamto.hasKey(name) :
    raise newException(ValueError, "No source found: " & "'$#'" % [name]) 
  
  sukamto[name](result)
  result.init()

proc get_extractor_from_source(name: string = "pahe") : BaseExtractor =
  name.getExtractor() 

export
  BaseExtractor,
  AnimeData,
  EpisodeData,
  ExFormatData,
  get_extractor_from_source,
  getExtractor,
  init,
  animes,
  episodes,
  formats,
  get
