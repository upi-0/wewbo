import
  main,
  terminal/[command, paramarg]

const
  name = "stream"
  help = "Streaming Anime"
  entry = stream

proc streamCommand*() : SubCommand {.gcsafe.} =
  let  
    commands = @[
      option("-s", "source", "Select Source", "mori"),
      option("-p", "player", "Select Player"),
      option("--mpv", "mpv_path", "MPV Path"),
      option("--ffplay", "ffplay_path", "ffplay path")
    ]
  result = newSubCommand(
    name = name,
    help = help,
    entry = entry,
    argOpts = commands
  )
