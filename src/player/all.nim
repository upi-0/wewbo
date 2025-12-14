import base
import players/[
  ffplayPlyr,
  mpvPlyr
]
from ../process import check

let player: array[2, Player] = [
  FfplayPL(name: "ffplay"),
  MpvPL(name: "mpv")
]

proc getAvailabePlayer() : seq[string] =
  for pler in player :
    if pler.check():
      result.add pler.name

proc getPlayer*(name: string = "mpv") : Player =
  for pler in player :
    if pler.name == name :
      return pler.setup()

export
  Player,
  watch

let players* = getAvailabePlayer()  