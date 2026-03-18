import
  terminal/paramarg,
  player/all,
  media/types,
  tui/logger

proc playerList*(n: FullArgument) =
  for pler in availablePlayer(true):
    echo "- " & pler 

proc playerTest*(f: FullArgument) =
  if f.nargs.len < 1:
    echo "Invalid player name: "
    quit(1)

  let
    playerName = f.nargs[0]    
    players = availablePlayer(true)

  if not players.contains(playerName):
    echo "Please select one of: ", players
    quit(1)
  
  let
    url = f["url"].getStr()
    player = getPlayer(playerName, mode=mEcho)
    media = MediaFormatData(
      video: url,
      typeExt: extMp4)

  player.watch(media)    
