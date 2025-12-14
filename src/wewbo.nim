import
  stream,
  download,
  version,
  terminal/[command, paramarg]

import
  illwill,
  terminal

const sourceHelp = "Select Source [kura|pahe|hime|taku]"

let app = [
  newSubCommand(
    "stream", stream.stream, @[
      option("-s", "source", tString, "hime", sourceHelp),
      option("-p", "player", tString, help="Select Player [ffmpeg|mpv]")
    ]
  ),
  newSubCommand(
    "dl", download.download, @[
      option("-s", "source", tString, "hime", sourceHelp),
      option("--outdir", "outdir", tString, help="Define output directory"),
      option("-fps", "fps", tInt, 24, "Set Video frame per second"),
      option("-crf", "crf", tInt, 28, "Set Video CRF (For compression)"),
      option("--no-sub", "nsub", tBool, false, "Dont include subtitle (Soft-sub only)")
    ]
  )
]

echo "wewbo " & ver
app.start()

try:
  illwillDeinit()
except:
  discard
finally:
  showCursor()
  eraseScreen()  
  quit(0)
