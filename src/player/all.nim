import base
import tables
import players/[
  ffplayPlyr,
  mpvPlyr
]
from ../process import check
from sequtils import toSeq
import tui/logger

type
  LoaderPlayerProc = proc(basePlayer: var Player): void {.gcsafe.}
  LoaderPlayerProcs = Table[string, LoaderPlayerProc]

proc loaderPlayerProcs: LoaderPlayerProcs =
  result["ffplay"] = newFfplayPlayer
  result["mpv"] = newMpvPlayer

const
  playerLoader = loaderPlayerProcs()
  playerList* = playerLoader.keys.toSeq()
  players* {.deprecated.} = playerList

proc getPlayer*(name = "mpv"; playerPath: string = ""; setPlayer = true; mode = mTui): Player =
  var player = Player()

  if not playerList.contains(name):
    let msg = "Invalid Player: " & name & ". Please select one of: " & $playerList
    raise newException(ValueError, msg)

  playerLoader[name](player)

  if playerPath != "":
    player.name = playerPath
  
  player.logMode = mode
  
  if setPlayer:
    return player.setUp()

  return player

proc availablePlayer*(raiseError = false): seq[string] =
  for player in playerList:
    var peler = getPlayer(player, setPlayer=false, mode=mSilent)
    if peler.check():
      result.add peler.name
    continue

  if raiseError and result.len < 1:
    raise newException(ValueError, "There is no player in your device.")
  
export
  Player,
  watch
