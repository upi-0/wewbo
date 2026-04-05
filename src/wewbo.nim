import
  app/stream/main,
  app/dl/main,
  app/player/main

import  
  version,
  terminal/[command, paramarg],
  tui/[base, logger],
  os

const sourceHelp = "Select Source [kura|pahe|hime|taku]"    

let app = [
  newSubCommand(
    "stream", stream, @[
      option("-s", "source", tString, "pahe", sourceHelp),
      option("-p", "player", tString, help="Select Player [ffmpeg|mpv]"),
      option("--mpv", "mpv_path", tString, help="mpv path"),
      option("--ffplay", "ffplay_path", tString, help="ffplay path")
    ], "Streaming Anime"
  ),
  newSubCommand(
    "dl", download, @[
      option("-s", "source", tString, "pahe", sourceHelp),
      option("--outdir", "outdir", tString, help="Define output directory"),
      option("-e", "episode", tString, help="Episode to download. (based on index)"),
      option("-fps", "fps", tInt, 24, "Set Video frame per second"),
      option("-crf", "crf", tInt, 28, "Set Video CRF (For compression)"),
      option("--no-sub", "nsub", tBool, false, "Dont include subtitle (Soft-sub only)")
    ], "Downloading Anime"
  ),
  newSubCommand("player", player, help="Player Test & List", argOpts = @[
      option("--test", "test", tBool, false, "Test Player"),
      option("--list", "list", tBool, false, "List Player"),
      option("-u", "url", tString, "https://huggingface.co/buckets/upi-0/astungkara/resolve/bon-apetit-op.mp4", "Media URL"),
      option("-p", "player_path", tString, help="player path")      
    ]
  ),
  newSubCommand("sources", sourceList, help="List available source."),
  newSubCommand("-v", (proc(f: FullArgument) = discard), help="Version info.")
]

proc main* = 
  try:
    echo "wewbo " & ver
    app.start()

  except ref Exception:
    if not loga.logger.isNil:
      loga.logger.close()
    
    echo "wewbo " & ver
    echo "ERROR: " & getCurrentExceptionMsg()

main()

if commandLineParams().contains "--capture-error":
  if not loga.logger.isNil:
    loga.logger.exportLog()
    echo "Error log saved to " & getCurrentDir() / "wewbo.txt"
