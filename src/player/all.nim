import base
import tables
import players/[
  ffplayPlyr,
  mpvPlyr
]
from ../process import check
from sequtils import toSeq

type
  LoaderPlayerProc = proc(basePlayer: var Player): void {.gcsafe.}
  LoaderPlayerProcs = Table[string, LoaderPlayerProc]

proc loaderPlayerProcs: LoaderPlayerProcs =
  result["ffplay"] = newFfplayPlayer
  result["mpv"] = newMpvPlayer

const
  playerLoader = loaderPlayerProcs()
  playerList = playerLoader.keys.toSeq()
  players* = playerList

proc getPlayer*(name: string = "mpv"): Player =
  var player = Player()
  playerLoader[name](player)
  player.setUp()

export
  Player,
  watch
