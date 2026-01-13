import
  os, strutils, json, malebolgia, options

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

proc searchAll(title: string; sources: seq[string] = @["pahe", "hime"]) : Content {.gcsafe.} =
  proc checkSource =
    const extractorsName = listExtractor()
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
  let log = useWewboLogger("Streaming", mode=mTui)

  try :
    let
      exName = f["source"].getStr()
      plName = f["player"].getStr()
      title = f.nargs[0]

    stream(title, exName, plName, log)
    log.close()

  except IndexDefect :
    echo "Try: `wewbo [Anime Title]`"
    quit(1)

  except ref Exception:
    log.close()
    echo "ERROR: " & getCurrentExceptionMsg()
