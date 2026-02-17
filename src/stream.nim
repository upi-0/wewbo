import
  os, strutils, json, malebolgia, options, random

import
  ./ui/controller,
  ./extractor/[all, base, types],
  ./tui/[ask, logger],
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

proc searchAll(title: string; sources: seq[string] = @["pahe", "hime"]) : Content {.gcsafe.} =
  proc checkSource =
    const extractorsName = listExtractor()
    for source in sources:
      if not extractorsName.contains(source):
        raise newException(ValueError, "Invalid Source: '$#'" % [source])

  proc mengontol(exName: string; title: string) : seq[AnimeData] =
    sleep rand 100  
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
    animeData = animeIndex.ask()
    exName = exIndex[animeIndex.find(animeData)]
    extractor = getExtractor(exName)

  exIndex.reset()
  animeIndex.reset()

  return (ex: extractor, an: animeData)

proc stream*(title: string, extractorName: string, playerName: string, log: WewboLogger) =
  let
    player = playerName.setPlayer()

  var
    extractor: BaseExtractor
    ad: AnimeData
    adOpt: Option[AnimeData] = none(AnimeData)

  if extractorName.contains(","):
    log.warn("You are currently using experemintal feature of conc searching.")
    log.warn("This action may cause memory leaks.")

    (extractor, ad) = searchAll(
      title,
      extractorName.split(",")
    )
    adOpt = ad.some

  else:
    extractor = extractorName.getExtractor()

  main_controller_loop(
    title,
    extractor,
    player,
    adOpt
  )

proc stream*(f: FullArgument) =
  if f.nargs.len < 1:
    raise newException(ValueError, "Try: `wewbo [Anime Title]`")

  let
    log = useWewboLogger("Streaming", mode=mSilent)
    exName = f["source"].getStr()
    plName = f["player"].getStr()
    title = f.nargs[0]

  stream(title, exName, plName, log)
