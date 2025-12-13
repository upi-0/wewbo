import logger
import illwill
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
import ./opts
import ./extractor/[all, types]
import ./player/all

proc setPlayer() : Player =
  var
    playerName = optionsParser["player"].getStr()

  if players.len < 1 :
    raise newException(ValueError, "There are no Players available on your device")
  else :
    if playerName == "" and players.contains("mpv") : playerName = "mpv"
    else : playerName = "ffplay"

  getPlayer(playerName)    

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

proc main*(title: string, extractorName: string) =
  var
    anime: AnimeData
    extractor: BaseExtractor
  
  try :
    extractor = getExtractor(extractorName)
    anime = askAnime(extractor, title)

  except AnimeNotFoundError :
    log.info "Failed to fetch anime from '$#' trying with 'pahe' instead" % [extractor.name]
    extractor = getExtractor("pahe")
    anime = askAnime(extractor, title)

  let (start_idx, episodes) = askEpisode(extractor, anime)

  main_controller_loop(
    extractor,
    setPlayer(),
    episodes,
    start_idx
  )  

proc main*() =
  try :
    let
      exName = optionsParser["name"].getStr()
      title = optionsParser.nargs[0]
    main(title, exName)

  except IndexDefect :
    echo "Try: `wewbo [Anime Title]`"
    quit(1)

  except ref Exception:
    log.info("ERROR: " & getCurrentExceptionMsg())
    log.info("This Program will close automaticly in 3 Seconds")
    sleep(3000)
    eraseScreen()
    showCursor()
    quit(1) 
