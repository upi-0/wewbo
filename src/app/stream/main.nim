import
  ../tui, general_act

import
  extractor/all,
  player/all,
  terminal/paramarg

proc stream*(f: FullArgument) {.gcsafe, injectProcName.} =
  proc findAndSelectPlayer() : Player =
    var playerName = f["player"].getStr()
    let polayar = availablePlayer(false)

    # If --mpv or --ffplay in the args:
    for playerN in playerList:
      let playerPath = f[playerN & "_path"].getStr()
      if playerPath.len > 0:
        return getPlayer(playerN, playerPath)

    # If -p valued:
    if playerName != "":
      return getPlayer(playerName)

    # Default
    else:
      for playerN in playerList:
        if polayar.contains(playerN):
          return getPlayer(playerN)

      discard availablePlayer() # Raise error due no player was detected.

  if f.nargs.len < 1:
    raise newException(ValueError, "Try: `wewbo [Anime Title]`")

  let
    (title, exName) = parseTitleAndSource(
      f.nargs[0], f["source"].getStr())

  let
    route = name.app(StreamSession)
    extractor = getExtractor(exName)

  block setUp:
    route.setSession()
    route.data = title
    route.session.ex = extractor
    route.session.player = findAndSelectPlayer()
  
  route.selectAnime()
  illwillDeinit()
