import
  terminal/paramarg,
  player/all,
  media/types,
  tui/logger

proc playerList*(n: FullArgument) =
  for pler in availablePlayer(true):
    echo "- " & pler 

proc playerTest*(f: FullArgument) =
  let hasihite = availablePlayer(true)

  if f.nargs.len < 1:
    echo "Select player: ", hasihite
    quit(1)

  let
    playerName = f.nargs[0]    
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
  quit(0)
  

proc player*(n: FullArgument) =
  if n["list"].getBool():
    n.playerList()
    quit(0)    

  if n["test"].getBool():
    n.playerTest()
    quit(0)

  echo "Usage: "
  echo "--test:mpv", " test MPV player"
  echo "--list", " list player"
