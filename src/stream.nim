import
  illwill, terminal, os, strutils, json

import ui/[
  ask,
  controller,
]

import
  ./extractor/[all, types],
  ./tui/[logger, base],
  ./player/all,
  ./terminal/paramarg

proc setPlayer(playerName: string) : Player =
  var ple = playerName
  if players.len < 1 :
    raise newException(ValueError, "There are no Players available on your device")
  else :
    if ple == "" and players.contains("mpv") : ple = "mpv"
    else : ple = "ffplay"

  getPlayer(ple)    

proc askAnime*(ex: BaseExtractor, title: string) : AnimeData {.raises: [AnimeNotFoundError, Exception].} =
  var listAnime = ex.animes(title)
  if listAnime.len < 1 :
    raise newException(AnimeNotFoundError, "No Anime Found")
  return listAnime.ask()

proc askEpisode(ex: BaseExtractor, ad: AnimeData) : tuple[index: int, episodes: seq[EpisodeData]] {.raises: [EpisodeNotFoundError, Exception].} =
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

proc stream*(title: string, extractorName: string, playerName: string) =
  var
    anime: AnimeData
    extractor: BaseExtractor
  
  try :
    extractor = getExtractor(extractorName)
    anime = askAnime(extractor, title)

  except AnimeNotFoundError :
    extractor = getExtractor("pahe")
    anime = askAnime(extractor, title)

  let (start_idx, episodes) = askEpisode(extractor, anime)

  main_controller_loop(
    extractor,
    playerName.setPlayer(),
    episodes,
    start_idx
  )  

proc stream*(f: FullArgument) =
  let log = useWewboLogger("Streaming")

  try :
    let
      exName = f["source"].getStr()
      plName = f["player"].getStr()
      title = f.nargs[0]

    stream(title, exName, plName)

  except IndexDefect :
    echo "Try: `wewbo [Anime Title]`"
    quit(1)

  except ref Exception:
    log.info("ERROR: " & getCurrentExceptionMsg())
    log.info("This Program will close automaticly in 3 Seconds")
    sleep(3000)

  log.close()
