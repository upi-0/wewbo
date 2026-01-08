import
  stream,
  download,
  version,
  terminal/[command, paramarg]

import
  player/all

const sourceHelp = "Select Source [kura|pahe|hime|taku]"

proc listAvailablePlayers*(n: FullArgument) =
  if players.len > 1 :
    for pler in players :
      echo "- " & pler

  else :
    echo "There are no players in your device."      

let app = [
  newSubCommand(
    "stream", stream.stream, @[
      option("-s", "source", tString, "hime", sourceHelp),
      option("-p", "player", tString, help="Select Player [ffmpeg|mpv]")
    ], "Streaming Anime"
  ),
  newSubCommand(
    "dl", download.download, @[
      option("-s", "source", tString, "hime", sourceHelp),
      option("--outdir", "outdir", tString, help="Define output directory"),
      option("-fps", "fps", tInt, 24, "Set Video frame per second"),
      option("-crf", "crf", tInt, 28, "Set Video CRF (For compression)"),
      option("--no-sub", "nsub", tBool, false, "Dont include subtitle (Soft-sub only)")
    ], "Downloading Anime"
  ),
  newSubCommand(
    "--list-players", listAvailablePlayers, help="list availabale players in your device."
  ),
]

echo "wewbo " & ver
app.start()
