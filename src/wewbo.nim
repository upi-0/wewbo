import
  app/stream/main,
  app/dl/main,
  app/player/main

import  
  version,
  terminal/[command, paramarg],
  tui/[base, logger]

const sourceHelp = "Select Source [kura|pahe|hime|taku]"    

let app = [
  newSubCommand(
    "stream", stream, @[
      option("-s", "source", tString, "hime", sourceHelp),
      option("-p", "player", tString, help="Select Player [ffmpeg|mpv]"),
      option("--mpv", "mpv_path", tString, help="mpv path"),
      option("--ffplay", "ffplay_path", tString, help="ffplay path")
    ], "Streaming Anime"
  ),
  newSubCommand(
    "dl", download, @[
      option("-s", "source", tString, "hime", sourceHelp),
      option("--outdir", "outdir", tString, help="Define output directory"),
      option("-e", "episode", tString, help="Episode to download. (based on index)"),
      option("-fps", "fps", tInt, 24, "Set Video frame per second"),
      option("-crf", "crf", tInt, 28, "Set Video CRF (For compression)"),
      option("--no-sub", "nsub", tBool, false, "Dont include subtitle (Soft-sub only)")
    ], "Downloading Anime"
  ),
  newSubCommand(
    "player.list", playerList, help="list availabale players in your device."
  ),
  newSubCommand(
    "player.test", playerTest, help="Player testing & verbosing.", argOpts = @[
      option("-u", "url", tString, "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4", "Media URL"),
      option("-p", "player_path", tString, help="player path")
    ]
  )
]

proc main* = 
  try:
    app.start()
  
  except ref Exception:
    if not loga.logger.isNil:
      loga.logger.close()
    
    echo "wewbo " & ver
    echo "ERROR: " & getCurrentExceptionMsg()

main()
