import
  illwill, terminal, os, strutils, json, malebolgia

import ui/[
  ask,
  controller,
]

import
  ./extractor/[all, base, types],
  ./tui/[logger, base],
  ./player/all,
  ./terminal/paramarg

type
  Content = tuple[ex: BaseExtractor, an: AnimeData]

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

proc searchAll(title: string; sources: seq[string] = @["pahe", "hime"]) : Content {.gcsafe.} =
  proc checkSource =
    const extractorsName = ["pahe", "hime", "taku", "kura"] # TODO: Jan langsung ditulis gini jir.
    for source in sources:
      if not extractorsName.contains(source):
        raise newException(ValueError, "Invalid Source: '$#'" % [source])

  proc mengontol(exName: string; title: string) : seq[AnimeData] =
    var
      ex = getExtractor(exName, "silent")
      re = ex.animes(title)
    
    result = re
    ex.close()

  checkSource()

  var
    rez = newSeq[seq[AnimeData]](sources.len)
    m = createMaster()

  m.awaitAll:
    for i, source in sources:
      m.spawn sleep(50)
      m.spawn mengontol(source, title) -> rez[i]

  var
    exIndex: seq[string]
    animeIndex: seq[AnimeData]

  for i, source in sources:
    for sconte in rez[i]:
      exIndex.add(source)
      animeIndex.add(sconte)

  let
    animeData = animeIndex.ask(init=false, deInit=false)
    exName = exIndex[animeIndex.find(animeData)]
    extractor = getExtractor(exName)

  exIndex.reset()
  animeIndex.reset()

  return (ex: extractor, an: animeData)

proc stream*(title: string, extractorName: string, playerName:  string) =
  var
    anime: AnimeData
    extractor: BaseExtractor

  if extractorName.contains(","):
    (extractor, anime) = searchAll(
      title,
      extractorName.split(",")
    )

  else:    
    try :
      extractor = getExtractor(extractorName)
      anime = askAnime(extractor, title)

    except AnimeNotFoundError:
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
  let log = useWewboLogger("Streaming", mode=mTui)

  try :
    let
      exName = f["source"].getStr()
      plName = f["player"].getStr()
      title = f.nargs[0]

    stream(title, exName, plName)
    log.close()

  except IndexDefect :
    echo "Try: `wewbo [Anime Title]`"
    quit(1)

  except ref Exception:
    log.close()
    echo "ERROR: " & getCurrentExceptionMsg()
