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
    hasihite = availablePlayer(true)
    playerPath = f["player_path"].getStr()

  if not hasihite.contains(playerName) and playerPath.len < 1:
    echo "Please select one of: ", hasihite
    quit(1)
  
  let
    url = f["url"].getStr()
    player = getPlayer(playerName, playerPath, mode=mEcho)
    media = MediaFormatData(
      video: url,
      typeExt: extMp4)

  player.watch(media)    
