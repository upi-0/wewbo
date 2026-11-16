import
  main,
  terminal/[command, paramarg]

const
  name = "player"
  help = "Player Tester"
  entry = player

proc playerCommand*: SubCommand =
  let
    commands = @[
      option("--test", "test", "Test Player", false),
      option("--list", "list", "List Player", false),
      option("-u", "url", "Media URL", "https://huggingface.co/buckets/upi-0/example-video/resolve/nggyu.webm"),
      option("-p", "player_path", "player path")
    ]
  result = newSubCommand(
    name = name,
    help = help,
    entry = entry,
    argOpts = commands
  )
