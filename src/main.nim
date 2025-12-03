import std/[
  terminal,
  os,
  strutils,
  json
]
import ui/[
  ask,
  controller,
]
import ./options
import ./extractor/[all, types]
import ./player/all

proc setPlayer() : Player =
  var
    players = getAvailabePlayer()
    playerName = optionsParser.get("player").getStr()

  if players.len < 1 :
    raise newException(ValueError, "There are no Players available on your device")
  else :
    if playerName == "" and players.contains("mpv") : playerName = "mpv"
    else : playerName = "ffplay"

  getPlayer(playerName)    

proc askAnime(ex: BaseExtractor, title: string) : AnimeData {.raises: [AnimeNotFoundError, Exception].} =
  var listAnime = ex.animes(title)
  if listAnime.len < 1 :
    raise newException(AnimeNotFoundError, "No Anime Found")
  return listAnime.ask()

proc askEpisode(ex: BaseExtractor, ad: AnimeData) : EpisodeData {.raises: [EpisodeNotFoundError, Exception].} =
  var
    animeUrl = ex.get(ad)
    listEpisode = ex.episodes(animeUrl)

  if listEpisode.len < 1 :
    raise newException(EpisodeNotFoundError, "No Episode Found")
  return listEpisode.ask()


proc main*() =
  var
    anime: AnimeData
    episodes: seq[EpisodeData]
    episode: EpisodeData
    start_idx: int
    playerName: string
    extractor: BaseExtractor

  let
    title = optionsParser.nargs[0]
    extractorName = optionsParser.get("name").getStr()
  
  try :
    extractor = getExtractor(extractorName)
    anime = askAnime(extractor, title)

  except AnimeNotFoundError :
    echo "Linux Rijal KO Gada anjir"
    extractor = getExtractor("pahe")
    anime = askAnime(extractor, title)

  episode = askEpisode(extractor, anime)
  start_idx = episodes.find episode
  playerName = optionsParser.get("player").getStr()

  main_controller_loop(
    extractor,
    setPlayer(),
    episodes,
    start_idx
  )  

when isMainModule :
  main()