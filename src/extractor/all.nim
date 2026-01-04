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

type
  ExtractorInitProc = proc(ex: var BaseExtractor) {.gcsafe.}

proc getExtractor(name: string): BaseExtractor {.gcsafe.} = 
    
  let sukamto: Table[string, ExtractorInitProc] = {
    "pahe" : (proc: ExtractorInitProc = newAnimepahe)(),
    "hime" : newHianime,
    "kura" : newKuramanime,
    "taku" : newOtakudesu
  }.toTable

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
