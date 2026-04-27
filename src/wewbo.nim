import
  app/stream/main,
  app/ani_dl/main,
  app/player/main,
  app/temp/main

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
  aniDlCommand,
  newSubCommand("player", player, help="Player Test & List", argOpts = @[
      option("--test", "test", tBool, false, "Test Player"),
      option("--list", "list", tBool, false, "List Player"),
      option("-u", "url", tString, "https://huggingface.co/buckets/upi-0/astungkara/resolve/bon-apetit-op.mp4", "Media URL"),
      option("-p", "player_path", tString, help="player path")      
    ]
  ),
  newSubCommand("temp", tempManagement, help="Temp Management", argOpts = @[
      option("--list", "list", tBool, false, "List Temp Files"),
      option("--clear", "clear", tBool, false, "Clear Temp Files")
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
