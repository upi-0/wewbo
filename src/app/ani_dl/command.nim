import
  main,
  terminal/[command, paramarg]

const
  name = "ani-dl"
  help = "Ani-DL. Anime Downloader"
  entry = download2

proc anidlCommand*: SubCommand =
  let
    commands = @[
      option("-s", "source", "Select Source", "toyo")
    ]
  result = newSubCommand(
    name = name,
    help = help,
    entry = entry,
    argOpts = commands
  )
