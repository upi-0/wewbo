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
  ../ui/ask,
  ../tui/logger

type
  ExtractorInitProc = proc(ex: var BaseExtractor) {.gcsafe.}

const sukamto: Table[string, ExtractorInitProc] = {
  "pahe" : (proc: ExtractorInitProc = newAnimepahe)(),
  "hime" : newHianime,
  "kura" : newKuramanime,
  "taku" : newOtakudesu
}.toTable

proc listExtractor*() : seq[string] {.gcsafe.} =
  for k in sukamto.keys: result.add(k)

proc getExtractor(name: string, mode: string = "tui"): BaseExtractor {.gcsafe.} = 

  if not sukamto.hasKey(name) :
    raise newException(ValueError, "No source found: " & "'$#'" % [name]) 
  
  sukamto[name](result)
  result.init(
    logMode=detectLogMode(mode)
  )

proc ask*(ex: BaseExtractor, title: string) : AnimeData =
  var listAnime = ex.animes(title)
  if listAnime.len < 1 :
    raise newException(AnimeNotFoundError, "No Anime Found")
  return listAnime.ask()

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
